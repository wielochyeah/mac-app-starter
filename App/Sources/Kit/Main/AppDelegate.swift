import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        if Launch.isBackground || launchedAsLoginItem {
            Launch.isBackground = true
            Log.info("background launch: no windows", "app")
            return
        }
        if !Settings.shared[.onboardingDone] && !Registry.orderedOnboardingSteps.isEmpty {
            AppActions.openOnboarding()
        } else if AppInfo.isEnabled("window") {
            AppActions.openMainWindow()
        }
    }

    /// macOS marks the open-application event of a login-item launch (keyAELaunchedAsLogInItem).
    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent, event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
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
