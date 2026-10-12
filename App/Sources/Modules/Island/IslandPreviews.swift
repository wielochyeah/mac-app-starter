import SwiftUI

// Stages that show the REAL island views on a piece of desktop: renders, the settings pane,
// the style tiles and the onboarding step (VoiceBud IslandBackdrop, HubIslandStage).

/// The top of a Mac screen: wallpaper, menu bar band and (optionally) the hardware notch,
/// drawn exactly like the closed island so nothing peeks out while a spring catches up.
struct IslandBackdrop: View {
    /// nil = a screen without notch.
    var notch: CGSize? = Metrics.Island.renderNotch
    var menuBar: CGFloat = Metrics.Island.renderMenuBar
    @Environment(\.colorScheme) private var scheme

    /// Menu bar height of a Mac without notch in renders.
    static let noNotchMenuBar: CGFloat = 25

    var body: some View {
        let t = Theme(scheme)
        ZStack(alignment: .top) {
            Rectangle().fill(t.wallpaper)
            t.menuBarTint.frame(height: menuBar)
            if let notch {
                UnevenRoundedRectangle(bottomLeadingRadius: Radius.Island.notch, bottomTrailingRadius: Radius.Island.notch)
                    .fill(IslandPalette.surface)
                    .frame(width: notch.width, height: notch.height)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A model for previews and renders: presented, at the render notch, in the given form.
enum IslandPreviewModel {
    static func make(_ content: IslandContent?, kind: IslandModel.Kind = .notch, canvas: CGSize = IslandLook.crop,
                     notch: Bool = true, still: Bool = true, configure: (IslandModel) -> Void = { _ in }) -> IslandModel {
        let m = IslandModel()
        m.kind = kind
        m.canvas = canvas
        m.notch = Metrics.Island.renderNotch
        m.capsuleTop = (notch ? Metrics.Island.renderMenuBar : IslandBackdrop.noNotchMenuBar) + Metrics.Island.capsuleTop
        m.content = content?.withoutBands
        m.bands = content?.bands ?? []
        m.presented = content != nil
        m.contentSwap = true
        m.stillTime = still ? IslandLook.stillTime : nil
        configure(m)
        return m
    }

    /// Mid-speech bands for the level meter in stills.
    static let speechBands: [Float] = [0.62, 0.85, 0.74, 0.55, 0.42, 0.30, 0.18]
}

/// The backdrop with the real island on it, at the model's canvas size.
struct IslandStage: View {
    let model: IslandModel
    var notch = true

    var body: some View {
        ZStack(alignment: .top) {
            IslandBackdrop(notch: notch ? model.notch : nil,
                           menuBar: notch ? Metrics.Island.renderMenuBar : IslandBackdrop.noNotchMenuBar)
            IslandView(model: model)
        }
        .frame(width: model.canvas.width, height: model.canvas.height)
        .clipped()
    }
}

/// A scaled-down still stage for tile previews: fills the tile's height, centred, cropped at
/// the sides.
struct IslandMiniStage: View {
    let kind: IslandModel.Kind
    var notch = true
    /// Extra zoom-out (the split "Automatic" tile shows two halves).
    var zoom: CGFloat = 1
    let content: IslandContent

    var body: some View {
        GeometryReader { geo in
            let stage = IslandLook.tileStage
            let scale = max(geo.size.height, 1) / stage.height * zoom
            // as wide as the tile at this scale, so the desktop fills it edge to edge
            let canvas = CGSize(width: max(geo.size.width / scale, 1), height: stage.height / zoom)
            IslandStage(model: IslandPreviewModel.make(content, kind: kind, canvas: canvas, notch: notch), notch: notch)
                .scaleEffect(scale, anchor: .top)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// The preview inside a style tile: the island at the notch, the capsule below a menu bar
/// without notch, or both halves for "Automatic".
struct IslandStyleTile: View {
    let style: IslandStyle
    @Environment(\.colorScheme) private var scheme

    static var content: IslandContent { .levels(IslandPreviewModel.speechBands, symbol: AppInfo.symbol) }

    var body: some View {
        switch style {
        case .island:
            IslandMiniStage(kind: .notch, content: Self.content)
        case .capsule:
            IslandMiniStage(kind: .capsule, notch: false, content: Self.content)
        case .auto:
            HStack(spacing: 0) {
                IslandMiniStage(kind: .notch, zoom: Self.splitZoom, content: Self.content)
                Theme(scheme).tileEdge.frame(width: Metrics.hairline)
                IslandMiniStage(kind: .capsule, notch: false, zoom: Self.splitZoom, content: Self.content)
            }
        }
    }

    /// Each half of the split tile shows its stage smaller.
    static let splitZoom: CGFloat = 0.7
}

/// The live stage above the style tiles (settings, onboarding): the island and the capsule
/// morph with the real springs when the style changes. Kapsel: the island shrinks back behind the
/// notch while the capsule grows out of its seed below the menu bar.
struct IslandStyleStage: View {
    let style: IslandStyle
    @State private var island: IslandModel
    @State private var capsule: IslandModel
    @Environment(\.renderStatic) private var renderStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(style: IslandStyle) {
        self.style = style
        let content = IslandStyleTile.content
        let canvas = IslandLook.stageCanvas
        _island = State(initialValue: IslandPreviewModel.make(content, kind: .notch, canvas: canvas, still: false) {
            $0.presented = style != .capsule
        })
        _capsule = State(initialValue: IslandPreviewModel.make(content, kind: .capsule, canvas: canvas, still: false) {
            $0.presented = style == .capsule
        })
    }

    private var capsuleShown: Bool { style == .capsule }

    var body: some View {
        ZStack(alignment: .top) {
            IslandBackdrop()
            if !renderStatic || !capsuleShown {
                IslandView(model: island)
            }
            if !renderStatic || capsuleShown {
                IslandView(model: capsule)
                    // the capsule's seed must not linger once it shrank back
                    .opacity(capsuleShown ? 1 : 0)
                    .animation(capsuleShown ? Motion.Island.cardIn : Motion.Island.cardOut.delay(Motion.Island.cardOutDelay),
                               value: capsuleShown)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: IslandLook.stageHeight)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .onAppear { sync() }
        .onChange(of: style) { sync() }
        .onChange(of: reduceMotion) { sync() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IslandText.style(style))
    }

    private func sync() {
        island.reduceMotion = reduceMotion
        capsule.reduceMotion = reduceMotion
        island.presented = style != .capsule
        capsule.presented = style == .capsule
    }
}
