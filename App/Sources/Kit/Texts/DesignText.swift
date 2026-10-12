// Texts of the design specimens (gallery entries and design.* renders).

enum DesignText {
    // Gallery titles
    static var tokens: String { tr(en: "Colors", de: "Farben") }
    static var type: String { tr(en: "Type", de: "Schrift") }
    static var accents: String { tr(en: "Accents", de: "Akzentfarben") }
    static var buttons: String { tr(en: "Buttons", de: "Tasten") }
    static var card: String { tr(en: "Card", de: "Karte") }
    static var row: String { tr(en: "Rows", de: "Zeilen") }
    static var groupLabel: String { tr(en: "Group label", de: "Gruppentitel") }
    static var separator: String { tr(en: "Separator", de: "Trennlinie") }
    static var footnote: String { tr(en: "Footnote", de: "Fußnote") }
    static var switchToggle: String { tr(en: "Switch", de: "Schalter") }
    static var segmented: String { tr(en: "Segmented control", de: "Segmentauswahl") }
    static var chip: String { tr(en: "Chips", de: "Chips") }
    static var badge: String { tr(en: "Badges", de: "Plaketten") }
    static var squircle: String { tr(en: "Icons", de: "Symbole") }
    static var keyCaps: String { tr(en: "Key caps", de: "Tastenkappen") }
    static var progress: String { tr(en: "Step progress", de: "Schrittanzeige") }
    static var spinner: String { tr(en: "Spinner", de: "Ladeanzeige") }
    static var emptyState: String { tr(en: "Empty state", de: "Leerer Zustand") }
    static var sectionHeader: String { tr(en: "Pane header", de: "Bereichskopf") }
    static var glass: String { tr(en: "Glass surface", de: "Glasfläche") }
    static var island: String { tr(en: "Island", de: "Insel") }
    static var statusMark: String { tr(en: "Status", de: "Status") }
    static var sampleSettings: String { tr(en: "Settings pane", de: "Einstellungsbereich") }
    static var sampleOnboarding: String { tr(en: "Setup step", de: "Einrichtungsschritt") }

    // Sample copy
    static var general: String { tr(en: "General", de: "Allgemein") }
    static var language: String { tr(en: "Language", de: "Sprache") }
    static var interface: String { tr(en: "Interface", de: "Oberfläche") }
    static var interfaceDetail: String { tr(en: "Language of windows, menus and notifications", de: "Sprache von Fenstern, Menüs und Mitteilungen") }
    static var behavior: String { tr(en: "Behavior", de: "Verhalten") }
    static var openAtLogin: String { tr(en: "Open at login", de: "Beim Anmelden öffnen") }
    static var openAtLoginDetail: String { tr(en: "Starts quietly in the menu bar", de: "Startet leise in der Menüleiste") }
    static var sounds: String { tr(en: "Sounds", de: "Töne") }
    static var soundsDetail: String { tr(en: "A soft sound when a task finishes", de: "Ein leiser Ton, wenn eine Aufgabe fertig ist") }
    static var hideInFullScreen: String { tr(en: "Hide in full screen", de: "Im Vollbild ausblenden") }
    static var hideInFullScreenDetail: String { tr(en: "Nothing appears while an app is in full screen", de: "Nichts erscheint, solange eine App im Vollbild ist") }
    static var footnoteSample: String {
        tr(en: "Changes apply right away. You can change them later in Settings under General.",
           de: "Änderungen gelten sofort. Du kannst sie später in den Einstellungen unter Allgemein ändern.")
    }
    static var setupTitle: String { tr(en: "Language", de: "Sprache") }
    static var setupSubtitle: String { tr(en: "Pick the language for windows and menus.", de: "Wähle die Sprache für Fenster und Menüs.") }
    static var setupHint: String { tr(en: "Lieber auf Deutsch? Wähle unten Deutsch.", de: "Prefer English? Pick English below.") }
    static var app: String { tr(en: "App", de: "App") }
    static var appDetail: String { tr(en: "Windows, menus and notifications", de: "Fenster, Menüs und Mitteilungen") }
    static var recommended: String { tr(en: "Recommended", de: "Empfohlen") }
    static var new: String { tr(en: "New", de: "Neu") }
    static var ready: String { tr(en: "Ready", de: "Bereit") }
    static var allowed: String { tr(en: "Allowed", de: "Erlaubt") }
    static var notAllowed: String { tr(en: "Not allowed yet", de: "Noch nicht erlaubt") }
    static var waiting: String { tr(en: "Waiting", de: "Wartet") }
    static var checking: String { tr(en: "Checking", de: "Wird geprüft") }
    static var failed: String { tr(en: "Download stopped", de: "Download abgebrochen") }
    static var emptyTitle: String { tr(en: "No notes yet", de: "Noch keine Notizen") }
    static var emptyMessage: String { tr(en: "Notes you save appear here, newest first.", de: "Notizen, die du sicherst, erscheinen hier, die neueste zuerst.") }
    static var newNote: String { tr(en: "New Note", de: "Neue Notiz") }
    static var glassSample: String { tr(en: "Floats above the content", de: "Schwebt über dem Inhalt") }
    static var typeSample: String { tr(en: "Calm, precise, local", de: "Ruhig, genau, lokal") }
    static var islandDone: String { tr(en: "Copied", de: "Kopiert") }
    static var islandMeta: String { tr(en: "Notes · 0.7 s", de: "Notizen · 0,7 s") }
    static var islandPreview: String {
        tr(en: "Pick up the printed plans before Friday and bring them to the site meeting.",
           de: "Hol die gedruckten Pläne vor Freitag ab und bring sie zur Baubesprechung mit.")
    }
    static var islandHint: String { tr(en: "Hover to read everything", de: "Zeigen, um alles zu lesen") }
    static var disabled: String { tr(en: "Not available", de: "Nicht verfügbar") }
}
