import SwiftUI

/// What the island shows right now. The controller (`Island`) owns one; previews, the settings
/// stage, onboarding tiles and renders build their own and drive the same views.
@Observable
final class IslandModel {
    enum Kind: String, Equatable { case notch, capsule }
    /// The pointer on a done card: `expanded` = unfolded with the whole text, `collapsed` = folded
    /// back after the pointer left (that change runs on the collapse springs).
    enum Hover: Equatable { case none, expanded, collapsed }

    var kind: Kind = .notch
    /// false = shrunk back into the hardware notch / the capsule's seed (the panel orders out next)
    var presented = false
    /// nil = nothing to show
    var content: IslandContent?
    /// Measured per take; the 185 × 32 stand-in only where nothing was measured (renders).
    var notch = Metrics.Island.renderNotch
    var canvas = IslandLook.canvas
    /// Screen top to capsule top (menu bar + 8, or notch + 8 when dodging another notch app).
    var capsuleTop = Metrics.Island.renderMenuBar + Metrics.Island.capsuleTop
    /// When the current take began (elapsed timer of `.levels` in the capsule).
    var startedAt = Date()
    var reduceMotion = false
    /// Deterministic still: every timeline stands at this time (renders, tests).
    var stillTime: Double?
    /// Elapsed seconds shown by the timer in stills.
    var stillElapsed: TimeInterval = 4
    /// A progress running 5 s or longer: since when (the ear counts the seconds).
    var slowSince: Date?
    /// A progress running 10 s or longer: the card says it takes longer.
    var slowHint = false
    /// false while a surface grows out or shrinks back (glyphs enter / leave); true while it
    /// stays and only its content changes (glyphs swap).
    var contentSwap = false
    var hover: Hover = .none
    /// "Expand on hover" is off: a folded done card shows its actions, so they stay reachable.
    var foldedActions = false
    /// The panel takes clicks (pointer on a hovered card or on Cancel).
    var acceptsClicks = false
    /// The visible surface's animated body rect (canvas points, top-left origin), reported by the
    /// views for pointer polling. Not observed: writing it never re-renders.
    @ObservationIgnored var cardFrame: CGRect = .zero
    /// The newest level bands, read by the meter every frame. Not observed (30 Hz updates).
    @ObservationIgnored var bands: [Float] = []
    /// Renders: the copy button shows "Copied".
    var stillCopied = false

    var phase: IslandContent.Phase? { content?.phase }
}

// MARK: - Surface geometry and its two springs

/// Animated geometry of one black surface. `top` is the notch's concave ear radius (capsules
/// ignore it), `bottom` the bottom corner radius (the capsule's corner radius).
nonisolated struct IslandSurfaceGeometry: Equatable, Sendable {
    var width: CGFloat
    var height: CGFloat
    var top: CGFloat = 0
    var bottom: CGFloat
}

private nonisolated struct IslandSurfaceKey: EnvironmentKey {
    static let defaultValue = IslandSurfaceGeometry(width: 0, height: 0, top: 0, bottom: 0)
}

extension EnvironmentValues {
    /// The current (animated) geometry of the surface a view sits in.
    var islandSurface: IslandSurfaceGeometry {
        get { self[IslandSurfaceKey.self] }
        set { self[IslandSurfaceKey.self] = newValue }
    }
}

/// Width and height (+ radii) live in two Animatable modifiers, each with its own value-scoped
/// animation, so they spring independently even when both change in one update (one global
/// `withAnimation`, or one animatable vector, would merge them). VoiceBud SPEC §0.
private struct IslandSurfaceWidthFX: ViewModifier, Animatable {
    var width: CGFloat
    nonisolated var animatableData: CGFloat {
        get { width }
        set { width = newValue }
    }

    func body(content: Content) -> some View {
        content.transformEnvironment(\.islandSurface) { $0.width = width }
    }
}

private struct IslandSurfaceHeightFX: ViewModifier, Animatable {
    var height: CGFloat
    var top: CGFloat
    var bottom: CGFloat
    nonisolated var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(height, AnimatablePair(top, bottom)) }
        set {
            height = newValue.first
            top = newValue.second.first
            bottom = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        content.transformEnvironment(\.islandSurface) {
            $0.height = height
            $0.top = top
            $0.bottom = bottom
        }
    }
}

private struct IslandHeightKey: Equatable {
    let height: CGFloat
    let top: CGFloat
    let bottom: CGFloat
}

extension View {
    /// Publishes `g` as the animated `islandSurface` for the shape and mask views inside. Width:
    /// 150/20 growing, 200/20 collapsing. Height + radii: 250/21 expanding, 250/25 collapsing.
    /// `reduce` (Reduce Motion): a 0.2 s cross-fade timing.
    func islandSurface(_ g: IslandSurfaceGeometry, widthGrowing: Bool, heightGrowing: Bool, reduce: Bool = false) -> some View {
        modifier(IslandSurfaceWidthFX(width: g.width))
            .animation(reduce ? Motion.Island.crossFade : Motion.Island.width(growing: widthGrowing), value: g.width)
            .modifier(IslandSurfaceHeightFX(height: g.height, top: g.top, bottom: g.bottom))
            .animation(reduce ? Motion.Island.crossFade : Motion.Island.height(growing: heightGrowing),
                       value: IslandHeightKey(height: g.height, top: g.top, bottom: g.bottom))
    }
}

// MARK: - Content transitions (VoiceBud SPEC §0)

/// Entering: blur 10, scaleX 0.75 from the notch side, opacity 0 → identity. Leaving: blur 4,
/// scaleX 0.25, opacity 0.
private struct IslandBlurScaleFX: ViewModifier {
    var blur: CGFloat
    var scaleX: CGFloat
    var opacity: Double
    var anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .scaleEffect(x: scaleX, y: 1, anchor: anchor)
            .opacity(opacity)
    }
}

/// Swapping inside a surface that stays: scale 0.8, 4 pt down, blur, opacity 0 → identity.
private struct IslandSwapFX: ViewModifier {
    var scale: CGFloat
    var y: CGFloat
    var blur: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .scaleEffect(scale)
            .offset(y: y)
            .opacity(opacity)
    }
}

private enum IslandFX {
    static let enterBlur: CGFloat = 10
    static let enterScale: CGFloat = 0.75
    static let leaveBlur: CGFloat = 4
    static let leaveScale: CGFloat = 0.25
    static let swapScale: CGFloat = 0.8
    static let swapOffset: CGFloat = 4
    /// Swap blur is the surface height / 6.
    static let swapBlurDivisor: CGFloat = 6
}

extension AnyTransition {
    /// Content entering / leaving a surface, anchored towards the notch (or the pill).
    static func islandEnter(toward anchor: UnitPoint, reduce: Bool) -> AnyTransition {
        // renders never transition; a resting blur(0) would still rasterise the text offscreen
        if RenderMode.isStatic { return .identity }
        if reduce { return AnyTransition.opacity.animation(Motion.Island.crossFade) }
        let rest = IslandBlurScaleFX(blur: 0, scaleX: 1, opacity: 1, anchor: anchor)
        return .asymmetric(
            insertion: AnyTransition.modifier(
                active: IslandBlurScaleFX(blur: IslandFX.enterBlur, scaleX: IslandFX.enterScale, opacity: 0, anchor: anchor),
                identity: rest).animation(Motion.Island.enter),
            removal: AnyTransition.modifier(
                active: IslandBlurScaleFX(blur: IslandFX.leaveBlur, scaleX: IslandFX.leaveScale, opacity: 0, anchor: anchor),
                identity: rest).animation(Motion.Island.exit))
    }

    /// Content swap inside a surface that stays on screen.
    static func islandSwap(height: CGFloat = Metrics.Island.renderNotch.height, reduce: Bool) -> AnyTransition {
        if RenderMode.isStatic { return .identity }
        if reduce { return AnyTransition.opacity.animation(Motion.Island.crossFade) }
        return AnyTransition.modifier(
            active: IslandSwapFX(scale: IslandFX.swapScale, y: IslandFX.swapOffset,
                                 blur: height / IslandFX.swapBlurDivisor, opacity: 0),
            identity: IslandSwapFX(scale: 1, y: 0, blur: 0, opacity: 1))
            .animation(Motion.Island.swap)
    }

    /// Glyphs in an ear or the pill: swap while the surface stays, enter / leave with it.
    static func islandGlyph(swap: Bool, toward anchor: UnitPoint, reduce: Bool) -> AnyTransition {
        swap ? .islandSwap(reduce: reduce) : .islandEnter(toward: anchor, reduce: reduce)
    }

    /// Preview ↔ whole text on a hovered card: both start with the same words at the same place,
    /// so the outgoing block fades quickly and the incoming one enters 50 ms later.
    static func islandHandOver(reduce: Bool) -> AnyTransition {
        if RenderMode.isStatic { return .identity }
        if reduce { return AnyTransition.opacity.animation(Motion.Island.crossFade) }
        return .asymmetric(
            insertion: AnyTransition.modifier(
                active: IslandBlurScaleFX(blur: IslandFX.enterBlur, scaleX: IslandFX.enterScale, opacity: 0, anchor: .top),
                identity: IslandBlurScaleFX(blur: 0, scaleX: 1, opacity: 1, anchor: .top))
                .animation(Motion.Island.handOverIn),
            removal: AnyTransition.opacity.animation(Motion.fade))
    }
}

/// Animation key for content changes inside a surface: makes the transaction animated so the
/// transitions above run (they carry their own timing).
struct IslandContentKey: Equatable {
    let phase: IslandContent.Phase?
    let presented: Bool
    /// 1 = counting seconds, 2 = "takes longer" card
    var slow = 0
    /// badge identity: a new symbol swaps in
    var badge = ""
}
