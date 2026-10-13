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

/// Small print under a card (11.5 `fg2`; 12 `prose` with `tone: .onboarding`). When the text
/// changes with a choice, `reserve` lists every text it can show: the footnote keeps the height of
/// the tallest in the current language and width, so swapping texts never moves the layout and no
/// empty line is left. `lines` reserves a fixed number of lines instead.
struct Footnote: View {
    let text: String
    var lines: Int = 0
    var reserve: [String] = []
    var tone: TextTone = .settings
    @Environment(\.colorScheme) private var scheme

    init(_ text: String, lines: Int = 0, reserve: [String] = [], tone: TextTone = .settings) {
        self.text = text
        self.lines = lines
        self.reserve = reserve
        self.tone = tone
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(reserve.enumerated()), id: \.offset) { _, other in
                styled(other).hidden().accessibilityHidden(true)
            }
            styled(text)
        }
        .frame(maxWidth: .infinity, minHeight: lines > 0 ? CGFloat(lines) * 16 : nil, alignment: .topLeading)
        .padding(.horizontal, 6)
        .padding(.top, Space.xs)
    }

    private func styled(_ text: String) -> some View {
        Text(text)
            .font(tone.small)
            .foregroundStyle(tone.smallColor(Theme(scheme)))
            .lineSpacing(tone == .settings ? TypeScale.footnoteLineSpacing : TypeScale.noteLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
