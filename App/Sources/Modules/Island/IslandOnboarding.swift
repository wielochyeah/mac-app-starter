import SwiftUI

/// Onboarding step "Island & Capsule" (order 500, only on Macs with a notch; VoiceBud
/// onboarding-08-darstellung): the live stage and two tiles, island at the notch or capsule. The island tile stores `auto` (island where
/// there is a notch), the capsule tile `capsule`.
struct IslandOnboardingStep: View {
    private let settings = Settings.shared

    /// What the two tiles stand for.
    enum Choice: Hashable { case island, capsule }

    var body: some View {
        let style = IslandStyle(rawValue: settings[.islandStyle]) ?? .auto
        let choice = Binding<Choice>(
            get: { style == .capsule ? .capsule : .island },
            set: { new in
                // keep an explicit "island" from settings; the island tile otherwise means auto
                let stored: IslandStyle = new == .capsule ? .capsule : (style == .island ? .island : .auto)
                settings[.islandStyle] = stored.rawValue
                Island.shared.settingsDidChange()
            })
        OnboardingPage {
            OnboardingHeader(title: IslandText.onboardingTitle, subtitle: IslandText.onboardingSubtitle)
                .padding(.bottom, Space.l)
            IslandStyleStage(style: style == .capsule ? .capsule : .island)
                .frame(width: Metrics.onboardingColumn)
                .padding(.bottom, Space.m)
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(tone: .onboarding) {
                    TilePicker([TileOption(Choice.island, title: IslandText.style(.island)),
                                TileOption(Choice.capsule, title: IslandText.style(.capsule))],
                               selection: choice) { c in
                        IslandStyleTile(style: c == .capsule ? .capsule : .island)
                    }
                }
                OnboardingFootnote(IslandText.onboardingNote, lines: 2)
            }
            .frame(width: Metrics.onboardingColumn)
        }
    }
}
