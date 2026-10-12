import Foundation

// A keyboard layout from a fixed table: the render scenes use the US one, so the PNGs read the
// same on every Mac (the rules and key caps in them would follow the build Mac's layout otherwise),
// and the tests add a German one.

/// A keyboard layout from a table: base, ⇧, ⌥ and ⌥⇧ layers; "~" prefixed entries are dead keys.
/// ⌘ types the base layer (menus match ⌘ shortcuts by it), ⌃ types nothing.
struct TableKeyboardLayout: KeyboardLayout {
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

    /// Adds the number pad and the space bar to a layer.
    static func merged(_ main: [UInt16: String]) -> [UInt16: String] {
        main.merging(keypad) { a, _ in a }.merging([49: " "]) { a, _ in a }
    }

    /// Mac "U.S." (main keys; ⌥ layer as on macOS).
    static let us = TableKeyboardLayout(
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
}
