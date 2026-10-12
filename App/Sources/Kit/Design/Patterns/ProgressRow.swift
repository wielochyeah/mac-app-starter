import SwiftUI

/// A download or long job in a card (VoiceBud OnboardingModelRow): 28 pt squircle, role (13 `fg`)
/// over name (12 `prose` / 11.5 `fg2`), on the right the size, "1.4 of 3.0 GB", or a status; a
/// 4 pt bar indented 40 pt under the text while running (tint colour) or paused (grey).
///
///     ProgressRow(role: MyText.speechModel, name: "Whisper turbo", symbol: "waveform", tint: .violet,
///                 phase: .running(done: 1_400_000_000, total: 3_000_000_000))
struct ProgressRow: View {
    enum Phase: Equatable {
        /// Not started; shows the size and a grey "Waiting".
        case waiting(total: Int64)
        case running(done: Int64, total: Int64)
        /// Stopped (offline, error); grey bar, "Paused" and a retry chip.
        case paused(done: Int64, total: Int64)
        /// Finished; size and a green "Ready".
        case done(total: Int64)

        /// 0…1 for the bar (nil when no bar is shown).
        var fraction: Double? {
            switch self {
            case .running(let done, let total), .paused(let done, let total):
                total > 0 ? min(max(Double(done) / Double(total), 0), 1) : 0
            case .waiting, .done: nil
            }
        }
    }

    let role: String
    let name: String
    var symbol: String
    var tint: TintName
    let phase: Phase
    var retry: (() -> Void)?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.textTone) private var tone

    init(role: String, name: String, symbol: String, tint: TintName = .accent, phase: Phase, retry: (() -> Void)? = nil) {
        self.role = role
        self.name = name
        self.symbol = symbol
        self.tint = tint
        self.phase = phase
        self.retry = retry
    }

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            HStack(spacing: Space.s) {
                SquircleIcon(symbol: symbol, tint: tint, size: Metrics.progressIcon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(role).font(TypeScale.body).foregroundStyle(t.fg)
                    Text(name).font(tone.small).foregroundStyle(tone.smallColor(t))
                }
                Spacer(minLength: Space.s)
                trailing(t)
            }
            if let fraction = phase.fraction {
                ProgressBar(fraction: fraction, tint: barTint(t))
                    .padding(.leading, Metrics.progressBarIndent)
                    .padding(.top, Metrics.progressRowY)
            }
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Metrics.progressRowY)
        .frame(minHeight: Metrics.rowMinHeight)
        .accessibilityElement(children: .combine)
    }

    private func barTint(_ t: Theme) -> Color {
        if case .paused = phase { return t.fg3 }
        return tint == .accent ? t.accent : (tint.colors.last ?? t.accent)
    }

    @ViewBuilder private func trailing(_ t: Theme) -> some View {
        let digits = tone.small.monospacedDigit()
        switch phase {
        case .waiting(let total):
            HStack(spacing: Space.s) {
                Text(ByteText.size(total)).font(digits).foregroundStyle(tone.smallColor(t))
                StatusMark(.idle, PatternsText.waiting)
            }
        case .running(let done, let total):
            Text(ByteText.progress(done: done, total: total))
                .font(digits)
                .foregroundStyle(tone.smallColor(t))
                .contentTransition(.numericText())
        case .paused:
            HStack(spacing: Space.s) {
                StatusMark(.warn, PatternsText.paused)
                if let retry { Chip(CommonText.retry, symbol: "arrow.clockwise", action: retry) }
            }
        case .done(let total):
            HStack(spacing: Space.s) {
                Text(ByteText.size(total)).font(digits).foregroundStyle(tone.smallColor(t))
                StatusMark(.ok, PatternsText.ready)
            }
        }
    }
}

/// A 4 pt capsule bar on `trackOff`; the fill is at least 4 pt so a start is visible.
struct ProgressBar: View {
    let fraction: Double
    var tint: Color?
    @Environment(\.colorScheme) private var scheme

    init(fraction: Double, tint: Color? = nil) {
        self.fraction = fraction
        self.tint = tint
    }

    var body: some View {
        let t = Theme(scheme)
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(t.trackOff)
                Capsule().fill(tint ?? t.accent)
                    .frame(width: max(Metrics.progressBar, g.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: Metrics.progressBar)
        .animation(.easeOut(duration: 0.3), value: fraction)
        .accessibilityElement()
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

/// Byte counts in the UI language, decimal units like Finder (pure; PatternsTests).
enum ByteText {
    enum Unit { case kb, mb, gb }

    /// The unit `bytes` reads best in: GB from 1 GB, MB from 1 MB, else KB.
    static func unit(for bytes: Int64) -> Unit {
        bytes >= 1_000_000_000 ? .gb : bytes >= 1_000_000 ? .mb : .kb
    }

    /// "0.9 GB" / "0,9 GB", "820 MB", "12 KB" (non-breaking space before the unit).
    static func size(_ bytes: Int64) -> String {
        let unit = unit(for: bytes)
        return value(bytes, in: unit) + "\u{00A0}" + name(unit)
    }

    /// "1.4 of 3.0 GB" / "1,4 von 3,0 GB": both numbers in the total's unit.
    static func progress(done: Int64, total: Int64) -> String {
        let unit = unit(for: total)
        return PatternsText.progress(value(done, in: unit), of: value(total, in: unit) + "\u{00A0}" + name(unit))
    }

    static func value(_ bytes: Int64, in unit: Unit) -> String {
        switch unit {
        case .gb: Format.decimal(Double(bytes) / 1_000_000_000, digits: 1)
        case .mb: Format.decimal(Double(bytes) / 1_000_000, digits: 0)
        case .kb: Format.decimal(max(Double(bytes) / 1_000, bytes > 0 ? 1 : 0), digits: 0)
        }
    }

    static func name(_ unit: Unit) -> String {
        switch unit {
        case .gb: "GB"
        case .mb: "MB"
        case .kb: "KB"
        }
    }
}
