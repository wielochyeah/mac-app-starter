import AppKit
import Carbon.HIToolbox

// Hotkeys registered with macOS through Carbon (`RegisterEventHotKey`), as VoiceBud does
// (ui/Hotkeys.swift). Needs no permission, and the keys never reach the app in front. Presses and
// releases arrive on the application event target and are handed to the `HotkeyCenter`.

/// "STHK": marks this app's hotkey ids in Carbon events.
private nonisolated let hotkeySignature: OSType = 0x5354_484B
/// The id `probe` registers under for a moment.
private nonisolated let probeNumber: UInt32 = 0xFFFF

/// The Carbon event handler: a plain C function, no captures. Carbon calls it on the main thread;
/// it hops to the main actor explicitly anyway.
private nonisolated func carbonHotkeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ data: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let got = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard got == noErr, id.signature == hotkeySignature, id.id != probeNumber else { return OSStatus(eventNotHandledErr) }
    let down = GetEventKind(event) == UInt32(kEventHotKeyPressed)
    let number = id.id
    DispatchQueue.main.async {
        MainActor.assumeIsolated { CarbonHotkeyBackend.active?.deliver?(number, down) }
    }
    return noErr
}

final class CarbonHotkeyBackend: HotkeyBackend {
    /// The backend that receives events (one per process; the handler is installed once).
    fileprivate static weak var active: CarbonHotkeyBackend?

    var deliver: ((UInt32, Bool) -> Void)?
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var installed = false

    func install() {
        Self.active = self
        guard !installed else { return }
        installed = true
        var specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let status = InstallEventHandler(GetApplicationEventTarget(), carbonHotkeyHandler, specs.count, &specs, nil, nil)
        if status != noErr { Log.error("hotkeys: InstallEventHandler failed (\(public: status))", "hotkeys") }
    }

    /// Exclusive first: another app on the same keys stays silent while this app holds them,
    /// instead of both acting. A plain hotkey never fails, so only the exclusive call can tell that
    /// someone else got there first; it is then registered plainly and gets presses once the
    /// other app lets go.
    func register(_ combo: KeyCombo, number: UInt32) -> HotkeyRegistration {
        unregister(number: number)
        let id = EventHotKeyID(signature: hotkeySignature, id: number)
        var ref: EventHotKeyRef?
        var status = RegisterEventHotKey(UInt32(combo.keyCode), combo.modifiers.rawValue, id, GetApplicationEventTarget(),
                                         OptionBits(kEventHotKeyExclusive), &ref)
        if status == noErr, let ref {
            refs[number] = ref
            return .ok
        }
        guard status == OSStatus(eventHotKeyExistsErr) else { return .failed(status) }
        status = RegisterEventHotKey(UInt32(combo.keyCode), combo.modifiers.rawValue, id, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return .failed(status) }
        refs[number] = ref
        return .heldElsewhere
    }

    func unregister(number: UInt32) {
        if let ref = refs.removeValue(forKey: number) { UnregisterEventHotKey(ref) }
    }

    func probe(_ combo: KeyCombo) -> Int32? {
        let id = EventHotKeyID(signature: hotkeySignature, id: probeNumber)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.modifiers.rawValue, id, GetApplicationEventTarget(),
                                         OptionBits(kEventHotKeyExclusive), &ref)
        if let ref { UnregisterEventHotKey(ref) }
        return status == noErr ? nil : status
    }
}

/// A backend that only remembers (tests, renders, gallery). `taken` combinations behave as held
/// by another app, `refused` ones as refused by macOS with that status.
final class FakeHotkeyBackend: HotkeyBackend {
    var deliver: ((UInt32, Bool) -> Void)?
    var taken: Set<KeyCombo> = []
    var refused: [KeyCombo: Int32] = [:]
    private(set) var registered: [UInt32: KeyCombo] = [:]
    private(set) var installed = false

    func install() { installed = true }

    func register(_ combo: KeyCombo, number: UInt32) -> HotkeyRegistration {
        if let code = refused[combo] { return .failed(code) }
        registered[number] = combo
        return taken.contains(combo) ? .heldElsewhere : .ok
    }

    func unregister(number: UInt32) { registered[number] = nil }

    func probe(_ combo: KeyCombo) -> Int32? {
        if let code = refused[combo] { return code }
        return taken.contains(combo) ? Int32(eventHotKeyExistsErr) : nil
    }

    /// Simulates a press or release of whatever is registered under `combo`.
    func press(_ combo: KeyCombo, down: Bool = true) {
        guard let number = registered.first(where: { $0.value == combo })?.key else { return }
        deliver?(number, down)
    }
}
