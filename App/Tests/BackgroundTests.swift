#if TESTING
#if MODUL_BACKGROUND
import AppKit
import ServiceManagement
import SwiftUI

/// Records schedule/cancel calls and fires on demand (no real scheduler, no waiting).
final class FakeJobScheduler: JobScheduling {
    private(set) var scheduled: [String: JobSchedule] = [:]
    private(set) var delays: [String: TimeInterval] = [:]
    private(set) var fires: [String: @MainActor () async -> Void] = [:]
    private(set) var cancels: [String] = []

    func schedule(_ schedule: JobSchedule, after delay: TimeInterval, fire: @escaping @MainActor () async -> Void) {
        scheduled[schedule.id] = schedule
        delays[schedule.id] = delay
        fires[schedule.id] = fire
    }

    func cancel(_ id: String) {
        scheduled.removeValue(forKey: id)
        fires.removeValue(forKey: id)
        cancels.append(id)
    }

    func fire(_ id: String) async { await fires[id]?() }
}

/// A clock the test moves by hand.
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

/// Lets a job wait until the test opens it.
final class JobGate: @unchecked Sendable {
    let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() { (stream, continuation) = AsyncStream<Void>.makeStream() }

    func open() { continuation.yield() }

    func wait() async {
        for await _ in stream { break }
    }
}

private struct Broken: LocalizedError {
    var errorDescription: String? { "disk full" }
}

final class BackgroundTests: TestSuite {
    final class Flag {
        var value = false
    }

    /// Runs `body` on the main actor and spins the run loop until it finished (max 5 s).
    static func run(_ body: @escaping @MainActor () async -> Void) {
        let done = Flag()
        Task { @MainActor in
            await body()
            done.value = true
        }
        let deadline = Date().addingTimeInterval(5)
        while !done.value && Date() < deadline { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005)) }
        expect(done.value, "async body did not finish")
    }

    static func spin(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !condition() && Date() < deadline { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005)) }
    }

    static func make(store: JobStore = MemoryJobStore(), scheduler: JobScheduling = FakeJobScheduler(), settings: Settings? = nil,
                     clock: TestClock = TestClock()) -> BackgroundJobs {
        BackgroundJobs(store: store, scheduler: scheduler, settings: settings, now: { clock.now })
    }

    static func withLang(_ lang: Lang, _ body: () -> Void) {
        let saved = Localizer.shared.forced
        Localizer.shared.forced = lang
        defer { Localizer.shared.forced = saved }
        body()
    }

    override class func register() {
        // MARK: Bookkeeping

        test("a finished run counts, keeps the outcome and the duration") {
            let start = Date(timeIntervalSince1970: 100)
            var r = JobBook.started(JobRecord(), at: start)
            expectEqual(r.lastStart, start)
            expectEqual(r.runs, 0)
            r = JobBook.finished(r, outcome: .done(note: "3"), at: start.addingTimeInterval(2.5))
            expectEqual(r.runs, 1)
            expectEqual(r.failures, 0)
            expectEqual(r.duration, 2.5)
            expectEqual(r.outcome, .done(note: "3"))
            r = JobBook.finished(JobBook.started(r, at: start.addingTimeInterval(10)), outcome: .failed("x"), at: start.addingTimeInterval(11))
            expectEqual(r.runs, 2)
            expectEqual(r.failures, 1)
            expectEqual(r.duration, 1)
        }

        test("error messages prefer the localized description") {
            expectEqual(JobBook.message(Broken()), "disk full")
            expect(!JobBook.message(CocoaError(.fileNoSuchFile)).isEmpty)
        }

        // MARK: Store

        test("outcome columns round-trip, unknown kinds read as none") {
            for outcome in [JobOutcome.done(), .done(note: "12 files"), .nothingToDo, .failed("offline")] {
                let (kind, detail) = DatabaseJobStore.columns(outcome)
                expectEqual(DatabaseJobStore.outcome(kind: kind, detail: detail), outcome)
            }
            expectEqual(DatabaseJobStore.outcome(kind: "exploded", detail: "?"), nil)
            expectEqual(DatabaseJobStore.outcome(kind: nil, detail: nil), nil)
        }

        test("the SQLite store keeps records across instances") {
            let url = tempDir().appendingPathComponent("background.sqlite")
            var record = JobRecord(lastStart: Date(timeIntervalSince1970: 10), lastEnd: Date(timeIntervalSince1970: 12),
                                   outcome: .failed("nope"), runs: 3, failures: 1)
            do {
                let store = DatabaseJobStore(url: url)
                expectEqual(try store.load(), [:])
                try store.save("a", record)
                record.runs = 4
                try store.save("a", record)   // upsert
                try store.save("b", JobRecord())
            } catch { return fail("\(error)") }
            expect(FileManager.default.fileExists(atPath: url.path))
            let loaded = try? DatabaseJobStore(url: url).load()
            expectEqual(loaded?["a"], record)
            expectEqual(loaded?["b"], JobRecord())
            expectEqual(loaded?.count, 2)
        }

        test("the store creates no file until it is used") {
            let url = tempDir().appendingPathComponent("never.sqlite")
            _ = DatabaseJobStore(url: url)
            expect(!FileManager.default.fileExists(atPath: url.path))
        }

        // MARK: Registration and scheduling

        test("register loads stored records and ignores a second registration") {
            let store = MemoryJobStore(["a": JobRecord(runs: 7)])
            let jobs = make(store: store)
            jobs.register(id: "a", title: { "A" }, interval: 600) { .done() }
            jobs.register(id: "a", title: { "A2" }, interval: 60) { .done() }
            expectEqual(jobs.jobs.count, 1)
            expectEqual(jobs.job("a")?.title(), "A")
            expectEqual(jobs.record("a").runs, 7)
            expectEqual(jobs.job("a")?.schedule.tolerance, 150, "a quarter of the interval by default")
        }

        test("start schedules enabled jobs; later registrations are scheduled at once; stop cancels") {
            let scheduler = FakeJobScheduler()
            let jobs = BackgroundJobs(store: MemoryJobStore(), scheduler: scheduler, settings: nil, disabled: ["off"])
            jobs.register(id: "on", title: { "On" }, interval: 3600, qos: .background) { .done() }
            jobs.register(id: "off", title: { "Off" }, interval: 3600) { .done() }
            expectEqual(scheduler.scheduled.count, 0, "nothing before start")
            jobs.start()
            expectEqual(Set(scheduler.scheduled.keys), ["on"])
            expectEqual(scheduler.scheduled["on"]?.qos, .background)
            jobs.register(id: "late", title: { "Late" }, interval: 60, exact: true) { .done() }
            expectEqual(scheduler.scheduled["late"]?.exact, true)
            jobs.stop()
            expectEqual(scheduler.scheduled.count, 0)
            expectEqual(Set(scheduler.cancels), ["on", "off", "late"])
        }

        test("exact jobs get at most a second of tolerance by default") {
            expectEqual(JobSchedule.defaultTolerance(interval: 3600, exact: false), 900)
            expectEqual(JobSchedule.defaultTolerance(interval: 60, exact: true), 1)
            expectEqual(JobSchedule.defaultTolerance(interval: 5, exact: true), 0.5)
            let jobs = make()
            jobs.register(id: "tick", title: { "Tick" }, interval: 60, exact: true) { .done() }
            expectEqual(jobs.job("tick")?.schedule.tolerance, 1)
            jobs.register(id: "own", title: { "Own" }, interval: 60, tolerance: 5, exact: true) { .done() }
            expectEqual(jobs.job("own")?.schedule.tolerance, 5, "an explicit tolerance stays")
        }

        test("first run: overdue or never run soon after launch, else the rest of the interval") {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let grace = JobBook.launchGrace
            expectEqual(JobBook.firstDelay(lastEnd: nil, interval: 86_400, now: now), grace)
            expectEqual(JobBook.firstDelay(lastEnd: now.addingTimeInterval(-2 * 86_400), interval: 86_400, now: now), grace)
            expectEqual(JobBook.firstDelay(lastEnd: now.addingTimeInterval(-20 * 60), interval: 3600, now: now), 40 * 60)
            expectEqual(JobBook.firstDelay(lastEnd: now.addingTimeInterval(-3598), interval: 3600, now: now), grace, "not sooner than the grace")
            expectEqual(JobBook.firstDelay(lastEnd: now.addingTimeInterval(600), interval: 3600, now: now), 3600, "clock went back")
        }

        test("start uses the stored last run: a weekly job overdue after restarts runs, a fresh one waits") {
            let clock = TestClock()
            let scheduler = FakeJobScheduler()
            let store = MemoryJobStore([
                "weekly": JobRecord(lastStart: clock.now.addingTimeInterval(-8 * 86_400), lastEnd: clock.now.addingTimeInterval(-8 * 86_400),
                                    outcome: .done(), runs: 3),
                "hourly": JobRecord(lastStart: clock.now.addingTimeInterval(-900), lastEnd: clock.now.addingTimeInterval(-900),
                                    outcome: .done(), runs: 9),
            ])
            let jobs = make(store: store, scheduler: scheduler, clock: clock)
            jobs.register(id: "weekly", title: { "W" }, interval: 7 * 86_400) { .done() }
            jobs.register(id: "hourly", title: { "H" }, interval: 3600) { .done() }
            jobs.register(id: "new", title: { "N" }, interval: 86_400) { .done() }
            jobs.start()
            expectEqual(scheduler.delays["weekly"], JobBook.launchGrace)
            expectEqual(scheduler.delays["hourly"], 2700)
            expectEqual(scheduler.delays["new"], JobBook.launchGrace)
        }

        test("switching a job off cancels it, on schedules it, and the choice is saved") {
            let settings = Settings(fileURL: tempDir().appendingPathComponent("settings.json"))
            let scheduler = FakeJobScheduler()
            let jobs = BackgroundJobs(store: MemoryJobStore(), scheduler: scheduler, settings: settings)
            jobs.register(id: "a", title: { "A" }, interval: 600) { .done() }
            jobs.start()
            jobs.setEnabled("a", false)
            expect(!jobs.isEnabled("a"))
            expect(scheduler.scheduled["a"] == nil)
            expectEqual(settings[.backgroundDisabledJobs], ["a"])
            let reread = BackgroundJobs(store: MemoryJobStore(), scheduler: FakeJobScheduler(),
                                        settings: Settings(fileURL: settings.fileURL))
            expect(!reread.isEnabled("a"), "persisted")
            jobs.setEnabled("a", true)
            expect(scheduler.scheduled["a"] != nil)
            expectEqual(settings[.backgroundDisabledJobs], [])
        }

        // MARK: Running

        test("a scheduled fire runs the job and records outcome and duration") {
            let scheduler = FakeJobScheduler()
            let clock = TestClock()
            let store = MemoryJobStore()
            let jobs = make(store: store, scheduler: scheduler, clock: clock)
            jobs.register(id: "a", title: { "A" }, interval: 600) {
                await MainActor.run { clock.advance(1.5) }
                return .done(note: "ok")
            }
            jobs.start()
            run { await scheduler.fire("a") }
            let record = jobs.record("a")
            expectEqual(record.outcome, .done(note: "ok"))
            expectEqual(record.runs, 1)
            expectEqual(record.duration, 1.5)
            expectEqual(store.records["a"], record, "saved")
            expect(!jobs.isRunning("a"))
        }

        test("the documented example compiles: a note from a main-actor text") {
            let jobs = make()
            jobs.register(id: "cleanup", title: { BackgroundSampleText.cleanup }, interval: 6 * 3600) {
                let removed = await Task.detached { 12 }.value      // work off the main actor
                guard removed > 0 else { return .nothingToDo }
                return .done(note: await MainActor.run { BackgroundText.every(TimeInterval(removed)) })
            }
            run {
                let outcome = await jobs.perform("cleanup")
                expectEqual(outcome, .done(note: BackgroundText.every(12)))
            }
        }

        test("a thrown error is recorded as a failure with its message") {
            let jobs = make()
            jobs.register(id: "a", title: { "A" }, interval: 600) { throw Broken() }
            run {
                let outcome = await jobs.perform("a")
                expectEqual(outcome, .failed("disk full"))
            }
            expectEqual(jobs.record("a").failures, 1)
        }

        test("runs never overlap; Run Now works while switched off") {
            let gate = JobGate()
            let jobs = BackgroundJobs(store: MemoryJobStore(), scheduler: FakeJobScheduler(), settings: nil, disabled: ["a"])
            jobs.register(id: "a", title: { "A" }, interval: 600) {
                await gate.wait()
                return .nothingToDo
            }
            jobs.runNow("a")
            spin { jobs.isRunning("a") }
            expect(jobs.isRunning("a"), "Run Now started the switched-off job")
            run {
                let second = await jobs.perform("a")
                expectEqual(second, nil, "a second run while the first is going is refused")
            }
            gate.open()
            spin { !jobs.isRunning("a") }
            expectEqual(jobs.record("a").outcome, .nothingToDo)
            expectEqual(jobs.record("a").runs, 1)
        }

        test("a fire for a job switched off after scheduling does nothing; unknown ids return nil") {
            let scheduler = FakeJobScheduler()
            let jobs = make(scheduler: scheduler)
            jobs.register(id: "a", title: { "A" }, interval: 600) { .done() }
            jobs.start()
            let fire = scheduler.fires["a"]
            jobs.setEnabled("a", false)
            run { await fire?() }
            expectEqual(jobs.record("a").runs, 0)
            run {
                let missing = await jobs.perform("missing")
                expectEqual(missing, nil)
            }
        }

        test("self-test flags bad schedules") {
            let jobs = make()
            jobs.register(id: "ok", title: { "OK" }, interval: 600) { .done() }
            expectEqual(BackgroundSelfTest.jobs(jobs.jobs), nil)
            jobs.register(id: "bad", title: { "Bad" }, interval: 60, tolerance: 120) { .done() }
            expect(BackgroundSelfTest.jobs(jobs.jobs)?.contains("bad") == true)
            let untitled = make()
            untitled.register(id: "x", title: { "" }, interval: 60) { .done() }
            expect(BackgroundSelfTest.jobs(untitled.jobs) != nil)
        }

        // MARK: Texts

        test("intervals read naturally in both languages") {
            withLang(.en) {
                expectEqual(BackgroundText.every(1), "Every second")
                expectEqual(BackgroundText.every(30), "Every 30 seconds")
                expectEqual(BackgroundText.every(60), "Every minute")
                expectEqual(BackgroundText.every(15 * 60), "Every 15 minutes")
                expectEqual(BackgroundText.every(90 * 60), "Every 90 minutes")
                expectEqual(BackgroundText.every(3600), "Hourly")
                expectEqual(BackgroundText.every(6 * 3600), "Every 6 hours")
                expectEqual(BackgroundText.every(86_400), "Daily")
                expectEqual(BackgroundText.every(2 * 86_400), "Every 2 days")
                expectEqual(BackgroundText.every(7 * 86_400), "Weekly")
            }
            withLang(.de) {
                expectEqual(BackgroundText.every(30), "Alle 30 Sekunden")
                expectEqual(BackgroundText.every(60), "Jede Minute")
                expectEqual(BackgroundText.every(15 * 60), "Alle 15 Minuten")
                expectEqual(BackgroundText.every(3600), "Stündlich")
                expectEqual(BackgroundText.every(6 * 3600), "Alle 6 Stunden")
                expectEqual(BackgroundText.every(86_400), "Täglich")
                expectEqual(BackgroundText.every(7 * 86_400), "Wöchentlich")
            }
        }

        test("last run reads relative to now") {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            withLang(.en) {
                expectEqual(BackgroundText.ago(now.addingTimeInterval(-20), now: now), "just now")
                expectEqual(BackgroundText.ago(now.addingTimeInterval(-240), now: now), "4 minutes ago")
                expectEqual(BackgroundText.summary(interval: 1800, lastRun: now.addingTimeInterval(-240), now: now),
                            "Every 30 minutes, last run 4 minutes ago")
                expectEqual(BackgroundText.summary(interval: 1800, lastRun: nil, now: now), "Every 30 minutes")
            }
            withLang(.de) {
                expectEqual(BackgroundText.ago(now.addingTimeInterval(-20), now: now), "gerade eben")
                expectEqual(BackgroundText.ago(now.addingTimeInterval(-240), now: now), "vor 4 Minuten")
                expectEqual(BackgroundText.summary(interval: 3600, lastRun: now.addingTimeInterval(-7200), now: now),
                            "Stündlich, zuletzt vor 2 Stunden")
            }
        }

        test("outcome words and badge tones") {
            withLang(.de) {
                expectEqual(BackgroundText.outcome(nil), "Noch nicht gelaufen")
                expectEqual(BackgroundText.outcome(.done()), "Erledigt")
                expectEqual(BackgroundText.outcome(.done(note: "3 Dateien")), "3 Dateien")
                expectEqual(BackgroundText.outcome(.failed("x")), "Fehlgeschlagen")
            }
            expectEqual(JobRow.tone(.done()), .ok)
            expectEqual(JobRow.tone(.failed("x")), .warn)
            expectEqual(JobRow.tone(.nothingToDo), .neutral)
            expectEqual(JobRow.tone(nil), .neutral)
            expectEqual(JobRow.tone(.done(), enabled: false), .neutral, "a switched-off job's badge is grey")
            expectEqual(JobRow.tone(.failed("x"), enabled: false), .neutral)
        }

        // MARK: Login item

        test("login item only for the installed app") {
            let home = "/Users/me"
            expectEqual(LoginItem.availability(bundlePath: "/Applications/Starter.app", isBundle: true, home: home), nil)
            expectEqual(LoginItem.availability(bundlePath: "/Users/me/Applications/Starter.app", isBundle: true, home: home), nil)
            expectEqual(LoginItem.availability(bundlePath: "/Applications/Tools/Starter.app", isBundle: true, home: home), nil)
            expectEqual(LoginItem.availability(bundlePath: "/Users/me/dev/app/build/Starter.app", isBundle: true, home: home), .notInstalled)
            expectEqual(LoginItem.availability(bundlePath: "/Users/me/Applications-old/Starter.app", isBundle: true, home: home), .notInstalled)
            expectEqual(LoginItem.availability(bundlePath: "/Volumes/Starter 1.0/Starter.app", isBundle: true, home: home), .diskImage)
            expectEqual(LoginItem.availability(
                bundlePath: "/private/var/folders/x/AppTranslocation/ABC/d/Starter.app", isBundle: true, home: home), .translocated)
            expectEqual(LoginItem.availability(bundlePath: "/Applications/Starter.app", isBundle: false, home: home), .notBundle)
            expectEqual(LoginItem.availability(bundlePath: "/Applications/../Users/me/x/Starter.app", isBundle: true, home: home),
                        .notInstalled, "paths are standardized")
            expect(!LoginItem.isAvailable, "the test binary is not an installed app")
            expectEqual(LoginItem.status, .unavailable)
        }

        test("login item status mapping and when macOS is called") {
            expectEqual(LoginItem.map(.enabled), .enabled)
            expectEqual(LoginItem.map(.requiresApproval), .requiresApproval)
            expectEqual(LoginItem.map(.notRegistered), .disabled)
            expectEqual(LoginItem.map(.notFound), .disabled)
            expect(LoginItem.needsChange(to: true, from: .disabled))
            expect(!LoginItem.needsChange(to: false, from: .disabled))
            expect(LoginItem.needsChange(to: false, from: .enabled))
            expect(!LoginItem.needsChange(to: true, from: .enabled))
            expect(LoginItem.needsChange(to: false, from: .requiresApproval))
            expect(!LoginItem.needsChange(to: true, from: .unavailable))
            expect(!LoginItem.needsChange(to: false, from: .unavailable))
        }

        test("onboarding switch: a pending choice wins, else on in a first setup, later what macOS reports") {
            expect(LoginItemStepRule.initial(status: .disabled, asked: false))
            expect(!LoginItemStepRule.initial(status: .disabled, asked: true))
            expect(LoginItemStepRule.initial(status: .enabled, asked: true))
            expect(LoginItemStepRule.initial(status: .requiresApproval, asked: true))
            expect(!LoginItemStepRule.initial(status: .disabled, asked: false, pending: false), "the person switched it off earlier")
            expect(LoginItemStepRule.initial(status: .disabled, asked: true, pending: true))
        }

        test("the setup choice is applied only once onboarding is done, never on Back or close") {
            expect(!LoginWish.isDue(onboardingDone: false, pending: true))
            expect(!LoginWish.isDue(onboardingDone: true, pending: nil))
            expect(LoginWish.isDue(onboardingDone: true, pending: false))
            let settings = Settings(fileURL: tempDir().appendingPathComponent("settings.json"))
            let login = LoginItemModel(status: .disabled)
            expect(!LoginWish.applyIfDue(settings: settings, login: login), "no wish, nothing to do")
            // the step recorded its default (on); the person went back or closed the window
            settings[.backgroundLoginWish] = true
            expect(!LoginWish.applyIfDue(settings: settings, login: login))
            expectEqual(login.status, .disabled, "nothing registered while onboarding runs")
            expectEqual(LoginWish.pending(settings), true, "the wish waits for the next setup")
            // onboarding finished
            settings[.onboardingDone] = true
            expect(LoginWish.applyIfDue(settings: settings, login: login))
            expectEqual(login.status, .enabled)
            expectEqual(LoginWish.pending(settings), nil, "applied once")
            expect(settings[.backgroundLoginAsked])
            expect(!LoginWish.applyIfDue(settings: settings, login: login))
            // a wish "off" against an enabled item switches it off
            settings[.backgroundLoginWish] = false
            expect(LoginWish.applyIfDue(settings: settings, login: login))
            expectEqual(login.status, .disabled)
        }

        test("a login launch is told by the launch Apple event") {
            let open = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEOpenApplication),
                                              targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                              transactionID: AETransactionID(kAnyTransactionID))
            expect(!LoginItem.isLoginLaunch(open), "a plain launch")
            open.setParam(NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem)), forKeyword: AEKeyword(keyAEPropData))
            expect(LoginItem.isLoginLaunch(open), "opened as a login item")
            let reopen = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication),
                                                targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                                transactionID: AETransactionID(kAnyTransactionID))
            reopen.setParam(NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem)), forKeyword: AEKeyword(keyAEPropData))
            expect(!LoginItem.isLoginLaunch(reopen), "only the open event counts")
            expect(!LoginItem.isLoginLaunch(nil))
            expect(!LoginItem.launchedAtLogin, "tests are not launched at login")
        }

        test("a preview login model changes only what it shows") {
            let model = LoginItemModel(status: .disabled)
            model.set(true)
            expectEqual(model.status, .enabled)
            expect(model.isOn)
            let unavailable = LoginItemModel(status: .unavailable, unavailable: .notInstalled)
            unavailable.set(true)
            expectEqual(unavailable.status, .unavailable)
        }

        test("every unavailable reason has words in both languages") {
            for lang in Lang.allCases {
                withLang(lang) {
                    let texts = [LoginItem.Unavailable.notBundle, .diskImage, .translocated, .notInstalled].map(BackgroundText.unavailable)
                    expectEqual(Set(texts).count, 4)
                }
            }
        }

        // MARK: Registration and scenes

        test("register adds the pane, the onboarding step (900, not for this binary), hooks and scenes") {
            Registry.withScratch {
                BackgroundModule.register()
                expectEqual(Registry.settingsPanes.map(\.id), ["background"])
                expectEqual(Registry.onboardingSteps.map(\.id), ["background.login"])
                expectEqual(Registry.onboardingSteps.first?.order, 900)
                expectEqual(Registry.orderedOnboardingSteps.count, 0, "only included for the installed app")
                expectEqual(Registry.launchHooks.count, 1)
                expectEqual(Registry.terminateHooks.count, 1)
                expectEqual(Registry.selfTests.map(\.id), ["background.jobs"])
                expectEqual(Registry.renderScenes.map(\.id).sorted(), BackgroundScenes.ids.sorted())
                expectEqual(Registry.problems(), [])
                for hook in Registry.launchHooks { hook() }
                expect(!BackgroundJobs.shared.isStarted, "nothing is scheduled headless")
            }
        }

        test("every background scene renders in both appearances") {
            for scene in Registry.orderedRenderScenes where scene.id.hasPrefix("background.") {
                for appearance in Appearance.allCases {
                    guard let png = RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: .de),
                          let rep = NSBitmapImageRep(data: png) else { fail("\(scene.id) \(appearance): no image"); continue }
                    expect(rep.pixelsWide > 600, "\(scene.id) width \(rep.pixelsWide)")
                    expect((rep.colorAt(x: 0, y: 0)?.alphaComponent ?? 0) > 0.99, "\(scene.id) \(appearance): opaque corner")
                }
            }
        }
    }
}
#endif
#endif
