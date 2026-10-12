#if TESTING
#if MODUL_HOTKEYS
import AppKit

// Tests of the hotkeys module: the rule engine against fixed US and German layouts (so the
// results do not depend on the Mac running them), key names, persistence, the center's
// registration with a fake backend, and the recorder fed with synthetic key events.

/// A keyboard layout from a table: base, ⇧, ⌥ and ⌥⇧ layers; "~" prefixed entries are dead keys.
/// ⌘ types the base layer (menus match ⌘ shortcuts by it), ⌃ types nothing.
private struct TableLayout: KeyboardLayout {
    let base: [UInt16: String]
    let shift: [UInt16: String]
    let option: [UInt16: String]
    let optionShift: [UInt16: String]

    func translate(_ keyCode: UInt16, modifiers: KeyModifiers) -> (text: String, dead: Bool)? {
        if modifiers.contains(.control) { return nil }
        let entry: String?
        if modifiers.contains(.command) {
            entry = base[keyCode]
        } else if modifiers.contains(.option) {
            entry = modifiers.contains(.shift) ? optionShift[keyCode] : option[keyCode]
        } else {
            entry = modifiers.contains(.shift) ? shift[keyCode] : base[keyCode]
        }
        guard let entry, !entry.isEmpty else { return nil }
        if entry.count > 1, entry.hasPrefix("~") { return (String(entry.dropFirst()), true) }
        return (entry, false)
    }

    private static let keypad: [UInt16: String] = [82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7",
                                                    91: "8", 92: "9", 65: ".", 67: "*", 69: "+", 75: "/", 78: "-", 81: "="]

    private static func merged(_ main: [UInt16: String]) -> [UInt16: String] {
        main.merging(keypad) { a, _ in a }.merging([49: " "]) { a, _ in a }
    }

    /// Mac "U.S." (main keys; ⌥ layer as on macOS).
    static let us = TableLayout(
        base: merged([0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v", 10: "§", 11: "b", 12: "q",
                      13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
                      25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
                      38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".", 50: "`"]),
        shift: merged([0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 10: "±", 11: "B", 12: "Q",
                       13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "!", 19: "@", 20: "#", 21: "$", 22: "^", 23: "%", 24: "+",
                       25: "(", 26: "&", 27: "_", 28: "*", 29: ")", 30: "}", 31: "O", 32: "U", 33: "{", 34: "I", 35: "P", 37: "L",
                       38: "J", 39: "\"", 40: "K", 41: ":", 42: "|", 43: "<", 44: "?", 45: "N", 46: "M", 47: ">", 50: "~"]),
        option: [0: "å", 1: "ß", 2: "∂", 3: "ƒ", 4: "˙", 5: "©", 6: "Ω", 7: "≈", 8: "ç", 9: "√", 11: "∫", 12: "œ", 13: "∑",
                 14: "~´", 15: "®", 16: "¥", 17: "†", 18: "¡", 19: "™", 20: "£", 21: "¢", 22: "§", 23: "∞", 24: "≠", 25: "ª",
                 26: "¶", 27: "–", 28: "•", 29: "º", 30: "‘", 31: "ø", 32: "~¨", 33: "“", 34: "~ˆ", 35: "π", 37: "¬", 38: "∆",
                 39: "æ", 40: "˚", 41: "…", 42: "«", 43: "≤", 44: "÷", 45: "~˜", 46: "µ", 47: "≥", 50: "~`", 49: "\u{00A0}"],
        optionShift: [49: "\u{00A0}"])

    /// Mac "German" (Y and Z swapped, umlauts, dead ^ ´ `; ⌥L is @).
    static let german = TableLayout(
        base: merged([0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "y", 7: "x", 8: "c", 9: "v", 10: "~^", 11: "b", 12: "q",
                      13: "w", 14: "e", 15: "r", 16: "z", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "~´",
                      25: "9", 26: "7", 27: "ß", 28: "8", 29: "0", 30: "+", 31: "o", 32: "u", 33: "ü", 34: "i", 35: "p", 37: "l",
                      38: "j", 39: "ä", 40: "k", 41: "ö", 42: "#", 43: ",", 44: "-", 45: "n", 46: "m", 47: ".", 50: "<"]),
        shift: merged([0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Y", 7: "X", 8: "C", 9: "V", 10: "°", 11: "B", 12: "Q",
                       13: "W", 14: "E", 15: "R", 16: "Z", 17: "T", 18: "!", 19: "\"", 20: "§", 21: "$", 22: "&", 23: "%", 24: "~`",
                       25: ")", 26: "/", 27: "?", 28: "(", 29: "=", 30: "*", 31: "O", 32: "U", 33: "Ü", 34: "I", 35: "P", 37: "L",
                       38: "J", 39: "Ä", 40: "K", 41: "Ö", 42: "'", 43: ";", 44: "_", 45: "N", 46: "M", 47: ":", 50: ">"]),
        option: [0: "å", 1: "‚", 2: "∂", 3: "ƒ", 4: "ª", 5: "©", 6: "¥", 7: "≈", 8: "ç", 9: "√", 11: "∫", 12: "«", 13: "∑",
                 14: "€", 15: "®", 16: "Ω", 17: "†", 18: "¡", 19: "“", 20: "¶", 21: "¢", 22: "]", 23: "[", 25: "}", 26: "|",
                 27: "¿", 28: "{", 29: "≠", 30: "±", 31: "ø", 32: "~¨", 35: "π", 37: "@", 40: "º", 42: "‘", 43: "∞", 44: "–",
                 45: "~~", 46: "µ", 47: "…", 50: "≤", 49: "\u{00A0}"],
        optionShift: [26: "\\", 49: "\u{00A0}"])
}

private enum HK {
    static let c: KeyModifiers = .command, s: KeyModifiers = .shift, o: KeyModifiers = .option, k: KeyModifiers = .control

    /// macOS's list as the tests assume it: screenshots on, Spotlight on, Spaces arrows on,
    /// Show Desktop (F11) on, the Zoom keys off.
    static let system: [SystemShortcut] = [
        .init(keyCode: 21, modifiers: [.shift, .command], enabled: true), .init(keyCode: 20, modifiers: [.shift, .command], enabled: true),
        .init(keyCode: 49, modifiers: .command, enabled: true), .init(keyCode: 123, modifiers: .control, enabled: true),
        .init(keyCode: 28, modifiers: [.option, .command], enabled: false), .init(keyCode: 103, modifiers: [], enabled: true),
    ]

    static func ctx(_ layout: KeyboardLayout = TableLayout.us, others: [ShortcutRules.Other] = [], voiceOver: Bool = false) -> ShortcutRules.Context {
        ShortcutRules.Context(layout: layout, system: system, others: others, voiceOver: voiceOver, appName: "Starter")
    }

    static func judge(_ code: UInt16, _ mods: KeyModifiers, _ layout: KeyboardLayout = TableLayout.us,
                      others: [ShortcutRules.Other] = [], voiceOver: Bool = false) -> ShortcutRules.Verdict {
        ShortcutRules.judge(KeyCombo(keyCode: code, modifiers: mods), in: ctx(layout, others: others, voiceOver: voiceOver))
    }

    static func refused(_ v: ShortcutRules.Verdict, _ containing: String? = nil) -> Bool {
        guard case .refuse(let why) = v else { return false }
        return containing.map { why.contains($0) } ?? true
    }

    static func taken(_ v: ShortcutRules.Verdict, note containing: String? = nil) -> Bool {
        guard case .take(_, let note) = v else { return false }
        guard let containing else { return note == nil }
        return note?.contains(containing) == true
    }

    static let quick = KeyCombo(keyCode: 40, modifiers: [.option, .shift, .command])      // ⌥⇧⌘K
    static let capture = KeyCombo(keyCode: 8, modifiers: [.control, .option, .command])   // ⌃⌥⌘C

    /// A center with two hotkeys, a fake backend and an in-memory store.
    static func center(_ choices: [String: HotkeyChoice] = [:], start: Bool = false) -> (HotkeyCenter, FakeHotkeyBackend) {
        let backend = FakeHotkeyBackend()
        let center = HotkeyCenter(backend: backend, store: MemoryHotkeyStore(choices))
        center.layout = TableLayout.us
        center.register(id: "quick", title: { "Quick" }, default: quick, order: 0, showInOnboarding: true) {}
        center.register(id: "capture", title: { "Capture" }, default: capture, order: 1) {}
        if start { center.startForTesting() }
        return (center, backend)
    }

    static func recorder(_ center: HotkeyCenter) -> ShortcutRecorder {
        let r = ShortcutRecorder(center: center)
        r.listensToEvents = false
        r.systemShortcuts = { system }
        r.voiceOver = { false }
        return r
    }
}

final class HotkeysRulesTests: TestSuite {
    override class func register() {
        let c = HK.c, s = HK.s, o = HK.o, k = HK.k

        test("menu shortcuts of nearly every app are refused with what they do") {
            expect(HK.refused(HK.judge(12, c), "quits the app"), "⌘Q")
            expect(HK.refused(HK.judge(13, c), "closes the window"), "⌘W")
            expect(HK.refused(HK.judge(38, c), "jumps to the selection"), "⌘J (⌘ + key table)")
            expect(HK.refused(HK.judge(40, c), "inserts a link"), "⌘K")
            expect(HK.refused(HK.judge(17, c), "Starter"), "the app's name is in the reason")
        }

        test("⌘ with any other single key is refused") {
            expect(HK.refused(HK.judge(4, c), "hides the app"), "⌘H")
            expect(HK.refused(HK.judge(46, c)), "⌘M")
            expect(HK.refused(HK.judge(41, c), "menu commands"), "⌘; (not named)")
        }

        test("menus match ⌘ shortcuts by character, so the layout decides") {
            expect(HK.refused(HK.judge(6, c, TableLayout.us), "undoes"), "US: code 6 is Z")
            expect(HK.refused(HK.judge(16, c, TableLayout.german), "undoes"), "German: Z sits on code 16")
            expect(HK.refused(HK.judge(6, c, TableLayout.german), "shows the history"), "German: code 6 is Y")
            expect(HK.refused(HK.judge(44, [s, c], TableLayout.us), "opens Help"), "US ⇧⌘/ is ⇧⌘?")
            expect(HK.refused(HK.judge(27, [s, c], TableLayout.german), "opens Help"), "German ⇧⌘ß is ⇧⌘?")
        }

        test("keys that type are refused without a modifier") {
            expect(HK.refused(HK.judge(13, []), "types “w”"), "W alone")
            expect(HK.refused(HK.judge(13, s), "types “W”"), "⇧W")
            expect(HK.refused(HK.judge(41, [], TableLayout.german), "types “ö”"), "Ö alone on German")
            expect(HK.refused(HK.judge(49, []), "space bar"), "Space alone")
        }

        test("text system keys are refused") {
            expect(HK.refused(HK.judge(0, k), "every text field"), "⌃A")
            expect(HK.refused(HK.judge(0, [k, s]), "every text field"), "⌃⇧A")
            expect(HK.refused(HK.judge(123, o), "every text field"), "⌥←")
            expect(HK.refused(HK.judge(123, c), "every text field"), "⌘←")
            expect(HK.refused(HK.judge(51, c), "every text field"), "⌘⌫")
        }

        test("editing keys: navigation sets refused, others taken with a note") {
            expect(HK.refused(HK.judge(126, s), "writing and moving"), "⇧↑")
            expect(HK.taken(HK.judge(123, [k, o, s]), note: "window tools"), "⌃⌥⇧←")
            expect(HK.taken(HK.judge(36, k), note: "chat apps"), "⌃↩ (system, off here)")
            expect(ShortcutRules.suggestion(for: 123, in: HK.ctx()) == nil, "no variant for arrows")
        }

        test("the Terminal: ⌃C refused, ⌃W taken with a note") {
            expect(HK.refused(HK.judge(8, k), "Terminal"), "⌃C")
            expect(HK.taken(HK.judge(13, k), note: "deletes the word before the cursor"), "⌃W")
            expect(HK.taken(HK.judge(15, k), note: "searches the history"), "⌃R")
        }

        test("macOS's own shortcuts: switched on refused, switched off noted, always-macOS refused") {
            expect(HK.refused(HK.judge(21, [s, c]), "saves a picture of the selected area"), "⇧⌘4 on")
            expect(HK.refused(HK.judge(49, c), "Spotlight"), "⌘Space on")
            expect(HK.refused(HK.judge(123, k), "moves left a space"), "⌃← on")
            expect(HK.refused(HK.judge(103, []), "shows the desktop"), "F11 on")
            expect(HK.taken(HK.judge(28, [o, c]), note: "It is off on your Mac"), "⌥⌘8 off")
            expect(HK.refused(HK.judge(12, [k, c]), "always belongs to macOS"), "⌃⌘Q")
            expect(HK.refused(HK.judge(53, [o, c]), "Force Quit"), "⌥⌘Esc")
            expect(HK.refused(HK.judge(48, c), "switches apps"), "⌘⇥")
        }

        test("F-keys: F13 alone taken, F5 with the fn note, media keys refused") {
            expect(HK.taken(HK.judge(105, [])), "F13 without a note")
            expect(HK.taken(HK.judge(96, []), note: "fn"), "F5")
            expect(HK.taken(HK.judge(96, [o, s]), note: "fn"), "⌥⇧F5")
            expect(HK.taken(HK.judge(96, c), note: "fn"), "⌘F5 (VoiceOver, not in this Mac's list)")
            expect(HK.refused(HK.judge(72, []), "volume"), "volume up")
            expect(HK.refused(HK.judge(53, []), "Esc"), "Esc alone")
        }

        test("⌥ characters: needed ones refused, rare ones noted (German)") {
            expect(HK.refused(HK.judge(37, o, TableLayout.german), "“@”"), "⌥L is @")
            expect(HK.refused(HK.judge(23, o, TableLayout.german), "“[”"), "⌥5 is [")
            expect(HK.refused(HK.judge(14, o, TableLayout.german), "“€”"), "⌥E is €")
            expect(HK.refused(HK.judge(26, [o, s], TableLayout.german), "“\\”"), "⌥⇧7 is backslash")
            expect(HK.refused(HK.judge(45, o, TableLayout.german), "accent “~”"), "⌥N is the only ~ accent")
            expect(HK.taken(HK.judge(6, o, TableLayout.german), note: "“¥”"), "⌥Y is ¥")
            expect(HK.refused(HK.judge(42, o, TableLayout.german), "“‘”"), "⌥# is a typographic quote")
        }

        test("⌥ characters (US)") {
            expect(HK.taken(HK.judge(37, o, TableLayout.us), note: "“¬”"), "⌥L is ¬")
            expect(HK.taken(HK.judge(16, o, TableLayout.us), note: "password fields"), "⌥Y is ¥")
            expect(HK.refused(HK.judge(14, o, TableLayout.us), "accent “´”"), "⌥E sets the acute")
            expect(HK.refused(HK.judge(50, o, TableLayout.us), "accent “`”"), "⌥` is the only dead grave")
            expect(HK.taken(HK.judge(49, o), note: "no-break space"), "⌥Space")
        }

        test("common apps and unnamed ⇧⌘ / ⌥⌘ letters are noted") {
            expect(HK.taken(HK.judge(0, [s, c]), note: "Applications"), "⇧⌘A")
            expect(HK.taken(HK.judge(2, [o, c]), note: "own menu commands"), "⌥⌘D")
            expect(HK.taken(HK.judge(40, [s, c]), note: "own menu commands"), "⇧⌘K")
            expect(HK.taken(HK.judge(40, [k, o, s, c])), "⌃⌥⇧⌘K without a note")
            expect(HK.taken(HK.judge(40, [o, s, c])), "⌥⇧⌘K without a note")
        }

        test("VoiceOver's ⌃⌥ is noted only while VoiceOver is on") {
            expect(HK.taken(HK.judge(40, [k, o], voiceOver: true), note: "VoiceOver"), "on")
            expect(HK.taken(HK.judge(40, [k, o], voiceOver: false)), "off")
        }

        test("the app's own other hotkeys are refused, by title") {
            let others = [ShortcutRules.Other(id: "quick", title: "Quick window", combo: HK.quick)]
            expect(HK.refused(HK.judge(40, [o, s, c], others: others), "“Quick window”"))
            expect(HK.taken(HK.judge(40, [k, o, s, c], others: others)), "another combination is fine")
        }

        test("a refusal offers a free variant on the same key") {
            expectEqual(ShortcutRules.suggestion(for: 13, in: HK.ctx()), KeyCombo(keyCode: 13, modifiers: [k, o, c]))
            let others = [ShortcutRules.Other(id: "x", title: "X", combo: KeyCombo(keyCode: 13, modifiers: [k, o, c]))]
            expectEqual(ShortcutRules.suggestion(for: 13, in: HK.ctx(others: others)), KeyCombo(keyCode: 13, modifiers: [k, s, c]))
            expect(ShortcutRules.suggestion(for: 72, in: HK.ctx()) == nil, "no variant for media keys")
        }

        test("every named meaning with text has both languages") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            for meaning in ShortcutRules.meanings {
                guard let text = meaning.text else { continue }
                Localizer.shared.forced = .en
                let en = text()
                Localizer.shared.forced = .de
                let de = text()
                expect(!en.isEmpty && !de.isEmpty && en != de, "meaning \(meaning.key) \(meaning.modifiers.glyphs.joined())")
            }
            expect(ShortcutRules.meanings.count >= 170, "the whole VoiceBud table is there")
        }

        test("the same reason every time (no dictionary order)") {
            let others = [ShortcutRules.Other(id: "a", title: "A", combo: HK.quick), ShortcutRules.Other(id: "b", title: "B", combo: HK.quick)]
            var reasons = Set<String>()
            for _ in 0..<6 {
                if case .refuse(let why) = HK.judge(40, [o, s, c], others: others) { reasons.insert(why) }
            }
            expectEqual(reasons.count, 1)
            expect(reasons.first?.contains("“A”") == true, "the first in display order")
        }
    }
}

final class HotkeysFormatTests: TestSuite {
    override class func register() {
        test("caps and labels in macOS order ⌃⌥⇧⌘") {
            let combo = KeyCombo(keyCode: 40, modifiers: [.command, .shift, .option, .control])
            expectEqual(TableLayout.us.caps(combo), ["⌃", "⌥", "⇧", "⌘", "K"])
            expectEqual(TableLayout.us.label(combo), "⌃⌥⇧⌘K")
            expectEqual(TableLayout.us.label(KeyCombo(keyCode: 96, modifiers: [.shift, .command])), "⇧⌘F5")
            expectEqual(TableLayout.us.label(KeyCombo(keyCode: 123, modifiers: .option)), "⌥←")
        }

        test("key names follow the layout") {
            expectEqual(TableLayout.us.keyName(6), "Z")
            expectEqual(TableLayout.german.keyName(6), "Y")
            expectEqual(TableLayout.german.keyName(27), "ß", "ß stays ß, not SS")
            expectEqual(TableLayout.german.keyName(41), "Ö")
            expectEqual(TableLayout.us.keyName(105), "F13")
            expectEqual(TableLayout.us.keyName(53), "Esc")
            expect(TableLayout.us.keyName(200) == nil, "unknown key")
        }

        test("space and keypad names are translated") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            Localizer.shared.forced = .en
            expectEqual(TableLayout.us.keyName(49), "Space")
            expectEqual(TableLayout.us.keyName(83), "Keypad 1")
            Localizer.shared.forced = .de
            expectEqual(TableLayout.us.keyName(49), "Leertaste")
            expectEqual(TableLayout.us.keyName(83), "Ziffernblock 1")
        }

        test("menu tokens come from the ⌘ layer, none for named keys") {
            expectEqual(TableLayout.german.menuToken(16), "z")
            expect(TableLayout.us.menuToken(123) == nil, "arrow")
            expect(TableLayout.us.menuToken(49) == nil, "space")
        }

        test("modifier sets from names and flags") {
            expectEqual(KeyModifiers(names: ["cmd", "Shift", "alt", "ctrl"]), KeyModifiers.all)
            expect(KeyModifiers(names: ["hyper"]) == nil, "unknown name")
            expectEqual(KeyModifiers(rawValue: 0xFFFF_FFFF), KeyModifiers.all, "other bits dropped")
            expectEqual(KeyModifiers(NSEvent.ModifierFlags([.command, .option, .function])), [.command, .option])
            expectEqual(KeyModifiers([.control, .shift]).names, ["control", "shift"])
        }

        test("system layout answers for ordinary keys") {
            // whatever this Mac's layout is, the space bar types a space and Esc types nothing
            expectEqual(SystemKeyboardLayout.current.typed(49), " ")
            expect(SystemKeyboardLayout.current.keyName(0) != nil, "A key has a name")
        }
    }
}

final class HotkeysStoreTests: TestSuite {
    override class func register() {
        test("choices encode readably and round-trip") {
            let combo = KeyCombo(keyCode: 40, modifiers: [.control, .option, .command])
            let data = try JSONEncoder().encode(HotkeyChoice.combo(combo))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            expectEqual(json?["keyCode"] as? Int, 40)
            expectEqual(json?["modifiers"] as? [String], ["control", "option", "command"])
            expectEqual(try JSONDecoder().decode(HotkeyChoice.self, from: data), .combo(combo))
            let off = try JSONEncoder().encode(HotkeyChoice.off)
            expectEqual(String(decoding: off, as: UTF8.self), "\"off\"")
            expectEqual(try JSONDecoder().decode(HotkeyChoice.self, from: off), .off)
        }

        test("broken values are refused by the decoder") {
            for bad in [#"{"keyCode": 300, "modifiers": []}"#, #"{"keyCode": 4, "modifiers": ["hyper"]}"#, #""sometimes""#, #"42"#] {
                expect((try? JSONDecoder().decode(HotkeyChoice.self, from: Data(bad.utf8))) == nil, bad)
            }
        }

        test("the settings store writes one key per hotkey and removes it for the standard") {
            let url = tempDir().appendingPathComponent("settings.json")
            let settings = Settings(fileURL: url)
            let store = SettingsHotkeyStore(settings: settings)
            store.save("quick", .combo(HK.capture))
            store.save("capture", .off)
            let again = SettingsHotkeyStore(settings: Settings(fileURL: url))
            expectEqual(again.load("quick"), .combo(HK.capture))
            expectEqual(again.load("capture"), .off)
            expectEqual(again.load("never"), .standard)
            store.save("quick", .standard)
            let object = SettingsTests.json(url)
            expect(object["hotkeys.quick"] == nil, "standard removes the key")
            expectEqual(object["hotkeys.capture"] as? String, "off")
        }

        test("a broken hand edit costs only that hotkey") {
            let url = tempDir().appendingPathComponent("settings.json")
            try Data(#"{"hotkeys.a": {"keyCode": 999}, "hotkeys.b": {"keyCode": 40, "modifiers": ["command", "option"]}}"#.utf8).write(to: url)
            let store = SettingsHotkeyStore(settings: Settings(fileURL: url))
            expectEqual(store.load("a"), .standard)
            expectEqual(store.load("b"), .combo(KeyCombo(keyCode: 40, modifiers: [.command, .option])))
        }

        test("a center loads choices from its store") {
            let (center, _) = HK.center(["capture": .off])
            expectEqual(center.choice("capture"), .off)
            expect(center.combo("capture") == nil, "off has no combination")
            expectEqual(center.combo("quick"), HK.quick)
            expectEqual(center.display("quick"), "⌥⇧⌘K")
        }
    }
}

final class HotkeysCenterTests: TestSuite {
    override class func register() {
        test("nothing reaches the backend before start") {
            let (center, backend) = HK.center()
            expect(backend.registered.isEmpty)
            expectEqual(center.status["quick"], .inactive)
            center.startForTesting()
            expect(backend.installed)
            expectEqual(Set(backend.registered.values), [HK.quick, HK.capture])
            expectEqual(center.status["quick"], .active)
        }

        test("a new choice re-registers at once") {
            let (center, backend) = HK.center(start: true)
            let other = KeyCombo(keyCode: 40, modifiers: [.control, .option, .shift, .command])
            center.set("quick", .combo(other))
            expectEqual(Set(backend.registered.values), [other, HK.capture])
            center.set("quick", .off)
            expectEqual(Set(backend.registered.values), [HK.capture])
            expectEqual(center.status["quick"], .off)
        }

        test("a combination equal to the standard is stored as the standard") {
            let store = MemoryHotkeyStore()
            let center = HotkeyCenter(backend: FakeHotkeyBackend(), store: store)
            center.register(id: "quick", title: { "Quick" }, default: HK.quick) {}
            center.set("quick", .combo(HK.quick))
            expectEqual(center.choice("quick"), .standard)
            expect(store.values.isEmpty)
        }

        test("the same keys twice: only the first hotkey gets them") {
            let (center, backend) = HK.center(["capture": .combo(HK.quick)], start: true)
            expectEqual(Array(backend.registered.values), [HK.quick])
            expectEqual(center.status["quick"], .active)
            expectEqual(center.status["capture"], .inactive)
        }

        test("held by another app and refused by macOS are reported") {
            let backend = FakeHotkeyBackend()
            backend.taken = [HK.quick]
            backend.refused = [HK.capture: -9868]
            let center = HotkeyCenter(backend: backend, store: MemoryHotkeyStore())
            center.register(id: "quick", title: { "Quick" }, default: HK.quick) {}
            center.register(id: "capture", title: { "Capture" }, default: HK.capture) {}
            center.startForTesting()
            expectEqual(center.status["quick"], .heldElsewhere)
            expectEqual(center.status["capture"], .failed(-9868))
            expectEqual(center.probe(HK.capture), -9868)
        }

        test("presses and releases reach the hotkey") {
            let backend = FakeHotkeyBackend()
            let center = HotkeyCenter(backend: backend, store: MemoryHotkeyStore())
            var log: [String] = []
            center.register(id: "hold", title: { "Hold" }, default: HK.quick, onRelease: { log.append("up") }) { log.append("down") }
            center.startForTesting()
            backend.press(HK.quick)
            expect(center.pressed.contains("hold"))
            backend.press(HK.quick, down: false)
            backend.press(HK.quick, down: false)                  // a release without its press: ignored
            expectEqual(log, ["down", "up"])
            expectEqual(center.pressCount["hold"], 1)
        }

        test("pausing unregisters everything; a hotkey taken away while held gets its release") {
            let backend = FakeHotkeyBackend()
            let center = HotkeyCenter(backend: backend, store: MemoryHotkeyStore())
            var released = 0
            center.register(id: "hold", title: { "Hold" }, default: HK.quick, onRelease: { released += 1 }) {}
            center.startForTesting()
            backend.press(HK.quick)
            center.pause(true)
            expect(backend.registered.isEmpty)
            expectEqual(released, 1)
            expectEqual(center.status["hold"], .inactive)
            center.pause(false)
            expectEqual(Array(backend.registered.values), [HK.quick])
        }

        test("stop and unregister remove registrations") {
            let (center, backend) = HK.center(start: true)
            center.unregister(id: "capture")
            expectEqual(Array(backend.registered.values), [HK.quick])
            expect(center.status["capture"] == nil)
            center.stop()
            expect(backend.registered.isEmpty)
        }

        test("display order and the onboarding hotkey") {
            let (center, _) = HK.center()
            expectEqual(center.definitions.map(\.id), ["quick", "capture"])
            expectEqual(center.onboardingHotkey?.id, "quick")
            expectEqual(center.others(than: "quick").map(\.id), ["capture"])
        }

        test("plan is pure: off and missing standards are skipped") {
            let defs = [
                HotkeyDefinition(id: "a", order: 0, title: { "A" }, subtitle: nil, standard: nil, showInOnboarding: false, onPress: {}, onRelease: nil),
                HotkeyDefinition(id: "b", order: 1, title: { "B" }, subtitle: nil, standard: HK.quick, showInOnboarding: false, onPress: {}, onRelease: nil),
                HotkeyDefinition(id: "c", order: 2, title: { "C" }, subtitle: nil, standard: HK.capture, showInOnboarding: false, onPress: {}, onRelease: nil),
            ]
            expectEqual(HotkeyCenter.plan(defs, choices: ["c": .off]), ["b": HK.quick])
        }
    }
}

final class HotkeysRecorderTests: TestSuite {
    override class func register() {
        let all: KeyModifiers = [.control, .option, .shift, .command]

        test("a free combination is taken on the key and recording ends") {
            let (center, _) = HK.center()
            let r = HK.recorder(center)
            r.start("quick")
            expect(center.isPaused, "hotkeys pause while recording")
            r.handle(.modifiers([.control, .option]))
            expectEqual(r.live, ["⌃", "⌥"])
            r.handle(.keyDown(40, all))
            expectEqual(center.combo("quick"), KeyCombo(keyCode: 40, modifiers: all))
            expect(r.target == nil && !center.isPaused)
            expect(r.problem == nil && r.note == nil)
        }

        test("a refusal keeps recording, offers a variant, and the variant can be taken") {
            let (center, _) = HK.center()
            let r = HK.recorder(center)
            r.start("quick")
            r.handle(.keyDown(13, .command))
            expectEqual(r.target, "quick")
            expect(r.problem?.text.contains("closes the window") == true)
            expectEqual(r.problem?.keys, ["⌘", "W"])
            let free = r.problem?.suggestion
            expectEqual(free, KeyCombo(keyCode: 13, modifiers: [.control, .option, .command]))
            if let free { r.use(free) }
            expectEqual(center.combo("quick"), free)
            expect(r.target == nil && r.problem == nil)
        }

        test("taken with a note: the note shows and Undo brings the old choice back") {
            let (center, _) = HK.center()
            let r = HK.recorder(center)
            r.start("quick")
            r.handle(.keyDown(13, .control))
            expectEqual(center.combo("quick"), KeyCombo(keyCode: 13, modifiers: .control))
            expect(r.note?.text.contains("Terminal") == true)
            expect(r.canUndo("quick"))
            r.undoLast()
            expectEqual(center.choice("quick"), .standard)
            expect(r.note == nil && !r.canUndo("quick"))
        }

        test("modifiers alone, two keys, fn, and a release without its press are refused") {
            let (center, _) = HK.center()
            let r = HK.recorder(center)
            r.start("quick")
            r.handle(.modifiers(.command))
            r.handle(.modifiers([]))
            expect(r.problem?.text.contains("Modifier keys alone") == true, "modifiers alone")
            r.handle(.keyDown(13, []))
            r.handle(.keyDown(1, []))
            expect(r.problem?.text.contains("two regular keys") == true, "two keys")
            r.handle(.keyUp(13, []))
            r.handle(.keyUp(1, []))
            r.handle(.fn(down: true))
            r.handle(.fn(down: false))
            expect(r.problem?.text.contains("fn key alone") == true, "fn alone")
            r.handle(.fn(down: true))
            r.handle(.keyDown(3, []))
            expect(r.problem?.text.contains("Leave fn out") == true, "fn with a letter")
            r.handle(.fn(down: false))
            r.handle(.keyUp(3, []))
            r.handle(.keyUp(49, .command))
            expect(r.problem?.text.contains("caught") == true, "release without press")
            expectEqual(r.target, "quick", "still recording")
            expectEqual(center.choice("quick"), .standard, "nothing stored")
        }

        test("Esc cancels, key repeats are ignored") {
            let (center, _) = HK.center()
            let r = HK.recorder(center)
            r.start("quick")
            r.handle(.keyDown(40, all, isRepeat: true))
            expectEqual(center.choice("quick"), .standard)
            r.handle(.keyDown(53, []))
            expect(r.target == nil && !center.isPaused)
            expectEqual(center.choice("quick"), .standard)
        }

        test("⌫ removes the shortcut, Undo and Default bring it back") {
            let (center, _) = HK.center()
            let r = HK.recorder(center)
            r.start("quick")
            r.handle(.keyDown(51, []))
            expectEqual(center.choice("quick"), .off)
            expect(r.canUndo("quick"))
            r.undoLast()
            expectEqual(center.choice("quick"), .standard)
            r.start("quick")
            r.handle(.keyDown(51, []))
            r.restore("quick", to: .standard)
            expectEqual(center.combo("quick"), HK.quick)
        }

        test("another hotkey's keys are refused; Default is checked the same way") {
            let (center, _) = HK.center()
            let r = HK.recorder(center)
            r.start("quick")
            r.handle(.keyDown(8, [.control, .option, .command]))
            expect(r.problem?.text.contains("“Capture”") == true)
            r.cancel()
            // capture moves to ⌃⌥⇧⌘C, quick takes capture's standard; then capture's Default clashes
            center.set("capture", .combo(KeyCombo(keyCode: 8, modifiers: all)))
            center.set("quick", .combo(HK.capture))
            r.restore("capture", to: .standard)
            expect(r.problem?.text.contains("“Quick”") == true)
            expectEqual(center.combo("capture"), KeyCombo(keyCode: 8, modifiers: all), "unchanged")
        }

        test("keys another app holds are rolled back with an explanation") {
            let (center, backend) = HK.center(start: true)
            let held = KeyCombo(keyCode: 40, modifiers: all)
            backend.taken = [held]
            let r = HK.recorder(center)
            r.start("quick")
            r.handle(.keyDown(40, all))
            expectEqual(center.choice("quick"), .standard, "rolled back")
            expect(r.problem?.text.contains("Another app already holds") == true)
            expectEqual(center.status["quick"], .active)
        }

        test("NSEvent conversion") {
            let flags = NSEventShim.flags([.control, .option])
            expectEqual(ShortcutRecorder.Event(flags), .modifiers([.control, .option]))
            expectEqual(ShortcutRecorder.Event(NSEventShim.key(40, [.command])), .keyDown(40, .command))
            expectEqual(ShortcutRecorder.Event(NSEventShim.key(40, [], up: true)), .keyUp(40, []))
            expectEqual(ShortcutRecorder.Event(NSEventShim.fn(true)), .fn(down: true))
        }
    }
}

/// Synthetic AppKit key events (no window, nothing reaches the system).
private enum NSEventShim {
    static func flags(_ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                         characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 59)!
    }

    static func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags, up: Bool = false) -> NSEvent {
        NSEvent.keyEvent(with: up ? .keyUp : .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                         context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!
    }

    static func fn(_ down: Bool) -> NSEvent {
        NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: down ? .function : [], timestamp: 0, windowNumber: 0,
                         context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 63)!
    }
}

final class HotkeysSceneTests: TestSuite {
    /// Spins the main run loop until a main-actor task runs at once three times in a row (or 5 s).
    private static func settleMainActor() {
        final class Flag { var done = false }
        let end = Date().addingTimeInterval(5)
        var quiet = 0
        while quiet < 3, Date() < end {
            let flag = Flag()
            let start = Date()
            Task { @MainActor in flag.done = true }
            while !flag.done, Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            quiet = Date().timeIntervalSince(start) < 0.03 ? quiet + 1 : 0
        }
    }

    override class func register() {
        test("scenes, gallery, pane and onboarding step are registered") {
            Registry.withScratch {
                HotkeysModule.register()
                let scenes = Set(Registry.renderScenes.map(\.id))
                for id in ["hotkeys.pane", "hotkeys.pane-empty", "hotkeys.recorder-states", "hotkeys.big-keys", "hotkeys.onboarding",
                           "hotkeys.onboarding-pressed", "hotkeys.onboarding-refused"] {
                    expect(scenes.contains(id), id)
                }
                expectEqual(Registry.settingsPanes.map(\.id), ["hotkeys"])
                expectEqual(Registry.onboardingSteps.first?.order, 600)
                expect(Registry.problems().isEmpty, Registry.problems().joined(separator: "; "))
                // the app registers no hotkey itself, so the step stays out
                expect(Registry.orderedOnboardingSteps.isEmpty, "step only with a showInOnboarding hotkey")
            }
        }

        test("every hotkeys scene renders in both appearances") {
            Registry.withScratch {
                HotkeysCatalog.register()
                RenderMode.isStatic = true
                defer { RenderMode.isStatic = false }
                for scene in Registry.renderScenes {
                    for appearance in [Appearance.light, .dark] {
                        // in a pool of its own: the hosting view is gone right after, not at the end of the run
                        let png = autoreleasepool {
                            RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: .de, scale: 1)
                        }
                        expect(png != nil && (png?.count ?? 0) > 1000, "\(scene.id) \(appearance)")
                    }
                }
            }
            // SwiftUI queues seconds of main-actor work after many offscreen renders; let it finish,
            // so later suites that wait briefly for main-actor tasks (ObservingTests) are not delayed
            settleMainActor()
        }
    }
}
#endif
#endif
