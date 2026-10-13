import Observation
import SwiftUI

/// Where an unfinished onboarding continues (step id and its order, so a step that is no longer
/// included still finds its neighbour).
nonisolated struct OnboardingResumePoint: Codable, Sendable, Equatable {
    var id: String
    var order: Int

    static let none = OnboardingResumePoint(id: "", order: 0)
}

extension SettingKey {
    /// The step the onboarding was on. Written on every step change and before anything that can
    /// restart the app, so a restart (Input Monitoring, Screen Recording, macOS's own "Quit &
    /// Reopen") comes back to the same step. VoiceBud lost it (notes gotcha 14).
    static var onboardingResume: SettingKey<OnboardingResumePoint> { .init("onboarding.resume", default: .none) }
    /// Set right before the app may restart from inside the setup ("Restart <App>", or a restart
    /// kind's request or System Settings pane, where macOS offers "Quit & Reopen"): the next
    /// launch opens the setup at `onboardingResume` even when it was finished before (shown again
    /// from Settings). Cleared once a flow used it, on "Done" and when the window is closed.
    static var onboardingReopen: SettingKey<Bool> { .init("onboarding.reopen", default: false) }
    /// Permission ids that were allowed when the setup was last finished. One of them gone at a
    /// later launch (an ad-hoc rebuild has a new signature, or it was revoked) reopens the setup
    /// at that step (VoiceBud `Onboarding.needed()`).
    static var onboardingAllowed: SettingKey<[String]> { .init("onboarding.allowed", default: []) }
}

/// What the footer's advance button does on a step. Steps that hold their own primary action
/// (a permission still missing) make it secondary; a step can rename it ("Skip").
struct OnboardingAdvance: Equatable {
    var isPrimary = true
    var title: String?
    var isEnabled = true
}

/// The onboarding's state: the included steps in order, the current one, the slide direction,
/// persistence and finishing. One flow per open window (rebuilt on every show, released on close).
@Observable final class OnboardingFlow {
    let steps: [OnboardingStep]
    private(set) var index: Int
    /// Direction of the last move (the page slides in from the right when true).
    private(set) var forward = true
    /// The current step's `OnboardingContext.canContinue` (reset to true on every step change).
    var canContinue = true
    let monitor: PermissionMonitor
    /// Advance rules by step id (`OnboardingKit.advanceRules`, copied at creation).
    @ObservationIgnored let rules: [String: (PermissionMonitor) -> OnboardingAdvance]
    @ObservationIgnored private let settings: Settings?
    /// Called once by `finish()` (closes the window and so on).
    @ObservationIgnored var onFinish: () -> Void = {}
    /// Set by `finish()`: a second click on Done (or Return pressed twice) does nothing.
    @ObservationIgnored private(set) var isFinished = false
    /// Set when the app is about to relaunch: closing the window then is not leaving the setup.
    @ObservationIgnored var isRelaunching = false
    /// Ids of the setup's permissions allowed right now. Recorded as `onboardingAllowed` on "Done"
    /// and when a finished setup is closed, so a permission left off on purpose stops reopening it.
    @ObservationIgnored var allowedNow: (() -> [String])?

    /// - settings: where the step and the done flag are saved; nil for renders (nothing written).
    init(steps: [OnboardingStep], monitor: PermissionMonitor = .shared, settings: Settings? = .shared,
         rules: [String: (PermissionMonitor) -> OnboardingAdvance] = [:], startAt: Int? = nil) {
        self.steps = steps
        self.monitor = monitor
        self.settings = settings
        self.rules = rules
        let start = startAt ?? settings.map {
            Self.startIndex(steps: steps.map { ($0.id, $0.order) }, done: $0[.onboardingDone],
                            reopen: $0[.onboardingReopen], resume: $0[.onboardingResume])
        } ?? 0
        index = steps.isEmpty ? 0 : min(max(start, 0), steps.count - 1)
        // the marker brought the setup back once; a later normal launch must not
        if let settings, settings[.onboardingReopen] { settings.reset(.onboardingReopen) }
    }

    // MARK: Reading

    var current: OnboardingStep? { steps.indices.contains(index) ? steps[index] : nil }
    var isFirst: Bool { index == 0 }
    var isLast: Bool { index >= steps.count - 1 }

    /// The footer's advance button for the current step.
    var advance: OnboardingAdvance {
        guard let current else { return OnboardingAdvance() }
        var spec = rules[current.id]?(monitor) ?? OnboardingAdvance()
        if spec.title == nil { spec.title = isLast ? OnboardingText.done : CommonText.continue }
        spec.isEnabled = spec.isEnabled && canContinue
        return spec
    }

    var context: OnboardingContext {
        OnboardingContext(canContinue: Binding(get: { [weak self] in self?.canContinue ?? true },
                                               set: { [weak self] in self?.canContinue = $0 }),
                          next: { [weak self] in self?.next() },
                          back: { [weak self] in self?.back() },
                          index: index, count: steps.count)
    }

    // MARK: Moving

    func next() {
        guard !isFinished else { return }
        if isLast { return finish() }
        go(to: index + 1)
    }

    func back() {
        guard index > 0 else { return }
        go(to: index - 1)
    }

    func go(to target: Int) {
        guard steps.indices.contains(target), target != index else { return }
        let isForward = target > index
        // the leaving page must render with the new direction before it is removed, otherwise it
        // slides out the old way: flip first, commit on the next runloop turn (VoiceBud go(to:))
        if isForward != forward {
            forward = isForward
            DispatchQueue.main.async { [weak self] in self?.commit(target) }
        } else {
            commit(target)
        }
    }

    /// Jumps to the step with this id (the Done page's rows of permissions not allowed yet).
    func go(toStep id: String) {
        if let target = steps.firstIndex(where: { $0.id == id }) { go(to: target) }
    }

    private func commit(_ target: Int) {
        guard steps.indices.contains(target) else { return }
        canContinue = true
        index = target
        save()
    }

    /// Saves the current step (also called right before anything that may restart the app).
    func save() {
        guard let settings, let current else { return }
        settings[.onboardingResume] = OnboardingResumePoint(id: current.id, order: current.order)
    }

    /// Saves the step and asks the next launch to reopen the setup there (right before
    /// anything that may restart the app; VoiceBud lost the step here, notes gotcha 14).
    func prepareRestart() {
        guard let settings else { return }
        save()
        settings[.onboardingReopen] = true
    }

    /// The window was closed without "Done" (not by a relaunch): no reopen on the next launch,
    /// and a setup shown again from Settings (or reopened for a lost permission) forgets its step
    /// and records what is allowed now. A first setup keeps its step.
    func leave() {
        guard !isFinished, !isRelaunching, let settings else { return }
        settings.reset(.onboardingReopen)
        if settings[.onboardingDone] {
            settings.reset(.onboardingResume)
            if let allowed = allowedNow?() { settings[.onboardingAllowed] = allowed }
        }
    }

    /// Marks onboarding done, forgets the step and calls `onFinish`.
    func finish() {
        guard !isFinished else { return }
        isFinished = true
        if let settings {
            if let allowed = allowedNow?() { settings[.onboardingAllowed] = allowed }
            settings[.onboardingDone] = true
            settings.reset(.onboardingResume)
            settings.reset(.onboardingReopen)
        }
        onFinish()
    }

    // MARK: Rules (pure, OnboardingTests)

    /// Where a newly opened onboarding starts: at the top once it was finished (shown again from
    /// Settings) unless a restart from inside the setup asked to `reopen` it, else at the saved
    /// step, else at the first step ordered after it, else at 0.
    nonisolated static func startIndex(steps: [(id: String, order: Int)], done: Bool, reopen: Bool = false,
                                       resume: OnboardingResumePoint) -> Int {
        guard !done || reopen, !resume.id.isEmpty else { return 0 }
        if let same = steps.firstIndex(where: { $0.id == resume.id }) { return same }
        return steps.firstIndex(where: { $0.order >= resume.order }) ?? 0
    }
}
