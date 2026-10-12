import AppKit
import SwiftUI

/// Gallery entries, render scenes (`window.*`) and self-test checks of the window module.
enum WindowCatalog {
    private struct Item {
        let id: String
        let title: () -> String
        var size: CGSize = .zero
        let view: () -> AnyView
    }

    /// Scene names without the `window.` prefix (tests).
    static var names: [String] { items.map(\.id) }

    static func register() {
        for item in items {
            Registry.gallery.append(GalleryEntry(id: "window.\(item.id)", area: "window", title: item.title, content: item.view))
            Registry.renderScenes.append(RenderScene(id: "window.\(item.id)", size: item.size, content: item.view))
        }
        Registry.selfTests += selfTests
    }

    private static var items: [Item] {
        [
            // whole windows
            Item(id: "main", title: { WindowText.galleryMain }) {
                window(selection: "overview") { SampleOverviewPage() }
            },
            Item(id: "home", title: { WindowText.galleryHome }) {
                AnyView(RenderBoard {
                    StaticMainWindow(pages: [HomePage.page], selection: HomePage.id) { HomePage() }
                })
            },
            Item(id: "detail", title: { WindowText.galleryDetail }) {
                window(selection: "hikes") { SampleDetailPage() }
            },
            Item(id: "search", title: { WindowText.gallerySearch }) {
                window(selection: "all", query: WindowSampleText.query) { SampleLibraryPage() }
            },
            Item(id: "search-empty", title: { WindowText.noResultsTitle }) {
                window(selection: "all", query: WindowSampleText.queryNone) { SampleLibraryPage() }
            },
            Item(id: "no-pages", title: { WindowText.galleryNoPages }) {
                AnyView(RenderBoard {
                    StaticMainWindow(pages: [], selection: nil) {
                        EmptyPage.noPages
                    }
                })
            },
            // parts
            Item(id: "sidebar", title: { WindowText.gallerySidebar }) {
                AnyView(StaticSidebar(groups: MainWindowModel.groups(WindowSamples.sidebarPages), selection: "hikes")
                    .frame(width: Metrics.Window.sidebarIdeal, height: Metrics.Window.minSize.height)
                    .padding(Metrics.Window.sidebarInset)
                    .background(SceneBackground()))
            },
            Item(id: "page-scaffold", title: { WindowCodeNames.pageScaffold }, size: CGSize(width: 760, height: 440)) {
                let shown = Array(WindowSamples.collections.prefix(4))
                return AnyView(PageScaffold(WindowSampleText.allEntries, subtitle: WindowSampleText.entries(shown.count)) {
                    TileGrid(items: shown) { c in WindowSamples.tile(c) }
                })
            },
            Item(id: "hero-header", title: { WindowCodeNames.heroHeader }) {
                specimen(width: 820) {
                    let hikes = WindowSamples.collection("hikes")
                    HeroHeader(eyebrow: WindowSampleText.featured, title: hikes.name(), subtitle: WindowSampleText.hikesSummary,
                               seed: "hero-\(hikes.id)", symbol: hikes.symbol,
                               primary: HeaderAction(WindowSampleText.open) {},
                               secondary: HeaderAction(WindowSampleText.addFavorite, symbol: "star") {})
                }
            },
            Item(id: "shelf", title: { WindowCodeNames.shelf }) {
                specimen(width: 820) {
                    Shelf(WindowSampleText.recent, seeAll: {}, items: WindowSamples.collections) { c in WindowSamples.tile(c) }
                }
            },
            Item(id: "tile", title: { WindowText.galleryTileStates }) {
                specimen(width: 620) {
                    HStack(alignment: .top, spacing: Space.tileGap) {
                        WindowSamples.tile(WindowSamples.collection("reading"))
                        WindowSamples.tile(WindowSamples.collection("recipes"), hover: true)
                        WindowSamples.tile(WindowSamples.collection("garden"), selected: true)
                    }
                    .frame(height: Metrics.Window.tile + Space.xxl + Space.s)
                    .padding(Metrics.tileRingOutset)
                }
            },
            Item(id: "tile-grid", title: { WindowCodeNames.tileGrid }) {
                specimen(width: 820) {
                    TileGrid(items: WindowSamples.collections) { c in WindowSamples.tile(c) }
                }
            },
            Item(id: "item-list", title: { WindowCodeNames.itemList }) {
                specimen(width: 760) {
                    ItemList(items: WindowSamples.routeItems, leading: .index,
                             columns: ItemListColumns(title: WindowSampleText.columnTitle, secondary: WindowSampleText.columnRegion,
                                                      meta: WindowSampleText.columnLength),
                             selection: .constant("rheinsteig"), previewHovered: "vineyard")
                    ItemList(items: WindowSamples.frequentItems, leading: .artwork)
                }
            },
            Item(id: "detail-header", title: { WindowCodeNames.detailHeader }) {
                specimen(width: 820) {
                    let hikes = WindowSamples.collection("hikes")
                    DetailHeader(eyebrow: WindowSampleText.collection, title: hikes.name(), subtitle: hikes.kind(),
                                 meta: WindowSampleText.hikesMeta(WindowSamples.routes.count, km: WindowSamples.totalKm),
                                 description: WindowSampleText.hikesDescription, seed: hikes.id, symbol: hikes.symbol,
                                 primary: HeaderAction(WindowSampleText.open) {},
                                 secondary: HeaderAction(WindowSampleText.addFavorite, symbol: "star") {})
                }
            },
            Item(id: "artwork", title: { WindowCodeNames.artwork }) {
                specimen(width: 620) { ArtworkSampleGrid() }
            },
            Item(id: "empty-page", title: { WindowCodeNames.emptyPage }, size: CGSize(width: 760, height: 380)) {
                AnyView(EmptyPage.noResults(WindowSampleText.queryNone))
            },
        ]
    }

    private static func window<Page: View>(selection: String, query: String? = nil, @ViewBuilder page: () -> Page) -> AnyView {
        AnyView(RenderBoard {
            StaticMainWindow(pages: WindowSamples.sidebarPages, selection: selection, query: query,
                             searchPrompt: selection == "all" ? WindowSampleText.searchPrompt : nil) { page() }
        })
    }

    private static func specimen<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> AnyView {
        AnyView(Specimen(width: width) { content() })
    }

    // MARK: Self-test

    private static var selfTests: [SelfTestCheck] {
        [
            SelfTestCheck(id: "window.registration") {
                guard Registry.pages.contains(where: { $0.id == HomePage.id }) else { return "home page not registered" }
                guard AppActions.mainWindowHandler != nil else { return "AppActions.mainWindowHandler not set" }
                guard MainMenu.decorators.count >= 1 else { return "main menu decorator missing" }
                return nil
            },
            SelfTestCheck(id: "window.symbols") {
                let missing = WindowCatalog.symbols.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil }
                return missing.isEmpty ? nil : "unknown SF Symbols: \(missing.joined(separator: ", "))"
            },
            SelfTestCheck(id: "window.chrome") { WindowCatalog.checkLiveWindow() },
            SelfTestCheck(id: "window.render") {
                guard let scene = Registry.renderScenes.first(where: { $0.id == "window.main" }) else { return "window.main missing" }
                let png = RenderRunner.png(scene.content(), size: scene.size, appearance: .light, lang: .de)
                return (png?.count ?? 0) > 50_000 ? nil : "window.main rendered no picture"
            },
        ]
    }

    /// Every SF Symbol the module draws itself (pages registered by others are checked by them).
    static var symbols: [String] {
        ["house.fill", "sidebar.left", "plus", "magnifyingglass", "arrow.up.right", "ellipsis", "star"]
            + BuildingBlock.all.map(\.symbol)
            + WindowSamples.collections.map(\.symbol)
            + WindowSamples.routes.map(\.symbol)
            + WindowSamples.sidebarPages.map(\.symbol)
    }

    /// Builds the real main window offscreen (never shown: `--selftest` is headless), with a model on
    /// a throwaway settings file, and checks the chrome: toolbar with the search field on a page
    /// that enabled search, unified style, hidden title, minimum size.
    static func checkLiveWindow() -> String? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("window-selftest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let settings = Settings(fileURL: dir.appendingPathComponent("settings.json"))
        let model = MainWindowModel(settings: settings)
        let pageID = model.currentPage?.id ?? HomePage.id
        let hadSearch = WindowSearch.isEnabled(pageID)
        if !hadSearch { WindowSearch.enable(page: pageID) }
        defer { if !hadSearch { WindowSearch.disable(page: pageID) } }

        let window = NSWindow(contentRect: NSRect(origin: .zero, size: Metrics.Window.size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingController(rootView: MainWindowController.content(model: model))
        host.sizingOptions = []
        window.contentViewController = host
        window.setContentSize(Metrics.Window.size)
        MainWindowController.configure(window)
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        defer {
            window.contentViewController = nil
            window.close()
        }

        var problems: [String] = []
        if window.isVisible { problems.append("main window became visible") }
        if window.toolbarStyle != .unified { problems.append("toolbar style is not unified") }
        if window.titleVisibility != .hidden { problems.append("title is visible") }
        let min = window.minSize
        if min != Metrics.Window.minSize { problems.append("minimum size \(min), expected \(Metrics.Window.minSize)") }
        if window.frame.size != Metrics.Window.size { problems.append("size \(window.frame.size) after layout") }
        if !window.styleMask.contains(.fullSizeContentView) { problems.append("no full-size content view") }
        if let toolbar = window.toolbar {
            let hasSearch = toolbar.items.contains { $0 is NSSearchToolbarItem || $0.itemIdentifier.rawValue.lowercased().contains("search") }
            if !hasSearch { problems.append("no search field in the toolbar (items: \(toolbar.items.map(\.itemIdentifier.rawValue)))") }
        } else {
            problems.append("no toolbar")
        }
        if FileManager.default.fileExists(atPath: settings.fileURL.path) { problems.append("opening the window wrote settings") }
        return problems.isEmpty ? nil : problems.joined(separator: "; ")
    }
}

/// Window background behind part scenes that are not specimens.
private struct SceneBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View { Theme(scheme).windowBg }
}

/// Twelve seeds in the app's accent family, at tile and list sizes.
private struct ArtworkSampleGrid: View {
    var body: some View {
        let seeds = WindowSamples.collections.map { ($0.id, $0.symbol) } + WindowSamples.routes.prefix(4).map { ("route-\($0.id)", $0.symbol) }
        VStack(alignment: .leading, spacing: Space.m) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s), count: 6), spacing: Space.s) {
                ForEach(seeds, id: \.0) { seed, symbol in
                    Artwork(seed: seed, symbol: symbol).aspectRatio(1, contentMode: .fit)
                }
            }
            HStack(spacing: Space.s) {
                ForEach(seeds.prefix(8), id: \.0) { seed, symbol in
                    Artwork(seed: seed, symbol: symbol).frame(width: Metrics.Window.listArtwork, height: Metrics.Window.listArtwork)
                }
            }
        }
    }
}
