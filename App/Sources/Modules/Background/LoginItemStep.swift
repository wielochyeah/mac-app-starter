import SwiftUI

/// Onboarding step "Open at login" (order 900, only for the installed app). The switch starts on
/// in a first setup (VoiceBud) and is applied when the person leaves the step, changing the login
/// item only if it differs from what macOS reports.
struct LoginItemStep: View {
    var login: LoginItemModel
    var settings: Settings
    @State private var wanted: Bool

    init(login: LoginItemModel = .shared, settings: Settings = .shared) {
        self.login = login
        self.settings = settings
        _wanted = State(initialValue: LoginItemStepRule.initial(status: login.status, asked: settings[.backgroundLoginAsked]))
    }

    var body: some View {
        OnboardingPage {
            OnboardingHero(symbol: "power", tint: .green).padding(.bottom, Space.m)
            OnboardingHeader(title: BackgroundText.stepTitle, subtitle: BackgroundText.stepSubtitle).padding(.bottom, Space.l)
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(tone: .onboarding) {
                    ToggleRow(BackgroundText.openAtLogin, subtitle: BackgroundText.stepToggleDetail, isOn: $wanted)
                }
                OnboardingFootnote(BackgroundText.stepFootnote, lines: 2)
            }
            .frame(width: BackgroundMetrics.stepCard)
            if login.status == .requiresApproval {
                InlineNotice(BackgroundText.needsApproval, kind: .warning, actionTitle: BackgroundText.openLoginItems) {
                    LoginItem.openSystemSettings()
                }
                .frame(width: Metrics.onboardingColumn)
                .padding(.top, Space.s)
            }
        }
        .onDisappear { apply() }
    }

    private func apply() {
        settings[.backgroundLoginAsked] = true
        if LoginItem.needsChange(to: wanted, from: login.status) { login.set(wanted) }
    }
}

enum BackgroundMetrics {
    /// The switch card on the step: as wide as the language step's card (VoiceBud 460).
    // design-ausnahme: VoiceBud's 460 pt step card has no token yet (S0b's language sample uses the same sum)
    static let stepCard: CGFloat = Metrics.onboardingNarrow + 60
}
