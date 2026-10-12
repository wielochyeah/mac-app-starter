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

    /// - settings: where the step and the done flag are saved; nil for renders (nothing written).
    init(steps: [OnboardingStep], monitor: PermissionMonitor = .shared, settings: Settings? = .shared,
         rules: [String: (PermissionMonitor) -> OnboardingAdvance] = [:], startAt: Int? = nil) {
        self.steps = steps
        self.monitor = monitor
        self.settings = settings
        self.rules = rules
        let start = startAt ?? settings.map {
            Self.startIndex(steps: steps.map { ($0.id, $0.order) }, done: $0[.onboardingDone], resume: $0[.onboardingResume])
        } ?? 0
        index = steps.isEmpty ? 0 : min(max(start, 0), steps.count - 1)
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

    /// Marks onboarding done, forgets the step and calls `onFinish`.
    func finish() {
        guard !isFinished else { return }
        isFinished = true
        if let settings {
            settings[.onboardingDone] = true
            settings.reset(.onboardingResume)
        }
        onFinish()
    }

    // MARK: Rules (pure, OnboardingTests)

    /// Where a newly opened onboarding starts: at the top once it was finished (shown again from
    /// Settings), else at the saved step, else at the first step ordered after it, else at 0.
    nonisolated static func startIndex(steps: [(id: String, order: Int)], done: Bool, resume: OnboardingResumePoint) -> Int {
        guard !done, !resume.id.isEmpty else { return 0 }
        if let same = steps.firstIndex(where: { $0.id == resume.id }) { return same }
        return steps.firstIndex(where: { $0.order >= resume.order }) ?? 0
    }
}
