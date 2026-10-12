// Texts of the settings window and its kit panes (General, About).

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
    static var language: String { tr(en: "Language", de: "Sprache") }
    static var interface: String { tr(en: "App language", de: "Sprache der App") }
    static var interfaceDetail: String { tr(en: "Windows, menus and notifications", de: "Fenster, Menüs und Mitteilungen") }
    static var languageNote: String {
        tr(en: "System uses the first language under Language & Region in System Settings that this app speaks.",
           de: "System nimmt die erste Sprache unter Sprache & Region in den Systemeinstellungen, die diese App spricht.")
    }
    static var followMac: String { tr(en: "System", de: "System") }
    static var appearance: String { tr(en: "Appearance", de: "Erscheinungsbild") }
    static var appearanceDetail: String { tr(en: "For every window of this app", de: "Für alle Fenster dieser App") }
    static var light: String { tr(en: "Light", de: "Hell") }
    static var dark: String { tr(en: "Dark", de: "Dunkel") }
    static var setupSection: String { tr(en: "Start Over", de: "Neu beginnen") }
    static var showSetup: String { tr(en: "Setup", de: "Einrichtung") }
    static var showSetupDetail: String {
        tr(en: "Walk through language and permissions again. Nothing is reset.",
           de: "Noch einmal durch Sprache und Freigaben gehen. Nichts wird zurückgesetzt.")
    }
    static var showSetupButton: String { tr(en: "Show Again", de: "Erneut zeigen") }
    static var reset: String { tr(en: "Reset Settings", de: "Einstellungen zurücksetzen") }
    static var resetDetail: String { tr(en: "Every setting goes back to its default", de: "Alle Einstellungen gehen auf den Standard zurück") }
    static var resetButton: String { tr(en: "Reset…", de: "Zurücksetzen …") }
    static var resetConfirmTitle: String { tr(en: "Reset all settings?", de: "Alle Einstellungen zurücksetzen?") }
    static var resetConfirmText: String {
        tr(en: "Language, appearance and the settings of every pane go back to their defaults. The setup stays done.",
           de: "Sprache, Erscheinungsbild und die Einstellungen aller Bereiche gehen auf den Standard zurück. Die Einrichtung bleibt erledigt.")
    }
    static var resetConfirmButton: String { tr(en: "Reset", de: "Zurücksetzen") }
    static var resetDone: String { tr(en: "Back to defaults", de: "Auf Standard zurückgesetzt") }

    // About
    static var about: String { tr(en: "About", de: "Über") }
    static var support: String { tr(en: "When something goes wrong", de: "Wenn etwas nicht klappt") }
    static var versionInfo: String { tr(en: "Version details", de: "Versionsangaben") }
    static var versionInfoDetail: String {
        tr(en: "App, build and macOS version for a bug report", de: "App, Build und macOS-Version für eine Fehlermeldung")
    }
    static var dataFolder: String { tr(en: "Data folder", de: "Datenordner") }
    static var showInFinder: String { tr(en: "Show in Finder", de: "Im Finder zeigen") }
    static var links: String { tr(en: "Links", de: "Links") }
    static var legal: String { tr(en: "Legal", de: "Rechtliches") }
    static var notices: String { tr(en: "Third-Party Notices", de: "Hinweise zu Drittanbietern") }
    static var noticesDetail: String { tr(en: "Licences of the code this app builds on", de: "Lizenzen des Codes, auf dem diese App aufbaut") }
}

/// Fixed texts of the settings render scenes (never shown in the running app).
enum SettingsSampleText {
    static var website: String { tr(en: "Website", de: "Webseite") }
    static var feedback: String { tr(en: "Send feedback", de: "Feedback senden") }
    /// Stand-in for THIRD_PARTY_NOTICES.md when the build has none.
    static var notices: String {
        tr(en: """
        # Third-party notices

        This app contains code from the following projects.

        ## VoiceBud

        MIT License, Copyright (c) 2026 Anas Riad

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated \
        documentation files (the "Software"), to deal in the Software without restriction, including without limitation \
        the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.

        - Design tokens and window chrome
        - Settings window layout
        """, de: """
        # Hinweise zu Drittanbietern

        Diese App enthält Code aus den folgenden Projekten.

        ## VoiceBud

        MIT License, Copyright (c) 2026 Anas Riad

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated \
        documentation files (the "Software"), to deal in the Software without restriction, including without limitation \
        the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.

        - Gestaltungswerte und Fensterrahmen
        - Aufbau des Einstellungsfensters
        """)
    }
}
