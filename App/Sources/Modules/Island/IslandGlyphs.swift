import AppKit
import SwiftUI

// The small pieces on the island: badges, record dot, spinner / progress ring, counters, the
// level meter and the buttons of a hovered card. Ported from VoiceBud ui/Island.swift.

/// 20 pt circle at the left of the ear row or pill: a symbol in its tint, the done check, or a
/// notice mark.
struct IslandBadge: View {
    let kind: IslandBadgeKind

    var body: some View {
        Group {
            switch kind {
            case .symbol(let symbol, let tint):
                ZStack {
                    Circle().fill(tint.colors.line.opacity(IslandLook.badgeFill))
                    Image(systemName: symbol)
                        .symbolFont(IslandLook.badgeGlyph, weight: .semibold)
                        .foregroundStyle(tint.colors.line)
                }
            case .check(let tint):
                Circle().fill(tint.colors.line)
                    .overlay(
                        IslandCheckGlyph()
                            .stroke(IslandPalette.surface, style: StrokeStyle(lineWidth: IslandLook.checkLine, lineCap: .round, lineJoin: .round))
                            .frame(width: IslandLook.check, height: IslandLook.check))
            case .notice(let kind):
                ZStack {
                    Circle().fill(Self.color(kind).opacity(IslandLook.badgeFill))
                    Image(systemName: kind == .info ? "info" : "exclamationmark")
                        .symbolFont(IslandLook.badgeGlyph, weight: .bold)
                        .foregroundStyle(Self.color(kind))
                }
            }
        }
        .frame(width: IslandLook.badge, height: IslandLook.badge)
        .accessibilityHidden(true)
    }

    static func color(_ kind: IslandNoticeKind) -> Color {
        switch kind {
        case .info, .success: IslandAccent.of().line
        case .warning: IslandPalette.warning
        case .error: IslandPalette.error
        }
    }
}

/// The red "live" dot with its halo.
struct IslandRecDot: View {
    var body: some View {
        Circle().fill(IslandPalette.rec)
            .frame(width: Metrics.Island.recDot, height: Metrics.Island.recDot)
            .background(Circle().fill(IslandPalette.rec.opacity(IslandLook.recHaloOpacity))
                .frame(width: IslandLook.recHalo, height: IslandLook.recHalo))
            .accessibilityHidden(true)
    }
}

/// 12 pt ring in a 16 pt frame: a spinning arc (one turn per second), or the known fraction.
struct IslandRing: View {
    let tint: IslandTint
    var fraction: Double?
    /// Renders: the spinner stands at this phase.
    var still: Double?

    var body: some View {
        if let fraction {
            ring(from: 0, to: CGFloat(min(max(fraction, 0), 1)), degrees: 0)
        } else if let still {
            ring(from: 0, to: IslandLook.spinnerArc, degrees: still * 360)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
                ring(from: 0, to: IslandLook.spinnerArc,
                     degrees: ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360)
            }
        }
    }

    private func ring(from: CGFloat, to: CGFloat, degrees: Double) -> some View {
        ZStack {
            Circle().stroke(IslandPalette.text.opacity(IslandLook.spinnerTrack), lineWidth: IslandLook.spinnerLine)
            Circle().trim(from: from, to: to)
                .stroke(tint.colors.line, style: StrokeStyle(lineWidth: IslandLook.spinnerLine, lineCap: .round))
                .rotationEffect(.degrees(degrees - 90))
        }
        .frame(width: IslandLook.spinner, height: IslandLook.spinner)
        .frame(width: IslandLook.spinnerFrame, height: IslandLook.spinnerFrame)
        .accessibilityHidden(true)
    }
}

/// Elapsed "m:ss" since `start`, ticking once a second (frozen in stills).
struct IslandTimerText: View {
    let start: Date
    var still: TimeInterval?

    var body: some View {
        if let still {
            label(still)
        } else {
            TimelineView(.periodic(from: start, by: 1)) { ctx in
                label(ctx.date.timeIntervalSince(start))
            }
        }
    }

    private func label(_ t: TimeInterval) -> some View {
        Text(verbatim: IslandLayout.timer(t)) // verbatim: digits only, the same in every language
            .font(TypeScale.subtitle.monospacedDigit())
            .foregroundStyle(IslandPalette.timer)
            .fixedSize()
    }
}

/// "7 s": seconds of a progress that takes longer, from 5 s on.
struct IslandSlowSeconds: View {
    let since: Date
    var still = false

    var body: some View {
        if still {
            label(Date())
        } else {
            TimelineView(.periodic(from: since, by: 1)) { ctx in label(ctx.date) }
        }
    }

    private func label(_ now: Date) -> some View {
        Text(IslandText.counter(max(Int(IslandTiming.slowCount), Int(now.timeIntervalSince(since)))))
            .font(TypeScale.subtitle.monospacedDigit())
            .foregroundStyle(IslandPalette.timer)
            .fixedSize()
    }
}

/// "42 %" next to a progress ring.
struct IslandPercent: View {
    let fraction: Double

    var body: some View {
        Text(IslandText.percent(fraction))
            .font(TypeScale.subtitle.monospacedDigit())
            .foregroundStyle(IslandPalette.timer)
            .fixedSize()
    }
}

// MARK: - Level meter

/// Calm level meter: 4 bars, 2 pt wide with 1.5 pt gaps, 2…14 pt tall (dots in silence), a
/// vertical gradient from lo to hi in the tint. Live bands are smoothed (attack 0.3 / release 0.1 per
/// 60 Hz frame, time-corrected); without bands a synthetic speech rhythm plays (previews).
/// Ported from VoiceBud WaveformView ("fein").
struct IslandMeter: View {
    let tint: IslandTint
    /// Read every frame (not observed), so 30 Hz updates never re-render the island.
    let bands: () -> [Float]
    var still: Double?

    @State private var engine = IslandMeterEngine()

    var body: some View {
        Group {
            if let still {
                canvas(t: still, smooth: false)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
                    canvas(t: ctx.date.timeIntervalSinceReferenceDate, smooth: true)
                }
            }
        }
        .frame(width: IslandLook.meterWidth, height: IslandLook.meterMax)
        .accessibilityHidden(true)
    }

    private func canvas(t: Double, smooth: Bool) -> some View {
        let colors = tint.colors, bands = bands, engine = engine
        return Canvas { gc, size in
            let targets = IslandMeterMath.targets(t: t, bands: bands())
            let heights = smooth ? engine.smooth(targets, t: t) : targets
            IslandMeterMath.draw(gc, size: size, heights: heights, lo: colors.lo, hi: colors.hi)
        }
    }
}

/// Per-view smoothing state, mutated from the Canvas renderer every frame.
final class IslandMeterEngine {
    private var heights: [CGFloat] = []
    private var lastT: Double?

    func smooth(_ targets: [CGFloat], t: Double) -> [CGFloat] {
        if heights.count != targets.count { heights = targets.map { _ in IslandLook.meterMin } }
        let dt = lastT.map { min(max(t - $0, 0), 0.1) } ?? (1.0 / 60)
        lastT = t
        heights = IslandMeterMath.step(heights, toward: targets, frames: dt * 60)
        return heights
    }
}

enum IslandMeterMath {
    /// Below this the input counts as silence (dots).
    static let silence: Float = 0.02
    static let attack: Double = 0.3
    static let release: Double = 0.1

    /// Speech-like loudness: syllables at ~4 Hz inside ~2.6 s phrases, short pauses between.
    static func speech(_ t: Double) -> Double {
        let gate: Double = t.truncatingRemainder(dividingBy: 3.1) < 2.6 ? 1 : 0
        let syllable = 0.5 + 0.5 * sin(t * 27.0) * sin(t * 10.7 + 1.3)
        return gate * (0.15 + 0.85 * max(0, syllable))
    }

    static func jitter(_ i: Int, _ t: Double) -> Double {
        let d = Double(i)
        return 0.5 + 0.5 * sin(t * (3.4 + d * 0.9) + d * 2.1) * sin(t * (1.7 + d * 0.5) + d)
    }

    /// Bar heights for any number of 0…1 bands: they are folded into the 4 bars (low-mid voice
    /// energy in the middle, highs lifted at the edges like VoiceBud's "fein" mapping).
    static func targets(t: Double, bands b: [Float]) -> [CGFloat] {
        let n = IslandLook.meterBars
        let span = IslandLook.meterMax - IslandLook.meterMin
        guard !b.isEmpty else {
            let env = speech(t)
            return (0..<n).map { i in IslandLook.meterMin + CGFloat(0.8 * env * (0.5 + 0.5 * jitter(i, t))) * span }
        }
        if (b.max() ?? 0) < silence { return Array(repeating: IslandLook.meterMin, count: n) }
        let groups = fold(b, into: n)
        let lift = [1.1, 1.0, 1.0, 1.7]
        let order = [2, 0, 1, 3]
        return (0..<n).map { i in
            let v = min(1, groups[order[i]] * lift[i]) * 0.95
            return IslandLook.meterMin + CGFloat(max(0, min(1, v))) * span
        }
    }

    /// Averages `bands` into `n` groups (low to high).
    static func fold(_ bands: [Float], into n: Int) -> [Double] {
        (0..<n).map { g in
            let lo = g * bands.count / n, hi = max(lo + 1, (g + 1) * bands.count / n)
            let slice = bands[min(lo, bands.count - 1)..<min(hi, bands.count)]
            return Double(slice.map { max(0, min(1, $0)) }.reduce(0, +)) / Double(max(1, slice.count))
        }
    }

    /// One smoothing step, time-corrected: `frames` = elapsed 60 Hz frames.
    static func step(_ heights: [CGFloat], toward targets: [CGFloat], frames: Double) -> [CGFloat] {
        zip(heights, targets).map { h, target in
            let a = target > h ? attack : release
            let k = CGFloat(1 - pow(1 - a, frames))
            return h + (target - h) * k
        }
    }

    static func draw(_ gc: GraphicsContext, size: CGSize, heights: [CGFloat], lo: Color, hi: Color) {
        let n = heights.count
        let total = CGFloat(n) * IslandLook.meterBar + CGFloat(n - 1) * IslandLook.meterGap
        var x = (size.width - total) / 2
        let gradient = Gradient(colors: [lo, hi])
        for h in heights {
            let hh = max(IslandLook.meterMin, min(IslandLook.meterMax, h))
            let r = CGRect(x: x, y: (size.height - hh) / 2, width: IslandLook.meterBar, height: hh)
            gc.fill(Path(roundedRect: r, cornerRadius: IslandLook.meterBar / 2),
                    with: .linearGradient(gradient, startPoint: CGPoint(x: r.midX, y: r.maxY), endPoint: CGPoint(x: r.midX, y: r.minY)))
            x += IslandLook.meterBar + IslandLook.meterGap
        }
    }
}

// MARK: - Buttons on black

/// Trackpad haptics like Alcove's: a light tick when the pointer reaches a card or a button, a
/// firmer one on a click. Force Touch trackpads only; harmless elsewhere.
enum IslandHaptic {
    static func tick() {
        guard IslandPrefs.current.haptics, !RenderMode.isHeadless else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func click() {
        guard IslandPrefs.current.haptics, !RenderMode.isHeadless else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

/// Press feedback on island buttons (opacity 0.6, scale 0.96).
struct IslandPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? Motion.Island.pressOpacity : 1)
            .scaleEffect(configuration.isPressed ? Motion.Island.pressScale : 1)
            .animation(Motion.fade, value: configuration.isPressed)
    }
}

/// A small button on a card: text on white 14 %, 22 pt tall, radius 7. `reserving` lists other
/// labels the button can switch to: it is as wide as the widest, so it never jumps.
struct IslandButton: View {
    let title: String
    var symbol: String?
    var reserving: [(title: String, symbol: String?)] = []
    /// Accent text (the "Copied" state).
    var highlighted = false
    var still = false
    let action: () -> Void

    var body: some View {
        Button {
            guard !still else { return }
            IslandHaptic.click()
            action()
        } label: {
            ZStack {
                ForEach(Array(reserving.enumerated()), id: \.offset) { _, other in
                    label(other.title, symbol: other.symbol).hidden()
                }
                label(title, symbol: symbol)
                    .foregroundStyle(highlighted ? IslandAccent.of().line : IslandPalette.text.opacity(IslandLook.buttonText))
            }
            .padding(.horizontal, IslandLook.buttonX)
            .frame(height: Metrics.Island.copyButtonHeight)
            .background(RoundedRectangle(cornerRadius: IslandLook.buttonRadius, style: .continuous).fill(IslandPalette.button))
            .contentShape(RoundedRectangle(cornerRadius: IslandLook.buttonRadius, style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { inside in if inside && !still { IslandHaptic.tick() } }
        .accessibilityLabel(title)
    }

    private func label(_ title: String, symbol: String?) -> some View {
        HStack(spacing: IslandLook.buttonLabelGap) {
            if let symbol { Image(systemName: symbol).font(TypeScale.micro) }
            Text(title).lineLimit(1)
        }
        .font(TypeScale.subtitleMedium)
    }
}

/// "Copy" on a hovered card: puts the whole text on the pasteboard and answers "Copied" with a
/// check for 1.4 s.
struct IslandCopyButton: View {
    let text: String
    var still = false
    var stillCopied = false

    @State private var copied = false
    @State private var resetWork: DispatchWorkItem?

    var body: some View {
        let done = copied || stillCopied
        IslandButton(title: done ? CommonText.copied : CommonText.copy, symbol: done ? "checkmark" : nil,
                     reserving: [(CommonText.copy, nil), (CommonText.copied, "checkmark")],
                     highlighted: done, still: still) { copy() }
            .accessibilityLabel(done ? CommonText.copied : IslandText.copyText)
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        withAnimation(Motion.fade) { copied = true }
        resetWork?.cancel()
        let work = DispatchWorkItem { withAnimation(Motion.reduced) { copied = false } }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + IslandTiming.copiedFor, execute: work)
    }
}

/// Start and done sounds (off by default; system sounds, quiet, overlapping plays allowed).
enum IslandSound {
    static func play(_ name: String) {
        guard IslandPrefs.current.sounds, !RenderMode.isHeadless,
              let sound = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else { return }
        sound.volume = IslandTiming.soundVolume
        sound.play()
    }
}
