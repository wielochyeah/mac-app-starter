import Foundation

/// Fires jobs on their schedule. `BackgroundJobs` decides what a fire does; tests inject a fake.
protocol JobScheduling: AnyObject {
    /// (Re)schedules a job; replaces an earlier schedule with the same id. `fire` returns when the
    /// run is over (macOS is told the activity finished only then).
    func schedule(_ schedule: JobSchedule, fire: @escaping @MainActor () async -> Void)
    func cancel(_ id: String)
}

/// macOS's `NSBackgroundActivityScheduler` for regular jobs (energy-aware, may defer while the
/// person is busy or on battery), a main run loop `Timer` for `exact` ones.
final class SystemJobScheduler: JobScheduling {
    private var activities: [String: NSBackgroundActivityScheduler] = [:]
    private var timers: [String: Timer] = [:]

    func schedule(_ schedule: JobSchedule, fire: @escaping @MainActor () async -> Void) {
        cancel(schedule.id)
        if schedule.exact {
            let timer = Timer(timeInterval: schedule.interval, repeats: true) { _ in
                Task { @MainActor in await fire() }
            }
            timer.tolerance = schedule.tolerance
            RunLoop.main.add(timer, forMode: .common)
            timers[schedule.id] = timer
            return
        }
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
        activities.removeValue(forKey: id)?.invalidate()
        timers.removeValue(forKey: id)?.invalidate()
    }
}

/// Never fires (renders).
final class NoJobScheduler: JobScheduling {
    func schedule(_ schedule: JobSchedule, fire: @escaping @MainActor () async -> Void) {}
    func cancel(_ id: String) {}
}
