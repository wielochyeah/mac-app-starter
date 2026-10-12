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

/// Resetting all settings: every key goes back to its default except the setup state
/// (`onboarding.*`), so a reset never throws the person back into the setup.
enum SettingsReset {
    static let keptPrefixes = ["onboarding."]

    /// The keys a reset removes (pure, tested).
    static func keys(in names: some Sequence<String>) -> [String] {
        names.filter { name in !keptPrefixes.contains { name.hasPrefix($0) } }.sorted()
    }

    /// Removes those keys from `settings`, then re-applies language and appearance.
    static func perform(on settings: Settings = .shared, applyToApp: Bool = true) {
        if applyToApp { Localizer.shared.choice = nil }
        for name in keys(in: settings.values.keys) {
            settings.reset(SettingKey<JSONValue>(name, default: .null))
        }
        if applyToApp { AppAppearance.apply() }
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
            SettingsSection {
                PickerRow(SettingsText.appearance, subtitle: SettingsText.appearanceDetail,
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { didReset = false }
    }
}

/// The reset row while asking: what happens, Cancel, Reset. Reset is the one primary button.
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
                Button(CommonText.cancel, action: cancel)
                    .buttonStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                Button(SettingsText.resetConfirmButton, action: confirm)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Space.s)
        .transition(.opacity)
    }
}
