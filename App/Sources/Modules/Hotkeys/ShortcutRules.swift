import AppKit

// What a new shortcut may be (ported from VoiceBud ui/ShortcutRules.swift, where the design goal
// was: not too strict, and every refusal says why). Allowed: a key with modifiers, or an F-key
// alone; the app registers it with macOS. Refused, with what the keys do instead: what macOS uses
// (the switched-on system shortcuts come from macOS itself), what nearly every app or the text
// system needs, what types a character that is needed, the app's own other hotkeys. Accepted with
// a note: what is switched off in macOS, what the Terminal or common apps use, rarely needed ⌥
// characters. A refusal comes with a free variant on the same key when there is one.
//
// Pure: everything it looks at comes in through `Context` (layout, macOS's list, the other
// hotkeys), so tests run it against fixed US and German layouts.

enum ShortcutRules {
    enum Verdict: Equatable {
        case take(KeyCombo, note: String?)
        case refuse(String)

        var isRefusal: Bool { if case .refuse = self { true } else { false } }
        var note: String? { if case .take(_, let note) = self { note } else { nil } }
    }

    /// Another hotkey of this app, with the title shown in its row.
    struct Other {
        let id: String
        let title: String
        let combo: KeyCombo
    }

    struct Context {
        var layout: KeyboardLayout
        /// macOS's own shortcuts, read when the recording started (`SystemShortcuts.read()`).
        var system: [SystemShortcut]
        /// The app's other hotkeys, in their display order (the reason shown must not depend on a
        /// dictionary's order).
        var others: [Other]
        var voiceOver = false
        var appName = AppInfo.displayName
    }

    // MARK: - Verdict

    /// A key with modifiers (or an F-key alone).
    static func judge(_ combo: KeyCombo, in ctx: Context) -> Verdict {
        let code = combo.keyCode
        let mods = combo.modifiers
        let layout = ctx.layout
        let keys = layout.label(combo)
        var note: String?

        if code == KeyCodes.escape && mods.isEmpty { return .refuse(HotkeysText.escCancels) }
        // volume and mute
        if KeyCodes.mediaKeys.contains(code) { return .refuse(HotkeysText.mediaKeys) }
        // the app's own other hotkeys
        if let why = clash(combo, others: ctx.others) { return .refuse(why) }
        // what always belongs to macOS (app switcher, Force Quit, lock screen, log out)
        if let n = meanings.first(where: { $0.kind == .always && $0.code == code && $0.modifiers == mods && $0.text != nil }) {
            return .refuse(HotkeysText.alwaysMacOS(keys, n.text!()))
        }
        // switched on in macOS: refused; a known one that is switched off here: a note
        let entries = ctx.system.filter { $0.keyCode == code && $0.modifiers == mods }
        let named = meanings.first { $0.kind == .system && $0.code == code && $0.modifiers == mods && $0.text != nil }
        if entries.contains(where: \.enabled) {
            if let named { return .refuse(HotkeysText.systemNamed(keys, named.text!())) }
            return .refuse(HotkeysText.systemUnnamed(keys))
        }
        if let named, !entries.isEmpty {
            note = HotkeysText.systemOffNote(keys, named.text!())
        }
        // ⌘ with one key: the apps' menus (with an arrow, ⌫ or ↩ the text rules below say more)
        if mods == .command && !KeyCodes.editingKeys.contains(code) {
            if let n = hit(code, mods, [.allApps], layout), let text = n.text {
                return .refuse(HotkeysText.everyApp(keys, text(), app: ctx.appName))
            }
            if let token = layout.menuToken(code), let what = ShortcutCatalogText.commandOnly[token] {
                return .refuse(HotkeysText.everyApp(keys, what(), app: ctx.appName))
            }
            if !KeyCodes.functionKeys.contains(code) { return .refuse(HotkeysText.commandAlone) }
        }
        // menu shortcuts nearly every app has, the text system's keys
        if let n = hit(code, mods, [.allApps, .text], layout), n.kind == .refuse, let text = n.text {
            if n.scope == .text { return .refuse(HotkeysText.everyTextField(keys, text())) }
            return .refuse(HotkeysText.everyAppOther(keys, text(), app: ctx.appName))
        }
        // editing and navigation keys: alone, with ⇧, or with ⌥ or ⌘ (and ⇧) they move and select
        // in text; other sets only some apps use
        if KeyCodes.editingKeys.contains(code) {
            let navigation = !mods.contains(.control) && [mods.contains(.option), mods.contains(.command)].filter { $0 }.count <= 1
            if navigation { return .refuse(HotkeysText.editingKey(keys)) }
            note = note ?? HotkeysText.editingKeyNote(keys)
        }
        // no modifier or ⇧ only on a key that types
        let strong: KeyModifiers = [.command, .control, .option]
        if mods.isDisjoint(with: strong), let ch = layout.typed(code, mods) {
            if code == KeyCodes.space { return .refuse(HotkeysText.spaceAlone) }
            return .refuse(HotkeysText.typesCharacter(keys, ch))
        }
        if mods.isDisjoint(with: strong) && !KeyCodes.functionKeys.contains(code) && !KeyCodes.editingKeys.contains(code) {
            return .refuse(HotkeysText.needsModifier(keys))
        }
        // ⌥ or ⌥⇧ without ⌃ and ⌘ on a key that types: needed characters refused, rare ones noted
        if mods.isDisjoint(with: [.command, .control]), mods.contains(.option), let info = layout.translate(code, modifiers: mods) {
            if info.dead && !deadElsewhere(info.text, besides: code, layout) {
                return .refuse(HotkeysText.deadKey(keys, info.text))
            }
            if !info.dead && needed(info.text, layout) {
                return .refuse(HotkeysText.neededCharacter(keys, info.text))
            }
            if let n = hit(code, mods, [.text], layout), n.kind == .warn, let text = n.text {
                note = HotkeysText.textWarnNote(keys, text())
            } else if info.text.trimmingCharacters(in: .whitespaces).isEmpty {
                note = HotkeysText.typesSpaceNote(keys)
            } else {
                note = HotkeysText.rareCharacterNote(keys, info.text)
            }
        }
        // the Terminal's control keys
        if let n = hit(code, mods, [.terminal], layout), let text = n.text {
            if n.kind == .terminalRefuse { return .refuse(HotkeysText.terminalRefuse(keys, text())) }
            note = note ?? HotkeysText.terminalNote(keys, text())
        }
        // common apps and services
        if let n = hit(code, mods, [.commonApps], layout), let text = n.text {
            note = note ?? HotkeysText.commonAppsNote(keys, text())
        }
        // ⇧⌘ or ⌥⌘ with a letter nobody names
        if note == nil, mods == [.shift, .command] || mods == [.option, .command], let token = layout.menuToken(code), token.count == 1,
           token.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
            note = HotkeysText.appMenusNote(keys, app: ctx.appName)
        }
        // VoiceOver's keys
        if note == nil, mods.isSuperset(of: [.control, .option]), ctx.voiceOver {
            note = HotkeysText.voiceOverNote(keys)
        }
        // F1–F12 on Apple keyboards
        if note == nil, KeyCodes.topRow.contains(code) {
            note = HotkeysText.fnNote(keys)
        }
        return .take(combo, note: note)
    }

    /// A free variant on the same key: ⌃⌥⌘, ⌃⇧⌘, ⌥⇧⌘, ⌃⌥⇧⌘, the first one with nothing to say.
    static func suggestion(for keyCode: UInt16, in ctx: Context) -> KeyCombo? {
        if KeyCodes.editingKeys.contains(keyCode) || KeyCodes.mediaKeys.contains(keyCode) { return nil }
        let candidates: [KeyModifiers] = [[.control, .option, .command], [.control, .shift, .command],
                                          [.option, .shift, .command], [.control, .option, .shift, .command]]
        for mods in candidates {
            let combo = KeyCombo(keyCode: keyCode, modifiers: mods)
            if case .take(_, nil) = judge(combo, in: ctx) { return combo }
        }
        return nil
    }

    /// Another of the app's hotkeys on the same keys, with why (nil: none).
    static func clash(_ combo: KeyCombo, others: [Other]) -> String? {
        others.first { $0.combo == combo }.map { HotkeysText.alreadyUsed(by: $0.title) }
    }

    // MARK: - Helpers

    static var meanings: [ShortcutMeaning] { ShortcutCatalogText.meanings }

    private static func hit(_ code: UInt16, _ mods: KeyModifiers, _ scopes: Set<ShortcutMeaning.Scope>,
                            _ layout: KeyboardLayout) -> ShortcutMeaning? {
        let token = layout.menuToken(code)
        let base = mods.subtracting(.shift)
        // a plain loop: the closure form of this search crashes the optimizer (Swift 6.3,
        // CopyPropagation "Found ownership error") in release builds
        for n in meanings where scopes.contains(n.scope) {
            let keyMatch: Bool
            switch n.key {
            case .code(let c): keyMatch = c == code
            case .token(let t): keyMatch = token == t
            }
            guard keyMatch else { continue }
            // the Terminal's ⌃ keys are the same with ⇧ (⌃⇧W still deletes a word there)
            if n.modifiers == mods || (n.kind == .terminal && n.modifiers == .control && base == .control) { return n }
        }
        return nil
    }

    /// A character that is needed and cannot be typed another way (an ASCII sign, €, typographic marks).
    static func needed(_ ch: String, _ layout: KeyboardLayout) -> Bool {
        for other in UInt16(0)...KeyCombo.maxKeyCode where !KeyCodes.editingKeys.contains(other) {
            if layout.typed(other) == ch || layout.typed(other, .shift) == ch { return false }
        }
        let marks = "€„“”‚‘’–—…»«›‹"
        return ch.unicodeScalars.allSatisfy {
            ($0.isASCII && !CharacterSet.alphanumerics.contains($0)) || marks.unicodeScalars.contains($0)
        }
    }

    /// The same accent from another key without ⌥ (then this one is not the only way to type it).
    static func deadElsewhere(_ accent: String, besides code: UInt16, _ layout: KeyboardLayout) -> Bool {
        for other in UInt16(0)...KeyCombo.maxKeyCode where !KeyCodes.editingKeys.contains(other) {
            for m: KeyModifiers in [[], .shift] where !(other == code && m.isEmpty) {
                if let info = layout.translate(other, modifiers: m), info.dead, info.text == accent { return true }
            }
        }
        return false
    }
}
