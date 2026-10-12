// What key combinations already do in macOS, in nearly every app, in text fields, in the Terminal
// and in common apps: the named table the shortcut rules explain refusals and notes with. Ported
// from VoiceBud (ui/ShortcutRules.swift, research of 10.10., 178 entries). System entries are
// matched by key code (positions), the others by the character the ⌘ layer types (menus match a
// shortcut by character, so ⌘Z is undo on every layout).

/// One known combination and what it does (`text` nil: macOS has it, without a description).
struct ShortcutMeaning {
    enum Key: Equatable { case code(UInt16), token(String) }

    /// `always`: always macOS (refused). `system`: macOS, refused while switched on, a note while off.
    /// `refuse`: nearly every app or the text system needs it. `terminalRefuse`: the Terminal needs
    /// it (⌃C). `terminal` / `warn`: some apps use it (accepted with a note).
    enum Kind { case always, system, refuse, terminalRefuse, terminal, warn }
    enum Scope { case system, allApps, text, terminal, commonApps }

    let key: Key
    let modifiers: KeyModifiers
    let kind: Kind
    let scope: Scope
    let text: (() -> String)?

    var code: UInt16? { if case .code(let c) = key { c } else { nil } }
    var token: String? { if case .token(let t) = key { t } else { nil } }
}

enum ShortcutCatalogText {
    private static func e(_ key: ShortcutMeaning.Key, _ modifiers: KeyModifiers, _ kind: ShortcutMeaning.Kind,
                          _ scope: ShortcutMeaning.Scope, _ text: (() -> String)?) -> ShortcutMeaning {
        ShortcutMeaning(key: key, modifiers: modifiers, kind: kind, scope: scope, text: text)
    }

    static let meanings: [ShortcutMeaning] = [
        e(.code(49), [.command], .system, .system) { tr(en: "opens Spotlight search", de: "öffnet die Spotlight-Suche") },  // ⌘Space
        e(.code(49), [.option, .command], .system, .system) { tr(en: "opens the Finder search window", de: "öffnet das Finder-Suchfenster") },  // ⌥⌘Space
        e(.code(49), [.control, .command], .system, .system) { tr(en: "opens Emoji & Symbols", de: "öffnet Emoji & Symbole") },  // ⌃⌘Space
        e(.code(49), [.control], .system, .system) { tr(en: "selects the previous input source", de: "wählt die vorherige Eingabequelle") },  // ⌃Space
        e(.code(49), [.control, .option], .system, .system) { tr(en: "selects the next input source", de: "wählt die nächste Eingabequelle") },  // ⌃⌥Space
        e(.code(48), [.command], .always, .system) { tr(en: "switches apps", de: "wechselt zwischen Apps") },  // ⌘⇥
        e(.code(48), [.shift, .command], .always, .system) { tr(en: "switches apps backwards", de: "wechselt rückwärts zwischen Apps") },  // ⇧⌘⇥
        e(.code(50), [.command], .system, .system) { tr(en: "moves focus to the app's next window", de: "wechselt zum nächsten Fenster der App") },  // ⌘< (US ⌘`)
        e(.code(50), [.shift, .command], .system, .system) { tr(en: "moves focus to the app's previous window", de: "wechselt zum vorigen Fenster der App") },  // ⇧⌘< (US ⇧⌘`)
        e(.code(50), [.option, .command], .system, .system) { tr(en: "moves focus to the window drawer", de: "setzt den Fokus auf die Schublade des Fensters") },  // ⌥⌘< (US ⌥⌘`)
        e(.code(20), [.shift, .command], .system, .system) { tr(en: "saves a picture of the screen as a file", de: "sichert ein Bildschirmfoto als Datei") },  // ⇧⌘3
        e(.code(20), [.control, .shift, .command], .system, .system) { tr(en: "copies a picture of the screen to the clipboard", de: "kopiert ein Bildschirmfoto in die Zwischenablage") },  // ⌃⇧⌘3
        e(.code(21), [.shift, .command], .system, .system) { tr(en: "saves a picture of the selected area", de: "sichert ein Bild des ausgewählten Bereichs") },  // ⇧⌘4
        e(.code(21), [.control, .shift, .command], .system, .system) { tr(en: "copies a picture of the selected area", de: "kopiert ein Bild des ausgewählten Bereichs") },  // ⌃⇧⌘4
        e(.code(23), [.shift, .command], .system, .system) { tr(en: "opens screenshot and recording options", de: "öffnet die Optionen für Bildschirmfotos und Bildschirmaufnahmen") },  // ⇧⌘5
        e(.code(22), [.shift, .command], .system, .system) { tr(en: "saves a picture of the Touch Bar", de: "sichert ein Bild der Touch Bar") },  // ⇧⌘6
        e(.code(22), [.control, .shift, .command], .system, .system) { tr(en: "copies a picture of the Touch Bar", de: "kopiert ein Bild der Touch Bar") },  // ⌃⇧⌘6
        e(.code(53), [.option, .command], .always, .system) { tr(en: "opens Force Quit", de: "öffnet „Sofort beenden“") },  // ⌥⌘Esc
        e(.code(53), [.option, .shift, .command], .always, .system) { tr(en: "force quits the frontmost app", de: "beendet die vorderste App sofort") },  // ⌥⇧⌘Esc
        e(.code(53), [.command], .system, .system) { tr(en: "opens the Game Overlay (macOS 26)", de: "öffnet die Spielüberlagerung (macOS 26)") },  // ⌘Esc
        e(.code(53), [.option], .system, .system) { tr(en: "speaks the selection", de: "liest die Auswahl vor") },  // ⌥Esc
        e(.code(126), [.control], .system, .system) { tr(en: "opens Mission Control", de: "öffnet Mission Control") },  // ⌃↑
        e(.code(125), [.control], .system, .system) { tr(en: "shows the app's windows", de: "zeigt alle Fenster der App") },  // ⌃↓
        e(.code(123), [.control], .system, .system) { tr(en: "moves left a space", de: "wechselt einen Space nach links") },  // ⌃←
        e(.code(124), [.control], .system, .system) { tr(en: "moves right a space", de: "wechselt einen Space nach rechts") },  // ⌃→
        e(.code(18), [.control], .system, .system) { tr(en: "switches to Desktop 1", de: "wechselt zu Schreibtisch 1") },  // ⌃1
        e(.code(19), [.control], .system, .system) { tr(en: "switches to Desktop 2", de: "wechselt zu Schreibtisch 2") },  // ⌃1
        e(.code(20), [.control], .system, .system) { tr(en: "switches to Desktop 3", de: "wechselt zu Schreibtisch 3") },  // ⌃1
        e(.code(21), [.control], .system, .system) { tr(en: "switches to Desktop 4", de: "wechselt zu Schreibtisch 4") },  // ⌃1
        e(.code(23), [.control], .system, .system) { tr(en: "switches to Desktop 5", de: "wechselt zu Schreibtisch 5") },  // ⌃1
        e(.code(22), [.control], .system, .system) { tr(en: "switches to Desktop 6", de: "wechselt zu Schreibtisch 6") },  // ⌃1
        e(.code(26), [.control], .system, .system) { tr(en: "switches to Desktop 7", de: "wechselt zu Schreibtisch 7") },  // ⌃1
        e(.code(28), [.control], .system, .system) { tr(en: "switches to Desktop 8", de: "wechselt zu Schreibtisch 8") },  // ⌃1
        e(.code(25), [.control], .system, .system) { tr(en: "switches to Desktop 9", de: "wechselt zu Schreibtisch 9") },  // ⌃1
        e(.code(29), [.control], .system, .system) { tr(en: "switches to Desktop 10", de: "wechselt zu Schreibtisch 10") },  // ⌃1
        e(.code(103), [], .system, .system) { tr(en: "shows the desktop", de: "zeigt den Schreibtisch") },  // F11
        e(.code(107), [], .system, .system) { tr(en: "decreases display brightness", de: "verringert die Bildschirmhelligkeit") },  // F14
        e(.code(113), [], .system, .system) { tr(en: "increases display brightness", de: "erhöht die Bildschirmhelligkeit") },  // F15
        e(.code(122), [.control], .system, .system) { tr(en: "turns keyboard access on or off", de: "schaltet die Tastatursteuerung ein oder aus") },  // ⌃F1
        e(.code(120), [.control], .system, .system) { tr(en: "moves focus to the menu bar", de: "setzt den Fokus auf die Menüleiste") },  // ⌃F2
        e(.code(99), [.control], .system, .system) { tr(en: "moves focus to the Dock", de: "setzt den Fokus auf das Dock") },  // ⌃F3
        e(.code(118), [.control], .system, .system) { tr(en: "moves focus to the active or next window", de: "setzt den Fokus auf das aktive oder nächste Fenster") },  // ⌃F4
        e(.code(96), [.control], .system, .system) { tr(en: "moves focus to the window toolbar", de: "setzt den Fokus auf die Symbolleiste des Fensters") },  // ⌃F5
        e(.code(97), [.control], .system, .system) { tr(en: "moves focus to the floating window", de: "setzt den Fokus auf das schwebende Fenster") },  // ⌃F6
        e(.code(98), [.control], .system, .system) { tr(en: "changes the way Tab moves focus", de: "ändert, wie der Tabulator den Fokus bewegt") },  // ⌃F7
        e(.code(100), [.control], .system, .system) { tr(en: "moves focus to the status menus", de: "setzt den Fokus auf die Statusmenüs") },  // ⌃F8
        e(.code(118), [.control, .shift], .system, .system) { tr(en: "probably moves focus to the previous window", de: "setzt vermutlich den Fokus auf das vorige Fenster") },  // ⌃⇧F4
        e(.code(96), [.command], .system, .system) { tr(en: "turns VoiceOver on or off", de: "schaltet VoiceOver ein oder aus") },  // ⌘F5
        e(.code(96), [.option, .command], .system, .system) { tr(en: "shows the Accessibility controls", de: "öffnet die Steuerung für Bedienungshilfen") },  // ⌥⌘F5
        e(.code(122), [.command], .system, .system) { tr(en: "probably mirrors the displays", de: "spiegelt vermutlich die Bildschirme") },  // ⌘F1
        e(.code(101), [.control], .system, .system, nil),  // ⌃F9
        e(.code(2), [.option, .command], .system, .system) { tr(en: "turns Dock hiding on or off", de: "blendet das Dock ein oder aus") },  // ⌥⌘D
        e(.code(2), [.control, .command], .system, .system) { tr(en: "looks up the word in the Dictionary", de: "schlägt das Wort im Lexikon nach") },  // ⌃⌘D
        e(.code(36), [.control], .system, .system) { tr(en: "shows the contextual menu", de: "öffnet das Kontextmenü") },  // ⌃↩
        e(.code(46), [.command], .system, .system) { tr(en: "minimizes the window", de: "legt das Fenster im Dock ab") },  // ⌘M
        e(.code(46), [.option, .command], .system, .system) { tr(en: "minimizes all of the app's windows", de: "legt alle Fenster der App im Dock ab") },  // ⌥⌘M
        e(.code(12), [.control, .command], .always, .system) { tr(en: "locks the screen", de: "sperrt den Bildschirm") },  // ⌃⌘Q
        e(.code(12), [.shift, .command], .always, .system) { tr(en: "logs you out", de: "meldet dich ab") },  // ⇧⌘Q
        e(.code(12), [.option, .shift, .command], .always, .system) { tr(en: "logs you out without asking", de: "meldet dich ohne Rückfrage ab") },  // ⌥⇧⌘Q
        e(.code(47), [.control, .option, .shift, .command], .always, .system) { tr(en: "starts a system diagnosis (sysdiagnose)", de: "startet eine Systemdiagnose (sysdiagnose)") },  // ⌃⌥⇧⌘.
        e(.code(12), [.control, .option, .shift, .command], .system, .system, nil),  // ⌃⌥⇧⌘Q
        e(.code(1), [.control, .command], .system, .system, nil),  // ⌃⌘S
        e(.code(3), [.shift, .command], .system, .system) { tr(en: "probably searches with Spotlight", de: "sucht vermutlich mit Spotlight") },  // ⇧⌘F
        e(.code(28), [.option, .command], .system, .system) { tr(en: "turns Zoom on or off", de: "schaltet den Zoom ein oder aus") },  // ⌥⌘8
        e(.code(24), [.option, .command], .system, .system) { tr(en: "zooms in", de: "vergrößert mit dem Zoom") },  // ⌥⌘= (DE ⌥⌘´)
        e(.code(27), [.option, .command], .system, .system) { tr(en: "zooms out", de: "verkleinert mit dem Zoom") },  // ⌥⌘- (DE ⌥⌘ß)
        e(.code(28), [.control, .option, .command], .system, .system) { tr(en: "inverts colors", de: "kehrt die Farben um") },  // ⌃⌥⌘8
        e(.code(47), [.control, .option, .command], .system, .system) { tr(en: "increases contrast", de: "erhöht den Kontrast") },  // ⌃⌥⌘.
        e(.code(43), [.control, .option, .command], .system, .system) { tr(en: "decreases contrast", de: "verringert den Kontrast") },  // ⌃⌥⌘,
        e(.code(49), [.control, .shift], .system, .system) { tr(en: "shows or hides Trackpad Handwriting", de: "blendet die Trackpad-Handschrift ein oder aus") },  // ⌃⇧Space
        e(.code(49), [.shift, .command], .system, .system) { tr(en: "asks Siri about the active window from macOS 27 on", de: "fragt ab macOS 27 Siri zum aktiven Fenster") },  // ⇧⌘Space
        e(.token("q"), [.command], .refuse, .allApps) { tr(en: "quits the app", de: "beendet die App") },  // ⌘Q
        e(.token("w"), [.command], .refuse, .allApps) { tr(en: "closes the window", de: "schließt das Fenster") },  // ⌘W
        e(.token("h"), [.command], .refuse, .allApps) { tr(en: "hides the app", de: "blendet die App aus") },  // ⌘H
        e(.token(","), [.command], .refuse, .allApps) { tr(en: "opens the settings", de: "öffnet die Einstellungen") },  // ⌘,
        e(.token("n"), [.command], .refuse, .allApps) { tr(en: "opens a new document or window", de: "öffnet ein neues Dokument oder Fenster") },  // ⌘N
        e(.token("o"), [.command], .refuse, .allApps) { tr(en: "opens a file", de: "öffnet eine Datei") },  // ⌘O
        e(.token("s"), [.command], .refuse, .allApps) { tr(en: "saves", de: "sichert") },  // ⌘S
        e(.token("p"), [.command], .refuse, .allApps) { tr(en: "prints", de: "druckt") },  // ⌘P
        e(.token("z"), [.command], .refuse, .allApps) { tr(en: "undoes", de: "widerruft") },  // ⌘Z
        e(.token("z"), [.shift, .command], .refuse, .allApps) { tr(en: "redoes", de: "wiederholt den letzten Schritt") },  // ⇧⌘Z
        e(.token("x"), [.command], .refuse, .allApps) { tr(en: "cuts", de: "schneidet aus") },  // ⌘X
        e(.token("c"), [.command], .refuse, .allApps) { tr(en: "copies", de: "kopiert") },  // ⌘C
        e(.token("v"), [.command], .refuse, .allApps) { tr(en: "pastes", de: "setzt ein") },  // ⌘V
        e(.token("a"), [.command], .refuse, .allApps) { tr(en: "selects all", de: "wählt alles aus") },  // ⌘A
        e(.token("f"), [.command], .refuse, .allApps) { tr(en: "finds", de: "sucht") },  // ⌘F
        e(.token("g"), [.command], .refuse, .allApps) { tr(en: "finds next", de: "sucht weiter") },  // ⌘G
        e(.token("g"), [.shift, .command], .refuse, .allApps) { tr(en: "finds previous (Finder: Go to Folder)", de: "sucht rückwärts (im Finder: Gehe zu Ordner)") },  // ⇧⌘G
        e(.token("t"), [.command], .refuse, .allApps) { tr(en: "opens a new tab", de: "öffnet einen neuen Tab") },  // ⌘T
        e(.token("."), [.command], .refuse, .allApps) { tr(en: "cancels", de: "bricht ab") },  // ⌘.
        e(.token("1"), [.command], .refuse, .allApps) { tr(en: "selects tab 1 or view 1", de: "wählt Tab 1 oder Darstellung 1") },  // ⌘1
        e(.token("2"), [.command], .refuse, .allApps) { tr(en: "selects tab 2 or view 2", de: "wählt Tab 2 oder Darstellung 2") },  // ⌘1
        e(.token("3"), [.command], .refuse, .allApps) { tr(en: "selects tab 3 or view 3", de: "wählt Tab 3 oder Darstellung 3") },  // ⌘1
        e(.token("4"), [.command], .refuse, .allApps) { tr(en: "selects tab 4 or view 4", de: "wählt Tab 4 oder Darstellung 4") },  // ⌘1
        e(.token("5"), [.command], .refuse, .allApps) { tr(en: "selects tab 5 or view 5", de: "wählt Tab 5 oder Darstellung 5") },  // ⌘1
        e(.token("6"), [.command], .refuse, .allApps) { tr(en: "selects tab 6 or view 6", de: "wählt Tab 6 oder Darstellung 6") },  // ⌘1
        e(.token("7"), [.command], .refuse, .allApps) { tr(en: "selects tab 7 or view 7", de: "wählt Tab 7 oder Darstellung 7") },  // ⌘1
        e(.token("8"), [.command], .refuse, .allApps) { tr(en: "selects tab 8 or view 8", de: "wählt Tab 8 oder Darstellung 8") },  // ⌘1
        e(.token("9"), [.command], .refuse, .allApps) { tr(en: "selects tab 9 or view 9", de: "wählt Tab 9 oder Darstellung 9") },  // ⌘1
        e(.token("h"), [.option, .command], .refuse, .allApps) { tr(en: "hides the other apps", de: "blendet die anderen Apps aus") },  // ⌥⌘H
        e(.token("w"), [.option, .command], .refuse, .allApps) { tr(en: "closes all of the app's windows", de: "schließt alle Fenster der App") },  // ⌥⌘W
        e(.token("s"), [.shift, .command], .refuse, .allApps) { tr(en: "saves as or duplicates", de: "sichert unter neuem Namen oder dupliziert") },  // ⇧⌘S
        e(.token("v"), [.option, .shift, .command], .refuse, .allApps) { tr(en: "pastes and matches style", de: "setzt ein und passt den Stil an") },  // ⌥⇧⌘V
        e(.token("f"), [.control, .command], .refuse, .allApps) { tr(en: "enters full screen", de: "schaltet auf Vollbild") },  // ⌃⌘F
        e(.token("/"), [.shift, .command], .refuse, .allApps) { tr(en: "opens Help", de: "öffnet die Hilfe") },  // ⇧⌘? on US
        e(.token("ß"), [.shift, .command], .refuse, .allApps) { tr(en: "opens Help", de: "öffnet die Hilfe") },  // ⇧⌘? on German
        e(.code(48), [.control], .refuse, .allApps) { tr(en: "moves to the next tab", de: "wechselt zum nächsten Tab") },  // ⌃⇥
        e(.code(48), [.control, .shift], .refuse, .allApps) { tr(en: "moves to the previous tab", de: "wechselt zum vorigen Tab") },  // ⌃⇧⇥
        e(.token("a"), [.control], .refuse, .text) { tr(en: "moves to the start of the line", de: "springt an den Zeilenanfang") },  // ⌃A
        e(.token("e"), [.control], .refuse, .text) { tr(en: "moves to the end of the line", de: "springt ans Zeilenende") },  // ⌃E
        e(.token("b"), [.control], .refuse, .text) { tr(en: "moves one character back", de: "geht ein Zeichen zurück") },  // ⌃B
        e(.token("f"), [.control], .refuse, .text) { tr(en: "moves one character forward", de: "geht ein Zeichen vor") },  // ⌃F
        e(.token("n"), [.control], .refuse, .text) { tr(en: "moves one line down", de: "geht eine Zeile runter") },  // ⌃N
        e(.token("p"), [.control], .refuse, .text) { tr(en: "moves one line up", de: "geht eine Zeile hoch") },  // ⌃P
        e(.token("d"), [.control], .refuse, .text) { tr(en: "deletes the character to the right", de: "löscht das Zeichen rechts") },  // ⌃D
        e(.token("h"), [.control], .refuse, .text) { tr(en: "deletes the character to the left", de: "löscht das Zeichen links") },  // ⌃H
        e(.token("k"), [.control], .refuse, .text) { tr(en: "deletes to the end of the line", de: "löscht bis zum Zeilenende") },  // ⌃K
        e(.token("y"), [.control], .refuse, .text) { tr(en: "pastes what ⌃K deleted last", de: "setzt das zuletzt mit ⌃K Gelöschte ein") },  // ⌃Y
        e(.token("t"), [.control], .refuse, .text) { tr(en: "transposes two characters", de: "vertauscht zwei Zeichen") },  // ⌃T
        e(.token("v"), [.control], .refuse, .text) { tr(en: "scrolls one page down", de: "blättert eine Seite weiter") },  // ⌃V
        e(.token("o"), [.control], .refuse, .text) { tr(en: "inserts a line after the cursor", de: "fügt hinter dem Cursor eine Zeile ein") },  // ⌃O
        e(.token("l"), [.control], .refuse, .text) { tr(en: "centers the view on the cursor", de: "zentriert die Ansicht auf den Cursor") },  // ⌃L
        e(.token("a"), [.control, .shift], .refuse, .text) { tr(en: "selects to the start of the line", de: "markiert bis zum Zeilenanfang") },  // ⌃⇧A
        e(.token("e"), [.control, .shift], .refuse, .text) { tr(en: "selects to the end of the line", de: "markiert bis zum Zeilenende") },  // ⌃⇧E
        e(.token("b"), [.control, .shift], .refuse, .text) { tr(en: "extends the selection one character back", de: "markiert ein Zeichen nach links") },  // ⌃⇧B
        e(.token("f"), [.control, .shift], .refuse, .text) { tr(en: "extends the selection one character forward", de: "markiert ein Zeichen nach rechts") },  // ⌃⇧F
        e(.token("n"), [.control, .shift], .refuse, .text) { tr(en: "extends the selection one line down", de: "markiert eine Zeile nach unten") },  // ⌃⇧N
        e(.token("p"), [.control, .shift], .refuse, .text) { tr(en: "extends the selection one line up", de: "markiert eine Zeile nach oben") },  // ⌃⇧P
        e(.token("v"), [.control, .shift], .refuse, .text) { tr(en: "extends the selection one page down", de: "markiert eine Seite nach unten") },  // ⌃⇧V
        e(.token("b"), [.control, .option], .refuse, .text) { tr(en: "moves one word back", de: "springt ein Wort zurück") },  // ⌃⌥B
        e(.token("f"), [.control, .option], .refuse, .text) { tr(en: "moves one word forward", de: "springt ein Wort vor") },  // ⌃⌥F
        e(.code(123), [.option], .refuse, .text) { tr(en: "moves one word back", de: "springt ein Wort zurück") },  // ⌥←
        e(.code(124), [.option], .refuse, .text) { tr(en: "moves one word forward", de: "springt ein Wort vor") },  // ⌥→
        e(.code(51), [.option], .refuse, .text) { tr(en: "deletes the word to the left", de: "löscht das Wort links") },  // ⌥⌫
        e(.code(123), [.command], .refuse, .text) { tr(en: "moves to the start of the line", de: "springt an den Zeilenanfang") },  // ⌘←
        e(.code(51), [.command], .refuse, .text) { tr(en: "deletes to the start of the line (Finder: moves to Trash)", de: "löscht bis zum Zeilenanfang (im Finder: legt in den Papierkorb)") },  // ⌘⌫
        e(.code(36), [.option], .refuse, .text) { tr(en: "inserts a line break in the field", de: "fügt im Feld einen Zeilenumbruch ein") },  // ⌥↩
        e(.code(49), [.option], .warn, .text) { tr(en: "types a no-break space", de: "tippt ein geschütztes Leerzeichen") },  // ⌥Space
        e(.code(49), [.option, .shift], .warn, .text) { tr(en: "types a no-break space", de: "tippt ein geschütztes Leerzeichen") },  // ⌥⇧Space
        e(.token("c"), [.control], .terminalRefuse, .terminal) { tr(en: "interrupts the running command", de: "bricht den laufenden Befehl ab") },  // ⌃C
        e(.token("z"), [.control], .terminal, .terminal) { tr(en: "suspends the running command", de: "hält den laufenden Befehl an") },  // ⌃Z
        e(.token("w"), [.control], .terminal, .terminal) { tr(en: "deletes the word before the cursor", de: "löscht das Wort vor dem Cursor") },  // ⌃W
        e(.token("u"), [.control], .terminal, .terminal) { tr(en: "deletes the line", de: "löscht die Zeile") },  // ⌃U
        e(.token("r"), [.control], .terminal, .terminal) { tr(en: "searches the history backwards", de: "sucht rückwärts im Verlauf") },  // ⌃R
        e(.token("s"), [.control], .terminal, .terminal) { tr(en: "stops output or searches the history forward", de: "hält die Ausgabe an oder sucht vorwärts im Verlauf") },  // ⌃S
        e(.token("q"), [.control], .terminal, .terminal) { tr(en: "resumes output (zsh: pushes the line aside)", de: "setzt die Ausgabe fort (zsh: stellt die Zeile zurück)") },  // ⌃Q
        e(.token("x"), [.control], .terminal, .terminal) { tr(en: "starts shell key sequences (nano: exits)", de: "beginnt Tastenfolgen der Shell (nano: beendet)") },  // ⌃X
        e(.token("g"), [.control], .terminal, .terminal) { tr(en: "aborts the input", de: "bricht die Eingabe ab") },  // ⌃G
        e(.token("\\"), [.control], .terminal, .terminal) { tr(en: "quits the command hard (SIGQUIT)", de: "beendet den Befehl hart (SIGQUIT)") },  // ⌃\
        e(.token("a"), [.shift, .command], .warn, .commonApps) { tr(en: "opens Applications in the Finder", de: "öffnet im Finder die Programme") },  // ⇧⌘A
        e(.token("d"), [.shift, .command], .warn, .commonApps) { tr(en: "opens the Desktop in the Finder", de: "öffnet im Finder den Schreibtisch") },  // ⇧⌘D
        e(.token("h"), [.shift, .command], .warn, .commonApps) { tr(en: "opens the home folder in the Finder", de: "öffnet im Finder den Benutzerordner") },  // ⇧⌘H
        e(.token("o"), [.shift, .command], .warn, .commonApps) { tr(en: "opens Documents in the Finder", de: "öffnet im Finder die Dokumente") },  // ⇧⌘O
        e(.token("r"), [.shift, .command], .warn, .commonApps) { tr(en: "opens AirDrop in the Finder and Reader in Safari", de: "öffnet im Finder AirDrop und in Safari den Reader") },  // ⇧⌘R
        e(.token("."), [.shift, .command], .warn, .commonApps) { tr(en: "shows hidden files in the Finder", de: "zeigt im Finder versteckte Dateien") },  // ⇧⌘.
        e(.token("l"), [.option, .command], .warn, .commonApps) { tr(en: "opens Downloads in the Finder and Safari", de: "öffnet im Finder und in Safari die Downloads") },  // ⌥⌘L
        e(.token("l"), [.shift, .command], .warn, .commonApps) { tr(en: "runs Safari's 'Search With Google' service", de: "sucht mit dem Safari-Dienst „Mit Google suchen“") },  // ⇧⌘L
        e(.token("y"), [.shift, .command], .warn, .commonApps) { tr(en: "makes a sticky note with the service", de: "erstellt mit dem Dienst einen Notizzettel") },  // ⇧⌘Y
        e(.token("m"), [.shift, .command], .warn, .commonApps) { tr(en: "opens the man page with the Terminal service", de: "öffnet mit dem Terminal-Dienst die man-Seite") },  // ⇧⌘M
        e(.token("b"), [.shift, .command], .warn, .commonApps) { tr(en: "shows or hides the browser's bookmarks bar", de: "blendet im Browser die Lesezeichenleiste ein oder aus") },  // ⇧⌘B
        e(.token("n"), [.shift, .command], .warn, .commonApps) { tr(en: "makes a new folder in the Finder and opens a private browser window", de: "erstellt im Finder einen neuen Ordner und öffnet im Browser ein privates Fenster") },  // ⇧⌘N
        e(.token("t"), [.shift, .command], .warn, .commonApps) { tr(en: "reopens the last closed browser tab", de: "öffnet im Browser den zuletzt geschlossenen Tab wieder") },  // ⇧⌘T
        e(.token("w"), [.shift, .command], .warn, .commonApps) { tr(en: "closes the whole window in browsers and many apps", de: "schließt in Browsern und vielen Apps das ganze Fenster") },  // ⇧⌘W
        e(.token("v"), [.shift, .command], .warn, .commonApps) { tr(en: "pastes without formatting in many apps", de: "setzt in vielen Apps ohne Formatierung ein") },  // ⇧⌘V
        e(.token("p"), [.shift, .command], .warn, .commonApps) { tr(en: "opens Page Setup", de: "öffnet „Papierformat“") },  // ⇧⌘P
        e(.token("i"), [.option, .command], .warn, .commonApps) { tr(en: "opens the browser's developer tools", de: "öffnet im Browser die Entwicklerwerkzeuge") },  // ⌥⌘I
        e(.token("j"), [.option, .command], .warn, .commonApps) { tr(en: "opens the browser's console", de: "öffnet im Browser die Konsole") },  // ⌥⌘J
        e(.token("c"), [.option, .command], .warn, .commonApps) { tr(en: "copies the style in text apps", de: "kopiert in Textprogrammen den Stil") },  // ⌥⌘C
        e(.token("v"), [.option, .command], .warn, .commonApps) { tr(en: "pastes the style in text apps and moves copied files in the Finder", de: "setzt in Textprogrammen den Stil ein und bewegt im Finder kopierte Dateien") },  // ⌥⌘V
        e(.token("s"), [.option, .command], .warn, .commonApps) { tr(en: "shows or hides the Finder sidebar", de: "blendet im Finder die Seitenleiste ein oder aus") },  // ⌥⌘S
        e(.token("t"), [.option, .command], .warn, .commonApps) { tr(en: "shows or hides the toolbar", de: "blendet die Symbolleiste ein oder aus") },  // ⌥⌘T
        e(.token("p"), [.option, .command], .warn, .commonApps) { tr(en: "shows or hides the Finder path bar", de: "blendet im Finder die Pfadleiste ein oder aus") },  // ⌥⌘P
        e(.token("a"), [.control, .command], .warn, .commonApps) { tr(en: "makes an alias in the Finder", de: "erzeugt im Finder ein Alias") },  // ⌃⌘A
        e(.token("t"), [.control, .command], .warn, .commonApps) { tr(en: "adds the item to the Finder sidebar", de: "fügt im Finder das Objekt zur Seitenleiste hinzu") },  // ⌃⌘T
        e(.code(51), [.shift, .command], .warn, .commonApps) { tr(en: "empties the Trash in the Finder", de: "leert im Finder den Papierkorb") },  // ⇧⌘⌫
        e(.token("]"), [.shift, .command], .warn, .commonApps) { tr(en: "moves to the next tab in browsers and many apps", de: "wechselt in Browsern und vielen Apps zum nächsten Tab") },
        e(.token("["), [.shift, .command], .warn, .commonApps) { tr(en: "moves to the previous tab in browsers and many apps", de: "wechselt in Browsern und vielen Apps zum vorigen Tab") },
        e(.token("\\"), [.shift, .command], .warn, .commonApps) { tr(en: "shows all tabs in Safari", de: "zeigt in Safari alle Tabs") },
    ]

    /// ⌘ with a single key: what it does in nearly every app (for keys the table does not name).
    static let commandOnly: [String: () -> String] = [
        "b": { tr(en: "makes text bold", de: "macht Text fett") },
        "i": { tr(en: "makes text italic", de: "macht Text kursiv") },
        "u": { tr(en: "underlines text", de: "unterstreicht Text") },
        "k": { tr(en: "inserts a link", de: "fügt einen Link ein") },
        "l": { tr(en: "jumps to the address bar", de: "springt in die Adressleiste") },
        "r": { tr(en: "reloads", de: "lädt neu") },
        "e": { tr(en: "uses the selection for find", de: "übernimmt die Auswahl für die Suche") },
        "d": { tr(en: "duplicates or bookmarks", de: "dupliziert oder setzt ein Lesezeichen") },
        "j": { tr(en: "jumps to the selection", de: "springt zur Auswahl") },
        "y": { tr(en: "shows the history", de: "zeigt den Verlauf") },
        "0": { tr(en: "resets the zoom", de: "setzt die Größe zurück") },
        "+": { tr(en: "zooms in", de: "vergrößert") },
        "=": { tr(en: "zooms in", de: "vergrößert") },
        "-": { tr(en: "zooms out", de: "verkleinert") },
        "ß": { tr(en: "zooms out", de: "verkleinert") },
    ]
}
