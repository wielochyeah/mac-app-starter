// Every user-visible string of the hotkeys module. Rule reasons ported from VoiceBud
// (ui/ShortcutRules.swift, ui/Hub.swift), with the app's name instead of "VoiceBud".

enum HotkeysText {
    // MARK: Pane

    static var pane: String { tr(en: "Keyboard Shortcuts", de: "Tastaturkurzbefehle") }
    static var paneIntro: String {
        tr(en: "These shortcuts work in every app, even while \(AppInfo.displayName) is in the background.",
           de: "Diese Kurzbefehle wirken in jeder App, auch wenn \(AppInfo.displayName) im Hintergrund ist.")
    }
    static var paneFootnote: String {
        tr(en: "A shortcut is a key with modifier keys, like ⌥⇧⌘K, or an F-key alone. \(AppInfo.displayName) refuses combinations that macOS or almost every app already uses and tells you what they do there.",
           de: "Ein Kurzbefehl ist eine Taste mit Sondertasten, etwa ⌥⇧⌘K, oder eine F-Taste allein. Was macOS oder fast jede App schon nutzt, lehnt \(AppInfo.displayName) ab und sagt dir, was die Kombination dort tut.")
    }
    static var emptyTitle: String { tr(en: "No shortcuts yet", de: "Noch keine Kurzbefehle") }
    static var emptyMessage: String {
        tr(en: "Once \(AppInfo.displayName) offers shortcuts, you set them up here.",
           de: "Sobald \(AppInfo.displayName) Kurzbefehle anbietet, stellst du sie hier ein.")
    }

    // MARK: Recorder row

    static var change: String { tr(en: "Change", de: "Ändern") }
    static var cancel: String { tr(en: "Cancel", de: "Abbrechen") }
    static var standard: String { tr(en: "Use Default", de: "Standard verwenden") }
    static var standardHelp: String { tr(en: "Back to the default shortcut", de: "Zurück zum Standard-Kurzbefehl") }
    static var undo: String { tr(en: "Undo", de: "Widerrufen") }
    static func use(_ keys: String) -> String { tr(en: "Use \(keys)", de: "\(keys) übernehmen") }
    static var pressKeys: String { tr(en: "Press keys…", de: "Drücke die Tasten …") }
    static var none: String { tr(en: "None", de: "Keiner") }
    static var recordPrompt: String {
        // \u{00A0} (no-break space) and \u{2011} (no-break hyphen) keep glyph groups, "⌫ removes"
        // and "F-key" on one line
        tr(en: "Press the new combination: a key with up to four modifier keys (⌃\u{00A0}⌥\u{00A0}⇧\u{00A0}⌘), or an F\u{2011}key. Esc\u{00A0}cancels, ⌫\u{00A0}removes the shortcut.",
           de: "Drücke die neue Kombination: eine Taste mit bis zu vier Sondertasten (⌃\u{00A0}⌥\u{00A0}⇧\u{00A0}⌘) oder eine F\u{2011}Taste. Esc\u{00A0}bricht ab, ⌫\u{00A0}entfernt den Kurzbefehl.")
    }
    static var recordHolding: String {
        tr(en: "Now add a key, like a letter or a number.", de: "Jetzt noch eine Taste dazu, etwa einen Buchstaben oder eine Zahl.")
    }
    /// After a refusal while recording (every reason already says what to press instead).
    static var escToCancel: String { tr(en: "Esc\u{00A0}cancels.", de: "Esc\u{00A0}bricht ab.") }
    static var removed: String {
        tr(en: "No shortcut. “Use Default” brings the original back.", de: "Kein Kurzbefehl. Mit „Standard verwenden“ kommt der ursprüngliche zurück.")
    }
    static func accessibilityKeys(_ keys: String) -> String { tr(en: "Shortcut \(keys)", de: "Kurzbefehl \(keys)") }

    // MARK: Recorder refusals (what the keys did while recording)

    static var modifiersAlone: String {
        tr(en: "Modifier keys alone do not work here. Press them together with a key, like ⌃⌥K.",
           de: "Sondertasten allein gehen hier nicht. Drücke sie zusammen mit einer Taste, etwa ⌃⌥K.")
    }
    static func twoKeys(_ a: String, _ b: String) -> String {
        tr(en: "\(a) and \(b) are two regular keys at once. macOS cannot report that as a shortcut. A shortcut is one key with up to four modifier keys (⌃\u{00A0}⌥\u{00A0}⇧\u{00A0}⌘).",
           de: "\(a) und \(b) sind zwei normale Tasten auf einmal. Das kann macOS nicht als Kurzbefehl melden. Ein Kurzbefehl ist eine Taste mit bis zu vier Sondertasten (⌃\u{00A0}⌥\u{00A0}⇧\u{00A0}⌘).")
    }
    static var fnAlone: String {
        tr(en: "\(AppInfo.displayName) cannot use the fn key alone as a shortcut. Use a key with ⌃, ⌥ or ⌘.",
           de: "Die fn-Taste allein kann \(AppInfo.displayName) nicht als Kurzbefehl nutzen. Nimm eine Taste mit ⌃, ⌥ oder ⌘.")
    }
    static var fnWithKey: String {
        tr(en: "macOS does not report the fn key together with another key to apps. It uses such combinations itself, like fn F for full screen or fn Q for Quick Note. Leave fn out.",
           de: "Die fn-Taste zusammen mit einer anderen Taste meldet macOS nicht an Apps. Solche Kombinationen nutzt macOS selbst, etwa fn F für Vollbild oder fn Q für die Schnellnotiz. Lass fn weg.")
    }
    static func caughtEarlier(_ keys: String) -> String {
        tr(en: "macOS or another app caught \(keys) before \(AppInfo.displayName) could see the keys (like ⌘Space for Spotlight or ⇧⌘4 for screenshots). This combination is taken. Use another one.",
           de: "macOS oder eine andere App hat \(keys) abgefangen, bevor \(AppInfo.displayName) die Tasten sehen konnte (etwa ⌘Leertaste für Spotlight oder ⇧⌘4 für Bildschirmfotos). Diese Kombination ist schon belegt. Nimm eine andere.")
    }
    static var lostFocus: String {
        tr(en: "\(AppInfo.displayName) moved to the background. If macOS used the combination itself (like ⌘⇥ or ⌘Space), it is taken. Click “Change” to try again.",
           de: "\(AppInfo.displayName) ist in den Hintergrund gerückt. Hat macOS die Kombination selbst genutzt (etwa ⌘⇥ oder ⌘Leertaste), ist sie schon belegt. Klicke auf „Ändern“ für einen neuen Versuch.")
    }
    static func heldElsewhere(_ keys: String) -> String {
        tr(en: "Another app already holds \(keys), like Raycast, Alfred or a window tool. \(AppInfo.displayName) would not get the keys. Free the combination there or use another one.",
           de: "Eine andere App hält \(keys) schon fest, etwa Raycast, Alfred oder ein Fenster-Tool. \(AppInfo.displayName) bekäme die Tasten nicht. Gib die Kombination dort frei oder nimm eine andere.")
    }
    static func macOSRefused(_ keys: String, _ status: Int) -> String {
        tr(en: "macOS does not accept \(keys) as a shortcut (error \(status)). Use another combination.",
           de: "macOS nimmt \(keys) nicht als Kurzbefehl an (Fehler \(status)). Nimm eine andere Kombination.")
    }

    // MARK: Row status (a hotkey that is set but does not arrive)

    static func heldElsewhereStatus(_ keys: String) -> String {
        tr(en: "Another app holds \(keys), so this shortcut does not arrive. Free it there or choose another one.",
           de: "Eine andere App hält \(keys) fest, deshalb kommt dieser Kurzbefehl nicht an. Gib ihn dort frei oder wähle einen anderen.")
    }
    static func duplicateStatus(_ keys: String, of title: String) -> String {
        tr(en: "“\(title)” has the same keys \(keys) and gets them, so this shortcut does nothing. Choose another combination.",
           de: "„\(title)“ hat dieselben Tasten \(keys) und bekommt sie, deshalb tut dieser Kurzbefehl nichts. Wähle eine andere Kombination.")
    }
    static func failedStatus(_ keys: String, _ status: Int) -> String {
        tr(en: "macOS did not accept \(keys) (error \(status)). Choose another combination.",
           de: "macOS hat \(keys) nicht angenommen (Fehler \(status)). Wähle eine andere Kombination.")
    }

    // MARK: Rule reasons (ShortcutRules)

    static var escCancels: String { tr(en: "Esc cancels the recording", de: "Esc bricht die Aufnahme ab") }
    static var mediaKeys: String {
        tr(en: "macOS keeps the volume, media and brightness keys for itself. Use an F-key or a combination with ⌃ or ⌘.",
           de: "Lautstärke-, Medien- und Helligkeitstasten behält macOS für sich. Nimm eine F-Taste oder eine Kombination mit ⌃ oder ⌘.")
    }
    static func alwaysMacOS(_ keys: String, _ what: String) -> String {
        tr(en: "\(keys) \(what). That always belongs to macOS. Use another combination.",
           de: "\(keys) \(what). Das gehört immer macOS. Nimm eine andere Kombination.")
    }
    static func systemNamed(_ keys: String, _ what: String) -> String {
        tr(en: "\(keys) \(what). It is a macOS shortcut (System Settings > Keyboard > Keyboard Shortcuts). Use another combination.",
           de: "\(keys) \(what). Das ist ein Kurzbefehl von macOS (Systemeinstellungen > Tastatur > Tastaturkurzbefehle). Nimm eine andere Kombination.")
    }
    static func systemUnnamed(_ keys: String) -> String {
        tr(en: "macOS uses \(keys) itself (System Settings > Keyboard > Keyboard Shortcuts). Use another combination.",
           de: "\(keys) belegt macOS selbst (Systemeinstellungen > Tastatur > Tastaturkurzbefehle). Nimm eine andere Kombination.")
    }
    static func systemOffNote(_ keys: String, _ what: String) -> String {
        tr(en: "Note: \(keys) \(what) once you switch this shortcut on in macOS. It is off on your Mac. If you switch it on later, macOS wins.",
           de: "Hinweis: \(keys) \(what), sobald du diesen Kurzbefehl in macOS einschaltest. Bei dir ist er aus. Schaltest du ihn später ein, gewinnt macOS.")
    }
    static func everyApp(_ keys: String, _ what: String, app: String) -> String {
        tr(en: "\(keys) \(what) in almost every app. As a \(app) shortcut, it would stop working everywhere. Add ⌃, ⌥ or ⇧.",
           de: "\(keys) \(what), und das in fast jeder App. Als Kurzbefehl von \(app) ginge das überall verloren. Nimm ⌃, ⌥ oder ⇧ dazu.")
    }
    static func everyAppOther(_ keys: String, _ what: String, app: String) -> String {
        tr(en: "\(keys) \(what) in almost every app. As a \(app) shortcut, it would stop working everywhere. Use another combination.",
           de: "\(keys) \(what), und das in fast jeder App. Als Kurzbefehl von \(app) ginge das überall verloren. Nimm eine andere Kombination.")
    }
    static var commandAlone: String {
        tr(en: "⌘ with a single key belongs to the apps’ menu commands. Add ⌃, ⌥ or ⇧.",
           de: "⌘ mit nur einer Taste gehört den Menübefehlen der Apps. Nimm ⌃, ⌥ oder ⇧ dazu.")
    }
    static func everyTextField(_ keys: String, _ what: String) -> String {
        tr(en: "\(keys) \(what) in every text field of macOS. As a shortcut that would be lost everywhere. Use another combination.",
           de: "\(keys) \(what), und das in jedem Textfeld von macOS. Als Kurzbefehl ginge das überall verloren. Nimm eine andere Kombination.")
    }
    static func editingKey(_ keys: String) -> String {
        tr(en: "Every app needs \(keys) for writing and moving around in text. Use a letter, a number or an F-key.",
           de: "\(keys) braucht jede App zum Schreiben und Bewegen im Text. Nimm einen Buchstaben, eine Zahl oder eine F-Taste.")
    }
    static func editingKeyNote(_ keys: String) -> String {
        tr(en: "Note: some apps use \(keys) themselves, like window tools with ⌃⌥ and the arrow keys, or chat apps to send. It then no longer works there.",
           de: "Hinweis: \(keys) nutzen manche Apps selbst, etwa Fenster-Tools mit ⌃⌥ und Pfeiltasten oder Chat-Apps zum Abschicken. Dort geht es dann nicht mehr.")
    }
    static var spaceAlone: String {
        tr(en: "The space bar is needed for writing. Add ⌃ or ⌘.", de: "Die Leertaste braucht man zum Schreiben. Nimm ⌃ oder ⌘ dazu.")
    }
    static func typesCharacter(_ keys: String, _ ch: String) -> String {
        tr(en: "\(keys) types “\(ch)”. As a shortcut you could no longer type it in any app. Add ⌃, ⌥ or ⌘.",
           de: "\(keys) tippt „\(ch)“. Als Kurzbefehl könntest du das in keiner App mehr schreiben. Nimm ⌃, ⌥ oder ⌘ dazu.")
    }
    static func needsModifier(_ keys: String) -> String {
        tr(en: "\(keys) does not work as a shortcut. Add ⌃, ⌥ or ⌘.", de: "\(keys) geht als Kurzbefehl nicht. Nimm ⌃, ⌥ oder ⌘ dazu.")
    }
    static func deadKey(_ keys: String, _ accent: String) -> String {
        tr(en: "On your keyboard \(keys) sets the accent “\(accent)” (for letters like ñ or é). As a shortcut it would be lost everywhere. Add ⌃ or ⌘.",
           de: "\(keys) setzt auf deiner Tastatur den Akzent „\(accent)“ (für Buchstaben wie ñ oder é). Als Kurzbefehl ginge der überall verloren. Nimm ⌃ oder ⌘ dazu.")
    }
    static func neededCharacter(_ keys: String, _ ch: String) -> String {
        tr(en: "On your keyboard \(keys) types “\(ch)”. As a shortcut you could no longer type “\(ch)” in any app. Add ⌃ or ⌘.",
           de: "\(keys) tippt auf deiner Tastatur „\(ch)“. Als Kurzbefehl könntest du „\(ch)“ in keiner App mehr schreiben. Nimm ⌃ oder ⌘ dazu.")
    }
    static func textWarnNote(_ keys: String, _ what: String) -> String {
        tr(en: "Note: \(keys) \(what). That then no longer works.", de: "Hinweis: \(keys) \(what). Das geht dann nicht mehr.")
    }
    static func typesSpaceNote(_ keys: String) -> String {
        tr(en: "Note: on your keyboard \(keys) types a space, which then no longer works in any app.",
           de: "Hinweis: \(keys) tippt auf deiner Tastatur ein Leerzeichen. Das geht dann in keiner App mehr.")
    }
    static func rareCharacterNote(_ keys: String, _ ch: String) -> String {
        tr(en: "Note: on your keyboard \(keys) types “\(ch)”, which then no longer works in any app. In password fields macOS pauses such shortcuts, so “\(ch)” arrives there.",
           de: "Hinweis: \(keys) tippt auf deiner Tastatur „\(ch)“. Das geht dann in keiner App mehr. In Passwortfeldern setzt macOS solche Kurzbefehle aus, dort kommt dann „\(ch)“ an.")
    }
    static func terminalRefuse(_ keys: String, _ what: String) -> String {
        tr(en: "\(keys) \(what) (in the Terminal, also in iTerm and VS Code). As a shortcut that would be lost there. Use another combination.",
           de: "\(keys) \(what) (im Terminal, auch in iTerm und VS Code). Als Kurzbefehl ginge das dort verloren. Nimm eine andere Kombination.")
    }
    static func terminalNote(_ keys: String, _ what: String) -> String {
        tr(en: "Note: \(keys) \(what) (in the Terminal, iTerm and VS Code too). That then no longer works there.",
           de: "Hinweis: \(keys) \(what) (im Terminal, auch in iTerm und VS Code). Dort geht das dann nicht mehr.")
    }
    static func commonAppsNote(_ keys: String, _ what: String) -> String {
        tr(en: "Note: \(keys) \(what). That then no longer works.", de: "Hinweis: \(keys) \(what). Das geht dann nicht mehr.")
    }
    static func appMenusNote(_ keys: String, app: String) -> String {
        tr(en: "Note: many apps use ⇧⌘ and ⌥⌘ with a letter for their own menu commands. \(app) cannot check whether an app uses \(keys). If one does, it no longer works there.",
           de: "Hinweis: ⇧⌘ und ⌥⌘ mit einem Buchstaben nutzen viele Apps für eigene Menübefehle. Ob eine App \(keys) belegt, kann \(app) nicht nachsehen. Falls ja, geht es dort nicht mehr.")
    }
    static func voiceOverNote(_ keys: String) -> String {
        tr(en: "Note: VoiceOver uses ⌃⌥ as its VO keys. While VoiceOver is on, \(keys) can replace a VoiceOver command.",
           de: "Hinweis: VoiceOver nutzt ⌃⌥ als VO-Taste. Solange VoiceOver an ist, kann \(keys) dort einen VoiceOver-Befehl ersetzen.")
    }
    static func fnNote(_ keys: String) -> String {
        tr(en: "Note: on Apple keyboards you press fn with \(keys) unless the F-keys are set as standard function keys (System Settings > Keyboard > Keyboard Shortcuts > Function Keys).",
           de: "Hinweis: Auf Apple-Tastaturen drückst du für \(keys) fn mit, solange die F-Tasten nicht als Standard-Funktionstasten eingestellt sind (Systemeinstellungen > Tastatur > Tastaturkurzbefehle > Funktionstasten).")
    }
    static func alreadyUsed(by title: String) -> String {
        tr(en: "That is already the shortcut for “\(title)”. Use another combination.",
           de: "Das ist schon der Kurzbefehl für „\(title)“. Nimm eine andere Kombination.")
    }

    // MARK: Key names

    static var space: String { tr(en: "Space", de: "Leertaste") }
    static func keypad(_ key: String) -> String { tr(en: "Keypad \(key)", de: "Ziffernblock \(key)") }
    /// The words printed under the modifier glyphs on Mac keyboards (US: control, option, command;
    /// German: ctrl, alt, cmd).
    static func capWord(_ glyph: String) -> String? {
        switch glyph {
        case "⌃": tr(en: "control", de: "ctrl")
        case "⌥": tr(en: "option", de: "alt")
        case "⇧": "shift"
        case "⌘": tr(en: "command", de: "cmd")
        default: nil
        }
    }

    // MARK: Onboarding step

    static var stepTitle: String { tr(en: "Your Shortcut", de: "Dein Tastaturkurzbefehl") }
    static func stepSubtitle(_ title: String) -> String {
        tr(en: "Start “\(title)” from any app with these keys.", de: "„\(title)“ startest du aus jeder App mit diesen Tasten.")
    }
    static func stepSubtitleNoKeys(_ title: String) -> String {
        tr(en: "Choose keys to start “\(title)” from any app.", de: "Wähle Tasten, mit denen du „\(title)“ aus jeder App startest.")
    }
    static var stepTry: String { tr(en: "Press the keys once to try it", de: "Drücke die Tasten einmal zum Ausprobieren") }
    static var stepWorks: String { tr(en: "Works", de: "Klappt") }
    static var stepNoShortcut: String { tr(en: "No shortcut set. Click “Change”.", de: "Kein Kurzbefehl gesetzt. Klicke auf „Ändern“.") }
    static var stepNoShortcutDefault: String {
        tr(en: "No shortcut set. Click “Change” or “Use Default”.", de: "Kein Kurzbefehl gesetzt. Klicke auf „Ändern“ oder „Standard verwenden“.")
    }
    static var stepRecording: String { tr(en: "Recording a new shortcut", de: "Aufnahme läuft") }
    static var stepHeld: String { tr(en: "Another app holds these keys", de: "Eine andere App hält diese Tasten fest") }
    static var stepFailed: String { tr(en: "macOS did not accept these keys", de: "macOS hat diese Tasten nicht angenommen") }
    static func stepDuplicate(_ title: String) -> String { tr(en: "Same keys as “\(title)”", de: "Dieselben Tasten wie „\(title)“") }
    static var stepFootnote: String {
        tr(en: "You can change it anytime in Settings > Keyboard Shortcuts.",
           de: "Du kannst ihn jederzeit unter Einstellungen > Tastaturkurzbefehle ändern.")
    }

    // MARK: Gallery and scenes

    static var galleryRecorder: String { tr(en: "Shortcut recorder", de: "Aufnahme für Tastaturkurzbefehle") }
    static var galleryBigKeys: String { tr(en: "Large key caps", de: "Große Tastenkappen") }
    static var galleryPane: String { tr(en: "Keyboard shortcuts pane", de: "Bereich Tastaturkurzbefehle") }
    static var galleryStep: String { tr(en: "Shortcut step", de: "Schritt Tastaturkurzbefehl") }
}

/// Texts of the sample hotkeys in renders and the gallery (never registered in the running app).
enum HotkeysSampleText {
    static var quickWindow: String { tr(en: "Open quick window", de: "Schnellfenster öffnen") }
    static var quickWindowDetail: String { tr(en: "From anywhere, also in full screen", de: "Von überall, auch im Vollbild") }
    static var captureSelection: String { tr(en: "Capture selection", de: "Auswahl übernehmen") }
    static var captureSelectionDetail: String { tr(en: "Takes the selected text of the active app", de: "Nimmt den markierten Text der aktiven App") }
    static var pause: String { tr(en: "Pause and resume", de: "Pausieren und fortsetzen") }
    static var stateIdle: String { tr(en: "Set", de: "Gesetzt") }
    static var stateRecording: String { tr(en: "Recording", de: "Aufnahme") }
    static var stateHolding: String { tr(en: "Modifiers held", de: "Sondertasten gehalten") }
    static var stateRefused: String { tr(en: "Refused", de: "Abgelehnt") }
    static var stateNote: String { tr(en: "Taken with a note", de: "Mit Hinweis übernommen") }
    static var stateHeld: String { tr(en: "Held by another app", de: "Von anderer App belegt") }
    static var stateDuplicate: String { tr(en: "Same keys as another shortcut", de: "Gleiche Tasten wie ein anderer Kurzbefehl") }
    static var stateOff: String { tr(en: "No shortcut", de: "Kein Kurzbefehl") }
}
