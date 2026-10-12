import AppKit
import SwiftUI

/// Opens and closes the settings window (VoiceBud HubController, notes vb-onboarding-hub §3.1).
///
/// `WindowHost` builds the window (900 x 620, min 760 x 500, empty unified toolbar for the 52 pt
/// band, frame autosave that gives up its name on close, views released on close, accessory ↔
/// regular through `AppForm`). On top of that this controller
/// - selects the requested pane (`AppActions.openSettings(pane:)`),
/// - routes ⌘W / ⌘F / ⌘, and the editing keys while the window is key (an accessory app may run
///   without a main menu; with one, the menu handles everything except ⌘F),
/// - hands focus back to the app that was in front when an accessory app's window closes,
/// - returns freed memory to the system half a second after closing.
enum SettingsController {
    static let windowID = "settings"

    private static var keyMonitor: Any?
    private static var closeObserver: NSObjectProtocol?
    private static var previousApp: NSRunningApplication?

    static var isOpen: Bool { WindowHost.window(windowID) != nil }

    static func show(pane: String?) {
        let hub = SettingsHub.shared
        hub.select(pane)
        guard !RenderMode.isHeadless else { return }
        let wasOpen = isOpen
        if !wasOpen, let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }
        let window = WindowHost.show(id: windowID, style: .settings, title: { CommonText.settings }) {
            AnyView(SettingsRootView(hub: hub))
        }
        window.orderFrontRegardless()
        guard !wasOpen else { return }
        installKeyMonitor(for: window)
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                                               queue: .main) { _ in
            MainActor.assumeIsolated { didClose() }
        }
    }

    static func close() { WindowHost.close(windowID) }

    private static func didClose() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        handBackActivation()
        // hand the released views' memory back (VoiceBud: the idle app stayed ~20 MB higher without)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { malloc_zone_pressure_relief(nil, 0) }
    }

    /// An accessory app without windows must not stay the active app: the person's next keystroke
    /// would go nowhere. Re-activate whoever was in front before Settings opened.
    private static func handBackActivation() {
        let previous = previousApp
        previousApp = nil
        guard !AppForm.hasWindowModule, AppForm.visibleWindowIDs.subtracting([windowID]).isEmpty,
              NSApp.isActive, let previous, !previous.isTerminated else { return }
        NSApp.yieldActivation(to: previous)
        previous.activate(from: NSRunningApplication.current, options: [])
    }

    private static func installKeyMonitor(for window: NSWindow) {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window] event in
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let number = event.windowNumber
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let window, window.windowNumber == number else { return false }
                let hasMenu = !(NSApp.mainMenu?.items.isEmpty ?? true)
                guard let action = SettingsKeys.action(key: key, flags: flags, hasMainMenu: hasMenu) else { return false }
                return perform(action, in: window)
            }
            return handled ? nil : event
        }
    }

    private static func perform(_ action: SettingsKeys.Action, in window: NSWindow) -> Bool {
        switch action {
        case .close:
            window.performClose(nil)
            return true
        case .search:
            SettingsHub.shared.requestSearch()
            return true
        case .settings:
            return true   // already open and key
        case .edit(let selector):
            return NSApp.sendAction(selector, to: nil, from: window)
        }
    }
}

/// Which keys the settings window handles itself (pure, tested).
enum SettingsKeys {
    enum Action: Equatable {
        case close, search, settings
        case edit(Selector)
    }

    /// ⌘ alone only. ⌘F always (no menu item searches a pane); the rest only without a main menu,
    /// where nothing else would handle them.
    static func action(key: String, flags: NSEvent.ModifierFlags, hasMainMenu: Bool) -> Action? {
        guard flags.intersection([.command, .shift, .option, .control]) == .command else { return nil }
        if key == "f" { return .search }
        guard !hasMainMenu else { return nil }
        switch key {
        case "w": return .close
        case ",": return .settings
        case "x": return .edit(#selector(NSText.cut(_:)))
        case "c": return .edit(#selector(NSText.copy(_:)))
        case "v": return .edit(#selector(NSText.paste(_:)))
        case "a": return .edit(#selector(NSText.selectAll(_:)))
        case "z": return .edit(Selector(("undo:")))
        default: return nil
        }
    }
}
