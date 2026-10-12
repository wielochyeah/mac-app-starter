import SwiftUI

/// The onboarding window's content: the current step sliding 26 pt with the page spring (a fade
/// under Reduce Motion), the footer with Back, the segmented progress and Continue/Done.
struct OnboardingRootView: View {
    let flow: OnboardingFlow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let advance = flow.advance
        OnboardingFrame {
            if let step = flow.current {
                step.content(flow.context)
                    .id(step.id)
                    .transition(transition)
            }
        } footer: {
            OnboardingFooter(count: flow.steps.count, index: flow.index,
                             advanceTitle: advance.title ?? CommonText.continue,
                             advanceIsPrimary: advance.isPrimary, canAdvance: advance.isEnabled,
                             back: flow.isFirst ? nil : { flow.back() },
                             advance: { flow.next() })
        }
        .animation(Motion.adaptive(Motion.page, reduce: reduceMotion), value: flow.index)
        .environment(\.permissionMonitor, flow.monitor)
        .environment(\.onboardingGoTo, { id in flow.go(toStep: id) })
        .onDisappear { flow.leave() }   // the window closed (a relaunch quits without this)
    }

    /// Read when the page is inserted and when it is removed: `flow.forward` is flipped one
    /// runloop turn before the index changes, so both use the new direction.
    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        let d: CGFloat = flow.forward ? 1 : -1
        return .asymmetric(insertion: .offset(x: Motion.pageOffset * d).combined(with: .opacity),
                           removal: .offset(x: -Motion.pageOffset * d).combined(with: .opacity))
    }
}

private nonisolated struct OnboardingGoToKey: EnvironmentKey {
    static var defaultValue: ((String) -> Void)? { nil }
}

extension EnvironmentValues {
    /// Jumps to an onboarding step by id (the Done page's rows of permissions not allowed yet).
    /// nil outside the onboarding window.
    var onboardingGoTo: ((String) -> Void)? {
        get { self[OnboardingGoToKey.self] }
        set { self[OnboardingGoToKey.self] = newValue }
    }
}
