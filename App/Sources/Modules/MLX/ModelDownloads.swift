import Foundation
import Observation

/// Model downloads for the MLX worker, one at a time (VoiceBud: "the progress stays honest"), each in
/// ai-worker/download.py as a child process that reports JSON progress lines. Nothing is downloaded
/// unless the user presses Download: the app makes no other network requests. A stopped or failed download keeps its bytes
/// and resumes on retry.
@Observable final class ModelDownloads {
    enum State: Equatable {
        case notStarted
        case queued
        case running(done: Int64, total: Int64)
        /// Stopped (offline, failed, cancelled); `problem` is the kind from download.py.
        case paused(done: Int64, total: Int64, problem: String)
        case done
    }

    /// How to start download.py for a model (nil: Python or the worker folder is missing).
    nonisolated struct Launch: Sendable {
        var executable: URL
        var arguments: [String]
        var environment: [String: String]
        var log: URL?
    }

    private(set) var catalog: ModelCatalog
    private(set) var states: [String: State] = [:]
    /// The last message of a failed download (log and diagnostics only).
    private(set) var lastProblem: String?
    @ObservationIgnored let hub: URL
    @ObservationIgnored private let launcher: (ModelSpec) -> Launch?
    /// Called on the main actor when a model finished (the provider re-checks its availability).
    @ObservationIgnored var onFinished: ((String) -> Void)?

    @ObservationIgnored private var queue: [String] = []
    @ObservationIgnored private var active: (id: String, process: Process, gen: Int)?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var terminal: [Int: Bool] = [:]
    /// Downloads whose model was deleted while they ran: their last events are ignored.
    @ObservationIgnored private var discarded: Set<Int> = []

    init(catalog: ModelCatalog, hub: URL, launch: @escaping (ModelSpec) -> Launch?) {
        self.catalog = catalog
        self.hub = hub
        launcher = launch
        refresh()
    }

    /// The app's downloads: catalog next to the worker, models in Application Support.
    static func standard() -> ModelDownloads {
        ModelDownloads(catalog: .current, hub: MLXPaths.hub) { model in
            guard let dir = MLXPaths.workerDir, let python = MLXPaths.python(workerDir: dir) else { return nil }
            MLXPaths.prepareModelsFolder()
            let catalog = ModelCatalog.current
            var args = ["-u", dir.appendingPathComponent("download.py").path, "--repo", model.repo, "--total", String(model.bytes),
                        "--hf-home", MLXPaths.hfHome.path, "--watch-stdin"]
            if let rev = model.revision { args += ["--revision", rev] }
            let allow = catalog.patterns(for: model)
            if !allow.isEmpty { args += ["--allow", allow.joined(separator: ",")] }
            return Launch(executable: python, arguments: args, environment: MLXPaths.environment(), log: MLXPaths.logFile)
        }
    }

    func state(_ id: String) -> State { states[id] ?? .notStarted }

    func isPresent(_ model: ModelSpec) -> Bool { HubCache.snapshot(hub: hub, repo: model.repo, revision: model.revision) != nil }

    /// The snapshot folder to hand to the worker, nil until downloaded.
    func path(_ model: ModelSpec) -> URL? { HubCache.snapshot(hub: hub, repo: model.repo, revision: model.revision) }

    /// Re-reads what is on disk (a model downloaded elsewhere, a folder deleted by hand).
    func refresh() {
        for m in catalog.models {
            let s = state(m.id)
            switch s {
            case .queued, .running: continue
            case .notStarted, .paused, .done:
                if isPresent(m) {
                    if s != .done { states[m.id] = .done }
                } else if s == .done {
                    states[m.id] = .notStarted
                }
            }
        }
    }

    /// Starts (or resumes) a download; queued behind a running one.
    func start(_ id: String) {
        guard let model = catalog.model(id) else { return }
        if isPresent(model) {
            states[id] = .done
            return
        }
        switch state(id) {
        case .queued, .running: return
        case .notStarted, .paused, .done: break
        }
        states[id] = .queued
        queue.append(id)
        pump()
    }

    /// Stops a running or queued download; its bytes stay for a later resume.
    func pause(_ id: String) {
        if let i = queue.firstIndex(of: id) {
            queue.remove(at: i)
            states[id] = .notStarted
            return
        }
        guard let active, active.id == id else { return }
        active.process.terminate()
    }

    /// Deletes a downloaded model; a running or queued download of it stops and leaves nothing behind.
    func remove(_ id: String) {
        guard let model = catalog.model(id) else { return }
        queue.removeAll { $0 == id }
        if let active, active.id == id {
            // its "cancelled" line and its end must not bring the row back as paused
            discarded.insert(active.gen)
            active.process.terminate()
        }
        do {
            try HubCache.remove(hub: hub, repo: model.repo)
        } catch {
            lastProblem = error.localizedDescription
        }
        states[id] = .notStarted
        refresh()
        onFinished?(id)
    }

    /// Bytes of all downloaded models on disk.
    var bytesOnDisk: Int64 { catalog.models.reduce(0) { $0 + HubCache.blobBytes(hub: hub, repo: $1.repo) } }

    var isBusy: Bool { active != nil || !queue.isEmpty }

    // MARK: Process

    private func pump() {
        guard active == nil, !queue.isEmpty else { return }
        let id = queue.removeFirst()
        guard let model = catalog.model(id) else { return pump() }
        guard let launch = launcher(model) else {
            states[id] = .paused(done: 0, total: model.bytes, problem: "setup")
            lastProblem = "Python environment missing (ai-worker/setup.sh)"
            return pump()
        }
        let p = Process()
        p.executableURL = launch.executable
        p.arguments = launch.arguments
        p.environment = launch.environment
        let stdin = Pipe(), stdout = Pipe()
        p.standardInput = stdin            // kept open: download.py stops when it closes (app gone)
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
                DispatchQueue.main.async { MainActor.assumeIsolated { box.value?.ended(gen, input: stdin) } }
                return
            }
            let lines = buffer.append(data)
            guard !lines.isEmpty else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { for l in lines { box.value?.received(l, gen: gen) } } }
        }
        let done = HubCache.blobBytes(hub: hub, repo: model.repo)
        states[id] = .running(done: min(done, model.bytes), total: model.bytes)
        do {
            try p.run()
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            states[id] = .paused(done: done, total: model.bytes, problem: "setup")
            lastProblem = error.localizedDescription
            return pump()
        }
        active = (id, p, gen)
        Log.info("mlx: downloading \(public: model.repo)", "mlx")
    }

    private func received(_ line: String, gen: Int) {
        guard let active, active.gen == gen, !discarded.contains(gen) else { return }
        let id = active.id
        switch DownloadEvent.parse(line) {
        case .start(let total):
            if case .running(let done, let old) = state(id) { states[id] = .running(done: done, total: total > 0 ? total : old) }
        case .progress(let done, let total):
            let old = { if case .running(_, let t) = self.state(id) { return t }; return 0 }()
            states[id] = .running(done: done, total: total > 0 ? total : old)
        case .done:
            terminal[gen] = true
            states[id] = .done
            Log.info("mlx: download of \(public: id) finished", "mlx")
        case .error(let kind, let message, let done, let total):
            terminal[gen] = true
            states[id] = .paused(done: done, total: total, problem: kind)
            if kind != "cancelled" {
                lastProblem = message
                Log.warn("mlx: download of \(public: id) stopped (\(public: kind)): \(message)", "mlx")
            }
        case .unknown(let text):
            Log.debug("mlx: download line ignored: \(text.prefix(120))", "mlx")
        }
    }

    private func ended(_ gen: Int, input: Pipe) {
        try? input.fileHandleForWriting.close()
        guard let active, active.gen == gen else { return }
        active.process.waitUntilExit()
        let id = active.id
        self.active = nil
        if discarded.remove(gen) != nil {
            // deleted while it ran: the process may have written until it exited
            terminal.removeValue(forKey: gen)
            if let model = catalog.model(id) { try? HubCache.remove(hub: hub, repo: model.repo) }
            states[id] = .notStarted
            onFinished?(id)
            return pump()
        }
        if terminal.removeValue(forKey: gen) == nil {
            // ended without a last word (killed, crashed): keep what arrived
            let model = catalog.model(id)
            let done = model.map { HubCache.blobBytes(hub: hub, repo: $0.repo) } ?? 0
            states[id] = .paused(done: done, total: model?.bytes ?? 0, problem: "failed")
        }
        if case .done = state(id) { onFinished?(id) }
        pump()
    }

    /// Stops everything (app quits); partial files stay for a resume.
    func stopAll() {
        queue.removeAll()
        active?.process.terminate()
    }
}
