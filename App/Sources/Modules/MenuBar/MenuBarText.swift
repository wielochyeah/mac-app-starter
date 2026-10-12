// Texts of the menu bar module (status item, panel, menu, settings pane). English and German (du).

enum MenuBarText {
    // MARK: Status

    static func stateName(_ state: MenuBarState) -> String {
        switch state {
        case .idle: tr(en: "Ready", de: "Bereit")
        case .busy: tr(en: "Working", de: "Arbeitet")
        case .attention: tr(en: "Needs you", de: "Braucht dich")
        }
    }

    /// The panel's status line when no module set a message.
    static func statusLine(_ state: MenuBarState) -> String {
        switch state {
        case .idle: tr(en: "Ready", de: "Bereit")
        case .busy: tr(en: "Working…", de: "Arbeitet …")
        case .attention: tr(en: "Something needs your attention", de: "Etwas braucht deine Aufmerksamkeit")
        }
    }

    /// Tooltip and VoiceOver label of the status item: "Starter: Ready".
    static func tooltip(_ line: String) -> String {
        tr(en: "\(AppInfo.displayName): \(line)", de: "\(AppInfo.displayName): \(line)")
    }

    // MARK: Menu and panel

    static var setupMenu: String { tr(en: "Setup…", de: "Einrichtung …") }
    static var actions: String { tr(en: "Actions", de: "Aktionen") }
    static var settings: String { tr(en: "Settings", de: "Einstellungen") }
    static var openWindow: String { tr(en: "Open Window", de: "Fenster öffnen") }
    static var quit: String { tr(en: "Quit", de: "Beenden") }

    // MARK: Settings pane

    static var paneTitle: String { tr(en: "Menu Bar", de: "Menüleiste") }
    static var paneIntro: String {
        tr(en: "How the icon in the menu bar shows what the app is doing.",
           de: "Wie das Symbol in der Menüleiste zeigt, was die App gerade tut.")
    }
    static var iconSection: String { tr(en: "Icon", de: "Symbol") }

    static func styleName(_ style: MenuBarIconStyle) -> String {
        switch style {
        case .plain: tr(en: "Plain", de: "Schlicht")
        case .marks: tr(en: "Marks", de: "Zeichen")
        case .color: tr(en: "Color", de: "Farbe")
        }
    }

    /// What a style does, under the tiles.
    static func styleNote(_ style: MenuBarIconStyle) -> String {
        switch style {
        case .plain: tr(en: "The icon never changes. Click it to see what the app is doing.",
                        de: "Das Symbol bleibt immer gleich. Was die App tut, siehst du nach einem Klick darauf.")
        case .marks: tr(en: "A small ring turns while the app works, a red dot shows when it needs you.",
                        de: "Ein kleiner Ring dreht sich, solange die App arbeitet, ein roter Punkt zeigt, wenn sie dich braucht.")
        case .color: tr(en: "The icon takes the accent color while the app works, a red dot shows when it needs you.",
                        de: "Das Symbol wird in der Akzentfarbe gezeigt, solange die App arbeitet, ein roter Punkt zeigt, wenn sie dich braucht.")
        }
    }

    static var statusText: String { tr(en: "Status next to the icon", de: "Status neben dem Symbol") }
    static var statusTextDetail: String {
        tr(en: "While the app works or needs you, a short text stands in the menu bar.",
           de: "Solange die App arbeitet oder dich braucht, steht ein kurzer Text in der Menüleiste.")
    }
    static var visible: String { tr(en: "Show in menu bar", de: "In der Menüleiste zeigen") }
    static var visibleDetail: String {
        tr(en: "Without the icon, open the app from the Dock or with Spotlight.",
           de: "Ohne Symbol öffnest du die App über das Dock oder mit Spotlight.")
    }

    // MARK: Renders and gallery

    static var actualSize: String { tr(en: "Actual size", de: "Originalgröße") }
    static var galleryIcon: String { tr(en: "Menu bar icon", de: "Menüleisten-Symbol") }
    static var galleryPanel: String { tr(en: "Menu bar panel", de: "Menüleisten-Übersicht") }
    static var galleryToggle: String { tr(en: "Panel toggle", de: "Schalter in der Übersicht") }
}

/// Sample content of the panel renders (never shown in the app).
enum MenuBarSampleText {
    static var quick: String { tr(en: "Quick settings", de: "Schnellzugriff") }
    static var pause: String { tr(en: "Pause", de: "Pausieren") }
    static var sounds: String { tr(en: "Sounds", de: "Töne") }
    static var recent: String { tr(en: "Recent", de: "Zuletzt") }
    static var importing: String { tr(en: "Importing 3 files…", de: "3 Dateien werden importiert …") }
    static var newItem: String { tr(en: "New Item", de: "Neues Objekt") }
    static var openFolder: String { tr(en: "Open Folder", de: "Ordner öffnen") }

    static var recentItems: [(title: String, symbol: String)] {
        [
            (tr(en: "Weekly report.pdf", de: "Wochenbericht.pdf"), "doc.richtext"),
            (tr(en: "Meeting notes", de: "Besprechungsnotizen"), "note.text"),
            (tr(en: "Photos from Lisbon", de: "Fotos aus Lissabon"), "photo.on.rectangle"),
        ]
    }
}
