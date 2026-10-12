import SwiftUI

// Module `hotkeys`: global keyboard shortcuts (Carbon `RegisterEventHotKey`, no permission needed),
// a settings pane "Keyboard Shortcuts" with a recorder per hotkey, and the onboarding step
// "Your shortcut". Code adds hotkeys with `HotkeyCenter.shared.register(…)` (example in HotkeyCenter.swift).
// Pane and step appear only once code registered a hotkey: a project without one shows neither.

enum HotkeysModule {
    static let symbol = "command"
    static let tint: TintName = .indigo

    static func register() {
        HotkeyCenter.shared.onRegister = { includePane() }
        if !HotkeyCenter.shared.definitions.isEmpty { includePane() }
        Registry.onboardingSteps.append(OnboardingStep(id: "hotkeys", order: 600,
                                                       isIncluded: { HotkeyCenter.shared.onboardingHotkey != nil }) { _ in
            AnyView(HotkeysOnboardingStep())
        })
        Registry.launchHooks.append { HotkeyCenter.shared.start() }
        Registry.terminateHooks.append { HotkeyCenter.shared.stop() }
        Registry.selfTests += selfTests
        HotkeysCatalog.register()
    }

    /// Adds the settings pane "Keyboard Shortcuts" once (with the first registered hotkey).
    static func includePane() {
        guard !Registry.settingsPanes.contains(where: { $0.id == paneID }) else { return }
        Registry.settingsPanes.append(SettingsPane(id: paneID, group: .settings, order: 400, title: { HotkeysText.pane },
                                                   symbol: symbol, tint: tint) { AnyView(HotkeysPane()) })
    }

    static let paneID = "hotkeys"

    /// Every standard the app registered, checked like a pressed combination (with macOS's list
    /// empty): nil when all are fine, else what is wrong.
    static func standardsProblems(_ center: HotkeyCenter, layout: KeyboardLayout? = nil) -> String? {
        var problems: [String] = []
        for (id, combo) in center.droppedStandards.sorted(by: { $0.key < $1.key }) {
            problems.append("\(id): \(center.layout.label(combo)) is no shortcut (needs ⌃, ⌥ or ⌘, or an F-key)")
        }
        for d in center.definitions {
            if let why = center.standardProblem(d.id, layout: layout) { problems.append("\(d.id): \(why)") }
        }
        return problems.isEmpty ? nil : problems.joined(separator: "; ")
    }

    private static var selfTests: [SelfTestCheck] {
        [
            // the project's standards (⌘Q or ⌘W as a global hotkey would break Quit or Close everywhere)
            SelfTestCheck(id: "hotkeys.standards") { standardsProblems(HotkeyCenter.shared) },
            SelfTestCheck(id: "hotkeys.rules") {
                let ctx = ShortcutRules.Context(layout: SystemKeyboardLayout.current, system: [], others: [], appName: "App")
                let quit = ShortcutRules.judge(KeyCombo(keyCode: 12, modifiers: .command), in: ctx)
                let free = ShortcutRules.judge(KeyCombo(keyCode: 40, modifiers: [.control, .option, .shift, .command]), in: ctx)
                guard quit.isRefusal else { return "⌘Q was not refused" }
                guard !free.isRefusal else { return "⌃⌥⇧⌘K was refused" }
                return nil
            },
            SelfTestCheck(id: "hotkeys.center") {
                let backend = FakeHotkeyBackend()
                let center = HotkeyCenter(backend: backend, store: MemoryHotkeyStore())
                var fired = 0
                let combo = KeyCombo(keyCode: 40, modifiers: [.option, .shift, .command])
                center.register(id: "selftest", title: { HotkeysText.pane }, default: combo) { fired += 1 }
                center.startForTesting()
                backend.press(combo)
                backend.press(combo, down: false)
                return fired == 1 && center.status["selftest"] == .active ? nil : "fake press did not arrive (\(fired))"
            },
        ]
    }
}
