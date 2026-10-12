#if MODUL_WINDOW
import SwiftUI

/// The notes pages in the main window (static window, sample data), and the note page in each AI
/// state when the ai module is compiled.
enum NotesWindowScenes {
    static func register() {
        let s = NotesScenes.self
        s.scene("overview") { window(NotesPages.overview) { NotesOverviewPage(store: $0, navigator: NotesNavigator()) } }
        s.scene("all") { window(NotesPages.all) { NotesAllPage(store: $0, navigator: NotesNavigator()) } }
        s.scene("search") {
            window(NotesPages.all, query: NotesSampleText.searchQuery) { NotesAllPage(store: $0, navigator: NotesNavigator()) }
        }
        s.scene("search-empty") {
            window(NotesPages.all, query: NotesSampleText.searchNone) { NotesAllPage(store: $0, navigator: NotesNavigator()) }
        }
        s.scene("collection") {
            window(NotesPages.collection(NotesSeed.home)) {
                NotesCollectionPage(collectionID: NotesSeed.home, store: $0, navigator: NotesNavigator(), layout: "grid")
            }
        }
        s.scene("collection-list") {
            window(NotesPages.collection(NotesSeed.home)) {
                NotesCollectionPage(collectionID: NotesSeed.home, store: $0, navigator: NotesNavigator(), layout: "list")
            }
        }
        s.scene("trash") {
            window(NotesPages.trash, store: NotesSamples.storeWithTrash()) { NotesTrashPage(store: $0, navigator: NotesNavigator()) }
        }
        s.scene("empty") {
            window(NotesPages.overview, store: NotesSamples.store(seed: false)) {
                NotesOverviewPage(store: $0, navigator: NotesNavigator())
            }
        }
        s.scene("detail") { detail() }
        #if MODUL_AI
        s.scene("detail-streaming") {
            aiDetail(summary: .running(NotesSampleText.summaryPartial), suggestion: .running)
        }
        s.scene("detail-done") {
            aiDetail(summary: .done(NotesSampleText.summaryDone),
                   suggestion: .done(NoteTitleSuggestion(title: NotesSampleText.suggestedTitle, tags: NotesSampleText.suggestedTags)))
        }
        s.scene("detail-unavailable") { aiDetail(availability: .unavailable(.appleIntelligenceOff)) }
        s.gallery("ai", title: { NotesText.galleryAI }) {
            let store = NotesSamples.store()
            if let note = NotesSamples.meeting(in: store) {
                NotesAISection(note: note, session: NotesAISession(ai: NotesPreviewModel.localAI(.available), showsProgress: false,
                                                                    summary: .done(NotesSampleText.summaryDone)),
                               store: store)
                    .frame(width: NotesLook.sideColumn)
            }
        }
        #endif
        s.gallery("tile", title: { NotesText.galleryTile }) {
            let store = NotesSamples.store()
            HStack(alignment: .top, spacing: Space.tileGap) {
                ForEach(store.recent(3)) { note in
                    NoteTile(note: note, store: store, previewHover: note.id == store.notes.first?.id) {}
                        .frame(width: Metrics.Window.tile)
                }
            }
        }
    }

    /// The whole main window with the notes sidebar and `page` selected.
    static func window<Page: View>(_ page: String, query: String? = nil, store: NotesStore = NotesSamples.store(),
                                   @ViewBuilder content: @escaping (NotesStore) -> Page) -> some View {
        RenderBoard {
            StaticMainWindow(pages: NotesPages.sidebar(store), selection: page, query: query,
                             searchPrompt: page == NotesPages.all ? NotesText.searchPrompt : nil) {
                content(store)
            }
        }
    }

    /// The note "Team meeting" opened from All Notes (with the ai module: a model is available,
    /// nothing asked yet).
    static func detail() -> some View {
        #if MODUL_AI
        return aiDetail()
        #else
        let store = NotesSamples.store()
        let navigator = NotesNavigator(openNote: NotesSamples.meeting(in: store)?.id, page: NotesPages.all)
        return window(NotesPages.all, store: store) { NotesAllPage(store: $0, navigator: navigator) }
        #endif
    }

    #if MODUL_AI
    /// The note page with the AI column in a given state.
    static func aiDetail(availability: AIAvailability = .available, summary: NotesAISession.Summary = .idle,
                         suggestion: NotesAISession.Suggestion = .idle) -> some View {
        let store = NotesSamples.store()
        let id = NotesSamples.meeting(in: store)?.id ?? 1
        let navigator = NotesNavigator(openNote: id, page: NotesPages.all)
        let board = NotesAIBoard()
        board.set(NotesAISession(ai: NotesPreviewModel.localAI(availability), showsProgress: false, summary: summary,
                                 suggestion: suggestion), for: id)
        return window(NotesPages.all, store: store) { NotesAllPage(store: $0, navigator: navigator) }
            .environment(\.notesAIBoard, board)
    }
    #endif
}
#endif
