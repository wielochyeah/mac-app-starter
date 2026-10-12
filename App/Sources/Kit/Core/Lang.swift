import Foundation
import Observation

/// The UI languages. Every user-visible string exists in both (see `tr(en:de:)`).
nonisolated enum Lang: String, CaseIterable, Codable, Sendable {
    case en, de

    /// Each language in its own name, so it can be found in either language.
    var nativeName: String {
        switch self {
        case .en: "English"
        case .de: "Deutsch"
        }
    }

    var locale: Locale { Locale(identifier: self == .de ? "de_DE" : "en_US") }

    /// The Mac's language if it is one of ours (German for any `de*`), else English.
    static func preferred(_ languages: [String] = Locale.preferredLanguages) -> Lang {
        for code in languages {
            let base = code.lowercased()
            if base.hasPrefix("de") { return .de }
            if base.hasPrefix("en") { return .en }
        }
        return .en
    }
}

/// Holds the current UI language. `@Observable`, so every SwiftUI body that calls `tr()` redraws
/// when the language changes (live switch, no restart).
///
/// Precedence: `forced` (env `STARTER_LANG=en|de`, renders, tests) > `choice` (the user's pick,
/// persisted as setting `app.language`) > the Mac's preferred languages.
@Observable final class Localizer {
    static let shared = Localizer()

    /// Set by `STARTER_LANG`, `--render --lang` and tests. Never persisted.
    var forced: Lang?
    /// The user's pick; `nil` follows the Mac.
    var choice: Lang? {
        didSet {
            guard persists, choice != oldValue else { return }
            Settings.shared[.appLanguage] = choice?.rawValue ?? "system"
        }
    }
    /// The Mac's language, read at launch (macOS relaunches apps when it changes).
    private(set) var system: Lang

    @ObservationIgnored private let persists: Bool

    var lang: Lang { forced ?? choice ?? system }

    init(environment: [String: String] = ProcessInfo.processInfo.environment,
         systemLanguages: [String] = Locale.preferredLanguages,
         stored: String? = nil,
         persists: Bool = true) {
        self.persists = persists
        system = Lang.preferred(systemLanguages)
        forced = environment["STARTER_LANG"].flatMap { Lang(rawValue: $0.lowercased()) }
        let saved = stored ?? (persists ? Settings.shared[.appLanguage] : "system")
        choice = Lang(rawValue: saved)
    }
}

extension SettingKey {
    /// "system", "en" or "de".
    static var appLanguage: SettingKey<String> { .init("app.language", default: "system") }
}

/// The one way to write UI copy: both languages, chosen by `Localizer.shared.lang`.
/// Lives in `*Text.swift` files (`enum <Area>Text`), never inline in views.
func tr(en: String, de: String) -> String {
    Localizer.shared.lang == .de ? de : en
}

/// Locale-aware formatting that follows the UI language (not the process locale).
enum Format {
    /// 1,284 (en) / 1.284 (de)
    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(Localizer.shared.lang.locale))
    }

    /// 0.7 (en) / 0,7 (de) with a fixed number of fraction digits.
    static func decimal(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Localizer.shared.lang.locale))
    }

    /// "0.7 s" / "0,7 s"
    static func seconds(_ value: Double) -> String { decimal(value) + "\u{202F}s" }

    /// Monday, October 5 / Montag, 5. Oktober
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(Localizer.shared.lang.locale))
    }

    /// 14:05 in both languages (24 h, like macOS in Germany) unless the locale says otherwise.
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(Localizer.shared.lang.locale))
    }
}
