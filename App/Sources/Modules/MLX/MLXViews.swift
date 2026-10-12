import SwiftUI

// The MLX section in the Models pane and the Local AI step: model choice, download rows,
// storage. Drawn from a snapshot (`MLXSectionModel`) like the AI pane.

struct MLXSectionModel {
    var rows: [ModelRowItem]
    var selected: String
    var options: [(value: String, title: String)]
    var memoryGB: Double?
    var footnote: String
    var bytesOnDisk: Int64
    var installed: Bool

    /// A download runs or waits; deleting is offered again when it is over.
    var isDownloading: Bool {
        rows.contains {
            switch $0.phase {
            case .queued, .running: true
            case .notStarted, .paused, .done: false
            }
        }
    }

    @MainActor static func live(_ provider: MLXProvider) -> MLXSectionModel {
        let d = provider.downloads
        let installed = provider.isInstalled()
        let states = Dictionary(uniqueKeysWithValues: d.catalog.models.map { ($0.id, d.state($0.id)) })
        let selected = provider.selected?.id ?? d.catalog.defaultID
        return MLXSectionModel(
            rows: d.catalog.models.map { row($0, d.state($0.id)) }, selected: selected,
            options: d.catalog.models.map { ($0.id, MLXText.role($0.role)) }, memoryGB: provider.selected?.ramGB,
            footnote: footnote(states, selected: selected, installed: installed), bytesOnDisk: d.bytesOnDisk,
            installed: installed)
    }

    static func row(_ model: ModelSpec, _ state: ModelDownloads.State) -> ModelRowItem {
        let phase: ModelRowItem.Phase = switch state {
        case .notStarted: .notStarted(total: model.bytes)
        case .queued: .queued(total: model.bytes)
        case .running(let done, let total): .running(done: done, total: total > 0 ? total : model.bytes)
        // "setup": it never ran (no Python then); offer a plain Download, not a retry of a failure
        case .paused(_, _, "setup"): .notStarted(total: model.bytes)
        case .paused(let done, let total, _): .paused(done: done, total: total > 0 ? total : model.bytes)
        case .done: .done(total: model.bytes)
        }
        let fast = model.role == "fast"
        return ModelRowItem(id: model.id, role: MLXText.roleTitle(model.role), name: AIText.modelName(model.name, bits: model.bits),
                            symbol: fast ? "hare.fill" : "scope", tint: fast ? .teal : .indigo, phase: phase)
    }

    /// VoiceBud's footnote states: offline, failed, running, ready, nothing yet (pure, tested).
    /// Not installed: that downloads need MLX first (the notice or the status row says why).
    static func footnote(_ states: [String: ModelDownloads.State], selected: String, installed: Bool = true) -> String {
        if !installed { return MLXText.noteNotInstalled(developer: AIBuild.canSetUpMLX) }
        let paused = states.values.compactMap { s -> String? in if case .paused(_, _, let p) = s { return p }; return nil }
        if paused.contains("offline") { return MLXText.noteOffline }
        if paused.contains(where: { $0 != "cancelled" && $0 != "setup" }) { return MLXText.noteFailed }
        if states.values.contains(where: { if case .running = $0 { return true }; return $0 == .queued }) { return MLXText.noteRunning }
        if states[selected] == .done { return MLXText.noteReady }
        return MLXText.noteNothing
    }
}

struct MLXSectionContent: View {
    let model: MLXSectionModel
    @Binding var selected: String
    var start: (String) -> Void = { _ in }
    var delete: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Space.pane) {
            SettingsSection(MLXText.section, footnote: model.footnote) {
                PickerRow(MLXText.model, subtitle: model.memoryGB.map(MLXText.memory), options: model.options, selection: $selected)
                // without MLX set up a download cannot work: no Download chip, no retry
                ForEach(model.rows) { item in ModelRowView(item: item, start: model.installed ? { start(item.id) } : nil) }
                if model.bytesOnDisk > 0 {
                    ButtonRow(MLXText.storage, subtitle: MLXText.storageDetail(ByteText.size(model.bytesOnDisk)),
                              button: MLXText.deleteModels, style: .secondary, action: delete)
                        .disabled(model.isDownloading)   // never delete a model under a running download
                }
            }
        }
    }
}

/// The live section in the Models pane.
struct MLXPaneSection: View {
    let provider: MLXProvider
    @State private var confirmDelete = false

    var body: some View {
        MLXSectionContent(model: .live(provider),
                          selected: Binding(get: { provider.selected?.id ?? "" }, set: { provider.select($0); LocalAI.shared.refresh() }),
                          start: { provider.downloads.start($0) }, delete: { confirmDelete = true })
            .confirmationDialog(MLXText.deleteConfirm, isPresented: $confirmDelete) {
                Button(MLXText.delete, role: .destructive) {
                    for m in provider.downloads.catalog.models { provider.downloads.remove(m.id) }
                    provider.refreshAvailability()
                    LocalAI.shared.refresh()
                }
                Button(CommonText.cancel, role: .cancel) {}
            } message: {
                Text(MLXText.deleteConfirmDetail)
            }
    }
}

/// On the Local AI step: the chosen model's row only (the step has little room), and nothing
/// when MLX is not set up (the step's footnote says so; a download could not start).
struct MLXOnboardingContent: View {
    let row: ModelRowItem?
    var start: (String) -> Void = { _ in }

    var body: some View {
        if let row {
            SettingsSection(tone: .onboarding) {
                ModelRowView(item: row) { start(row.id) }
            }
        }
    }
}

struct MLXOnboardingSection: View {
    let provider: MLXProvider

    var body: some View {
        let model = MLXSectionModel.live(provider)
        MLXOnboardingContent(row: model.installed ? model.rows.first { $0.id == model.selected } : nil) { provider.downloads.start($0) }
    }
}
