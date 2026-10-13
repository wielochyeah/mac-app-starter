import AppKit
import SwiftUI

/// Borderless, non-activating, click-through panel above the menu bar (VoiceBud IslandPanel,
/// notes §3). The shape animates inside it; the panel itself never resizes or animates.
final class IslandPanel: NSPanel {
    /// Above the status bar (25 + 8), below what macOS keeps for itself.
    static let levelAboveStatusBar = 8

    init(size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + Self.levelAboveStatusBar)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false               // shadows are drawn in SwiftUI
        ignoresMouseEvents = true       // click-through until the pointer rests on a card
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .none
        // NSApp.hide (e.g. when a settings window closes) must never hide a running island
        canHide = false
        // screen recordings show the island
        sharingType = .readOnly
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // the panel deliberately covers the menu bar and the notch
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// The panel never becomes key, so the first click on a hovered card (Copy, an action) must
/// reach SwiftUI directly instead of activating the window.
final class IslandHostingView: NSHostingView<IslandView> {
    required init(rootView: IslandView) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("IslandHostingView is created in code only")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// What the controller needs from the window (a fake in tests).
protocol IslandSurfaceHost: AnyObject {
    /// AppKit's view: ordered in.
    var isVisible: Bool { get }
    /// The window server's view (a panel that lost its Spaces membership is "visible" but not on screen).
    var isReallyOnScreen: Bool { get }
    var frame: CGRect { get }
    var alpha: CGFloat { get }
    /// Builds the (ordered-out) panel ahead of the first use.
    func prepare()
    /// Places the panel at `frame` with alpha 0; orders it front when `front`.
    func orderIn(frame: CGRect, front: Bool)
    func fade(to alpha: CGFloat, duration: Double)
    /// Orders out and resets alpha to 1.
    func orderOut()
    func move(to origin: CGPoint)
    func setClickThrough(_ on: Bool)
    /// Drops the panel; the next `orderIn` builds a fresh one (which joins every Space again).
    func rebuild()
}

/// The real host: one `IslandPanel` with the SwiftUI island in it.
final class IslandPanelHost: IslandSurfaceHost {
    private let model: IslandModel
    private let dismiss: () -> Void
    private var panel: IslandPanel?

    init(model: IslandModel, dismiss: @escaping () -> Void) {
        self.model = model
        self.dismiss = dismiss
    }

    var isVisible: Bool { panel?.isVisible ?? false }
    var frame: CGRect { panel?.frame ?? .zero }
    var alpha: CGFloat { panel?.alphaValue ?? 0 }

    var isReallyOnScreen: Bool {
        guard let panel, panel.windowNumber > 0 else { return false }
        let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(panel.windowNumber)) as? [[String: Any]]
        return (info?.first?[kCGWindowIsOnscreen as String] as? Bool) ?? false
    }

    func prepare() { _ = ensure() }

    private func ensure() -> IslandPanel {
        if let panel { return panel }
        let p = IslandPanel(size: model.canvas)
        let host = IslandHostingView(rootView: IslandView(model: model, dismiss: dismiss))
        host.sizingOptions = []
        host.frame = CGRect(origin: .zero, size: model.canvas)
        host.autoresizingMask = [.width, .height]
        p.contentView = host
        panel = p
        return p
    }

    func orderIn(frame: CGRect, front: Bool) {
        let p = ensure()
        p.setFrame(frame, display: false)
        p.alphaValue = 0
        if front { p.orderFrontRegardless() }
    }

    func fade(to alpha: CGFloat, duration: Double) {
        guard let panel, panel.alphaValue != alpha else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: alpha > 0 ? .easeOut : .easeIn)
            panel.animator().alphaValue = alpha
        }
    }

    func orderOut() {
        panel?.orderOut(nil)
        panel?.alphaValue = 1
    }

    func move(to origin: CGPoint) { panel?.setFrameOrigin(origin) }

    func setClickThrough(_ on: Bool) { panel?.ignoresMouseEvents = on }

    func rebuild() {
        if let panel {
            Log.warn("island: panel rebuilt (behavior \(public: panel.collectionBehavior.rawValue), level \(public: panel.level.rawValue))", "island")
        }
        panel?.orderOut(nil)
        panel = nil
    }

    /// Frontmost app has an on-screen window covering the screen (CGWindowList bounds need no
    /// permission; CG coordinates start top-left of the primary screen). On notched screens
    /// native full screen windows start below the camera housing; that shape only counts when the
    /// menu bar band and the housing band differ (32 vs 33 pt on a 14" MacBook Pro), so a
    /// maximised window is never taken for full screen. VoiceBud isFullscreen.
    static func isFullscreen(_ geo: IslandScreenGeometry) -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? geo.frame.height
        let target = CGRect(x: geo.frame.minX, y: primaryHeight - geo.frame.maxY, width: geo.frame.width, height: geo.frame.height)
        let housingCheck = geo.safeTop > 0 && abs(geo.menuBarHeight - geo.safeTop) >= 0.5
        for info in list {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary) else { continue }
            guard abs(bounds.minX - target.minX) < 2, abs(bounds.width - target.width) < 2,
                  abs(bounds.maxY - target.maxY) < 1 else { continue }
            let top = bounds.minY - target.minY
            if abs(top) < 1 { return true }
            if housingCheck && abs(top - geo.safeTop) < 0.5 { return true }
        }
        return false
    }
}

// MARK: - Scheduling (injectable clock for tests)

/// A cancellable piece of scheduled work. Only touched on the main thread.
final class IslandTask: @unchecked Sendable {
    private var onCancel: (() -> Void)?
    private(set) var isCancelled = false

    init(onCancel: (() -> Void)? = nil) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        onCancel?()
        onCancel = nil
    }
}

/// The island's clock: one-shot and repeating work on the main thread. `MainScheduler` in the
/// app; tests advance a manual clock.
protocol IslandScheduling: AnyObject {
    var now: Date { get }
    @discardableResult func after(_ seconds: Double, _ work: @escaping () -> Void) -> IslandTask
    func every(_ seconds: Double, tolerance: Double, _ work: @escaping () -> Void) -> IslandTask
}

private final class IslandWork: @unchecked Sendable {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}

final class MainScheduler: IslandScheduling {
    var now: Date { Date() }

    @discardableResult func after(_ seconds: Double, _ work: @escaping () -> Void) -> IslandTask {
        let task = IslandTask()
        let box = IslandWork(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            MainActor.assumeIsolated {
                guard !task.isCancelled else { return }
                box.run()
            }
        }
        return task
    }

    func every(_ seconds: Double, tolerance: Double, _ work: @escaping () -> Void) -> IslandTask {
        let box = IslandWork(work)
        let timer = Timer(timeInterval: seconds, repeats: true) { _ in
            MainActor.assumeIsolated { box.run() }
        }
        timer.tolerance = tolerance
        // .common: keeps running while a menu is open or something is dragged
        RunLoop.main.add(timer, forMode: .common)
        let t = IslandWork { timer.invalidate() }
        return IslandTask { t.run() }
    }
}
