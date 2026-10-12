import SwiftUI

/// Tiles in an adaptive grid that fills the page width (Music "Albums").
///
///     TileGrid(items: filtered) { item in Tile(…) }
struct TileGrid<Item: Identifiable, TileView: View>: View {
    let items: [Item]
    var minimum: CGFloat
    var maximum: CGFloat
    let tile: (Item) -> TileView

    init(items: [Item], minimum: CGFloat = Metrics.Window.tileMin, maximum: CGFloat = Metrics.Window.tileMax,
         @ViewBuilder tile: @escaping (Item) -> TileView) {
        self.items = items
        self.minimum = minimum
        self.maximum = maximum
        self.tile = tile
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: Space.tileGap, alignment: .top)],
                  alignment: .leading, spacing: Space.l) {
            ForEach(items) { item in tile(item) }
        }
    }
}
