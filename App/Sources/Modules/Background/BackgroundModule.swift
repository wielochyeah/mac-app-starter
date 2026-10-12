import SwiftUI

/// The background worker app form: scheduled jobs (`BackgroundJobs`), "Open at login"
/// (`LoginItem`, only for the installed app), the settings pane "Background" and the onboarding
/// step "Open at Login".
///
/// Public API for features and other modules:
/// - `BackgroundJobs.shared.register(id:title:interval:tolerance:qos:exact:run:)`
/// - `BackgroundJobs.shared.runNow(_:)`, `.perform(_:) async`, `.record(_:)`, `.isRunning(_:)`
/// - `LoginItem.isAvailable`, `.status`, `.setEnabled(_:)`, `.launchedAtLogin`, `LoginItemModel.shared`
enum BackgroundModule {
    static func register() {
        // whether the login item was already set up is state: "Reset settings" must not ask again
        SettingsReset.keep(SettingKey<Bool>.backgroundLoginAsked.name)
        Registry.settingsPanes.append(SettingsPane(id: "background", group: .settings, order: 310, title: { BackgroundText.paneTitle },
                                                   symbol: "clock.arrow.circlepath", tint: .teal) { AnyView(BackgroundPane()) })
        Registry.onboardingSteps.append(OnboardingStep(id: "background.login", order: 900, isIncluded: { LoginItem.isAvailable }) { _ in
            AnyView(LoginItemStep())
        })
        // jobs and the login item change in the real app only: never in renders, self-tests or
        // headless test runs
        Registry.launchHooks.append {
            _ = LoginItem.launchedAtLogin   // read while the launch event is current, kept for later readers
            guard !RenderMode.isHeadless, !RenderMode.isStatic else { return }
            LoginWish.watch()
            BackgroundJobs.shared.start()
        }
        Registry.terminateHooks.append { BackgroundJobs.shared.stop() }
        Registry.selfTests.append(SelfTestCheck(id: "background.jobs") { BackgroundSelfTest.jobs(BackgroundJobs.shared.jobs) })
        BackgroundScenes.register()
    }
}

enum BackgroundSelfTest {
    /// Registered jobs have sane schedules (ids are unique by construction).
    static func jobs(_ jobs: [BackgroundJobs.Job]) -> String? {
        for job in jobs {
            if job.id.isEmpty { return "a job has an empty id" }
            if job.schedule.interval < 1 { return "job \(job.id): interval below one second" }
            if job.schedule.tolerance < 0 || job.schedule.tolerance > job.schedule.interval {
                return "job \(job.id): tolerance must be between 0 and the interval"
            }
            if job.title().isEmpty { return "job \(job.id): empty title" }
        }
        return nil
    }
}
