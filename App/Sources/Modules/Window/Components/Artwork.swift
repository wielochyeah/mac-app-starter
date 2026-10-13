import SwiftUI

/// What a seed string turns into: a hue turned away from the accent, the gradient direction, where
/// the light falls and how big it is. Same seed, same picture, on every Mac and every launch
/// (FNV-1a + SplitMix64, not `hashValue`, which changes per process).
///
/// The hue family is wide on purpose: a shelf of covers in one accent colour reads as a coloured
/// wash, not as different things (Music shows each album in its own colours). Every picture stays
/// within a quarter turn of the accent on either side, a little calmer than the accent itself, and
/// dark enough for white glyphs.
nonisolated struct ArtworkRecipe: Equatable, Sendable {
    /// How far the base gradient may turn away from the accent on the colour wheel (degrees):
    /// a violet app gets teal, blue, indigo, violet, magenta and rose.
    static let maxHueShift = 90.0
    /// How far the light spot may turn further from the base (degrees).
    static let maxLightTurn = 30.0
    /// The light spot's widest turn from the accent.
    static let maxLightHue = maxHueShift + maxLightTurn
    /// Brightest relative luminance any colour of the picture may have: white glyphs keep at least
    /// 3:1 against it ((1 + 0.05) / (0.28 + 0.05) = 3.18).
    static let maxLuminance = 0.28
    /// Saturation against the accent's own (calmer than the controls, never louder).
    static let saturationRange = 0.72...0.95

    /// Degrees the accent gradient is turned on the colour wheel (-90 … 90).
    let hueShift: Double
    /// Extra turn of the light spot against the base (10 … 30 degrees, either way).
    let lightShift: Double
    /// Gradient from `start` to `end` (unit points, opposite corners or edges).
    let start: UnitPoint
    let end: UnitPoint
    /// Centre and diameter (share of the longer side) of the light spot.
    let light: UnitPoint
    let lightSize: Double
    /// Darker spot on the opposite side.
    let shade: UnitPoint
    let shadeSize: Double
    /// Scales the accent's saturation (`saturationRange`).
    let saturation: Double

    init(seed: String) {
        var rng = SplitMix64(seed: Self.hash(seed))
        hueShift = rng.next(in: -Self.maxHueShift...Self.maxHueShift)
        let lightTurn = rng.next(in: 10...Self.maxLightTurn)
        lightShift = rng.nextBool() ? lightTurn : -lightTurn
        let angle = rng.next(in: 0..<360) * .pi / 180
        start = UnitPoint(x: 0.5 - cos(angle) / 2, y: 0.5 - sin(angle) / 2)
        end = UnitPoint(x: 0.5 + cos(angle) / 2, y: 0.5 + sin(angle) / 2)
        light = UnitPoint(x: rng.next(in: 0.1...0.9), y: rng.next(in: 0.05...0.5))
        lightSize = rng.next(in: 0.7...1.2)
        shade = UnitPoint(x: 1 - light.x, y: rng.next(in: 0.65...1.0))
        shadeSize = rng.next(in: 0.6...1.0)
        saturation = rng.next(in: Self.saturationRange)
    }

    /// 64-bit FNV-1a over the UTF-8 bytes.
    static func hash(_ text: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            h ^= UInt64(byte)
            h &*= 0x0000_0100_0000_01B3
        }
        return h
    }

    /// The light spot's turn away from the accent: `hueShift + lightShift` (within ±120).
    var lightHue: Double { hueShift + lightShift }

    /// The four colours of the picture: the accent's gradient turned by `hueShift`, the light spot
    /// turned further, the shade a darker bottom colour. Top, bottom and light are held at or below
    /// `maxLuminance`, so white glyphs stay readable for every accent (orange and green included).
    /// Computed here, not with SwiftUI's `hueRotation`, because offscreen renders drop that filter
    /// and would not match the window. A grey accent (graphit) stays grey: it has no hue to turn.
    func colors(_ palette: AccentPalette) -> (top: ArtworkRGB, bottom: ArtworkRGB, light: ArtworkRGB, shade: ArtworkRGB) {
        let cap = Self.maxLuminance
        let top = ArtworkRGB(hex: palette.gradientTop).rotated(hueShift, saturation: saturation * 1.15).capped(luminance: cap)
        let bottom = ArtworkRGB(hex: palette.brand).rotated(hueShift, saturation: saturation).capped(luminance: cap)
        let light = ArtworkRGB(hex: palette.gradientTop).rotated(lightHue, saturation: saturation).capped(luminance: cap)
        let shade = bottom.rotated(-lightShift / 2, brightness: 0.62)
        return (top, bottom, light, shade)
    }

    struct SplitMix64 {
        var state: UInt64
        init(seed: UInt64) { state = seed }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        /// Uniform in [0, 1).
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
        mutating func next(in range: ClosedRange<Double>) -> Double { range.lowerBound + unit() * (range.upperBound - range.lowerBound) }
        mutating func next(in range: Range<Double>) -> Double { range.lowerBound + unit() * (range.upperBound - range.lowerBound) }
        mutating func nextBool() -> Bool { next() & 1 == 1 }
    }
}

/// An sRGB colour as numbers (0 … 1), so the artwork maths stays testable and off the main actor.
nonisolated struct ArtworkRGB: Equatable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        self.init(r: Double((hex >> 16) & 0xFF) / 255, g: Double((hex >> 8) & 0xFF) / 255, b: Double(hex & 0xFF) / 255)
    }

    /// Hue, saturation, brightness, each 0 … 1.
    var hsb: (h: Double, s: Double, b: Double) {
        let maxV = max(r, g, b), minV = min(r, g, b), delta = maxV - minV
        var hue = 0.0
        if delta > 0 {
            if maxV == r { hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxV == g { hue = (b - r) / delta + 2 }
            else { hue = (r - g) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maxV == 0 ? 0 : delta / maxV, maxV)
    }

    init(h: Double, s: Double, b v: Double) {
        let h6 = (h - floor(h)) * 6, i = Int(h6) % 6, f = h6 - floor(h6)
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch i {
        case 0: self.init(r: v, g: t, b: p)
        case 1: self.init(r: q, g: v, b: p)
        case 2: self.init(r: p, g: v, b: t)
        case 3: self.init(r: p, g: q, b: v)
        case 4: self.init(r: t, g: p, b: v)
        default: self.init(r: v, g: p, b: q)
        }
    }

    /// WCAG relative luminance (0 black … 1 white).
    var luminance: Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// Contrast ratio against another colour (1 … 21).
    func contrast(_ other: ArtworkRGB) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// The same hue and saturation, darkened (HSB brightness) until the luminance is at most `limit`.
    func capped(luminance limit: Double) -> ArtworkRGB {
        guard luminance > limit else { return self }
        var low = 0.0, high = 1.0
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if rotated(0, brightness: mid).luminance > limit { high = mid } else { low = mid }
        }
        return rotated(0, brightness: low)
    }

    /// Turned by `degrees` on the colour wheel, saturation and brightness scaled (clamped to 0 … 1).
    func rotated(_ degrees: Double, saturation: Double = 1, brightness: Double = 1) -> ArtworkRGB {
        let c = hsb
        return ArtworkRGB(h: c.h + degrees / 360, s: min(1, max(0, c.s * saturation)), b: min(1, max(0, c.b * brightness)))
    }
}

private nonisolated struct ArtworkAccentKey: EnvironmentKey {
    static let defaultValue: AccentName? = nil
}

extension EnvironmentValues {
    /// Draws artwork in another accent than the app's (tests and the gallery compare accents).
    var artworkAccent: AccentName? {
        get { self[ArtworkAccentKey.self] }
        set { self[ArtworkAccentKey.self] = newValue }
    }
}

/// Generated art for tiles, lists and headers: the accent gradient turned on the colour wheel by a
/// seed (up to a quarter turn either way), a light and a shade spot, and an SF Symbol. No image
/// files; the same seed always draws the same picture. Fills its frame. The only gradient surface
/// inside page content (DESIGN §8): covers, list artwork and the hero, nowhere else.
///
///     Artwork(seed: item.id, symbol: "leaf.fill").frame(width: 168, height: 168)
struct Artwork: View {
    enum GlyphPlacement { case center, trailing, none }

    let seed: String
    var symbol: String?
    var placement: GlyphPlacement
    /// nil picks by size: `Radius.tile`, or `Radius.artworkSmall` below 64 pt.
    var cornerRadius: CGFloat?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.artworkAccent) private var accent

    init(seed: String, symbol: String? = nil, placement: GlyphPlacement = .center, cornerRadius: CGFloat? = nil) {
        self.seed = seed
        self.symbol = symbol
        self.placement = symbol == nil ? .none : placement
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        let t = Theme(scheme)
        let recipe = ArtworkRecipe(seed: seed)
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let long = max(geo.size.width, geo.size.height)
            let radius = cornerRadius ?? (side < Metrics.Window.artworkSmall ? Radius.artworkSmall : Radius.tile)
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            ZStack {
                background(recipe, size: geo.size, long: long)
                if let symbol { ArtworkGlyph(symbol: symbol, placement: placement, size: geo.size) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(t.artworkEdge, lineWidth: Metrics.hairline))
        }
        .accessibilityHidden(true)
    }

    private func background(_ r: ArtworkRecipe, size: CGSize, long: CGFloat) -> some View {
        let c = r.colors(AccentPalette.of(accent ?? AppConfig.accent))
        let light = Color(artwork: c.light), shade = Color(artwork: c.shade)
        return ZStack {
            LinearGradient(colors: [Color(artwork: c.top), Color(artwork: c.bottom)], startPoint: r.start, endPoint: r.end)
            Circle()
                .fill(RadialGradient(colors: [light, light.opacity(0)], center: .center, startRadius: 0, endRadius: long * r.lightSize / 2))
                .frame(width: long * r.lightSize, height: long * r.lightSize)
                .position(x: size.width * r.light.x, y: size.height * r.light.y)
            Circle()
                .fill(RadialGradient(colors: [shade.opacity(Metrics.Window.artworkShadeStrength), shade.opacity(0)], center: .center,
                                     startRadius: 0, endRadius: long * r.shadeSize / 2))
                .frame(width: long * r.shadeSize, height: long * r.shadeSize)
                .position(x: size.width * r.shade.x, y: size.height * r.shade.y)
        }
    }
}

/// The SF Symbol on artwork: white with a soft shadow, centred or large at the trailing side.
/// Its own view so a header can draw it above a scrim (`HeroBackdrop`).
struct ArtworkGlyph: View {
    let symbol: String
    let placement: Artwork.GlyphPlacement
    let size: CGSize
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let side = min(size.width, size.height)
        switch placement {
        case .center:
            Image(systemName: symbol)
                .symbolFont(side * Metrics.Window.artworkGlyph, weight: .semibold)
                .foregroundStyle(t.onArtwork)
                .shadow(color: t.artworkShadow, radius: side * Metrics.Window.artworkGlyphShadow, y: side * Metrics.Window.artworkGlyphShadowY)
                .frame(width: size.width, height: size.height)
        case .trailing:
            Image(systemName: symbol)
                .symbolFont(side * Metrics.Window.artworkGlyphWide, weight: .semibold)
                .foregroundStyle(t.onArtwork)
                .shadow(color: t.artworkShadow, radius: side * Metrics.Window.artworkGlyphShadow, y: side * Metrics.Window.artworkGlyphShadowY)
                .padding(.trailing, side * Metrics.Window.artworkGlyphTrailing)
                .frame(width: size.width, height: size.height, alignment: .trailing)
        case .none:
            EmptyView()
        }
    }
}
