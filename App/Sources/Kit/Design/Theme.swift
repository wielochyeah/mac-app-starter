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

/// One accent: fill (buttons, switches, progress), text (links, badges; >= 4.5:1 on window and
/// card backgrounds in both schemes), ring (selection; >= 3:1), onAccent (text on the fill).
nonisolated struct AccentPalette: Sendable {
    let fill: UInt32
    let textLight: UInt32
    let textDark: UInt32
    let ringLight: UInt32
    let ringDark: UInt32
    let onAccent: UInt32
    /// Lighter top colour for the accent squircle gradient.
    let gradientTop: UInt32

    static func of(_ name: AccentName) -> AccentPalette {
        switch name {
        case .violett: AccentPalette(fill: 0x8F6CF2, textLight: 0x6A4BD6, textDark: 0xB89EFA,
                                     ringLight: 0x8F6CF2, ringDark: 0xB89EFA, onAccent: 0xFFFFFF, gradientTop: 0xC3A8FF)
        case .rot: AccentPalette(fill: 0xFA2D48, textLight: 0xC8102E, textDark: 0xFF6B7D,
                                 ringLight: 0xE3243B, ringDark: 0xFF5C70, onAccent: 0xFFFFFF, gradientTop: 0xFF8A98)
        case .blau: AccentPalette(fill: 0x0A84FF, textLight: 0x0064D2, textDark: 0x5EAEFF,
                                  ringLight: 0x0A7AF0, ringDark: 0x4DA3FF, onAccent: 0xFFFFFF, gradientTop: 0x7DB6FF)
        case .gruen: AccentPalette(fill: 0x249B43, textLight: 0x1A7433, textDark: 0x4CD472,
                                   ringLight: 0x22913F, ringDark: 0x3CC864, onAccent: 0xFFFFFF, gradientTop: 0x86EFAC)
        case .orange: AccentPalette(fill: 0xF5900A, textLight: 0x9E4F00, textDark: 0xFFB340,
                                    ringLight: 0xC26A00, ringDark: 0xFF9F0A, onAccent: 0x1D1D1F, gradientTop: 0xFFC56B)
        case .graphit: AccentPalette(fill: 0x6E6E73, textLight: 0x56565C, textDark: 0xC7C7CC,
                                     ringLight: 0x6E6E73, ringDark: 0xA1A1A6, onAccent: 0xFFFFFF, gradientTop: 0xA1A1A6)
        }
    }
}

/// Opaque background hex values, shared by `Theme` and the contrast test.
nonisolated enum ThemeHex {
    static let windowBgLight: UInt32 = 0xECECEE
    static let windowBgDark: UInt32 = 0x1E1E20
    static let cardLight: UInt32 = 0xF7F7F8
    static let cardDark: UInt32 = 0x2A2A2D
    static let fgLight: UInt32 = 0x1D1D1F
    static let fgDark: UInt32 = 0xF5F5F7
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
    var sidebarPanel: Color { dark ? Color(hex: 0x2A2A2B) : Color(hex: 0xF1F1F2) }
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
    var fg2: Color { dark ? Color(hex: 0xEBEBF5, opacity: 0.6) : Color(hex: 0x3C3C43, opacity: 0.64) }
    var fg3: Color { dark ? Color(hex: 0xEBEBF5, opacity: 0.36) : Color(hex: 0x3C3C43, opacity: 0.42) }
    /// Running sentences (onboarding, explanations): about 5.5:1 on the window in light mode.
    var prose: Color { dark ? fg2 : Color(hex: 0x3C3C43, opacity: 0.80) }
    var sideGroup: Color { dark ? Color(hex: 0xEBEBF5, opacity: 0.42) : Color(hex: 0x3C3C43, opacity: 0.55) }

    // MARK: Interaction
    var sideSel: Color { dark ? .white.opacity(0.09) : .black.opacity(0.075) }
    var rowHover: Color { dark ? .white.opacity(0.05) : .black.opacity(0.035) }
    var field: Color { dark ? .white.opacity(0.08) : .black.opacity(0.05) }
    var chip: Color { dark ? .white.opacity(0.1) : .black.opacity(0.06) }
    var chipActive: Color { dark ? .white.opacity(0.18) : .black.opacity(0.12) }

    // MARK: Accent
    var accent: Color { Color(hex: palette.fill) }
    var accentText: Color { Color(hex: dark ? palette.textDark : palette.textLight) }
    var ring: Color { Color(hex: dark ? palette.ringDark : palette.ringLight) }
    /// Text and glyphs on an accent fill (primary button).
    var onAccent: Color { Color(hex: palette.onAccent) }
    /// Quiet accent background (badges, flashes).
    var accentSoft: Color { accent.opacity(dark ? 0.22 : 0.12) }
    var accentGradient: [Color] { [Color(hex: palette.gradientTop), Color(hex: palette.fill)] }

    // MARK: Controls
    var switchOff: Color { dark ? .white.opacity(0.17) : Color(hex: 0xD4D4D9) }
    var knob: Color { .white }
    var knobShadow: Color { .black.opacity(0.25) }
    var trackOff: Color { dark ? .white.opacity(0.15) : Color(hex: 0xD6D6DB) }
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
    var strike: Color { dark ? Color(hex: 0xFF6B6B) : Color(hex: 0xD9363E) }
    var ok: Color { Color(hex: 0x30D158) }
    var warn: Color { Color(hex: 0xFF9F0A) }
    var idle: Color { fg3 }
    /// Status colours as text on window/card backgrounds (>= 4.5:1).
    var okText: Color { dark ? ok : Color(hex: 0x1E7B34) }
    var warnText: Color { dark ? warn : Color(hex: 0x8A4B00) }

    // MARK: Window chrome in renders
    var trafficRed: Color { Color(hex: 0xFF5F57) }
    var trafficYellow: Color { Color(hex: 0xFEBC2E) }
    var trafficGreen: Color { Color(hex: 0x28C840) }
    var trafficEdge: Color { .black.opacity(0.12) }
}
