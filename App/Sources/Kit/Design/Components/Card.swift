import SwiftUI

/// A settings card: rows stacked without spacing, radius 13, `card` fill, hairline `cardStroke`.
/// Put `Separator()` between rows.
struct Card<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        VStack(spacing: 0) { content }
            .background(shape.fill(t.card))
            .clipShape(shape)
            .overlay(shape.strokeBorder(t.cardStroke, lineWidth: Metrics.hairline))
    }
}

/// A 0.5 pt hairline in `separator`, full width like VoiceBud's cards (`inset` indents it).
struct Separator: View {
    var inset: CGFloat = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(Theme(scheme).separator)
            .frame(height: Metrics.hairline)
            .padding(.leading, inset)
    }
}

/// The label above a card ("Language", "Behavior"): 12.5 semibold `fg2`.
struct GroupLabel: View {
    let text: String
    var top: CGFloat = 0
    @Environment(\.colorScheme) private var scheme

    init(_ text: String, top: CGFloat = 0) {
        self.text = text
        self.top = top
    }

    var body: some View {
        Text(text)
            .font(TypeScale.groupLabel)
            .foregroundStyle(Theme(scheme).fg2)
            .padding(.leading, 6)
            .padding(.bottom, 7)
            .padding(.top, top)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Small print under a card. `lines` reserves height so swapping texts never moves the layout.
struct Footnote: View {
    let text: String
    var lines: Int = 0
    @Environment(\.colorScheme) private var scheme

    init(_ text: String, lines: Int = 0) {
        self.text = text
        self.lines = lines
    }

    var body: some View {
        Text(text)
            .font(TypeScale.subtitle)
            .foregroundStyle(Theme(scheme).fg2)
            .lineSpacing(TypeScale.footnoteLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: lines > 0 ? CGFloat(lines) * 16 : nil, alignment: .topLeading)
            .padding(.horizontal, 6)
            .padding(.top, Space.xs)
    }
}
