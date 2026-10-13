// Texts of the settings window and its kit panes (General, About).
// English capitalisation: section headers, sheet titles and buttons in Title Case, row titles and
// subtitles in sentence case without a final period.

enum SettingsText {
    // Window
    static var noPanesTitle: String { tr(en: "Nothing to set up", de: "Nichts einzustellen") }
    static var noPanesMessage: String {
        tr(en: "Modules add their panes here with a SettingsPane in register().",
           de: "Module zeigen ihre Bereiche hier mit einem SettingsPane in register().")
    }

    // Gallery entries
    static var sidebarTitle: String { tr(en: "Settings sidebar", de: "Seitenleiste der Einstellungen") }
    static var footerTitle: String { tr(en: "Sidebar footer", de: "Fußzeile der Seitenleiste") }

    // General
    static var general: String { tr(en: "General", de: "Allgemein") }
    static var generalIntro: String {
        tr(en: "Language and appearance apply to every window of the app at once.",
           de: "Sprache und Erscheinungsbild gelten sofort für jedes Fenster der App.")
    }
    static var language: String { tr(en: "Language", de: "Sprache") }
    static var interface: String { tr(en: "App language", de: "Sprache der App") }
    static var interfaceDetail: String { tr(en: "Windows, menus and notifications", de: "Fenster, Menüs und Mitteilungen") }
    static var languageNote: String {
        tr(en: "With “Automatic”, the app uses the first language it supports from the list in System Settings under General > Language & Region.",
           de: "Bei „Automatisch“ nutzt die App die erste Sprache, die sie beherrscht, aus der Liste in den Systemeinstellungen unter Allgemein > Sprache & Region.")
    }
    static var followMac: String { tr(en: "Automatic", de: "Automatisch") }
    static var appearance: String { tr(en: "Appearance", de: "Erscheinungsbild") }
    static var lightOrDark: String { tr(en: "Light or dark", de: "Hell oder dunkel") }
    static var appearanceDetail: String { tr(en: "For every window of this app", de: "Für alle Fenster dieser App") }
    static var light: String { tr(en: "Light", de: "Hell") }
    static var dark: String { tr(en: "Dark", de: "Dunkel") }
    static var setupSection: String { tr(en: "Start Over", de: "Neu beginnen") }
    static var showSetup: String { tr(en: "Setup", de: "Einrichtung") }
    static var showSetupDetail: String {
        tr(en: "Go through language and permissions again without resetting anything",
           de: "Sprache und Berechtigungen noch einmal durchgehen, ohne etwas zurückzusetzen")
    }
    static var showSetupButton: String { tr(en: "Show Setup Again", de: "Einrichtung erneut zeigen") }
    static var reset: String { tr(en: "Reset settings", de: "Einstellungen zurücksetzen") }
    static var resetDetail: String { tr(en: "Every setting goes back to its default", de: "Alle Einstellungen gehen auf den Standard zurück") }
    static var resetButton: String { tr(en: "Reset…", de: "Zurücksetzen …") }
    static var resetConfirmTitle: String { tr(en: "Reset all settings?", de: "Alle Einstellungen zurücksetzen?") }
    static var resetConfirmText: String {
        tr(en: "Language, appearance and the options in every pane go back to their defaults. You won’t need to go through setup again.",
           de: "Sprache, Erscheinungsbild und die Optionen aller Bereiche gehen auf den Standard zurück. Die Einrichtung musst du nicht wiederholen.")
    }
    static var resetConfirmButton: String { tr(en: "Reset", de: "Zurücksetzen") }
    static var resetDone: String { tr(en: "Back to defaults", de: "Auf Standard zurückgesetzt") }

    // About
    static var about: String { tr(en: "About", de: "Über") }
    static var support: String { tr(en: "Troubleshooting", de: "Bei Problemen") }
    static var versionInfo: String { tr(en: "Version details", de: "Versionsangaben") }
    static var versionInfoDetail: String {
        tr(en: "App, build and macOS version for a bug report", de: "App, Build und macOS-Version für eine Fehlermeldung")
    }
    static var dataFolder: String { tr(en: "Data folder", de: "Datenordner") }
    static var showInFinder: String { tr(en: "Show in Finder", de: "Im Finder zeigen") }
    static var links: String { tr(en: "Links", de: "Links") }
    static var legal: String { tr(en: "Legal", de: "Rechtliches") }
    /// Title of the notices sheet (Title Case) and of the row that opens it (sentence case).
    static var notices: String { tr(en: "Third-Party Notices", de: "Hinweise zu Drittanbietern") }
    static var noticesRow: String { tr(en: "Third-party notices", de: "Hinweise zu Drittanbietern") }
    static var noticesDetail: String { tr(en: "Licenses of the code this app builds on", de: "Lizenzen des Codes, auf dem diese App aufbaut") }
}

/// Fixed texts of the settings render scenes (never shown in the running app).
enum SettingsSampleText {
    static var website: String { tr(en: "Website", de: "Website") }
    static var feedback: String { tr(en: "Send feedback", de: "Feedback senden") }
    /// Extra panes of the `settings.window-many` scene (a project with content panes, like VoiceBud).
    static var panes: [(group: SettingsGroup, title: () -> String, symbol: String, tint: TintName)] {
        [(.content, { tr(en: "History", de: "Verlauf") }, "clock.fill", .blue),
         (.content, { tr(en: "Dictionary", de: "Wörterbuch") }, "book.fill", .orange),
         (.content, { tr(en: "Snippets", de: "Textbausteine") }, "text.quote", .teal),
         (.settings, { tr(en: "Sounds", de: "Töne") }, "speaker.wave.2.fill", .red),
         (.settings, { tr(en: "Keyboard Shortcuts", de: "Tastaturkurzbefehle") }, "command", .graphite),
         (.settings, { tr(en: "Privacy", de: "Datenschutz") }, "hand.raised.fill", .blue),
         (.settings, { tr(en: "Updates", de: "Aktualisierungen") }, "arrow.down.circle.fill", .green)]
    }
    /// Fallback for the notices scenes when the build bundled no App/Resources/Notices (tests);
    /// renders of a normal build show the real file.
    static var notices: String {
        tr(en: """
        # Third-Party Notices

        This app contains software by other authors (sample text).

        ## VoiceBud

        Parts of the design come from VoiceBud by Anas Riad, under the MIT License.

        ```
        MIT License

        Copyright (c) 2026 Anas Riad

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software.
        ```
        """, de: """
        # Hinweise zu Drittanbietern

        Diese App enthält Software anderer Autorinnen und Autoren (Beispieltext).

        ## VoiceBud

        Teile der Gestaltung stammen aus VoiceBud von Anas Riad, unter der MIT-Lizenz.

        ```
        MIT License

        Copyright (c) 2026 Anas Riad

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software.
        ```
        """)
    }
}
