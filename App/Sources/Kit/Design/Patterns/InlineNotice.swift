import SwiftUI

/// A banner inside a pane or step that explains a state and, if there is one, the way out
/// (VoiceBud OnboardingSpeedHint): tinted fill (10 % / 16 %) with a 1 pt edge (35 %), radius 12,
/// icon 15 semibold, optional 13 semibold title, 12 `prose` text, optional chip: on the right, or
/// under the text with `actionBelow` where the column is narrow (a 460 pt step card), so the text
/// keeps its width.
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

        func color(_ t: Theme) -> Color {
            switch self {
            case .info: t.accent
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
        HStack(alignment: .top, spacing: Space.noticeGap) {
            Image(systemName: kind.symbol)
                .symbolFont(Metrics.noticeIcon, weight: .semibold)
                .foregroundStyle(tone)
                .frame(width: Metrics.noticeIconColumn)
                .padding(.top, 1)
                .accessibilityLabel(kind.spoken)
            VStack(alignment: .leading, spacing: 3) {
                if let title {
                    Text(title).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
                }
                OnboardingRichText(text, perform: perform)
                    .font(TypeScale.secondary)
                    .foregroundStyle(t.prose)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                if actionBelow, let actionTitle, let action {
                    Chip(actionTitle, action: action).padding(.top, Space.xxs)
                }
            }
            Spacer(minLength: 0)
            if !actionBelow, let actionTitle, let action {
                Chip(actionTitle, action: action)
            }
        }
        .padding(.horizontal, Space.noticeX)
        .padding(.vertical, Space.noticeY)
        .background(shape.fill(t.noticeFill(tone)))
        .overlay(shape.strokeBorder(t.noticeEdge(tone), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
