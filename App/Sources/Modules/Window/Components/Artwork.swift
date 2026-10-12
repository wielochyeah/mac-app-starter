import SwiftUI

/// What a seed string turns into: a hue shift away from the accent, the gradient direction, where
/// the light falls and how big it is. Same seed, same picture, on every Mac and every launch
/// (FNV-1a + SplitMix64, not `hashValue`, which changes per process).
nonisolated struct ArtworkRecipe: Equatable, Sendable {
    /// Degrees the accent gradient is turned on the colour wheel (-60 … 60).
    let hueShift: Double
    /// Extra turn of the light spot against the base (20 … 70 degrees, either way).
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
    /// 0.9 … 1.15
    let saturation: Double

    init(seed: String) {
        var rng = SplitMix64(seed: Self.hash(seed))
        hueShift = rng.next(in: -60...60)
        let lightTurn = rng.next(in: 20...70)
        lightShift = rng.nextBool() ? lightTurn : -lightTurn
        let angle = rng.next(in: 0..<360) * .pi / 180
        start = UnitPoint(x: 0.5 - cos(angle) / 2, y: 0.5 - sin(angle) / 2)
        end = UnitPoint(x: 0.5 + cos(angle) / 2, y: 0.5 + sin(angle) / 2)
        light = UnitPoint(x: rng.next(in: 0.1...0.9), y: rng.next(in: 0.05...0.5))
        lightSize = rng.next(in: 0.7...1.2)
        shade = UnitPoint(x: 1 - light.x, y: rng.next(in: 0.65...1.0))
        shadeSize = rng.next(in: 0.6...1.0)
        saturation = rng.next(in: 0.9...1.15)
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

    /// The four colours of the picture: the accent's gradient turned by `hueShift`, the light spot
    /// turned further, the shade a darker bottom colour. Computed here, not with SwiftUI's
    /// `hueRotation`, because offscreen renders drop that filter and would not match the window.
    func colors(_ palette: AccentPalette) -> (top: ArtworkRGB, bottom: ArtworkRGB, light: ArtworkRGB, shade: ArtworkRGB) {
        // the light top colour is deepened a little so white glyphs keep their edge
        let top = ArtworkRGB(hex: palette.gradientTop).rotated(hueShift, saturation: saturation * 1.2, brightness: 0.93)
        let bottom = ArtworkRGB(hex: palette.brand).rotated(hueShift, saturation: saturation)
        let light = ArtworkRGB(hex: palette.gradientTop).rotated(hueShift + lightShift, saturation: saturation)
        let shade = ArtworkRGB(hex: palette.brand).rotated(hueShift - lightShift / 2, saturation: saturation, brightness: 0.62)
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

    /// Turned by `degrees` on the colour wheel, saturation and brightness scaled (clamped to 0 … 1).
    func rotated(_ degrees: Double, saturation: Double = 1, brightness: Double = 1) -> ArtworkRGB {
        let c = hsb
        return ArtworkRGB(h: c.h + degrees / 360, s: min(1, max(0, c.s * saturation)), b: min(1, max(0, c.b * brightness)))
    }
}

/// Generated art for tiles, lists and headers: the accent gradient turned on the colour wheel by a
/// seed, a light and a shade spot, and an SF Symbol. No image files; the same seed always draws the
/// same picture, and every picture belongs to the app's accent family. Fills its frame.
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
                glyph(t, side: side, size: geo.size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(t.artworkEdge, lineWidth: Metrics.hairline))
        }
        .accessibilityHidden(true)
    }

    private func background(_ r: ArtworkRecipe, size: CGSize, long: CGFloat) -> some View {
        let c = r.colors(AccentPalette.of(AppConfig.accent))
        let light = Color(artwork: c.light), shade = Color(artwork: c.shade)
        return ZStack {
            LinearGradient(colors: [Color(artwork: c.top), Color(artwork: c.bottom)], startPoint: r.start, endPoint: r.end)
            Circle()
                .fill(RadialGradient(colors: [light, light.opacity(0)], center: .center, startRadius: 0, endRadius: long * r.lightSize / 2))
                .frame(width: long * r.lightSize, height: long * r.lightSize)
                .position(x: size.width * r.light.x, y: size.height * r.light.y)
            Circle()
                .fill(RadialGradient(colors: [shade.opacity(0.75), shade.opacity(0)], center: .center, startRadius: 0, endRadius: long * r.shadeSize / 2))
                .frame(width: long * r.shadeSize, height: long * r.shadeSize)
                .position(x: size.width * r.shade.x, y: size.height * r.shade.y)
        }
    }

    @ViewBuilder
    private func glyph(_ t: Theme, side: CGFloat, size: CGSize) -> some View {
        if let symbol {
            switch placement {
            case .center:
                Image(systemName: symbol)
                    .symbolFont(side * Metrics.Window.artworkGlyph, weight: .semibold)
                    .foregroundStyle(t.onArtwork.opacity(0.92))
                    .shadow(color: t.artworkShadow, radius: side * 0.05, y: side * 0.015)
            case .trailing:
                Image(systemName: symbol)
                    .symbolFont(side * Metrics.Window.artworkGlyphWide, weight: .semibold)
                    .foregroundStyle(t.onArtwork.opacity(0.9))
                    .shadow(color: t.artworkShadow, radius: side * 0.05, y: side * 0.015)
                    .padding(.trailing, side * 0.3)
                    .frame(width: size.width, height: size.height, alignment: .trailing)
            case .none:
                EmptyView()
            }
        }
    }
}
