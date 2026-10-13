import Foundation
import os

/// Logging through the unified log (Console.app, `log stream --predicate 'subsystem == "<bundleId>"'`).
/// Mirrors to stderr when `STARTER_LOG=stderr` (tests, renders, self-test).
///
/// Never log the person's content (texts, recordings, clipboard, file names and paths in their
/// home folder) at any level. Interpolated values are private: the log shows `<private>` unless
/// the Mac allows private data. Mark only technical values public (ids, counts, status codes, enum
/// names, fixed file names):
///
///     Log.info("mlx: worker started (pid \(public: pid))", "mlx")
///     Log.error("notes: opening failed: \(error)", "notes")   // the error may name a path: private
nonisolated enum Log {
    static func debug(_ message: @autoclosure () -> LogMessage, _ area: String = "app") { write(.debug, area, message()) }
    static func info(_ message: @autoclosure () -> LogMessage, _ area: String = "app") { write(.info, area, message()) }
    static func warn(_ message: @autoclosure () -> LogMessage, _ area: String = "app") { write(.default, area, message()) }
    static func error(_ message: @autoclosure () -> LogMessage, _ area: String = "app") { write(.error, area, message()) }

    private static let mirror = ProcessInfo.processInfo.environment["STARTER_LOG"] == "stderr"

    private static func write(_ level: OSLogType, _ area: String, _ message: LogMessage) {
        let logger = Logger(subsystem: AppConfig.bundleId, category: area)
        if message.hasPrivate {
            logger.log(level: level, "\(message.redacted, privacy: .public) | \(message.full, privacy: .private)")
        } else {
            logger.log(level: level, "\(message.redacted, privacy: .public)")
        }
        if mirror {
            let tag = switch level {
            case .debug: "debug"
            case .info: "info"
            case .error, .fault: "error"
            default: "warn"
            }
            FileHandle.standardError.write(Data("[\(area)] \(tag): \(message.full)\n".utf8))
        }
    }
}

/// One log line: the literal parts are public, every interpolated value is private unless written
/// `\(public: value)`.
nonisolated struct LogMessage: ExpressibleByStringInterpolation, Sendable {
    /// The line with each private value replaced by `<private>`: what the log always shows.
    fileprivate(set) var redacted: String
    /// The whole line (stderr mirror; private data in the log only where the Mac allows it).
    fileprivate(set) var full: String
    fileprivate(set) var hasPrivate = false

    init(stringLiteral value: String) {
        redacted = value
        full = value
    }

    init(stringInterpolation: StringInterpolation) { self = stringInterpolation.message }

    struct StringInterpolation: StringInterpolationProtocol {
        fileprivate var message = LogMessage(stringLiteral: "")

        init(literalCapacity: Int, interpolationCount: Int) {}

        mutating func appendLiteral(_ literal: String) {
            message.redacted += literal
            message.full += literal
        }

        mutating func appendInterpolation<T>(_ value: T) {
            message.redacted += "<private>"
            message.full += String(describing: value)
            message.hasPrivate = true
        }

        mutating func appendInterpolation<T>(public value: T) {
            let text = String(describing: value)
            message.redacted += text
            message.full += text
        }
    }
}
