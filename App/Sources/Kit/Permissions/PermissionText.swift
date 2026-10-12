// Words for permissions: title, why the app asks, what to do in each state, and short status
// words. Projects replace the "why" sentence per kind with `PermissionsKit.reasons[kind]` (in
// their own feature code), so these kit texts stay generic.

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
        case .automation: tr(en: "Automation", de: "Automation")
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
        default: title(kind)
        }
    }

    /// Why the app asks: the subtitle of the permission step ("\n" where the line should break).
    static func why(_ kind: PermissionKind) -> String {
        switch kind {
        case .microphone:
            tr(en: "\(app) needs your permission to hear you.\nThe microphone runs only while you record.",
               de: "\(app) braucht deine Erlaubnis, um dich zu hören.\nDas Mikrofon läuft nur, während du aufnimmst.")
        case .camera:
            tr(en: "\(app) needs your permission to use the camera.\nIt runs only while you take a picture.",
               de: "\(app) braucht deine Erlaubnis für die Kamera.\nSie läuft nur, während du ein Bild aufnimmst.")
        case .accessibility:
            tr(en: "\(app) needs your permission to work with other apps,\nfor example to insert text at your cursor.",
               de: "\(app) braucht deine Erlaubnis, um mit anderen Apps zu arbeiten,\nzum Beispiel um Text an deinem Cursor einzufügen.")
        case .inputMonitoring:
            tr(en: "\(app) needs your permission to notice\nyour keyboard shortcuts in every app.",
               de: "\(app) braucht deine Erlaubnis, um deine\nKurzbefehle in jeder App zu erkennen.")
        case .screenRecording:
            tr(en: "\(app) needs your permission to see what is on your screen.\nImages stay on your Mac.",
               de: "\(app) braucht deine Erlaubnis, um zu sehen, was auf dem Bildschirm ist.\nBilder bleiben auf deinem Mac.")
        case .notifications:
            tr(en: "\(app) tells you when something is done,\neven while you work in another app.",
               de: "\(app) sagt dir Bescheid, wenn etwas fertig ist,\nauch wenn du gerade in einer anderen App bist.")
        case .automation(let bundleId):
            tr(en: "\(app) needs your permission to control \(PermissionsKit.appName(bundleId))\nfor the actions you start.",
               de: "\(app) braucht deine Erlaubnis, um \(PermissionsKit.appName(bundleId)) zu steuern,\nnur für Aktionen, die du startest.")
        case .speechRecognition:
            tr(en: "\(app) needs your permission to turn speech into text.",
               de: "\(app) braucht deine Erlaubnis, um Sprache in Text umzuwandeln.")
        case .contacts:
            tr(en: "\(app) needs your permission to read your contacts.\nNothing is uploaded.",
               de: "\(app) braucht deine Erlaubnis, um deine Kontakte zu lesen.\nNichts wird hochgeladen.")
        case .calendars:
            tr(en: "\(app) needs your permission to read and add calendar events.",
               de: "\(app) braucht deine Erlaubnis, um Termine zu lesen und anzulegen.")
        case .reminders:
            tr(en: "\(app) needs your permission to read and add reminders.",
               de: "\(app) braucht deine Erlaubnis, um Erinnerungen zu lesen und anzulegen.")
        case .photos:
            tr(en: "\(app) needs your permission to open your photos.\nNothing is uploaded.",
               de: "\(app) braucht deine Erlaubnis, um deine Fotos zu öffnen.\nNichts wird hochgeladen.")
        case .location:
            tr(en: "\(app) needs your location for results near you.\nIt never leaves your Mac.",
               de: "\(app) braucht deinen Standort für Ergebnisse in deiner Nähe.\nEr verlässt deinen Mac nie.")
        case .bluetooth:
            tr(en: "\(app) needs Bluetooth to connect your devices.",
               de: "\(app) braucht Bluetooth, um deine Geräte zu verbinden.")
        case .localNetwork:
            tr(en: "\(app) needs the local network to find devices near you.",
               de: "\(app) braucht das lokale Netzwerk, um Geräte in deiner Nähe zu finden.")
        }
    }

    /// The verb phrase of macOS's question ("… whether <App> may <phrase>").
    private static func askPhrase(_ kind: PermissionKind) -> (en: String, de: String) {
        switch kind {
        case .microphone: ("use your microphone", "dein Mikrofon nutzen")
        case .camera: ("use your camera", "deine Kamera nutzen")
        case .notifications: ("send you notifications", "dir Mitteilungen senden")
        case .automation(let bundleId):
            ("control \(PermissionsKit.appName(bundleId))", "\(PermissionsKit.appName(bundleId)) steuern")
        case .speechRecognition: ("use speech recognition", "die Spracherkennung nutzen")
        case .contacts: ("access your contacts", "auf deine Kontakte zugreifen")
        case .calendars: ("access your calendars", "auf deine Kalender zugreifen")
        case .reminders: ("access your reminders", "auf deine Erinnerungen zugreifen")
        case .photos: ("access your photos", "auf deine Fotos zugreifen")
        case .location: ("use your location", "deinen Standort nutzen")
        case .bluetooth: ("use Bluetooth", "Bluetooth nutzen")
        case .localNetwork: ("find devices on your network", "Geräte in deinem Netzwerk finden")
        case .accessibility, .inputMonitoring, .screenRecording: ("", "")
        }
    }

    /// The lines under the status slot for this state (`app://reveal` shows the app in the Finder).
    static func hint(_ kind: PermissionKind, _ status: PermissionStatus) -> [String] {
        switch status {
        case .granted:
            return [changeLater(kind)]
        case .restartNeeded:
            return [tr(en: "The permission takes effect once \(app) restarts.\nSetup continues right here afterwards.",
                       de: "Die Freigabe greift erst, wenn \(app) neu startet.\nDanach geht die Einrichtung genau hier weiter.")]
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
            if status == .denied {
                return [tr(en: "Turn on \(quoted) in System Settings under \(list).",
                           de: "Schalte in den Systemeinstellungen unter \(list) den Eintrag \(quoted) ein.")]
            }
            let phrase = askPhrase(kind)
            var lines = [tr(en: "macOS asks next whether \(app) may \(phrase.en).\nChoose “Allow”.",
                            de: "macOS fragt gleich, ob \(app) \(phrase.de) darf.\nWähle „Erlauben“.")]
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
                              de: "Klick im Dialog auf „Systemeinstellungen öffnen“ und schalte dort \(quoted) ein.")
                return kind.needsRestart ? [open, restart] : [open]
            }
            let switchOn = tr(en: "Turn on \(quoted) in System Settings under \(list).",
                              de: "Schalte in den Systemeinstellungen unter \(list) den Eintrag \(quoted) ein.")
            return [switchOn, kind.needsRestart ? restart : revealHint]
        }
    }

    static var revealHint: String {
        tr(en: "Not in the list? Click [Show in Finder](app://reveal) and drag the app into it.",
           de: "Steht die App nicht in der Liste? Klick auf [Im Finder zeigen](app://reveal) und zieh sie hinein.")
    }

    private static func changeLater(_ kind: PermissionKind) -> String {
        if kind == .notifications {
            return tr(en: "You can change this anytime in System Settings\nunder “Notifications”.",
                      de: "Ändern kannst du das jederzeit in den Systemeinstellungen\nunter „Mitteilungen“.")
        }
        return tr(en: "You can change this anytime in System Settings\nunder “Privacy & Security”.",
                  de: "Ändern kannst du das jederzeit in den Systemeinstellungen\nunter „Datenschutz & Sicherheit“.")
    }

    /// Short status words for summaries and lists.
    static func short(_ status: PermissionStatus) -> String {
        switch status {
        case .granted: PatternsText.granted
        case .denied: PatternsText.denied
        case .missing: tr(en: "Not set up", de: "Nicht eingerichtet")
        case .requested: tr(en: "Waiting", de: "Wartet")
        case .restartNeeded: tr(en: "After restart", de: "Nach Neustart")
        }
    }

    /// The status slot's waiting word: a dialog waits for the answer, a switch for the person.
    static func waiting(_ kind: PermissionKind) -> String {
        kind.prompt == .settingsSwitch ? PatternsText.waitingForSwitch : PatternsText.waitingForAnswer
    }

    static var firstUse: String { tr(en: "Asked on first use", de: "Fragt bei der ersten Nutzung") }
}
