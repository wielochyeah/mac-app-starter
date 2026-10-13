import SwiftUI

// Sizes, type and colours the patterns need on top of Tokens.swift / Theme.swift. Values from
// VoiceBud's onboarding (ui/Onboarding.swift) and hub (ui/Hub.swift), notes vb-onboarding-hub
// §2.7 and §3–§4. Kept next to the patterns so the base token files stay small.

extension Metrics {
    /// OnboardingCentered: the page is lifted this much above the true centre ...
    nonisolated static let onboardingLift: CGFloat = 12
    /// ... but never placed closer than this to the titlebar.
    nonisolated static let onboardingMinTop: CGFloat = 24
    /// Fixed state slot of a permission step (button / spinner / check) and the hint area under it.
    static let statusSlotHeight: CGFloat = 30
    static let onboardingHint = CGSize(width: 560, height: 64)
    /// Buttons inside the status slot (VoiceBud 150; Screen Recording used 190).
    static let slotButtonMinWidth: CGFloat = 150
    /// Reserved height per footnote line (`lines:`), VoiceBud `lines * 16`.
    static let footnoteLine: CGFloat = 16
    /// Custom hero art on the welcome step (VoiceBud's island stage), radius `Radius.hero`.
    static let heroArt = CGSize(width: 672, height: 200)
    /// Tile previews: 56 (settings, small), 64, 86 (large onboarding tiles).
    static let tilePreview: CGFloat = 56
    static let tilePreviewLarge: CGFloat = 86
    /// The selection ring sits this far outside the tile (VoiceBud padding -4, line 2.5).
    static let tileRingOutset: CGFloat = 4
    static let tileRingLine: CGFloat = 2.5
    /// Progress row: icon, bar height, bar indent (icon + gap) and the row's vertical padding.
    static let progressIcon: CGFloat = 28
    static let progressBar: CGFloat = 4
    static let progressBarIndent: CGFloat = 40
    static let progressRowY: CGFloat = 10
    /// Search field in pane headers and list cards (VoiceBud 236 x 28).
    static let searchField = CGSize(width: 236, height: 28)
    static let searchFieldCompact = CGSize(width: 180, height: 24)
    /// Value capsule ("3.0 s") and menu picker button heights.
    static let valueCapsuleHeight: CGFloat = 23
    static let menuPickerHeight: CGFloat = 22
    /// Leading icon of an inline notice.
    static let noticeIcon: CGFloat = 15
    static let noticeIconColumn: CGFloat = 18
    /// Narrowest text column of a notice with its chip beside it; narrower puts the chip below.
    static let noticeTextMin: CGFloat = 240
    /// Large status mark in the onboarding slot (check 15 pt).
    static let statusMarkLarge: CGFloat = 15
    /// Empty state inside a list card.
    static let listEmptyPadding: CGFloat = 28
}

extension Space {
    /// Gap between an inline notice's icon and its text (VoiceBud speed hint 10).
    static let noticeGap: CGFloat = 10
    /// Inline notice padding (VoiceBud 14 / 11).
    static let noticeX: CGFloat = 14
    static let noticeY: CGFloat = 11
    /// Pane subtitle under the header band: bottom gap before the first section.
    static let paneIntroBottom: CGFloat = 16
    /// Settings tile picker insets inside a card (VoiceBud HubTilePicker 12 / 13 / 11).
    static let tileTop: CGFloat = 13
    static let tileBottom: CGFloat = 11
    /// Title under a tile preview: 7 (settings) / 8 (onboarding).
    static let tileTitleGap: CGFloat = 7
}

extension Radius {
    /// Inline notice (VoiceBud speed hint 12).
    static let notice: CGFloat = 12
}

extension TypeScale {
    /// Pane intro under the header band (VoiceBud dictionary pane 12.5 fg2).
    static let paneIntro = Font.system(size: 12.5)
    /// Search field text.
    static let search = Font.system(size: 12.5)
    /// Value capsule ("3.0 s"), medium with monospaced digits.
    static let value = Font.system(size: 12.5, weight: .medium).monospacedDigit()
    /// Empty state title inside a list (VoiceBud history 15 semibold).
    static let emptyTitle = Font.system(size: 15, weight: .semibold)
    /// Counts in sidebars and list headers (11.5 monospaced digits).
    static let count = Font.system(size: 11.5).monospacedDigit()
    /// Settings tile titles (12.5; semibold when selected).
    static let tileTitle = Font.system(size: 12.5)
    static let tileTitleSelected = Font.system(size: 12.5, weight: .semibold)
}

extension Theme {
    /// Shadow under the 64 pt hero squircle (VoiceBud black 12 % / 30 %).
    var heroShadow: Color { .black.opacity(dark ? 0.3 : 0.12) }
    /// Inline notice fill and edge for a tone colour (VoiceBud speed hint: 10 % / 16 %, edge 35 %).
    func noticeFill(_ tone: Color) -> Color { tone.opacity(dark ? 0.16 : 0.10) }
    func noticeEdge(_ tone: Color) -> Color { tone.opacity(0.35) }
    /// An info notice is neutral: no colour, so it never reads like an error, a success or a
    /// warning in an app whose accent is red, green or orange.
    var noticeNeutralFill: Color { dark ? .white.opacity(ThemeHex.noticeNeutralDark) : .black.opacity(ThemeHex.noticeNeutralLight) }
}

// MARK: Onboarding steps

// The kit's own steps (welcome art, done badge, feature rows) and the step card that modules use too.

extension Metrics {
    /// Welcome: the app icon in the hero art, and the art's distance from the window top
    /// (VoiceBud: 40 = titlebar 32 + 8).
    static let welcomeIcon: CGFloat = 104
    static let welcomeIconShadowRadius: CGFloat = 16
    static let welcomeIconShadowY: CGFloat = 8
    static let welcomeArtTop: CGFloat = 40
    /// Welcome: the concentric rings around the icon (radius of the first, gap between rings).
    static let welcomeRingFirst: CGFloat = 76
    static let welcomeRingGap: CGFloat = 34
    static let welcomeRingCount = 4
    /// Done: app icon with a check badge cut out of the window background (VoiceBud finish page).
    static let doneIcon: CGFloat = 72
    static let doneBadge: CGFloat = 21
    static let doneBadgeCut: CGFloat = 3
    static let doneBadgeInset: CGFloat = 4
    static let doneBadgeGlyph: CGFloat = 10.5
    /// The narrow card of a step (language, done, open at login; VoiceBud 460).
    static let onboardingCard: CGFloat = 460
    /// Feature rows: the squircle in front of each feature.
    static let featureIcon: CGFloat = 32
}

extension Theme {
    /// The accent glow behind the welcome icon: strong at the centre, gone at the art's edge.
    var welcomeGlow: [Gradient.Stop] {
        [.init(color: accent.opacity(dark ? 0.55 : 0.42), location: 0),
         .init(color: accent.opacity(dark ? 0.16 : 0.12), location: 0.45),
         .init(color: accent.opacity(0), location: 1)]
    }
    /// The art's ground under the glow: a touch deeper than the window in dark, lighter in light.
    var welcomeGround: Color { dark ? desk.opacity(0.6) : card.opacity(0.7) }
    /// Hairline rings around the icon.
    var welcomeRing: Color { accent.opacity(dark ? 0.28 : 0.22) }
    /// Soft shadow under the welcome icon: accent-tinted in light (a neutral one greys the glow
    /// around the icon), the render desk's shadow in dark.
    var welcomeIconShadow: Color { dark ? deskShadow : accent.opacity(0.28) }
}
