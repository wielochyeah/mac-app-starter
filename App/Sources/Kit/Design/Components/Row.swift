import SwiftUI

/// Where small text sits: the settings hub (11.5 pt `fg2`, VoiceBud HubRow/HubFootnote) or the
/// onboarding window (12 pt `prose`, VoiceBud OnboardingRow/OnboardingFootnote).
enum TextTone {
    case settings, onboarding

    var small: Font { self == .settings ? TypeScale.subtitle : TypeScale.secondary }
    func smallColor(_ t: Theme) -> Color { self == .settings ? t.fg2 : t.prose }
}

/// A settings row (VoiceBud HubRow): min height 44, title 13 `fg`, optional subtitle (11.5 `fg2`;
/// 12 `prose` with `tone: .onboarding`), optional leading squircle icon or status dot, trailing control.
struct Row<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: TintName = .accent
    var dot: Color?
    /// A subtitle that must be seen (a refused shortcut, an error): pass `Theme(scheme).strikeText`.
    var subtitleColor: Color?
    var tone: TextTone = .settings
    let trailing: Trailing
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled

    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent,
         dot: Color? = nil, subtitleColor: Color? = nil, tone: TextTone = .settings, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.dot = dot
        self.subtitleColor = subtitleColor
        self.tone = tone
        self.trailing = trailing()
    }

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.s) {
            // a disabled row dims its label like the control dims itself, so the row reads as off
            HStack(spacing: Space.s) {
                if let dot { Circle().fill(dot).frame(width: Metrics.dot, height: Metrics.dot) }
                if let symbol { SquircleIcon(symbol: symbol, tint: tint, size: 24) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(TypeScale.body).foregroundStyle(t.fg)
                    if let subtitle {
                        Text(subtitle)
                            .font(tone.small)
                            .foregroundStyle(subtitleColor ?? tone.smallColor(t))
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, dot == nil ? 0 : -3)
            }
            .opacity(enabled ? 1 : Metrics.disabledOpacity)
            Spacer(minLength: Space.s)
            trailing
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, subtitle == nil ? 0 : Space.rowY)
        .frame(minHeight: Metrics.rowMinHeight)
    }
}

extension Row where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, dot: Color? = nil,
         tone: TextTone = .settings) {
        self.init(title, subtitle: subtitle, symbol: symbol, tint: tint, dot: dot, tone: tone) { EmptyView() }
    }
}

/// The header band of a settings pane (VoiceBud HubPaneHeader): squircle 22 + title 15.5 bold,
/// trailing slot (search field), height 52, padding 20, hairline below, opaque and above the
/// scrolling content.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var symbol: String?
    var tint: TintName = .accent
    let trailing: Trailing
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, symbol: String? = nil, tint: TintName = .accent, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.trailing = trailing()
    }

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.iconGap) {
            if let symbol { SquircleIcon(symbol: symbol, tint: tint) }
            Text(title).font(TypeScale.paneTitle).foregroundStyle(t.fg)
            Spacer(minLength: Space.s)
            trailing
        }
        .padding(.horizontal, Space.pane)
        .frame(height: Metrics.paneHeader)
        .background(t.windowBg)
        .overlay(alignment: .bottom) { Rectangle().fill(t.separator).frame(height: Metrics.hairline) }
        .zIndex(1)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, symbol: String? = nil, tint: TintName = .accent) {
        self.init(title, symbol: symbol, tint: tint) { EmptyView() }
    }
}
