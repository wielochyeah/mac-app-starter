import Foundation

/// Fires jobs on their schedule. `BackgroundJobs` decides what a fire does; tests inject a fake.
protocol JobScheduling: AnyObject {
    /// (Re)schedules a job; replaces an earlier schedule with the same id. The first fire comes
    /// `delay` seconds from now (catching up with a run missed while the app was not running),
    /// then one every interval. `fire` returns when the run is over (macOS is told the activity
    /// finished only then).
    func schedule(_ schedule: JobSchedule, after delay: TimeInterval, fire: @escaping @MainActor () async -> Void)
    func cancel(_ id: String)
}

/// macOS's `NSBackgroundActivityScheduler` for regular jobs (energy-aware, may defer while the
/// person is busy or on battery), a main run loop `Timer` for `exact` ones. A first run due
/// sooner than one interval (catching up) is a one-shot timer, after which macOS takes over.
final class SystemJobScheduler: JobScheduling {
    private var activities: [String: NSBackgroundActivityScheduler] = [:]
    private var timers: [String: Timer] = [:]
    /// Bumped by every schedule and cancel, so a catch-up run that ends after a cancel or a new
    /// schedule does not start the old repeating activity.
    private var generation: [String: Int] = [:]

    func schedule(_ schedule: JobSchedule, after delay: TimeInterval, fire: @escaping @MainActor () async -> Void) {
        cancel(schedule.id)
        let id = schedule.id
        let gen = generation[id, default: 0]
        let firstFire = Date().addingTimeInterval(max(delay, 0))
        if schedule.exact {
            let timer = Timer(fire: firstFire, interval: schedule.interval, repeats: true) { _ in
                Task { @MainActor in await fire() }
            }
            timer.tolerance = schedule.tolerance
            RunLoop.main.add(timer, forMode: .common)
            timers[id] = timer
            return
        }
        guard delay < schedule.interval else {
            startActivity(schedule, fire: fire)
            return
        }
        let first = Timer(fire: firstFire, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.catchUp(schedule, generation: gen, fire: fire) }
        }
        first.tolerance = min(schedule.tolerance, JobBook.launchGrace)
        RunLoop.main.add(first, forMode: .common)
        timers[id] = first
    }

    /// The one-shot catch-up run; afterwards macOS takes over unless the job was cancelled or
    /// scheduled anew meanwhile.
    private func catchUp(_ schedule: JobSchedule, generation gen: Int, fire: @escaping @MainActor () async -> Void) {
        Task { @MainActor [weak self] in
            await fire()
            self?.resume(schedule, generation: gen, fire: fire)
        }
    }

    private func resume(_ schedule: JobSchedule, generation gen: Int, fire: @escaping @MainActor () async -> Void) {
        guard generation[schedule.id, default: 0] == gen else { return }
        timers.removeValue(forKey: schedule.id)
        startActivity(schedule, fire: fire)
    }

    private func startActivity(_ schedule: JobSchedule, fire: @escaping @MainActor () async -> Void) {
        let activity = NSBackgroundActivityScheduler(identifier: "\(AppInfo.bundleId).job.\(schedule.id)")
        activity.repeats = true
        activity.interval = schedule.interval
        activity.tolerance = schedule.tolerance
        activity.qualityOfService = schedule.qos
        nonisolated(unsafe) let deferCheck = activity
        activity.schedule { completion in
            // the system asks running activities to stop early when the person needs the Mac
            if deferCheck.shouldDefer {
                completion(.deferred)
                return
            }
            Task { @MainActor in
                await fire()
                completion(.finished)
            }
        }
        activities[schedule.id] = activity
    }

    func cancel(_ id: String) {
        generation[id, default: 0] += 1
        activities.removeValue(forKey: id)?.invalidate()
        timers.removeValue(forKey: id)?.invalidate()
    }
}

/// Never fires (renders).
final class NoJobScheduler: JobScheduling {
    func schedule(_ schedule: JobSchedule, after delay: TimeInterval, fire: @escaping @MainActor () async -> Void) {}
    func cancel(_ id: String) {}
}
