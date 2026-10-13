import Foundation
import Observation

/// Runs ai-worker/worker.py as a child process and talks to it (port of VoiceBud's
/// `cleanup.Cleaner` client rules, generic):
///
/// - started on the first request, never at app launch; it exits by itself when idle and is
///   started again on the next request (a clean exit is not a crash).
/// - each request waits for its own answer; the timeout runs from the worker's "started" event,
///   so time in the queue or loading the model (up to `queueGrace`) is not counted.
/// - a timeout kills the worker (marked as our own kill, so it is not counted as a crash).
/// - a crash fails the open requests; the next start waits per `RestartPolicy` (0, 5, 30, 300 s
///   for crashes in a row) and a request that died in the first crash is sent once more.
/// - cancel: cancelling the calling Task sends "cancel"; the worker stops after the next token.
///   A worker that has not confirmed it within `cancelGrace` is stuck and is killed (our own kill,
///   so the next request starts a fresh worker at once).
/// - stderr goes to `MLXPaths.logFile`, stdout is the protocol only.
@Observable final class MLXWorkerClient {
    /// How to start the worker.
    nonisolated struct Launch: Sendable {
        var executable: URL
        var arguments: [String]
        var environment: [String: String]
        /// stderr goes here (nil: discarded).
        var log: URL?
    }

    enum Phase: Equatable {
        case stopped
        case starting
        case running
        /// After a crash: the next start waits until this time.
        case waiting(until: Date)
    }

    struct GenerateResult: Equatable {
        let text: String
        let stats: WorkerStats
    }

    private(set) var phase: Phase = .stopped
    /// The model folder loaded in the running worker (nil after an exit).
    private(set) var loadedModel: String?
    /// Crashes in a row (reset by the next answer).
    private(set) var crashes = 0
    private(set) var lastCrash: Date?
    /// Short cause of the last failure, for the log and diagnostics (never shown as UI copy).
    private(set) var lastProblem: String?
    /// Worker processes started so far (tests).
    private(set) var starts = 0

    @ObservationIgnored var policy = RestartPolicy()
    /// Time a request may wait for "started" (queue + model load) on top of its own timeout.
    @ObservationIgnored var queueGrace: TimeInterval = 90
    /// Time the worker may take to say "ready".
    @ObservationIgnored var startTimeout: TimeInterval = 20
    /// After a cancel the request ends at the latest this much later, answer or not.
    @ObservationIgnored var cancelGrace: TimeInterval = 5
    @ObservationIgnored var now: () -> Date = Date.init
    @ObservationIgnored private let launcher: () -> Launch?

    private struct Pending {
        let id: Int
        let process: Int
        let continuation: CheckedContinuation<WorkerEvent, Error>
        let sent: Date
        var started: Date?
        let timeout: TimeInterval
        let onToken: ((String) -> Void)?
        var cancelAt: Date?
    }

    @ObservationIgnored private var pending: [Int: Pending] = [:]
    @ObservationIgnored private var nextID = 1
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var input: FileHandle?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var ownKill = false
    @ObservationIgnored private var idleExit = false
    @ObservationIgnored private var timedOutID: Int?
    @ObservationIgnored private var endings: [Int: (eof: Bool, status: Int32?)] = [:]
    @ObservationIgnored private var ticker: Timer?

    /// `launch` is asked at every start; nil means "not installed".
    init(launch: @escaping () -> Launch?) {
        launcher = launch
        signal(SIGPIPE, SIG_IGN)   // a write to a worker that just died must not kill the app
    }

    var isRunning: Bool { process != nil }

    // MARK: Requests

    /// Generates text. `onToken` gets each piece as it arrives (streaming). When the worker crashes
    /// mid-answer the request is sent once more to a fresh worker; `onRestart` is called first, so a
    /// caller that collects pieces starts over instead of appending the second answer to the first.
    func generate(prompt: String, system: String?, model: String?, maxTokens: Int, temperature: Double = 0,
                  priority: Int = 0, timeout: TimeInterval? = nil, onToken: ((String) -> Void)? = nil,
                  onRestart: (() -> Void)? = nil) async throws -> GenerateResult {
        let budget = timeout ?? WorkerBudget.timeout(maxTokens: maxTokens)
        func once() async throws -> GenerateResult {
            let event = try await request(timeout: budget, onToken: onToken) { id in
                WorkerRequest.generate(id: id, prompt: prompt, system: system, model: model, maxTokens: maxTokens,
                                       temperature: temperature, stream: onToken != nil, priority: priority)
            }
            guard case .done(_, let text, _, _, let stats) = event else { throw AIError.failed("unexpected \(event)") }
            if let model { loadedModel = model }
            return GenerateResult(text: text ?? "", stats: stats)
        }
        do {
            return try await once()
        } catch AIError.workerCrashed where policy.wait(crashes: crashes, lastCrash: lastCrash, now: now()) == 0 {
            // one more try on a fresh worker (VoiceBud: a single crash must not cost the answer)
            Log.warn("mlx: worker ended during a request; sending it once more", "mlx")
            onRestart?()
            return try await once()
        }
    }

    /// Loads a model folder now (warm-up), so the first answer does not wait for it.
    func load(model: String, timeout: TimeInterval = 120) async throws -> WorkerStats {
        let event = try await request(timeout: timeout, onToken: nil) { WorkerRequest.load(id: $0, model: model) }
        guard case .done(_, _, _, _, let stats) = event else { throw AIError.failed("unexpected \(event)") }
        loadedModel = model
        return stats
    }

    func unload() async throws {
        _ = try await request(timeout: 10, onToken: nil) { WorkerRequest.unload(id: $0) }
        loadedModel = nil
    }

    /// Answered by the worker's reader thread, also while it generates.
    func ping(timeout: TimeInterval = 5) async throws -> (loaded: String?, busy: Bool) {
        let event = try await request(timeout: timeout, onToken: nil, startedImmediately: true) { WorkerRequest.ping(id: $0) }
        guard case .pong(_, let loaded, let busy) = event else { throw AIError.failed("unexpected \(event)") }
        return (loaded, busy)
    }

    /// Stops request `id` (also what cancelling the calling Task does).
    func cancel(_ id: Int) {
        guard var p = pending[id], p.cancelAt == nil else { return }
        p.cancelAt = now()
        pending[id] = p
        write(WorkerRequest.cancel(id: id))
    }

    /// Ids of open requests (tests, diagnostics).
    var openRequests: [Int] { pending.keys.sorted() }

    /// Quit: "shutdown", up to 2 s for the worker to go, then kill. Open requests end as cancelled.
    func shutdown() {
        guard let p = process else { return }
        ownKill = true
        write(WorkerRequest.shutdown)
        let deadline = Date().addingTimeInterval(2)
        while p.isRunning && Date() < deadline { usleep(20_000) }
        if p.isRunning { p.terminate() }
        let hard = Date().addingTimeInterval(1)
        while p.isRunning && Date() < hard { usleep(20_000) }
        if p.isRunning { kill(p.processIdentifier, SIGKILL) }
        // done here, not in the exit handler: the app may be quitting
        generation += 1
        process = nil
        input = nil
        loadedModel = nil
        phase = .stopped
        for id in pending.keys { finish(id, .failure(AIError.cancelled)) }
    }

    private func request(timeout: TimeInterval, onToken: ((String) -> Void)?, startedImmediately: Bool = false,
                         _ make: (Int) -> String) async throws -> WorkerEvent {
        try Task.checkCancellation()
        try ensureRunning()
        let id = nextID
        nextID += 1
        let line = make(id)
        let process = generation
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkerEvent, Error>) in
                let sent = now()
                pending[id] = Pending(id: id, process: process, continuation: continuation, sent: sent,
                                      started: startedImmediately ? sent : nil, timeout: timeout, onToken: onToken)
                startTicker()
                // a failed write means the worker is going away: its exit fails this request
                write(line)
            }
        } onCancel: {
            let box = WeakBox(self)
            DispatchQueue.main.async { MainActor.assumeIsolated { box.value?.cancel(id) } }
        }
    }

    // MARK: Process

    private func ensureRunning() throws {
        if process != nil { return }
        let wait = policy.wait(crashes: crashes, lastCrash: lastCrash, now: now())
        if wait > 0 { throw AIError.restarting(wait) }
        guard let launch = launcher() else { throw AIError.unavailable(.notInstalled) }
        try spawn(launch)
    }

    private func spawn(_ launch: Launch) throws {
        let p = Process()
        p.executableURL = launch.executable
        p.arguments = launch.arguments
        p.environment = launch.environment
        let stdin = Pipe(), stdout = Pipe()
        p.standardInput = stdin
        p.standardOutput = stdout
        if let log = launch.log, let handle = MLXPaths.appendHandle(log) { p.standardError = handle } else { p.standardError = FileHandle.nullDevice }

        generation += 1
        let gen = generation
        let box = WeakBox(self)
        let buffer = LineBuffer()
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                DispatchQueue.main.async { MainActor.assumeIsolated { box.value?.ended(gen, eof: true, status: nil) } }
                return
            }
            let lines = buffer.append(data)
            guard !lines.isEmpty else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { for line in lines { box.value?.received(line, from: gen) } } }
        }
        p.terminationHandler = { proc in
            let status = proc.terminationStatus
            DispatchQueue.main.async { MainActor.assumeIsolated { box.value?.ended(gen, eof: false, status: status) } }
        }
        do {
            try p.run()
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            lastProblem = "cannot start \(launch.executable.path): \(error.localizedDescription)"
            Log.error("mlx: \(lastProblem ?? "")", "mlx")
            throw AIError.unavailable(.notInstalled)
        }
        process = p
        input = stdin.fileHandleForWriting
        ownKill = false
        idleExit = false
        timedOutID = nil
        startedAt = now()
        starts += 1
        phase = .starting
        startTicker()
        Log.info("mlx: worker started (pid \(public: p.processIdentifier))", "mlx")
    }

    @discardableResult
    private func write(_ line: String) -> Bool {
        guard let input else { return false }
        do {
            try input.write(contentsOf: Data(line.utf8))
            return true
        } catch {
            Log.warn("mlx: write to worker failed: \(error.localizedDescription)", "mlx")
            return false
        }
    }

    private func received(_ line: String, from gen: Int) {
        guard gen == generation else { return }
        let event = WorkerEvent.parse(line)
        switch event {
        case .ready:
            phase = .running
        case .pong(let id, _, _):
            finish(id, .success(event))
        case .started(let id):
            pending[id]?.started = now()
        case .token(let id, let text):
            pending[id]?.onToken?(text)
        case .done(let id, _, _, let cancelled, _):
            if cancelled {
                finish(id, .failure(AIError.cancelled))
            } else {
                crashes = 0
                finish(id, .success(event))
            }
        case .error(let id, let kind, let message):
            lastProblem = "\(kind): \(message)"
            Log.warn("mlx: worker error \(public: kind): \(message)", "mlx")
            if let id { finish(id, .failure(kind == "mlx-missing" ? AIError.unavailable(.notInstalled) : AIError.failed(lastProblem ?? kind))) }
        case .exit(let reason):
            idleExit = reason == "idle"
        case .unknown(let text):
            Log.debug("mlx: ignored line \(text.prefix(120))", "mlx")
        }
    }

    /// Called twice per process (stdout closed, process terminated); acts once both happened, so
    /// every line the worker wrote has been handled first.
    private func ended(_ gen: Int, eof: Bool, status: Int32?) {
        var state = endings[gen] ?? (false, nil)
        if eof { state.eof = true }
        if let status { state.status = status }
        endings[gen] = state
        guard state.eof, let code = state.status else { return }
        endings[gen] = nil
        guard gen == generation else { return }

        let open = pending.values.filter { $0.process == gen }
        let planned = ownKill || idleExit || (code == 0 && open.isEmpty)
        process = nil
        input = nil
        loadedModel = nil
        if planned {
            phase = .stopped
            Log.info("mlx: worker ended (\(public: idleExit ? "idle" : ownKill ? "stopped" : "exit \(code)"))", "mlx")
        } else {
            crashes += 1
            lastCrash = now()
            lastProblem = "worker exited with \(code)"
            let wait = policy.delay(afterCrashes: crashes)
            phase = wait > 0 ? .waiting(until: now().addingTimeInterval(wait)) : .stopped
            Log.error("mlx: worker crashed (exit \(public: code), \(public: crashes) in a row, next start in \(public: Int(wait)) s)", "mlx")
        }
        for p in open { finish(p.id, .failure(p.id == timedOutID ? AIError.timeout : AIError.workerCrashed)) }
        timedOutID = nil
    }

    private func finish(_ id: Int, _ result: Result<WorkerEvent, Error>) {
        guard let p = pending.removeValue(forKey: id) else { return }
        p.continuation.resume(with: result)
        if pending.isEmpty && phase != .starting { stopTicker() }
    }

    /// Kills the worker on purpose (timeout, failed start); its open requests fail.
    private func killWorker(_ why: String) {
        guard let p = process else { return }
        lastProblem = why
        Log.warn("mlx: \(public: why); stopping the worker", "mlx")
        p.terminate()
        let pid = p.processIdentifier
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if p.isRunning { kill(pid, SIGKILL) } }
    }

    // MARK: Deadlines

    private func startTicker() {
        guard ticker == nil else { return }
        let box = WeakBox(self)
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated { box.value?.tick() }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        let t = now()
        if phase == .starting, let s = startedAt, t.timeIntervalSince(s) > startTimeout, process != nil {
            // not our kill: a worker that never says "ready" counts as a crash
            killWorker("worker did not start within \(Int(startTimeout)) s")
            startedAt = nil
        }
        for p in pending.values {
            if let c = p.cancelAt, t.timeIntervalSince(c) > cancelGrace {
                finish(p.id, .failure(AIError.cancelled))
                // a worker that ignores a cancel is stuck in the generation: it would never go
                // idle and every later request would queue behind it until its timeout
                if p.process == generation, process != nil, p.started != nil {
                    ownKill = true
                    killWorker("request \(p.id) did not stop within \(Int(cancelGrace)) s of its cancel")
                }
                continue
            }
            let deadline = p.started.map { $0.addingTimeInterval(p.timeout) } ?? p.sent.addingTimeInterval(p.timeout + queueGrace)
            if t > deadline, p.process == generation, process != nil, timedOutID == nil {
                timedOutID = p.id
                ownKill = true
                killWorker("no answer to request \(p.id) within \(Int(p.timeout)) s")
            }
        }
        if pending.isEmpty && phase != .starting { stopTicker() }
    }
}
