import SwiftUI

// Sizes and colours only the onboarding's own steps use (welcome art, done badge, feature rows).
// Kept here until another area needs them; candidates for Kit/Design (see docs/bau/status/D.md).

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
    /// Cards on the language and done steps (VoiceBud: narrow column 400 + 60).
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
    /// Soft shadow under the welcome icon (the render desk's shadow strength).
    var welcomeIconShadow: Color { deskShadow }
}
