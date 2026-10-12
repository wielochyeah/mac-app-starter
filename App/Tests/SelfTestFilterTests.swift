#if TESTING
import AppKit

/// `--selftest <prefix>` and on-demand checks (Kit/Main/SelfTest.swift).
final class SelfTestFilterTests: TestSuite {
    override class func register() {
        test("--selftest takes an optional prefix") {
            expectEqual(LaunchFlags.parse(["app", "--selftest"]).selftestOnly, nil)
            let named = LaunchFlags.parse(["app", "--selftest", "ai"])
            expect(named.selftest)
            expectEqual(named.selftestOnly, "ai")
            expect(named.errors.isEmpty)
            // a following flag is not a prefix
            let flagged = LaunchFlags.parse(["app", "--selftest", "--demo"])
            expectEqual(flagged.selftestOnly, nil)
            expect(!flagged.errors.isEmpty)
        }

        test("on-demand checks run only when named") {
            Registry.withScratch {
                var ran: [String] = []
                Registry.selfTests = [
                    SelfTestCheck(id: "x.cheap") { ran.append("x.cheap"); return nil },
                    SelfTestCheck(id: "x.live", onDemand: true) { ran.append("x.live"); return nil },
                    SelfTestCheck(id: "y.other") { ran.append("y.other"); return nil },
                ]
                expectEqual(SelfTestRunner.run(), 0)
                expectEqual(ran, ["x.cheap", "y.other"])
                ran = []
                expectEqual(SelfTestRunner.run(only: "x."), 0)
                expectEqual(ran, ["x.cheap", "x.live"])
                expectEqual(SelfTestRunner.run(only: "nothing"), 1, "an unknown prefix fails")
            }
        }
    }
}
#endif
