import SwiftUI

/// The colour of a badge, spinner or meter on the island (always drawn on black).
enum IslandTint: String, CaseIterable, Equatable, Sendable {
    case accent, teal, amber, sky, green, red

    var colors: IslandAccent {
        switch self {
        case .accent: IslandAccent.of()
        case .teal: IslandAccent.teal
        case .amber: IslandAccent.amber
        case .sky: IslandAccent.sky
        case .green: IslandAccent.of(.gruen)
        case .red: IslandAccent.of(.rot)
        }
    }
}

/// A button on a card: an action on a done card, or Cancel on a progress that takes longer.
/// Two actions are equal when they look the same (id, title, symbol); the closure is not compared.
struct IslandAction: Identifiable, Equatable {
    let id: String
    let title: String
    var symbol: String?
    /// The card closes after the action ran.
    var dismisses: Bool
    let perform: () -> Void

    init(id: String, title: String, symbol: String? = nil, dismisses: Bool = true, perform: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.dismisses = dismisses
        self.perform = perform
    }

    static func == (a: IslandAction, b: IslandAction) -> Bool {
        a.id == b.id && a.title == b.title && a.symbol == b.symbol && a.dismisses == b.dismisses
    }
}

enum IslandNoticeKind: String, CaseIterable, Equatable, Sendable {
    case info, success, warning, error
}

/// What the island shows. Apps call `Island.shared.present(_:)` / `update(_:)` with one of these.
///
///     Island.shared.present(.progress(title: "Exporting", fraction: 0.4))
///     Island.shared.update(.done(title: "Exported", detail: "12 files", body: summary,
///                                actions: [IslandAction(id: "show", title: "Show") { reveal() }]))
///     Island.shared.present(.notice(text: "No connection", kind: .error))
enum IslandContent: Equatable {
    /// Something is going on: badge + short title left of the notch, detail right (e.g. "2:14").
    case activity(symbol: String, title: String, detail: String? = nil, tint: IslandTint = .accent)
    /// Work in progress: a spinner, or a ring when `fraction` (0…1) is known. From 5 s on the
    /// seconds count; from 10 s a small card says it takes longer and offers `cancel`.
    case progress(title: String, fraction: Double? = nil, symbol: String = "arrow.triangle.2.circlepath",
                  tint: IslandTint = .accent, cancel: IslandAction? = nil)
    /// A live level meter (e.g. a microphone): bands 0…1, any count; empty = calm synthetic motion.
    /// Updating only the bands is cheap (`Island.shared.update(.levels(…))` does not re-render).
    case levels([Float], symbol: String = "waveform", tint: IslandTint = .accent)
    /// Finished: a card with title, dim detail and an optional text. Hovering unfolds the whole
    /// text with Copy and the `actions`. Hides after the confirmation time from settings.
    case done(title: String, detail: String? = nil, body: String? = nil, actions: [IslandAction] = [],
              tint: IslandTint = .accent)
    /// A short message that hides itself after 2.5 s.
    case notice(text: String, kind: IslandNoticeKind = .info)

    enum Phase: String, CaseIterable {
        case activity, progress, levels, done, notice
    }

    var phase: Phase {
        switch self {
        case .activity: .activity
        case .progress: .progress
        case .levels: .levels
        case .done: .done
        case .notice: .notice
        }
    }

    /// Something still runs (no auto-hide; the island heals itself while it is up).
    var isRunning: Bool { phase == .activity || phase == .progress || phase == .levels }

    /// The bands of a `.levels` content.
    var bands: [Float]? {
        if case .levels(let b, _, _) = self { return b }
        return nil
    }

    /// The same content without its bands: two levels contents with equal `withoutBands`
    /// differ only in the live values.
    var withoutBands: IslandContent {
        if case .levels(_, let symbol, let tint) = self { return .levels([], symbol: symbol, tint: tint) }
        return self
    }

    /// A done card with something to unfold (text or actions).
    var canExpand: Bool {
        if case .done(_, _, let body, let actions, _) = self {
            return !(body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !actions.isEmpty
        }
        return false
    }

    var cancelAction: IslandAction? {
        if case .progress(_, _, _, _, let cancel) = self { return cancel }
        return nil
    }
}

/// The badge at the left of the ear row or pill.
enum IslandBadgeKind: Equatable {
    case symbol(String, IslandTint)
    case check(IslandTint)
    case notice(IslandNoticeKind)

    /// Identity for transitions: a different badge swaps in.
    var key: String {
        switch self {
        case .symbol(let s, let t): "symbol.\(s).\(t.rawValue)"
        case .check(let t): "check.\(t.rawValue)"
        case .notice(let k): "notice.\(k.rawValue)"
        }
    }

    init(_ content: IslandContent) {
        switch content {
        case .activity(let symbol, _, _, let tint), .progress(_, _, let symbol, let tint, _), .levels(_, let symbol, let tint):
            self = .symbol(symbol, tint)
        case .done(_, _, _, _, let tint):
            self = .check(tint)
        case .notice(_, let kind):
            self = kind == .success ? .check(.accent) : .notice(kind)
        }
    }
}
