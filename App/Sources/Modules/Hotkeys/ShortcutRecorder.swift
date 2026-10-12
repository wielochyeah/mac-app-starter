import AppKit
import Observation

// Records a new shortcut for one hotkey (VoiceBud HubShortcutRecorder, without its modifier-only
// chords: Carbon hotkeys need a key). A key with modifiers is taken when the key goes down;
// `ShortcutRules` decides, and a refusal stays on screen with its reason (and a free variant)
// while the row keeps listening. Meanwhile every hotkey of the app is paused, so the keys pressed
// here start nothing, and the keys type nothing (the local event monitor swallows them). Only one
// recorder listens at a time (settings pane and onboarding step may both be open).

@Observable final class ShortcutRecorder {
    struct Problem: Equatable {
        let target: String
        let text: String
        var keys: [String] = []
        var suggestion: KeyCombo?
    }

    /// What the recorder reacts to (from `NSEvent`, or synthetic in tests).
    enum Event: Equatable {
        /// The modifiers held now (a flagsChanged event).
        case modifiers(KeyModifiers)
        /// The fn (globe) key went down or up.
        case fn(down: Bool)
        case keyDown(UInt16, KeyModifiers, isRepeat: Bool = false)
        case keyUp(UInt16, KeyModifiers)

        init?(_ event: NSEvent) {
            switch event.type {
            case .flagsChanged where event.keyCode == KeyCodes.fn: self = .fn(down: event.modifierFlags.contains(.function))
            case .flagsChanged: self = .modifiers(KeyModifiers(event.modifierFlags))
            case .keyDown: self = .keyDown(event.keyCode, KeyModifiers(event.modifierFlags), isRepeat: event.isARepeat)
            case .keyUp: self = .keyUp(event.keyCode, KeyModifiers(event.modifierFlags))
            default: return nil
            }
        }
    }

    /// The hotkey id being recorded.
    private(set) var target: String?
    /// The modifier glyphs held right now.
    private(set) var live: [String] = []
    /// Why the last try was refused (under its row until the next try).
    private(set) var problem: Problem?
    /// What the accepted shortcut does elsewhere (kept until the next change).
    private(set) var note: Problem?
    /// The choice before the last change that came with a note (or a removal): "Undo".
    private(set) var undo: (target: String, previous: HotkeyChoice)?

    @ObservationIgnored let center: HotkeyCenter
    /// false in tests and renders: no event monitor, no timeout, no haptics.
    @ObservationIgnored var listensToEvents = true
    @ObservationIgnored var systemShortcuts: @MainActor () -> [SystemShortcut] = { SystemShortcuts.read() }
    @ObservationIgnored var voiceOver: @MainActor () -> Bool = { NSWorkspace.shared.isVoiceOverEnabled }

    @ObservationIgnored private var system: [SystemShortcut] = []
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var resign: NSObjectProtocol?
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var held: KeyModifiers = []
    /// Modifiers were held during this press without a key: their release alone is no shortcut.
    @ObservationIgnored private var modifiersOnly = false
    /// Regular keys down now: a second one is two keys at once; a release without its press was
    /// taken by macOS or another app first.
    @ObservationIgnored private var keysDown: Set<UInt16> = []
    @ObservationIgnored private var fnDown = false
    @ObservationIgnored private var fnAlone = false
    /// This recorder holds one of the center's pauses.
    @ObservationIgnored private var holdsPause = false
    /// The recorder listening right now: starting another one cancels it.
    @ObservationIgnored private static weak var active: ShortcutRecorder?

    /// Seconds without a try after which the recording ends by itself.
    static let idleTimeout: Duration = .seconds(25)

    init(center: HotkeyCenter = .shared) {
        self.center = center
    }

    // MARK: Starting and stopping

    func start(_ target: String) {
        cancel()
        problem = nil
        if note?.target == target { note = nil }
        guard center.definition(target) != nil else { return }
        self.target = target
        held = []
        modifiersOnly = false
        keysDown = []
        fnDown = false
        fnAlone = false
        live = []
        system = systemShortcuts()
        if let other = Self.active, other !== self { other.cancel() }
        Self.active = self
        center.pause(true)
        holdsPause = true
        guard listensToEvents else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            MainActor.assumeIsolated {
                if let self, let e = Event(event) { self.handle(e) }
            }
            return nil                                   // the keys pressed here type nothing
        }
        resign = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                                        object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lostFocus() }
        }
        armTimeout()
    }

    func cancel() {
        if target != nil, problem?.target == target { problem = nil }
        stop()
    }

    private func stop() {
        guard target != nil else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resign { NotificationCenter.default.removeObserver(resign) }
        monitor = nil
        resign = nil
        timeout?.cancel()
        timeout = nil
        target = nil
        live = []
        if Self.active === self { Self.active = nil }
        if holdsPause {
            holdsPause = false
            center.pause(false)                          // registers the (new) keys again
        }
    }

    private func armTimeout() {
        guard listensToEvents else { return }
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: Self.idleTimeout)
            guard !Task.isCancelled else { return }
            self?.cancel()
        }
    }

    /// The app went to the background while recording: most likely macOS used the keys (⌘⇥, ⌘Space).
    private func lostFocus() {
        guard let target else { return }
        let keys = live
        stop()
        problem = Problem(target: target, text: HotkeysText.lostFocus, keys: keys)
    }

    // MARK: Events

    func handle(_ event: Event) {
        guard let target else { return }
        let layout = center.layout
        switch event {
        case .fn(let down):
            if down {
                fnDown = true
                fnAlone = keysDown.isEmpty && held.isEmpty
            } else {
                fnDown = false
                if fnAlone { refuse(target, HotkeysText.fnAlone, keys: ["fn"]) }
                fnAlone = false
            }
        case .modifiers(let mods):
            fnAlone = false
            if !mods.isEmpty {
                if keysDown.isEmpty { modifiersOnly = true }
                held = mods
                live = mods.glyphs
            } else {
                let wasOnly = modifiersOnly && keysDown.isEmpty
                let glyphs = held.glyphs
                held = []
                live = []
                modifiersOnly = false
                if wasOnly { refuse(target, HotkeysText.modifiersAlone, keys: glyphs) }
            }
        case .keyDown(let code, let mods, let isRepeat):
            if isRepeat { return }
            if code == KeyCodes.escape && mods.isEmpty { cancel(); return }
            if code == KeyCodes.delete && mods.isEmpty { remove(target); return }
            modifiersOnly = false
            fnAlone = false
            if let other = keysDown.first {
                // two regular keys at once: macOS reports only one key with modifiers
                keysDown.insert(code)
                let a = layout.keyName(other) ?? "?", b = layout.keyName(code) ?? "?"
                refuse(target, HotkeysText.twoKeys(a, b), keys: [a, b])
                return
            }
            keysDown.insert(code)
            if fnDown, !KeyCodes.functionKeys.contains(code), !KeyCodes.editingKeys.contains(code) {
                // fn with another key: macOS keeps those for itself (fn F full screen, fn Q Quick Note)
                refuse(target, HotkeysText.fnWithKey, keys: ["fn", layout.keyName(code) ?? "?"])
                return
            }
            judge(KeyCombo(keyCode: code, modifiers: mods))
        case .keyUp(let code, let mods):
            if keysDown.remove(code) == nil {
                // its press never came: macOS or another app took the keys first
                let combo = KeyCombo(keyCode: code, modifiers: mods)
                refuse(target, HotkeysText.caughtEarlier(layout.label(combo)), keys: layout.caps(combo),
                       suggestion: suggestion(for: code, in: context(for: target)))
            }
        }
    }

    private func context(for target: String) -> ShortcutRules.Context {
        ShortcutRules.Context(layout: center.layout, system: system, others: center.others(than: target), voiceOver: voiceOver())
    }

    private func judge(_ combo: KeyCombo) {
        guard let target else { return }
        let ctx = context(for: target)
        let verdict = ShortcutRules.judge(combo, in: ctx)
        apply(verdict, keys: center.layout.caps(combo))
        if verdict.isRefusal, var p = problem, p.target == target {
            p.suggestion = suggestion(for: combo.keyCode, in: ctx)
            problem = p
        }
    }

    /// A free variant on the same key that the rules take without a note and macOS has not given
    /// to another app.
    private func suggestion(for keyCode: UInt16, in ctx: ShortcutRules.Context) -> KeyCombo? {
        ShortcutRules.suggestion(for: keyCode, in: ctx) { [center] in center.probe($0) == nil }
    }

    private func refuse(_ target: String, _ text: String, keys: [String], suggestion: KeyCombo? = nil) {
        problem = Problem(target: target, text: text, keys: keys, suggestion: suggestion)
        live = []
        haptic(.generic)
        armTimeout()
    }

    private func apply(_ verdict: ShortcutRules.Verdict, keys: [String]) {
        guard let target else { return }
        switch verdict {
        case .refuse(let text):
            refuse(target, text, keys: keys)
        case .take(let combo, let text):
            let before = center.choice(target)
            let unchanged = center.combo(target) == combo
            if !unchanged { center.set(target, .combo(combo)) }
            problem = nil
            note = text.map { Problem(target: target, text: $0) }
            undo = text != nil && !unchanged ? (target, before) : nil
            stop()                                       // registers the new key
            if !unchanged, let why = registrationProblem(target, combo) {
                center.set(target, before)
                note = nil
                undo = nil
                // keep listening, with a free variant: the person picks another one right here
                start(target)
                problem = Problem(target: target, text: why, keys: keys,
                                  suggestion: suggestion(for: combo.keyCode, in: context(for: target)))
                haptic(.generic)
                return
            }
            haptic(.levelChange)
        }
    }

    /// What macOS said to the new keys (nil: fine, or not started, as in renders and tests).
    private func registrationProblem(_ target: String, _ combo: KeyCombo) -> String? {
        let keys = center.layout.label(combo)
        switch center.status[target] {
        case .failed(let code)?: return HotkeysText.macOSRefused(keys, Int(code))
        case .heldElsewhere?: return HotkeysText.heldElsewhere(keys)
        default: return nil
        }
    }

    // MARK: Actions of the row

    /// The free variant offered with a refusal.
    func use(_ combo: KeyCombo) {
        guard target != nil else { return }
        apply(.take(combo, note: nil), keys: center.layout.caps(combo))
    }

    /// ⌫ while recording: no shortcut for this hotkey (Undo and Default bring it back).
    func remove(_ target: String) {
        let before = center.choice(target)
        center.set(target, .off)
        problem = nil
        stop()
        guard before != .off else { return }
        note = Problem(target: target, text: HotkeysText.removed)
        undo = (target, before)
    }

    /// "Undo" shows only when it brings back something "Default" would not.
    func canUndo(_ target: String) -> Bool {
        undo?.target == target && note?.target == target && undo?.previous != .standard
    }

    func undoLast() {
        guard let undo else { return }
        restore(undo.target, to: undo.previous)
    }

    /// "Default" (`.standard`) or "Undo" (the previous choice): checked against the other hotkeys
    /// like a new shortcut.
    func restore(_ target: String, to choice: HotkeyChoice) {
        guard let definition = center.definition(target) else { return }
        if let wanted = choice.resolved(standard: definition.standard),
           let why = ShortcutRules.clash(wanted, others: center.others(than: target)) {
            problem = Problem(target: target, text: why, keys: center.layout.caps(wanted))
            return
        }
        center.set(target, choice)
        problem = nil                    // an old complaint may have been about the shortcut just changed
        if note?.target == target { note = nil }
        if undo?.target == target { undo = nil }
    }

    private func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard listensToEvents else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    // MARK: Renders

    /// Renders and the gallery: a row as it looks while recording, after a refused try, or with a note.
    func preview(target: String? = nil, live: [String] = [], problem: Problem? = nil, note: Problem? = nil, undoable: Bool = false) {
        listensToEvents = false
        self.target = target
        self.live = live
        self.problem = problem
        self.note = note
        if let note, undoable { undo = (note.target, .standard) }
    }
}
