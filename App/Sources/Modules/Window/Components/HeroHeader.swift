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

/// The two buttons of a header: one primary, one secondary (one primary action per view).
struct HeaderActions: View {
    var primary: HeaderAction?
    var secondary: HeaderAction?

    var body: some View {
        if primary != nil || secondary != nil {
            HStack(spacing: Space.s) {
                if let primary {
                    Button(action: primary.perform) { label(primary) }.buttonStyle(.primary)
                }
                if let secondary {
                    Button(action: secondary.perform) { label(secondary) }.buttonStyle(.secondary)
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
        let shape = RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
        ZStack(alignment: .bottomLeading) {
            Artwork(seed: seed, symbol: symbol, placement: .trailing, cornerRadius: Radius.hero)
            LinearGradient(colors: [t.artworkScrim, t.artworkScrim.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .clipShape(shape)
            VStack(alignment: .leading, spacing: Space.xxs) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(TypeScale.secondarySemibold)
                        .foregroundStyle(t.onArtworkSecondary)
                }
                Text(title)
                    .font(TypeScale.heroTitle)
                    .foregroundStyle(t.onArtwork)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(TypeScale.lede)
                        .foregroundStyle(t.onArtworkSecondary)
                        .lineLimit(2)
                }
                HeaderActions(primary: primary, secondary: secondary)
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
