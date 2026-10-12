import SwiftUI

/// The notch island / capsule module (`MODUL_ISLAND`). Public API: `Island.shared`
/// (`present`, `update`, `dismiss`, `isPresenting`, `notchBusy`). Contributes the settings pane
/// "Island & Capsule", the onboarding step of the same name (only on Macs with a notch), render
/// scenes, gallery entries, a `--demo` loop and self-tests.
enum IslandModule {
    static func register() {
        Registry.settingsPanes.append(SettingsPane(id: "island", group: .settings, order: 200, title: { IslandText.pane },
                                                   symbol: IslandPane.symbol, tint: .black) { AnyView(IslandPane()) })
        // without a notch both choices show the capsule: the question would change nothing
        Registry.onboardingSteps.append(OnboardingStep(id: "island.appearance", order: 500,
                                                       isIncluded: { IslandScreen.all.contains { IslandScreenGeometry($0).notch != nil } }) { _ in
            AnyView(IslandOnboardingStep())
        })
        Registry.launchHooks.append { Island.shared.start() }
        Registry.terminateHooks.append {
            IslandDemo.stop()
            Island.shared.stop()
        }
        Registry.demoDrivers.append {
            if IslandDemo.wanted() { IslandDemo.play(loop: true) }
        }
        IslandScenes.register()
        registerSelfTests()
    }

    /// A 14" MacBook Pro: notch 185 × 32 between two menu bar halves of 663.5 pt.
    private static let referenceScreen = IslandScreen(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                                      visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949), safeTop: 32,
                                                      auxLeftWidth: 663.5, auxRightWidth: 663.5, displayID: 1)

    private static func registerSelfTests() {
        Registry.selfTests.append(SelfTestCheck(id: "island.geometry") {
            // the measurement itself, on a known screen
            let ref = IslandScreenGeometry(referenceScreen)
            guard ref.notch == CGSize(width: 185, height: 32), ref.notchMidX == 756, ref.menuBarHeight == 33 else {
                return "reference MacBook: notch \(String(describing: ref.notch)) at \(ref.notchMidX), menu bar \(ref.menuBarHeight)"
            }
            // the machine's screens: a camera housing is found as a notch narrower than the screen,
            // centred inside it, and the panel stays on the screen
            for screen in IslandScreen.all {
                let geo = IslandScreenGeometry(screen)
                let name = "screen \(screen.displayID.map(String.init) ?? "?")"
                if screen.safeTop > 0 {
                    guard let notch = geo.notch, notch.width < screen.frame.width / 2, notch.height == screen.safeTop else {
                        return "\(name): safe area \(screen.safeTop) but notch \(String(describing: geo.notch))"
                    }
                }
                guard geo.notchMidX > screen.frame.minX, geo.notchMidX < screen.frame.maxX else {
                    return "\(name): notch centre \(geo.notchMidX) outside \(screen.frame)"
                }
                guard geo.menuBarHeight > 0, geo.menuBarHeight < screen.frame.height / 4 else {
                    return "\(name): menu bar \(geo.menuBarHeight)"
                }
            }
            return nil
        })
        // the real controller with a real panel, headless: content shows in the model, the
        // panel is never asked to come to the front, everything is gone after stop()
        Registry.selfTests.append(SelfTestCheck(id: "island.headless") {
            var deps = Island.Dependencies.live
            deps.headless = true
            var fronts: [Bool] = []
            let live = deps.makeHost
            deps.makeHost = { model, dismiss in
                RecordingIslandHost(live(model, dismiss)) { fronts.append($0) }
            }
            deps.screens = { [referenceScreen] }
            deps.mouse = { CGPoint(x: referenceScreen.frame.midX, y: referenceScreen.frame.midY) }
            let island = Island(deps: deps)
            defer { island.stop() }
            island.present(.notice(text: IslandSampleText.noticeInfo))
            guard island.isPresenting, island.model.phase == .notice else { return "present did not set the content" }
            guard !fronts.isEmpty else { return "the panel was never ordered in" }
            guard !fronts.contains(true) else { return "the panel was ordered to the front" }
            island.stop()
            return island.isPresenting ? "stop left content behind" : nil
        })
    }
}

/// Wraps a host and reports every `orderIn`'s `front` flag (self-test).
private final class RecordingIslandHost: IslandSurfaceHost {
    private let inner: IslandSurfaceHost
    private let record: (Bool) -> Void

    init(_ inner: IslandSurfaceHost, record: @escaping (Bool) -> Void) {
        self.inner = inner
        self.record = record
    }

    var isVisible: Bool { inner.isVisible }
    var isReallyOnScreen: Bool { inner.isReallyOnScreen }
    var frame: CGRect { inner.frame }
    var alpha: CGFloat { inner.alpha }
    func prepare() { inner.prepare() }
    func orderIn(frame: CGRect, front: Bool) {
        record(front)
        inner.orderIn(frame: frame, front: front)
    }
    func fade(to alpha: CGFloat, duration: Double) { inner.fade(to: alpha, duration: duration) }
    func orderOut() { inner.orderOut() }
    func move(to origin: CGPoint) { inner.move(to: origin) }
    func setClickThrough(_ on: Bool) { inner.setClickThrough(on) }
    func rebuild() { inner.rebuild() }
}
