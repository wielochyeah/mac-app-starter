import SwiftUI

// The island's views (VoiceBud ui/Island.swift, SPEC §0): every surface is ONE black shape whose
// width and height (+ radii) animate on their own springs; content enters, leaves and swaps with
// the island transitions. Stills (renders) and Reduce Motion take a plain layout path: the shape
// is sized by its content and nothing morphs.

/// Fills the transparent panel (or a preview stage); the notch island or the capsule animates
/// inside it.
struct IslandView: View {
    let model: IslandModel
    /// Closes the island after a card action (the controller passes its dismiss).
    var dismiss: () -> Void = {}

    /// The canvas coordinate space (top-left origin) card frames are reported in.
    nonisolated static let space = "Island.canvas"

    /// Reduce Motion identity: each phase, and the unfolded card, is its own island.
    private struct FadeID: Hashable {
        let phase: IslandContent.Phase?
        let expanded: Bool
    }

    var body: some View {
        let fadeID = FadeID(phase: model.phase, expanded: model.hover == .expanded)
        ZStack(alignment: .top) {
            switch (model.kind, model.reduceMotion) {
            case (.notch, false):
                NotchIslandView(model: model, hover: model.hover, dismiss: dismiss)
            case (.notch, true):
                NotchIslandView(model: model, hover: model.hover, dismiss: dismiss)
                    .id(fadeID)
                    .transition(.opacity)
            case (.capsule, false):
                CapsuleView(model: model, hover: model.hover, dismiss: dismiss)
                    .padding(.top, model.capsuleTop)
            case (.capsule, true):
                CapsuleView(model: model, hover: model.hover, dismiss: dismiss)
                    .padding(.top, model.capsuleTop)
                    .id(fadeID)
                    .transition(.opacity)
            }
        }
        .frame(width: model.canvas.width, height: model.canvas.height, alignment: .top)
        .coordinateSpace(.named(Self.space))
        .environment(\.colorScheme, .dark)
        // only a hovered card (or Cancel under the pointer) takes clicks; the panel ignores the
        // mouse everywhere else
        .allowsHitTesting(model.acceptsClicks)
    }
}

/// Values every island view derives from the model and the environment.
private struct IslandState {
    let model: IslandModel
    let hover: IslandModel.Hover
    /// Renders: every timeline stands still.
    let still: Double?

    init(_ model: IslandModel, hover: IslandModel.Hover, renderStatic: Bool) {
        self.model = model
        self.hover = hover
        still = model.stillTime ?? (renderStatic ? IslandLook.stillTime : nil)
    }

    var reduce: Bool { model.reduceMotion }
    /// Stills and Reduce Motion: the shape is sized by its content, nothing morphs.
    var layoutMode: Bool { still != nil || reduce }
    var content: IslandContent? { model.content }
    var phase: IslandContent.Phase? { model.phase }
    /// Geometry as if shown; with Reduce Motion the island fades instead of growing.
    var shown: Bool { content != nil && (model.presented || reduce) }
    var expanded: Bool { shown && phase == .done && hover == .expanded && (content?.canExpand ?? false) }
    /// Folding back after a hover runs on the collapse springs.
    var growing: Bool { shown && hover != .collapsed }
    var slowCounting: Bool { phase == .progress && model.slowSince != nil }
    var slowHint: Bool { phase == .progress && model.slowHint }
    var badge: IslandBadgeKind? { content.map(IslandBadgeKind.init) }
    var elapsedStill: TimeInterval? { still == nil ? nil : model.stillElapsed }

    var contentKey: IslandContentKey {
        IslandContentKey(phase: phase, presented: model.presented, slow: slowHint ? 2 : slowCounting ? 1 : 0,
                         badge: badge?.key ?? "")
    }

    /// Title next to the badge (activity, progress); an empty title shows the badge alone.
    var title: String? {
        switch content {
        case .activity(_, let title, _, _), .progress(let title, _, _, _, _): title.isEmpty ? nil : title
        default: nil
        }
    }

    var tint: IslandTint {
        switch content {
        case .activity(_, _, _, let t), .progress(_, _, _, let t, _), .levels(_, _, let t, _), .done(_, _, _, _, let t): t
        default: .accent
        }
    }
}

/// Reports the surface's animated body rect (canvas points) for pointer polling. Invisible,
/// takes no clicks, does not change the surface's size.
private struct IslandSurfaceHitArea: View {
    let model: IslandModel
    @Environment(\.islandSurface) private var g

    var body: some View {
        Color.clear
            .frame(width: max(0, g.width), height: max(0, g.height))
            .allowsHitTesting(false)
            .islandReportsCardFrame(model)
    }
}

extension View {
    /// Writes this view's frame in the island canvas into `model.cardFrame` (not observed).
    func islandReportsCardFrame(_ model: IslandModel) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(IslandView.space)) } action: { model.cardFrame = $0 }
    }
}

// MARK: - Island at the notch

struct NotchIslandView: View {
    let model: IslandModel
    /// `model.hover` handed in as a value: with Reduce Motion the outgoing island of a
    /// cross-fade keeps its own folded or unfolded card.
    var hover: IslandModel.Hover = .none
    var dismiss: () -> Void = {}
    /// Measured height of ear row + body (drives the height spring).
    @State private var contentHeight: CGFloat = 0
    @Environment(\.renderStatic) private var renderStatic

    var body: some View {
        let s = IslandState(model, hover: hover, renderStatic: renderStatic)
        let geo = geometry(s)
        if s.layoutMode {
            contentStack(s, width: geo.width)
                .frame(minHeight: model.notch.height, alignment: .top)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: geo.bottom, bottomTrailingRadius: geo.bottom))
                .background(alignment: .top) {
                    NotchShape(topRadius: geo.top, bottomRadius: geo.bottom)
                        .fill(IslandPalette.surface)
                        .padding(.horizontal, -geo.top)
                }
                .islandReportsCardFrame(model)
                .opacity(s.reduce && !model.presented ? 0 : 1)
        } else {
            ZStack(alignment: .top) {
                NotchSurfaceShape()
                IslandSurfaceHitArea(model: model)
                contentStack(s, width: geo.width)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                    .mask(alignment: .top) { NotchSurfaceMask() }
            }
            .islandSurface(IslandSurfaceGeometry(width: geo.width, height: geo.height, top: geo.top, bottom: geo.bottom),
                           widthGrowing: s.growing, heightGrowing: s.growing && hasBody(s))
        }
    }

    private func hasBody(_ s: IslandState) -> Bool {
        s.shown && (s.phase == .done || s.phase == .notice || s.slowHint)
    }

    /// Width, height and radii (VoiceBud: ear 8 compact / 13 with a body; bottom 12 compact,
    /// 19 card, 24 unfolded; closed = exactly the notch, 8 pt narrower).
    private func geometry(_ s: IslandState) -> IslandSurfaceGeometry {
        let notch = model.notch
        let width = IslandLayout.notchWidth(s.content, notch: notch, shown: s.shown, expanded: s.expanded,
                                            slowCounting: s.slowCounting, slowHint: s.slowHint)
        guard s.shown else {
            return IslandSurfaceGeometry(width: width, height: notch.height, top: 0,
                                         bottom: min(Radius.Island.notch, notch.height / 3))
        }
        let body = hasBody(s)
        return IslandSurfaceGeometry(
            width: width,
            height: body ? max(notch.height, contentHeight) : notch.height,
            top: body ? Radius.Island.earExpanded : Radius.Island.earCollapsed,
            bottom: !body ? Radius.Island.bottomCompact : (s.expanded ? Radius.Island.bottomLive : Radius.Island.bottomCard))
    }

    /// Laid out at the target width (text never re-wraps while the shape springs); the animated
    /// surface reveals it. On hover the frame widens on the width spring, so the badge and the
    /// title ride with the edges.
    private func contentStack(_ s: IslandState, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            earRow(s)
            if hasBody(s) {
                bodyContent(s)
                    .transition(.islandEnter(toward: .top, reduce: s.reduce))
            }
        }
        .animation(s.layoutMode ? nil : Motion.Island.swap, value: s.contentKey)
        .frame(width: width, alignment: .top)
        .animation(s.layoutMode ? nil : Motion.Island.width(growing: s.growing), value: s.expanded)
    }

    private func earRow(_ s: IslandState) -> some View {
        HStack(spacing: 0) {
            leftEar(s)
                .padding(.leading, IslandLook.earPad)
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: model.notch.width)
            rightEar(s)
                .padding(.trailing, IslandLook.earPad)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: model.notch.height)
    }

    private func leftEar(_ s: IslandState) -> some View {
        let t = AnyTransition.islandGlyph(swap: model.contentSwap, toward: .trailing, reduce: s.reduce)
        return HStack(spacing: IslandLook.earSpacing) {
            if s.shown, let badge = s.badge {
                IslandBadge(kind: badge).id(badge.key).transition(t)
            }
            if s.shown && (s.content?.isRecording ?? false) { IslandRecDot().transition(t) }
            if s.shown, let title = s.title {
                Text(title)
                    .font(TypeScale.secondarySemibold)
                    .foregroundStyle(IslandPalette.text)
                    .lineLimit(1)
                    .id(title)
                    .transition(t)
            }
        }
    }

    private func rightEar(_ s: IslandState) -> some View {
        let t = AnyTransition.islandGlyph(swap: model.contentSwap, toward: .leading, reduce: s.reduce)
        return ZStack(alignment: .trailing) {
            if s.shown, case .activity(_, _, let detail?, _) = s.content {
                Text(detail)
                    .font(TypeScale.secondaryMedium.monospacedDigit())
                    .foregroundStyle(IslandPalette.meta)
                    .lineLimit(1)
                    .transition(t)
            }
            if s.shown, case .progress(_, let fraction, _, let tint, _) = s.content {
                HStack(spacing: IslandLook.glyphGap) {
                    if let since = model.slowSince {
                        IslandSlowSeconds(since: since, still: s.still != nil)
                            .transition(.islandGlyph(swap: true, toward: .leading, reduce: s.reduce))
                    }
                    if let fraction { IslandPercent(fraction: fraction) }
                    IslandRing(tint: tint, fraction: fraction, still: s.still.map { _ in IslandLook.stillTime / 5 })
                }
                .animation(s.layoutMode ? nil : Motion.Island.swap, value: model.slowSince != nil)
                .transition(t)
            }
            if s.shown && s.phase == .levels {
                IslandMeter(tint: s.tint, bands: { [model] in model.bands }, still: s.still)
                    .transition(t)
            }
        }
    }

    @ViewBuilder private func bodyContent(_ s: IslandState) -> some View {
        let swap = AnyTransition.islandEnter(toward: .top, reduce: s.reduce)
        ZStack(alignment: .topLeading) {
            if s.slowHint {
                IslandSlowBody(cancel: s.content?.cancelAction, still: s.still != nil, dismiss: dismiss)
                    .transition(swap)
            } else if case .done(let title, let detail, let text, let actions, _) = s.content {
                VStack(alignment: .leading, spacing: IslandLook.titleGap) {
                    IslandTitleLine(title: title, detail: detail)
                    IslandDoneText(text: text, actions: actions, expanded: s.expanded, foldedActions: model.foldedActions,
                                   still: s.still != nil, reduce: s.reduce, stillCopied: model.stillCopied, dismiss: dismiss)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(swap)
            } else if case .notice(let text, _) = s.content {
                IslandNoticeBody(text: text)
                    .transition(swap)
            }
        }
        .padding(.horizontal, Metrics.Island.bodyPad)
        .padding(.top, IslandLook.bodyTop)
        .padding(.bottom, IslandLook.bodyBottom)
    }
}

// MARK: - Capsule (no notch, style "capsule", or dodging another notch app)

/// One black capsule that grows out of a 36 × 8 seed and morphs between the pill (activity,
/// progress, levels), the done card and the notice card.
struct CapsuleView: View {
    let model: IslandModel
    var hover: IslandModel.Hover = .none
    var dismiss: () -> Void = {}
    @State private var pillWidth: CGFloat = 0
    @State private var doneHeight: CGFloat = 0
    @State private var noticeHeight: CGFloat = 0
    @Environment(\.renderStatic) private var renderStatic

    var body: some View {
        let s = IslandState(model, hover: hover, renderStatic: renderStatic)
        if s.content == nil {
            // nothing on screen: no timelines keep running behind an ordered-out panel
            Color.clear.frame(width: 1, height: 1)
        } else if s.layoutMode {
            stillBody(s).opacity(s.reduce && !model.presented ? 0 : 1)
        } else {
            mainSurface(s)
        }
    }

    private func cardWidth(_ s: IslandState) -> CGFloat {
        s.expanded ? Metrics.Island.liveWidth : Metrics.Island.doneWidth
    }

    private func noticeText(_ s: IslandState) -> String {
        if case .notice(let text, _) = s.content { return text }
        return ""
    }

    private func geometry(_ s: IslandState) -> IslandSurfaceGeometry {
        let pill = Metrics.Island.pillHeight
        guard s.shown else {
            return IslandSurfaceGeometry(width: Metrics.Island.seed.width, height: Metrics.Island.seed.height,
                                         bottom: Radius.Island.seed)
        }
        switch s.phase {
        case .done:
            return IslandSurfaceGeometry(width: cardWidth(s), height: max(pill, doneHeight), bottom: Radius.Island.capsuleCard)
        case .notice:
            let h = max(pill, noticeHeight)
            return IslandSurfaceGeometry(width: IslandLayout.capsuleNoticeWidth(noticeText(s)), height: h,
                                         bottom: min(Radius.Island.capsuleCard, h / 2))
        default:
            return IslandSurfaceGeometry(width: pillWidth > 0 ? pillWidth : Metrics.Island.pillFallbackWidth,
                                         height: pill, bottom: Radius.Island.capsule)
        }
    }

    private func mainSurface(_ s: IslandState) -> some View {
        let isCard = s.phase == .done || s.phase == .notice
        return ZStack(alignment: .top) {
            CapsuleSurfaceShape()
            IslandSurfaceHitArea(model: model)
            ZStack(alignment: .top) {
                if s.shown && (s.content?.isRunning ?? false) {
                    pill(s)
                        .fixedSize()
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pillWidth = $0 }
                        .transition(.islandEnter(toward: .center, reduce: s.reduce))
                }
                if s.shown && s.phase == .done {
                    doneCard(s)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { doneHeight = $0 }
                        .onDisappear { doneHeight = 0 }
                        .transition(.islandEnter(toward: .top, reduce: s.reduce))
                }
                if s.shown && s.phase == .notice {
                    noticeCard(s)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { noticeHeight = $0 }
                        .transition(.islandEnter(toward: .top, reduce: s.reduce))
                }
            }
            .animation(Motion.Island.swap, value: s.contentKey)
            .mask(alignment: .top) { CapsuleSurfaceMask() }
        }
        .islandSurface(geometry(s), widthGrowing: s.growing, heightGrowing: s.growing && isCard)
    }

    @ViewBuilder private func stillBody(_ s: IslandState) -> some View {
        switch s.phase {
        case .done:
            doneCard(s).background(CapsuleBackdrop(radius: Radius.Island.capsuleCard)).islandReportsCardFrame(model)
        case .notice:
            noticeCard(s).background(CapsuleBackdrop(radius: Radius.Island.capsule))
        default:
            pill(s).fixedSize().background(CapsuleBackdrop(radius: Metrics.Island.pillHeight / 2)).islandReportsCardFrame(model)
        }
    }

    private func pill(_ s: IslandState) -> some View {
        let t = AnyTransition.islandGlyph(swap: model.contentSwap, toward: .leading, reduce: s.reduce)
        return HStack(spacing: IslandLook.pillSpacing) {
            if let badge = s.badge { IslandBadge(kind: badge).id(badge.key).transition(t) }
            if let title = s.title {
                Text(title)
                    .font(TypeScale.secondarySemibold)
                    .foregroundStyle(IslandPalette.text)
                    .lineLimit(1)
                    .frame(maxWidth: IslandLook.pillTitleMax, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                    .id(title)
                    .transition(t)
            }
            if case .activity(_, _, let detail?, _) = s.content {
                Text(detail)
                    .font(TypeScale.secondaryMedium.monospacedDigit())
                    .foregroundStyle(IslandPalette.meta)
                    .lineLimit(1)
                    .fixedSize()
                    .transition(t)
            }
            if case .progress(_, let fraction, _, let tint, let cancel) = s.content {
                if let since = model.slowSince { IslandSlowSeconds(since: since, still: s.still != nil).transition(t) }
                if let fraction { IslandPercent(fraction: fraction).transition(t) }
                IslandRing(tint: tint, fraction: fraction, still: s.still.map { _ in IslandLook.stillTime / 5 }).transition(t)
                if s.slowHint {
                    Text(IslandText.takesLonger)
                        .font(TypeScale.subtitleMedium)
                        .foregroundStyle(IslandPalette.body)
                        .fixedSize()
                        .transition(t)
                    if let cancel {
                        IslandButton(title: cancel.title, symbol: cancel.symbol, still: s.still != nil) { cancel.run(dismiss: dismiss) }
                            .transition(t)
                    }
                }
            }
            if s.phase == .levels {
                if s.content?.isRecording ?? false {
                    IslandRecDot().transition(t)
                    IslandTimerText(start: model.startedAt, still: s.elapsedStill)
                }
                IslandMeter(tint: s.tint, bands: { [model] in model.bands }, still: s.still).transition(t)
            }
        }
        .padding(.leading, IslandLook.pillLeading)
        .padding(.trailing, IslandLook.pillTrailing)
        .frame(height: Metrics.Island.pillHeight)
    }

    @ViewBuilder private func doneCard(_ s: IslandState) -> some View {
        if case .done(let title, let detail, let text, let actions, let tint) = s.content {
            VStack(alignment: .leading, spacing: IslandLook.cardRowGap) {
                HStack(spacing: IslandLook.actionGap) {
                    IslandBadge(kind: .check(tint))
                    IslandTitleLine(title: title, detail: detail)
                    Spacer(minLength: IslandLook.actionGap)
                }
                .frame(height: IslandLook.cardRow)
                IslandDoneText(text: text, actions: actions, expanded: s.expanded, foldedActions: model.foldedActions,
                               still: s.still != nil, reduce: s.reduce, stillCopied: model.stillCopied, dismiss: dismiss)
                    .padding(.leading, IslandLook.cardIndent)
            }
            .padding(.top, IslandLook.cardTop)
            .padding(.leading, IslandLook.cardLeading)
            .padding(.trailing, IslandLook.cardTrailing)
            .padding(.bottom, IslandLook.cardBottom)
            .frame(width: cardWidth(s), alignment: .leading)
            // on hover the card widens on the width spring: badge and title ride along
            .animation(s.layoutMode ? nil : Motion.Island.width(growing: s.growing), value: s.expanded)
        }
    }

    private func noticeCard(_ s: IslandState) -> some View {
        HStack(spacing: IslandLook.actionGap) {
            if let badge = s.badge { IslandBadge(kind: badge) }
            IslandNoticeBody(text: noticeText(s))
        }
        .padding(.vertical, IslandLook.noticeY)
        .padding(.leading, IslandLook.noticeLeading)
        .padding(.trailing, IslandLook.noticeTrailing)
        .frame(width: IslandLayout.capsuleNoticeWidth(noticeText(s)), alignment: .leading)
    }
}
