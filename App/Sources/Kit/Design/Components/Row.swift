import SwiftUI

/// A settings row (VoiceBud HubRow): min height 44, title 13 `fg`, optional subtitle 11.5 `fg2`,
/// optional leading squircle icon or status dot, trailing control.
struct Row<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: TintName = .accent
    var dot: Color?
    /// A subtitle that must be seen (a refused shortcut, an error): pass `Theme(scheme).strike`.
    var subtitleColor: Color?
    let trailing: Trailing
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent,
         dot: Color? = nil, subtitleColor: Color? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.dot = dot
        self.subtitleColor = subtitleColor
        self.trailing = trailing()
    }

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.s) {
            if let dot { Circle().fill(dot).frame(width: Metrics.dot, height: Metrics.dot) }
            if let symbol { SquircleIcon(symbol: symbol, tint: tint, size: 24) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(TypeScale.body).foregroundStyle(t.fg)
                if let subtitle {
                    Text(subtitle)
                        .font(TypeScale.subtitle)
                        .foregroundStyle(subtitleColor ?? t.fg2)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, dot == nil ? 0 : -3)
            Spacer(minLength: Space.s)
            trailing
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, subtitle == nil ? 0 : Space.rowY)
        .frame(minHeight: Metrics.rowMinHeight)
    }
}

extension Row where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, dot: Color? = nil) {
        self.init(title, subtitle: subtitle, symbol: symbol, tint: tint, dot: dot) { EmptyView() }
    }
}

/// The header band of a settings pane (VoiceBud HubPaneHeader): squircle 22 + title 15.5 bold,
/// trailing slot (search field), height 52, padding 20, hairline below.
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
        HStack(spacing: Space.s - 2) {
            if let symbol { SquircleIcon(symbol: symbol, tint: tint) }
            Text(title).font(TypeScale.paneTitle).foregroundStyle(t.fg)
            Spacer(minLength: Space.s)
            trailing
        }
        .padding(.horizontal, Space.pane)
        .frame(height: Metrics.paneHeader)
        .overlay(alignment: .bottom) { Rectangle().fill(t.separator).frame(height: Metrics.hairline) }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, symbol: String? = nil, tint: TintName = .accent) {
        self.init(title, symbol: symbol, tint: tint) { EmptyView() }
    }
}
