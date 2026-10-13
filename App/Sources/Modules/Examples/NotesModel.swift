import Foundation

// The data of the example feature "Notes": notes, collections, where a note came from. Plain
// values; `NotesStore` reads and writes them.

/// Where a note came from (stored as text, so new kinds can be added without a migration).
enum NoteSource: String, CaseIterable, Sendable {
    case typed, clipboard, ai

    var symbol: String {
        switch self {
        case .typed: "square.and.pencil"
        case .clipboard: "doc.on.clipboard"
        case .ai: "sparkles"
        }
    }
}

struct NoteItem: Identifiable, Equatable {
    let id: Int64
    var title: String
    var body: String
    var collectionID: Int64?
    var pinned: Bool
    var trashedAt: Date?
    let createdAt: Date
    var updatedAt: Date
    var source: NoteSource

    var isTrashed: Bool { trashedAt != nil }

    /// The first non-empty line of the body, for tiles and the hero.
    var preview: String {
        body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
    }

    /// Seed for generated artwork: stable per note.
    var seed: String { "note-\(id)" }
}

extension NoteItem: RowDecodable {
    init(row: SQLRow) throws {
        id = Int64(try row.require("id", SQLRow.int))
        title = row.string("title") ?? ""
        body = row.string("body") ?? ""
        collectionID = row.int("collection_id").map(Int64.init)
        pinned = row.bool("pinned") ?? false
        trashedAt = row.date("trashed_at")
        createdAt = try row.require("created_at", SQLRow.date)
        updatedAt = try row.require("updated_at", SQLRow.date)
        source = NoteSource(rawValue: row.string("source") ?? "") ?? .typed
    }
}

struct NoteCollection: Identifiable, Equatable {
    let id: Int64
    var name: String
    var symbol: String
    var order: Int

    var seed: String { "collection-\(id)" }
}

extension NoteCollection: RowDecodable {
    init(row: SQLRow) throws {
        id = Int64(try row.require("id", SQLRow.int))
        name = row.string("name") ?? ""
        symbol = row.string("symbol") ?? "folder.fill"
        order = row.int("sort_order") ?? 0
    }
}

/// What an open editor shows. Loaded once (an edit not written yet wins over the stored note),
/// changed by typing, and it follows the store when the store changed the note itself while no
/// edit waits ("Add to Note", "Use Title"): otherwise the next keystroke would write the old text
/// back over that change.
struct NoteEditorText: Equatable {
    var title = ""
    var body = ""
    private(set) var isLoaded = false

    mutating func load(_ note: NoteItem, draft: (title: String, body: String)?) {
        guard !isLoaded else { return }
        title = draft?.title ?? note.title
        body = draft?.body ?? note.body
        isLoaded = true
    }

    /// The stored note changed. With nothing typed waiting to be written the editor and the store
    /// agreed before, so the store's version is the newer one.
    mutating func follow(_ note: NoteItem, draft: (title: String, body: String)?) {
        guard isLoaded, draft == nil else { return }
        title = note.title
        body = note.body
    }
}

/// A title the local model suggested, with up to three one-word tags.
struct NoteTitleSuggestion: Equatable {
    var title: String
    var tags: [String]
}

extension NoteItem {
    /// The title, or "Untitled" for a note without one.
    var shownTitle: String { NoteItem.shownTitle(title) }

    static func shownTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NotesText.untitled : title
    }

    /// The same note with the text as it is in the editor (not written yet).
    static func with(_ note: NoteItem, title: String, body: String) -> NoteItem {
        var copy = note
        copy.title = title
        copy.body = body
        return copy
    }
}
