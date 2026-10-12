// Texts of the main window: menus, sidebar, content blocks and the start page.

enum WindowText {
    // MARK: Menus (German titles as in macOS)
    static var fileMenu: String { tr(en: "File", de: "Ablage") }
    static var viewMenu: String { tr(en: "View", de: "Darstellung") }
    static var find: String { tr(en: "Find", de: "Suchen") }
    static var toggleSidebar: String { tr(en: "Show or Hide Sidebar", de: "Seitenleiste ein- oder ausblenden") }
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
        tr(en: "This is where your first view goes. Window, sidebar, search and the building blocks below are ready; this page is a placeholder you replace.",
           de: "Hier baust du deine erste Ansicht. Fenster, Seitenleiste, Suche und die Bausteine unten sind fertig; diese Seite ist ein Platzhalter, den du ersetzt.")
    }
    static var nextSteps: String { tr(en: "Next steps", de: "Nächste Schritte") }
    static var stepPageTitle: String { tr(en: "Add a page", de: "Seite anlegen") }
    static var stepPageText: String {
        tr(en: "Create a view in its own folder and register it as an AppPage. It shows up in the sidebar.",
           de: "Leg eine Ansicht in einem eigenen Ordner an und melde sie als AppPage an. Sie erscheint in der Seitenleiste.")
    }
    static var stepBlocksTitle: String { tr(en: "Use the building blocks", de: "Bausteine nutzen") }
    static var stepBlocksText: String {
        tr(en: "Page frame, hero, shelves, tile grids and lists keep every page in the same look.",
           de: "Seitenrahmen, Titelbild, Regale, Kachelraster und Listen halten jede Seite im selben Look.")
    }
    static var stepAgentTitle: String { tr(en: "Build it with an agent", de: "Mit einem Agenten bauen") }
    static var stepAgentText: String {
        tr(en: "The skill neue-ansicht walks through a new page step by step, texts and renders included.",
           de: "Der Skill neue-ansicht führt Schritt für Schritt durch eine neue Seite, mit Texten und Renders.")
    }
    static var buildingBlocks: String { tr(en: "Building blocks", de: "Bausteine") }
    static var replaceHome: String {
        tr(en: "Remove this page in WindowModule.register() once your first own page exists.",
           de: "Diese Seite entfernst du in WindowModule.register(), sobald deine erste eigene Seite steht.")
    }

    /// Short descriptions of the building blocks on the start page and in the gallery.
    static var blockPageScaffold: String { tr(en: "Page frame with large title", de: "Seitenrahmen mit großem Titel") }
    static var blockHero: String { tr(en: "Artwork with title and actions", de: "Bild mit Titel und Aktionen") }
    static var blockShelf: String { tr(en: "Row of tiles that scrolls", de: "Kachelreihe zum Blättern") }
    static var blockTile: String { tr(en: "Artwork, title, hover action", de: "Bild, Titel, Hover-Aktion") }
    static var blockTileGrid: String { tr(en: "Tiles that fill the width", de: "Kacheln über die ganze Breite") }
    static var blockItemList: String { tr(en: "Rows like a track list", de: "Zeilen wie eine Titelliste") }
    static var blockDetailHeader: String { tr(en: "Header of a detail page", de: "Kopf einer Detailseite") }
    static var blockArtwork: String { tr(en: "Generated art, no image files", de: "Erzeugte Bilder ohne Bilddateien") }
    static var blockEmptyPage: String { tr(en: "Empty and no-results state", de: "Leerer Zustand und keine Treffer") }

    // MARK: Gallery titles
    static var galleryMain: String { tr(en: "Main window", de: "Hauptfenster") }
    static var galleryHome: String { tr(en: "Start page", de: "Startseite") }
    static var galleryDetail: String { tr(en: "Detail page", de: "Detailseite") }
    static var gallerySearch: String { tr(en: "Search results", de: "Suchergebnisse") }
    static var gallerySidebar: String { tr(en: "Sidebar", de: "Seitenleiste") }
    static var galleryTileStates: String { tr(en: "Tile states", de: "Kachelzustände") }
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
