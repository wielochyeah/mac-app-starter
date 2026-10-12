import AppKit
import SwiftUI

/// What a panel section gets: `close()` hides the panel (call it before opening a window or after
/// an action that is done).
struct MenuBarPanelContext {
    let close: () -> Void
}

/// A block in the menu bar panel (a Control Center module): optional title above, the content in
/// one rounded tile. Contribute from your module's or feature's `register()`:
///
///     MenuBarPanel.sections.append(MenuBarSection(id: "sync", order: 10, title: { SyncText.title }) { panel in
///         AnyView(SyncTile(onOpen: { panel.close(); AppActions.openMainWindow() }))
///     })
///
/// Lower `order` sits higher. The panel lists `Registry.menuItems` below the sections as actions.
/// `tiled: false` leaves out the tile around the content (a row of `MenuBarToggle`s brings its own).
struct MenuBarSection: Identifiable {
    let id: String
    let order: Int
    let title: (() -> String)?
    let tiled: Bool
    let content: (MenuBarPanelContext) -> AnyView

    init(id: String, order: Int, title: (() -> String)? = nil, tiled: Bool = true,
         content: @escaping (MenuBarPanelContext) -> AnyView) {
        self.id = id
        self.order = order
        self.title = title
        self.tiled = tiled
        self.content = content
    }
}

/// The module-local registry of panel sections.
enum MenuBarPanel {
    static var sections: [MenuBarSection] = []

    static var orderedSections: [MenuBarSection] {
        sections.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }
}

// MARK: - Placement (pure, tested)

enum MenuBarPanelPlacement {
    /// The panel's frame: centred under the status item, `gap` below the menu bar, kept `margin`
    /// inside the screen's visible frame (screen coordinates, origin bottom left).
    static func frame(below item: NSRect, size: NSSize, visible: NSRect, gap: CGFloat = Space.xxs,
                      margin: CGFloat = Space.xs) -> NSRect {
        var x = (item.midX - size.width / 2).rounded()
        x = min(max(x, visible.minX + margin), visible.maxX - margin - size.width)
        let top = min(item.minY, visible.maxY) - gap
        return NSRect(x: x, y: (top - size.height).rounded(), width: size.width, height: size.height)
    }

    /// The panel's size from the content's fitting size: never narrower than the panel width.
    static func size(fitting: NSSize) -> NSSize {
        NSSize(width: max(fitting.width, MenuBarPanelMetrics.width).rounded(.up), height: fitting.height.rounded(.up))
    }

    /// The same frame with a new height, the top edge kept (content grew or shrank).
    static func resized(_ frame: NSRect, height: CGFloat) -> NSRect {
        NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height)
    }
}

// MARK: - Window

/// A borderless panel that can be key (text fields, Esc) without activating the app.
private final class MenuBarPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) { onCancel?() }
    var onCancel: (() -> Void)?
}

/// Shows the SwiftUI panel under the status item like a Control Center module: rounded glass,
/// fades in and out, closes on a click elsewhere, on Esc and on a second click on the item. The
/// SwiftUI tree is built on open and released on close (VoiceBud memory discipline).
final class MenuBarPanelController: NSObject, NSWindowDelegate {
    private var panel: MenuBarPanelWindow?
    private var monitors: [Any] = []
    private weak var button: NSStatusBarButton?
    /// Set when the panel closed through the status item's own mouse-down, so the click that
    /// follows does not reopen it.
    private var closedAt: Date?

    var isOpen: Bool { panel != nil }

    func toggle(from button: NSStatusBarButton) {
        if isOpen {
            close()
        } else if closedAt.map({ Date().timeIntervalSince($0) < MenuBarPanelMetrics.reopenGuard }) != true {
            // the click on the item itself may first take the key status away from the panel and
            // close it there; that same click must not reopen it
            open(from: button)
        }
    }

    func open(from button: NSStatusBarButton) {
        guard panel == nil, !RenderMode.isHeadless, let itemWindow = button.window,
              let screen = itemWindow.screen ?? NSScreen.main else { return }
        self.button = button
        let item = itemWindow.convertToScreen(button.convert(button.bounds, to: nil))

        let window = MenuBarPanelWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                        backing: .buffered, defer: true)
        window.isFloatingPanel = true
        window.level = .popUpMenu
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        window.animationBehavior = .none
        window.delegate = self
        window.onCancel = { [weak self] in self?.close() }

        let root = MenuBarPanelView(close: { [weak self] in self?.close() }) { [weak self] height in
            self?.fit(height: height)
        }
        let (host, size) = Self.host(root)
        window.contentView = host
        window.setFrame(MenuBarPanelPlacement.frame(below: item, size: size, visible: screen.visibleFrame), display: false)
        panel = window

        window.alphaValue = 0
        window.orderFrontRegardless()
        window.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = MenuBarPanelMetrics.fadeIn
            window.animator().alphaValue = 1
        }
        button.highlight(true)
        installMonitors()
    }

    func close() {
        guard let window = panel else { return }
        panel = nil
        closedAt = Date()
        removeMonitors()
        button?.highlight(false)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = MenuBarPanelMetrics.fadeOut
            window.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                window.orderOut(nil)
                window.contentView = nil
                window.delegate = nil
                // closed windows give their memory back (VoiceBud hub: ~50 MB stayed without this)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { malloc_zone_pressure_relief(nil, 0) }
            }
        })
    }

    /// The hosting view and the panel's first size. The size is measured while the hosting view
    /// still sizes itself; only then are its own size constraints switched off (the panel follows
    /// the content's height through `fit`). Measuring after `sizingOptions = []` gives 0 x 0, a
    /// panel nobody sees (review 12.10.). The width never drops below the panel's width.
    static func host<Root: View>(_ root: Root) -> (NSHostingView<Root>, NSSize) {
        let host = NSHostingView(rootView: root)
        let fitting = host.fittingSize
        host.sizingOptions = []
        return (host, MenuBarPanelPlacement.size(fitting: fitting))
    }

    /// The content changed height: keep the top edge under the menu bar.
    private func fit(height: CGFloat) {
        guard let window = panel, abs(window.frame.height - height) >= 0.5 else { return }
        window.setFrame(MenuBarPanelPlacement.resized(window.frame, height: height), display: true)
    }

    private func installMonitors() {
        // a click in another app or on the desktop (global monitors need no permission for mouse events)
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            self?.close()
        }) {
            monitors.append(global)
        }
        // a click into one of our other windows
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            if let self, let panel = self.panel, event.window !== panel, event.window !== self.button?.window {
                self.close()
            }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func removeMonitors() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
    }

    func windowDidResignKey(_ notification: Notification) {
        // another window took the keyboard (Settings opened from the panel, a click elsewhere)
        close()
    }
}

/// Sizes and timings of the panel. Candidates for Kit/Design (Control Center-like surfaces).
enum MenuBarPanelMetrics {
    /// Control Center modules are 320–360 pt wide.
    static let width: CGFloat = 340
    static let appIcon: CGFloat = 32
    static let toggleCircle: CGFloat = 28
    /// Fades of the AppKit panel. `Motion.fade` is a SwiftUI `Animation` and `NSAnimationContext`
    /// needs seconds; fade in matches its 0.12 s. Kit candidate: `Motion.panelFadeIn/Out`.
    static let fadeIn: TimeInterval = 0.12
    static let fadeOut: TimeInterval = 0.16
    /// A click on the item within this time after the panel closed does not reopen it.
    static let reopenGuard: TimeInterval = 0.3
}
