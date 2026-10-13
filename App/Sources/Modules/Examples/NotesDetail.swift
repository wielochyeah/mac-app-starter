#if MODUL_WINDOW
import SwiftUI

/// One note: the album-like header (collection, title, when edited, Copy and Pin), the editor
/// (title, text, collection, trash) that saves while typing, and with the ai module the local AI
/// actions beside it (below it when the window is narrow).
struct NoteDetailPage: View {
    let noteID: Int64
    /// The page the back link returns to.
    let backTitle: String
    var store: NotesStore
    var navigator: NotesNavigator
    #if MODUL_AI
    /// Renders put a board with prepared sessions into the environment.
    @Environment(\.notesAIBoard) private var board
    #endif

    @State private var editing = NoteEditorText()
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        if let note = store.note(noteID) {
            let shown = NoteItem.shownTitle(editing.isLoaded ? editing.title : note.title)
            PageScaffold(shown, showsTitle: false) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Button { navigator.close() } label: {
                        Label(backTitle, systemImage: "chevron.left")
                    }
                    .buttonStyle(PlainStyle())
                    .font(TypeScale.bodyMedium)
                    .foregroundStyle(t.accentText)
                    .keyboardShortcut(.cancelAction)
                    DetailHeader(eyebrow: store.collection(note.collectionID)?.name ?? NotesText.noCollection, title: shown,
                                 meta: NotesText.meta(note, now: store.now()), seed: note.seed, symbol: NotesLook.symbol(note, in: store),
                                 primary: HeaderAction(CommonText.copy, symbol: "doc.on.doc") {
                                     NotesActions.copy(NoteItem.with(note, title: editing.title, body: editing.body))
                                 },
                                 secondary: HeaderAction(note.pinned ? NotesText.unpin : NotesText.pin,
                                                         symbol: note.pinned ? "pin.slash" : "pin") {
                                     store.setPinned(note.id, !note.pinned)
                                 })
                }
                #if MODUL_AI
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Space.l) {
                        // the ideal width lets ViewThatFits judge the row by its narrowest editor
                        editor(note).frame(minWidth: NotesLook.editorMinWidth, idealWidth: NotesLook.editorMinWidth,
                                           maxWidth: .infinity)
                        assistant(note).frame(width: NotesLook.sideColumn)
                    }
                    VStack(alignment: .leading, spacing: Space.l) {
                        editor(note)
                        assistant(note)
                    }
                }
                #else
                editor(note)
                #endif
            }
            .onAppear { editing.load(note, draft: store.draft(noteID)) }
            .onChange(of: note) { _, stored in editing.follow(stored, draft: store.draft(noteID)) }
            .onDisappear { leave() }
        }
    }

    private func editor(_ note: NoteItem) -> some View {
        NoteEditor(title: Binding(get: { editing.isLoaded ? editing.title : note.title }, set: { editing.title = $0; changed() }),
                   text: Binding(get: { editing.isLoaded ? editing.body : note.body }, set: { editing.body = $0; changed() }),
                   collection: Binding(get: { note.collectionID ?? 0 }, set: { store.move(note.id, to: $0 == 0 ? nil : $0) }),
                   collections: store.collections, saving: store.isSaving) {
            store.trash(note.id)
            navigator.close()
        }
    }

    #if MODUL_AI
    /// Summary and title suggestion work on the text as it is in the editor.
    private func assistant(_ note: NoteItem) -> some View {
        NotesAISection(note: NoteItem.with(note, title: editing.isLoaded ? editing.title : note.title,
                                           body: editing.isLoaded ? editing.body : note.body),
                       session: (board ?? .shared).session(for: note.id), store: store)
    }
    #endif

    private func changed() {
        store.edit(noteID, title: editing.title, body: editing.body)
    }

    /// Writes the last edit; a new note left empty goes away again.
    private func leave() {
        store.flush()
        if let note = store.note(noteID), note.title.isEmpty, note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.delete(noteID)
        }
    }
}

/// The editor card: title field, text, and a footer with the collection, the save state and
/// "Move to Trash". Renders draw the fields as text (offscreen captures cannot draw AppKit fields).
struct NoteEditor: View {
    @Binding var title: String
    @Binding var text: String
    @Binding var collection: Int64
    let collections: [NoteCollection]
    var saving: Bool
    let trash: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.renderStatic) private var renderStatic

    var body: some View {
        let t = Theme(scheme)
        Card {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(NotesText.titleLabel).font(TypeScale.secondaryMedium).foregroundStyle(t.fg2)
                if renderStatic {
                    Text(NoteItem.shownTitle(title)).font(TypeScale.headline).foregroundStyle(title.isEmpty ? t.fg3 : t.fg).lineLimit(1)
                } else {
                    TextField("", text: $title, prompt: Text(NotesText.untitled))
                        .textFieldStyle(.plain)
                        .font(TypeScale.headline)
                        .foregroundStyle(t.fg)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.rowX)
            .padding(.vertical, Space.s)
            Separator()
            Group {
                if renderStatic {
                    Text(text.isEmpty ? NotesText.bodyPlaceholder : text)
                        .foregroundStyle(text.isEmpty ? t.fg3 : t.fg)
                        .lineSpacing(TypeScale.proseLineSpacing)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, Space.rowX)
                        .padding(.vertical, Space.s)
                } else {
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(t.fg)
                        .lineSpacing(TypeScale.proseLineSpacing)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, Space.xs)
                        .accessibilityLabel(NotesText.bodyLabel)
                }
            }
            .font(TypeScale.reading)
            .frame(minHeight: NotesLook.editorMinHeight, alignment: .topLeading)
            Separator()
            HStack(spacing: Space.s) {
                MenuPicker([(Int64(0), NotesText.noCollection)] + collections.map { ($0.id, $0.name) }, selection: $collection)
                    .fixedSize()
                    .accessibilityLabel(NotesText.columnCollection)
                Spacer(minLength: Space.xs)
                Text(saving ? NotesText.saving : NotesText.saved)
                    .font(TypeScale.secondary)
                    .foregroundStyle(t.fg3)
                    .lineLimit(1)
                Chip(NotesText.moveToTrash, symbol: "trash", action: trash).fixedSize()
            }
            .padding(.horizontal, Space.rowX)
            .padding(.vertical, Space.xs)
        }
    }
}
#endif
