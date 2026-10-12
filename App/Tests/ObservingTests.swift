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
    /// Lets the main-actor tasks that Observation schedules run.
    static func spin() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }

    override class func register() {
        test("track calls onChange on every change") {
            let counter = Counter()
            var calls = 0
            Observing.track { _ = counter.value } onChange: { calls += 1 }
            counter.value = 1
            spin()
            counter.value = 2
            spin()
            expectEqual(calls, 2)
        }

        test("track stops once while returns false") {
            let counter = Counter()
            let active = Flag()
            var calls = 0
            Observing.track { _ = counter.value } while: { active.on } onChange: { calls += 1 }
            counter.value = 1
            spin()
            expectEqual(calls, 1)
            active.on = false
            counter.value = 2
            spin()
            active.on = true   // a stopped tracker never resumes
            counter.value = 3
            spin()
            expectEqual(calls, 1)
        }
    }
}
#endif
