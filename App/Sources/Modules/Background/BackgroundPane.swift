import SwiftUI

/// Settings pane "Background": open at login, and the list of scheduled tasks with last run,
/// outcome, an on/off switch and "Run Now" (on hover, in the context menu and as a VoiceOver action).
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
            JobList(jobs: jobs, previewHovered: previewHovered)
        }
        .onAppear { login.refresh() }
    }
}

/// The tasks as one settings group (label above the card like "Start"), or an empty state.
struct JobList: View {
    var jobs: BackgroundJobs
    var previewHovered: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        SettingsSection(BackgroundText.jobs) {
            if jobs.jobs.isEmpty {
                VStack(spacing: Space.xxs) {
                    Text(BackgroundText.noJobs).font(TypeScale.emptyTitle).foregroundStyle(t.fg)
                    Text(BackgroundText.noJobsDetail).font(TypeScale.paneIntro).foregroundStyle(t.fg2)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Metrics.listEmptyPadding)
            } else {
                ForEach(jobs.jobs) { job in
                    JobRow(job: job, jobs: jobs, previewHovered: previewHovered == job.id)
                }
            }
        }
    }
}

/// One task: title, schedule and last run (kept current), the failure message, outcome or a
/// spinner, "Run Now" while hovered, and the switch. Metrics of the kit `Row` (44 min, 12 / 9).
/// "Run Now" is also in the row's context menu and a VoiceOver action, so it never needs a pointer.
struct JobRow: View {
    let job: BackgroundJobs.Job
    var jobs: BackgroundJobs
    var previewHovered = false
    @State private var pointer = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.renderStatic) private var renderStatic

    private var hovered: Bool { pointer || previewHovered }

    var body: some View {
        let t = Theme(scheme)
        let record = jobs.record(job.id)
        let running = jobs.isRunning(job.id)
        let isEnabled = jobs.isEnabled(job.id)
        let enabled = Binding(get: { jobs.isEnabled(job.id) }, set: { jobs.setEnabled(job.id, $0) })
        HStack(spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.hair) {
                Text(job.title()).font(TypeScale.body).foregroundStyle(isEnabled ? t.fg : t.fg2)
                summary(record).font(TypeScale.subtitle).foregroundStyle(t.fg2)
                if case .failed(let message) = record.outcome, !running {
                    // the same warning tone as the badge, text-grade (>= 4.5:1)
                    Text(message).font(TypeScale.subtitle).foregroundStyle(t.warnText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.s)
            if hovered && !running {
                Chip(BackgroundText.runNow, symbol: "play.fill") { jobs.runNow(job.id) }
                    .fixedSize()
                    .transition(.opacity)
                    .accessibilityHidden(true)   // the row's action says the same
            }
            Group {
                if running {
                    StatusMark(.busy, BackgroundText.running)
                } else {
                    Badge(BackgroundText.outcome(record.outcome), tone: Self.tone(record.outcome, enabled: isEnabled))
                        .help(record.duration.map(BackgroundText.took) ?? "")
                }
            }
            .fixedSize()
            SwitchToggle(isOn: enabled).accessibilityLabel(BackgroundText.jobSwitch(job.title()))
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Space.rowY)
        .frame(minHeight: Metrics.rowMinHeight)
        .background(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .fill(hovered ? t.rowHover : .clear)
                .padding(.horizontal, Space.xxs)
        )
        .contentShape(Rectangle())
        .onHover { inside in withAnimation(Motion.fade) { pointer = inside } }
        .contextMenu {
            Button(BackgroundText.runNow) { jobs.runNow(job.id) }.disabled(running)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: BackgroundText.runNow) { jobs.runNow(job.id) }
        .animation(Motion.fade, value: hovered)
    }

    /// "Every 30 minutes, last run 4 minutes ago", re-read every minute while shown.
    @ViewBuilder
    private func summary(_ record: JobRecord) -> some View {
        if renderStatic {
            Text(BackgroundText.summary(interval: job.schedule.interval, lastRun: record.lastEnd, now: jobs.now()))
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                Text(BackgroundText.summary(interval: job.schedule.interval, lastRun: record.lastEnd, now: jobs.now()))
            }
        }
    }

    /// One tone per state: done green, failed the warning tone (badge and message), nothing to do
    /// or not run grey; a switched-off job's badge is grey whatever its last outcome.
    static func tone(_ outcome: JobOutcome?, enabled: Bool = true) -> Badge.Tone {
        guard enabled else { return .neutral }
        return switch outcome {
        case .done: .ok
        case .failed: .warn
        case .nothingToDo, nil: .neutral
        }
    }
}
