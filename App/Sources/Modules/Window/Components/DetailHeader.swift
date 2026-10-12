import SwiftUI

/// The header of a detail page (Music album): large artwork on the left, eyebrow, title,
/// subtitle in the accent, a meta line, a short description and the actions on the right.
struct DetailHeader: View {
    var eyebrow: String?
    let title: String
    var subtitle: String?
    var meta: String?
    var description: String?
    let seed: String
    var symbol: String?
    var primary: HeaderAction?
    var secondary: HeaderAction?
    @Environment(\.colorScheme) private var scheme

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil, meta: String? = nil, description: String? = nil,
         seed: String, symbol: String? = nil, primary: HeaderAction? = nil, secondary: HeaderAction? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.meta = meta
        self.description = description
        self.seed = seed
        self.symbol = symbol
        self.primary = primary
        self.secondary = secondary
    }

    var body: some View {
        let t = Theme(scheme)
        HStack(alignment: .bottom, spacing: Space.l) {
            Artwork(seed: seed, symbol: symbol)
                .frame(width: Metrics.Window.detailArtwork, height: Metrics.Window.detailArtwork)
                .compositingGroup()
                .shadow(color: t.artworkShadow, radius: Space.s, y: Space.xxs)
            VStack(alignment: .leading, spacing: Space.xxs) {
                if let eyebrow {
                    Text(eyebrow).font(TypeScale.secondarySemibold).foregroundStyle(t.fg2)
                }
                Text(title)
                    .font(TypeScale.detailTitle)
                    .foregroundStyle(t.fg)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(TypeScale.headline).foregroundStyle(t.accentText).lineLimit(1)
                }
                if let meta {
                    Text(meta).font(TypeScale.secondary).foregroundStyle(t.fg2).lineLimit(1)
                        .padding(.top, Space.hair)
                }
                if let description {
                    Text(description)
                        .font(TypeScale.body)
                        .foregroundStyle(t.prose)
                        .lineSpacing(TypeScale.footnoteLineSpacing)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: Metrics.settingsColumn, alignment: .leading)
                        .padding(.top, Space.xs)
                }
                HeaderActions(primary: primary, secondary: secondary)
                    .padding(.top, Space.s)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }
}
