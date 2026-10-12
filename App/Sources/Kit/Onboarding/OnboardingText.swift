// Texts of the onboarding window and its kit steps (welcome, language, features, done).
// Permission words live in Kit/Permissions/PermissionText.swift.

enum OnboardingText {
    static var windowTitle: String { tr(en: "Set Up \(AppInfo.displayName)", de: "\(AppInfo.displayName) einrichten") }
    /// The advance button on the last step.
    static var done: String { tr(en: "Done", de: "Fertig") }
    static var doneAndRestart: String { tr(en: "Done and Restart", de: "Fertig und neu starten") }

    // MARK: Welcome

    /// Project: one or two short lines that say what the app does for the person.
    static var welcomeLede: String {
        tr(en: "A few short steps and you are ready.\nYour data stays on your Mac.",
           de: "Ein paar kurze Schritte, dann kann es losgehen.\nDeine Daten bleiben auf deinem Mac.")
    }
    static func welcomeNote(steps: Int) -> String {
        tr(en: "\(steps) steps. You can change everything later in Settings.",
           de: "\(steps) Schritte. Alles lässt sich später in den Einstellungen ändern.")
    }

    // MARK: Language

    static var languageTitle: String { tr(en: "Language", de: "Sprache") }
    static var languageSubtitle: String {
        tr(en: "The language of windows, menus and notifications.", de: "Die Sprache von Fenstern, Menüs und Mitteilungen.")
    }
    /// In the other language on purpose: the way to the switch for whoever needs it (VoiceBud).
    static var languageCrossHint: String {
        tr(en: "Lieber auf Deutsch? Wähle unten bei App „Deutsch“.", de: "Prefer English? Choose English next to App below.")
    }
    static var languageApp: String { tr(en: "App", de: "App") }
    static var languageAppDetail: String { tr(en: "Texts in windows and menus", de: "Texte in Fenstern und Menüs") }
    /// A language's name in the UI language ("German" / "Deutsch").
    static func languageName(_ lang: Lang) -> String {
        switch lang {
        case .en: tr(en: "English", de: "Englisch")
        case .de: tr(en: "German", de: "Deutsch")
        }
    }
    static var followMac: String { tr(en: "Same as the Mac", de: "Wie der Mac") }
    static func followMacDetail(_ language: String) -> String {
        tr(en: "Your Mac uses \(language)", de: "Dein Mac nutzt \(language)")
    }
    static var languageFootnote: String {
        tr(en: "Switches right away. You can change it later in Settings under General.",
           de: "Wechselt sofort. Du kannst sie später in den Einstellungen unter Allgemein ändern.")
    }

    // MARK: Features

    static var featuresTitle: String { tr(en: "What \(AppInfo.displayName) Does", de: "Das kann \(AppInfo.displayName)") }

    // MARK: Done

    static var doneTitle: String { tr(en: "All Set", de: "Alles bereit") }
    static var doneSubtitle: String {
        tr(en: "This is what is set up. You can change all of it later.",
           de: "Das ist eingerichtet. Du kannst alles später ändern.")
    }
    static var doneLanguage: String { tr(en: "Language", de: "Sprache") }
    static func doneLanguageValue(_ language: String, followsMac: Bool) -> String {
        followsMac ? tr(en: "\(language), same as the Mac", de: "\(language), wie der Mac") : language
    }
    static func donePermissions(granted: Int, of total: Int) -> String {
        tr(en: "\(granted) of \(total) allowed", de: "\(granted) von \(total) erteilt")
    }
    static var donePermissionsTitle: String { tr(en: "Permissions", de: "Freigaben") }
    static var doneSettings: String { tr(en: "Settings", de: "Einstellungen") }
    /// Next to the ⌘, key caps.
    static var doneSettingsWindow: String { tr(en: "In the app menu or with the shortcut", de: "Im App-Menü oder per Kurzbefehl") }
    static var doneSettingsMenuBar: String {
        tr(en: "Click the icon in the menu bar", de: "Klick auf das Symbol in der Menüleiste")
    }
    static var doneFootnote: String {
        tr(en: "You can show this setup again in Settings under General.",
           de: "Diese Einrichtung findest du jederzeit in den Einstellungen unter Allgemein.")
    }
    static var doneRestartNote: String {
        tr(en: "\(AppInfo.displayName) restarts once at the end, so every permission takes effect.",
           de: "\(AppInfo.displayName) startet am Ende einmal neu, damit jede Freigabe wirkt.")
    }

    // MARK: Gallery

    static var galleryWelcomeArt: String { tr(en: "Welcome art", de: "Willkommensbild") }
    static var galleryFeatureRow: String { tr(en: "Feature row", de: "Funktionszeile") }
    static var galleryDoneIcon: String { tr(en: "App icon with check", de: "App-Symbol mit Haken") }
}

/// Copy of the onboarding render scenes only (sample features; the starter registers none).
enum OnboardingSampleText {
    static var organizeTitle: String { tr(en: "Everything in one place", de: "Alles an einem Ort") }
    static var organizeDetail: String {
        tr(en: "Collects what you work on, sorted the way you think.",
           de: "Sammelt, woran du arbeitest, sortiert so, wie du denkst.")
    }
    static var localTitle: String { tr(en: "Stays on your Mac", de: "Bleibt auf deinem Mac") }
    static var localDetail: String {
        tr(en: "No account, no cloud. Your data never leaves this Mac.",
           de: "Kein Konto, keine Cloud. Deine Daten verlassen diesen Mac nie.")
    }
    static var quickTitle: String { tr(en: "One shortcut away", de: "Einen Kurzbefehl entfernt") }
    static var quickDetail: String {
        tr(en: "Open it from any app without leaving what you are doing.",
           de: "Öffne es aus jeder App, ohne zu verlassen, woran du gerade bist.")
    }
}
