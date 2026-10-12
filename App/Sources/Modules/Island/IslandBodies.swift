import SwiftUI

// What drops down under the ear row (notch) or fills a capsule card: the done card's title,
// preview and unfolded text with its buttons, a notice, and the "takes longer" line.
// Ported from VoiceBud IslandDoneBody / IslandDoneText / IslandFullText / IslandErrorBody.

/// Title in white semibold, the detail dim after it, separated by a plain gap (never a middle
/// dot), one line, cut in the middle.
struct IslandTitleLine: View {
    let title: String
    var detail: String?

    var body: some View {
        Text(Self.attributed(title: title, detail: detail))
            .lineLimit(1)
            .truncationMode(.middle)
    }

    static func attributed(title: String, detail: String?) -> AttributedString {
        var a = AttributedString(title)
        a.font = TypeScale.secondarySemibold
        a.foregroundColor = IslandPalette.text
        if let detail, !detail.isEmpty {
            var d = AttributedString(IslandText.metaGap + detail)
            d.font = TypeScale.secondaryMedium.monospacedDigit()
            d.foregroundColor = IslandPalette.meta
            a += d
        }
        return a
    }
}

/// The text part of a done card: one preview line, or on hover the whole text with Copy and the
/// card's actions. The incoming block enters, the outgoing one hands over with a quick fade.
/// `foldedActions` ("Expand on hover" off): the folded card shows the actions under its line.
struct IslandDoneText: View {
    let text: String?
    let actions: [IslandAction]
    var expanded = false
    var foldedActions = false
    var still = false
    var reduce = false
    var stillCopied = false
    /// Runs after an action that closes the card.
    var dismiss: () -> Void = {}

    var body: some View {
        let t = AnyTransition.islandHandOver(reduce: reduce)
        let text = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 0) {
            if !text.isEmpty {
                ZStack(alignment: .topLeading) {
                    if expanded {
                        IslandFullText(text: text, still: still).transition(t)
                    } else {
                        IslandPreviewText(text: text).transition(t)
                    }
                }
            }
            if (expanded && (!text.isEmpty || !actions.isEmpty)) || (foldedActions && !expanded && !actions.isEmpty) {
                HStack(spacing: IslandLook.actionGap) {
                    if expanded && !text.isEmpty { IslandCopyButton(text: text, still: still, stillCopied: stillCopied) }
                    ForEach(actions) { action in
                        IslandButton(title: action.title, symbol: action.symbol, still: still) {
                            action.run(dismiss: dismiss)
                        }
                    }
                }
                .padding(.top, text.isEmpty ? 0 : IslandLook.actionTop)
                .transition(t)
            }
        }
    }
}

struct IslandPreviewText: View {
    let text: String

    var body: some View {
        Text(IslandLayout.preview(text))
            .font(TypeScale.preview)
            .foregroundStyle(IslandPalette.body)
            .lineSpacing(TypeScale.previewLineSpacing)
            .lineLimit(1)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Sizes itself to the content, capped at the reference text's height (12 lines) plus half a
/// line: when text continues, half a line peeks out under the fade, so the cut never reads as
/// the end. Subviews: [0] content (hidden, measures), [1] reference (hidden), [2] what is shown.
nonisolated struct IslandCappedHeightLayout: Layout {
    /// The reference text's line count (the one source; `IslandLook.fullTextMaxLines` reads it).
    static let maxLines = 12
    /// The unfolded width when nothing is proposed: `Metrics.Island.liveWidth`, repeated because
    /// the layout runs off the main actor (IslandLayoutTests keeps the two equal).
    static let defaultWidth: CGFloat = 470

    static func limit(reference: CGFloat) -> CGFloat {
        reference + reference / CGFloat(maxLines) / 2
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? Self.defaultWidth
        let content = subviews[0].sizeThatFits(ProposedViewSize(width: w, height: nil)).height
        let reference = subviews[1].sizeThatFits(ProposedViewSize(width: w, height: nil)).height
        return CGSize(width: w, height: min(content, Self.limit(reference: reference)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let free = ProposedViewSize(width: bounds.width, height: nil)
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: free)
        subviews[1].place(at: bounds.origin, anchor: .topLeading, proposal: free)
        subviews[2].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

/// The whole text of a hovered card: up to 12 lines; longer text scrolls with a soft fade where
/// more continues. Stills draw the unscrolled state without a ScrollView.
struct IslandFullText: View {
    let text: String
    var still = false

    @State private var contentHeight: CGFloat = 0
    @State private var referenceHeight: CGFloat = 0
    @State private var edges: Edges?

    private struct Edges: Equatable {
        var above: Bool
        var below: Bool
    }

    private var overflowing: Bool {
        referenceHeight > 0 && contentHeight > IslandCappedHeightLayout.limit(reference: referenceHeight) + 0.5
    }
    private var fadeAbove: Bool { edges?.above ?? false }
    private var fadeBelow: Bool { edges?.below ?? overflowing }

    var body: some View {
        let paragraphs = IslandLayout.paragraphs(text)
        IslandCappedHeightLayout {
            paragraphsView(paragraphs)
                .hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            Text(verbatim: Array(repeating: "X", count: IslandLook.fullTextMaxLines).joined(separator: "\n")) // verbatim: hidden line-height reference, never shown
                .font(TypeScale.preview)
                .lineSpacing(TypeScale.previewLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { referenceHeight = $0 }
            if still {
                paragraphsView(paragraphs)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()
            } else {
                ScrollView(.vertical) {
                    paragraphsView(paragraphs)
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
                .onScrollGeometryChange(for: Edges.self) { geo in
                    Edges(above: geo.visibleRect.minY > 0.5, below: geo.visibleRect.maxY < geo.contentSize.height - 0.5)
                } action: { _, new in
                    edges = new
                }
            }
        }
        .mask(fade)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private func paragraphsView(_ paragraphs: [String]) -> some View {
        VStack(alignment: .leading, spacing: IslandLook.paragraphGap) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
                Text(p)
                    .font(TypeScale.preview)
                    .foregroundStyle(IslandPalette.body)
                    .lineSpacing(TypeScale.previewLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Solid in the middle; the ends fade only where more text continues.
    private var fade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(fadeAbove ? 0 : 1), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: IslandLook.fadeTop)
            // design-ausnahme: a mask, only its alpha counts
            Rectangle().fill(Color.black)
            LinearGradient(colors: [.black, .black.opacity(fadeBelow ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                .frame(height: IslandLook.fadeBottom)
        }
        .animation(still ? nil : Motion.reduced, value: Edges(above: fadeAbove, below: fadeBelow))
    }
}

/// A notice: centred under the notch, at most two lines.
struct IslandNoticeBody: View {
    let text: String
    var centered = true

    var body: some View {
        Text(text)
            .font(TypeScale.previewMedium)
            .foregroundStyle(IslandPalette.body)
            .multilineTextAlignment(centered ? .center : .leading)
            .lineLimit(IslandLook.noticeMaxLines)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

/// Progress from 10 s on: "Taking longer" and, when the app offers it, Cancel.
struct IslandSlowBody: View {
    let cancel: IslandAction?
    var still = false
    /// Runs after a Cancel that closes the island (`IslandAction.dismisses`).
    var dismiss: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: IslandLook.glyphGap) {
            Text(IslandText.takesLonger)
                .font(TypeScale.previewMedium)
                .foregroundStyle(IslandPalette.body)
                .lineLimit(1)
            Spacer(minLength: IslandLook.actionGap)
            if let cancel {
                IslandButton(title: cancel.title, symbol: cancel.symbol, still: still) { cancel.run(dismiss: dismiss) }
            } else {
                Text(IslandText.stillWorking)
                    .font(TypeScale.subtitle)
                    .foregroundStyle(IslandPalette.meta)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
