import SwiftUI

/// A titled row of tiles that scrolls sideways (Music "Recently Played"). The row runs out to the
/// window edges while its first tile lines up with the page title (`\.windowPageInset`).
///
///     Shelf(PageText.recent, seeAll: { select("recent") }, items: recent) { item in
///         Tile(title: item.name, subtitle: item.detail, seed: item.id, symbol: item.symbol)
///     }
struct Shelf<Item: Identifiable, TileView: View>: View {
    let title: String
    var subtitle: String?
    var seeAll: (() -> Void)?
    let items: [Item]
    var tileWidth: CGFloat
    let tile: (Item) -> TileView
    @Environment(\.renderStatic) private var renderStatic
    @Environment(\.windowPageInset) private var inset

    init(_ title: String, subtitle: String? = nil, seeAll: (() -> Void)? = nil, items: [Item],
         tileWidth: CGFloat = Metrics.Window.tile, @ViewBuilder tile: @escaping (Item) -> TileView) {
        self.title = title
        self.subtitle = subtitle
        self.seeAll = seeAll
        self.items = items
        self.tileWidth = tileWidth
        self.tile = tile
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            PageSectionTitle(title, subtitle: subtitle, seeAll: seeAll)
            if renderStatic, let first = items.first {
                // A row wider than the page must not widen the page: one hidden tile gives the
                // height, the row hangs off it as an overlay and is clipped at the window edge.
                tile(first).frame(width: tileWidth)
                    .padding(.vertical, Metrics.tileRingOutset)
                    .hidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, inset)
                    .overlay(alignment: .topLeading) { row.fixedSize().padding(.leading, inset) }
                    .clipped()
                    .padding(.horizontal, -inset)
            } else {
                ScrollView(.horizontal, showsIndicators: false) { row }
                    .contentMargins(.horizontal, inset, for: .scrollContent)
                    .padding(.horizontal, -inset)
            }
        }
    }

    private var row: some View {
        LazyHStack(alignment: .top, spacing: Space.tileGap) {
            ForEach(items) { item in
                tile(item).frame(width: tileWidth)
            }
        }
        // the selection ring sits 4 pt outside a tile
        .padding(.vertical, Metrics.tileRingOutset)
    }
}
