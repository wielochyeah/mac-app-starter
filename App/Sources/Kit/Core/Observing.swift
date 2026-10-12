import Observation

/// Calls `onChange` every time a value read in `track` changes (Observation outside SwiftUI),
/// e.g. to re-title AppKit menus when the language switches:
///
///     Observing.track { _ = Localizer.shared.lang } onChange: { rebuildMenu() }
///
/// `onChange` runs on the main actor after the change. Tracking lasts for the process lifetime.
enum Observing {
    static func track(_ track: @escaping @MainActor () -> Void, onChange: @escaping @MainActor () -> Void) {
        withObservationTracking {
            track()
        } onChange: {
            Task { @MainActor in
                onChange()
                Observing.track(track, onChange: onChange)
            }
        }
    }
}
