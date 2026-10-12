import AppKit
import Observation

// Global hotkeys (VoiceBud ui/Hotkeys.swift, generalised). Code registers a hotkey with an id, a
// title for the settings row and a standard combination; the person may choose another one or
// none, which is persisted per id (`hotkeys.<id>` in settings.json) and takes effect at once, no
// restart. Registration with macOS goes through a `HotkeyBackend` (Carbon `RegisterEventHotKey`
// in the app, a fake in tests and renders).
//
//     HotkeyCenter.shared.register(id: "quick-window", title: { MyText.quickWindow },
//                                  default: KeyCombo(keyCode: 40, modifiers: [.option, .shift, .command]),
//                                  showInOnboarding: true) { QuickWindow.toggle() }

/// One hotkey as code registered it.
struct HotkeyDefinition: Identifiable {
    let id: String
    let order: Int
    let title: () -> String
    let subtitle: (() -> String)?
    /// nil: no standard; the hotkey does nothing until the person sets one.
    let standard: KeyCombo?
    /// The onboarding step "Shortcut" shows the first such hotkey (by order).
    let showInOnboarding: Bool
    let onPress: () -> Void
    let onRelease: (() -> Void)?
}

/// What macOS made of a hotkey's combination.
enum HotkeyStatus: Equatable {
    /// Registered; presses arrive.
    case active
    /// No combination (none chosen, or no standard).
    case off
    /// Not registered right now: not started (renders, tests, headless) or paused while recording.
    case inactive
    /// Another hotkey of this app (the id) has the same keys and gets them; this one does nothing.
    case duplicate(of: String)
    /// Another app registered the same keys exclusively; this app gets no presses until it lets go.
    case heldElsewhere
    /// macOS refused the combination (status code).
    case failed(Int32)
}

/// What a backend reports for one registration.
enum HotkeyRegistration: Equatable {
    case ok, heldElsewhere, failed(Int32)
}

/// Talks to macOS (or pretends to). Numbers identify registrations; presses come back through
/// `deliver(number, down)`.
protocol HotkeyBackend: AnyObject {
    var deliver: ((UInt32, Bool) -> Void)? { get set }
    func install()
    func register(_ combo: KeyCombo, number: UInt32) -> HotkeyRegistration
    func unregister(number: UInt32)
    /// Asks macOS about a combination without keeping it: nil when free, else the status.
    func probe(_ combo: KeyCombo) -> Int32?
}

/// Where choices are kept.
protocol HotkeyStore {
    func load(_ id: String) -> HotkeyChoice
    func save(_ id: String, _ choice: HotkeyChoice)
}

/// The app's settings file.
struct SettingsHotkeyStore: HotkeyStore {
    var settings: Settings = .shared

    func load(_ id: String) -> HotkeyChoice { settings[.hotkey(id)] }

    func save(_ id: String, _ choice: HotkeyChoice) {
        if choice == .standard { settings.reset(.hotkey(id)) } else { settings[.hotkey(id)] = choice }
    }
}

/// In memory only (renders, gallery, tests).
final class MemoryHotkeyStore: HotkeyStore {
    var values: [String: HotkeyChoice] = [:]

    init(_ values: [String: HotkeyChoice] = [:]) { self.values = values }

    func load(_ id: String) -> HotkeyChoice { values[id] ?? .standard }
    func save(_ id: String, _ choice: HotkeyChoice) { values[id] = choice == .standard ? nil : choice }
}

@Observable final class HotkeyCenter {
    static let shared = HotkeyCenter(backend: CarbonHotkeyBackend(), store: SettingsHotkeyStore())

    /// All hotkeys in display order (order, then id).
    private(set) var definitions: [HotkeyDefinition] = []
    /// The person's choice per id (`.standard` when none).
    private(set) var choices: [String: HotkeyChoice] = [:]
    private(set) var status: [String: HotkeyStatus] = [:]
    /// Hotkeys whose keys are down right now (the onboarding step lights its key caps).
    private(set) var pressed: Set<String> = []
    /// How often each hotkey fired since launch (the onboarding step's "Works").
    private(set) var pressCount: [String: Int] = [:]
    /// Bumped when the keyboard layout changes: key caps read through the layout redraw.
    private(set) var layoutRevision = 0
    private(set) var isPaused = false
    private(set) var isStarted = false
    /// Standards that are no shortcut (a key without ⌃, ⌥ or ⌘ that is not an F-key): dropped at
    /// `register`, reported by the selftest.
    private(set) var droppedStandards: [String: KeyCombo] = [:]

    @ObservationIgnored let backend: HotkeyBackend
    @ObservationIgnored let store: HotkeyStore
    @ObservationIgnored var layout: KeyboardLayout = SystemKeyboardLayout.current
    @ObservationIgnored private var numbers: [String: UInt32] = [:]
    @ObservationIgnored private var nextNumber: UInt32 = 1
    /// What is registered with the backend right now.
    @ObservationIgnored private var registered: [String: KeyCombo] = [:]
    @ObservationIgnored private var layoutObserver: NSObjectProtocol?
    /// Recorders that paused the hotkeys (two windows may record at once).
    @ObservationIgnored private var pauses = 0
    /// Ends the observation of the store started by the previous `start`.
    @ObservationIgnored private var followGeneration = 0
    /// Called after every `register` (the module adds its settings pane with the first hotkey).
    @ObservationIgnored var onRegister: (() -> Void)?

    init(backend: HotkeyBackend, store: HotkeyStore) {
        self.backend = backend
        self.store = store
        backend.deliver = { [weak self] number, down in self?.fired(number, down: down) }
    }

    // MARK: Registering

    /// Adds a hotkey (or replaces one with the same id). `action` runs on every press, `onRelease`
    /// when the keys go up again (hold-to-talk and the like).
    func register(id: String, title: @escaping () -> String, subtitle: (() -> String)? = nil, default standard: KeyCombo?,
                  order: Int = 0, showInOnboarding: Bool = false, onRelease: (() -> Void)? = nil,
                  action: @escaping () -> Void) {
        var standard = standard
        droppedStandards[id] = nil
        if let combo = standard, !combo.isShortcut {
            // a plain key as a global hotkey could no longer be typed in any app
            Log.warn("hotkeys: \(id) standard \(layout.label(combo)) has no ⌃, ⌥ or ⌘ and is no F-key, dropped", "hotkeys")
            droppedStandards[id] = combo
            standard = nil
        }
        let definition = HotkeyDefinition(id: id, order: order, title: title, subtitle: subtitle, standard: standard,
                                          showInOnboarding: showInOnboarding, onPress: action, onRelease: onRelease)
        definitions.removeAll { $0.id == id }
        definitions.append(definition)
        definitions.sort { ($0.order, $0.id) < ($1.order, $1.id) }
        choices[id] = load(id)
        if numbers[id] == nil {
            numbers[id] = nextNumber
            nextNumber += 1
        }
        if let why = standardProblem(id) {
            Log.warn("hotkeys: \(id) standard: \(why)", "hotkeys")
        }
        apply()
        onRegister?()
    }

    func unregister(id: String) {
        definitions.removeAll { $0.id == id }
        choices[id] = nil
        droppedStandards[id] = nil
        apply()
        status[id] = nil
    }

    /// Why the rules would refuse a hotkey's standard if a person pressed it (the selftest reports
    /// it; a standard like ⌘Q would break Quit in every app). nil: fine or no standard.
    func standardProblem(_ id: String, layout: KeyboardLayout? = nil) -> String? {
        guard let standard = definition(id)?.standard else { return nil }
        let ctx = ShortcutRules.Context(layout: layout ?? self.layout, system: [], others: others(than: id, standardsOnly: true))
        if case .refuse(let why) = ShortcutRules.judge(standard, in: ctx) { return why }
        return nil
    }

    func definition(_ id: String) -> HotkeyDefinition? { definitions.first { $0.id == id } }

    /// The first hotkey marked for the onboarding step.
    var onboardingHotkey: HotkeyDefinition? { definitions.first(where: \.showInOnboarding) }

    // MARK: Choices

    func choice(_ id: String) -> HotkeyChoice { choices[id] ?? .standard }

    /// The combination in effect for `id` (the choice, else the standard), nil when none.
    func combo(_ id: String) -> KeyCombo? {
        choice(id).resolved(standard: definition(id)?.standard)
    }

    /// One line for menus and texts ("⌥⇧⌘K"), nil when the hotkey has no combination.
    func display(_ id: String) -> String? { combo(id).map { layout.label($0) } }

    /// Saves a choice and re-registers at once. A combination equal to the standard is stored as
    /// the standard (so a later change of the standard reaches the person).
    func set(_ id: String, _ choice: HotkeyChoice) {
        guard let definition = definition(id) else { return }
        if case .combo(let combo) = choice, !combo.isShortcut {
            Log.warn("hotkeys: \(id) \(layout.label(combo)) has no ⌃, ⌥ or ⌘ and is no F-key, not set", "hotkeys")
            return
        }
        var value = choice
        if case .combo(let combo) = choice, combo == definition.standard { value = .standard }
        choices[id] = value
        store.save(id, value)
        apply()
    }

    /// The other hotkeys' combinations, for the rule engine (display order).
    func others(than id: String, standardsOnly: Bool = false) -> [ShortcutRules.Other] {
        definitions.compactMap { d in
            guard d.id != id, let combo = standardsOnly ? d.standard : combo(d.id) else { return nil }
            return ShortcutRules.Other(id: d.id, title: d.title(), combo: combo)
        }
    }

    /// The stored choice, a combination that is no shortcut (a hand edit like `{"keyCode": 0}`,
    /// plain A) read as the standard.
    private func load(_ id: String) -> HotkeyChoice {
        let choice = store.load(id)
        if case .combo(let combo) = choice, !combo.isShortcut {
            Log.warn("hotkeys: stored \(id) \(layout.label(combo)) has no ⌃, ⌥ or ⌘ and is no F-key, using the standard", "hotkeys")
            return .standard
        }
        return choice
    }

    /// Reads every choice from the store again (settings.json changed underneath: "Reset all
    /// settings", a hand edit with `Settings.reload()`) and re-registers what changed.
    func reloadChoices() {
        var changed = false
        for d in definitions {
            let choice = load(d.id)
            if choices[d.id] != choice {
                choices[d.id] = choice
                changed = true
            }
        }
        if changed { apply() }
    }

    /// Follows the store while started: a store backed by `Settings` is observable, so a reset or
    /// reload reaches the registrations at once (an in-memory store never changes underneath).
    private func followStore() {
        followGeneration += 1
        let generation = followGeneration
        Observing.track { [weak self] in
            guard let self else { return }
            for d in self.definitions { _ = self.store.load(d.id) }
        } while: { [weak self] in
            self?.followGeneration == generation
        } onChange: { [weak self] in
            self?.reloadChoices()
        }
    }

    // MARK: Lifecycle

    /// Installs the event handler and registers everything. Does nothing in headless runs (tests,
    /// renders, `--selftest`): nothing reaches macOS there.
    func start() {
        guard !isStarted, !RenderMode.isHeadless, !RenderMode.isStatic else { return }
        startForTesting()
        layoutObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layoutRevision += 1 }
        }
    }

    /// `start()` without the headless guard and the layout observer (tests with a fake backend).
    func startForTesting() {
        isStarted = true
        backend.install()
        followStore()
        apply()
    }

    /// Unregisters everything (app quits).
    func stop() {
        isStarted = false
        followGeneration += 1
        apply()
        if let layoutObserver { DistributedNotificationCenter.default().removeObserver(layoutObserver) }
        layoutObserver = nil
    }

    /// While a shortcut is being recorded nothing may fire: the keys pressed there start nothing.
    /// Counted: every `pause(true)` needs its `pause(false)`, the hotkeys come back with the last.
    func pause(_ on: Bool) {
        pauses = max(0, pauses + (on ? 1 : -1))
        guard isPaused != (pauses > 0) else { return }
        isPaused = pauses > 0
        apply()
    }

    /// Asks macOS whether a combination is free (nil) without keeping it.
    func probe(_ combo: KeyCombo) -> Int32? { isStarted ? backend.probe(combo) : nil }

    // MARK: Registration with macOS

    /// What should be registered: every hotkey with a combination, a combination used twice only
    /// for the first hotkey (display order; the later one gets `.duplicate`). Pure (tests).
    static func plan(_ definitions: [HotkeyDefinition], choices: [String: HotkeyChoice]) -> [String: KeyCombo] {
        var want: [String: KeyCombo] = [:]
        var taken = Set<KeyCombo>()
        for d in definitions {
            guard let combo = (choices[d.id] ?? .standard).resolved(standard: d.standard) else { continue }
            guard taken.insert(combo).inserted else {
                Log.warn("hotkeys: \(d.id) has the same keys as an earlier hotkey, not registered twice", "hotkeys")
                continue
            }
            want[d.id] = combo
        }
        return want
    }

    /// Brings the backend in line with the definitions and choices.
    func apply() {
        let planned = Self.plan(definitions, choices: choices)
        let want = isStarted && !isPaused ? planned : [:]
        for (id, combo) in registered where want[id] != combo {
            // macOS sends a release only to the registration that got the press: a hotkey taken
            // away while held gets its release from here (a hold would never end otherwise)
            if pressed.remove(id) != nil { definition(id)?.onRelease?() }
            if let number = numbers[id] { backend.unregister(number: number) }
            registered[id] = nil
        }
        var next: [String: HotkeyStatus] = [:]
        for d in definitions {
            guard let wanted = planned[d.id] else {
                if let mine = self.combo(d.id) {
                    let owner = definitions.first { planned[$0.id] == mine }
                    next[d.id] = owner.map { .duplicate(of: $0.id) } ?? .inactive
                } else {
                    next[d.id] = .off
                }
                continue
            }
            guard want[d.id] != nil else {
                next[d.id] = .inactive
                continue
            }
            if registered[d.id] == wanted {
                next[d.id] = status[d.id] ?? .active
                continue
            }
            guard let number = numbers[d.id] else { continue }
            switch backend.register(wanted, number: number) {
            case .ok:
                registered[d.id] = wanted
                next[d.id] = .active
            case .heldElsewhere:
                // registered plainly: presses arrive once the other app lets go
                registered[d.id] = wanted
                next[d.id] = .heldElsewhere
                Log.info("hotkeys: \(d.id) \(layout.label(wanted)) is held exclusively by another app", "hotkeys")
            case .failed(let code):
                next[d.id] = .failed(code)
                Log.warn("hotkeys: \(d.id) \(layout.label(wanted)) refused by macOS (status \(code))", "hotkeys")
            }
        }
        if next != status { status = next }
    }

    private func fired(_ number: UInt32, down: Bool) {
        guard !isPaused, let id = numbers.first(where: { $0.value == number })?.key, registered[id] != nil,
              let definition = definition(id) else { return }
        if down {
            pressed.insert(id)
            pressCount[id, default: 0] += 1
            definition.onPress()
        } else if pressed.remove(id) != nil {
            definition.onRelease?()
        }
    }

    // MARK: Renders

    /// Renders and the gallery: shows a hotkey as pressed / tried without macOS.
    func previewPress(_ id: String, held: Bool = true) {
        if held { pressed.insert(id) } else { pressed.remove(id) }
        pressCount[id, default: 0] += 1
    }

    /// Renders and the gallery: a status as macOS would report it.
    func previewStatus(_ id: String, _ value: HotkeyStatus) { status[id] = value }
}
