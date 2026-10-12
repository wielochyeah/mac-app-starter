import AppKit

// The value types of the hotkeys module: modifier set, a key with modifiers, and what the person
// chose for one hotkey. All `nonisolated` and Sendable, so they can be stored through `SettingKey`
// (see Kit/Core/Settings.swift) and used from the Carbon callback.

/// The four modifier keys, with Carbon's bit values (`cmdKey` 256, `shiftKey` 512, `optionKey` 2048,
/// `controlKey` 4096), so a set goes straight into `RegisterEventHotKey`.
nonisolated struct KeyModifiers: OptionSet, Hashable, Sendable {
    let rawValue: UInt32

    init(rawValue: UInt32) { self.rawValue = rawValue & Self.all.rawValue }

    static let command = KeyModifiers(rawValue: 256)
    static let shift = KeyModifiers(rawValue: 512)
    static let option = KeyModifiers(rawValue: 2048)
    static let control = KeyModifiers(rawValue: 4096)
    static let all: KeyModifiers = KeyModifiers(uncheckedRaw: 256 | 512 | 2048 | 4096)

    private init(uncheckedRaw: UInt32) { rawValue = uncheckedRaw }

    /// macOS order ⌃⌥⇧⌘, one glyph per modifier.
    var glyphs: [String] {
        var out: [String] = []
        if contains(.control) { out.append("⌃") }
        if contains(.option) { out.append("⌥") }
        if contains(.shift) { out.append("⇧") }
        if contains(.command) { out.append("⌘") }
        return out
    }

    /// Names used in settings.json (readable when edited by hand).
    var names: [String] {
        var out: [String] = []
        if contains(.control) { out.append("control") }
        if contains(.option) { out.append("option") }
        if contains(.shift) { out.append("shift") }
        if contains(.command) { out.append("command") }
        return out
    }

    init?(names: [String]) {
        var m: KeyModifiers = []
        for name in names {
            switch name.lowercased() {
            case "control", "ctrl": m.insert(.control)
            case "option", "alt": m.insert(.option)
            case "shift": m.insert(.shift)
            case "command", "cmd": m.insert(.command)
            default: return nil
            }
        }
        self = m
    }

    /// From an AppKit event's flags (device-independent part only).
    init(_ flags: NSEvent.ModifierFlags) {
        var m: KeyModifiers = []
        if flags.contains(.control) { m.insert(.control) }
        if flags.contains(.option) { m.insert(.option) }
        if flags.contains(.shift) { m.insert(.shift) }
        if flags.contains(.command) { m.insert(.command) }
        self = m
    }
}

/// A key with modifiers (or an F-key alone) that the app registers with macOS.
/// `keyCode` is the virtual key code (`kVK_*`): a position on the keyboard, the same on every layout.
/// What the key reads as ("K", "Ö", "F5") comes from the layout in use (`KeyboardLayout`).
///
/// Stored as `{"keyCode": 40, "modifiers": ["control", "option", "command"]}`.
nonisolated struct KeyCombo: Codable, Hashable, Sendable {
    let keyCode: UInt16
    let modifiers: KeyModifiers

    init(keyCode: UInt16, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Key codes above this are not keys of a Mac keyboard (and Carbon refuses them).
    static let maxKeyCode: UInt16 = 127

    private enum CodingKeys: String, CodingKey { case keyCode, modifiers }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let code = try c.decode(UInt16.self, forKey: .keyCode)
        let names = try c.decodeIfPresent([String].self, forKey: .modifiers) ?? []
        guard code <= Self.maxKeyCode, let mods = KeyModifiers(names: names) else {
            throw DecodingError.dataCorruptedError(forKey: .keyCode, in: c, debugDescription: "not a key combination")
        }
        keyCode = code
        modifiers = mods
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(keyCode, forKey: .keyCode)
        try c.encode(modifiers.names, forKey: .modifiers)
    }
}

/// What the person chose for one hotkey: the app's standard, no shortcut, or an own combination.
/// Stored per hotkey as setting `hotkeys.<id>`: `"off"` or a `KeyCombo` object; the standard is
/// the absent key. A value that cannot be read gives `.standard` (one bad hand edit costs one entry).
nonisolated enum HotkeyChoice: Codable, Hashable, Sendable {
    case standard
    case off
    case combo(KeyCombo)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let word = try? c.decode(String.self) {
            switch word {
            case "off": self = .off
            case "standard": self = .standard
            default: throw DecodingError.dataCorruptedError(in: c, debugDescription: "unknown hotkey choice \(word)")
            }
            return
        }
        self = .combo(try c.decode(KeyCombo.self))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .standard: try c.encode("standard")
        case .off: try c.encode("off")
        case .combo(let combo): try c.encode(combo)
        }
    }

    /// The combination this choice gives for a hotkey whose standard is `standard`.
    func resolved(standard: KeyCombo?) -> KeyCombo? {
        switch self {
        case .standard: standard
        case .off: nil
        case .combo(let combo): combo
        }
    }
}

extension SettingKey {
    /// One hotkey's choice: `hotkeys.<id>`.
    static func hotkey(_ id: String) -> SettingKey<HotkeyChoice> { .init("hotkeys.\(id)", default: .standard) }
}
