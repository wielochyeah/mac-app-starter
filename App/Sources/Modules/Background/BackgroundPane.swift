import SwiftUI

/// Settings pane "Background": open at login, and the list of scheduled tasks with last run,
/// outcome, an on/off switch and "Run Now" on hover.
struct BackgroundPane: View {
    var jobs: BackgroundJobs = .shared
    var login: LoginItemModel = .shared
    /// Shows a row as hovered without a pointer (renders).
    var previewHovered: String?

    var body: some View {
        let openAtLogin = Binding(get: { login.isOn }, set: { login.set($0) })
        PaneScaffold(title: BackgroundText.paneTitle, symbol: "clock.arrow.circlepath", tint: .teal, subtitle: BackgroundText.paneIntro) {
            SettingsSection(BackgroundText.startSection, footnote: login.unavailable.map(BackgroundText.unavailable)) {
                ToggleRow(BackgroundText.openAtLogin, subtitle: BackgroundText.openAtLoginDetail, isOn: openAtLogin)
                    .disabled(login.unavailable != nil)
            }
            if login.status == .requiresApproval {
                InlineNotice(BackgroundText.needsApproval, kind: .warning, actionTitle: BackgroundText.openLoginItems) {
                    LoginItem.openSystemSettings()
                }
            }
            if let error = login.error {
                InlineNotice(error, kind: .error)
            }
            ListCard(BackgroundText.jobs, items: jobs.jobs, emptyTitle: BackgroundText.noJobs, emptyMessage: BackgroundText.noJobsDetail,
                     previewHovered: previewHovered) { job, hovered in
                JobRow(job: job, jobs: jobs, hovered: hovered)
            }
        }
        .onAppear { login.refresh() }
    }
}

/// One task: title, schedule and last run, the failure message in red, outcome or a spinner,
/// "Run Now" while hovered, and the switch. Metrics of the kit `Row` (44 min, 12 / 9).
struct JobRow: View {
    let job: BackgroundJobs.Job
    var jobs: BackgroundJobs
    var hovered: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let record = jobs.record(job.id)
        let running = jobs.isRunning(job.id)
        let enabled = Binding(get: { jobs.isEnabled(job.id) }, set: { jobs.setEnabled(job.id, $0) })
        HStack(spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.hair) {
                Text(job.title()).font(TypeScale.body).foregroundStyle(enabled.wrappedValue ? t.fg : t.fg2)
                Text(BackgroundText.summary(interval: job.schedule.interval, lastRun: record.lastEnd, now: jobs.now()))
                    .font(TypeScale.subtitle).foregroundStyle(t.fg2)
                if case .failed(let message) = record.outcome, !running {
                    Text(message).font(TypeScale.subtitle).foregroundStyle(t.strike)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.s)
            if hovered && !running {
                Chip(BackgroundText.runNow, symbol: "play.fill") { jobs.runNow(job.id) }
                    .fixedSize()
                    .transition(.opacity)
            }
            Group {
                if running {
                    StatusMark(.busy, BackgroundText.running)
                } else {
                    Badge(BackgroundText.outcome(record.outcome), tone: Self.tone(record.outcome))
                        .help(record.duration.map(BackgroundText.took) ?? "")
                }
            }
            .fixedSize()
            SwitchToggle(isOn: enabled).accessibilityLabel(BackgroundText.jobSwitch(job.title()))
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Space.rowY)
        .frame(minHeight: Metrics.rowMinHeight)
        .animation(Motion.fade, value: hovered)
    }

    static func tone(_ outcome: JobOutcome?) -> Badge.Tone {
        switch outcome {
        case .done: .ok
        case .failed: .warn
        case .nothingToDo, nil: .neutral
        }
    }
}
