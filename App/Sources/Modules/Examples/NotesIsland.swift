#if MODUL_ISLAND
import SwiftUI

// What the island shows for notes (skill `insel-zustand`): quick capture as an activity that turns
// into the done card "Saved to Notes" with Open (Copy is on the card itself), a short notice after
// copying, and the AI work as a progress that counts from 5 s and offers Cancel from 10 s.
// Nothing reaches the island in tests, renders or --selftest.

enum NotesIsland {
    private static var live: Bool { !RenderMode.isHeadless && !RenderMode.isStatic }

    /// The setup's welcome art plays a quick note being saved.
    static func register() {
        IslandWelcome.working = { saving }
        IslandWelcome.result = {
            let note = NoteItem(id: 0, title: "", body: NotesSampleText.welcomeClip, collectionID: NotesSeed.home, pinned: false,
                                trashedAt: nil, createdAt: NotesSamples.now, updatedAt: NotesSamples.now, source: .clipboard)
            return saved(note, collection: NotesSampleText.home, hoverExpands: true, open: {}, copy: {})
        }
    }

    // MARK: Contents (pure: the render scenes show the same)

    static var saving: IslandContent {
        .activity(symbol: "doc.on.clipboard", title: NotesText.islandSaving, tint: .amber)
    }

    /// The done card after a capture. With "Expand on hover" off the card shows its actions
    /// folded but not its Copy button, so Copy comes along as an action then.
    static func saved(_ note: NoteItem, collection: String?, hoverExpands: Bool, open: @escaping () -> Void,
                      copy: @escaping () -> Void) -> IslandContent {
        var actions = [IslandAction(id: "notes.open", title: NotesText.open, symbol: "arrow.up.forward.app", perform: open)]
        if !hoverExpands {
            actions.append(IslandAction(id: "notes.copy", title: CommonText.copy, symbol: "doc.on.doc", perform: copy))
        }
        return .done(title: NotesText.islandSaved, detail: collection, body: note.body, actions: actions, tint: .amber)
    }

    /// The card after saving the sample note "Train to Hamburg" (render scenes); built on each
    /// call, so it is in the language of the moment.
    static var sample: IslandContent {
        let note = NoteItem(id: 0, title: NotesSampleText.trainTitle, body: NotesSampleText.trainBody, collectionID: NotesSeed.travel,
                            pinned: false, trashedAt: nil, createdAt: NotesSamples.now, updatedAt: NotesSamples.now, source: .clipboard)
        return saved(note, collection: NotesSampleText.travel, hoverExpands: true, open: {}, copy: {})
    }

    static var clipboardEmpty: IslandContent { .notice(text: NotesText.clipboardEmpty, kind: .warning) }

    /// A copy marked as a password or one-time code: nothing was saved.
    static var clipboardConcealed: IslandContent { .notice(text: NotesText.clipboardConcealed, kind: .info) }

    static func progress(_ title: String, cancel: @escaping () -> Void) -> IslandContent {
        .progress(title: title, symbol: "sparkles", tint: .sky,
                  cancel: IslandAction(id: "notes.cancel", title: CommonText.cancel, perform: cancel))
    }

    // MARK: Capture

    static func capturing() {
        guard live else { return }
        Island.shared.present(saving)
    }

    static func captured(_ outcome: NotesCapture.Outcome, store: NotesStore) {
        guard live else { return }
        let content: IslandContent
        switch outcome {
        case .empty:
            content = clipboardEmpty
        case .concealed:
            content = clipboardConcealed
        case .saved(let note):
            content = saved(note, collection: store.collection(note.collectionID)?.name,
                            hoverExpands: Settings.shared[.islandHoverExpand],
                            open: { NotesActions.open(note.id) }, copy: { SystemPasteboard().write(note.body) })
        }
        // the island grows first, then turns into the result
        Task {
            try? await Task.sleep(for: NotesLook.captureBeat)
            Island.shared.update(content)
        }
    }

    static func copied() {
        guard live else { return }
        Island.shared.present(.notice(text: NotesText.copiedNotice, kind: .success))
    }

    // MARK: Local AI

    static func working(_ title: String, cancel: @escaping () -> Void) {
        guard live else { return }
        Island.shared.present(progress(title, cancel: cancel))
    }

    static func stopped() {
        guard live else { return }
        Island.shared.dismiss()
    }

    #if MODUL_AI
    static func summarized(_ note: NoteItem, _ summary: String) {
        guard live else { return }
        Island.shared.update(.done(title: NotesText.summaryReady, detail: note.shownTitle, body: summary, tint: .sky))
    }

    static func suggested(_ found: NoteTitleSuggestion) {
        guard live else { return }
        Island.shared.update(.done(title: NotesText.titleReady, detail: found.title, tint: .sky))
    }

    static func failed(_ error: AIError) {
        guard live else { return }
        if error == .cancelled {
            Island.shared.dismiss()
        } else {
            Island.shared.update(.notice(text: AIText.error(error), kind: .error))
        }
    }
    #endif
}
#endif
