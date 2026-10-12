// Words the patterns show on their own (slot states, download rows, list search), plus the
// gallery titles and the sample copy of the patterns.* scenes.

enum PatternsText {
    // Status slot (permission steps)
    static var allowAccess: String { tr(en: "Allow Access", de: "Freigabe erteilen") }
    static var openSystemSettings: String { tr(en: "Open System Settings", de: "Systemeinstellungen öffnen") }
    static var granted: String { tr(en: "Allowed", de: "Erteilt") }
    static var denied: String { tr(en: "Not allowed", de: "Abgelehnt") }
    static var waitingForAnswer: String { tr(en: "Waiting for your answer", de: "Wartet auf deine Antwort") }
    static var waitingForSwitch: String { tr(en: "Waiting for the switch", de: "Wartet auf deinen Schalter") }
    static var afterRestart: String { tr(en: "Takes effect after a restart", de: "Wirkt nach Neustart") }
    static var restartApp: String { tr(en: "Restart \(AppInfo.displayName)", de: "\(AppInfo.displayName) neu starten") }

    // Progress rows (downloads)
    static var ready: String { tr(en: "Ready", de: "Bereit") }
    static var paused: String { tr(en: "Paused", de: "Pausiert") }
    static var waiting: String { tr(en: "Waiting", de: "Wartet") }
    /// "1.4 of 3.0 GB": `done` without unit, `total` with unit.
    static func progress(_ done: String, of total: String) -> String {
        tr(en: "\(done) of \(total)", de: "\(done) von \(total)")
    }

    // Lists and search
    static var clearSearch: String { tr(en: "Clear Search", de: "Suche löschen") }
    static var noResults: String { tr(en: "No results", de: "Keine Treffer") }
    static func nothingFound(_ query: String) -> String {
        tr(en: "Nothing found for “\(query)”.", de: "Nichts gefunden für „\(query)“.")
    }

    // Notices
    static var info: String { tr(en: "Note", de: "Hinweis") }
    static var warning: String { tr(en: "Warning", de: "Warnung") }
    static var error: String { tr(en: "Error", de: "Fehler") }
    static var opensOutside: String { tr(en: "Opens in another app", de: "Öffnet in einer anderen App") }

    // Gallery titles
    static var onboardingPage: String { tr(en: "Setup page", de: "Einrichtungsseite") }
    static var onboardingHeader: String { tr(en: "Setup header", de: "Einrichtungskopf") }
    static var onboardingHero: String { tr(en: "Setup hero", de: "Einrichtungsbild") }
    static var onboardingFootnote: String { tr(en: "Setup footnote", de: "Einrichtungsfußnote") }
    static var onboardingHint: String { tr(en: "Setup hint", de: "Einrichtungshinweis") }
    static var statusSlot: String { tr(en: "Status slot", de: "Statusfeld") }
    static var tilePicker: String { tr(en: "Tile picker", de: "Kachelauswahl") }
    static var richText: String { tr(en: "Text with links", de: "Text mit Links") }
    static var onboardingFooter: String { tr(en: "Setup footer", de: "Einrichtungsleiste") }
    static var paneScaffold: String { tr(en: "Settings pane frame", de: "Einstellungsrahmen") }
    static var settingsSection: String { tr(en: "Settings section", de: "Einstellungsgruppe") }
    static var toggleRow: String { tr(en: "Switch row", de: "Schalterzeile") }
    static var pickerRow: String { tr(en: "Picker row", de: "Auswahlzeile") }
    static var valueRow: String { tr(en: "Value row", de: "Wertzeile") }
    static var buttonRow: String { tr(en: "Button row", de: "Tastenzeile") }
    static var confirmRow: String { tr(en: "Confirmation row", de: "Rückfragezeile") }
    static var linkRow: String { tr(en: "Link row", de: "Linkzeile") }
    static var navigationRow: String { tr(en: "Navigation row", de: "Navigationszeile") }
    static var inlineNotice: String { tr(en: "Notice", de: "Hinweisfeld") }
    static var progressRow: String { tr(en: "Download row", de: "Downloadzeile") }
    static var listCard: String { tr(en: "List card", de: "Listenkarte") }
    static var countBadge: String { tr(en: "Count", de: "Anzahl") }
    static var searchField: String { tr(en: "Search field", de: "Suchfeld") }
    static var samplePane: String { tr(en: "Sample settings pane", de: "Beispiel Einstellungsbereich") }
    static var sampleStep: String { tr(en: "Sample setup step", de: "Beispiel Einrichtungsschritt") }
    static var samplePermission: String { tr(en: "Sample permission step", de: "Beispiel Berechtigungsschritt") }
}

/// Copy of the patterns.* sample scenes (fixed, so renders are deterministic).
enum PatternsSampleText {
    static var general: String { tr(en: "General", de: "Allgemein") }
    static var generalIntro: String {
        tr(en: "How the app looks and behaves. Changes apply right away.",
           de: "Wie die App aussieht und sich verhält. Änderungen gelten sofort.")
    }
    static var language: String { tr(en: "Language", de: "Sprache") }
    static var interface: String { tr(en: "Interface", de: "Oberfläche") }
    static var interfaceDetail: String { tr(en: "Windows, menus and notifications", de: "Fenster, Menüs und Mitteilungen") }
    static var appearance: String { tr(en: "Appearance", de: "Darstellung") }
    static var appearanceDetail: String { tr(en: "Light, dark or like the Mac", de: "Hell, dunkel oder wie der Mac") }
    static var system: String { tr(en: "System", de: "System") }
    static var light: String { tr(en: "Light", de: "Hell") }
    static var dark: String { tr(en: "Dark", de: "Dunkel") }
    static var behavior: String { tr(en: "Behavior", de: "Verhalten") }
    static var openAtLogin: String { tr(en: "Open at login", de: "Beim Anmelden öffnen") }
    static var openAtLoginDetail: String { tr(en: "Starts quietly in the menu bar", de: "Startet leise in der Menüleiste") }
    static var sounds: String { tr(en: "Sounds", de: "Töne") }
    static var soundsDetail: String { tr(en: "A soft sound when a task finishes", de: "Ein leiser Ton, wenn eine Aufgabe fertig ist") }
    static var confirmation: String { tr(en: "Show confirmation", de: "Bestätigung anzeigen") }
    static var behaviorNote: String {
        tr(en: "The confirmation stays this long after a task finishes.",
           de: "So lange bleibt die Bestätigung stehen, wenn eine Aufgabe fertig ist.")
    }
    static var models: String { tr(en: "Models", de: "Modelle") }
    static var speechModel: String { tr(en: "Speech recognition", de: "Spracherkennung") }
    static var speechModelName: String { tr(en: "Whisper turbo, 8-bit", de: "Whisper turbo, 8 Bit") }
    static var textModel: String { tr(en: "Text cleanup", de: "Textaufbereitung") }
    static var textModelName: String { tr(en: "Qwen 3, 4B", de: "Qwen 3, 4B") }
    static var embedModel: String { tr(en: "Search index", de: "Suchindex") }
    static var embedModelName: String { tr(en: "MiniLM, small", de: "MiniLM, klein") }
    static var offlineNote: String {
        tr(en: "No connection to the internet. The download continues once you are back online.",
           de: "Keine Verbindung zum Internet. Der Download geht weiter, sobald du wieder online bist.")
    }
    static var noWaitNote: String {
        tr(en: "You don’t have to wait, the download runs in the background.",
           de: "Du musst nicht warten, der Download läuft im Hintergrund.")
    }
    static var storage: String { tr(en: "Storage", de: "Speicher") }
    static var dataFolder: String { tr(en: "Data folder", de: "Datenordner") }
    static var dataFolderDetail: String { tr(en: "Settings and history of this Mac", de: "Einstellungen und Verlauf dieses Macs") }
    static var showInFinder: String { tr(en: "Show in Finder", de: "Im Finder zeigen") }
    static var used: String { tr(en: "Space used", de: "Belegt") }
    static var deleteHistory: String { tr(en: "Delete history", de: "Verlauf löschen") }
    static var deleteHistoryDetail: String { tr(en: "Removes every saved entry", de: "Entfernt alle gesicherten Einträge") }
    static var delete: String { tr(en: "Delete…", de: "Löschen …") }
    static var deleteHistoryConfirm: String { tr(en: "Delete the whole history?", de: "Den ganzen Verlauf löschen?") }
    static var deleteHistoryConfirmText: String {
        tr(en: "Every saved entry is removed from this Mac. This cannot be undone.",
           de: "Jeder gesicherte Eintrag wird von diesem Mac entfernt. Das lässt sich nicht rückgängig machen.")
    }
    static var deleteNow: String { tr(en: "Delete", de: "Löschen") }
    static var shortcuts: String { tr(en: "Keyboard shortcuts", de: "Kurzbefehle") }
    static var shortcutsDetail: String { tr(en: "4 shortcuts", de: "4 Kurzbefehle") }
    static var privacy: String { tr(en: "Privacy & Security", de: "Datenschutz & Sicherheit") }
    static var privacyDetail: String { tr(en: "Microphone, Accessibility", de: "Mikrofon, Bedienungshilfen") }
    static var help: String { tr(en: "Help", de: "Hilfe") }
    static var helpDetail: String { tr(en: "Questions and answers", de: "Fragen und Antworten") }
    static var noticeInfo: String {
        tr(en: "Apple Intelligence is off. Turn it on in System Settings to use local models.",
           de: "Apple Intelligence ist aus. Schalte es in den Systemeinstellungen ein, um lokale Modelle zu nutzen.")
    }
    static var noticeInfoTitle: String { tr(en: "Local models unavailable", de: "Lokale Modelle nicht verfügbar") }
    static var noticeWarn: String {
        tr(en: "Less than 2 GB free. Downloads pause until there is room.",
           de: "Weniger als 2 GB frei. Downloads pausieren, bis wieder Platz ist.")
    }
    static var noticeError: String {
        tr(en: "The history could not be opened. Your entries are safe, try again after a restart.",
           de: "Der Verlauf ließ sich nicht öffnen. Deine Einträge sind sicher, versuch es nach einem Neustart.")
    }
    static var turnOn: String { tr(en: "Turn On…", de: "Einschalten …") }
    static var apps: String { tr(en: "Apps", de: "Apps") }
    static var searchApps: String { tr(en: "Search apps", de: "Apps durchsuchen") }
    static var noApps: String { tr(en: "No apps yet", de: "Noch keine Apps") }
    static var noAppsDetail: String { tr(en: "Apps you add appear here.", de: "Apps, die du hinzufügst, erscheinen hier.") }
    static var sampleApps: [(name: String, detail: String, symbol: String, tint: TintName)] {
        [(tr(en: "Mail", de: "Mail"), tr(en: "Reads the open message", de: "Liest die offene Nachricht"), "envelope.fill", .blue),
         (tr(en: "Notes", de: "Notizen"), tr(en: "Reads the open note", de: "Liest die offene Notiz"), "note.text", .yellow),
         (tr(en: "Safari", de: "Safari"), tr(en: "Reads the page title", de: "Liest den Seitentitel"), "safari.fill", .sky),
         (tr(en: "Terminal", de: "Terminal"), tr(en: "Never reads", de: "Liest nie mit"), "terminal.fill", .black)]
    }
    static var island: String { tr(en: "Island at the notch", de: "Insel an der Notch") }
    static var capsule: String { tr(en: "Capsule", de: "Kapsel") }
    static var islandDetail: String { tr(en: "Grows out of the notch", de: "Wächst aus der Notch") }
    static var capsuleDetail: String { tr(en: "Floats below the menu bar", de: "Schwebt unter der Menüleiste") }
    static var off: String { tr(en: "Off", de: "Aus") }
    static var offDetail: String { tr(en: "Only the menu bar", de: "Nur die Menüleiste") }

    // Steps
    static var languageSubtitle: String {
        tr(en: "The language of windows, menus and notifications.", de: "Die Sprache von Fenstern, Menüs und Mitteilungen.")
    }
    /// In the other language on purpose: the way to the switch for whoever needs it (VoiceBud).
    static var languageCrossHint: String {
        // text-ausnahme: the hint is written in the other language so whoever needs it can read it
        tr(en: "Lieber auf Deutsch? Unten bei App „Deutsch“ wählen.", de: "Prefer English? Choose English next to App below.")
    }
    static var app: String { tr(en: "App", de: "App") }
    static var appDetail: String { tr(en: "Texts in windows, menus and the island", de: "Texte in Fenstern, Menüs und Insel") }
    static var languageFootnote: String {
        tr(en: "Follows the Mac until you pick one. You can change it later in Settings under General.",
           de: "Folgt dem Mac, bis du eine wählst. Du kannst sie später in den Einstellungen unter Allgemein ändern.")
    }
    static var accessibility: String { tr(en: "Accessibility", de: "Bedienungshilfen") }
    static var accessibilitySubtitle: String {
        // umbruch: a balanced two-line subtitle under the step title (VoiceBud)
        tr(en: "\(AppInfo.displayName) needs your permission to insert text at the cursor\nand to see which app you are writing in.",
           de: "\(AppInfo.displayName) braucht deine Erlaubnis, um Text am Cursor einzufügen\nund zu sehen, in welcher App du schreibst.")
    }
    static var accessibilityHint: String {
        tr(en: "Turn on “\(AppInfo.displayName)” in System Settings.",
           de: "Schalte in den Systemeinstellungen „\(AppInfo.displayName)“ ein.")
    }
    static var accessibilityRevealHint: String {
        tr(en: "Not in the list? Click [Show in Finder](app://reveal) and drag the app into it.",
           de: "Steht die App nicht in der Liste? Klick auf [Im Finder zeigen](app://reveal) und zieh sie hinein.")
    }
    static var grantedHint: String { tr(en: "Next up: the models.", de: "Weiter geht es mit den Modellen.") }
    static var missingHint: String {
        tr(en: "macOS asks next whether \(AppInfo.displayName) may use the microphone.\nChoose “Allow”.",
           de: "macOS fragt gleich, ob \(AppInfo.displayName) dein Mikrofon nutzen darf.\nWähle „Erlauben“.")
    }
    static var restartHint: String {
        tr(en: "The permission works once \(AppInfo.displayName) restarts.\nThat takes two seconds, this window stays open.",
           de: "Die Freigabe greift erst, wenn \(AppInfo.displayName) neu startet.\nDas dauert zwei Sekunden, dieses Fenster bleibt offen.")
    }
    static var welcomeTitle: String { AppInfo.displayName }
    static var welcomeLede: String {
        tr(en: "A calm place for your work.\nEverything stays on your Mac.", de: "Ein ruhiger Ort für deine Arbeit.\nAlles bleibt auf deinem Mac.")
    }
    static var appearanceTitle: String { tr(en: "Appearance", de: "Darstellung") }
    static var appearanceSubtitle: String { tr(en: "How the app shows up while it works.", de: "So zeigt sich die App, während sie arbeitet.") }
    static var appearanceFootnote: String { tr(en: "You can change this later in Settings.", de: "Das kannst du später in den Einstellungen ändern.") }
    static var linkSample: String {
        tr(en: "Something missing? [Open the setup again](app://setup) or [show the data folder](app://reveal).",
           de: "Fehlt etwas? [Einrichtung erneut zeigen](app://setup) oder [Datenordner zeigen](app://reveal).")
    }
}
