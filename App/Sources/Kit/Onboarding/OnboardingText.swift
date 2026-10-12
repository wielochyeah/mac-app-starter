// Texts of the onboarding window and its kit steps (welcome, language, features, done).
// Permission words live in Kit/Permissions/PermissionText.swift.

enum OnboardingText {
    static var windowTitle: String { tr(en: "Set Up \(AppInfo.displayName)", de: "\(AppInfo.displayName) einrichten") }
    /// The advance button on the last step.
    static var done: String { tr(en: "Done", de: "Fertig") }
    static var doneAndRestart: String { tr(en: "Done and Restart", de: "Fertig und neu starten") }

    // MARK: Welcome

    /// What the app does for the person, one line: `app.tagline` in starter.json. nil when the
    /// project has not set one; the welcome then shows the name only (the kit claims nothing).
    static var welcomeLede: String? {
        let line = tr(en: AppConfig.tagline.en, de: AppConfig.tagline.de)
        return line.isEmpty ? nil : line
    }
    static func welcomeNote(steps: Int) -> String {
        tr(en: "Setup takes \(steps) short steps.", de: "Die Einrichtung hat \(steps) kurze Schritte.")
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
    static var languageAppDetail: String { tr(en: "Windows, menus and notifications", de: "Fenster, Menüs und Mitteilungen") }
    /// A language's name in the UI language ("German" / "Deutsch").
    static func languageName(_ lang: Lang) -> String {
        switch lang {
        case .en: tr(en: "English", de: "Englisch")
        case .de: tr(en: "German", de: "Deutsch")
        }
    }
    static var followMac: String { tr(en: "Same as the Mac", de: "Wie der Mac") }
    /// - offered: the Mac's first language is one the app has; else `language` is the fallback.
    static func followMacDetail(_ language: String, offered: Bool) -> String {
        offered ? tr(en: "Your Mac uses \(language)", de: "Dein Mac nutzt \(language)")
            : tr(en: "\(language), because your Mac's language is not offered",
                 de: "\(language), weil die Sprache deines Macs fehlt")
    }
    static var languageFootnote: String {
        tr(en: "The language switches right away.\nYou can also change it later in Settings > General.",
           de: "Die Sprache wechselt sofort.\nÄndern kannst du sie auch später unter Einstellungen > Allgemein.")
    }

    // MARK: Features

    static var featuresTitle: String { tr(en: "What \(AppInfo.displayName) Does", de: "Das kann \(AppInfo.displayName)") }

    // MARK: Done

    /// "All Set" only when every permission of the setup is allowed.
    static func doneTitle(complete: Bool) -> String {
        complete ? tr(en: "All Set", de: "Alles bereit") : tr(en: "Almost Done", de: "Fast fertig")
    }
    static var doneSubtitle: String {
        tr(en: "This is how \(AppInfo.displayName) is set up now.", de: "So ist \(AppInfo.displayName) jetzt eingerichtet.")
    }
    /// The subtitle while permissions are not allowed: what that means and the way back.
    /// - names: the titles of the missing permissions; collapsed: they share one summary row.
    static func doneMissing(_ names: [String], collapsed: Bool) -> String {
        let consequence = names.count == 1
            ? tr(en: "\(names[0]) is not allowed yet. What needs it stays off.",
                 de: "\(names[0]) ist noch nicht erteilt. Was davon abhängt, bleibt aus.")
            : tr(en: "\(names.count) permissions are not allowed yet. What needs them stays off.",
                 de: "\(names.count) Freigaben fehlen noch. Was davon abhängt, bleibt aus.")
        let way = collapsed
            ? tr(en: "Click the row to go back to the first one.", de: "Ein Klick auf die Zeile führt zurück zur ersten.")
            : names.count == 1
                ? tr(en: "Click its row to go back to that step.", de: "Ein Klick auf die Zeile führt zurück zu dem Schritt.")
                : tr(en: "Click a row to go back to that step.", de: "Ein Klick auf eine Zeile führt zurück zu dem Schritt.")
        return consequence + "\n" + way
    }
    static var doneLanguage: String { tr(en: "Language", de: "Sprache") }
    /// - sameAsMac: follows the Mac and the Mac's first language is offered.
    static func doneLanguageValue(_ language: String, sameAsMac: Bool) -> String {
        sameAsMac ? tr(en: "\(language), same as the Mac", de: "\(language), wie der Mac") : language
    }
    static func donePermissions(granted: Int, of total: Int) -> String {
        tr(en: "\(granted) of \(total) allowed", de: "\(granted) von \(total) erteilt")
    }
    static var donePermissionsTitle: String { tr(en: "Permissions", de: "Freigaben") }
    static var doneSettings: String { tr(en: "Settings", de: "Einstellungen") }
    /// Next to the ⌘, key cap.
    static var doneSettingsWindow: String { tr(en: "In the app menu or with the shortcut", de: "Im App-Menü oder per Kurzbefehl") }
    static var doneSettingsMenuBar: String {
        tr(en: "Click the icon in the menu bar", de: "Klick auf das Symbol in der Menüleiste")
    }
    static var doneFootnote: String {
        tr(en: "You can change all of this later in Settings under General.",
           de: "Alles lässt sich später unter Einstellungen > Allgemein ändern.")
    }
    static var doneRestartNote: String {
        tr(en: "\(AppInfo.displayName) restarts once at the end so the new permissions take effect.",
           de: "\(AppInfo.displayName) startet am Ende einmal neu, damit die neuen Freigaben wirken.")
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
        tr(en: "Collects what you work on in one list.",
           de: "Sammelt, woran du arbeitest, in einer Liste.")
    }
    static var localTitle: String { tr(en: "Stays on your Mac", de: "Bleibt auf deinem Mac") }
    static var localDetail: String {
        tr(en: "No account, no cloud. Your data never leaves this Mac.",
           de: "Kein Konto, keine Cloud. Deine Daten verlassen diesen Mac nie.")
    }
    static var quickTitle: String { tr(en: "One shortcut away", de: "Einen Kurzbefehl entfernt") }
    static var quickDetail: String {
        tr(en: "Open it from any app without switching apps.",
           de: "Öffne es aus jeder App, ohne die App zu wechseln.")
    }
}
