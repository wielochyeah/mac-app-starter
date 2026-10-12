import SwiftUI

/// Settings pane "Keyboard Shortcuts": every registered hotkey as a recorder row, the rules in a
/// footnote. Empty state while no code registered a hotkey.
struct HotkeysPane: View {
    let center: HotkeyCenter
    @State private var recorder: ShortcutRecorder

    init(center: HotkeyCenter = .shared, recorder: ShortcutRecorder? = nil) {
        self.center = center
        _recorder = State(initialValue: recorder ?? ShortcutRecorder(center: center))
    }

    var body: some View {
        PaneScaffold(title: HotkeysText.pane, symbol: HotkeysModule.symbol, tint: HotkeysModule.tint,
                     subtitle: center.definitions.isEmpty ? nil : HotkeysText.paneIntro) {
            if center.definitions.isEmpty {
                EmptyState(symbol: HotkeysModule.symbol, title: HotkeysText.emptyTitle, message: HotkeysText.emptyMessage)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Space.xl)
            } else {
                SettingsSection(footnote: HotkeysText.paneFootnote) {
                    ForEach(center.definitions) { definition in
                        ShortcutRecorderRow(definition.id, center: center, recorder: recorder)
                    }
                }
            }
        }
        .onDisappear { recorder.cancel() }
    }
}

/// Onboarding step "Your shortcut" (order 600): the primary hotkey as large key caps that light up
/// while it is held, a line that says whether it works (and turns into "Works" after the first
/// press of these keys), and the recorder row to change it. Included only when a hotkey is
/// registered with `showInOnboarding: true`. The caps slot and the card area keep their height,
/// so the page does not move when the shortcut is removed or a refusal makes the row taller.
struct HotkeysOnboardingStep: View {
    let center: HotkeyCenter
    @State private var recorder: ShortcutRecorder
    /// Presses before the step appeared (or before the keys last changed) do not count as trying it.
    @State private var pressesAtStart: Int?

    /// `pressesAtStart`: renders pass 0 so a preview press counts as tried.
    init(center: HotkeyCenter = .shared, recorder: ShortcutRecorder? = nil, pressesAtStart: Int? = nil) {
        self.center = center
        _recorder = State(initialValue: recorder ?? ShortcutRecorder(center: center))
        let start = pressesAtStart ?? center.onboardingHotkey.map { center.pressCount[$0.id] ?? 0 }
        _pressesAtStart = State(initialValue: start)
    }

    var body: some View {
        if let hotkey = center.onboardingHotkey {
            let combo = center.combo(hotkey.id)
            let presses = center.pressCount[hotkey.id] ?? 0
            let tried = presses > (pressesAtStart ?? 0)
            let line = Self.statusLine(center: center, recorder: recorder, id: hotkey.id, tried: tried)
            OnboardingPage {
                OnboardingHeader(title: HotkeysText.stepTitle,
                                 subtitle: combo == nil ? HotkeysText.stepSubtitleNoKeys(hotkey.title())
                                                        : HotkeysText.stepSubtitle(hotkey.title()))
                    .padding(.bottom, Space.l)
                Group {
                    if let combo {
                        let _ = center.layoutRevision
                        BigKeyCaps(keys: center.layout.caps(combo), pressed: center.pressed.contains(hotkey.id))
                    } else {
                        Color.clear
                    }
                }
                .frame(height: Metrics.Hotkeys.bigKey.height)
                .padding(.bottom, Space.l)
                StatusLine(kind: line.kind, text: line.text)
                    .padding(.bottom, Space.l)
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSection(tone: .onboarding) {
                        ShortcutRecorderRow(hotkey.id, center: center, recorder: recorder)
                    }
                    OnboardingFootnote(HotkeysText.stepFootnote)
                }
                .frame(width: Metrics.onboardingColumn)
                .frame(minHeight: Metrics.Hotkeys.stepCardArea, alignment: .top)
            }
            .onAppear { if pressesAtStart == nil { pressesAtStart = presses } }
            .onChange(of: combo) { pressesAtStart = presses }
            .onDisappear { recorder.cancel() }
        }
    }

    /// What the status line says, from the real state: recording, no keys, keys that do not
    /// arrive (held by another app, refused by macOS, the same as another hotkey), tried or not.
    static func statusLine(center: HotkeyCenter, recorder: ShortcutRecorder, id: String,
                           tried: Bool) -> (kind: StatusMark.Kind, text: String) {
        if recorder.target == id { return (.busy, HotkeysText.stepRecording) }
        guard center.combo(id) != nil else {
            let hasStandard = center.definition(id)?.standard != nil
            return (.warn, hasStandard ? HotkeysText.stepNoShortcutDefault : HotkeysText.stepNoShortcut)
        }
        switch center.status[id] {
        case .heldElsewhere?: return (.warn, HotkeysText.stepHeld)
        case .failed?: return (.warn, HotkeysText.stepFailed)
        case .duplicate(let other)?: return (.warn, HotkeysText.stepDuplicate(center.definition(other)?.title() ?? other))
        default: return tried ? (.ok, HotkeysText.stepWorks) : (.idle, HotkeysText.stepTry)
        }
    }
}

/// The step's status line in the 30 pt slot height: grey dot "Press the keys once", green check
/// "Works", a spinner while recording, orange dot when the keys are missing or do not arrive.
/// Swaps in place with a fade.
private struct StatusLine: View {
    let kind: StatusMark.Kind
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StatusMark(kind, text, large: true)
                .id(text)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: Motion.stateScale)))
        }
        .frame(height: Metrics.statusSlotHeight)
        .animation(Motion.adaptive(Motion.page, reduce: reduceMotion), value: text)
    }
}
