#if TESTING
import AppKit

final class BackgroundLaunchTests: TestSuite {
    override class func register() {
        test("--background is a known flag and sets background") {
            let flags = LaunchFlags.parse(["app", "--background"])
            expect(flags.errors.isEmpty, "\(flags.errors)")
            expect(flags.background)
            expect(!flags.isTool)
            expect(!LaunchFlags.parse(["app"]).background)
        }

        test("launch and Dock click resume unfinished setup before the main window") {
            expectEqual(AppDelegate.primaryWindow(setupDone: false, hasSetupSteps: true, mainWindow: true), .onboarding)
            expectEqual(AppDelegate.primaryWindow(setupDone: false, hasSetupSteps: false, mainWindow: true), .main)
            expectEqual(AppDelegate.primaryWindow(setupDone: true, hasSetupSteps: true, mainWindow: true), .main)
            expectEqual(AppDelegate.primaryWindow(setupDone: true, hasSetupSteps: true, mainWindow: false), AppDelegate.PrimaryWindow.none)
        }

        test("menu decorators run on every rebuild") {
            var calls = 0
            MainMenu.decorators.append { _ in calls += 1 }
            defer { MainMenu.decorators.removeLast(); MainMenu.rebuild() }
            MainMenu.rebuild()
            MainMenu.rebuild()
            expectEqual(calls, 2)
        }
    }
}
#endif
