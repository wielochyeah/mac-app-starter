import SwiftUI

/// A round button over artwork (tile hover, hero): symbol plus an accessibility label.
struct ArtworkAction {
    let symbol: String
    let label: String
    let perform: () -> Void

    init(symbol: String, label: String, perform: @escaping () -> Void) {
        self.symbol = symbol
        self.label = label
        self.perform = perform
    }
}

/// A square of artwork with a title and a subtitle under it (Music album tile). On hover a scrim
/// fades in with the tile's action at the bottom left and "More" at the bottom right; selection
/// draws the accent ring 4 pt outside the artwork. Width comes from the container (shelf, grid).
///
///     Tile(title: c.name, subtitle: CollectionText.count(c.items), seed: c.id, symbol: c.symbol,
///          action: ArtworkAction(symbol: "play.fill", label: CommonText.open) { play(c) }) { open(c) }
struct Tile: View {
    let title: String
    var subtitle: String?
    let seed: String
    var symbol: String?
    var isSelected: Bool
    var action: ArtworkAction?
    var more: ArtworkAction?
    /// Draws the hover state without a pointer (renders, gallery).
    var previewHover: Bool
    var open: (() -> Void)?

    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(title: String, subtitle: String? = nil, seed: String, symbol: String? = nil, isSelected: Bool = false,
         action: ArtworkAction? = nil, more: ArtworkAction? = nil, previewHover: Bool = false, open: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.seed = seed
        self.symbol = symbol
        self.isSelected = isSelected
        self.action = action
        self.more = more
        self.previewHover = previewHover
        self.open = open
    }

    var body: some View {
        let t = Theme(scheme)
        let showsHover = (hovering || previewHover) && (action != nil || more != nil)
        VStack(alignment: .leading, spacing: Space.xxs) {
            Artwork(seed: seed, symbol: symbol)
                .aspectRatio(1, contentMode: .fit)
                .overlay { hoverLayer(t, visible: showsHover) }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.ring, style: .continuous)
                            .strokeBorder(t.ring, lineWidth: Metrics.tileRingLine)
                            .padding(-Metrics.tileRingOutset)
                    }
                }
                .padding(.bottom, Space.xxs)
                .contentShape(Rectangle())
                .onTapGesture { open?() }
            Text(title)
                .font(TypeScale.bodyMedium)
                .foregroundStyle(t.fg)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(TypeScale.secondary)
                    .foregroundStyle(t.fg2)
                    .lineLimit(1)
            }
        }
        .onHover { inside in
            withAnimation(reduceMotion ? Motion.reduced : Motion.fade) { hovering = inside }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WindowText.tileLabel(title, subtitle))
        .accessibilityAddTraits(open == nil ? [] : .isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction { open?() }
    }

    @ViewBuilder
    private func hoverLayer(_ t: Theme, visible: Bool) -> some View {
        if visible {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [t.artworkScrimLight.opacity(0), t.artworkScrimLight], startPoint: .center, endPoint: .bottom)
                HStack {
                    if let action { ArtworkButton(action: action) }
                    Spacer(minLength: 0)
                    if let more { ArtworkButton(action: more) }
                }
                .padding(Space.xs)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .transition(.opacity)
        }
    }
}

/// The round dark button on artwork (30 pt, white glyph).
struct ArtworkButton: View {
    let action: ArtworkAction
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        Button(action: action.perform) {
            Image(systemName: action.symbol)
                .symbolFont(Metrics.Window.tileButtonGlyph, weight: .bold)
                .foregroundStyle(t.onArtwork)
                .frame(width: Metrics.Window.tileButton, height: Metrics.Window.tileButton)
                .background(Circle().fill(t.artworkButton))
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(action.label)
        .help(action.label)
    }
}
