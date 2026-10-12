import SwiftUI

// Render scenes (`hotkeys.*`) and gallery entries. Sample hotkeys live only here, in a center with
// a fake backend and an in-memory store: nothing is registered with macOS and nothing is saved.
// Reasons and notes come from the real rule engine, so the renders show what the app would say.
// Everything reads through the fixed US layout, so the PNGs are the same on every Mac.

enum HotkeysCatalog {
    static func register() {
        let scenes: [(id: String, size: CGSize, title: () -> String, view: () -> AnyView)] = [
            ("hotkeys.pane", Sample.paneSize, { HotkeysText.galleryPane }, { AnyView(SamplePane()) }),
            ("hotkeys.pane-empty", Sample.emptyPaneSize, { HotkeysText.galleryPane }, { AnyView(SampleEmptyPane()) }),
            ("hotkeys.recorder-states", .zero, { HotkeysText.galleryRecorder }, { AnyView(RecorderStates()) }),
            ("hotkeys.big-keys", .zero, { HotkeysText.galleryBigKeys }, { AnyView(BigKeysSample()) }),
            ("hotkeys.onboarding", .zero, { HotkeysText.galleryStep }, { AnyView(SampleStep(state: .waiting)) }),
            ("hotkeys.onboarding-pressed", .zero, { HotkeysText.galleryStep }, { AnyView(SampleStep(state: .pressed)) }),
            ("hotkeys.onboarding-refused", .zero, { HotkeysText.galleryStep }, { AnyView(SampleStep(state: .refused)) }),
            ("hotkeys.onboarding-refused-long", .zero, { HotkeysText.galleryStep }, { AnyView(SampleStep(state: .refusedLong)) }),
            ("hotkeys.onboarding-caught", .zero, { HotkeysText.galleryStep }, { AnyView(SampleStep(state: .caught)) }),
            ("hotkeys.onboarding-recording", .zero, { HotkeysText.galleryStep }, { AnyView(SampleStep(state: .recording)) }),
            ("hotkeys.onboarding-held", .zero, { HotkeysText.galleryStep }, { AnyView(SampleStep(state: .held)) }),
            ("hotkeys.onboarding-off", .zero, { HotkeysText.galleryStep }, { AnyView(SampleStep(state: .off)) }),
        ]
        for scene in scenes {
            Registry.renderScenes.append(RenderScene(id: scene.id, size: scene.size, content: scene.view))
        }
        Registry.gallery += [
            GalleryEntry(id: "hotkeys.recorder", area: "hotkeys", title: { HotkeysText.galleryRecorder }) { AnyView(RecorderStates()) },
            GalleryEntry(id: "hotkeys.big-keys", area: "hotkeys", title: { HotkeysText.galleryBigKeys }) { AnyView(BigKeysSample()) },
        ]
    }
}

// MARK: - Sample data

private enum Sample {
    static let paneSize = CGSize(width: 680, height: 340)
    static let emptyPaneSize = CGSize(width: 680, height: 320)

    static let quick = KeyCombo(keyCode: 40, modifiers: [.option, .shift, .command])        // ⌥⇧⌘K
    static let capture = KeyCombo(keyCode: 8, modifiers: [.control, .option, .command])      // ⌃⌥⌘C
    static let pause = KeyCombo(keyCode: 105, modifiers: [])                                 // F13
    static let closeWindow = KeyCombo(keyCode: 13, modifiers: .command)                       // ⌘W
    static let deleteWord = KeyCombo(keyCode: 13, modifiers: .control)                        // ⌃W
    static let screenshotOptions = KeyCombo(keyCode: 23, modifiers: [.shift, .command])       // ⇧⌘5
    /// macOS's list as on a new Mac, for the refusals of switched-on system shortcuts.
    static let system = [SystemShortcut(keyCode: 23, modifiers: [.shift, .command], enabled: true)]
    static let layout = TableKeyboardLayout.us

    /// A center with the three sample hotkeys; `choices` as if the person had changed them.
    static func center(_ choices: [String: HotkeyChoice] = [:]) -> HotkeyCenter {
        let center = HotkeyCenter(backend: FakeHotkeyBackend(), store: MemoryHotkeyStore(choices))
        center.layout = layout
        center.register(id: "quick", title: { HotkeysSampleText.quickWindow }, subtitle: { HotkeysSampleText.quickWindowDetail },
                        default: quick, order: 0, showInOnboarding: true) {}
        center.register(id: "capture", title: { HotkeysSampleText.captureSelection },
                        subtitle: { HotkeysSampleText.captureSelectionDetail }, default: capture, order: 1) {}
        center.register(id: "pause", title: { HotkeysSampleText.pause }, default: pause, order: 2) {}
        return center
    }

    static func recorder(_ center: HotkeyCenter) -> ShortcutRecorder {
        let recorder = ShortcutRecorder(center: center)
        recorder.listensToEvents = false
        return recorder
    }

    static func context(_ center: HotkeyCenter, for id: String) -> ShortcutRules.Context {
        ShortcutRules.Context(layout: center.layout, system: system, others: center.others(than: id))
    }

    /// The refusal the rules give for `combo`, with their free variant.
    static func refusal(_ center: HotkeyCenter, _ id: String, _ combo: KeyCombo) -> ShortcutRecorder.Problem {
        let ctx = context(center, for: id)
        let text: String
        switch ShortcutRules.judge(combo, in: ctx) {
        case .refuse(let why): text = why
        case .take: text = ""
        }
        return ShortcutRecorder.Problem(target: id, text: text, keys: center.layout.caps(combo),
                                        suggestion: ShortcutRules.suggestion(for: combo.keyCode, in: ctx))
    }

    /// The note the rules give for `combo` (taken).
    static func note(_ center: HotkeyCenter, _ id: String, _ combo: KeyCombo) -> ShortcutRecorder.Problem? {
        ShortcutRules.judge(combo, in: context(center, for: id)).note.map { ShortcutRecorder.Problem(target: id, text: $0) }
    }
}

// MARK: - Settings pane

/// The pane as a person sees it after changing two shortcuts: the capture key with a Terminal
/// note and Undo, the pause key removed.
private struct SamplePane: View {
    private let center = Sample.center(["capture": .combo(Sample.deleteWord), "pause": .off])
    private let recorder: ShortcutRecorder

    init() {
        recorder = Sample.recorder(center)
        recorder.preview(note: Sample.note(center, "capture", Sample.deleteWord), undoable: true)
    }

    var body: some View { HotkeysPane(center: center, recorder: recorder) }
}

private struct SampleEmptyPane: View {
    private let center: HotkeyCenter = {
        let center = HotkeyCenter(backend: FakeHotkeyBackend(), store: MemoryHotkeyStore())
        center.layout = Sample.layout
        return center
    }()

    var body: some View { HotkeysPane(center: center) }
}

// MARK: - Recorder states

/// Every state of a recorder row, one card each: set, recording, modifiers held, refused with a
/// free variant, taken with a note and Undo, held by another app, no shortcut.
private struct RecorderStates: View {
    private struct Item: Identifiable {
        let id: String
        let title: String
        let center: HotkeyCenter
        let recorder: ShortcutRecorder
        /// The hotkey whose row is shown.
        var row = "quick"
    }

    private var items: [Item] {
        func item(_ title: String, _ choices: [String: HotkeyChoice] = [:], row: String = "quick",
                  _ configure: (HotkeyCenter, ShortcutRecorder) -> Void) -> Item {
            let center = Sample.center(choices)
            let recorder = Sample.recorder(center)
            configure(center, recorder)
            return Item(id: title, title: title, center: center, recorder: recorder, row: row)
        }
        return [
            item(HotkeysSampleText.stateIdle) { _, _ in },
            item(HotkeysSampleText.stateRecording) { _, r in r.preview(target: "quick") },
            item(HotkeysSampleText.stateHolding) { _, r in r.preview(target: "quick", live: KeyModifiers([.control, .option]).glyphs) },
            item(HotkeysSampleText.stateRefused) { c, r in
                r.preview(target: "quick", problem: Sample.refusal(c, "quick", Sample.closeWindow))
            },
            item(HotkeysSampleText.stateNote, ["quick": .combo(Sample.deleteWord)]) { c, r in
                r.preview(note: Sample.note(c, "quick", Sample.deleteWord), undoable: true)
            },
            item(HotkeysSampleText.stateHeld) { c, _ in c.previewStatus("quick", .heldElsewhere) },
            item(HotkeysSampleText.stateDuplicate, ["capture": .combo(Sample.quick)], row: "capture") { _, _ in },
            item(HotkeysSampleText.stateOff, ["quick": .off]) { _, _ in },
        ]
    }

    var body: some View {
        Specimen(width: Sample.paneSize.width) {
            ForEach(items) { item in
                SettingsSection(item.title) {
                    ShortcutRecorderRow(item.row, center: item.center, recorder: item.recorder)
                }
            }
        }
    }
}

// MARK: - Large key caps

private struct BigKeysSample: View {
    var body: some View {
        let layout = Sample.layout
        Specimen(width: Metrics.onboardingColumn) {
            VStack(spacing: Space.l) {
                BigKeyCaps(keys: layout.caps(Sample.quick))
                BigKeyCaps(keys: layout.caps(Sample.quick), pressed: true)
                BigKeyCaps(keys: layout.caps(Sample.pause))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s)
        }
    }
}

// MARK: - Onboarding step

private struct SampleStep: View {
    enum State { case waiting, pressed, refused, refusedLong, caught, recording, held, off }
    private let center = Sample.center()
    private let recorder: ShortcutRecorder

    init(state: State) {
        recorder = Sample.recorder(center)
        switch state {
        case .waiting: break
        case .pressed: center.previewPress("quick")
        case .refused: recorder.preview(target: "quick", problem: Sample.refusal(center, "quick", Sample.closeWindow))
        case .refusedLong:
            // a long reason with a free variant: ⇧⌘5 is switched on in macOS on every Mac
            recorder.preview(target: "quick", problem: Sample.refusal(center, "quick", Sample.screenshotOptions))
        case .caught:
            // the longest reason the recorder gives (the keys never arrived)
            let caught = Sample.layout.label(Sample.screenshotOptions)
            let suggestion = ShortcutRules.suggestion(for: Sample.screenshotOptions.keyCode, in: Sample.context(center, for: "quick"))
            recorder.preview(target: "quick", problem: ShortcutRecorder.Problem(
                target: "quick", text: HotkeysText.caughtEarlier(caught), keys: Sample.layout.caps(Sample.screenshotOptions),
                suggestion: suggestion))
        case .recording: recorder.preview(target: "quick")
        case .held: center.previewStatus("quick", .heldElsewhere)
        case .off: center.set("quick", .off)
        }
    }

    var body: some View {
        RenderBoard {
            StaticWindow(size: Metrics.onboardingWindow, chrome: .onboarding) {
                OnboardingFrame {
                    HotkeysOnboardingStep(center: center, recorder: recorder, pressesAtStart: 0)
                } footer: {
                    OnboardingFooter(count: 7, index: 4, back: {}, advance: {})
                }
            }
        }
    }
}
