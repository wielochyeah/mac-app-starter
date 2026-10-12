import SwiftUI

/// Render scenes (`onboarding.*`) and gallery entries. Every scene is the real
/// `OnboardingRootView` on a flow with fixed sample steps and a preview permission monitor, in
/// the onboarding window chrome on the render desk; nothing is read from or written to settings.
enum OnboardingScenes {
    /// The sample setup: three features and three permissions (the starter's own config lists
    /// only notifications), so every step and footer state shows up.
    static let samplePermissions: [PermissionKind] = [.microphone, .accessibility, .inputMonitoring]

    static func register() {
        let restartKind = PermissionKind.inputMonitoring
        var scenes: [(String, () -> AnyView)] = [
            ("welcome", { window(at: OnboardingKit.StepID.welcome) }),
            ("language", { window(at: OnboardingKit.StepID.language) }),
            ("features", { window(at: OnboardingKit.StepID.features) }),
            ("done", { window(at: OnboardingKit.StepID.done, states: [.microphone: .granted, .accessibility: .granted, .inputMonitoring: .missing]) }),
            ("done-restart", { window(at: OnboardingKit.StepID.done, states: [.microphone: .granted, .accessibility: .granted, .inputMonitoring: .restartNeeded]) }),
            ("permission-microphone-waiting", { window(at: OnboardingKit.StepID.permission(.microphone), states: [.microphone: .requested]) }),
            ("permission-accessibility-waiting", { window(at: OnboardingKit.StepID.permission(.accessibility), states: [.accessibility: .requested]) }),
            ("permission-automation-denied", {
                let mail = PermissionKind.automation(bundleId: "com.apple.mail")
                return window(at: OnboardingKit.StepID.permission(mail), permissions: [mail], states: [mail: .denied])
            }),
            ("permission-notifications", {
                window(at: OnboardingKit.StepID.permission(.notifications), permissions: [.notifications], states: [.notifications: .missing])
            }),
        ]
        // every state of one kind that has them all (Input Monitoring needs a restart)
        for status in PermissionStatus.allCases {
            let name = status == .restartNeeded ? "restart" : status.rawValue
            scenes.append(("permission-\(name)", { window(at: OnboardingKit.StepID.permission(restartKind), states: [restartKind: status]) }))
        }
        for (name, view) in scenes {
            Registry.renderScenes.append(RenderScene(id: "onboarding.\(name)", size: .zero, content: view))
        }

        Registry.gallery += [
            GalleryEntry(id: "onboarding.welcome-art", area: "onboarding", title: { OnboardingText.galleryWelcomeArt }) {
                AnyView(WelcomeArt().clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)))
            },
            GalleryEntry(id: "onboarding.feature-row", area: "onboarding", title: { OnboardingText.galleryFeatureRow }) {
                AnyView(SettingsSection(tone: .onboarding) {
                    ForEach(sampleFeatures.prefix(2)) { FeatureRow(feature: $0) }
                }.frame(width: Metrics.onboardingColumn))
            },
            GalleryEntry(id: "onboarding.done-icon", area: "onboarding", title: { OnboardingText.galleryDoneIcon }) {
                AnyView(DoneIcon())
            },
        ]
    }

    static var sampleFeatures: [OnboardingFeature] {
        [OnboardingFeature(id: "sample.organize", order: 0, symbol: "square.stack.3d.up.fill", tint: .accent,
                           title: { OnboardingSampleText.organizeTitle }, detail: { OnboardingSampleText.organizeDetail }),
         OnboardingFeature(id: "sample.local", order: 1, symbol: "lock.fill", tint: .blue,
                           title: { OnboardingSampleText.localTitle }, detail: { OnboardingSampleText.localDetail }),
         OnboardingFeature(id: "sample.quick", order: 2, symbol: "command", tint: .graphite,
                           title: { OnboardingSampleText.quickTitle }, detail: { OnboardingSampleText.quickDetail })]
    }

    /// The sample flow at `stepId`, as a window on the render desk.
    static func window(at stepId: String, permissions: [PermissionKind] = samplePermissions,
                       states: [PermissionKind: PermissionStatus] = [:]) -> AnyView {
        let steps = OnboardingKit.kitSteps(permissions: permissions, features: { sampleFeatures }, previewFollowsMac: true)
            .filter { $0.isIncluded() }
            .sorted { ($0.order, $0.id) < ($1.order, $1.id) }
        let flow = OnboardingFlow(steps: steps, monitor: .preview(states), settings: nil,
                                  rules: OnboardingKit.kitRules(permissions: permissions),
                                  startAt: steps.firstIndex { $0.id == stepId } ?? 0)
        return AnyView(RenderBoard {
            StaticWindow(size: Metrics.onboardingWindow, chrome: .onboarding) {
                OnboardingRootView(flow: flow)
            }
        })
    }
}
