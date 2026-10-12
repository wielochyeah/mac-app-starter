// Texts of the main window: menus, sidebar, content blocks and the start page.

enum WindowText {
    // MARK: Menus (German titles as in macOS)
    static var fileMenu: String { tr(en: "File", de: "Ablage") }
    static var viewMenu: String { tr(en: "View", de: "Darstellung") }
    static var find: String { tr(en: "Find", de: "Suchen") }
    static var showSidebar: String { tr(en: "Show Sidebar", de: "Seitenleiste einblenden") }
    static var hideSidebar: String { tr(en: "Hide Sidebar", de: "Seitenleiste ausblenden") }
    static var enterFullScreen: String { tr(en: "Enter Full Screen", de: "Vollbildmodus aktivieren") }
    static var showSetup: String { tr(en: "Show Setup Again", de: "Einrichtung erneut zeigen") }

    // MARK: Window
    static var sidebar: String { tr(en: "Sidebar", de: "Seitenleiste") }
    static var noPagesTitle: String { tr(en: "No pages yet", de: "Noch keine Seiten") }
    static var noPagesMessage: String {
        tr(en: "Pages that modules or features register appear in the sidebar.",
           de: "Seiten, die Module oder Funktionen anmelden, erscheinen in der Seitenleiste.")
    }

    // MARK: Content blocks
    static var seeAll: String { tr(en: "See All", de: "Alle anzeigen") }
    static var more: String { tr(en: "More", de: "Mehr") }
    static var noResultsTitle: String { tr(en: "No results", de: "Keine Treffer") }

    /// "Nothing matches “Garten”."
    static func noResultsMessage(_ query: String) -> String {
        tr(en: "Nothing matches “\(query)”. Check the spelling or search for a shorter word.",
           de: "Nichts passt zu „\(query)“. Prüf die Schreibweise oder such nach einem kürzeren Wort.")
    }

    /// Accessibility label of a tile: "Recipes, 24 entries".
    static func tileLabel(_ title: String, _ subtitle: String?) -> String {
        guard let subtitle, !subtitle.isEmpty else { return title }
        return tr(en: "\(title), \(subtitle)", de: "\(title), \(subtitle)")
    }

    // MARK: Start page (a fresh project sees this)
    static var homeTitle: String { tr(en: "Home", de: "Start") }
    static var homeLede: String {
        tr(en: "This is where your first view goes. Window, sidebar, menus and the building blocks below are ready; this page is a placeholder that your first own page replaces.",
           de: "Hier baust du deine erste Ansicht. Fenster, Seitenleiste, Menüs und die Bausteine unten sind fertig; diese Seite ist ein Platzhalter, den deine erste eigene Seite ersetzt.")
    }
    static var nextSteps: String { tr(en: "Next steps", de: "Nächste Schritte") }
    static var stepPageTitle: String { tr(en: "Add a page", de: "Seite anlegen") }
    static var stepPageText: String {
        tr(en: "Create a view under Features and add it to Registry.pages as an AppPage. It shows up in the sidebar.",
           de: "Leg unter Features eine Ansicht an und häng sie als AppPage an Registry.pages. Sie erscheint in der Seitenleiste.")
    }
    static var stepBlocksTitle: String { tr(en: "Use the building blocks", de: "Bausteine nutzen") }
    static var stepBlocksText: String {
        tr(en: "Page frame, hero, shelves, grids and lists keep every page in the same style. Toolbar search: WindowSearch.enable.",
           de: "Seitenrahmen, Titelbild, Regale, Raster und Listen halten jede Seite im selben Stil. Suche in der Symbolleiste: WindowSearch.enable.")
    }
    static var stepAgentTitle: String { tr(en: "Build it with an agent", de: "Mit einem Agenten bauen") }
    static var stepAgentText: String {
        tr(en: "The skill neue-ansicht walks through a new page step by step, texts and renders included.",
           de: "Der Skill neue-ansicht führt Schritt für Schritt durch eine neue Seite, mit Texten und Renders.")
    }
    static var buildingBlocks: String { tr(en: "Building blocks", de: "Bausteine") }
    static var replaceHome: String {
        tr(en: "This page steps aside by itself once a page of yours takes the first place in the sidebar: section .main, order 0 or lower.",
           de: "Diese Seite verschwindet von selbst, sobald eine eigene Seite den ersten Platz in der Seitenleiste einnimmt: section .main, order 0 oder kleiner.")
    }

    /// Short descriptions of the building blocks on the start page and in the gallery.
    /// One line under a 168 pt tile in both languages (WindowTests measures them).
    static var blockPageScaffold: String { tr(en: "Page frame, large title", de: "Seitenrahmen, großer Titel") }
    static var blockHero: String { tr(en: "Artwork, title, actions", de: "Bild, Titel, Aktionen") }
    static var blockShelf: String { tr(en: "Row of tiles to scroll", de: "Kachelreihe zum Blättern") }
    static var blockTile: String { tr(en: "Artwork with quick action", de: "Bild mit Schnellaktion") }
    static var blockTileGrid: String { tr(en: "Tiles in a grid", de: "Kacheln im Raster") }
    static var blockItemList: String { tr(en: "Rows like a track list", de: "Zeilen wie Titellisten") }
    static var blockDetailHeader: String { tr(en: "Top of a detail page", de: "Kopf einer Detailseite") }
    static var blockArtwork: String { tr(en: "Generated, no image files", de: "Erzeugt, ohne Bilddateien") }
    static var blockEmptyPage: String { tr(en: "Empty, no results", de: "Leer, keine Treffer") }

    // MARK: Gallery titles
    static var galleryMain: String { tr(en: "Main window", de: "Hauptfenster") }
    static var galleryHome: String { tr(en: "Start page", de: "Startseite") }
    static var galleryDetail: String { tr(en: "Detail page", de: "Detailseite") }
    static var gallerySearch: String { tr(en: "Search results", de: "Suchergebnisse") }
    static var gallerySidebar: String { tr(en: "Sidebar", de: "Seitenleiste") }
    static var galleryTileStates: String { tr(en: "Tile states", de: "Kachelzustände") }
    static var galleryNoPages: String { tr(en: "Window without pages", de: "Fenster ohne Seiten") }
}

/// Code identifiers and paths shown on the start page. Same in every language (not UI copy).
enum WindowCodeNames {
    static let featuresPath = "App/Sources/Features/"
    static let componentsPath = "App/Sources/Modules/Window/Components/"
    static let skillPath = ".claude/skills/neue-ansicht/"
    static let pageScaffold = "PageScaffold"
    static let heroHeader = "HeroHeader"
    static let shelf = "Shelf"
    static let tile = "Tile"
    static let tileGrid = "TileGrid"
    static let itemList = "ItemList"
    static let detailHeader = "DetailHeader"
    static let artwork = "Artwork"
    static let emptyPage = "EmptyPage"
}
