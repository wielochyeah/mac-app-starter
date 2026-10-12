import SwiftUI

/// A button in a header (hero, detail): title, optional SF Symbol, action.
struct HeaderAction {
    let title: String
    var symbol: String?
    let perform: () -> Void

    init(_ title: String, symbol: String? = nil, perform: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.perform = perform
    }
}

/// The two buttons of a header: one primary, one secondary (one primary action per view). On
/// artwork (`onArtwork`) the secondary button is dark glass with white text in both schemes; the
/// scheme's own secondary style would turn pale on light artwork in dark mode.
struct HeaderActions: View {
    var primary: HeaderAction?
    var secondary: HeaderAction?
    var onArtwork = false

    var body: some View {
        if primary != nil || secondary != nil {
            HStack(spacing: Space.s) {
                if let primary {
                    Button(action: primary.perform) { label(primary) }.buttonStyle(.primary)
                }
                if let secondary {
                    if onArtwork {
                        Button(action: secondary.perform) { label(secondary) }.buttonStyle(OnArtworkButtonStyle())
                    } else {
                        Button(action: secondary.perform) { label(secondary) }.buttonStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func label(_ action: HeaderAction) -> some View {
        if let symbol = action.symbol {
            Label(action.title, systemImage: symbol)
        } else {
            Text(action.title)
        }
    }
}

/// The secondary button over artwork: the kit button's metrics, a dark fill, white label and edge.
struct OnArtworkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OnArtworkButtonBody(label: configuration.label, pressed: configuration.isPressed)
    }
}

private struct OnArtworkButtonBody<Label: View>: View {
    let label: Label
    let pressed: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
        label
            .font(TypeScale.bodyMedium)
            .foregroundStyle(t.onArtwork)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Space.m)
            .frame(minWidth: Metrics.buttonMinWidth, minHeight: Metrics.buttonHeight)
            .background(shape.fill(t.artworkButton))
            .overlay(shape.strokeBorder(t.artworkButtonEdge, lineWidth: Metrics.hairline))
            .contentShape(shape)
            .opacity(enabled ? 1 : Metrics.disabledOpacity)
            .scaleEffect(pressed ? Motion.pressScale : 1)
            .animation(Motion.press, value: pressed)
    }
}

/// The hero's picture: artwork plus a scrim that is solid under the whole text column and fades
/// out only to the right of it, so white text keeps at least 4.5:1 on any seed and accent. The
/// glyph shows only where it fits beside the text column (never under the title).
struct HeroBackdrop: View {
    let seed: String
    var symbol: String?
    @Environment(\.colorScheme) private var scheme

    /// Width the text column needs, insets included.
    static var textColumn: CGFloat { Metrics.Window.heroTextWidth + Space.l + Space.l }

    /// The glyph needs the text column plus its own width and trailing distance.
    static func showsGlyph(width: CGFloat, height: CGFloat) -> Bool {
        width >= textColumn + height * (Metrics.Window.artworkGlyphWide + Metrics.Window.artworkGlyphTrailing)
    }

    var body: some View {
        let t = Theme(scheme)
        GeometryReader { geo in
            let solid = min(1, Self.textColumn / max(geo.size.width, 1))
            ZStack {
                Artwork(seed: seed, cornerRadius: Radius.hero)
                LinearGradient(stops: [
                    .init(color: t.artworkScrim, location: 0),
                    .init(color: t.artworkScrim, location: solid),
                    .init(color: t.artworkScrim.opacity(0), location: 1),
                ], startPoint: .leading, endPoint: .trailing)
                .clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
                // above the scrim, so it stays white
                if let symbol, Self.showsGlyph(width: geo.size.width, height: geo.size.height) {
                    ArtworkGlyph(symbol: symbol, placement: .trailing, size: geo.size)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A wide artwork banner with eyebrow, title, subtitle and up to two actions over a scrim (the
/// feature at the top of Music "Home"). Same picture in light and dark; the text is always white.
///
///     HeroHeader(eyebrow: T.featured, title: c.name, subtitle: c.summary, seed: c.id, symbol: c.symbol,
///                primary: HeaderAction(CommonText.open, symbol: "arrow.right") { open(c) })
struct HeroHeader: View {
    var eyebrow: String?
    let title: String
    var subtitle: String?
    let seed: String
    var symbol: String?
    var primary: HeaderAction?
    var secondary: HeaderAction?
    var height: CGFloat
    @Environment(\.colorScheme) private var scheme

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil, seed: String, symbol: String? = nil,
         primary: HeaderAction? = nil, secondary: HeaderAction? = nil, height: CGFloat = Metrics.Window.heroHeight) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.seed = seed
        self.symbol = symbol
        self.primary = primary
        self.secondary = secondary
        self.height = height
    }

    var body: some View {
        let t = Theme(scheme)
        ZStack(alignment: .bottomLeading) {
            HeroBackdrop(seed: seed, symbol: symbol)
            VStack(alignment: .leading, spacing: Space.xxs) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(TypeScale.secondarySemibold)
                        .foregroundStyle(t.onArtwork)
                }
                Text(title)
                    .font(TypeScale.heroTitle)
                    .foregroundStyle(t.onArtwork)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(TypeScale.lede)
                        .foregroundStyle(t.onArtwork)
                        .lineLimit(2)
                }
                HeaderActions(primary: primary, secondary: secondary, onArtwork: true)
                    .padding(.top, Space.s)
            }
            .frame(maxWidth: Metrics.Window.heroTextWidth, alignment: .leading)
            .padding(Space.l)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .compositingGroup()
        .shadow(color: t.panelShadow, radius: Space.s, y: Space.xxs)
        .accessibilityElement(children: .contain)
    }
}
