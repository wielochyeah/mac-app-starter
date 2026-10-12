import SwiftUI

/// The accent switch (VoiceBud HubSwitch): capsule 36 x 21, white knob 17, springs over with a
/// slight overshoot. Drawn in SwiftUI, so it also shows in offscreen renders.
struct SwitchToggle: View {
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        let t = Theme(scheme)
        Button {
            withAnimation(Motion.adaptive(Motion.toggle, reduce: reduceMotion)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? t.accent : t.switchOff)
                .frame(width: Metrics.switchSize.width, height: Metrics.switchSize.height)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(t.knob)
                        .shadow(color: t.knobShadow, radius: 1.5, y: 1)
                        .frame(width: Metrics.switchKnob, height: Metrics.switchKnob)
                        .padding(Space.hair)
                }
                .contentShape(Capsule())
                .opacity(enabled ? 1 : Metrics.disabledOpacity)
        }
        .buttonStyle(PlainStyle())
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? CommonText.on : CommonText.off)
    }
}

/// A small segmented control (VoiceBud HubSegmented): 12 pt, selected segment white with a soft
/// shadow on a quiet track. Each option is (value, title).
struct Segmented<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    @Environment(\.colorScheme) private var scheme

    init(_ options: [(value: Value, title: String)], selection: Binding<Value>) {
        self.options = options
        _selection = selection
    }

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.hair) {
            ForEach(options, id: \.value) { option in
                let on = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.title)
                        .font(on ? TypeScale.secondarySemibold : TypeScale.secondary)
                        .foregroundStyle(on ? t.fg : t.fg2)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: Metrics.segmentHeight)
                        .background(RoundedRectangle(cornerRadius: Radius.segment, style: .continuous)
                            .fill(on ? t.segmentSelected : .clear)
                            .shadow(color: on ? t.segmentShadow : .clear, radius: 1, y: 0.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(Space.hair)
        .background(RoundedRectangle(cornerRadius: Radius.segmentTrack, style: .continuous).fill(t.segmentTrack))
        .fixedSize()
    }
}

/// A small action pill (VoiceBud HubChip): height 24, radius 7, 11.5 medium, optional symbol.
/// Dims like every kit control when disabled (`.disabled(true)`).
struct Chip: View {
    let title: String
    var symbol: String?
    var active = false
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled

    init(_ title: String, symbol: String? = nil, active: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.active = active
        self.action = action
    }

    var body: some View {
        let t = Theme(scheme)
        Button(action: action) {
            HStack(spacing: Space.xxs) {
                if let symbol { Image(systemName: symbol).font(TypeScale.micro) }
                Text(title).lineLimit(1)
            }
            .font(TypeScale.subtitleMedium)
            .foregroundStyle(t.fg)
            .padding(.horizontal, 9)
            .frame(height: Metrics.chipHeight)
            .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).fill(active ? t.chipActive : t.chip))
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : Metrics.disabledOpacity)
        }
        .buttonStyle(PressStyle())
    }
}

/// A tiny label pill ("Recommended", "New", "Beta"): 10.5 semibold, height 16. Text is >= 4.5:1
/// on its own tint over window and card in both schemes (DesignTests).
struct Badge: View {
    enum Tone { case accent, ok, warn, neutral }
    let text: String
    var tone: Tone = .accent
    @Environment(\.colorScheme) private var scheme

    init(_ text: String, tone: Tone = .accent) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        let t = Theme(scheme)
        let (fg, bg): (Color, Color) = switch tone {
        case .accent: (t.accentText, t.accentSoft)
        case .ok: (t.okText, t.okSoft)
        case .warn: (t.warnText, t.warnSoft)
        case .neutral: (t.fg, t.chip)
        }
        Text(text)
            .font(TypeScale.badge)
            .foregroundStyle(fg)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(height: Metrics.badgeHeight)
            .background(Capsule().fill(bg))
    }
}

/// Key caps for shortcuts (VoiceBud HubKeyCaps). Modifier glyphs ⌃⇧⌥⌘ are drawn as SF Symbols
/// because the ⌃ character sits higher than ⇧ in the system font.
struct KeyCaps: View {
    let keys: [String]
    @Environment(\.colorScheme) private var scheme

    init(_ keys: [String]) { self.keys = keys }

    static let symbolFor: [String: String] = ["⌃": "control", "⇧": "shift", "⌥": "option", "⌘": "command",
                                               "↩": "return", "⌫": "delete.left", "⇥": "arrow.right.to.line"]

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.xxs) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Group {
                    if let symbol = Self.symbolFor[key] {
                        Image(systemName: symbol).font(TypeScale.secondaryMedium)
                    } else {
                        Text(key).font(TypeScale.secondaryMedium)
                    }
                }
                .foregroundStyle(t.fg)
                .frame(minWidth: Metrics.keyCap, minHeight: Metrics.keyCap)
                .padding(.horizontal, key.count > 1 && Self.symbolFor[key] == nil ? Space.xxs : 0)
                .background(RoundedRectangle(cornerRadius: Radius.keyCap, style: .continuous).fill(t.capsuleBg))
                .overlay(RoundedRectangle(cornerRadius: Radius.keyCap, style: .continuous).strokeBorder(t.capsuleStroke, lineWidth: Metrics.hairline))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys.joined(separator: " "))
    }
}

/// A status word with a mark (VoiceBud OnboardingStatus): granted, missing, idle, busy, error.
struct StatusMark: View {
    enum Kind { case ok, warn, idle, busy, error }
    let kind: Kind
    let text: String
    /// The onboarding status slot's size (VoiceBud `large`): 15 pt check, 13 pt text, 7 pt gap.
    var large = false
    @Environment(\.colorScheme) private var scheme

    init(_ kind: Kind, _ text: String, large: Bool = false) {
        self.kind = kind
        self.text = text
        self.large = large
    }

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: large ? 7 : 6) {
            Group {
                switch kind {
                case .ok:
                    Image(systemName: "checkmark.circle.fill")
                        .symbolFont(large ? Metrics.statusMarkLarge : 13, weight: .semibold)
                        .foregroundStyle(t.ok)
                case .warn: Circle().fill(t.warn).frame(width: 8, height: 8)
                case .idle: Circle().fill(t.idle).frame(width: Metrics.dot, height: Metrics.dot)
                case .busy: Spinner(size: 12)
                case .error:
                    Image(systemName: "exclamationmark.circle.fill")
                        .symbolFont(large ? Metrics.statusMarkLarge : 13, weight: .semibold)
                        .foregroundStyle(t.strike)
                }
            }
            // a fixed slot lines texts up in lists; the large (slot) form sits inline like VoiceBud's
            .frame(width: large ? nil : Metrics.spinner, height: Metrics.spinner)
            // VoiceBud: settled states (ok, warn) medium in fg, waiting states regular in prose
            let quiet = kind == .idle || kind == .busy
            Text(text)
                .font(large ? (quiet ? TypeScale.body : TypeScale.bodyMedium) : (quiet ? TypeScale.secondary : TypeScale.secondaryMedium))
                .foregroundStyle(kind == .error ? t.strikeText : quiet ? t.prose : t.fg)
        }
    }
}
