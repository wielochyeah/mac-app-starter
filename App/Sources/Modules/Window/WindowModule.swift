import SwiftUI

// The window module: Dock icon, main window in the style of Music on macOS 26 (native sidebar,
// toolbar search, content pages built from Components/), the standard menus of a window app.
//
// Launch: AppDelegate opens the main window (`AppActions.openMainWindow`) unless onboarding runs
// first, the app started with `--background` or as a login item, or it runs headless. When the
// first setup finishes, the main window opens (hook below). Dock click reopens it.

enum WindowModule {
    static func register() {
        Registry.pages.append(HomePage.page)
        AppActions.mainWindowHandler = { MainWindowController.show() }
        WindowMainMenu.install()
        WindowSidebarFooter.add(id: "window.local", order: 1000) {
            AnyView(SidebarStatusLine(text: CommonText.allLocal))
        }
        WindowCatalog.register()
        Registry.launchHooks.append(openWhenSetupFinishes)
    }

    /// Onboarding closes into the main window, so a window app never ends its first launch with
    /// nothing on screen.
    private static func openWhenSetupFinishes() {
        guard !RenderMode.isHeadless, !Settings.shared[.onboardingDone] else { return }
        var opened = false
        Observing.track({ _ = Settings.shared[.onboardingDone] }, while: { !opened }) {
            guard Settings.shared[.onboardingDone], !opened else { return }
            opened = true
            AppActions.openMainWindow()
        }
    }
}
