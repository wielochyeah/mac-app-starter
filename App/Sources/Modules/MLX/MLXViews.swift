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

    @MainActor static func live(_ provider: MLXProvider) -> MLXSectionModel {
        let d = provider.downloads
        let states = Dictionary(uniqueKeysWithValues: d.catalog.models.map { ($0.id, d.state($0.id)) })
        let selected = provider.selected?.id ?? d.catalog.defaultID
        return MLXSectionModel(
            rows: d.catalog.models.map { row($0, d.state($0.id)) }, selected: selected,
            options: d.catalog.models.map { ($0.id, MLXText.role($0.role)) }, memoryGB: provider.selected?.ramGB,
            // the pane's top notice already explains a missing setup when MLX is the one in use
            footnote: footnote(states, selected: selected,
                               installed: provider.isInstalled() || LocalAI.shared.availability.reason == .notInstalled), bytesOnDisk: d.bytesOnDisk,
            installed: provider.isInstalled())
    }

    static func row(_ model: ModelSpec, _ state: ModelDownloads.State) -> ModelRowItem {
        let phase: ModelRowItem.Phase = switch state {
        case .notStarted: .notStarted(total: model.bytes)
        case .queued: .queued(total: model.bytes)
        case .running(let done, let total): .running(done: done, total: total > 0 ? total : model.bytes)
        case .paused(let done, let total, _): .paused(done: done, total: total > 0 ? total : model.bytes)
        case .done: .done(total: model.bytes)
        }
        let fast = model.role == "fast"
        return ModelRowItem(id: model.id, role: MLXText.roleTitle(model.role), name: MLXText.name(model.name, bits: model.bits),
                            symbol: fast ? "hare.fill" : "scope", tint: fast ? .teal : .indigo, phase: phase)
    }

    /// VoiceBud's footnote states: offline, failed, running, ready, nothing yet (pure, tested).
    /// Not installed: how to set it up (the status row says "Not set up").
    static func footnote(_ states: [String: ModelDownloads.State], selected: String, installed: Bool = true) -> String {
        if !installed { return AIText.reasonHint(.notInstalled) }
        let paused = states.values.compactMap { s -> String? in if case .paused(_, _, let p) = s { return p }; return nil }
        if paused.contains("offline") { return MLXText.noteOffline }
        if paused.contains(where: { $0 != "cancelled" }) { return MLXText.noteFailed }
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
            SettingsSection(MLXText.section, footnote: model.footnote, footnoteLines: 2) {
                PickerRow(MLXText.model, subtitle: model.memoryGB.map(MLXText.memory), options: model.options, selection: $selected)
                ForEach(model.rows) { item in ModelRowView(item: item) { start(item.id) } }
                if model.bytesOnDisk > 0 {
                    ButtonRow(MLXText.storage, subtitle: MLXText.storageDetail(ByteText.size(model.bytesOnDisk)),
                              button: MLXText.deleteModels, style: .secondary, action: delete)
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

/// On the Local AI step: the chosen model's row only (the step has little room).
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
        MLXOnboardingContent(row: model.rows.first { $0.id == model.selected }) { provider.downloads.start($0) }
    }
}
