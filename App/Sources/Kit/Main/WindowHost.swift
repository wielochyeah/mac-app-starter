import AppKit
import SwiftUI

/// Opens SwiftUI content in AppKit windows (one per id), keeps the activation policy right
/// (`AppForm`) and releases each window's views when it closes (memory stays low while idle).
///
///     WindowHost.show(id: "settings", style: .settings, title: { CommonText.settings }) {
///         AnyView(SettingsRoot())
///     }
enum WindowHost {
    enum Style {
        /// Hub/settings: resizable, hidden title, transparent titlebar, unified empty toolbar
        /// (52 pt band with the traffic lights centred, VoiceBud hub).
        case settings
        /// Onboarding: fixed size, close button only, movable by background.
        case onboarding
        /// Main window: resizable, standard titlebar integration (the window module customises it).
        case main
    }

    private static var windows: [String: NSWindow] = [:]
    private static var delegates: [String: CloseObserver] = [:]

    static func window(_ id: String) -> NSWindow? { windows[id] }
    static var openIDs: Set<String> { Set(windows.keys) }

    /// Shows the window with this id, creating it (with `content`) when it is not open.
    /// `configure` runs once on a new window, before its saved frame is restored and it is shown.
    @discardableResult
    static func show(id: String, style: Style, size: CGSize? = nil, minSize: CGSize? = nil,
                     title: @escaping () -> String, configure: ((NSWindow) -> Void)? = nil,
                     content: () -> AnyView) -> NSWindow {
        if let existing = windows[id] {
            AppForm.windowWillShow(id)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return existing
        }
        let defaultSize = style == .onboarding ? Metrics.onboardingWindow : Metrics.settingsWindow
        let frameSize = size ?? defaultSize
        let mask: NSWindow.StyleMask = switch style {
        case .settings, .main: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        case .onboarding: [.titled, .closable, .fullSizeContentView]
        }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: frameSize), styleMask: mask, backing: .buffered, defer: false)
        let host = NSHostingController(rootView: content())
        host.sizingOptions = []
        window.contentViewController = host
        window.setContentSize(frameSize)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.title = title()
        switch style {
        case .settings:
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbar = NSToolbar(identifier: "\(id).toolbar")
            window.toolbarStyle = .unified
            window.minSize = minSize ?? Metrics.settingsWindowMin
        case .onboarding:
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        case .main:
            window.minSize = minSize ?? Metrics.settingsWindowMin
        }
        configure?(window)
        let autosave = "\(AppConfig.bundleId).\(id)"
        if style == .onboarding || !window.setFrameUsingName(autosave) { window.center() }
        if style != .onboarding { window.setFrameAutosaveName(autosave) }

        let observer = CloseObserver(id: id)
        window.delegate = observer
        windows[id] = window
        delegates[id] = observer
        // stops (and releases `title`) once this window is closed or replaced under the same id
        Observing.track { _ = title() } while: { [weak window] in
            window != nil && windows[id] === window
        } onChange: { [weak window] in
            window?.title = title()
        }

        AppForm.windowWillShow(id)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        return window
    }

    static func close(_ id: String) { windows[id]?.performClose(nil) }

    fileprivate static func didClose(_ id: String) {
        guard let window = windows.removeValue(forKey: id) else { return }
        delegates.removeValue(forKey: id)
        // the autosave name must be unique among live windows: give it up before a reopen
        window.setFrameAutosaveName("")
        DispatchQueue.main.async {
            window.contentViewController = nil
            window.delegate = nil
        }
        AppForm.windowDidClose(id)
    }

    private final class CloseObserver: NSObject, NSWindowDelegate {
        let id: String
        init(id: String) { self.id = id }
        func windowWillClose(_ notification: Notification) { WindowHost.didClose(id) }
    }
}
