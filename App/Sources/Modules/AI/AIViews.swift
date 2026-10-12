import AppKit
import Observation
import SwiftUI

// The Models pane and the Local AI onboarding step. Both are drawn from a plain snapshot
// (`AIPaneModel`), so renders and the gallery show fixed states and the live views only read
// `LocalAI.shared` into it.

// MARK: - Snapshot

struct AIProviderInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let shortTitle: String
    let detail: String
    let symbol: String
    let tint: TintName
    let availability: AIAvailability
}

struct AIPaneModel {
    var providers: [AIProviderInfo]
    var choice: String
    var activeID: String?
    var availability: AIAvailability
    var usage: AIUsage

    @MainActor static func live(_ ai: LocalAI = .shared) -> AIPaneModel {
        _ = ai.revision
        return AIPaneModel(
            providers: ai.providers.map {
                AIProviderInfo(id: $0.id, title: $0.title, shortTitle: $0.shortTitle, detail: $0.detail, symbol: $0.symbol,
                               tint: $0.tint, availability: $0.availability)
            },
            choice: ai.choice, activeID: ai.active?.id, availability: ai.availability, usage: ai.usage)
    }

    /// The problem to explain on top, if requests cannot be answered.
    var problem: AIUnavailableReason? { availability.reason }
    var showsPicker: Bool { providers.count > 1 }
}

enum AILinks {
    static let appleIntelligence = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!
    static let softwareUpdate = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension")!

    /// The System Settings page that fixes `reason`, if there is one.
    static func fix(for reason: AIUnavailableReason) -> URL? {
        switch reason {
        case .appleIntelligenceOff: appleIntelligence
        case .systemTooOld: softwareUpdate
        default: nil
        }
    }

    static func open(_ url: URL) {
        guard !RenderMode.isStatic, !RenderMode.isHeadless else { return }
        NSWorkspace.shared.open(url)
    }
}

extension AIUnavailableReason {
    var mark: StatusMark.Kind {
        switch self {
        case .appleIntelligenceOff, .systemTooOld: .warn
        case .modelNotReady: .busy
        case .notInstalled, .modelMissing, .deviceNotEligible, .unsupportedHardware, .unknown: .idle
        }
    }
}

// MARK: - Provider row

struct AIProviderRow: View {
    let info: AIProviderInfo
    var inUse = false

    var body: some View {
        Row(info.title, subtitle: info.detail, symbol: info.symbol, tint: info.tint) {
            HStack(spacing: Space.xs) {
                if inUse { Badge(AIText.inUse, tone: .accent) }
                switch info.availability {
                case .available: StatusMark(.ok, PatternsText.ready)
                case .unavailable(let reason): StatusMark(reason.mark, AIText.statusWord(reason))
                }
            }
        }
    }
}

// MARK: - Model rows (downloads; the MLX module fills them)

/// One downloadable model as a row: before the download a "Download" chip, then the kit's
/// `ProgressRow` (queued / running / paused with retry / done).
struct ModelRowItem: Identifiable, Equatable {
    enum Phase: Equatable {
        case notStarted(total: Int64)
        case queued(total: Int64)
        case running(done: Int64, total: Int64)
        case paused(done: Int64, total: Int64)
        case done(total: Int64)
    }

    let id: String
    let role: String
    let name: String
    let symbol: String
    let tint: TintName
    let phase: Phase

    static func == (a: ModelRowItem, b: ModelRowItem) -> Bool {
        (a.id, a.role, a.name, a.symbol, a.phase) == (b.id, b.role, b.name, b.symbol, b.phase) && a.tint == b.tint
    }
}

struct ModelRowView: View {
    let item: ModelRowItem
    var start: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    @Environment(\.textTone) private var tone

    var body: some View {
        switch item.phase {
        case .notStarted(let total):
            let t = Theme(scheme)
            HStack(spacing: Space.s) {
                SquircleIcon(symbol: item.symbol, tint: item.tint, size: Metrics.progressIcon)
                VStack(alignment: .leading, spacing: Space.hair) {
                    Text(item.role).font(TypeScale.body).foregroundStyle(t.fg)
                    Text(item.name).font(tone.small).foregroundStyle(tone.smallColor(t))
                }
                Spacer(minLength: Space.s)
                Text(ByteText.size(total)).font(tone.small.monospacedDigit()).foregroundStyle(tone.smallColor(t))
                Chip(AIText.download, symbol: "arrow.down", action: start)
            }
            .padding(.horizontal, Space.rowX)
            .padding(.vertical, Metrics.progressRowY)
            .frame(minHeight: Metrics.rowMinHeight)
        case .queued(let total):
            ProgressRow(role: item.role, name: item.name, symbol: item.symbol, tint: item.tint, phase: .waiting(total: total))
        case .running(let done, let total):
            ProgressRow(role: item.role, name: item.name, symbol: item.symbol, tint: item.tint, phase: .running(done: done, total: total))
        case .paused(let done, let total):
            ProgressRow(role: item.role, name: item.name, symbol: item.symbol, tint: item.tint,
                        phase: .paused(done: done, total: total), retry: start)
        case .done(let total):
            ProgressRow(role: item.role, name: item.name, symbol: item.symbol, tint: item.tint, phase: .done(total: total))
        }
    }
}

// MARK: - Try it

/// The pane's test prompt: a field, Send/Stop, the streamed answer and who answered how fast.
@Observable final class AITrial {
    var prompt = ""
    private(set) var answer = ""
    private(set) var running = false
    private(set) var error: AIError?
    private(set) var latency: Double?
    private(set) var provider: String?
    @ObservationIgnored private var task: Task<Void, Never>?

    init() {}

    /// A fixed state for renders and the gallery.
    init(prompt: String, answer: String, latency: Double?, provider: String?, running: Bool = false, error: AIError? = nil) {
        self.prompt = prompt
        self.answer = answer
        self.latency = latency
        self.provider = provider
        self.running = running
        self.error = error
    }

    func send(_ ai: LocalAI = .shared) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let question = text.isEmpty ? AIText.trySample : text
        stop()
        answer = ""
        error = nil
        latency = nil
        provider = ai.active?.title
        running = true
        let start = Date()
        task = Task { @MainActor [weak self] in
            do {
                for try await partial in ai.stream(prompt: question) {
                    self?.answer = partial
                }
                self?.latency = Date().timeIntervalSince(start)
            } catch {
                let e = AIError.from(error)
                if e != .cancelled { self?.error = e }
            }
            self?.running = false
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        running = false
    }
}

struct AITrialSection: View {
    @Bindable var trial: AITrial
    let canSend: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.renderStatic) private var renderStatic

    var body: some View {
        let t = Theme(scheme)
        SettingsSection(AIText.trySection, footnote: AIText.tryNote) {
            HStack(spacing: Space.s) {
                field(t)
                if trial.running {
                    Button(AIText.stop) { trial.stop() }.buttonStyle(.secondary)
                } else {
                    Button(AIText.send) { trial.send() }
                        .buttonStyle(.primary)
                        .disabled(!canSend)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, Space.rowX)
            .padding(.vertical, Space.rowY)
            if trial.running || !trial.answer.isEmpty || trial.error != nil {
                answer(t)
            }
        }
    }

    @ViewBuilder private func field(_ t: Theme) -> some View {
        Group {
            if renderStatic {
                Text(trial.prompt.isEmpty ? AIText.trySample : trial.prompt)
                    .foregroundStyle(trial.prompt.isEmpty ? t.fg3 : t.fg)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("", text: $trial.prompt, prompt: Text(AIText.trySample))
                    .textFieldStyle(.plain)
                    .foregroundStyle(t.fg)
                    .onSubmit { if canSend && !trial.running { trial.send() } }
            }
        }
        .font(TypeScale.body)
        .padding(.horizontal, Space.iconGap)
        .frame(height: Metrics.buttonHeight)
        .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(t.field))
    }

    private func answer(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if let error = trial.error {
                Text(AIText.error(error)).font(TypeScale.body).foregroundStyle(t.strike)
            } else if trial.answer.isEmpty {
                StatusMark(.busy, AIText.thinking)
            } else {
                Text(trial.answer)
                    .font(TypeScale.reading)
                    .foregroundStyle(t.fg)
                    .lineSpacing(TypeScale.noteLineSpacing)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let latency = trial.latency, let provider = trial.provider, trial.error == nil {
                Text(AIText.answered(in: latency, by: provider))
                    .font(TypeScale.subtitle.monospacedDigit())
                    .foregroundStyle(t.fg2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Space.s)
    }
}

// MARK: - Pane

struct AIPaneContent: View {
    let model: AIPaneModel
    @Binding var choice: String
    let trial: AITrial
    var sections: [AIPaneSection] = []

    var body: some View {
        PaneScaffold(title: AIText.pane, symbol: "cpu", tint: .indigo, subtitle: AIText.paneIntro) {
            if let reason = model.problem {
                InlineNotice(AIText.reasonHint(reason), title: AIText.reasonTitle(reason), kind: .warning,
                             actionTitle: AILinks.fix(for: reason) == nil ? nil : AIText.openAISettings,
                             action: AILinks.fix(for: reason).map { url in { AILinks.open(url) } })
            }
            SettingsSection(AIText.providerSection) {
                if model.showsPicker {
                    PickerRow(AIText.providerChoice, subtitle: AIText.providerChoiceDetail,
                              options: [(ProviderChoice.automatic, AIText.automatic)] + model.providers.map { ($0.id, $0.shortTitle) },
                              selection: $choice)
                }
                ForEach(model.providers) { info in
                    AIProviderRow(info: info, inUse: model.showsPicker && info.id == model.activeID && info.availability.isAvailable)
                }
            }
            ForEach(sections.sorted { ($0.order, $0.id) < ($1.order, $1.id) }) { $0.pane() }
            AITrialSection(trial: trial, canSend: model.availability.isAvailable)
            SettingsSection(AIText.usageSection, footnote: AIText.usageNote) {
                ValueRow(AIText.requests, value: Format.number(model.usage.requests))
                ValueRow(AIText.failures, value: Format.number(model.usage.failures))
                ValueRow(AIText.lastAnswer, value: lastAnswer)
            }
        }
    }

    private var lastAnswer: String {
        guard let latency = model.usage.lastLatency else { return AIText.noAnswerYet }
        let name = model.providers.first { $0.id == model.usage.lastProvider }?.shortTitle ?? (model.usage.lastProvider ?? "")
        return AIText.answered(in: latency, by: name)
    }
}

/// The live pane (registered as settings pane "ai").
struct AISettingsPane: View {
    @State private var trial = AITrial()
    private var ai: LocalAI { .shared }

    var body: some View {
        let model = AIPaneModel.live(ai)
        AIPaneContent(model: model, choice: Binding(get: { ai.choice }, set: { ai.choice = $0; ai.refresh() }),
                      trial: trial, sections: ai.sections)
            .task {
                // availability changes outside the app (Apple Intelligence switched on, model ready)
                while !Task.isCancelled {
                    ai.refresh()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
            .onDisappear { trial.stop() }
    }
}

// MARK: - Onboarding step

struct AIOnboardingContent: View {
    let model: AIPaneModel
    var sections: [AIPaneSection] = []

    var body: some View {
        OnboardingPage {
            OnboardingHero(symbol: "cpu", tint: .indigo).padding(.bottom, Space.m)
            OnboardingHeader(title: AIText.stepTitle, subtitle: AIText.stepSubtitle).padding(.bottom, Space.l)
            VStack(alignment: .leading, spacing: Space.s) {
                SettingsSection(tone: .onboarding) {
                    ForEach(model.providers) { info in
                        AIProviderRow(info: info, inUse: model.showsPicker && info.id == model.activeID && info.availability.isAvailable)
                    }
                }
                ForEach(sections.filter { $0.onboarding != nil }.sorted { ($0.order, $0.id) < ($1.order, $1.id) }) {
                    $0.onboarding?()
                }
            }
            .tone(.onboarding)
            .frame(width: Metrics.onboardingColumn)
            OnboardingFootnote(note, lines: 2) { action in
                if action == "fix", let reason = model.problem, let url = AILinks.fix(for: reason) { AILinks.open(url) }
            }
            .frame(width: Metrics.onboardingColumn, alignment: .leading)
        }
    }

    private var note: String {
        guard let reason = model.problem else { return AIText.stepReady }
        return AIText.onboardingHint(reason, link: AILinks.fix(for: reason) != nil)
    }
}

struct AIOnboardingStep: View {
    private var ai: LocalAI { .shared }

    var body: some View {
        AIOnboardingContent(model: .live(ai), sections: ai.sections)
            .task {
                while !Task.isCancelled {
                    ai.refresh()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
    }
}
