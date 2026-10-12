import SwiftUI

// Tokens for the notch island / capsule and the "Mac desktop" stage around it (onboarding hero,
// settings tiles, island renders). Values from VoiceBud (Palette, IslandMetrics, HubWallpaper;
// notes vb-island-notch §4.2, §4.3, §12 and vb-onboarding-hub §2.8). The island is always drawn
// on pure black, so its colours do not change with light/dark.

/// Colours on the island and capsule surface.
enum IslandPalette {
    /// The surface: opaque black, no material (it must melt into the hardware notch).
    static let surface = Color.black
    /// Text levels: titles, body/preview text, timer, meta line, dim hints.
    static let text = Color.white
    static let body = Color.white.opacity(0.88)
    static let timer = Color.white.opacity(0.55)
    static let meta = Color.white.opacity(0.5)
    static let dim = Color.white.opacity(0.42)
    /// Recording dot, warning text, error glyph.
    static let rec = Color(hex: 0xFF453A)
    static let warning = Color(hex: 0xFFD27A)
    static let error = Color(hex: 0xFF6B61)
    /// Small buttons on the island (Copy): white 14 %.
    static let button = Color.white.opacity(0.14)
    /// Capsule drop shadow (the notch island has none); hanging cards a bit darker.
    static let shadow = Color.black.opacity(0.5)
    static let shadowHanging = Color.black.opacity(0.6)
}

/// An accent as used on black: `line` for strokes and labels, `lo`/`hi` for the two ends of
/// waveform bars and glows.
struct IslandAccent {
    let line: Color
    let lo: Color
    let hi: Color

    init(line: UInt32, lo: UInt32, hi: UInt32) {
        self.line = Color(hex: line)
        self.lo = Color(hex: lo)
        self.hi = Color(hex: hi)
    }

    /// The app's accent on the island (violett = VoiceBud's dictate mode).
    static func of(_ accent: AccentName = AppConfig.accent) -> IslandAccent {
        switch accent {
        case .violett: IslandAccent(line: 0xB89EFA, lo: 0x8F6CF2, hi: 0xE4DAFF)
        case .rot: IslandAccent(line: 0xFF6B7D, lo: 0xFA2D48, hi: 0xFFD6DC)
        case .blau: IslandAccent(line: 0x5EAEFF, lo: 0x0A84FF, hi: 0xD6EBFF)
        case .gruen: IslandAccent(line: 0x4CD472, lo: 0x249B43, hi: 0xCFF5DA)
        case .orange: IslandAccent(line: 0xFFC56B, lo: 0xE89B2E, hi: 0xFFE7B8)
        case .graphit: IslandAccent(line: 0xC7C7CC, lo: 0x8E8E93, hi: 0xECECF0)
        }
    }

    /// Further modes of one app (VoiceBud: prompt, command, screen text).
    static let teal = IslandAccent(line: 0x6BE6D4, lo: 0x2FBFAA, hi: 0xC8FAF1)
    static let amber = IslandAccent(line: 0xFFC56B, lo: 0xE89B2E, hi: 0xFFE7B8)
    static let sky = IslandAccent(line: 0x8CCBFF, lo: 0x3E92F0, hi: 0xDCEEFF)
}

/// The desktop picture behind island renders, the onboarding hero and settings tiles.
enum Wallpaper {
    /// Dark: violet night (#5A4BB0, #2C2470, #130F33 from the centre out), light: peach dusk (#FBE3D2,
    /// #EFBFAE, #C497B6).
    static func gradient(dark: Bool) -> EllipticalGradient {
        let stops: [Gradient.Stop] = dark
            ? [.init(color: Color(hex: 0x5A4BB0), location: 0), .init(color: Color(hex: 0x2C2470), location: 0.42),
               .init(color: Color(hex: 0x130F33), location: 1)]
            : [.init(color: Color(hex: 0xFBE3D2), location: 0), .init(color: Color(hex: 0xEFBFAE), location: 0.38),
               .init(color: Color(hex: 0xC497B6), location: 1)]
        return EllipticalGradient(stops: stops, center: UnitPoint(x: dark ? 0.18 : 0.75, y: 0),
                                  startRadiusFraction: 0, endRadiusFraction: 1.25)
    }

    /// The menu bar band over the wallpaper (#120E2E at 16 %), as tall as the notch.
    static let menuBarTint = Color(hex: 0x120E2E, opacity: 0.16)
    /// Menu bar text and glyphs drawn on the wallpaper.
    static func menuBarText(dark: Bool) -> Color { dark ? .white.opacity(0.92) : .black.opacity(0.85) }
}

extension Theme {
    /// The wallpaper for this scheme (`Wallpaper.gradient(dark:)`).
    var wallpaper: EllipticalGradient { Wallpaper.gradient(dark: dark) }
    var menuBarTint: Color { Wallpaper.menuBarTint }
    var menuBarText: Color { Wallpaper.menuBarText(dark: dark) }
}

extension Radius {
    /// Island and capsule corners (VoiceBud SPEC §0).
    enum Island {
        /// Top "ear" corners where the island meets the menu bar.
        static let earCollapsed: CGFloat = 8
        static let earExpanded: CGFloat = 13
        /// Bottom corners: compact island, card, live text card.
        static let bottomCompact: CGFloat = 12
        static let bottomCard: CGFloat = 19
        static let bottomLive: CGFloat = 24
        /// The drawn hardware notch (bottom corners) in renders.
        static let notch: CGFloat = 9
        /// Capsule (Macs without notch): pill, cards, the seed it grows from.
        static let capsule: CGFloat = 20
        static let capsuleCard: CGFloat = 22
        static let seed: CGFloat = 4
    }
}

extension Metrics {
    /// Island and capsule sizes (VoiceBud IslandMetrics / CapsuleView).
    enum Island {
        /// Extra width on each side of the notch while compact (recording / working).
        static let compactWing: CGFloat = 50
        static let doneWidth: CGFloat = 400
        static let liveWidth: CGFloat = 470
        /// Horizontal inset of ear content and body text.
        static let bodyPad: CGFloat = 14
        /// Collapsed island is this much narrower than the hardware notch.
        static let collapsedInset: CGFloat = 8
        static let pillHeight: CGFloat = 40
        static let pillFallbackWidth: CGFloat = 128
        static let seed = CGSize(width: 36, height: 8)
        /// Capsule top below the menu bar, and the gap to a hanging live card.
        static let capsuleTop: CGFloat = 8
        static let cardGap: CGFloat = 6
        static let copyButtonHeight: CGFloat = 22
        static let recDot: CGFloat = 6
        /// Menu bar height of a notched 14" MacBook in renders (no-notch Macs: 25).
        static let renderMenuBar: CGFloat = 33
        static let renderNotch = CGSize(width: 185, height: 32)
    }
}

extension TypeScale {
    /// Text read at length: live text on the island, history entries.
    static let reading = Font.system(size: 13.5)
    /// Island preview and full text, tile titles.
    static let preview = Font.system(size: 12.5)
    /// Island error text, value capsule, tile titles that must stand out.
    static let previewMedium = Font.system(size: 12.5, weight: .medium)
    /// Line spacing of island preview text (live text uses `proseLineSpacing`).
    static let previewLineSpacing: CGFloat = 2.5
}

extension Motion.Island {
    /// Press feedback on island buttons: opacity and scale on `Motion.fade`.
    static let pressOpacity: Double = 0.6
    static let pressScale: CGFloat = 0.96
    /// The hanging live card fades in and out (after `cardOutDelay`) so the seed never lingers.
    static let cardIn = Animation.easeOut(duration: 0.12)
    static let cardOut = Animation.easeIn(duration: 0.22)
    static let cardOutDelay: Double = 0.1
}
