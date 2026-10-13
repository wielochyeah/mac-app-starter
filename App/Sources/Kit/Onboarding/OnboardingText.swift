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
        // text-ausnahme: the hint is written in the other language so whoever needs it can read it
        tr(en: "Lieber auf Deutsch? Wähle unten „Deutsch“.", de: "Prefer English? Choose “English” below.")
    }
    static var languageApp: String { tr(en: "App language", de: "Sprache der App") }
    static var languageAppDetail: String { tr(en: "Windows, menus and notifications", de: "Fenster, Menüs und Mitteilungen") }
    /// A language's name in the UI language ("German" / "Deutsch").
    static func languageName(_ lang: Lang) -> String {
        switch lang {
        case .en: tr(en: "English", de: "Englisch")
        case .de: tr(en: "German", de: "Deutsch")
        }
    }
    static var followMac: String { tr(en: "Automatic", de: "Automatisch") }
    /// - offered: the Mac's first language is one the app has; else `language` is the fallback.
    static func followMacDetail(_ language: String, offered: Bool) -> String {
        offered ? tr(en: "Your Mac uses \(language)", de: "Dein Mac nutzt \(language)")
            : tr(en: "\(language), because the app does not offer your Mac’s language",
                 de: "\(language), weil die App die Sprache deines Macs nicht anbietet")
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
            ? tr(en: "Permission for \(names[0]) is still missing. What needs it stays off.",
                 de: "Die Berechtigung für \(names[0]) fehlt noch. Was davon abhängt, bleibt aus.")
            : tr(en: "\(names.count) permissions are still missing. What needs them stays off.",
                 de: "\(names.count) Berechtigungen fehlen noch. Was davon abhängt, bleibt aus.")
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
        sameAsMac ? tr(en: "Automatic (\(language))", de: "Automatisch (\(language))") : language
    }
    static func donePermissions(granted: Int, of total: Int) -> String {
        tr(en: "\(granted) of \(total) allowed", de: "\(granted) von \(total) erlaubt")
    }
    static var donePermissionsTitle: String { tr(en: "Permissions", de: "Berechtigungen") }
    static var doneSettings: String { tr(en: "Settings", de: "Einstellungen") }
    /// Next to the ⌘, key cap.
    static var doneSettingsWindow: String { tr(en: "In the app menu or with the keyboard shortcut", de: "Im App-Menü oder mit dem Tastaturkurzbefehl") }
    static var doneSettingsMenuBar: String {
        tr(en: "Click the icon in the menu bar", de: "Klicke auf das Symbol in der Menüleiste")
    }
    /// One line under the card: where each of the two settings lives later.
    static var doneFootnote: String {
        tr(en: "Language: Settings > General. Permissions: System Settings.",
           de: "Sprache: Einstellungen > Allgemein. Berechtigungen: Systemeinstellungen.")
    }
    static var doneRestartNote: String {
        tr(en: "\(AppInfo.displayName) restarts once at the end so the new permissions take effect.",
           de: "\(AppInfo.displayName) startet am Ende einmal neu, damit die neuen Berechtigungen greifen.")
    }

    // MARK: Gallery

    static var galleryWelcomeArt: String { tr(en: "Welcome art", de: "Willkommensbild") }
    static var galleryFeatureRow: String { tr(en: "Feature row", de: "Funktionszeile") }
    static var galleryDoneIcon: String { tr(en: "App icon with check", de: "App-Symbol mit Haken") }
}

/// Copy of the onboarding render scenes only (sample features; the starter registers none).
enum OnboardingSampleText {
    static var organizeTitle: String { tr(en: "Collect notes", de: "Notizen sammeln") }
    static var organizeDetail: String {
        tr(en: "Saves text from any app in one list, newest first.",
           de: "Sichert Text aus jeder App in einer Liste, den neuesten zuerst.")
    }
    static var localTitle: String { tr(en: "No account, no cloud", de: "Kein Konto, keine Cloud") }
    static var localDetail: String {
        tr(en: "Notes are stored in one file on this Mac.",
           de: "Die Notizen liegen in einer Datei auf diesem Mac.")
    }
    static var quickTitle: String { tr(en: "Open with ⌃⌥N", de: "Mit ⌃⌥N öffnen") }
    static var quickDetail: String {
        tr(en: "The list opens in front of any app, without switching apps.",
           de: "Die Liste öffnet sich über jeder App, ohne dass du die App wechselst.")
    }
}
