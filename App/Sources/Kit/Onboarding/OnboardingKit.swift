import AppKit
import SwiftUI

/// Kit/Onboarding: the setup window shown on first launch (`AppDelegate` opens it while
/// `onboardingDone` is false) and again from Settings (`AppActions.openOnboarding()`).
///
/// Steps are `Registry.onboardingSteps` sorted by order: the kit adds Welcome (0), Language (10),
/// Features (20), one step per `starter.json` permission (300 +) and Done (1000); modules add
/// theirs in between (e.g. 400 local AI, 500 island style, 600 shortcut, 900 login item).
enum OnboardingKit {
    /// How a step's footer button behaves, by step id (default: primary "Continue", "Done" on the
    /// last step). A step that holds its own primary action makes the footer quiet:
    ///     OnboardingKit.advanceRules["hotkeys"] = { _ in OnboardingAdvance(isPrimary: false, title: HotkeysText.skip) }
    static var advanceRules: [String: (PermissionMonitor) -> OnboardingAdvance] = [:]

    enum StepID {
        static let welcome = "welcome"
        static let language = "language"
        static let features = "features"
        static let done = "done"
        static func permission(_ kind: PermissionKind) -> String { "permission.\(kind.id)" }
    }

    enum Order {
        static let welcome = 0
        static let language = 10
        static let features = 20
        static let permissions = 300
        static let done = 1000
    }

    static func register() {
        AppActions.onboardingHandler = { OnboardingWindow.show() }
        let permissions = onboardingPermissions(PermissionsKit.configured)
        Registry.onboardingSteps += kitSteps(permissions: permissions)
        advanceRules.merge(kitRules(permissions: permissions)) { _, kit in kit }
        Registry.launchHooks.append { reopenIfPermissionLost(permissions) }
        OnboardingScenes.register()
        Registry.selfTests += [
            SelfTestCheck(id: "onboarding.steps") {
                let ids = Set(Registry.orderedOnboardingSteps.map(\.id))
                let wanted = [StepID.welcome, StepID.done] + permissions.map(StepID.permission)
                let missing = wanted.filter { !ids.contains($0) }
                return missing.isEmpty ? nil : "missing steps \(missing.joined(separator: ", "))"
            },
            SelfTestCheck(id: "onboarding.window") {
                let flow = OnboardingFlow(steps: Registry.orderedOnboardingSteps, monitor: .preview([:]), settings: nil,
                                          rules: advanceRules, startAt: 0)
                let host = NSHostingController(rootView: OnboardingRootView(flow: flow))
                let size = host.sizeThatFits(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
                return size == Metrics.onboardingWindow ? nil : "root view is \(size), expected \(Metrics.onboardingWindow)"
            },
        ]
    }

    /// The permissions that get a step: everything macOS lets the app check (Local Network is
    /// asked by macOS on first use and has nothing to show here).
    static func onboardingPermissions(_ kinds: [PermissionKind]) -> [PermissionKind] {
        var seen = Set<PermissionKind>()
        return kinds.filter { $0.canCheck && seen.insert($0).inserted }
    }

    /// The kit's steps. `features` and `previewFollowsMac` let renders use fixed sample content.
    static func kitSteps(permissions: [PermissionKind],
                         features: @escaping () -> [OnboardingFeature] = { OnboardingFeatures.shown },
                         previewFollowsMac: Bool? = nil) -> [OnboardingStep] {
        var steps = [
            OnboardingStep(id: StepID.welcome, order: Order.welcome, isIncluded: { true }) { context in
                AnyView(WelcomeStep(stepCount: context.count))
            },
            OnboardingStep(id: StepID.language, order: Order.language, isIncluded: { AppConfig.languages.count > 1 }) { _ in
                AnyView(LanguageStep(previewFollowsMac: previewFollowsMac))
            },
            OnboardingStep(id: StepID.features, order: Order.features, isIncluded: { !features().isEmpty }) { _ in
                AnyView(FeaturesStep(features: features()))
            },
            OnboardingStep(id: StepID.done, order: Order.done, isIncluded: { true }) { _ in
                AnyView(DoneStep(permissions: permissions, previewFollowsMac: previewFollowsMac))
            },
        ]
        for (i, kind) in permissions.enumerated() {
            steps.append(OnboardingStep(id: StepID.permission(kind), order: Order.permissions + i, isIncluded: { true }) { _ in
                AnyView(PermissionStep(kind: kind, restart: { OnboardingWindow.restart() },
                                       willLeaveForRestart: { OnboardingWindow.flow?.prepareRestart() }))
            })
        }
        return steps
    }

    /// Footer rules of the kit steps: Continue is primary on a permission step only once it is
    /// granted (until then the slot holds the one primary button); Done says it restarts.
    static func kitRules(permissions: [PermissionKind]) -> [String: (PermissionMonitor) -> OnboardingAdvance] {
        var rules: [String: (PermissionMonitor) -> OnboardingAdvance] = [:]
        for kind in permissions {
            rules[StepID.permission(kind)] = { monitor in OnboardingAdvance(isPrimary: monitor.status(kind) == .granted) }
        }
        rules[StepID.done] = { monitor in
            restartPending(permissions, monitor) ? OnboardingAdvance(title: OnboardingText.doneAndRestart) : OnboardingAdvance()
        }
        return rules
    }

    static func restartPending(_ permissions: [PermissionKind], _ monitor: PermissionMonitor) -> Bool {
        permissions.contains { monitor.status($0) == .restartNeeded }
    }

    /// Whether `AppDelegate` opens the setup at launch: not finished yet, or a restart from inside
    /// the setup asked for it (also after a re-run from Settings); never for a login-item or
    /// `--background` launch.
    nonisolated static func opensAtLaunch(done: Bool, reopen: Bool, hasSteps: Bool, background: Bool) -> Bool {
        hasSteps && !background && (!done || reopen)
    }

    /// The first permission that was allowed when the setup was finished and is not any more
    /// (pure; a kind still being asked for does not count).
    nonisolated static func lostPermission(allowed: [String], now: [(kind: PermissionKind, status: PermissionStatus)]) -> PermissionKind? {
        now.first { allowed.contains($0.kind.id) && ($0.status == .missing || $0.status == .denied) }?.kind
    }

    /// Launch hook: after the setup was finished, a permission it had allowed is gone (ad-hoc
    /// rebuilds lose them, notes gotcha 10): open the setup at that step. Pressing "Done" there
    /// records the new state, so a permission left off on purpose stops reopening it.
    static func reopenIfPermissionLost(_ permissions: [PermissionKind]) {
        let settings = Settings.shared
        guard !RenderMode.isHeadless, !Launch.isBackground, !Launch.isDemo, settings[.onboardingDone],
              !settings[.onboardingAllowed].isEmpty else { return }
        Task {
            let monitor = PermissionMonitor.shared
            await monitor.refresh(permissions)
            guard let lost = lostPermission(allowed: settings[.onboardingAllowed], now: permissions.map { ($0, monitor.status($0)) }),
                  let step = Registry.orderedOnboardingSteps.first(where: { $0.id == StepID.permission(lost) }) else { return }
            Log.info("permission \(lost.id) was allowed and is gone: setup reopens", "onboarding")
            settings[.onboardingResume] = OnboardingResumePoint(id: step.id, order: step.order)
            settings[.onboardingReopen] = true
            AppActions.openOnboarding()
        }
    }

    static var opensAtLaunch: Bool {
        opensAtLaunch(done: Settings.shared[.onboardingDone], reopen: Settings.shared[.onboardingReopen],
                      hasSteps: !Registry.orderedOnboardingSteps.isEmpty, background: Launch.isBackground)
    }
}

/// The onboarding window (720 x 560, transparent titlebar, close button only; `WindowHost` keeps
/// the activation policy right and releases the views on close). A new flow per show.
enum OnboardingWindow {
    static let id = "onboarding"
    /// The open window's flow (to save the step before a restart).
    private(set) static weak var flow: OnboardingFlow?

    static func show() {
        WindowHost.show(id: id, style: .onboarding, title: { OnboardingText.windowTitle }) {
            let flow = makeFlow()
            Self.flow = flow
            return AnyView(OnboardingRootView(flow: flow))
        }
    }

    static func makeFlow() -> OnboardingFlow {
        let firstTime = !Settings.shared[.onboardingDone]
        let permissions = OnboardingKit.onboardingPermissions(PermissionsKit.configured)
        let flow = OnboardingFlow(steps: Registry.orderedOnboardingSteps, rules: OnboardingKit.advanceRules)
        flow.onFinish = { [weak flow] in
            guard let flow else { return }
            Settings.shared[.onboardingAllowed] = permissions.filter { flow.monitor.status($0).isAllowed }.map(\.id)
            finish(firstTime: firstTime, restart: OnboardingKit.restartPending(permissions, flow.monitor))
        }
        return flow
    }

    /// After "Done": close, then restart when a permission waits for it, or open the main window
    /// after the very first setup of a window app.
    private static func finish(firstTime: Bool, restart: Bool) {
        WindowHost.close(id)
        if restart, AppRelaunch.relaunch() { return }
        if firstTime && AppInfo.isEnabled("window") { AppActions.openMainWindow() }
    }

    /// "Restart <App>" on a permission step: save the step and the reopen marker, then relaunch.
    /// The new process opens the setup again at this step, also when it was shown from Settings.
    static func restart() {
        AppRelaunch.relaunch {
            flow?.prepareRestart()
            flow?.isRelaunching = true
        }
    }
}
