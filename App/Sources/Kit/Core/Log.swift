import Foundation
import os

/// Logging through the unified log (Console.app, `log stream --predicate 'subsystem == "<bundleId>"'`).
/// Mirrors to stderr when `STARTER_LOG=stderr` (tests, renders, self-test).
/// Never log user content at `.info` or above; use `debug` for that (it is not persisted).
nonisolated enum Log {
    static func debug(_ message: @autoclosure () -> String, _ area: String = "app") { write(.debug, area, message()) }
    static func info(_ message: @autoclosure () -> String, _ area: String = "app") { write(.info, area, message()) }
    static func warn(_ message: @autoclosure () -> String, _ area: String = "app") { write(.default, area, message()) }
    static func error(_ message: @autoclosure () -> String, _ area: String = "app") { write(.error, area, message()) }

    private static let mirror = ProcessInfo.processInfo.environment["STARTER_LOG"] == "stderr"

    private static func write(_ level: OSLogType, _ area: String, _ message: String) {
        Logger(subsystem: AppConfig.bundleId, category: area).log(level: level, "\(message, privacy: .public)")
        if mirror {
            let tag = switch level {
            case .debug: "debug"
            case .info: "info"
            case .error, .fault: "error"
            default: "warn"
            }
            FileHandle.standardError.write(Data("[\(area)] \(tag): \(message)\n".utf8))
        }
    }
}
