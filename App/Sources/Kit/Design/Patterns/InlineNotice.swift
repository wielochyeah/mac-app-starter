import SwiftUI

/// A banner inside a pane or step that explains a state and, if there is one, the way out
/// (VoiceBud OnboardingSpeedHint): radius 12, icon 15 semibold, optional 13 semibold title, 12
/// `prose` text, optional chip. Success, warning and error are tinted (fill 10 % / 16 %, 1 pt edge
/// at 35 %); info is neutral (an `fg2` symbol on a quiet fill, no edge), so it never reads like one
/// of them when the accent is red, green or orange. The chip sits on the right while the text
/// keeps at least `Metrics.noticeTextMin` beside it, else under the text; `actionBelow` puts it
/// there always (a 460 pt step card).
struct InlineNotice: View {
    enum Kind {
        case info, success, warning, error

        var symbol: String {
            switch self {
            case .info: "info.circle.fill"
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.octagon.fill"
            }
        }

        /// The tone of the symbol, fill and edge; nil for the neutral info notice.
        func color(_ t: Theme) -> Color? {
            switch self {
            case .info: nil
            case .success: t.ok
            case .warning: t.warn
            case .error: t.strike
            }
        }

        /// What VoiceOver says before the text.
        var spoken: String {
            switch self {
            case .info, .success: PatternsText.info
            case .warning: PatternsText.warning
            case .error: PatternsText.error
            }
        }
    }

    let text: String
    var title: String?
    var kind: Kind
    var actionTitle: String?
    var actionBelow: Bool
    var action: (() -> Void)?
    var perform: (String) -> Void
    @Environment(\.colorScheme) private var scheme

    /// `text` may contain `[label](app://action)` links, routed to `perform`.
    init(_ text: String, title: String? = nil, kind: Kind = .info, actionTitle: String? = nil, actionBelow: Bool = false,
         action: (() -> Void)? = nil, perform: @escaping (String) -> Void = { _ in }) {
        self.text = text
        self.title = title
        self.kind = kind
        self.actionTitle = actionTitle
        self.actionBelow = actionBelow
        self.action = action
        self.perform = perform
    }

    var body: some View {
        let t = Theme(scheme)
        let tone = kind.color(t)
        let shape = RoundedRectangle(cornerRadius: Radius.notice, style: .continuous)
        Group {
            if let actionTitle, let action, !actionBelow {
                // the chip beside the text while the text keeps a readable width, else below it
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Space.noticeGap) {
                        icon(t, tone)
                        message(t).frame(minWidth: Metrics.noticeTextMin, idealWidth: Metrics.noticeTextMin,
                                         maxWidth: .infinity, alignment: .leading)
                        Chip(actionTitle, action: action)
                    }
                    HStack(alignment: .top, spacing: Space.noticeGap) {
                        icon(t, tone)
                        VStack(alignment: .leading, spacing: 3) {
                            message(t)
                            Chip(actionTitle, action: action).padding(.top, Space.xxs)
                        }
                        Spacer(minLength: 0)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: Space.noticeGap) {
                    icon(t, tone)
                    VStack(alignment: .leading, spacing: 3) {
                        message(t)
                        if let actionTitle, let action { Chip(actionTitle, action: action).padding(.top, Space.xxs) }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, Space.noticeX)
        .padding(.vertical, Space.noticeY)
        .background(shape.fill(tone.map { t.noticeFill($0) } ?? t.noticeNeutralFill))
        .overlay {
            if let tone { shape.strokeBorder(t.noticeEdge(tone), lineWidth: 1) }
        }
        .accessibilityElement(children: .combine)
    }

    private func icon(_ t: Theme, _ tone: Color?) -> some View {
        Image(systemName: kind.symbol)
            .symbolFont(Metrics.noticeIcon, weight: .semibold)
            .foregroundStyle(tone ?? t.fg2)
            .frame(width: Metrics.noticeIconColumn)
            .padding(.top, 1)
            .accessibilityLabel(kind.spoken)
    }

    private func message(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let title {
                Text(title).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
            }
            OnboardingRichText(text, perform: perform)
                .font(TypeScale.secondary)
                .foregroundStyle(t.prose)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
