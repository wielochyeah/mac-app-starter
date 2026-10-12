import SwiftUI

/// What a permission step's 30 pt slot shows (VoiceBud OnboardingPermissionStep.slot). Each state
/// has a factory with the kit's default words; pass your own text where the step needs it.
struct OnboardingSlotState {
    enum Kind: String { case action, waiting, denied, granted, restartNeeded }

    struct SlotButton {
        let title: String
        let action: () -> Void
    }

    let kind: Kind
    let text: String
    /// The primary button (`action`, `restartNeeded`) or the secondary one (`waiting`, `denied`).
    let button: SlotButton?
    /// `denied`: help shown as a link instead of a button (`[title](app://action)` style), optional.
    let helpLink: SlotButton?

    /// Changes whenever the visible slot changes; drives the cross-fade (and `OnboardingHint(key:)`).
    var key: String { "\(kind.rawValue)|\(text)|\(button?.title ?? "")|\(helpLink?.title ?? "")" }

    /// A primary button ("Allow Access"). Return triggers it.
    static func action(_ title: String = PatternsText.allowAccess, perform: @escaping () -> Void) -> Self {
        Self(kind: .action, text: "", button: SlotButton(title: title, action: perform), helpLink: nil)
    }

    /// Spinner + "Waiting for your answer", optionally with a secondary button ("Open System Settings").
    static func waiting(_ text: String = PatternsText.waitingForAnswer, button: SlotButton? = nil) -> Self {
        Self(kind: .waiting, text: text, button: button, helpLink: nil)
    }

    /// Orange dot + "Not allowed" and a way out: a secondary button and/or a help link.
    static func denied(_ text: String = PatternsText.denied, button: SlotButton? = nil, helpLink: SlotButton? = nil) -> Self {
        Self(kind: .denied, text: text, button: button, helpLink: helpLink)
    }

    /// Green check + "Allowed".
    static func granted(_ text: String = PatternsText.granted) -> Self {
        Self(kind: .granted, text: text, button: nil, helpLink: nil)
    }

    /// Orange dot + "Takes effect after a restart" + primary "Restart <App>".
    static func restartNeeded(_ text: String = PatternsText.afterRestart, buttonTitle: String = PatternsText.restartApp,
                              restart: @escaping () -> Void) -> Self {
        Self(kind: .restartNeeded, text: text, button: SlotButton(title: buttonTitle, action: restart), helpLink: nil)
    }

}

extension OnboardingSlotState.SlotButton {
    /// The usual secondary button of `waiting` / `denied`: "Open System Settings".
    static func openSettings(_ open: @escaping () -> Void) -> Self {
        Self(title: PatternsText.openSystemSettings, action: open)
    }
}

/// The fixed 30 pt slot of a permission step: one state at a time, swapped in place with a fade
/// and a slight scale (VoiceBud stateKey transition), so nothing below it moves.
///
///     OnboardingStatusSlot(grant == .granted ? .granted() : .action { request() })
///     OnboardingStatusSlot(.denied(button: .openSettings { monitor.openSettings(kind) }))
///     OnboardingHint(hintLines, key: slot.key).padding(.top, Space.s)
struct OnboardingStatusSlot: View {
    let state: OnboardingSlotState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ state: OnboardingSlotState) { self.state = state }

    var body: some View {
        ZStack {
            content
                .id(state.key)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: Motion.stateScale)))
        }
        .frame(height: Metrics.statusSlotHeight)
        .animation(Motion.adaptive(Motion.page, reduce: reduceMotion), value: state.key)
    }

    @ViewBuilder private var content: some View {
        HStack(spacing: Space.s) {
            switch state.kind {
            case .action:
                primary
            case .waiting:
                StatusMark(.busy, state.text, large: true)
                secondary
            case .denied:
                StatusMark(.warn, state.text, large: true)
                secondary
                if let link = state.helpLink {
                    OnboardingRichText(RichTextLinks.markdown(title: link.title, action: "help")) { _ in link.action() }
                        .font(TypeScale.bodyMedium)
                }
            case .granted:
                StatusMark(.ok, state.text, large: true)
            case .restartNeeded:
                StatusMark(.warn, state.text, large: true)
                primary
            }
        }
        .fixedSize()
    }

    @ViewBuilder private var primary: some View {
        if let button = state.button {
            Button(button.title, action: button.action)
                .buttonStyle(.primary(minWidth: Metrics.slotButtonMinWidth))
                .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder private var secondary: some View {
        if let button = state.button {
            Button(button.title, action: button.action)
                .buttonStyle(.secondary(minWidth: Metrics.slotButtonMinWidth))
        }
    }
}
