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
        let window = make(id: id, style: style, size: size, minSize: minSize, title: title(), configure: configure,
                          content: content)
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

    /// Builds a window without showing or registering it (`show` and the self-tests use it).
    /// A resizable window holds its minimum (`minSize`, default `Metrics.settingsWindowMin`) through
    /// its SwiftUI root, see `holdingMinimum`.
    static func make(id: String, style: Style, size: CGSize? = nil, minSize: CGSize? = nil, title: String,
                     configure: ((NSWindow) -> Void)? = nil, content: () -> AnyView) -> NSWindow {
        let defaultSize = style == .onboarding ? Metrics.onboardingWindow : Metrics.settingsWindow
        let frameSize = size ?? defaultSize
        let minimum: CGSize? = style == .onboarding ? nil : (minSize ?? Metrics.settingsWindowMin)
        let mask: NSWindow.StyleMask = switch style {
        case .settings, .main: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        case .onboarding: [.titled, .closable, .fullSizeContentView]
        }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: frameSize), styleMask: mask, backing: .buffered, defer: false)
        let band = ToolbarBand()
        let host = NSHostingController(rootView: minimum.map { holdingMinimum(content(), $0, band: band) } ?? content())
        host.sizingOptions = []
        window.contentViewController = host
        window.setContentSize(frameSize)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.title = title
        switch style {
        case .settings:
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbar = NSToolbar(identifier: "\(id).toolbar")
            window.toolbarStyle = .unified
        case .onboarding:
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        case .main:
            break
        }
        configure?(window)
        if minimum != nil {
            // The toolbar band above the SwiftUI content differs by window (main 52 pt, settings
            // 66 pt); it is known once the chrome is set up. The root reads it, so it is not rebuilt.
            band.height = window.frame.height - window.contentLayoutRect.height
            // A minimum already on the window is converted with the 32 pt title bar and then grows
            // by the toolbar (the main window ended at 900 x 620); cleared first, the hosting
            // controller lands exactly on the requested size.
            window.minSize = .zero
            window.contentMinSize = .zero
            host.sizingOptions = [.minSize]
        }
        return window
    }

    /// The SwiftUI root of a resizable window with a minimum. NSHostingController resets a plain
    /// `window.minSize` to zero on its first layout, so the root carries the minimum instead; the
    /// toolbar band sits above the SwiftUI content, so the content asks for that much less.
    private static func holdingMinimum(_ content: AnyView, _ minimum: CGSize, band: ToolbarBand) -> AnyView {
        AnyView(MinimumFrame(content: content, minimum: minimum, band: band))
    }

    @Observable fileprivate final class ToolbarBand {
        var height = Metrics.paneHeader
    }

    private struct MinimumFrame: View {
        let content: AnyView
        let minimum: CGSize
        let band: ToolbarBand

        var body: some View {
            // `maxWidth`/`maxHeight: .infinity` make this frame the minimum, not the split view's own
            content.frame(minWidth: minimum.width, maxWidth: .infinity,
                          minHeight: minimum.height - band.height, maxHeight: .infinity)
        }
    }

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
