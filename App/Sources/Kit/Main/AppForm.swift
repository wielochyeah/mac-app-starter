import AppKit

/// The app's form decides its activation policy:
/// - `window` module enabled: `.regular` (Dock icon, app menu).
/// - otherwise `.accessory` (menu bar / island / background app, `LSUIElement`), switching to
///   `.regular` while any kit window (settings, onboarding, …) is open, and back only when the
///   last of them closed (VoiceBud switched back while onboarding was still open; this counts).
/// - headless (`STARTER_HEADLESS=1`, renders, self-test): always `.prohibited`.
enum AppForm {
    private static var openWindows: Set<String> = []

    static var hasWindowModule: Bool { AppInfo.isEnabled("window") }

    /// Ids of kit windows currently shown (see `WindowHost`).
    static var visibleWindowIDs: Set<String> { openWindows }

    /// Pure policy rule (tested).
    static func policy(windowModule: Bool, headless: Bool, openWindows: Int) -> NSApplication.ActivationPolicy {
        if headless { return .prohibited }
        if windowModule { return .regular }
        return openWindows > 0 ? .regular : .accessory
    }

    static var currentPolicy: NSApplication.ActivationPolicy {
        policy(windowModule: hasWindowModule, headless: RenderMode.isHeadless, openWindows: openWindows.count)
    }

    static func applyActivationPolicy() {
        let wanted = currentPolicy
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
    }

    /// Call before ordering a window front. Accessory apps become regular so the window can be key.
    static func windowWillShow(_ id: String) {
        openWindows.insert(id)
        applyActivationPolicy()
    }

    /// Call when a window closed. The last one turns an accessory app back into an accessory app
    /// and hands activation back to the app the person came from.
    static func windowDidClose(_ id: String) {
        openWindows.remove(id)
        guard openWindows.isEmpty else { return }
        // during windowWillClose the closing window still counts as visible: wait a tick
        DispatchQueue.main.async {
            guard openWindows.isEmpty else { return }
            let wasRegular = NSApp.activationPolicy() == .regular
            applyActivationPolicy()
            if wasRegular && currentPolicy == .accessory { NSApp.hide(nil) }
        }
    }
}
