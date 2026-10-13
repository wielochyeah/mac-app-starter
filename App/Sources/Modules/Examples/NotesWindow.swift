#if MODUL_WINDOW
import SwiftUI

// The notes in the main window (skill `neue-ansicht`): Overview replaces the starter's home page
// (section main, order 0), All Notes with the toolbar search, Trash, and one page per collection.
// A note opens on top of the page it was opened from (`NotesNavigator`), with a back link.

enum NotesPages {
    static let overview = "notes.overview"
    static let all = "notes.all"
    static let trash = "notes.trash"
    static let collectionPrefix = "notes.collection."

    static func collection(_ id: Int64) -> String { collectionPrefix + String(id) }

    static func register() {
        Registry.pages += fixedPages
        WindowSearch.enable(page: all) { NotesText.searchPrompt }
        // collections live in the database: their pages come once the app has opened it (never
        // in renders, tests or --selftest, which must not create the file)
        Registry.launchHooks.append {
            guard !RenderMode.isHeadless, !RenderMode.isStatic else { return }
            Registry.pages += collectionPages(NotesStore.shared)
        }
        OnboardingFeatures.items.append(OnboardingFeature(id: "notes.collections", order: 20, symbol: "square.grid.2x2.fill",
                                                          tint: .teal, title: { NotesText.featureCollectionsTitle },
                                                          detail: { NotesText.featureCollectionsDetail }))
    }

    /// Overview, All Notes and Trash; the content reads the shared store when the window shows it.
    static var fixedPages: [AppPage] {
        [
            AppPage(id: overview, section: .main, order: 0, title: { NotesText.overview }, symbol: "house.fill") {
                AnyView(NotesOverviewPage())
            },
            AppPage(id: all, section: .library, order: 0, title: { NotesText.allNotes }, symbol: "note.text") {
                AnyView(NotesAllPage())
            },
            AppPage(id: trash, section: .library, order: 10, title: { NotesText.trash }, symbol: "trash") {
                AnyView(NotesTrashPage())
            },
        ]
    }

    static func collectionPages(_ store: NotesStore) -> [AppPage] {
        store.collections.map { c in
            AppPage(id: collection(c.id), section: .collections, order: c.order,
                    title: { store.collection(c.id)?.name ?? c.name }, symbol: c.symbol) {
                AnyView(NotesCollectionPage(collectionID: c.id, store: store))
            }
        }
    }

    /// The sidebar of the render scenes: the same pages, with a sample store.
    static func sidebar(_ store: NotesStore) -> [AppPage] { fixedPages + collectionPages(store) }

    /// The page title the back link of an open note names.
    static func title(of page: String, in store: NotesStore) -> String {
        switch page {
        case overview: NotesText.overview
        case trash: NotesText.trash
        case all: NotesText.allNotes
        default:
            Int64(page.dropFirst(collectionPrefix.count)).flatMap { store.collection($0)?.name } ?? NotesText.allNotes
        }
    }
}

/// Which note is open on top of which page. One per window; renders make their own.
@Observable final class NotesNavigator {
    static let shared = NotesNavigator()

    private(set) var openNote: Int64?
    private(set) var page: String?

    init(openNote: Int64? = nil, page: String? = nil) {
        self.openNote = openNote
        self.page = page
    }

    func open(_ id: Int64, on page: String) {
        self.page = page
        openNote = id
    }

    func close() { openNote = nil }

    /// The note open on `page`, if any.
    func note(on page: String) -> Int64? { self.page == page ? openNote : nil }

    /// A page left through the sidebar forgets its open note.
    func leave(_ page: String) {
        if self.page == page { openNote = nil }
    }

    /// From outside the window (status menu, island, hotkey): the note on the notes page that is
    /// showing, else on All Notes, and the window to the front.
    func show(_ id: Int64, window: MainWindowModel = .shared) {
        let current = window.currentPage?.id ?? ""
        let target = current.hasPrefix("notes.") && current != NotesPages.trash ? current : NotesPages.all
        open(id, on: target)
        AppActions.openMainWindow(page: target)
    }
}

/// A notes page, or the note opened on top of it.
struct NotesPageHost<Content: View>: View {
    let page: String
    var store: NotesStore
    var navigator: NotesNavigator
    let content: Content

    init(page: String, store: NotesStore, navigator: NotesNavigator, @ViewBuilder content: () -> Content) {
        self.page = page
        self.store = store
        self.navigator = navigator
        self.content = content()
    }

    var body: some View {
        Group {
            if let id = navigator.note(on: page), store.note(id) != nil {
                NoteDetailPage(noteID: id, backTitle: NotesPages.title(of: page, in: store), store: store, navigator: navigator)
                    .id(id)
            } else {
                content
            }
        }
        .onDisappear { navigator.leave(page) }
    }
}

// MARK: - Pages

/// Overview: the most recent pinned note as the hero, shelves of recently edited and pinned
/// notes, the collections as a list.
struct NotesOverviewPage: View {
    var store: NotesStore = .shared
    var navigator: NotesNavigator = .shared

    var body: some View {
        NotesPageHost(page: NotesPages.overview, store: store, navigator: navigator) {
            if store.notes.isEmpty {
                NotesEmptyPage(store: store, navigator: navigator, page: NotesPages.overview)
            } else {
                PageScaffold(NotesText.overview, subtitle: NotesText.overviewSubtitle(notes: store.notes.count,
                                                                                      collections: store.collections.count)) {
                    if let hero = store.pinned.first ?? store.notes.first {
                        HeroHeader(eyebrow: hero.pinned ? NotesText.pinnedNote : NotesText.lastEdited, title: hero.shownTitle,
                                   subtitle: hero.preview, seed: hero.seed, symbol: NotesLook.symbol(hero, in: store),
                                   primary: HeaderAction(NotesText.open, symbol: "arrow.up.forward") {
                                       navigator.open(hero.id, on: NotesPages.overview)
                                   },
                                   secondary: HeaderAction(NotesText.newNote, symbol: "plus") {
                                       NotesWindowActions.newNote(in: nil, on: NotesPages.overview, store: store, navigator: navigator)
                                   },
                                   height: Metrics.Window.heroHeightCompact)
                    }
                    Shelf(NotesText.recentlyEdited, seeAll: { MainWindowModel.shared.select(NotesPages.all) },
                          items: store.recent(NotesLook.shelfCount)) { note in
                        NoteTile(note: note, store: store) { navigator.open(note.id, on: NotesPages.overview) }
                    }
                    if !store.pinned.isEmpty {
                        Shelf(NotesText.pinned, items: store.pinned) { note in
                            NoteTile(note: note, store: store) { navigator.open(note.id, on: NotesPages.overview) }
                        }
                    }
                    VStack(alignment: .leading, spacing: Space.s) {
                        PageSectionTitle(NotesText.allCollections)
                        ItemList(items: store.collections.map { c in
                            ItemListItem(id: String(c.id), title: c.name, meta: NotesText.count(store.notes(in: c.id).count),
                                         seed: c.seed, symbol: c.symbol)
                        }, leading: .artwork, open: { item in
                            MainWindowModel.shared.select(NotesPages.collectionPrefix + item.id)
                        })
                    }
                }
            }
        }
    }
}

/// Every live note as a list, filtered by the toolbar search (full-text index).
struct NotesAllPage: View {
    var store: NotesStore = .shared
    var navigator: NotesNavigator = .shared
    /// Renders pass the query; the window passes the toolbar search through the environment.
    var query: String?
    @State private var selection: String?
    @Environment(\.windowSearch) private var windowSearch

    var body: some View {
        let query = self.query ?? windowSearch
        NotesPageHost(page: NotesPages.all, store: store, navigator: navigator) {
            if store.notes.isEmpty {
                NotesEmptyPage(store: store, navigator: navigator, page: NotesPages.all)
            } else {
                let found = store.search(query)
                PageScaffold(NotesText.allNotes,
                             subtitle: query.isEmpty ? NotesText.count(found.count) : NotesText.results(found.count, query)) {
                    NotesNewButton(collection: nil, page: NotesPages.all, store: store, navigator: navigator)
                } content: {
                    if found.isEmpty {
                        NoResults(query: query)
                    } else {
                        NotesList(notes: found, store: store, selection: $selection) { id in
                            navigator.open(id, on: NotesPages.all)
                        }
                    }
                }
            }
        }
    }
}

/// One collection: its notes as tiles or as a list (the choice is kept in `notes.layout`).
struct NotesCollectionPage: View {
    let collectionID: Int64
    var store: NotesStore = .shared
    var navigator: NotesNavigator = .shared
    /// Renders pass the layout; the window reads and writes the setting.
    var layout: String?
    @State private var selection: String?

    var body: some View {
        let page = NotesPages.collection(collectionID)
        let layout = Binding(get: { self.layout ?? Settings.shared[.notesLayout] }, set: { Settings.shared[.notesLayout] = $0 })
        NotesPageHost(page: page, store: store, navigator: navigator) {
            if let collection = store.collection(collectionID) {
                let notes = store.notes(in: collectionID)
                PageScaffold(collection.name, subtitle: NotesText.count(notes.count)) {
                    HStack(spacing: Space.s) {
                        Segmented([("grid", NotesText.tiles), ("list", NotesText.list)], selection: layout)
                            .fixedSize()
                        NotesNewButton(collection: collectionID, page: page, store: store, navigator: navigator)
                    }
                } content: {
                    if notes.isEmpty {
                        PageEmptyState(symbol: collection.symbol, title: NotesText.collectionEmptyTitle,
                                       message: NotesText.collectionEmptyMessage)
                    } else if layout.wrappedValue == "list" {
                        NotesList(notes: notes, store: store, showsCollection: false, selection: $selection) { id in
                            navigator.open(id, on: page)
                        }
                    } else {
                        TileGrid(items: notes) { note in
                            NoteTile(note: note, store: store) { navigator.open(note.id, on: page) }
                        }
                    }
                }
            } else {
                EmptyPage(symbol: "folder", title: NotesText.collectionMissingTitle, message: NotesText.collectionMissingMessage)
            }
        }
    }
}

/// Notes in the trash with the day they were moved there; restore or delete from the context menu.
struct NotesTrashPage: View {
    var store: NotesStore = .shared
    var navigator: NotesNavigator = .shared
    @State private var selection: String?

    var body: some View {
        NotesPageHost(page: NotesPages.trash, store: store, navigator: navigator) {
            PageScaffold(NotesText.trash, subtitle: Self.subtitle) {
                if store.trashed.isEmpty {
                    PageEmptyState(symbol: "trash", title: NotesText.trashEmptyTitle, message: NotesText.trashEmptyMessage)
                } else {
                    // like All Notes, the artwork dimmed: these notes are on their way out
                    ItemList(items: store.trashed.map { note in
                        ItemListItem(id: String(note.id), title: note.shownTitle,
                                     secondary: store.collection(note.collectionID)?.name ?? NotesText.noCollection,
                                     meta: note.trashedAt.map { NotesText.edited($0, now: store.now()) }, seed: note.seed,
                                     symbol: NotesLook.symbol(note, in: store), dimmed: true)
                    }, leading: .artwork,
                             columns: ItemListColumns(title: NotesText.columnTitle, secondary: NotesText.columnCollection,
                                                      meta: NotesText.columnTrashed),
                             selection: $selection) { item in
                        if let id = Int64(item.id) {
                            Button(NotesText.restore) { store.restore(id) }
                            Button(NotesText.deleteNow) { store.delete(id) }
                        }
                    }
                    Footnote(NotesText.trashHint)
                }
            }
        }
    }

    /// Without the background module nothing empties the trash on its own, so the page says so.
    static var subtitle: String {
        #if MODUL_BACKGROUND
        return NotesText.trashSubtitleAuto
        #else
        return NotesText.trashSubtitleManual
        #endif
    }
}

/// No notes at all: one sentence how to get the first, one action.
struct NotesEmptyPage: View {
    var store: NotesStore
    var navigator: NotesNavigator
    let page: String

    var body: some View {
        EmptyPage(symbol: "note.text", title: NotesText.emptyTitle, message: NotesText.emptyMessage,
                  actionTitle: NotesText.newNote) {
            NotesWindowActions.newNote(in: nil, on: page, store: store, navigator: navigator)
        }
    }
}

// MARK: - Building blocks

/// A note as a tile: artwork from the note, title, when it was edited; hover offers Copy.
struct NoteTile: View {
    let note: NoteItem
    var store: NotesStore
    var previewHover = false
    let open: () -> Void

    var body: some View {
        Tile(title: note.shownTitle, subtitle: NotesText.edited(note.updatedAt, now: store.now()), seed: note.seed,
             symbol: NotesLook.symbol(note, in: store),
             action: ArtworkAction(symbol: "doc.on.doc", label: CommonText.copy) { NotesActions.copy(note) },
             previewHover: previewHover, open: open)
    }
}

/// Notes as a list: title, collection, when edited; double click opens, context menu for the rest.
struct NotesList: View {
    let notes: [NoteItem]
    var store: NotesStore
    var showsCollection = true
    @Binding var selection: String?
    let open: (Int64) -> Void

    var body: some View {
        ItemList(items: notes.map { note in
            ItemListItem(id: String(note.id), title: note.shownTitle,
                         secondary: showsCollection ? (store.collection(note.collectionID)?.name ?? NotesText.noCollection) : nil,
                         meta: NotesText.edited(note.updatedAt, now: store.now()), seed: note.seed,
                         symbol: NotesLook.symbol(note, in: store))
        }, leading: .artwork,
                 columns: ItemListColumns(title: NotesText.columnTitle, secondary: showsCollection ? NotesText.columnCollection : nil,
                                          meta: NotesText.columnEdited),
                 selection: $selection, open: { item in Int64(item.id).map(open) }) { item in
            if let id = Int64(item.id), let note = store.note(id) {
                Button(NotesText.open) { open(id) }
                Button(CommonText.copy) { NotesActions.copy(note) }
                Button(note.pinned ? NotesText.unpin : NotesText.pin) { store.setPinned(id, !note.pinned) }
                Divider()
                Button(NotesText.moveToTrash) { store.trash(id) }
            }
        }
    }
}

/// "New Note" on the title line of a page.
struct NotesNewButton: View {
    let collection: Int64?
    let page: String
    var store: NotesStore
    var navigator: NotesNavigator

    var body: some View {
        Chip(NotesText.newNote, symbol: "plus") {
            NotesWindowActions.newNote(in: collection, on: page, store: store, navigator: navigator)
        }
        .fixedSize()
    }
}

enum NotesWindowActions {
    /// An empty note in `collection` (else the default collection), opened on `page`. Left empty,
    /// it is removed again when the editor closes.
    static func newNote(in collection: Int64?, on page: String, store: NotesStore, navigator: NotesNavigator) {
        guard let note = store.add(title: "", body: "", collectionID: collection ?? store.defaultCollectionID) else { return }
        navigator.open(note.id, on: page)
    }
}
#endif
