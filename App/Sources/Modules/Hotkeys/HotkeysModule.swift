import SwiftUI

// Module `hotkeys`: global keyboard shortcuts (Carbon `RegisterEventHotKey`, no permission needed),
// a settings pane "Keyboard Shortcuts" with a recorder per hotkey, and the onboarding step
// "Your shortcut". Code adds hotkeys with `HotkeyCenter.shared.register(…)`; see README.md here.

enum HotkeysModule {
    static let symbol = "command"
    static let tint: TintName = .indigo

    static func register() {
        Registry.settingsPanes.append(SettingsPane(id: "hotkeys", group: .settings, order: 400, title: { HotkeysText.pane },
                                                   symbol: symbol, tint: tint) { AnyView(HotkeysPane()) })
        Registry.onboardingSteps.append(OnboardingStep(id: "hotkeys", order: 600,
                                                       isIncluded: { HotkeyCenter.shared.onboardingHotkey != nil }) { _ in
            AnyView(HotkeysOnboardingStep())
        })
        Registry.launchHooks.append { HotkeyCenter.shared.start() }
        Registry.terminateHooks.append { HotkeyCenter.shared.stop() }
        Registry.selfTests += selfTests
        HotkeysCatalog.register()
    }

    private static var selfTests: [SelfTestCheck] {
        [
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
