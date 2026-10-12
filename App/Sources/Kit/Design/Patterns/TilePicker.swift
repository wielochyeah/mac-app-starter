import SwiftUI

/// One choice of a `TilePicker`: value, title under the preview, optional detail line and badge
/// ("Recommended").
struct TileOption<Value: Hashable> {
    let value: Value
    let title: String
    var detail: String?
    var badge: String?

    init(_ value: Value, title: String, detail: String? = nil, badge: String? = nil) {
        self.value = value
        self.title = title
        self.detail = detail
        self.badge = badge
    }
}

/// Tiles with live previews and one selection ring that springs to the chosen tile (VoiceBud
/// OnboardingTilePicker / HubTilePicker): previews radius 11 with a 1 pt `tileEdge`, the ring
/// radius 15, 2.5 pt `ring`, 4 pt outside, `Motion.tile`. ←/→ move the selection when the picker
/// has keyboard focus. `tone: .onboarding` (title 12 `prose`, 12 pt inset) for setup steps,
/// `.settings` (title 12.5 `fg2`, card insets 12 / 13 / 11) inside a settings `Card`.
///
///     TilePicker([TileOption(.island, title: …), TileOption(.capsule, title: …)], selection: $style) { style in
///         StylePreview(style)
///     }
struct TilePicker<Value: Hashable, Preview: View>: View {
    let options: [TileOption<Value>]
    @Binding var selection: Value
    var previewHeight: CGFloat
    var tone: TextTone
    let preview: (Value) -> Preview
    @Namespace private var ns
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ options: [TileOption<Value>], selection: Binding<Value>, previewHeight: CGFloat = Metrics.tilePreview,
         tone: TextTone = .onboarding, @ViewBuilder preview: @escaping (Value) -> Preview) {
        self.options = options
        _selection = selection
        self.previewHeight = previewHeight
        self.tone = tone
        self.preview = preview
    }

    /// The value `offset` tiles away from `current`, clamped at the ends (pure; PatternsTests).
    static func step(from current: Value, by offset: Int, in values: [Value]) -> Value {
        guard let i = values.firstIndex(of: current) else { return values.first ?? current }
        return values[min(max(i + offset, 0), values.count - 1)]
    }

    var body: some View {
        let t = Theme(scheme)
        HStack(alignment: .top, spacing: Space.s) {
            ForEach(options, id: \.value) { option in
                tile(option, t: t)
            }
        }
        .overlay {
            // one ring for the whole picker, drawn above the tiles; it springs to the matched source
            RoundedRectangle(cornerRadius: Radius.ring, style: .continuous)
                .strokeBorder(t.ring, lineWidth: Metrics.tileRingLine)
                .padding(-Metrics.tileRingOutset)
                .matchedGeometryEffect(id: selection, in: ns, isSource: false)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, Space.s)
        .padding(.top, tone == .settings ? Space.tileTop : Space.s)
        .padding(.bottom, tone == .settings ? Space.tileBottom : Space.s)
        .focusable()
        .onKeyPress(.leftArrow) { move(-1) }
        .onKeyPress(.rightArrow) { move(1) }
        .accessibilityElement(children: .contain)
    }

    private func move(_ offset: Int) -> KeyPress.Result {
        let next = Self.step(from: selection, by: offset, in: options.map(\.value))
        guard next != selection else { return .ignored }
        select(next)
        return .handled
    }

    private func select(_ value: Value) {
        withAnimation(Motion.adaptive(Motion.tile, reduce: reduceMotion)) { selection = value }
    }

    private func tile(_ option: TileOption<Value>, t: Theme) -> some View {
        let selected = option.value == selection
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        let onboarding = tone == .onboarding
        return Button { select(option.value) } label: {
            VStack(spacing: 0) {
                preview(option.value)
                    .frame(maxWidth: .infinity)
                    .frame(height: previewHeight)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(t.tileEdge, lineWidth: 1))
                    .matchedGeometryEffect(id: option.value, in: ns, isSource: true)
                HStack(spacing: 6) {
                    Text(option.title)
                        .font(onboarding ? (selected ? TypeScale.secondarySemibold : TypeScale.secondary)
                                         : (selected ? TypeScale.tileTitleSelected : TypeScale.tileTitle))
                        .foregroundStyle(selected ? t.fg : (onboarding ? t.prose : t.fg2))
                        .lineLimit(1)
                    if let badge = option.badge { Badge(badge) }
                }
                .padding(.top, onboarding ? Space.xs : Space.tileTitleGap)
                if let detail = option.detail {
                    Text(detail)
                        .font(tone.small)
                        .foregroundStyle(tone.smallColor(t))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.hair)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The onboarding name for `TilePicker` (same view; `tone` defaults to `.onboarding`).
typealias OnboardingTilePicker<Value: Hashable, Preview: View> = TilePicker<Value, Preview>
