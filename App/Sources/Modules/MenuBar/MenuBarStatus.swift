import Observation

/// What the app is doing, as the menu bar icon and the panel header show it.
nonisolated enum MenuBarState: String, CaseIterable, Sendable {
    /// Nothing going on: the plain symbol.
    case idle
    /// Working: a turning ring at the symbol (style "marks") or the accent colour (style "color").
    case busy
    /// Something needs the person: a red dot at the symbol.
    case attention
}

/// The menu bar icon's state. Any code on the main actor sets it:
///
///     MenuBarStatus.shared.state = .busy
///     MenuBarStatus.shared.message = MyText.importing      // optional, else the state's own words
///     MenuBarStatus.shared.shortTitle = MyText.fileCount   // optional, "3 files" next to the icon
///     …
///     MenuBarStatus.shared.state = .idle                   // also clears message and short title
///
/// The status item, the panel header and the tooltip follow at once (`@Observable`).
@Observable final class MenuBarStatus {
    static let shared = MenuBarStatus()

    var state: MenuBarState = .idle {
        didSet {
            if state == .idle {
                message = nil
                shortTitle = nil
            }
        }
    }

    /// The panel's status line ("Importing 3 files…"). Nil shows the state's default words.
    var message: String?

    /// A word or two next to the icon when "Status next to the icon" is on ("3 files", "0:42").
    /// Nil shows the state's name ("Working"). Longer texts are cut (`MenuBarPrefs.titleLimit`).
    var shortTitle: String?

    /// The status line of the panel header, the tooltip and VoiceOver.
    var line: String { message ?? MenuBarText.statusLine(state) }

    init(state: MenuBarState = .idle, message: String? = nil, shortTitle: String? = nil) {
        self.state = state
        self.message = message
        self.shortTitle = shortTitle
    }
}

/// How the icon shows the state (setting `menubar.iconStyle`).
nonisolated enum MenuBarIconStyle: String, CaseIterable, Sendable {
    /// Always the plain symbol; the state shows only in the panel.
    case plain
    /// A turning ring while busy, a red dot for attention (default).
    case marks
    /// The symbol in the accent colour while busy, the red dot for attention.
    case color

    /// Unknown or broken setting values fall back to the default.
    init(setting: String) { self = MenuBarIconStyle(rawValue: setting) ?? .marks }
}

extension SettingKey {
    /// "plain", "marks" or "color" (`MenuBarIconStyle`).
    static var menuBarIconStyle: SettingKey<String> { .init("menubar.iconStyle", default: MenuBarIconStyle.marks.rawValue) }
    /// Shows a short title next to the icon while the app is busy or needs attention.
    static var menuBarStatusText: SettingKey<Bool> { .init("menubar.statusText", default: false) }
    /// Whether the status item is shown. Only honoured when the window module keeps the app reachable.
    static var menuBarVisible: SettingKey<Bool> { .init("menubar.visible", default: true) }
}

/// The settings of the menu bar item, resolved (pure rules, tested).
enum MenuBarPrefs {
    /// Without a main window the status item is the only way into the app: it always shows.
    static func isVisible(setting: Bool, windowModule: Bool) -> Bool { setting || !windowModule }

    /// Characters next to the icon at most: a wide item pushes other items (or itself) under the
    /// notch on MacBooks.
    static let titleLimit = 14

    /// Text next to the icon: only with the setting on and only while busy or needing attention;
    /// the short title or the state's name ("Working", "Needs you"), never the panel sentence.
    static func title(state: MenuBarState, short: String?, showsText: Bool) -> String {
        guard showsText, state != .idle else { return "" }
        let text = (short?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? MenuBarText.stateName(state)
        return capped(text)
    }

    /// Cuts a text to `titleLimit` characters with an ellipsis.
    static func capped(_ text: String, limit: Int = titleLimit) -> String {
        guard text.count > limit else { return text }
        return text.prefix(limit - 1).trimmingCharacters(in: .whitespaces) + "…"
    }
}
