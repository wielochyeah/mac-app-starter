import Observation

/// Calls `onChange` every time a value read in `track` changes (Observation outside SwiftUI),
/// e.g. to re-title AppKit menus when the language switches:
///
///     Observing.track { _ = Localizer.shared.lang } onChange: { rebuildMenu() }
///
/// `onChange` runs on the main actor after the change. Tracking lasts as long as `while` returns
/// true (default: the process lifetime); once it returns false the closures are released at the
/// next change. Anything tied to an object should stop with it:
///
///     Observing.track { _ = title() } while: { [weak window] in window != nil } onChange: { … }
enum Observing {
    static func track(_ track: @escaping @MainActor () -> Void,
                      while isActive: @escaping @MainActor () -> Bool = { true },
                      onChange: @escaping @MainActor () -> Void) {
        guard isActive() else { return }
        withObservationTracking {
            track()
        } onChange: {
            Task { @MainActor in
                guard isActive() else { return }
                onChange()
                Observing.track(track, while: isActive, onChange: onChange)
            }
        }
    }
}
