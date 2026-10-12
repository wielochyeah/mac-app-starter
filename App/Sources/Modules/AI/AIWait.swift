import Foundation

/// Runs async work to the end from synchronous code on the main thread (self-tests, the test
/// harness) by spinning the main run loop, so main-actor continuations keep running. Never use it
/// from UI code.
enum AIWait {
    enum Outcome<T> {
        case value(T)
        case failure(Error)
        case timedOut
    }

    static func run<T>(timeout: TimeInterval, _ work: @escaping @MainActor () async throws -> T) -> Outcome<T> {
        var outcome: Outcome<T>?
        let task = Task { @MainActor in
            do { outcome = .value(try await work()) } catch { outcome = .failure(error) }
        }
        let deadline = Date().addingTimeInterval(timeout)
        while outcome == nil && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        if outcome == nil {
            task.cancel()
            // give the cancellation a moment to unwind (a provider sends its own cancel)
            let grace = Date().addingTimeInterval(1)
            while outcome == nil && Date() < grace { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
            return .timedOut
        }
        return outcome!
    }

    /// Spins the main run loop until `condition` is true or the time is up; returns the condition.
    @discardableResult
    static func until(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        return condition()
    }
}
