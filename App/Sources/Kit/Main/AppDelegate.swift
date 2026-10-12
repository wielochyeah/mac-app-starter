import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Launch.noteLaunchEvent(NSAppleEventManager.shared().currentAppleEvent)
        AppForm.applyActivationPolicy()
        MainMenu.install()
        if !AppInfo.isAppBundle, let icon = AppInfo.icon() { NSApp.applicationIconImage = icon }
        for hook in Registry.launchHooks { hook() }
        guard !RenderMode.isHeadless else {
            Log.info("headless launch: no windows", "app")
            return
        }
        if Launch.isDemo {
            for driver in Registry.demoDrivers { driver() }
            return
        }
        if Launch.isBackground {
            Log.info("background launch: no windows", "app")
            return
        }
        if OnboardingKit.opensAtLaunch {
            AppActions.openOnboarding()
        } else if AppInfo.isEnabled("window") {
            AppActions.openMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows && !RenderMode.isHeadless { AppActions.openMainWindow() }
        return true
    }

    /// Menu bar, island and background forms keep running without windows.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        for hook in Registry.terminateHooks { hook() }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
