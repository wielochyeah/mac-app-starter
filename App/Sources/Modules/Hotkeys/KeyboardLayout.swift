import AppKit
import Carbon.HIToolbox

// What a key types and how it reads on its cap, through the keyboard layout in use (VoiceBud
// ShortcutRules.typedInfo / keyName / menuToken, generalised). The rule engine and the key caps
// take a `KeyboardLayout`, so tests inject fixed US and German tables.

/// One keyboard layout: what a key types with modifiers.
protocol KeyboardLayout {
    /// The text the key types with these modifiers, and whether it is a dead key (an accent that
    /// waits for the next letter; then `text` is the accent itself). nil: it types nothing.
    func translate(_ keyCode: UInt16, modifiers: KeyModifiers) -> (text: String, dead: Bool)?
}

/// Keys whose meaning does not depend on the layout (positions are fixed on every Mac keyboard).
enum KeyCodes {
    static let `return`: UInt16 = 36, tab: UInt16 = 48, space: UInt16 = 49, delete: UInt16 = 51
    static let escape: UInt16 = 53, fn: UInt16 = 63

    /// Keys that type nothing: their cap name, by key code. "Space" is translated (`HotkeysText`).
    static let specialNames: [UInt16: String] = [
        36: "↩", 48: "⇥", 51: "⌫", 53: "Esc", 76: "⌤", 114: "Help", 115: "↖", 116: "⇞", 117: "⌦",
        119: "↘", 121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
        109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16",
        64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]
    /// The number pad types the same as the main row: its keys get their own name.
    static let keypad: [UInt16: String] = [
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
        65: ",", 67: "*", 69: "+", 75: "/", 78: "-", 81: "=", 71: "⌧",
    ]
    static let functionKeys: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
    /// F1–F12: media keys on Apple keyboards unless fn is held or they are set as standard function keys.
    static let topRow: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
    /// Keys for writing and moving around in text.
    static let editingKeys: Set<UInt16> = [36, 48, 51, 53, 76, 114, 115, 116, 117, 119, 121, 123, 124, 125, 126]
    /// Volume and mute (most media keys never arrive as keys at all).
    static let mediaKeys: Set<UInt16> = [72, 73, 74]
}

extension KeyboardLayout {
    /// What the key types, nil when nothing.
    func typed(_ keyCode: UInt16, _ modifiers: KeyModifiers = []) -> String? {
        translate(keyCode, modifiers: modifiers)?.text
    }

    /// How the key reads on its cap: "W", "2", "F5", "←", "ß" (stays ß, not SS), "Space".
    func keyName(_ keyCode: UInt16) -> String? {
        if keyCode == KeyCodes.space { return HotkeysText.space }
        if let name = KeyCodes.specialNames[keyCode] { return name }
        if let pad = KeyCodes.keypad[keyCode] { return HotkeysText.keypad(pad) }
        guard let c = typed(keyCode), !c.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let upper = c.uppercased()
        return upper.count == c.count ? upper : c
    }

    /// The character menus match a ⌘ shortcut by (the ⌘ layer: ⌘Z is undo on a German keyboard
    /// too, although the key sits elsewhere). nil for keys that type nothing.
    func menuToken(_ keyCode: UInt16) -> String? {
        if KeyCodes.specialNames[keyCode] != nil || keyCode == KeyCodes.space { return nil }
        return (typed(keyCode, .command) ?? typed(keyCode))?.lowercased()
    }

    /// Key caps for a combination: modifier glyphs in macOS order, then the key ("⌃", "⌥", "K").
    func caps(_ combo: KeyCombo) -> [String] {
        combo.modifiers.glyphs + [keyName(combo.keyCode) ?? "?"]
    }

    /// One line: "⌃⌥K", "⇧⌘F5".
    func label(_ combo: KeyCombo) -> String {
        combo.modifiers.glyphs.joined() + (keyName(combo.keyCode) ?? "?")
    }
}

/// The layout the person types with right now (Text Input Sources + `UCKeyTranslate`).
struct SystemKeyboardLayout: KeyboardLayout {
    static let current = SystemKeyboardLayout()

    func translate(_ keyCode: UInt16, modifiers: KeyModifiers) -> (text: String, dead: Bool)? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
                ?? TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        func run(_ code: UInt16, _ state: UInt32, _ dead: inout UInt32) -> String? {
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = data.withUnsafeBytes { buffer -> OSStatus in
                guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
                return UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), state, UInt32(LMGetKbdType()),
                                      0, &dead, chars.count, &length, &chars)
            }
            guard status == noErr else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
        var dead: UInt32 = 0
        guard let first = run(keyCode, (modifiers.rawValue >> 8) & 0xFF, &dead) else { return nil }
        if first.isEmpty && dead != 0 {
            // a dead key: the accent on its own is what follows with a space
            let accent = run(KeyCodes.space, 0, &dead) ?? ""
            let trimmed = accent.trimmingCharacters(in: .whitespaces)
            if accent.isEmpty { return nil }
            return (trimmed.isEmpty ? accent : trimmed, true)
        }
        let printable = first.unicodeScalars.contains { !CharacterSet.controlCharacters.contains($0) }
        return printable && !first.isEmpty ? (first, false) : nil
    }
}

/// macOS's own shortcuts (System Settings > Keyboard > Keyboard Shortcuts) with the person's
/// changes, switched on or off.
nonisolated struct SystemShortcut: Equatable, Sendable {
    let keyCode: UInt16
    let modifiers: KeyModifiers
    let enabled: Bool
}

enum SystemShortcuts {
    private static let fnFlag: UInt32 = 0x20000          // kEventKeyModifierFnMask in the list

    /// Read once per recording (about 200 entries).
    static func read() -> [SystemShortcut] {
        var list: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&list) == noErr, let items = list?.takeRetainedValue() as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let code = (item[kHISymbolicHotKeyCode as String] as? NSNumber)?.intValue,
                  let raw = (item[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value,
                  code >= 0, code < 0xFFFF else { return nil }
            let key = UInt16(code)
            // the fn bit comes by itself with F-keys and arrows; on other keys it is a 🌐 shortcut of
            // its own (🌐Q, 🌐F), not the same keys without 🌐
            if raw & fnFlag != 0 && !KeyCodes.functionKeys.contains(key) && !KeyCodes.editingKeys.contains(key) { return nil }
            let mods = KeyModifiers(rawValue: raw)
            if key == 111 && (mods.isEmpty || mods == .shift) { return nil }    // F12 and ⇧F12: Dashboard, gone
            // fn-flagged arrows without ⌃ or ⌘ are the plain keys (text editing), not system shortcuts
            if raw & fnFlag != 0 && KeyCodes.editingKeys.contains(key) && mods.isDisjoint(with: [.control, .command]) { return nil }
            return SystemShortcut(keyCode: key, modifiers: mods, enabled: (item[kHISymbolicHotKeyEnabled as String] as? Bool) == true)
        }
    }
}
