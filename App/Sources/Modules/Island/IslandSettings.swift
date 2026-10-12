import Foundation

/// How the island appears (setting `island.style`).
nonisolated enum IslandStyle: String, CaseIterable, Sendable {
    /// The island at the notch; below the notch as a capsule while another notch app shows
    /// something (`Island.notchBusy`, which the app has to provide; without it `auto` behaves
    /// like `island`); the capsule on screens without a notch.
    case auto
    /// Always the island at the notch (screens without a notch still get the capsule: the
    /// island never draws a fake notch).
    case island
    /// Always the capsule below the menu bar.
    case capsule

    /// The styles settings offer: "Island at the Notch" only when the app reports a busy notch
    /// (`dodges`); otherwise it would look and behave exactly like Automatic.
    static func offered(dodges: Bool) -> [IslandStyle] {
        dodges ? allCases : [.auto, .capsule]
    }

    /// The tile that stands for this stored style (`island` shows as Automatic where it is not offered).
    func shown(dodges: Bool) -> IslandStyle {
        self == .island && !dodges ? .auto : self
    }
}

extension SettingKey {
    static var islandStyle: SettingKey<String> { .init("island.style", default: IslandStyle.auto.rawValue) }
    /// Seconds a done card stays; `IslandTiming.stays` (60) or more: until the next content.
    static var islandConfirmSeconds: SettingKey<Double> { .init("island.confirmSeconds", default: 3) }
    static var islandHoverExpand: SettingKey<Bool> { .init("island.hoverExpand", default: true) }
    static var islandSounds: SettingKey<Bool> { .init("island.sounds", default: false) }
    static var islandHaptics: SettingKey<Bool> { .init("island.haptics", default: true) }
    static var islandHideInFullscreen: SettingKey<Bool> { .init("island.hideInFullscreen", default: false) }
}

/// The island's settings as one value: read once per change, replaced in tests.
struct IslandPrefs: Equatable {
    var style: IslandStyle = .auto
    var confirmSeconds: Double = 3
    var hoverExpand = true
    var sounds = false
    var haptics = true
    var hideInFullscreen = false

    /// The values in `Settings.shared` (unknown style names fall back to `auto`).
    static var current: IslandPrefs {
        let s = Settings.shared
        return IslandPrefs(style: IslandStyle(rawValue: s[.islandStyle]) ?? .auto,
                           confirmSeconds: s[.islandConfirmSeconds],
                           hoverExpand: s[.islandHoverExpand],
                           sounds: s[.islandSounds],
                           haptics: s[.islandHaptics],
                           hideInFullscreen: s[.islandHideInFullscreen])
    }

    /// How long a done card stays: nil = until the next content.
    var confirmDelay: Double? {
        confirmSeconds >= IslandTiming.stays ? nil : max(IslandTiming.minConfirm, confirmSeconds)
    }

    /// The choices offered in settings (seconds; `IslandTiming.stays` = "Stays").
    static let confirmChoices: [Double] = [1.5, 3, 5, IslandTiming.stays]
}
