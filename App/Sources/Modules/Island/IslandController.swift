import AppKit
import SwiftUI

/// The island: the public API and its lifecycle (VoiceBud IslandController, made generic).
///
///     Island.shared.present(.progress(title: IslandSampleText.exporting, fraction: 0.2))
///     Island.shared.update(.progress(title: IslandSampleText.exporting, fraction: 0.8))
///     Island.shared.update(.done(title: …, body: …))      // hides after the confirmation time
///     Island.shared.dismiss()
///
/// One panel, on the screen under the pointer when a take starts. Island or capsule is decided
/// once per take (`present`), never mid-way. Nothing runs while idle: the panel is ordered out,
/// and every timer (hover polling, self-heal, slow counter) exists only while something shows.
final class Island {
    static let shared = Island(deps: .live)

    /// The world the island talks to. `live` in the app; tests pass a manual clock, a fake panel
    /// and hand-made screens.
    struct Dependencies {
        var scheduler: IslandScheduling
        var makeHost: (IslandModel, @escaping () -> Void) -> IslandSurfaceHost
        var screens: () -> [IslandScreen]
        /// Pointer location in screen coordinates.
        var mouse: () -> CGPoint
        var prefs: () -> IslandPrefs
        var isFullscreen: (IslandScreenGeometry) -> Bool
        /// Nothing goes on screen (STARTER_HEADLESS, renders, tests); the pointer is virtual.
        var headless: Bool
        var playSound: (String) -> Void
        var haptic: () -> Void

        static var live: Dependencies {
            Dependencies(scheduler: MainScheduler(),
                         makeHost: { IslandPanelHost(model: $0, dismiss: $1) },
                         screens: { IslandScreen.all },
                         mouse: { NSEvent.mouseLocation },
                         prefs: { IslandPrefs.current },
                         isFullscreen: { IslandPanelHost.isFullscreen($0) },
                         headless: RenderMode.isHeadless || RenderMode.isStatic,
                         playSound: { IslandSound.play($0) },
                         haptic: { IslandHaptic.tick() })
        }
    }

    let model = IslandModel()
    /// Another notch app (or the app itself) occupies the notch right now: with style `auto`
    /// the next take shows as a capsule just below the notch. Default: nobody.
    var notchBusy: (() -> Bool)?

    private let deps: Dependencies
    private var host: IslandSurfaceHost!
    private var observers: [NSObjectProtocol] = []

    // Take state
    private var targetDisplay: UInt32?
    private var suppressed = false
    private var orderedIn = false
    private var shownBefore = false
    private var lastRebuild: Date?
    private var hiddenSince: Date?

    // Timers (each exists only while needed)
    private var presentTask: IslandTask?
    private var swapTask: IslandTask?
    private var fadeTask: IslandTask?
    private var orderOutTask: IslandTask?
    private var hideTask: IslandTask?
    private var hideDeadline: Date?
    private var slowTasks: [IslandTask] = []
    private var healTask: IslandTask?

    // Pointer on a card (hover to expand, Cancel)
    private var hoverTask: IslandTask?
    private var collapseTask: IslandTask?
    private var pointerInside = false
    private var parkedPointer: CGPoint?
    private var suspendedHide: Double?
    private var virtualPointerInside = false

    init(deps: Dependencies) {
        self.deps = deps
        host = deps.makeHost(model) { [weak self] in self?.dismiss() }
    }

    // MARK: Public API

    /// Shows `content` as a new take on the screen under the pointer. A surface that is still up
    /// on the same screen in the same form morphs into it instead of growing again.
    func present(_ content: IslandContent) {
        let previous = isShowing ? model.content : nil
        cancelTimers()
        guard let screen = IslandScreen.containing(deps.mouse(), in: deps.screens()) else { return }
        let geo = IslandScreenGeometry(screen)
        let prefs = deps.prefs()
        let busy = geo.notch != nil && (notchBusy?() ?? false)
        let kind = geo.kind(style: prefs.style, notchBusy: busy)
        let capsuleTop = geo.capsuleTop(style: prefs.style, notchBusy: busy)
        let reuse = model.presented && model.kind == kind && targetDisplay == geo.displayID && orderedIn

        suppressed = prefs.hideInFullscreen && deps.isFullscreen(geo)
        targetDisplay = geo.displayID
        let start = deps.scheduler.now
        let configure = { [model] in
            model.kind = kind
            model.capsuleTop = capsuleTop
            model.startedAt = start
            model.content = content.withoutBands
            model.bands = content.bands ?? []
            model.hover = .none
            model.acceptsClicks = false
            model.slowSince = nil
            model.slowHint = false
        }
        trace("present \(content.phase.rawValue) as \(kind.rawValue)\(reuse ? " (morph)" : "")")

        if reuse {
            // still on screen: the surface morphs into the new take, glyphs swap
            quietly { model.contentSwap = true }
            animate(configure)
            host.fade(to: 1, duration: IslandTiming.fadeIn)
            contentDidChange(from: previous)
            return
        }

        // Start collapsed in the notch (or as the capsule's seed) with the panel transparent,
        // grow on the next frame, fade the panel in: the first frame never shows.
        quietly {
            model.presented = false
            model.contentSwap = false
            model.notch = geo.drawnNotch
            configure()
        }
        orderIn(geo)
        if shownBefore {
            deps.scheduler.after(IslandTiming.verifyQuick) { [weak self] in self?.verifyOnScreen() }
        }
        shownBefore = !deps.headless && !suppressed
        presentTask = deps.scheduler.after(IslandTiming.presentDelay) { [weak self] in
            guard let self else { return }
            self.presentTask = nil
            self.animate { self.model.presented = true }
            self.host.fade(to: 1, duration: IslandTiming.fadeIn)
            // from now on the surface stays: later content changes swap instead of entering
            self.swapTask = self.deps.scheduler.after(IslandTiming.swapAfter) { [weak self] in
                guard let self, self.model.presented else { return }
                self.quietly { self.model.contentSwap = true }
            }
        }
        deps.scheduler.after(IslandTiming.verifyLate) { [weak self] in self?.verifyOnScreen() }
        if content.isRunning { deps.playSound("Tink") }
        contentDidChange(from: nil)
    }

    /// Changes what the island shows. On screen: in place (glyphs swap, the surface springs to
    /// the new size). Not on screen: like `present`.
    func update(_ content: IslandContent) {
        guard isShowing, let current = model.content else {
            present(content)
            return
        }
        // a live meter: only the bands changed, nothing re-renders
        if content.phase == .levels && content.withoutBands == current {
            model.bands = content.bands ?? []
            return
        }
        let phaseChanged = current.phase != content.phase
        if phaseChanged {
            hideTask?.cancel()
            hideTask = nil
            hideDeadline = nil
            stopPointerTracking()
            if content.phase != .progress { resetSlow() }
        }
        animate { [model] in
            model.content = content.withoutBands
            model.bands = content.bands ?? []
            if phaseChanged {
                model.hover = .none
                model.acceptsClicks = false
            }
        }
        if phaseChanged {
            contentDidChange(from: current)
        } else if (content.phase == .done || content.phase == .notice) && !hoverHolds {
            contentDidChange(from: current)
        } else {
            refreshPointerTracking()
        }
    }

    /// Shrinks the island back into the notch (or the capsule into its seed) and orders the
    /// panel out.
    func dismiss() { dismiss(quick: false) }

    /// Something is shown or on its way in (false once a dismiss started).
    var isPresenting: Bool { model.content != nil && orderOutTask == nil }

    /// Builds the panel ahead of the first use (the first take then does not pay for SwiftUI's
    /// first graph setup), and starts following screen and Reduce Motion changes.
    func start() {
        model.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard observers.isEmpty else { return }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.screensChanged() }
            })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.model.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                }
            })
        if !deps.headless {
            deps.scheduler.after(0) { [weak self] in self?.host.prepare() }
        }
    }

    func stop() {
        for o in observers {
            NotificationCenter.default.removeObserver(o)
            NSWorkspace.shared.notificationCenter.removeObserver(o)
        }
        observers = []
        cancelTimers()
        healTask?.cancel()
        healTask = nil
        host.orderOut()
        orderedIn = false
        resetModel()
    }

    /// Tests and headless runs: moves a virtual pointer onto or off the card.
    func testPointer(inside: Bool) {
        virtualPointerInside = inside
        pollPointer()
    }

    /// Settings changed while a card is up (hover switch, confirmation time).
    func settingsDidChange() {
        guard model.presented, model.phase == .done else { return }
        refreshPointerTracking()
        if !pointerTrackingWanted && model.hover == .expanded { animate { self.model.hover = .collapsed } }
        if hideTask != nil || !hoverHolds { scheduleHide(deps.prefs().confirmDelay) }
    }

    // MARK: Take lifecycle

    /// On screen or growing in (the 16 ms before the first frame), and not on its way out:
    /// content that arrives during a dismiss starts over.
    private var isShowing: Bool {
        (model.presented || presentTask != nil) && model.content != nil && orderedIn && orderOutTask == nil
    }

    /// The current content with its live bands.
    private var fullContent: IslandContent? {
        guard let c = model.content else { return nil }
        if case .levels(_, let symbol, let tint) = c { return .levels(model.bands, symbol: symbol, tint: tint) }
        return c
    }

    private func contentDidChange(from previous: IslandContent?) {
        guard let content = model.content else { return }
        switch content.phase {
        case .notice:
            scheduleHide(IslandTiming.noticeHide)
        case .done:
            if previous?.isRunning ?? false { deps.playSound("Pop") }
            scheduleHide(deps.prefs().confirmDelay)
        case .progress:
            if previous?.phase != .progress { startSlowTimers() }
        case .activity, .levels:
            break
        }
        refreshPointerTracking()
        updateHealTimer()
    }

    private func orderIn(_ geo: IslandScreenGeometry) {
        host.orderIn(frame: CGRect(origin: geo.panelOrigin(for: model.canvas), size: model.canvas),
                     front: !deps.headless && !suppressed)
        orderedIn = true
    }

    private func dismiss(quick: Bool) {
        hideTask?.cancel()
        hideTask = nil
        hideDeadline = nil
        presentTask?.cancel()
        presentTask = nil
        swapTask?.cancel()
        swapTask = nil
        stopPointerTracking()
        resetSlow()
        healTask?.cancel()
        healTask = nil
        guard model.presented || orderedIn else {
            resetModel()
            return
        }
        guard orderOutTask == nil else { return }
        trace("dismiss\(quick ? " (quick)" : "")")
        // glyphs leave with the leave transition, not the swap: that has to be on screen for one
        // frame before they are removed
        quietly { model.contentSwap = false }
        presentTask = deps.scheduler.after(IslandTiming.collapseDelay) { [weak self] in
            guard let self else { return }
            self.presentTask = nil
            self.animate { self.model.presented = false }
        }
        let fadeAt = quick ? IslandTiming.fadeAtQuick : IslandTiming.fadeAt
        fadeTask = deps.scheduler.after(fadeAt) { [weak self] in
            guard let self else { return }
            self.fadeTask = nil
            self.host.fade(to: 0, duration: IslandTiming.fadeOut)
        }
        orderOutTask = deps.scheduler.after(fadeAt + IslandTiming.orderOutAfterFade) { [weak self] in
            guard let self else { return }
            self.orderOutTask = nil
            self.host.orderOut()
            self.orderedIn = false
            self.resetModel()
        }
    }

    private func resetModel() {
        quietly {
            model.presented = false
            model.contentSwap = false
            model.content = nil
            model.hover = .none
            model.acceptsClicks = false
            model.slowSince = nil
            model.slowHint = false
        }
        model.cardFrame = .zero
        model.bands = []
    }

    private func scheduleHide(_ seconds: Double?) {
        hideTask?.cancel()
        hideTask = nil
        hideDeadline = nil
        guard let seconds else { return }
        hideDeadline = deps.scheduler.now.addingTimeInterval(seconds)
        hideTask = deps.scheduler.after(seconds) { [weak self] in
            guard let self else { return }
            self.hideTask = nil
            self.hideDeadline = nil
            self.dismiss(quick: false)
        }
    }

    private func cancelTimers() {
        for task in [hideTask, orderOutTask, fadeTask, presentTask, swapTask] { task?.cancel() }
        hideTask = nil
        hideDeadline = nil
        orderOutTask = nil
        fadeTask = nil
        presentTask = nil
        swapTask = nil
        stopPointerTracking()
        resetSlow()
    }

    // MARK: Progress that takes longer

    private func startSlowTimers() {
        resetSlow()
        let start = deps.scheduler.now
        let count = deps.scheduler.after(IslandTiming.slowCount) { [weak self] in
            guard let self, self.model.phase == .progress else { return }
            self.animate { self.model.slowSince = start }
        }
        let hint = deps.scheduler.after(IslandTiming.slowHint) { [weak self] in
            guard let self, self.model.phase == .progress else { return }
            self.animate { self.model.slowHint = true }
            self.refreshPointerTracking()
        }
        slowTasks = [count, hint]
    }

    private func resetSlow() {
        slowTasks.forEach { $0.cancel() }
        slowTasks = []
        if model.slowSince != nil || model.slowHint {
            quietly {
                model.slowSince = nil
                model.slowHint = false
            }
        }
    }

    // MARK: Pointer on a card (VoiceBud SPEC §0, decided 03.10.)

    /// The pointer keeps the card up: inside it, or within the grace after it left.
    private var hoverHolds: Bool { pointerInside || collapseTask != nil }

    /// A card the pointer can use: a done card that unfolds, or Cancel on a slow progress.
    private var pointerTrackingWanted: Bool {
        guard let content = model.content else { return false }
        switch content.phase {
        case .done: return deps.prefs().hoverExpand && content.canExpand
        case .progress: return model.slowHint && content.cancelAction != nil
        default: return false
        }
    }

    private func refreshPointerTracking() {
        if pointerTrackingWanted {
            startPointerTracking()
        } else if hoverTask != nil {
            stopPointerTracking()
        }
    }

    /// ~30 Hz pointer polling, only while such a card is up (no global event monitors: they need
    /// permissions; idle CPU stays 0).
    private func startPointerTracking() {
        guard hoverTask == nil, deps.headless || !suppressed else { return }
        pointerInside = false
        parkedPointer = deps.headless ? nil : deps.mouse()
        hoverTask = deps.scheduler.every(IslandTiming.hoverPoll, tolerance: IslandTiming.hoverTolerance) { [weak self] in
            self?.pollPointer()
        }
    }

    private func stopPointerTracking() {
        hoverTask?.cancel()
        hoverTask = nil
        collapseTask?.cancel()
        collapseTask = nil
        pointerInside = false
        parkedPointer = nil
        suspendedHide = nil
        virtualPointerInside = false
        host.setClickThrough(true)
        if model.acceptsClicks { model.acceptsClicks = false }
    }

    private func pollPointer() {
        guard hoverTask != nil, model.presented, model.phase == .done || model.phase == .progress else { return }
        let inside: Bool
        if deps.headless {
            inside = virtualPointerInside
        } else {
            guard orderedIn, !suppressed else { return }
            let mouse = deps.mouse()
            if let parked = parkedPointer {
                if abs(mouse.x - parked.x) < IslandTiming.parkedSlack && abs(mouse.y - parked.y) < IslandTiming.parkedSlack { return }
                parkedPointer = nil
            }
            inside = Self.pointer(mouse, isOn: model.cardFrame, panel: host.frame, notch: model.kind == .notch ? model.notch.height : nil,
                                  entering: !pointerInside)
        }
        guard inside != pointerInside else { return }
        pointerInside = inside
        if inside { pointerEntered() } else { pointerLeft() }
    }

    /// Is the pointer on the card? `card` is in canvas points (top-left origin) inside `panel`
    /// (screen points); 1 pt of slack so the very top screen row counts. Entering the notch
    /// island, the menu bar strip does not count: a pointer on its way to a status item next to
    /// the notch neither unfolds the card nor loses its click.
    static func pointer(_ mouse: CGPoint, isOn card: CGRect, panel: CGRect, notch: CGFloat?, entering: Bool) -> Bool {
        guard card.width > 1, card.height > 1 else { return false }
        var rect = CGRect(x: panel.minX + card.minX, y: panel.maxY - card.maxY, width: card.width, height: card.height)
            .insetBy(dx: -1, dy: -1)
        if entering, let notch {
            rect = rect.intersection(CGRect(x: rect.minX, y: rect.minY, width: rect.width,
                                            height: max(0, panel.maxY - notch - rect.minY)))
        }
        return rect.contains(mouse)
    }

    /// Pointer on the card: it takes clicks, the auto-hide stops with its remaining time kept,
    /// and a done card unfolds to the whole text.
    private func pointerEntered() {
        collapseTask?.cancel()
        collapseTask = nil
        host.setClickThrough(false)
        model.acceptsClicks = true
        if let task = hideTask {
            task.cancel()
            hideTask = nil
            suspendedHide = max(0, hideDeadline?.timeIntervalSince(deps.scheduler.now) ?? 0)
            hideDeadline = nil
        }
        if model.phase == .done, model.hover != .expanded, model.content?.canExpand ?? false {
            deps.haptic()
            animate { self.model.hover = .expanded }
        }
        trace("pointer -> enter (remaining \(suspendedHide.map { String(format: "%.2f s", $0) } ?? "none"))")
    }

    /// Pointer gone: click-through again at once; after 0.6 s the card folds back and hides
    /// after the remaining time, at least 0.8 s.
    private func pointerLeft() {
        host.setClickThrough(true)
        collapseTask?.cancel()
        collapseTask = deps.scheduler.after(IslandTiming.hoverGrace) { [weak self] in
            guard let self else { return }
            self.collapseTask = nil
            self.model.acceptsClicks = false
            if self.model.hover == .expanded { self.animate { self.model.hover = .collapsed } }
            if self.model.phase == .done {
                let hideIn = self.deps.prefs().confirmDelay.map { _ in max(self.suspendedHide ?? 0, IslandTiming.hoverMinRemaining) }
                self.suspendedHide = nil
                self.scheduleHide(hideIn)
            }
        }
        trace("pointer -> leave")
    }

    // MARK: Self-healing (VoiceBud 04.10.: a panel can lose its Spaces membership)

    private func updateHealTimer() {
        let needed = (model.content?.isRunning ?? false) && orderedIn && !deps.headless
        if needed && healTask == nil {
            healTask = deps.scheduler.every(IslandTiming.healInterval, tolerance: IslandTiming.healInterval / 4) { [weak self] in
                self?.ensureVisible()
            }
        } else if !needed, let task = healTask {
            task.cancel()
            healTask = nil
            hiddenSince = nil
        }
    }

    /// Running content is always on screen. Checked with the window server, not AppKit:
    /// `isVisible` stays true for a panel stuck on another Space. A gap under 0.4 s is the entry.
    private func ensureVisible() {
        guard let content = fullContent, content.isRunning, !deps.headless, !suppressed else {
            hiddenSince = nil
            return
        }
        if model.presented, orderedIn, host.isVisible, host.alpha > 0.5, orderOutTask == nil, host.isReallyOnScreen {
            hiddenSince = nil
            return
        }
        let now = deps.scheduler.now
        let since = hiddenSince ?? now
        hiddenSince = since
        guard now.timeIntervalSince(since) > IslandTiming.healGap else { return }
        hiddenSince = nil
        if host.isVisible && !host.isReallyOnScreen { rebuild("\(content.phase.rawValue) ordered in but not on screen") }
        present(content)
    }

    /// Shortly after a card appears: really on screen? (Never right after ordering in: the
    /// window server books a new or resized panel some 40 ms late.)
    private func verifyOnScreen() {
        guard !deps.headless, !suppressed, orderedIn, host.isVisible, model.presented, orderOutTask == nil,
              let content = fullContent, !host.isReallyOnScreen,
              lastRebuild.map({ deps.scheduler.now.timeIntervalSince($0) > IslandTiming.rebuildCooldown }) ?? true else { return }
        rebuild("\(content.phase.rawValue) ordered in but not on screen")
        present(content)
    }

    private func rebuild(_ why: String) {
        lastRebuild = deps.scheduler.now
        Log.warn("island: \(why)", "island")
        host.rebuild()
        orderedIn = false
        shownBefore = false
    }

    /// Displays or scaling changed: re-measure and re-place. A take whose display is gone (lid
    /// closed, monitor unplugged) or lost its notch moves to the screen under the pointer when
    /// running, else it is dismissed (never a fake notch on a screen without one).
    func screensChanged() {
        guard model.presented, let content = fullContent else { return }
        let screens = deps.screens()
        guard let screen = screens.first(where: { $0.displayID == targetDisplay }) else {
            content.isRunning ? present(content) : dismiss(quick: true)
            return
        }
        let geo = IslandScreenGeometry(screen)
        if geo.notch == nil && model.kind == .notch {
            content.isRunning ? present(content) : dismiss(quick: true)
            return
        }
        let prefs = deps.prefs()
        let busy = geo.notch != nil && (notchBusy?() ?? false)
        quietly {
            model.notch = geo.drawnNotch
            model.capsuleTop = geo.capsuleTop(style: prefs.style, notchBusy: busy)
        }
        host.move(to: geo.panelOrigin(for: model.canvas))
    }

    // MARK: Helpers

    /// Model changes without a global animation: each surface animates width and height with its
    /// own value-scoped spring. Reduce Motion: a 0.2 s cross-fade.
    private func animate(_ body: @escaping () -> Void) {
        if model.reduceMotion {
            withAnimation(Motion.Island.crossFade, body)
        } else {
            body()
        }
    }

    private func quietly(_ body: () -> Void) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet, body)
    }

    private func trace(_ message: String) {
        Log.debug("island: \(message)", "island")
    }
}
