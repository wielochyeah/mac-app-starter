// Words used across the whole app. Area texts live in <Area>Text.swift next to their code.
// Every string has English and German (du); views never contain UI copy literals.

enum CommonText {
    static var ok: String { tr(en: "OK", de: "OK") }
    static var cancel: String { tr(en: "Cancel", de: "Abbrechen") }
    static var done: String { tr(en: "Done", de: "Fertig") }
    static var close: String { tr(en: "Close", de: "Schließen") }
    static var back: String { tr(en: "Back", de: "Zurück") }
    static var `continue`: String { tr(en: "Continue", de: "Weiter") }
    static var skip: String { tr(en: "Skip", de: "Überspringen") }
    static var retry: String { tr(en: "Try Again", de: "Erneut versuchen") }
    static var remove: String { tr(en: "Remove", de: "Entfernen") }
    static var add: String { tr(en: "Add", de: "Hinzufügen") }
    static var change: String { tr(en: "Change", de: "Ändern") }
    static var reset: String { tr(en: "Reset", de: "Zurücksetzen") }
    static var copy: String { tr(en: "Copy", de: "Kopieren") }
    static var copied: String { tr(en: "Copied", de: "Kopiert") }
    static var search: String { tr(en: "Search", de: "Suchen") }
    static var on: String { tr(en: "On", de: "Ein") }
    static var off: String { tr(en: "Off", de: "Aus") }
    static var loading: String { tr(en: "Loading", de: "Wird geladen") }
    static var settings: String { tr(en: "Settings", de: "Einstellungen") }
    static var settingsMenu: String { tr(en: "Settings…", de: "Einstellungen …") }
    static var openApp: String { tr(en: "Open \(AppInfo.displayName)", de: "\(AppInfo.displayName) öffnen") }
    static var quitApp: String { tr(en: "Quit \(AppInfo.displayName)", de: "\(AppInfo.displayName) beenden") }
    static var aboutApp: String { tr(en: "About \(AppInfo.displayName)", de: "Über \(AppInfo.displayName)") }
    static var hideApp: String { tr(en: "Hide \(AppInfo.displayName)", de: "\(AppInfo.displayName) ausblenden") }
    static var hideOthers: String { tr(en: "Hide Others", de: "Andere ausblenden") }
    static var showAll: String { tr(en: "Show All", de: "Alle einblenden") }
    static var edit: String { tr(en: "Edit", de: "Bearbeiten") }
    static var undo: String { tr(en: "Undo", de: "Widerrufen") }
    static var redo: String { tr(en: "Redo", de: "Wiederholen") }
    static var cut: String { tr(en: "Cut", de: "Ausschneiden") }
    static var paste: String { tr(en: "Paste", de: "Einsetzen") }
    static var selectAll: String { tr(en: "Select All", de: "Alles auswählen") }
    static var window: String { tr(en: "Window", de: "Fenster") }
    static var minimize: String { tr(en: "Minimize", de: "Im Dock ablegen") }
    static var zoom: String { tr(en: "Zoom", de: "Zoomen") }
    static var help: String { tr(en: "Help", de: "Hilfe") }
    static var systemLanguage: String { tr(en: "System", de: "System") }
    static var allLocal: String { tr(en: "All local and offline", de: "Alles lokal und offline") }
    static var nothingLeaves: String { tr(en: "Nothing leaves your Mac", de: "Nichts verlässt deinen Mac") }

    /// "Step 2 of 5" (accessibility label of the onboarding progress).
    static func step(_ index: Int, of count: Int) -> String {
        tr(en: "Step \(index) of \(count)", de: "Schritt \(index) von \(count)")
    }

    /// "Version 1.0.0 (1)"
    static func version(_ version: String, build: Int) -> String {
        tr(en: "Version \(version) (\(build))", de: "Version \(version) (\(build))")
    }
}

/// Texts of kit structures (sidebar sections, settings groups).
enum KitText {
    static func section(_ section: PageSection) -> String {
        switch section {
        case .main: tr(en: "Home", de: "Start")
        case .library: tr(en: "Library", de: "Mediathek")
        case .collections: tr(en: "Collections", de: "Sammlungen")
        }
    }

    static func settingsGroup(_ group: SettingsGroup) -> String {
        switch group {
        case .content: tr(en: "Content", de: "Inhalte")
        case .settings: tr(en: "Settings", de: "Einstellungen")
        }
    }
}
