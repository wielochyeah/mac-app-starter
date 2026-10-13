// Texts of the component gallery (the Gallery pane in Settings).

enum GalleryText {
    static var title: String { tr(en: "Gallery", de: "Galerie") }
    static var searchPrompt: String { tr(en: "Search components", de: "Bausteine suchen") }
    static var allAreas: String { tr(en: "All areas", de: "Alle Bereiche") }
    /// The stage follows the window's appearance.
    static var schemeWindow: String { tr(en: "Automatic", de: "Automatisch") }
    static var schemeLight: String { tr(en: "Light", de: "Hell") }
    static var schemeDark: String { tr(en: "Dark", de: "Dunkel") }
    static var previewLabel: String { tr(en: "Preview appearance", de: "Erscheinungsbild der Vorschau") }
    static var areaLabel: String { tr(en: "Area", de: "Bereich") }
    static var emptyTitle: String { tr(en: "No components yet", de: "Noch keine Bausteine") }
    static var emptyMessage: String {
        tr(en: "Modules add their components here with a GalleryEntry in register().",
           de: "Module zeigen ihre Bausteine hier mit einem GalleryEntry in register().")
    }

    /// "1 component" / "48 components"
    static func count(_ n: Int) -> String {
        n == 1 ? tr(en: "1 component", de: "1 Baustein")
            : tr(en: "\(Format.number(n)) components", de: "\(Format.number(n)) Bausteine")
    }

    /// Title of a gallery area (the `area` of a `GalleryEntry`).
    static func area(_ id: String) -> String {
        switch id {
        case "design": tr(en: "Design", de: "Gestaltung")
        case "patterns": tr(en: "Patterns", de: "Muster")
        case "settings": tr(en: "Settings", de: "Einstellungen")
        case "onboarding": tr(en: "Setup", de: "Einrichtung")
        case "permissions": tr(en: "Permissions", de: "Berechtigungen")
        case "gallery": tr(en: "Gallery", de: "Galerie")
        case "window": tr(en: "Main window", de: "Hauptfenster")
        case "menubar": tr(en: "Menu bar", de: "Menüleiste")
        case "island": tr(en: "Island", de: "Insel")
        case "background": tr(en: "Background", de: "Hintergrund")
        case "hotkeys": tr(en: "Keyboard shortcuts", de: "Tastaturkurzbefehle")
        case "ai": tr(en: "Local AI", de: "Lokale KI")
        case "mlx": tr(en: "MLX models", de: "MLX-Modelle")
        case "examples": tr(en: "Examples", de: "Beispiele")
        // an area this list does not know yet (a project's own): its id, capitalised
        default: id.prefix(1).uppercased() + id.dropFirst()
        }
    }
}

extension GalleryText {
    /// A search with no hits (render scene `gallery.no-results`).
    static var sampleQuery: String { tr(en: "slider", de: "Schieberegler") }
}
