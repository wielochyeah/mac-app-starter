import SwiftUI

// Render scenes and gallery entries of the background module. Sample jobs with fixed records and
// a fixed clock, a login item with fixed status: deterministic, nothing is scheduled or registered.

enum BackgroundScenes {
    static let ids = ["background.pane", "background.pane-unavailable", "background.pane-approval", "background.onboarding",
                      "background.onboarding-approval"]

    static func register() {
        Registry.renderScenes.append(RenderScene(id: "background.pane", size: .zero) {
            AnyView(BackgroundPane(jobs: BackgroundSamples.jobs(), login: LoginItemModel(status: .enabled),
                                   previewHovered: BackgroundSamples.hoveredJob)
                .frame(width: BackgroundSamples.paneSize.width, height: BackgroundSamples.paneSize.height))
        })
        Registry.renderScenes.append(RenderScene(id: "background.pane-unavailable", size: .zero) {
            AnyView(BackgroundPane(jobs: BackgroundSamples.emptyJobs(), login: LoginItemModel(status: .unavailable, unavailable: .notInstalled))
                .frame(width: BackgroundSamples.paneSize.width, height: BackgroundSamples.emptyPaneHeight))
        })
        // macOS waits for approval, a change failed, and a task that has not run yet
        Registry.renderScenes.append(RenderScene(id: "background.pane-approval", size: .zero) {
            AnyView(BackgroundPane(jobs: BackgroundSamples.newJob(),
                                   login: LoginItemModel(status: .requiresApproval,
                                                         error: BackgroundText.loginItemFailed(BackgroundSampleText.notPermitted)))
                .frame(width: BackgroundSamples.paneSize.width, height: BackgroundSamples.emptyPaneHeight))
        })
        Registry.renderScenes.append(RenderScene(id: "background.onboarding", size: .zero) {
            AnyView(BackgroundSamples.OnboardingWindow {
                LoginItemStep(login: LoginItemModel(status: .disabled), settings: BackgroundSamples.settings())
            })
        })
        Registry.renderScenes.append(RenderScene(id: "background.onboarding-approval", size: .zero) {
            AnyView(BackgroundSamples.OnboardingWindow {
                LoginItemStep(login: LoginItemModel(status: .requiresApproval), settings: BackgroundSamples.settings())
            })
        })
        Registry.gallery.append(GalleryEntry(id: "background.jobs", area: "background", title: { BackgroundText.galleryJobs }) {
            AnyView(JobList(jobs: BackgroundSamples.jobs()))
        })
    }
}

enum BackgroundSamples {
    /// The settings window's detail column (900 wide minus the 224 sidebar).
    static let paneSize = CGSize(width: 676, height: 620)
    static let emptyPaneHeight: CGFloat = 470
    static let hoveredJob = "sample.inbox"

    /// A fixed "now" for relative times.
    static let now = Date(timeIntervalSince1970: 1_791_000_000)

    static func settings() -> Settings {
        Settings.inMemory()
    }

    /// Five jobs: done with a note, nothing to do (hovered: Run Now), running, failed, switched off.
    static func jobs() -> BackgroundJobs {
        func record(_ minutesAgo: Double, _ outcome: JobOutcome, took seconds: Double = 1.2) -> JobRecord {
            let end = now.addingTimeInterval(-minutesAgo * 60)
            return JobRecord(lastStart: end.addingTimeInterval(-seconds), lastEnd: end, outcome: outcome, runs: 14,
                             failures: outcome.isFailure ? 1 : 0)
        }
        let store = MemoryJobStore([
            "sample.cleanup": record(4, .done(note: BackgroundSampleText.removed)),
            "sample.inbox": record(12, .nothingToDo),
            "sample.backup": record(180, .done()),
            "sample.sync": record(35, .failed(BackgroundSampleText.folderMissing)),
            "sample.report": record(3 * 1440, .done()),
        ])
        // the weekly summary is switched off
        let jobs = BackgroundJobs(store: store, scheduler: NoJobScheduler(), settings: nil, now: { now },
                                  running: ["sample.backup"], disabled: ["sample.report"])
        let samples: [(String, () -> String, TimeInterval)] = [
            ("sample.cleanup", { BackgroundSampleText.cleanup }, 6 * 3600),
            ("sample.inbox", { BackgroundSampleText.checkFolder }, 15 * 60),
            ("sample.backup", { BackgroundSampleText.backup }, 86_400),
            ("sample.sync", { BackgroundSampleText.sync }, 30 * 60),
            ("sample.report", { BackgroundSampleText.report }, 7 * 86_400),
        ]
        for (id, title, interval) in samples {
            jobs.register(id: id, title: title, interval: interval) { .nothingToDo }
        }
        return jobs
    }

    /// One task that has not run yet.
    static func newJob() -> BackgroundJobs {
        let jobs = emptyJobs()
        jobs.register(id: "sample.index", title: { BackgroundSampleText.newJob }, interval: 3600) { .nothingToDo }
        return jobs
    }

    static func emptyJobs() -> BackgroundJobs {
        BackgroundJobs(store: MemoryJobStore(), scheduler: NoJobScheduler(), settings: nil, now: { now })
    }

    /// The step in the onboarding window on the render desk.
    struct OnboardingWindow<Page: View>: View {
        let page: Page

        init(@ViewBuilder page: () -> Page) { self.page = page() }

        var body: some View {
            RenderBoard {
                StaticWindow(size: Metrics.onboardingWindow, chrome: .onboarding) {
                    OnboardingFrame {
                        page
                    } footer: {
                        // the login step comes before Done (order 1000), so it is never the last
                        OnboardingFooter(count: 7, index: 5, back: {}, advance: {})
                    }
                }
            }
        }
    }
}
