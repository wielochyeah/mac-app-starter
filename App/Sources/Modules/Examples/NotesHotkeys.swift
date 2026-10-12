#if MODUL_HOTKEYS
import Carbon.HIToolbox

// Quick capture from any app (skill `kurzbefehl`): ⌃⌥N saves the copied text as a note. The
// standard passes the shortcut rules on US and German layouts (test), and the hotkey is the one
// the onboarding step shows.

enum NotesHotkeys {
    static let id = "notes.capture"
    /// ⌃⌥N: no app or system shortcut, types nothing with ⌃ held.
    static let standard = KeyCombo(keyCode: UInt16(kVK_ANSI_N), modifiers: [.control, .option])

    static func register() {
        HotkeyCenter.shared.register(id: id, title: { NotesText.hotkeyTitle }, subtitle: { NotesText.hotkeySubtitle },
                                     default: standard, showInOnboarding: true) {
            NotesCapture.captureClipboard()
        }
        OnboardingFeatures.items.append(OnboardingFeature(id: "notes.quick", order: 10, symbol: "doc.on.clipboard", tint: .yellow,
                                                          title: { NotesText.featureQuickTitle },
                                                          detail: { NotesText.featureQuickDetail(HotkeyCenter.shared.display(id)) }))
    }
}
#endif
