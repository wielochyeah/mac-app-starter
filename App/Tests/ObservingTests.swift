#if TESTING
import Foundation
import Observation

@Observable private final class Counter {
    var value = 0
}

private final class Flag {
    var on = true
}

final class ObservingTests: TestSuite {
    /// Lets the main-actor tasks that Observation schedules run until `done` holds. Waits for the
    /// condition (up to `timeout`) instead of a fixed time: under load (render tests, parallel
    /// builds) the main actor can be busy for longer than any short fixed wait.
    static func spin(until done: () -> Bool, timeout: TimeInterval = 5) {
        let end = Date().addingTimeInterval(timeout)
        while !done() && Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    }

    /// For checks that nothing happens: gives pending main-actor tasks time to run.
    static func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.2)) }

    override class func register() {
        test("track calls onChange on every change") {
            let counter = Counter()
            var calls = 0
            Observing.track { _ = counter.value } onChange: { calls += 1 }
            counter.value = 1
            spin { calls == 1 }
            counter.value = 2
            spin { calls == 2 }
            settle()
            expectEqual(calls, 2)
        }

        test("track stops once while returns false") {
            let counter = Counter()
            let active = Flag()
            var calls = 0
            Observing.track { _ = counter.value } while: { active.on } onChange: { calls += 1 }
            counter.value = 1
            spin { calls == 1 }
            expectEqual(calls, 1)
            active.on = false
            counter.value = 2
            settle()
            active.on = true   // a stopped tracker never resumes
            counter.value = 3
            settle()
            expectEqual(calls, 1)
        }
    }
}
#endif
