import AppKit
import SwiftUI

// Island-only sizes and timings on top of Kit/Design/Island.swift (IslandPalette, IslandAccent,
// Radius.Island, Metrics.Island, Motion.Island). Values are VoiceBud's (ui/Island.swift,
// ui/IslandWindow.swift; notes vb-island-notch §3–§8). Candidates for Kit/Design/Island.swift
// once a second module needs them.

/// Sizes of the island's glyphs, ears, pills and cards.
enum IslandLook {
    /// The transparent panel the shape animates in (tall enough for a hovered card).
    static let canvas = CGSize(width: 640, height: 400)
    /// Render crops: a 14" MacBook's top centre, and the taller one for hovered cards.
    static let crop = CGSize(width: 600, height: 220)
    static let hoverCrop = CGSize(width: 600, height: 380)

    // Ears (the notch island's content left and right of the camera)
    static let earPad: CGFloat = 14
    static let earSpacing: CGFloat = 7
    /// A body (card) is never narrower than the notch plus this on each side.
    static let cardWing: CGFloat = 80

    // Glyphs
    static let badge: CGFloat = 20
    static let badgeGlyph: CGFloat = 10
    static let badgeFill: Double = 0.22
    static let recHalo: CGFloat = 12
    static let recHaloOpacity: Double = 0.18
    static let check: CGFloat = 11
    static let checkLine: CGFloat = 1.7
    static let spinner: CGFloat = 12
    static let spinnerFrame: CGFloat = 16
    static let spinnerLine: CGFloat = 1.9
    static let spinnerArc: CGFloat = 0.3
    static let spinnerTrack: Double = 0.15
    static let glyphGap: CGFloat = 6

    // Bodies under the ear row
    static let bodyTop: CGFloat = 2
    static let bodyBottom: CGFloat = 13
    static let titleGap: CGFloat = 2
    static let fullTextMaxLines = 12
    static let paragraphGap: CGFloat = 6
    static let fadeTop: CGFloat = 16
    static let fadeBottom: CGFloat = 26
    static let actionTop: CGFloat = 10
    static let actionGap: CGFloat = 8
    static let noticeMaxLines = 2

    // Small buttons on black (Copy, actions, Cancel)
    static let buttonX: CGFloat = 9
    static let buttonRadius: CGFloat = 7
    static let buttonLabelGap: CGFloat = 4
    static let buttonText: Double = 0.86

    // Capsule (Macs without notch)
    static let pillLeading: CGFloat = 10
    static let pillTrailing: CGFloat = 14
    static let pillSpacing: CGFloat = 10
    /// Longer titles in the pill are cut.
    static let pillTitleMax: CGFloat = 220
    static let cardTop: CGFloat = 9
    static let cardLeading: CGFloat = 12
    static let cardTrailing: CGFloat = 16
    static let cardBottom: CGFloat = 13
    static let cardRow: CGFloat = 24
    static let cardRowGap: CGFloat = 3
    static let cardIndent: CGFloat = 28
    static let noticeY: CGFloat = 10
    static let noticeLeading: CGFloat = 10
    static let noticeTrailing: CGFloat = 16
    static let noticeMinCapsule: CGFloat = 160
    /// Capsule shadow: a blurred black copy, inset (the CSS negative spread) and moved down.
    static let shadowInset: CGFloat = 10
    static let shadowOffset: CGFloat = 8
    static let shadowBlur: CGFloat = 12

    // Level meter (VoiceBud "fein": 4 bars)
    static let meterBars = 4
    static let meterBar: CGFloat = 2
    static let meterGap: CGFloat = 1.5
    static let meterMin: CGFloat = 2
    static let meterMax: CGFloat = 14
    static var meterWidth: CGFloat { CGFloat(meterBars) * meterBar + CGFloat(meterBars - 1) * meterGap }

    // Previews (settings stage, tiles, onboarding)
    static let stageHeight: CGFloat = 132
    static let stageCanvas = CGSize(width: 600, height: 132)
    static let tileStage = CGSize(width: 400, height: 150)

    /// Every timeline (spinner, meter, counters) stands still at this time in renders.
    static let stillTime: Double = 0.75

    /// AppKit twins of the type steps used on the island, for width maths (VoiceBud measures
    /// the error card the same way).
    // design-ausnahme: NSFont twins of TypeScale.secondarySemibold / secondaryMedium / previewMedium / subtitle
    static let titleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    // design-ausnahme: see above
    static let detailFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    // design-ausnahme: see above
    static let noticeFont = NSFont.systemFont(ofSize: 12.5, weight: .medium)
    // design-ausnahme: see above
    static let counterFont = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
}

/// Timings of the present / dismiss choreography, auto-hide and hover (VoiceBud
/// IslandController, notes §5.4, §6, §7, §9).
enum IslandTiming {
    /// Grow on the next frame after ordering the (transparent) panel in, then fade it in.
    static let presentDelay: Double = 0.016
    static let fadeIn: Double = 0.1
    /// From then on content changes swap instead of entering.
    static let swapAfter: Double = 0.06
    /// Dismiss: leave transition on screen for one frame, collapse, fade, order out.
    static let collapseDelay: Double = 0.02
    static let fadeAtQuick: Double = 0.12
    static let fadeAt: Double = 0.22
    static let fadeOut: Double = 0.22
    static let orderOutAfterFade: Double = 0.26
    /// Notices hide on their own.
    static let noticeHide: Double = 2.5
    /// A done card shows at least this long; a setting of `stays` or more keeps it up.
    static let minConfirm: Double = 0.3
    static let stays: Double = 60
    /// Progress that takes longer: seconds counter from 5 s, the hint card from 10 s.
    static let slowCount: Double = 5
    static let slowHint: Double = 10
    /// Pointer polling while a card can be hovered (30 Hz), grace after leaving, minimum rest.
    static let hoverPoll: Double = 1.0 / 30
    static let hoverTolerance: Double = 1.0 / 120
    static let hoverGrace: Double = 0.6
    static let hoverMinRemaining: Double = 0.8
    /// A pointer resting where the card appeared counts only after moving this far.
    static let parkedSlack: CGFloat = 0.5
    /// Self-heal: check every 0.25 s while running; hidden longer than 0.4 s means gone.
    static let healInterval: Double = 0.25
    static let healGap: Double = 0.4
    /// On-screen verification after ordering in, and at most one rebuild per 5 s.
    static let verifyQuick: Double = 0.06
    static let verifyLate: Double = 0.35
    static let rebuildCooldown: Double = 5
    /// "Copied" feedback on the copy button.
    static let copiedFor: Double = 1.4
    /// Sound volume of the start / done sounds.
    static let soundVolume: Float = 0.22
}

extension Motion.Island {
    /// Reduce Motion: every island change is a 0.2 s cross-fade.
    static var crossFade: Animation { Motion.reduced }
    /// Preview → whole text on hover: the outgoing block fades quickly, the incoming one
    /// enters 50 ms later.
    static var handOverIn: Animation { enter.delay(0.05) }
}
