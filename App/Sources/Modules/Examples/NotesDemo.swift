import Foundation

/// A clipboard with fixed text (the demo; tests use their own).
struct FixedPasteboard: NotesPasteboard {
    var value: String?

    func text() -> String? { value }
    func write(_ text: String) {}
}

/// `--demo examples` (or `--demo` without the island module, whose own loop would fight over the
/// island): sample notes in memory, the window on the overview, a quick capture of a fixed text,
/// then the new note opens and the local model summarizes it. For the person at the Mac only;
/// tests and renders never run it, and it never writes the real notes file or the clipboard.
enum NotesDemo {
    static func wanted(_ arguments: [String] = CommandLine.arguments) -> Bool {
        guard let i = arguments.firstIndex(of: "--demo") else { return false }
        let areas = arguments[(i + 1)...].prefix { !$0.hasPrefix("-") }
        return areas.contains("examples") || (areas.isEmpty && !AppInfo.isEnabled("island"))
    }

    /// Launch hook, before anything opens the store.
    static func prepare() {
        guard Launch.isDemo, wanted() else { return }
        NotesStore.useInstead(NotesStore(url: nil))
    }

    static func run() {
        guard wanted() else { return }
        Task {
            AppActions.openMainWindow()
            try? await Task.sleep(for: .seconds(2))
            NotesCapture.captureClipboard(pasteboard: FixedPasteboard(value: NotesSampleText.demoClip))
            try? await Task.sleep(for: .seconds(4))
            guard let note = NotesStore.shared.notes.first(where: { $0.source == .clipboard }) else { return }
            NotesActions.open(note.id)
            #if MODUL_AI
            try? await Task.sleep(for: .seconds(1))
            NotesAIBoard.shared.session(for: note.id).summarize(note)
            #endif
        }
    }
}
