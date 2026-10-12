import SwiftUI

/// The notch island / capsule module (`MODUL_ISLAND`). Public API: `Island.shared`
/// (`present`, `update`, `dismiss`, `isPresenting`). Contributes the settings pane "Island &
/// Capsule", the onboarding step "Appearance", render scenes, gallery entries, a `--demo` loop
/// and self-tests.
enum IslandModule {
    static func register() {
        Registry.settingsPanes.append(SettingsPane(id: "island", group: .settings, order: 200, title: { IslandText.pane },
                                                   symbol: IslandPane.symbol, tint: .black) { AnyView(IslandPane()) })
        Registry.onboardingSteps.append(OnboardingStep(id: "island.appearance", order: 500, isIncluded: { true }) { _ in
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

    private static func registerSelfTests() {
        Registry.selfTests.append(SelfTestCheck(id: "island.geometry") {
            for screen in IslandScreen.all {
                let geo = IslandScreenGeometry(screen)
                let origin = geo.panelOrigin(for: IslandLook.canvas)
                guard geo.menuBarHeight > 0, origin.y + IslandLook.canvas.height == screen.frame.maxY else {
                    return "screen \(screen.displayID.map(String.init) ?? "?"): menu bar \(geo.menuBarHeight), panel top \(origin.y)"
                }
            }
            return nil
        })
        // the real controller with a real panel, headless: content shows in the model, the
        // panel never becomes visible, everything is gone after stop()
        Registry.selfTests.append(SelfTestCheck(id: "island.headless") {
            var deps = Island.Dependencies.live
            deps.headless = true
            // a 14" MacBook Pro, so the check does not depend on the machine's displays
            let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
            deps.screens = { [IslandScreen(frame: frame, visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949), safeTop: 32,
                                           auxLeftWidth: 663.5, auxRightWidth: 663.5, displayID: 1)] }
            deps.mouse = { CGPoint(x: frame.midX, y: frame.midY) }
            let island = Island(deps: deps)
            defer { island.stop() }
            island.present(.notice(text: IslandSampleText.noticeInfo))
            guard island.isPresenting, island.model.phase == .notice else { return "present did not set the content" }
            guard !NSApp.windows.contains(where: { $0 is IslandPanel && $0.isVisible }) else { return "the island panel became visible" }
            island.stop()
            return island.isPresenting ? "stop left content behind" : nil
        })
    }
}
