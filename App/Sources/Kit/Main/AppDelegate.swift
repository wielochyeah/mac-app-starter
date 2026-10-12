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
        openPrimaryWindow(mainWindow: AppInfo.isEnabled("window"))
    }

    /// What a launch or a Dock click shows: setup while it is unfinished (also after a background
    /// launch that skipped it), else the main window when the app has one.
    enum PrimaryWindow: Equatable { case onboarding, main, none }

    static func primaryWindow(setupDone: Bool, hasSetupSteps: Bool, mainWindow: Bool) -> PrimaryWindow {
        if !setupDone && hasSetupSteps { return .onboarding }
        return mainWindow ? .main : .none
    }

    private func openPrimaryWindow(mainWindow: Bool) {
        switch Self.primaryWindow(setupDone: Settings.shared[.onboardingDone],
                                  hasSetupSteps: !Registry.orderedOnboardingSteps.isEmpty, mainWindow: mainWindow) {
        case .onboarding: AppActions.openOnboarding()
        case .main: AppActions.openMainWindow()
        case .none: break
        }
    }

    /// macOS marks the open-application event of a login-item launch (keyAELaunchedAsLogInItem).
    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent, event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        // openMainWindow is a no-op without the window module, as before
        if !hasVisibleWindows && !RenderMode.isHeadless { openPrimaryWindow(mainWindow: true) }
        return true
    }

    /// Menu bar, island and background forms keep running without windows.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        for hook in Registry.terminateHooks { hook() }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
