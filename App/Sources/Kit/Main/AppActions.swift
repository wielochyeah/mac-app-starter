import AppKit

/// App-wide actions. Kit areas and modules install the handlers at registration
/// (e.g. `AppActions.settingsHandler = { pane in SettingsController.show(pane: pane) }`); callers only
/// use the static functions, so a module can be removed without breaking its callers.
enum AppActions {
    /// Opens the settings window, optionally at a pane id. Installed by Kit/Settings.
    static var settingsHandler: ((String?) -> Void)?
    /// Opens the onboarding window. Installed by Kit/Onboarding.
    static var onboardingHandler: (() -> Void)?
    /// Opens (or focuses) the main window, at a page id when one is given. Installed by the window
    /// module.
    static var mainWindowHandler: ((String?) -> Void)?

    static func openSettings(pane: String? = nil) {
        guard !RenderMode.isHeadless || settingsHandler != nil else { return }
        if let settingsHandler { settingsHandler(pane) } else { Log.warn("openSettings: no settings handler", "app") }
    }

    static func openOnboarding() {
        if let onboardingHandler { onboardingHandler() } else { Log.warn("openOnboarding: no onboarding handler", "app") }
    }

    /// Opens the main window, with `page` (an `AppPage` id) selected when given. Without a window
    /// module this opens Settings (the app's only window) and the page is ignored.
    static func openMainWindow(page: String? = nil) {
        if let mainWindowHandler { mainWindowHandler(page) } else { openSettings() }
    }

    static func showAbout() { openSettings(pane: "about") }

    static func quit() { NSApp.terminate(nil) }
}
