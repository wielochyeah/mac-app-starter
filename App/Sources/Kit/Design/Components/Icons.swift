import SwiftUI

/// The gradient squircle icon (VoiceBud HubSquircle): radius size * 0.28, vertical gradient from
/// the tint, white 22 % hairline, white glyph at half the size.
struct SquircleIcon: View {
    let symbol: String
    var tint: TintName = .accent
    var size: CGFloat = Metrics.squircle
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: Radius.squircle(size), style: .continuous)
        shape
            .fill(LinearGradient(colors: tint == .accent ? t.accentGradient : tint.colors, startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(t.squircleEdge, lineWidth: Metrics.hairline))
            .overlay {
                Image(systemName: symbol)
                    .font(TypeScale.squircleGlyph(size))
                    .foregroundStyle(t.squircleGlyph)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Step progress (VoiceBud OnboardingProgress): one 18 x 3 capsule per step, spacing 4, accent up
/// to and including the current step.
struct SegmentedProgress: View {
    let count: Int
    let current: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Metrics.progressSpacing) {
            ForEach(0..<max(count, 0), id: \.self) { i in
                Capsule()
                    .fill(i <= current ? t.accent : t.trackOff)
                    .frame(width: Metrics.progressSegment.width, height: Metrics.progressSegment.height)
            }
        }
        .animation(Motion.page, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CommonText.step(current + 1, of: count))
    }
}

/// A calm spinner: a 28 % accent arc on a track, one turn per 0.9 s. Static at 70° in renders.
struct Spinner: View {
    var size: CGFloat = Metrics.spinner
    @Environment(\.colorScheme) private var scheme
    @Environment(\.renderStatic) private var renderStatic

    var body: some View {
        if renderStatic {
            arc(angle: 70)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) / 0.9
                arc(angle: turn * 360)
            }
        }
    }

    private func arc(angle: Double) -> some View {
        let t = Theme(scheme)
        let line = max(Metrics.spinnerLine, size * Metrics.spinnerLineRatio)
        return ZStack {
            Circle().stroke(t.trackOff, lineWidth: line)
            Circle().trim(from: 0, to: 0.28)
                .stroke(t.accent, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(angle - 90))   // the arc starts at 12 o'clock
        }
        .frame(width: size, height: size)
        .accessibilityLabel(CommonText.loading)
    }
}

/// A centred empty state: symbol, title, one calm sentence, optional action.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.colorScheme) private var scheme

    init(symbol: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: Space.s) {
            Image(systemName: symbol)
                .symbolFont(Metrics.emptyStateSymbol, weight: .light)
                .foregroundStyle(t.fg3)
                .padding(.bottom, Space.xxs)
            Text(title).font(TypeScale.headline).foregroundStyle(t.fg)
            Text(message)
                .font(TypeScale.body)
                .foregroundStyle(t.prose)
                .multilineTextAlignment(.center)
                .lineSpacing(TypeScale.proseLineSpacing)
                .frame(maxWidth: Metrics.onboardingNarrow)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.secondary).padding(.top, Space.xxs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Glass for custom surfaces: the system's Liquid Glass on screen, a token-coloured stand-in in
/// static renders (glass never draws offscreen, and tinted glass blanks the whole capture).
struct GlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = Radius.card
    let content: Content
    @Environment(\.colorScheme) private var scheme
    @Environment(\.renderStatic) private var renderStatic

    init(cornerRadius: CGFloat = Radius.card, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if renderStatic || RenderMode.isStatic {
            content
                .background(shape.fill(t.glassStandIn))
                .overlay(shape.strokeBorder(t.glassStroke, lineWidth: Metrics.hairline))
                .shadow(color: t.panelShadow, radius: 6, y: 1)
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}
