import Foundation

// The pure parts of talking to ai-worker/worker.py and ai-worker/download.py (JSON lines; the
// protocol is documented at the top of worker.py). Tested in MLXTests without a process.

/// One line from worker.py.
nonisolated enum WorkerEvent: Equatable, Sendable {
    case ready(pid: Int)
    case pong(id: Int, loaded: String?, busy: Bool)
    case started(id: Int)
    case token(id: Int, text: String)
    /// `text` for generate, `model` for load; `cancelled` when the request was stopped.
    case done(id: Int, text: String?, model: String?, cancelled: Bool, stats: WorkerStats)
    case error(id: Int?, kind: String, message: String)
    case exit(reason: String)
    /// Not JSON or an unknown event (logged, otherwise ignored).
    case unknown(String)

    static func parse(_ line: String) -> WorkerEvent {
        guard let o = JSONLine.object(line), let event = o["event"]?.string else { return .unknown(line) }
        let id = o["id"]?.int
        switch event {
        case "ready": return .ready(pid: o["pid"]?.int ?? 0)
        case "pong":
            guard let id else { return .unknown(line) }
            return .pong(id: id, loaded: o["loaded"]?.string, busy: o["busy"]?.bool ?? false)
        case "started":
            guard let id else { return .unknown(line) }
            return .started(id: id)
        case "token":
            guard let id else { return .unknown(line) }
            return .token(id: id, text: o["text"]?.string ?? "")
        case "done":
            guard let id else { return .unknown(line) }
            var stats = WorkerStats(o["stats"]?.objectValue ?? [:])
            if let load = o["load_s"]?.double { stats.loadSeconds = load }
            return .done(id: id, text: o["text"]?.string, model: o["model"]?.string, cancelled: o["cancelled"]?.bool ?? false,
                         stats: stats)
        case "error": return .error(id: id, kind: o["kind"]?.string ?? "failed", message: o["error"]?.string ?? "")
        case "exit": return .exit(reason: o["reason"]?.string ?? "")
        default: return .unknown(line)
        }
    }
}

/// Timings of one request (worker.py "stats"); all optional.
nonisolated struct WorkerStats: Equatable, Sendable {
    var tokens: Int?
    var tokensPerSecond: Double?
    var loadSeconds: Double?
    var promptSeconds: Double?
    var evalSeconds: Double?
    var peakMB: Double?

    init(tokens: Int? = nil, tokensPerSecond: Double? = nil, loadSeconds: Double? = nil, promptSeconds: Double? = nil,
         evalSeconds: Double? = nil, peakMB: Double? = nil) {
        self.tokens = tokens
        self.tokensPerSecond = tokensPerSecond
        self.loadSeconds = loadSeconds
        self.promptSeconds = promptSeconds
        self.evalSeconds = evalSeconds
        self.peakMB = peakMB
    }

    init(_ o: [String: JSONValue]) {
        self.init(tokens: o["tokens"]?.int, tokensPerSecond: o["tps"]?.double, loadSeconds: o["load_s"]?.double,
                  promptSeconds: o["prompt_s"]?.double, evalSeconds: o["eval_s"]?.double, peakMB: o["peak_mb"]?.double)
    }
}

/// Requests to worker.py, one JSON object per line (keys sorted, so lines are deterministic).
nonisolated enum WorkerRequest {
    static func ping(id: Int) -> String { line(["op": .string("ping"), "id": .int(Int64(id))]) }

    static func load(id: Int, model: String) -> String {
        line(["op": .string("load"), "id": .int(Int64(id)), "model": .string(model)])
    }

    static func unload(id: Int) -> String { line(["op": .string("unload"), "id": .int(Int64(id))]) }

    static func cancel(id: Int) -> String { line(["op": .string("cancel"), "id": .int(Int64(id))]) }

    static var shutdown: String { line(["op": .string("shutdown")]) }

    static func generate(id: Int, prompt: String, system: String?, model: String?, maxTokens: Int, temperature: Double,
                         stream: Bool, priority: Int = 0, loopGuard: Bool = true) -> String {
        var o: [String: JSONValue] = [
            "op": .string("generate"), "id": .int(Int64(id)), "prompt": .string(prompt), "max_tokens": .int(Int64(maxTokens)),
            "temp": .double(temperature), "stream": .bool(stream), "priority": .int(Int64(priority)), "loop_guard": .bool(loopGuard),
        ]
        if let system, !system.isEmpty { o["system"] = .string(system) }
        if let model { o["model"] = .string(model) }
        return line(o)
    }

    static func line(_ object: [String: JSONValue]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(JSONValue.object(object))) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}

/// One line from download.py.
nonisolated enum DownloadEvent: Equatable, Sendable {
    case start(total: Int64)
    case progress(done: Int64, total: Int64)
    case done(path: String, total: Int64)
    /// kind: offline | failed | cancelled | setup
    case error(kind: String, message: String, done: Int64, total: Int64)
    case unknown(String)

    static func parse(_ line: String) -> DownloadEvent {
        guard let o = JSONLine.object(line), let event = o["event"]?.string else { return .unknown(line) }
        let total = o["total"]?.int64 ?? 0
        switch event {
        case "start": return .start(total: total)
        case "progress": return .progress(done: o["done"]?.int64 ?? 0, total: total)
        case "done": return .done(path: o["path"]?.string ?? "", total: total)
        case "error":
            return .error(kind: o["kind"]?.string ?? "failed", message: o["error"]?.string ?? "", done: o["done"]?.int64 ?? 0, total: total)
        default: return .unknown(line)
        }
    }
}

/// When the worker may start again after crashing (VoiceBud: restart, then back off).
nonisolated struct RestartPolicy: Equatable, Sendable {
    /// Wait before the start after the 1st, 2nd, 3rd, 4th+ crash in a row.
    var delays: [TimeInterval] = [0, 5, 30, 300]

    /// The wait after `crashes` crashes in a row (0 crashes: none).
    func delay(afterCrashes crashes: Int) -> TimeInterval {
        guard crashes > 0, !delays.isEmpty else { return 0 }
        return delays[min(crashes, delays.count) - 1]
    }

    /// Seconds still to wait at `now`, 0 when a start is allowed.
    func wait(crashes: Int, lastCrash: Date?, now: Date) -> TimeInterval {
        guard let lastCrash else { return 0 }
        return max(0, lastCrash.addingTimeInterval(delay(afterCrashes: crashes)).timeIntervalSince(now))
    }
}

/// Budgets that grow with the input (VoiceBud: a fixed budget failed long inputs on slow Macs).
nonisolated enum WorkerBudget {
    /// Answer length when the caller does not say: room for about twice the prompt, 256…2048 tokens.
    static func maxTokens(promptCharacters: Int) -> Int {
        min(2048, max(256, promptCharacters / 2 + 256))
    }

    /// Seconds a running generation may take after "started" (load and queue are not counted).
    static func timeout(maxTokens: Int) -> TimeInterval {
        min(300, 20 + Double(maxTokens) * 0.05)
    }
}

/// Splits a byte stream into lines; safe to feed from a pipe's background queue.
nonisolated final class LineBuffer: @unchecked Sendable {
    private var pending = Data()
    private let lock = NSLock()

    func append(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pending.append(data)
        var lines: [String] = []
        while let nl = pending.firstIndex(of: 0x0A) {
            let line = pending[pending.startIndex..<nl]
            pending.removeSubrange(pending.startIndex...nl)
            let text = String(decoding: line, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append(text) }
        }
        return lines
    }
}

/// A weak reference that can travel into @Sendable closures (pipe handlers, timers) and back to
/// the main actor.
nonisolated final class WeakBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

nonisolated enum JSONLine {
    static func object(_ line: String) -> [String: JSONValue]? {
        guard let data = line.data(using: .utf8), let v = try? JSONDecoder().decode(JSONValue.self, from: data) else { return nil }
        return v.objectValue
    }
}

nonisolated extension JSONValue {
    var string: String? { if case .string(let s) = self { return s }; return nil }
    var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var int64: Int64? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int64(d)
        default: return nil
        }
    }
    var int: Int? { int64.map { Int($0) } }
    var double: Double? {
        switch self {
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: return nil
        }
    }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
}
