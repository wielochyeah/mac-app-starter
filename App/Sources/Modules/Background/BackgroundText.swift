import Foundation

// Texts of the background module (jobs, login item, settings pane, onboarding step). English and
// German (du).

enum BackgroundText {
    // MARK: Settings pane

    static var paneTitle: String { tr(en: "Background", de: "Hintergrund") }
    static var paneIntro: String {
        tr(en: "What the app does on its own, and whether it starts with your Mac.",
           de: "Was die App von selbst erledigt und ob sie mit deinem Mac startet.")
    }
    static var startSection: String { tr(en: "Start", de: "Start") }
    static var openAtLogin: String { tr(en: "Open at login", de: "Beim Anmelden starten") }
    static var openAtLoginDetail: String {
        tr(en: "Opens with your Mac and waits quietly in the background.",
           de: "Öffnet sich mit deinem Mac und wartet still im Hintergrund.")
    }

    static func unavailable(_ reason: LoginItem.Unavailable) -> String {
        let app = AppInfo.displayName
        return switch reason {
        case .notBundle:
            tr(en: "Only the app itself can open at login, not a bare program file.",
               de: "Beim Anmelden starten kann nur die App selbst, keine einzelne Programmdatei.")
        case .diskImage:
            tr(en: "\(app) is running from the disk image. Move it to the Applications folder and open it from there.",
               de: "\(app) läuft noch vom Disk-Image. Ziehe die App in den Ordner „Programme“ und öffne sie dort.")
        case .translocated:
            tr(en: "macOS opened \(app) from a temporary place. Move it to the Applications folder and open it again.",
               de: "macOS hat \(app) an einem vorläufigen Ort geöffnet. Ziehe die App in den Ordner „Programme“ und öffne sie erneut.")
        case .notInstalled:
            tr(en: "Only for the installed app: move \(app) to the Applications folder and open it from there.",
               de: "Nur für die installierte App: Ziehe \(app) in den Ordner „Programme“ und öffne die App von dort.")
        }
    }

    static var needsApproval: String {
        tr(en: "The app opens at login once you allow it in System Settings under General > Login Items & Extensions.",
           de: "Die App startet erst beim Anmelden, wenn du das in den Systemeinstellungen unter Allgemein > Anmeldeobjekte & Erweiterungen erlaubst.")
    }
    static var openLoginItems: String { tr(en: "Open System Settings", de: "Systemeinstellungen öffnen") }

    static func loginItemFailed(_ message: String) -> String {
        tr(en: "The login item could not be changed: \(message)", de: "Das Anmeldeobjekt ließ sich nicht ändern: \(message)")
    }

    // MARK: Jobs

    static var jobs: String { tr(en: "Tasks", de: "Aufgaben") }
    static var noJobs: String { tr(en: "No tasks", de: "Keine Aufgaben") }
    static var noJobsDetail: String {
        tr(en: "No tasks are scheduled for this app.", de: "Für diese App sind keine Aufgaben geplant.")
    }
    static var runNow: String { tr(en: "Run Now", de: "Jetzt ausführen") }
    static var running: String { tr(en: "Running", de: "Läuft") }

    static func outcome(_ outcome: JobOutcome?) -> String {
        switch outcome {
        case nil: tr(en: "Not run yet", de: "Noch nicht gelaufen")
        case .done(let note): note ?? tr(en: "Done", de: "Erledigt")
        case .nothingToDo: tr(en: "Nothing to do", de: "Nichts zu tun")
        case .failed: tr(en: "Failed", de: "Fehlgeschlagen")
        }
    }

    /// "Every 30 minutes", "Hourly", "Every 6 hours", "Daily".
    static func every(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if seconds < 60 {
            let s = max(Int(seconds.rounded()), 1)
            return s == 1 ? tr(en: "Every second", de: "Jede Sekunde") : tr(en: "Every \(s) seconds", de: "Alle \(s) Sekunden")
        }
        if minutes == 1 { return tr(en: "Every minute", de: "Jede Minute") }
        if minutes == 7 * 1440 { return tr(en: "Weekly", de: "Wöchentlich") }
        if minutes % 1440 == 0 {
            let d = minutes / 1440
            return d == 1 ? tr(en: "Daily", de: "Täglich") : tr(en: "Every \(d) days", de: "Alle \(d) Tage")
        }
        if minutes % 60 == 0 {
            let h = minutes / 60
            return h == 1 ? tr(en: "Hourly", de: "Stündlich") : tr(en: "Every \(h) hours", de: "Alle \(h) Stunden")
        }
        return tr(en: "Every \(minutes) minutes", de: "Alle \(minutes) Minuten")
    }

    /// "4 minutes ago" / "vor 4 Minuten"; under a minute "just now" / "gerade eben".
    static func ago(_ date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 60 { return tr(en: "just now", de: "gerade eben") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Localizer.shared.lang.locale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// The row's second line: "Every 30 minutes, last run 4 minutes ago".
    static func summary(interval: TimeInterval, lastRun: Date?, now: Date) -> String {
        guard let lastRun else { return every(interval) }
        let when = ago(lastRun, now: now)
        return tr(en: "\(every(interval)), last run \(when)", de: "\(every(interval)), zuletzt \(when)")
    }

    /// Tooltip of the outcome: "Took 1.2 s".
    static func took(_ seconds: TimeInterval) -> String {
        tr(en: "Took \(Format.seconds(seconds))", de: "Dauer \(Format.seconds(seconds))")
    }

    static func jobSwitch(_ title: String) -> String {
        tr(en: "Run \(title) automatically", de: "\(title) automatisch ausführen")
    }

    // MARK: Onboarding

    static var stepTitle: String { tr(en: "Start with Your Mac", de: "Mit dem Mac starten") }
    static var stepSubtitle: String {
        tr(en: "\(AppInfo.displayName) is there as soon as you log in, and waits quietly in the background.",
           de: "\(AppInfo.displayName) ist da, sobald du dich anmeldest, und wartet still im Hintergrund.")
    }
    static var stepToggleDetail: String {
        tr(en: "You can change this anytime in Settings.", de: "Das kannst du jederzeit in den Einstellungen ändern.")
    }
    static var stepFootnote: String {
        tr(en: "macOS lists \(AppInfo.displayName) in System Settings under General > Login Items & Extensions.",
           de: "macOS führt \(AppInfo.displayName) in den Systemeinstellungen unter Allgemein > Anmeldeobjekte & Erweiterungen.")
    }

    // MARK: Gallery

    static var galleryJobs: String { tr(en: "Background tasks", de: "Hintergrundaufgaben") }
}

/// Sample jobs of the renders (never registered in the app).
enum BackgroundSampleText {
    static var cleanup: String { tr(en: "Clean up the cache", de: "Cache aufräumen") }
    static var checkFolder: String { tr(en: "Check the inbox folder", de: "Eingangsordner prüfen") }
    static var backup: String { tr(en: "Back up the database", de: "Datenbank sichern") }
    static var sync: String { tr(en: "Sync with the shared folder", de: "Mit dem geteilten Ordner abgleichen") }
    static var report: String { tr(en: "Weekly summary", de: "Wochenübersicht") }
    static var folderMissing: String { tr(en: "The shared folder is not connected.", de: "Der geteilte Ordner ist nicht verbunden.") }
    static var removed: String { tr(en: "12 files removed", de: "12 Dateien entfernt") }
    static var newJob: String { tr(en: "Index new documents", de: "Neue Dokumente erfassen") }
    static var notPermitted: String { tr(en: "Operation not permitted.", de: "Vorgang nicht erlaubt.") }
}
