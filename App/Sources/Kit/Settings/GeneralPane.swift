import AppKit
import SwiftUI

extension SettingKey {
    /// "system", "light" or "dark" (see `AppAppearance`).
    static var appAppearance: SettingKey<String> { .init("app.appearance", default: "system") }
}

/// The app-wide appearance choice. "system" follows the Mac; light and dark pin every window of
/// this app (Theme reads the SwiftUI colour scheme, which follows `NSApp.appearance`).
enum AppAppearance: String, CaseIterable {
    case system, light, dark

    /// Unknown stored values fall back to the Mac's appearance.
    init(stored: String) { self = AppAppearance(rawValue: stored) ?? .system }

    var appearanceName: NSAppearance.Name? {
        switch self {
        case .system: nil
        case .light: .aqua
        case .dark: .darkAqua
        }
    }

    var title: String {
        switch self {
        case .system: SettingsText.followMac
        case .light: SettingsText.light
        case .dark: SettingsText.dark
        }
    }

    static var current: AppAppearance { AppAppearance(stored: Settings.shared[.appAppearance]) }

    /// Applies the stored choice to the whole app.
    static func apply() {
        let name = current.appearanceName
        guard NSApp.appearance?.name != name else { return }
        NSApp.appearance = name.flatMap { NSAppearance(named: $0) }
    }
}

/// Resetting all settings: every key goes back to its default, except keys that hold state rather
/// than a preference. The kit keeps the setup state (`onboarding.*`, a reset never throws the person
/// back into the setup) and the developer switch `kit.showGallery`.
///
/// Modules extend it in `register()`:
///
///     SettingsReset.keep("ai.usage")                  // state (a prefix), not a preference
///     SettingsReset.didReset.append { MyCache.shared.reload() }   // re-read cached values
enum SettingsReset {
    /// Key prefixes a reset leaves alone. Exact keys work too (a key is its own prefix).
    private(set) static var keptPrefixes = ["onboarding.", "kit.showGallery"]
    /// Run after a reset, so modules re-read the values they hold in memory and apply them now
    /// (hotkeys re-register, a window re-reads its layout) instead of at the next launch.
    static var didReset: [() -> Void] = []

    static func keep(_ prefix: String) {
        if !keptPrefixes.contains(prefix) { keptPrefixes.append(prefix) }
    }

    /// The keys a reset removes (pure, tested).
    static func keys(in names: some Sequence<String>, keeping kept: [String] = keptPrefixes) -> [String] {
        names.filter { name in !kept.contains { name.hasPrefix($0) } }.sorted()
    }

    /// Removes those keys from `settings`, re-applies language and appearance, then runs `didReset`.
    static func perform(on settings: Settings = .shared, applyToApp: Bool = true) {
        if applyToApp { Localizer.shared.choice = nil }
        for name in keys(in: settings.values.keys) {
            settings.reset(SettingKey<JSONValue>(name, default: .null))
        }
        if applyToApp {
            AppAppearance.apply()
            for hook in didReset { hook() }
        }
        Log.info("settings: reset to defaults", "settings")
    }
}

/// Kit pane "General": app language (follow the Mac / English / German, live), appearance
/// (System / Light / Dark, app-wide), show the setup again, reset all settings (with an in-place
/// confirmation instead of an alert, so the state is visible in renders).
struct GeneralPane: View {
    /// Renders pass a fixed confirmation state.
    var confirmingReset = false
    @State private var confirming = false
    @State private var didReset = false
    private let localizer = Localizer.shared
    private let settings = Settings.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let language = Binding(get: { localizer.choice?.rawValue ?? "system" },
                               set: { localizer.choice = Lang(rawValue: $0) })
        let appearance = Binding(get: { AppAppearance(stored: settings[.appAppearance]).rawValue },
                                 set: { settings[.appAppearance] = $0; AppAppearance.apply() })
        PaneScaffold(title: SettingsText.general, symbol: "gearshape.fill", tint: .graphite) {
            SettingsSection(SettingsText.language, footnote: SettingsText.languageNote) {
                // each language in its own name, so it can be found in either language
                PickerRow(SettingsText.interface, subtitle: SettingsText.interfaceDetail,
                          options: [("system", SettingsText.followMac), ("de", Lang.de.nativeName), ("en", Lang.en.nativeName)],
                          selection: language)
            }
            SettingsSection(SettingsText.appearance) {
                PickerRow(SettingsText.lightOrDark, subtitle: SettingsText.appearanceDetail,
                          options: AppAppearance.allCases.map { ($0.rawValue, $0.title) }, selection: appearance)
            }
            SettingsSection(SettingsText.setupSection) {
                if AppActions.onboardingHandler != nil {
                    ButtonRow(SettingsText.showSetup, subtitle: SettingsText.showSetupDetail, button: SettingsText.showSetupButton) {
                        AppActions.openOnboarding()
                    }
                }
                if confirming || confirmingReset {
                    ResetConfirmation(cancel: { setConfirming(false) }, confirm: reset)
                } else {
                    Row(SettingsText.reset, subtitle: didReset ? nil : SettingsText.resetDetail) {
                        if didReset {
                            StatusMark(.ok, SettingsText.resetDone)
                        } else {
                            Chip(SettingsText.resetButton) { setConfirming(true) }
                        }
                    }
                }
            }
        }
    }

    private func setConfirming(_ on: Bool) {
        withAnimation(Motion.adaptive(Motion.expand, reduce: reduceMotion)) { confirming = on }
    }

    private func reset() {
        SettingsReset.perform()
        setConfirming(false)
        didReset = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.doneHold) { didReset = false }
    }
}

/// The reset row while asking: what happens, Reset, Cancel. Cancel is the prominent button and Esc
/// presses it; Reset is red text on a quiet button with no key equivalent, so Return never resets.
private struct ResetConfirmation: View {
    let cancel: () -> Void
    let confirm: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolFont(Metrics.noticeIcon, weight: .semibold)
                    .foregroundStyle(t.warn)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.hair) {
                    Text(SettingsText.resetConfirmTitle).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
                    Text(SettingsText.resetConfirmText)
                        .font(TypeScale.subtitle)
                        .foregroundStyle(t.fg2)
                        .lineSpacing(TypeScale.footnoteLineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: Space.xs) {
                Spacer(minLength: 0)
                // the label carries its own colour: the button style sets the default text colour
                Button(action: confirm) { Text(SettingsText.resetConfirmButton).foregroundStyle(t.destructive) }
                    .buttonStyle(.secondary)
                Button(CommonText.cancel, action: cancel)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Space.s)
        .transition(.opacity)
    }
}
