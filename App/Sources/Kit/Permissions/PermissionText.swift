// Words for permissions: title, why the app asks, what to do in each state, and short status
// words. Projects replace the "why" sentence per kind with `PermissionsKit.reasons[kind]` (in
// their own feature code). The kit's own sentences only say what the permission is for: no
// promise about storage, uploads or when a device runs, because the kit cannot keep it for
// every app. A project that can keep one adds it in its own reason.

enum PermissionText {
    private static var app: String { AppInfo.displayName }

    static func title(_ kind: PermissionKind) -> String {
        switch kind {
        case .microphone: tr(en: "Microphone", de: "Mikrofon")
        case .camera: tr(en: "Camera", de: "Kamera")
        case .accessibility: tr(en: "Accessibility", de: "Bedienungshilfen")
        case .inputMonitoring: tr(en: "Input Monitoring", de: "Eingabeüberwachung")
        case .screenRecording: tr(en: "Screen Recording", de: "Bildschirmaufnahme")
        case .notifications: tr(en: "Notifications", de: "Mitteilungen")
        case .automation(let bundleId):
            tr(en: "Control \(PermissionsKit.appName(bundleId))", de: "\(PermissionsKit.appName(bundleId)) steuern")
        case .speechRecognition: tr(en: "Speech Recognition", de: "Spracherkennung")
        case .contacts: tr(en: "Contacts", de: "Kontakte")
        case .calendars: tr(en: "Calendars", de: "Kalender")
        case .reminders: tr(en: "Reminders", de: "Erinnerungen")
        case .photos: tr(en: "Photos", de: "Fotos")
        case .location: tr(en: "Location", de: "Standort")
        case .bluetooth: tr(en: "Bluetooth", de: "Bluetooth")
        case .localNetwork: tr(en: "Local Network", de: "Lokales Netzwerk")
        }
    }

    /// The list's name in System Settings, where it differs from the title.
    static func settingsName(_ kind: PermissionKind) -> String {
        switch kind {
        case .screenRecording: tr(en: "Screen & System Audio Recording", de: "Bildschirm- & Systemaudioaufnahme")
        case .location: tr(en: "Location Services", de: "Ortungsdienste")
        case .automation: tr(en: "Automation", de: "Automation")
        default: title(kind)
        }
    }

    /// Why the app asks: the subtitle of the permission step ("\n" where the line should break).
    static func why(_ kind: PermissionKind) -> String {
        switch kind {
        case .microphone:
            tr(en: "\(app) needs your permission to hear you.",
               de: "\(app) braucht deine Erlaubnis, um dich zu hören.")
        case .camera:
            tr(en: "\(app) needs your permission to use the camera.",
               de: "\(app) braucht deine Erlaubnis für die Kamera.")
        case .accessibility:
            // umbruch: a balanced two-line subtitle under the step title (VoiceBud)
            tr(en: "\(app) needs your permission to work with other apps,\nfor example to insert text at your cursor.",
               de: "\(app) braucht deine Erlaubnis, um mit anderen Apps zu arbeiten,\nzum Beispiel um Text an deinem Cursor einzufügen.")
        case .inputMonitoring:
            // umbruch: a balanced two-line subtitle under the step title (VoiceBud)
            tr(en: "\(app) needs your permission to notice\nyour keyboard shortcuts in every app.",
               de: "\(app) braucht deine Erlaubnis, um in jeder App\ndeine Tastaturkurzbefehle zu erkennen.")
        case .screenRecording:
            tr(en: "\(app) needs your permission to see what is on your screen.",
               de: "\(app) braucht deine Erlaubnis, um zu sehen, was auf dem Bildschirm ist.")
        case .notifications:
            // umbruch: a balanced two-line subtitle under the step title (VoiceBud)
            tr(en: "\(app) needs your permission to send you notifications,\neven while you work in another app.",
               de: "\(app) braucht deine Erlaubnis für Mitteilungen,\nauch wenn du gerade in einer anderen App bist.")
        case .automation(let bundleId):
            tr(en: "\(app) needs your permission to control \(PermissionsKit.appName(bundleId)).",
               de: "\(app) braucht deine Erlaubnis, um \(PermissionsKit.appName(bundleId)) zu steuern.")
        case .speechRecognition:
            tr(en: "\(app) needs your permission to turn speech into text.",
               de: "\(app) braucht deine Erlaubnis, um Sprache in Text umzuwandeln.")
        case .contacts:
            tr(en: "\(app) needs your permission to read your contacts.",
               de: "\(app) braucht deine Erlaubnis, um deine Kontakte zu lesen.")
        case .calendars:
            tr(en: "\(app) needs your permission to read and add calendar events.",
               de: "\(app) braucht deine Erlaubnis, um Termine zu lesen und anzulegen.")
        case .reminders:
            tr(en: "\(app) needs your permission to read and add reminders.",
               de: "\(app) braucht deine Erlaubnis, um Erinnerungen zu lesen und anzulegen.")
        case .photos:
            tr(en: "\(app) needs your permission to open your photos.",
               de: "\(app) braucht deine Erlaubnis, um deine Fotos zu öffnen.")
        case .location:
            tr(en: "\(app) needs your location for results near you.",
               de: "\(app) braucht deinen Standort für Ergebnisse in deiner Nähe.")
        case .bluetooth:
            tr(en: "\(app) needs Bluetooth to connect your devices.",
               de: "\(app) braucht Bluetooth, um deine Geräte zu verbinden.")
        case .localNetwork:
            tr(en: "\(app) needs the local network to find devices near you.",
               de: "\(app) braucht das lokale Netzwerk, um Geräte in deiner Nähe zu finden.")
        }
    }

    /// The first hint line of a dialog kind before macOS asks: its question, and what to choose.
    private static func askLine(_ kind: PermissionKind) -> String {
        switch kind {
        case .microphone:
            tr(en: "macOS asks next whether \(app) may use your microphone.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) dein Mikrofon nutzen darf.\nWähle „Erlauben“.")
        case .camera:
            tr(en: "macOS asks next whether \(app) may use your camera.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) deine Kamera nutzen darf.\nWähle „Erlauben“.")
        case .notifications:
            tr(en: "macOS asks next whether \(app) may send you notifications.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) dir Mitteilungen senden darf.\nWähle „Erlauben“.")
        case .automation(let bundleId):
            tr(en: "macOS asks next whether \(app) may control \(PermissionsKit.appName(bundleId)).\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) \(PermissionsKit.appName(bundleId)) steuern darf.\nWähle „Erlauben“.")
        case .speechRecognition:
            tr(en: "macOS asks next whether \(app) may use speech recognition.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) die Spracherkennung nutzen darf.\nWähle „Erlauben“.")
        case .contacts:
            tr(en: "macOS asks next whether \(app) may access your contacts.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) auf deine Kontakte zugreifen darf.\nWähle „Erlauben“.")
        case .calendars:
            tr(en: "macOS asks next whether \(app) may access your calendars.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) auf deine Kalender zugreifen darf.\nWähle „Erlauben“.")
        case .reminders:
            tr(en: "macOS asks next whether \(app) may access your reminders.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) auf deine Erinnerungen zugreifen darf.\nWähle „Erlauben“.")
        case .photos:
            tr(en: "macOS asks next whether \(app) may access your photos.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) auf deine Fotos zugreifen darf.\nWähle „Erlauben“.")
        case .location:
            tr(en: "macOS asks next whether \(app) may use your location.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) deinen Standort nutzen darf.\nWähle „Erlauben“.")
        case .bluetooth:
            tr(en: "macOS asks next whether \(app) may use Bluetooth.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) Bluetooth nutzen darf.\nWähle „Erlauben“.")
        case .localNetwork:
            tr(en: "macOS asks next whether \(app) may find devices on your network.\nChoose “Allow”.",
               de: "macOS fragt gleich, ob \(app) Geräte in deinem Netzwerk finden darf.\nWähle „Erlauben“.")
        case .accessibility, .inputMonitoring, .screenRecording:
            ""   // switch kinds: no dialog question (see `hint`)
        }
    }

    /// The lines under the status slot for this state (`app://reveal` shows the app in the Finder).
    static func hint(_ kind: PermissionKind, _ status: PermissionStatus) -> [String] {
        switch status {
        case .granted:
            return [changeLater(kind)]
        case .restartNeeded:
            return [tr(en: "The permission takes effect once \(app) restarts.\nSetup continues right here afterwards.",
                       de: "Die Berechtigung greift erst, wenn \(app) neu startet.\nDanach geht die Einrichtung genau hier weiter.")]
        case .missing, .requested, .denied:
            break
        }
        let quoted = tr(en: "“\(app)”", de: "„\(app)“")
        let list = tr(en: "“\(settingsName(kind))”", de: "„\(settingsName(kind))“")
        switch kind.prompt {
        case .firstUse:
            return [tr(en: "macOS asks the first time \(app) searches your network.\nChoose “Allow”.",
                       de: "macOS fragt, wenn \(app) zum ersten Mal im Netzwerk sucht.\nWähle „Erlauben“.")]
        case .dialog:
            if status == .denied, case .automation(let bundleId) = kind {
                // System Settings lists the target under this app: that switch is the one
                let target = tr(en: "“\(PermissionsKit.appName(bundleId))”", de: "„\(PermissionsKit.appName(bundleId))“")
                return [tr(en: "In System Settings under \(list), turn on \(target) below \(quoted).",
                           de: "Schalte in den Systemeinstellungen unter \(list) bei \(quoted) den Eintrag \(target) ein.")]
            }
            if status == .denied {
                return [tr(en: "Turn on \(quoted) in System Settings under \(list).",
                           de: "Schalte in den Systemeinstellungen unter \(list) den Eintrag \(quoted) ein.")]
            }
            var lines = [askLine(kind)]
            if case .automation(let bundleId) = kind {
                let target = PermissionsKit.appName(bundleId)
                lines.append(tr(en: "\(target) must be open for this.", de: "Dafür muss \(target) geöffnet sein."))
            }
            return lines
        case .settingsSwitch:
            let restart = tr(en: "Then restart \(app) once, with one click here.",
                             de: "Danach startest du \(app) einmal neu, mit einem Klick hier.")
            if status == .missing {
                let open = tr(en: "In the dialog, click “Open System Settings” and turn on \(quoted) there.",
                              de: "Klicke im Dialog auf „Systemeinstellungen öffnen“ und schalte dort \(quoted) ein.")
                return kind.needsRestart ? [open, restart] : [open]
            }
            let switchOn = tr(en: "Turn on \(quoted) in System Settings under \(list).",
                              de: "Schalte in den Systemeinstellungen unter \(list) den Eintrag \(quoted) ein.")
            return [switchOn, kind.needsRestart ? restart : revealHint]
        }
    }

    static var revealHint: String {
        tr(en: "Not in the list? Click [Show in Finder](app://reveal) and drag the app into it.",
           de: "Steht die App nicht in der Liste? Klicke auf [Im Finder zeigen](app://reveal) und ziehe sie hinein.")
    }

    private static func changeLater(_ kind: PermissionKind) -> String {
        if kind == .notifications {
            // umbruch: a balanced two-line subtitle under the step title (VoiceBud)
            return tr(en: "You can change this anytime in System Settings\nunder “Notifications”.",
                      de: "Ändern kannst du das jederzeit in den Systemeinstellungen\nunter „Mitteilungen“.")
        }
        // umbruch: a balanced two-line subtitle under the step title (VoiceBud)
        return tr(en: "You can change this anytime in System Settings\nunder “Privacy & Security”.",
                  de: "Ändern kannst du das jederzeit in den Systemeinstellungen\nunter „Datenschutz & Sicherheit“.")
    }

    /// Short status words for summaries and lists.
    static func short(_ status: PermissionStatus) -> String {
        switch status {
        case .granted: PatternsText.granted
        case .denied: PatternsText.denied
        case .missing: tr(en: "Not allowed yet", de: "Noch nicht erlaubt")
        case .requested: tr(en: "Waiting", de: "Wartet")
        case .restartNeeded: tr(en: "After restart", de: "Nach Neustart")
        }
    }

    /// The status slot's waiting word: a dialog waits for the answer, a switch for the person.
    static func waiting(_ kind: PermissionKind) -> String {
        kind.prompt == .settingsSwitch ? PatternsText.waitingForSwitch : PatternsText.waitingForAnswer
    }
}
