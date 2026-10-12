import AppKit
import SwiftUI

/// Settings pane "Notes" (skill `neue-einstellung`, content group): how many notes there are, the
/// collection new notes go to, where the file lies, and reloading the sample data (asks first).
struct NotesPane: View {
    static let id = "notes"

    var store: NotesStore = .shared
    /// The file shown under "Storage" (renders pass the usual place; the store may be in memory).
    var location: URL?
    /// Renders pass a fixed confirmation state.
    var confirmingReload = false
    @State private var confirming = false
    @State private var reloaded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static var pane: SettingsPane {
        SettingsPane(id: id, group: .content, order: 100, title: { NotesText.paneTitle }, symbol: "note.text", tint: .yellow) {
            AnyView(NotesPane())
        }
    }

    var body: some View {
        let collection = Binding(get: { Settings.shared[.notesDefaultCollection] }, set: { Settings.shared[.notesDefaultCollection] = $0 })
        let file = location ?? store.url
        PaneScaffold(title: NotesText.paneTitle, symbol: "note.text", tint: .yellow, subtitle: NotesText.paneIntro) {
            if let problem = store.problem {
                InlineNotice(problem, kind: .error)
            }
            SettingsSection(NotesText.notesSection) {
                ValueRow(NotesText.notesCount, value: Format.number(store.notes.count))
                ValueRow(NotesText.trashCount, subtitle: NotesText.trashCountDetail, value: Format.number(store.trashed.count))
                PickerRow(NotesText.defaultCollection, subtitle: NotesText.defaultCollectionDetail,
                          options: [(0, NotesText.noCollection)] + store.collections.map { (Int($0.id), $0.name) },
                          selection: collection, style: .menu)
            }
            SettingsSection(NotesText.storageSection, footnote: NotesText.storageNote) {
                if let file {
                    ButtonRow(NotesText.storageFile, subtitle: Self.shortPath(file), button: NotesText.showInFinder) {
                        Self.reveal(file)
                    }
                } else {
                    ValueRow(NotesText.storageFile, subtitle: NotesText.inMemoryDetail, value: NotesText.inMemory)
                }
            }
            SettingsSection(NotesText.samplesSection) {
                if confirming || confirmingReload {
                    NotesReloadConfirmation(cancel: { setConfirming(false) }, confirm: reload)
                } else {
                    Row(NotesText.reloadSamples, subtitle: reloaded ? nil : NotesText.reloadSamplesDetail) {
                        if reloaded {
                            StatusMark(.ok, NotesText.reloaded)
                        } else {
                            Chip(NotesText.reloadButton) { setConfirming(true) }
                        }
                    }
                }
            }
        }
    }

    private func setConfirming(_ on: Bool) {
        withAnimation(Motion.adaptive(Motion.expand, reduce: reduceMotion)) { confirming = on }
    }

    private func reload() {
        store.reloadSamples()
        setConfirming(false)
        reloaded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.doneHold) { reloaded = false }
    }

    /// The path with the home folder as "~".
    static func shortPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    /// The usual place of the file (renders show it whatever STARTER_DATA_DIR says).
    static var usualLocation: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(AppConfig.bundleId, isDirectory: true)
            .appendingPathComponent("notes.sqlite")
    }

    private static func reveal(_ url: URL) {
        guard !RenderMode.isStatic, !RenderMode.isHeadless else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

/// The reload row while asking: what happens, Reload, Cancel. Cancel is the prominent button and
/// Esc presses it; Reload is red text on a quiet button without a key equivalent (the reset of
/// the General pane does the same).
private struct NotesReloadConfirmation: View {
    let cancel: () -> Void
    let confirm: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolFont(Metrics.noticeIcon, weight: .semibold)
                    .foregroundStyle(t.warn)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.hair) {
                    Text(NotesText.reloadConfirmTitle).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
                    Text(NotesText.reloadConfirmText)
                        .font(TypeScale.subtitle)
                        .foregroundStyle(t.fg2)
                        .lineSpacing(TypeScale.footnoteLineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: Space.xs) {
                Spacer(minLength: 0)
                Button(action: confirm) { Text(NotesText.reloadConfirmButton).foregroundStyle(t.destructive) }
                    .buttonStyle(.secondary)
                Button(CommonText.cancel, action: cancel)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Space.s)
        .transition(.opacity)
    }
}
