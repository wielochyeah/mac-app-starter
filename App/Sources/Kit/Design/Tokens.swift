import SwiftUI

// Spacing, radii, type, motion and fixed sizes. Views outside Kit/Design use only these
// (scripts/check_design.py rejects literal paddings, spacings, corner radii, font sizes, springs).
// Values come from VoiceBud's hub and onboarding (docs: notes vb-onboarding-hub §2.7, §4).

/// Gaps and paddings. The onboarding rhythm is 8 / 12 / 16 / 24; the hub adds 20 for pane content.
enum Space {
    static let hair: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    /// Hub pane content padding (horizontal), and the gap between setting groups.
    static let pane: CGFloat = 20
    /// Row insets inside a card.
    static let rowX: CGFloat = 12
    static let rowY: CGFloat = 9
    /// Between a squircle icon and its title (pane header, sidebar rows), VoiceBud hub.
    static let iconGap: CGFloat = 9
}

/// Corner radii, always used with `style: .continuous`.
enum Radius {
    static let keyCap: CGFloat = 6
    static let segment: CGFloat = 6
    static let chip: CGFloat = 7
    static let button: CGFloat = 8
    static let field: CGFloat = 8
    static let segmentTrack: CGFloat = 8
    static let row: CGFloat = 10
    static let tile: CGFloat = 11
    static let card: CGFloat = 13
    static let hero: CGFloat = 14
    static let ring: CGFloat = 15
    static let window: CGFloat = 16
    static let panel: CGFloat = 18
    /// macOS 26 window corner (floating sidebar era).
    static let windowGlass: CGFloat = 26

    /// App-icon-like squircle corner for a given size.
    static func squircle(_ size: CGFloat) -> CGFloat { size * 0.28 }
}

/// Type scale: system font (SF Pro) with explicit sizes, never `.title`/`.body` text styles.
enum TypeScale {
    /// Big page headers in the main window (hero).
    static let display = Font.system(size: 34, weight: .bold)
    /// Onboarding welcome title.
    static let intro = Font.system(size: 28, weight: .bold)
    /// Onboarding step titles, empty-state titles, page titles.
    static let title = Font.system(size: 22, weight: .bold)
    /// Section titles in content pages (shelves).
    static let headline = Font.system(size: 17, weight: .semibold)
    /// Settings pane title in the header band.
    static let paneTitle = Font.system(size: 15.5, weight: .bold)
    /// Welcome lede and content shown at reading size.
    static let lede = Font.system(size: 15)
    static let body = Font.system(size: 13)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let bodySemibold = Font.system(size: 13, weight: .semibold)
    /// Group labels above cards.
    static let groupLabel = Font.system(size: 12.5, weight: .semibold)
    static let secondary = Font.system(size: 12)
    static let secondaryMedium = Font.system(size: 12, weight: .medium)
    static let secondarySemibold = Font.system(size: 12, weight: .semibold)
    /// Row subtitles, footnotes, chips.
    static let subtitle = Font.system(size: 11.5)
    static let subtitleMedium = Font.system(size: 11.5, weight: .medium)
    static let caption = Font.system(size: 11)
    static let badge = Font.system(size: 10.5, weight: .semibold)
    static let micro = Font.system(size: 9.5, weight: .bold)

    /// Line spacing for running text (onboarding sentences, footnotes).
    static let proseLineSpacing: CGFloat = 3
    static let footnoteLineSpacing: CGFloat = 1.5

    /// Glyph inside a squircle of `size`.
    static func squircleGlyph(_ size: CGFloat) -> Font { .system(size: size * 0.5, weight: .semibold) }
    /// SF Symbol at a fixed point size (icons in rows, empty states).
    static func symbol(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}

/// Motion: springs from VoiceBud. Respect Reduce Motion with `Motion.adaptive(_:reduce:)`.
enum Motion {
    /// Onboarding page change and other large moves.
    static let page = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// Button press feedback.
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.6)
    /// Sidebar selection moving between rows.
    static let selection = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// Tile picker ring.
    static let tile = Animation.spring(response: 0.5, dampingFraction: 0.74)
    /// Switch knob (slight overshoot).
    static let toggle = Animation.spring(response: 0.34, dampingFraction: 0.6)
    /// Expanding rows and disclosure.
    static let expand = Animation.spring(response: 0.36, dampingFraction: 0.86)
    /// Reduce Motion replacement for every spring.
    static let reduced = Animation.easeInOut(duration: 0.2)
    /// A quick fade (hover chips, swaps that must not move).
    static let fade = Animation.easeOut(duration: 0.12)

    /// Page transition offset (points) and press scales.
    static let pageOffset: CGFloat = 26
    static let pressScale: CGFloat = 0.97
    static let pressScaleSmall: CGFloat = 0.95
    static let stateScale: CGFloat = 0.96

    static func adaptive(_ animation: Animation, reduce: Bool) -> Animation { reduce ? reduced : animation }

    /// The island's surfaces (Alcove-like, mass 1). Width and height use separate springs.
    enum Island {
        static let widthGrow = Animation.interpolatingSpring(mass: 1, stiffness: 150, damping: 20)
        static let widthCollapse = Animation.interpolatingSpring(mass: 1, stiffness: 200, damping: 20)
        static let heightGrow = Animation.interpolatingSpring(mass: 1, stiffness: 250, damping: 21)
        static let heightCollapse = Animation.interpolatingSpring(mass: 1, stiffness: 250, damping: 25)
        /// Content swaps while the surface stays (waveform → spinner → check).
        static let swap = Animation.interpolatingSpring(mass: 1, stiffness: 150, damping: 14)
        static let enter = Animation.easeOut(duration: 0.30)
        static let exit = Animation.easeIn(duration: 0.25)

        static func width(growing: Bool) -> Animation { growing ? widthGrow : widthCollapse }
        static func height(growing: Bool) -> Animation { growing ? heightGrow : heightCollapse }
    }
}

/// Fixed sizes of kit surfaces and controls.
enum Metrics {
    static let hairline: CGFloat = 0.5
    static let rowMinHeight: CGFloat = 44
    static let buttonMinWidth: CGFloat = 92
    static let buttonWideMinWidth: CGFloat = 104
    static let buttonHeight: CGFloat = 30
    static let switchSize = CGSize(width: 36, height: 21)
    static let switchKnob: CGFloat = 17
    static let segmentHeight: CGFloat = 22
    static let chipHeight: CGFloat = 24
    static let badgeHeight: CGFloat = 16
    static let keyCap: CGFloat = 22
    static let squircle: CGFloat = 22
    static let squircleLarge: CGFloat = 64
    static let dot: CGFloat = 7
    static let progressSegment = CGSize(width: 18, height: 3)
    static let progressSpacing: CGFloat = 4
    static let spinner: CGFloat = 16
    static let paneHeader: CGFloat = 52
    static let settingsColumn: CGFloat = 640
    static let onboardingWindow = CGSize(width: 720, height: 560)
    static let onboardingFooter: CGFloat = 68
    static let onboardingColumn: CGFloat = 560
    static let onboardingNarrow: CGFloat = 400
    static let settingsWindow = CGSize(width: 900, height: 620)
    static let settingsWindowMin = CGSize(width: 760, height: 500)
    static let sidebarWidth: CGFloat = 224
    static let sidebarRow: CGFloat = 34
    static let titlebar: CGFloat = 32
    static let trafficLight: CGFloat = 14
    static let trafficSpacing: CGFloat = 9
    static let trafficInset: CGFloat = 19
}

/// Gradient tints for squircle icons (settings panes, permission icons), from VoiceBud's hub.
nonisolated enum TintName: String, CaseIterable, Sendable {
    case accent, violet, blue, sky, indigo, teal, green, yellow, orange, red, graphite, black

    /// Top and bottom of the vertical gradient (0xRRGGBB).
    func gradient(accent: AccentName = AppConfig.accent) -> (top: UInt32, bottom: UInt32) {
        switch self {
        case .accent:
            let p = AccentPalette.of(accent)
            return (p.gradientTop, p.brand)
        case .violet: return (0xC3A8FF, 0x8F6CF2)
        case .blue: return (0x7DB6FF, 0x3B82F6)
        case .sky: return (0x8CCBFF, 0x3E92F0)
        case .indigo: return (0xA5B4FC, 0x6366F1)
        case .teal: return (0x5EEAD4, 0x14B8A6)
        case .green: return (0x86EFAC, 0x22C55E)
        case .yellow: return (0xFBBF24, 0xF59E0B)
        case .orange: return (0xFFB648, 0xFF8A00)
        case .red: return (0xFB7185, 0xF43F5E)
        case .graphite: return (0xA1A1A6, 0x76767B)
        case .black: return (0x3A3A3C, 0x000000)
        }
    }

    var colors: [Color] {
        let g = gradient()
        return [Color(hex: g.top), Color(hex: g.bottom)]
    }
}
