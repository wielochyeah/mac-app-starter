import SwiftUI

// Sample pages built only from the window module's components, for renders and the gallery.
// Fixed data, so every render is the same. Not registered as pages of the app.

enum WindowSamples {
    struct Collection: Identifiable {
        let id: String
        let symbol: String
        let name: () -> String
        let kind: () -> String
        let count: Int

        var subtitle: String { WindowSampleText.entries(count) }
    }

    static let collections: [Collection] = [
        Collection(id: "hikes", symbol: "figure.hiking", name: { WindowSampleText.hikes }, kind: { WindowSampleText.outdoor }, count: 6),
        Collection(id: "recipes", symbol: "fork.knife", name: { WindowSampleText.recipes }, kind: { WindowSampleText.kitchen }, count: 24),
        Collection(id: "reading", symbol: "books.vertical.fill", name: { WindowSampleText.reading }, kind: { WindowSampleText.books }, count: 9),
        Collection(id: "garden", symbol: "leaf.fill", name: { WindowSampleText.garden }, kind: { WindowSampleText.outdoor }, count: 14),
        Collection(id: "workshop", symbol: "hammer.fill", name: { WindowSampleText.workshop }, kind: { WindowSampleText.making }, count: 5),
        Collection(id: "photos", symbol: "camera.fill", name: { WindowSampleText.photos }, kind: { WindowSampleText.outdoor }, count: 31),
        Collection(id: "italian", symbol: "character.bubble.fill", name: { WindowSampleText.italian }, kind: { WindowSampleText.learning }, count: 40),
        Collection(id: "practice", symbol: "music.note", name: { WindowSampleText.practice }, kind: { WindowSampleText.learning }, count: 7),
    ]

    static func collection(_ id: String) -> Collection { collections.first { $0.id == id } ?? collections[0] }

    struct Route {
        let id: String
        let name: () -> String
        let region: String
        let km: Double
        let symbol: String
    }

    static let routes: [Route] = [
        Route(id: "feldberg", name: { WindowSampleText.routeFeldberg }, region: "Taunus", km: 14.2, symbol: "mountain.2.fill"),
        Route(id: "lahn", name: { WindowSampleText.routeLahn }, region: "Lahntal", km: 18.5, symbol: "water.waves"),
        Route(id: "rheinsteig", name: { WindowSampleText.routeRheinsteig }, region: "Mittelrhein", km: 21.0, symbol: "signpost.right.fill"),
        Route(id: "vineyard", name: { WindowSampleText.routeVineyard }, region: "Rheingau", km: 9.8, symbol: "leaf.fill"),
        Route(id: "ridge", name: { WindowSampleText.routeRidge }, region: "Rhön", km: 16.4, symbol: "mountain.2.fill"),
        Route(id: "lake", name: { WindowSampleText.routeLake }, region: "Vogelsberg", km: 7.3, symbol: "drop.fill"),
    ]

    static var totalKm: Double { routes.reduce(0) { $0 + $1.km } }

    static var routeItems: [ItemListItem] {
        routes.map { r in
            ItemListItem(id: r.id, title: r.name(), secondary: r.region, meta: WindowSampleText.km(r.km), seed: "route-\(r.id)", symbol: r.symbol)
        }
    }

    static var frequentItems: [ItemListItem] {
        ["recipes", "hikes", "italian", "reading", "garden"].map { id in
            let c = collection(id)
            return ItemListItem(id: c.id, title: c.name(), secondary: c.kind(), meta: c.subtitle, seed: c.id, symbol: c.symbol)
        }
    }

    /// Collections whose name or kind matches the query (each word, case and accents ignored).
    static func matching(_ query: String) -> [Collection] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return collections }
        return collections.filter { ListSearch.matches($0.name(), $0.kind(), query: q) }
    }

    // MARK: Sidebar of the sample window

    static func page(_ id: String, _ section: PageSection, _ order: Int, _ symbol: String, _ title: @escaping () -> String) -> AppPage {
        AppPage(id: id, section: section, order: order, title: title, symbol: symbol) { AnyView(EmptyView()) }
    }

    static var sidebarPages: [AppPage] {
        [
            page("overview", .main, 0, "house.fill") { WindowSampleText.overview },
            page("favorites", .main, 1, "star.fill") { WindowSampleText.favorites },
            page("recent", .library, 0, "clock.fill") { WindowSampleText.recent },
            page("all", .library, 1, "square.grid.2x2.fill") { WindowSampleText.allEntries },
            page("hikes", .collections, 0, "figure.hiking") { WindowSampleText.hikes },
            page("recipes", .collections, 1, "fork.knife") { WindowSampleText.recipes },
            page("reading", .collections, 2, "books.vertical.fill") { WindowSampleText.reading },
            page("garden", .collections, 3, "leaf.fill") { WindowSampleText.garden },
        ]
    }

    static func tile(_ c: Collection, selected: Bool = false, hover: Bool = false) -> Tile {
        Tile(title: c.name(), subtitle: c.subtitle, seed: c.id, symbol: c.symbol, isSelected: selected,
             action: ArtworkAction(symbol: "arrow.up.right", label: WindowSampleText.open) {},
             more: ArtworkAction(symbol: "ellipsis", label: WindowText.more) {},
             previewHover: hover)
    }
}

/// The overview: hero, a shelf of recently opened collections, a list of frequently used ones.
struct SampleOverviewPage: View {
    var body: some View {
        let hikes = WindowSamples.collection("hikes")
        PageScaffold(WindowSampleText.overview) {
            HeroHeader(eyebrow: WindowSampleText.featured, title: hikes.name(), subtitle: WindowSampleText.hikesSummary,
                       seed: "hero-\(hikes.id)", symbol: hikes.symbol,
                       primary: HeaderAction(WindowSampleText.open) {},
                       secondary: HeaderAction(WindowSampleText.addFavorite, symbol: "star") {})
            Shelf(WindowSampleText.recent, seeAll: {}, items: WindowSamples.collections) { c in
                WindowSamples.tile(c, hover: c.id == "recipes")
            }
            VStack(alignment: .leading, spacing: Space.s) {
                PageSectionTitle(WindowSampleText.frequentlyUsed)
                ItemList(items: WindowSamples.frequentItems, leading: .artwork)
            }
        }
    }
}

/// A collection's page: album-like header and the entries as a list.
struct SampleDetailPage: View {
    var body: some View {
        let hikes = WindowSamples.collection("hikes")
        PageScaffold(hikes.name(), showsTitle: false) {
            DetailHeader(eyebrow: WindowSampleText.collection, title: hikes.name(), subtitle: hikes.kind(),
                         meta: WindowSampleText.hikesMeta(WindowSamples.routes.count, km: WindowSamples.totalKm),
                         description: WindowSampleText.hikesDescription, seed: hikes.id, symbol: hikes.symbol,
                         primary: HeaderAction(WindowSampleText.open) {},
                         secondary: HeaderAction(WindowSampleText.addFavorite, symbol: "star") {})
            ItemList(items: WindowSamples.routeItems, leading: .index,
                     columns: ItemListColumns(title: WindowSampleText.columnTitle, secondary: WindowSampleText.columnRegion,
                                              meta: WindowSampleText.columnLength),
                     selection: .constant("rheinsteig"), previewHovered: "vineyard")
        }
    }
}

/// All collections as a grid, filtered by the toolbar search (`\.windowSearch`).
struct SampleLibraryPage: View {
    @Environment(\.windowSearch) private var query

    var body: some View {
        let found = WindowSamples.matching(query)
        if found.isEmpty {
            EmptyPage.noResults(query)
        } else {
            PageScaffold(WindowSampleText.allEntries,
                         subtitle: query.isEmpty ? WindowSampleText.entries(found.count) : WindowSampleText.results(found.count, query)) {
                TileGrid(items: found) { c in WindowSamples.tile(c, selected: c.id == "garden") }
            }
        }
    }
}
