import Foundation
import Observation

/// What a run of a job came to.
nonisolated enum JobOutcome: Equatable, Sendable {
    /// The job did its work; `note` is a short line for the settings list ("3 files").
    case done(note: String? = nil)
    /// It ran and found nothing to do.
    case nothingToDo
    /// It failed (the job threw or reported it); the message is shown in the settings list.
    case failed(String)

    var isFailure: Bool { if case .failed = self { true } else { false } }
}

/// Last run of a job, kept across launches (`JobStore`).
nonisolated struct JobRecord: Equatable, Sendable {
    var lastStart: Date?
    var lastEnd: Date?
    var outcome: JobOutcome?
    var runs = 0
    var failures = 0

    /// Seconds the last finished run took.
    var duration: TimeInterval? {
        guard let lastStart, let lastEnd, lastEnd >= lastStart else { return nil }
        return lastEnd.timeIntervalSince(lastStart)
    }
}

/// The bookkeeping of a run (pure, tested).
nonisolated enum JobBook {
    static func started(_ record: JobRecord, at date: Date) -> JobRecord {
        var r = record
        r.lastStart = date
        return r
    }

    static func finished(_ record: JobRecord, outcome: JobOutcome, at date: Date) -> JobRecord {
        var r = record
        if r.lastStart == nil { r.lastStart = date }
        r.lastEnd = date
        r.outcome = outcome
        r.runs += 1
        if outcome.isFailure { r.failures += 1 }
        return r
    }

    /// The person-facing text of an error a job threw.
    static func message(_ error: Error) -> String {
        if let described = (error as? LocalizedError)?.errorDescription, !described.isEmpty { return described }
        return error.localizedDescription
    }
}

/// When a job runs. `exact: false` (default) hands timing to macOS (`NSBackgroundActivityScheduler`:
/// spreads work, respects energy and the person's activity, may defer); `exact: true` uses a timer
/// on the main run loop for work that must happen at its interval while the app runs.
nonisolated struct JobSchedule: Equatable, Sendable {
    let id: String
    let interval: TimeInterval
    let tolerance: TimeInterval
    let qos: QualityOfService
    let exact: Bool
}

extension SettingKey {
    /// Ids of jobs the person switched off in Settings → Background.
    static var backgroundDisabledJobs: SettingKey<[String]> { .init("background.disabledJobs", default: []) }
}

/// Scheduled background jobs. Register from a module's or feature's `register()`:
///
///     BackgroundJobs.shared.register(id: "cleanup", title: { MyText.cleanup }, interval: 6 * 3600) {
///         let removed = try await Cache.shared.removeExpired()        // runs off the main actor
///         return removed > 0 ? .done(note: MyText.removed(removed)) : .nothingToDo
///     }
///
/// Jobs are scheduled at launch (and at once when registered later), run at most once at a time,
/// can be switched off per job, and record their last run, outcome and duration (SQLite in
/// Application Support, opened only when a job exists). Settings → Background lists them with a
/// "Run Now" button. `@Observable`, so that list follows runs live.
@Observable final class BackgroundJobs {
    static let shared = BackgroundJobs()

    struct Job: Identifiable {
        let id: String
        let title: () -> String
        let schedule: JobSchedule
        let run: @Sendable () async throws -> JobOutcome
    }

    private(set) var jobs: [Job] = []
    private(set) var records: [String: JobRecord] = [:]
    private(set) var running: Set<String> = []
    /// Ids switched off (persisted as `background.disabledJobs`).
    private(set) var disabled: Set<String>

    @ObservationIgnored private let store: JobStore
    @ObservationIgnored private let scheduler: JobScheduling
    @ObservationIgnored private let settings: Settings?
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private(set) var isStarted = false

    /// `settings: nil` keeps the switches in memory (renders start from `disabled`).
    init(store: JobStore = DatabaseJobStore(), scheduler: JobScheduling = SystemJobScheduler(), settings: Settings? = .shared,
         now: @escaping () -> Date = Date.init, running: Set<String> = [], disabled: Set<String> = []) {
        self.store = store
        self.scheduler = scheduler
        self.settings = settings
        self.now = now
        self.running = running
        self.disabled = settings.map { Set($0[.backgroundDisabledJobs]) } ?? disabled
    }

    // MARK: Registration

    /// Adds a job. `tolerance` defaults to a quarter of the interval (lets macOS batch work).
    /// A second registration with the same id is ignored (logged).
    func register(id: String, title: @escaping () -> String, interval: TimeInterval, tolerance: TimeInterval? = nil,
                  qos: QualityOfService = .utility, exact: Bool = false,
                  run: @escaping @Sendable () async throws -> JobOutcome) {
        guard !jobs.contains(where: { $0.id == id }) else {
            Log.error("background: job \(id) registered twice, keeping the first", "background")
            return
        }
        let spec = JobSchedule(id: id, interval: max(interval, 1), tolerance: tolerance ?? interval / 4, qos: qos, exact: exact)
        let job = Job(id: id, title: title, schedule: spec, run: run)
        jobs.append(job)
        loadIfNeeded()
        if isStarted && isEnabled(id) { schedule(job) }
    }

    func job(_ id: String) -> Job? { jobs.first { $0.id == id } }

    // MARK: Scheduling

    /// Schedules every enabled job (launch hook).
    func start() {
        guard !isStarted else { return }
        isStarted = true
        for job in jobs where isEnabled(job.id) { schedule(job) }
    }

    /// Cancels every schedule (terminate hook). Runs in flight finish on their own.
    func stop() {
        for job in jobs { scheduler.cancel(job.id) }
        isStarted = false
    }

    private func schedule(_ job: Job) {
        let id = job.id
        scheduler.schedule(job.schedule) { [weak self] in
            guard let self, self.isEnabled(id) else { return }
            await self.perform(id)
        }
    }

    // MARK: Switches

    func isEnabled(_ id: String) -> Bool { !disabled.contains(id) }

    func setEnabled(_ id: String, _ on: Bool) {
        guard isEnabled(id) != on else { return }
        if on { disabled.remove(id) } else { disabled.insert(id) }
        settings?[.backgroundDisabledJobs] = disabled.sorted()
        guard isStarted, let job = job(id) else { return }
        if on { schedule(job) } else { scheduler.cancel(id) }
    }

    // MARK: Running

    func record(_ id: String) -> JobRecord { records[id] ?? JobRecord() }
    func isRunning(_ id: String) -> Bool { running.contains(id) }

    /// "Run Now": runs the job at once unless it is running (also when switched off: the person
    /// asked for it).
    func runNow(_ id: String) {
        Task { await perform(id) }
    }

    /// Runs a job and records the result. Nil when the job is unknown or already running (runs
    /// never overlap).
    @discardableResult
    func perform(_ id: String) async -> JobOutcome? {
        guard let job = job(id), !running.contains(id) else { return nil }
        running.insert(id)
        records[id] = JobBook.started(record(id), at: now())
        let outcome: JobOutcome
        do {
            outcome = try await job.run()
        } catch {
            outcome = .failed(JobBook.message(error))
        }
        let finished = JobBook.finished(record(id), outcome: outcome, at: now())
        records[id] = finished
        running.remove(id)
        do {
            try store.save(id, finished)
        } catch {
            Log.error("background: saving \(id) failed: \(error)", "background")
        }
        if outcome.isFailure { Log.warn("background: \(id) failed", "background") }
        return outcome
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        do {
            records.merge(try store.load()) { current, _ in current }
        } catch {
            Log.error("background: loading job records failed: \(error)", "background")
        }
    }
}
