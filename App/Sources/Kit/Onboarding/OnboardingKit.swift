import SwiftUI

// STUB (S0): a minimal working onboarding so the app launches. Strand D replaces this folder
// (window, steps, permissions, model download) and keeps `OnboardingKit.register()`.

enum OnboardingKit {
    static func register() {
        AppActions.onboardingHandler = { OnboardingWindow.show() }
        Registry.onboardingSteps.append(OnboardingStep(id: "welcome", order: 0, isIncluded: { true }) { _ in
            AnyView(OnboardingWelcome())
        })
    }
}

enum OnboardingWindow {
    static func show() {
        WindowHost.show(id: "onboarding", style: .onboarding, title: { OnboardingText.windowTitle }) {
            AnyView(OnboardingRoot())
        }
    }

    static func finish() {
        Settings.shared[.onboardingDone] = true
        WindowHost.close("onboarding")
    }
}

struct OnboardingRoot: View {
    @State private var index = 0
    @State private var canContinue = true
    @State private var forward = true
    private let steps = Registry.orderedOnboardingSteps
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            ZStack {
                if steps.indices.contains(index) {
                    steps[index].content(context)
                        .id(steps[index].id)
                        .transition(transition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, Metrics.titlebar)
            .clipped()
            ZStack {
                if steps.count > 1 { SegmentedProgress(count: steps.count, current: index) }
                HStack {
                    if index > 0 { Button(CommonText.back) { move(-1) }.buttonStyle(.secondary) }
                    Spacer()
                    Button(index == steps.count - 1 ? OnboardingText.start : CommonText.continue) { move(1) }
                        .buttonStyle(.primary(minWidth: Metrics.buttonWideMinWidth))
                        .disabled(!canContinue)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, Space.l)
            .frame(height: Metrics.onboardingFooter)
        }
        .frame(width: Metrics.onboardingWindow.width, height: Metrics.onboardingWindow.height)
        .background(t.windowBg)
    }

    private var context: OnboardingContext {
        OnboardingContext(canContinue: $canContinue, next: { move(1) }, back: { move(-1) }, index: index, count: steps.count)
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        let d: CGFloat = forward ? 1 : -1
        return .asymmetric(insertion: .offset(x: Motion.pageOffset * d).combined(with: .opacity),
                           removal: .offset(x: -Motion.pageOffset * d).combined(with: .opacity))
    }

    private func move(_ delta: Int) {
        let target = index + delta
        guard target >= 0 else { return }
        guard target < steps.count else { return OnboardingWindow.finish() }
        forward = delta > 0
        canContinue = true
        withAnimation(Motion.adaptive(Motion.page, reduce: reduceMotion)) { index = target }
    }
}

private struct OnboardingWelcome: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: Space.m) {
            SquircleIcon(symbol: AppInfo.symbol, tint: .accent, size: Metrics.squircleLarge)
            Text(OnboardingText.welcomeTitle).font(TypeScale.intro).foregroundStyle(t.fg)
            Text(OnboardingText.welcomeLede).font(TypeScale.lede).foregroundStyle(t.prose)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Metrics.onboardingColumn)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
