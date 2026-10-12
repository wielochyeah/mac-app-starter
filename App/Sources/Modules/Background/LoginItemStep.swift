import SwiftUI

/// Onboarding step "Start with Your Mac" (order 900, only for the installed app).
///
/// In a first setup the switch starts on (VoiceBud) and only records a wish (`LoginWish`), applied
/// when onboarding is done: Back, closing the window or quitting halfway register nothing. When
/// the setup is shown again later (from the menu or Settings), the switch acts at once, like the
/// one in the Background pane.
struct LoginItemStep: View {
    var login: LoginItemModel
    var settings: Settings
    private let firstSetup: Bool
    @State private var wanted: Bool

    init(login: LoginItemModel = .shared, settings: Settings = .shared) {
        self.login = login
        self.settings = settings
        firstSetup = !settings[.onboardingDone]
        _wanted = State(initialValue: LoginItemStepRule.initial(status: login.status, asked: settings[.backgroundLoginAsked],
                                                                pending: LoginWish.pending(settings)))
    }

    var body: some View {
        let isOn = Binding(get: { firstSetup ? wanted : login.isOn }, set: { choose($0) })
        OnboardingPage {
            OnboardingHero(symbol: "power", tint: .green).padding(.bottom, Space.m)
            OnboardingHeader(title: BackgroundText.stepTitle, subtitle: BackgroundText.stepSubtitle).padding(.bottom, Space.l)
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(tone: .onboarding) {
                    ToggleRow(BackgroundText.openAtLogin, subtitle: BackgroundText.stepToggleDetail, isOn: isOn)
                }
                if login.status == .requiresApproval {
                    // the notice names the same place in System Settings, so it replaces the footnote
                    InlineNotice(BackgroundText.needsApproval, kind: .warning, actionTitle: BackgroundText.openLoginItems) {
                        LoginItem.openSystemSettings()
                    }
                    .padding(.top, Space.s)
                } else {
                    OnboardingFootnote(BackgroundText.stepFootnote, lines: 2)
                }
            }
            .frame(width: Metrics.onboardingCard)
        }
        .onAppear {
            // the switch's starting value counts as the choice once the setup is finished (never in renders)
            if firstSetup && !RenderMode.isStatic { settings[.backgroundLoginWish] = wanted }
        }
    }

    private func choose(_ on: Bool) {
        if firstSetup {
            wanted = on
            if !RenderMode.isStatic { settings[.backgroundLoginWish] = on }
        } else {
            settings[.backgroundLoginAsked] = true
            login.set(on)
        }
    }
}
