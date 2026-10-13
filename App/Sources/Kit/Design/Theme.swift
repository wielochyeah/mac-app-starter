import SwiftUI

// Colour tokens (ported from VoiceBud's HubTheme, generalised for accents).
//
// Colours are resolved from the SwiftUI ColorScheme, not from dynamic NSColors, so offscreen
// renders in light and dark come out exactly like the window. Every view does:
//
//     @Environment(\.colorScheme) private var scheme
//     …
//     let t = Theme(scheme)
//     Text(…).foregroundStyle(t.fg)
//
// Only files in Kit/Design may contain colour literals (scripts/check_design.py).

extension Color {
    /// sRGB colour from 0xRRGGBB.
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// The accent colours a project can pick in starter.json (`app.accent`).
nonisolated enum AccentName: String, CaseIterable, Codable, Sendable {
    case violett, rot, blau, gruen, orange, graphit
}

/// One accent. `brand` is the colour people know (icon gradient, app icon); `fillLight`/`fillDark`
/// paint controls (buttons, switches, progress) and differ from it where the brand colour would
/// not stand apart from the off state (orange in light, graphit in dark, rot in dark). `text` is
/// for links and badges (>= 4.5:1 on window and card, also on the badge tint), `ring` for
/// selection (>= 3:1), `onAccent` for labels on the fill (>= 3:1 like VoiceBud, see DesignTests).
nonisolated struct AccentPalette: Sendable {
    let brand: UInt32
    let fillLight: UInt32
    let fillDark: UInt32
    let textLight: UInt32
    let textDark: UInt32
    let ringLight: UInt32
    let ringDark: UInt32
    let onAccent: UInt32
    /// Lighter top colour for the accent squircle gradient (bottom: `brand`).
    let gradientTop: UInt32

    func fill(dark: Bool) -> UInt32 { dark ? fillDark : fillLight }

    static func of(_ name: AccentName) -> AccentPalette {
        switch name {
        case .violett: AccentPalette(brand: 0x8F6CF2, fillLight: 0x8F6CF2, fillDark: 0x8F6CF2, textLight: 0x6243CC, textDark: 0xB89EFA,
                                     ringLight: 0x8F6CF2, ringDark: 0xB89EFA, onAccent: 0xFFFFFF, gradientTop: 0xC3A8FF)
        case .rot: AccentPalette(brand: 0xFA2D48, fillLight: 0xFA2D48, fillDark: 0xFF3B55, textLight: 0xB80D29, textDark: 0xFF8592,
                                 ringLight: 0xE3243B, ringDark: 0xFF5C70, onAccent: 0xFFFFFF, gradientTop: 0xFF8A98)
        case .blau: AccentPalette(brand: 0x0A84FF, fillLight: 0x0A84FF, fillDark: 0x0A84FF, textLight: 0x005BBF, textDark: 0x5EAEFF,
                                  ringLight: 0x0A7AF0, ringDark: 0x4DA3FF, onAccent: 0xFFFFFF, gradientTop: 0x7DB6FF)
        case .gruen: AccentPalette(brand: 0x249B43, fillLight: 0x249B43, fillDark: 0x249B43, textLight: 0x176A2E, textDark: 0x4CD472,
                                   ringLight: 0x22913F, ringDark: 0x3CC864, onAccent: 0xFFFFFF, gradientTop: 0x86EFAC)
        case .orange: AccentPalette(brand: 0xF5900A, fillLight: 0xC96A00, fillDark: 0xF5900A, textLight: 0x934900, textDark: 0xFFB340,
                                    ringLight: 0xC26A00, ringDark: 0xFF9F0A, onAccent: 0x1D1D1F, gradientTop: 0xFFC56B)
        case .graphit: AccentPalette(brand: 0x6E6E73, fillLight: 0x6E6E73, fillDark: 0x8E8E93, textLight: 0x56565C, textDark: 0xC7C7CC,
                                     ringLight: 0x6E6E73, ringDark: 0xA1A1A6, onAccent: 0xFFFFFF, gradientTop: 0xA1A1A6)
        }
    }
}

/// Background hex values and the opacities of translucent tokens, shared by `Theme` and the
/// contrast tests (which composite them over window and card).
nonisolated enum ThemeHex {
    static let windowBgLight: UInt32 = 0xECECEE
    static let windowBgDark: UInt32 = 0x1E1E20
    static let cardLight: UInt32 = 0xF7F7F8
    static let cardDark: UInt32 = 0x2A2A2D
    static let fgLight: UInt32 = 0x1D1D1F
    static let fgDark: UInt32 = 0xF5F5F7
    /// Secondary text colours, used at the opacities below. `fg2`, `prose` and `sideGroup` are
    /// text (>= 4.5:1 on window, card and sidebar panel); `fg3` is for placeholders, disabled
    /// states and decorative glyphs only (chevrons, a search loupe), never for text people read.
    static let secondaryLight: UInt32 = 0x3C3C43
    static let secondaryDark: UInt32 = 0xEBEBF5
    static let fg2Light = 0.74
    static let fg2Dark = 0.6
    static let fg3Light = 0.42
    static let fg3Dark = 0.36
    static let proseLight = 0.80
    static let sideGroupLight = 0.74
    static let sideGroupDark = 0.54
    /// The floating sidebar panel (macOS 26) and the renders' stand-in for it.
    static let sidebarPanelLight: UInt32 = 0xF1F1F2
    static let sidebarPanelDark: UInt32 = 0x2A2A2B
    /// Neutral fill of an info notice: black (light) / white (dark) at these opacities.
    static let noticeNeutralLight = 0.05
    static let noticeNeutralDark = 0.06
    /// Switch off (light opaque; dark white at `switchOffDarkAlpha`, sits on cards).
    static let switchOffLight: UInt32 = 0xD4D4D9
    static let switchOffDarkAlpha = 0.17
    /// Progress track off (light opaque; dark white at `trackOffDarkAlpha`, sits on the window).
    static let trackOffLight: UInt32 = 0xD6D6DB
    static let trackOffDarkAlpha = 0.15
    /// Badge tints: the tone's colour at this opacity.
    static let accentSoftLight = 0.12
    static let accentSoftDark = 0.22
    static let ok: UInt32 = 0x30D158
    static let okTextLight: UInt32 = 0x1A6E2E
    static let okSoftLight = 0.14
    static let okSoftDark = 0.2
    static let warn: UInt32 = 0xFF9F0A
    static let warnTextLight: UInt32 = 0x8A4B00
    /// Errors: the mark (symbols, dots, rings; >= 3:1) and the text-grade red (>= 4.5:1).
    static let strikeLight: UInt32 = 0xD9363E
    static let strikeDark: UInt32 = 0xFF6B6B
    static let strikeTextLight: UInt32 = 0xC4162E
    static let warnSoftLight = 0.16
    static let warnSoftDark = 0.2
    /// Chip and neutral badge: black (light) / white (dark) at these opacities.
    static let chipLight = 0.06
    static let chipDark = 0.1
}

/// WCAG 2 contrast for opaque sRGB colours.
nonisolated enum Contrast {
    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF) + 0.7152 * channel((hex >> 8) & 0xFF) + 0.0722 * channel(hex & 0xFF)
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// `color` at `alpha` over the opaque `background` (sRGB channel blend, like the renderer).
    static func over(_ color: UInt32, _ alpha: Double, _ background: UInt32) -> UInt32 {
        func mix(_ shift: UInt32) -> UInt32 {
            let f = Double((color >> shift) & 0xFF), b = Double((background >> shift) & 0xFF)
            return UInt32((f * alpha + b * (1 - alpha)).rounded()) << shift
        }
        return mix(16) | mix(8) | mix(0)
    }
}

struct Theme {
    let dark: Bool
    let accentName: AccentName
    private let palette: AccentPalette

    init(_ scheme: ColorScheme, accent: AccentName = AppConfig.accent) {
        dark = scheme == .dark
        accentName = accent
        palette = AccentPalette.of(accent)
    }

    // MARK: Surfaces
    var windowBg: Color { Color(hex: dark ? ThemeHex.windowBgDark : ThemeHex.windowBgLight) }
    /// Sidebar before macOS 26 (flush), and the static stand-in for the sidebar column.
    var sidebarBg: Color { dark ? Color(hex: 0x262628) : Color(hex: 0xE2E2E5) }
    /// The floating sidebar panel drawn by macOS 26 (renders imitate it with this).
    var sidebarPanel: Color { Color(hex: dark ? ThemeHex.sidebarPanelDark : ThemeHex.sidebarPanelLight) }
    var sidebarPanelStroke: Color { dark ? .white.opacity(0.1) : .black.opacity(0.06) }
    var card: Color { Color(hex: dark ? ThemeHex.cardDark : ThemeHex.cardLight) }
    var cardStroke: Color { dark ? .white.opacity(0.075) : .black.opacity(0.09) }
    var separator: Color { dark ? .white.opacity(0.08) : .black.opacity(0.07) }
    var windowStroke: Color { dark ? .white.opacity(0.14) : .black.opacity(0.22) }
    /// The "desk" renders sit on, and its shadow.
    var desk: Color { dark ? Color(hex: 0x111113) : Color(hex: 0xF3F2EF) }
    var deskShadow: Color { .black.opacity(dark ? 0.5 : 0.18) }
    var panelShadow: Color { .black.opacity(dark ? 0.35 : 0.06) }

    // MARK: Text
    var fg: Color { Color(hex: dark ? ThemeHex.fgDark : ThemeHex.fgLight) }
    /// Secondary text: subtitles, values, times, counts, hints (>= 4.5:1).
    var fg2: Color { secondary(dark ? ThemeHex.fg2Dark : ThemeHex.fg2Light) }
    /// Placeholders, disabled states and decorative glyphs only; never text people have to read.
    var fg3: Color { secondary(dark ? ThemeHex.fg3Dark : ThemeHex.fg3Light) }
    /// Running sentences (onboarding, explanations): about 5.4:1 on the window in light mode.
    var prose: Color { dark ? fg2 : secondary(ThemeHex.proseLight) }
    /// Group titles of a sidebar (>= 4.5:1 on the sidebar panel).
    var sideGroup: Color { secondary(dark ? ThemeHex.sideGroupDark : ThemeHex.sideGroupLight) }

    private func secondary(_ opacity: Double) -> Color {
        Color(hex: dark ? ThemeHex.secondaryDark : ThemeHex.secondaryLight, opacity: opacity)
    }

    // MARK: Interaction
    var sideSel: Color { dark ? .white.opacity(0.09) : .black.opacity(0.075) }
    var rowHover: Color { dark ? .white.opacity(0.05) : .black.opacity(0.035) }
    var field: Color { dark ? .white.opacity(0.08) : .black.opacity(0.05) }
    var chip: Color { dark ? .white.opacity(ThemeHex.chipDark) : .black.opacity(ThemeHex.chipLight) }
    var chipActive: Color { dark ? .white.opacity(0.18) : .black.opacity(0.12) }

    // MARK: Accent
    var accent: Color { Color(hex: palette.fill(dark: dark)) }
    var accentText: Color { Color(hex: dark ? palette.textDark : palette.textLight) }
    var ring: Color { Color(hex: dark ? palette.ringDark : palette.ringLight) }
    /// Text and glyphs on an accent fill (primary button).
    var onAccent: Color { Color(hex: palette.onAccent) }
    /// Quiet accent background (badges, flashes).
    var accentSoft: Color { accent.opacity(dark ? ThemeHex.accentSoftDark : ThemeHex.accentSoftLight) }
    /// The squircle/app-icon gradient: same in both schemes (brand colour at the bottom).
    var accentGradient: [Color] { [Color(hex: palette.gradientTop), Color(hex: palette.brand)] }

    // MARK: Controls
    var switchOff: Color { dark ? .white.opacity(ThemeHex.switchOffDarkAlpha) : Color(hex: ThemeHex.switchOffLight) }
    var knob: Color { .white }
    var knobShadow: Color { .black.opacity(0.25) }
    var trackOff: Color { dark ? .white.opacity(ThemeHex.trackOffDarkAlpha) : Color(hex: ThemeHex.trackOffLight) }
    var detent: Color { dark ? .white.opacity(0.32) : .black.opacity(0.28) }
    var capsuleBg: Color { dark ? .white.opacity(0.06) : .white }
    var capsuleStroke: Color { dark ? .white.opacity(0.16) : .black.opacity(0.18) }
    var tileEdge: Color { dark ? .black.opacity(0.55) : .black.opacity(0.12) }
    var segmentTrack: Color { dark ? .white.opacity(0.08) : .black.opacity(0.06) }
    var segmentSelected: Color { dark ? .white.opacity(0.16) : .white }
    var segmentShadow: Color { .black.opacity(dark ? 0 : 0.12) }
    var buttonSecondary: Color { dark ? .white.opacity(0.12) : .white }
    var buttonSecondaryEdge: Color { dark ? .white.opacity(0.08) : .black.opacity(0.13) }
    var buttonPrimaryEdge: Color { .black.opacity(0.08) }
    var buttonShadow: Color { .black.opacity(dark ? 0 : 0.05) }
    var squircleEdge: Color { .white.opacity(0.22) }
    var squircleGlyph: Color { .white }
    /// Stand-in for glass in static renders (glass never shows offscreen).
    var glassStandIn: Color { dark ? Color(hex: 0x2C2C2F, opacity: 0.92) : Color(hex: 0xFAFAFB, opacity: 0.92) }
    var glassStroke: Color { dark ? .white.opacity(0.12) : .black.opacity(0.08) }

    // MARK: Status
    /// Errors as a mark: symbols, dots, rings (>= 3:1). Text in red uses `strikeText`.
    var strike: Color { Color(hex: dark ? ThemeHex.strikeDark : ThemeHex.strikeLight) }
    var ok: Color { Color(hex: ThemeHex.ok) }
    var warn: Color { Color(hex: ThemeHex.warn) }
    var idle: Color { fg3 }
    /// Status colours as text on window/card backgrounds and on their badge tints (>= 4.5:1).
    var okText: Color { dark ? ok : Color(hex: ThemeHex.okTextLight) }
    var warnText: Color { dark ? warn : Color(hex: ThemeHex.warnTextLight) }
    var strikeText: Color { dark ? strike : Color(hex: ThemeHex.strikeTextLight) }
    /// Badge tints (`Badge`): the tone's colour at a low opacity.
    var okSoft: Color { ok.opacity(dark ? ThemeHex.okSoftDark : ThemeHex.okSoftLight) }
    var warnSoft: Color { warn.opacity(dark ? ThemeHex.warnSoftDark : ThemeHex.warnSoftLight) }

    // MARK: Window chrome in renders
    var trafficRed: Color { Color(hex: 0xFF5F57) }
    var trafficYellow: Color { Color(hex: 0xFEBC2E) }
    var trafficGreen: Color { Color(hex: 0x28C840) }
    var trafficEdge: Color { .black.opacity(0.12) }
}
