import Foundation
import Observation

extension SettingKey {
    /// Collection new notes and clipboard captures go to (0: none).
    static var notesDefaultCollection: SettingKey<Int> { .init("notes.defaultCollection", default: 0) }
    /// How a collection page shows its notes: "grid" or "list".
    static var notesLayout: SettingKey<String> { .init("notes.layout", default: "grid") }
}

/// The only way the UI touches notes: a SQLite file of its own (`Paths.database("notes")`) with
/// numbered migrations, an FTS5 index kept in sync by triggers (plain LIKE search when FTS5 is
/// missing or broken), sample data in the UI language on the first open, and in-memory lists the
/// views observe. Every write goes to the file at once; text edits are collected and written after
/// a short pause (`edit`, `flush`).
///
///     let store = NotesStore.shared
///     let note = store.add(title: "Packing list", body: "Passport", collectionID: nil)
///     let hits = store.search("pass")
@Observable final class NotesStore {
    /// Live notes (not in the trash), last edited first.
    private(set) var notes: [NoteItem] = []
    /// Notes in the trash, last trashed first.
    private(set) var trashed: [NoteItem] = []
    /// Collections in their order.
    private(set) var collections: [NoteCollection] = []
    /// Set when the file could not be opened or written: the store then keeps working in memory,
    /// and the settings pane says that changes are not kept.
    private(set) var problem: String?
    /// An edit waits to be written (the editor shows "Saving").
    private(set) var isSaving = false

    /// The database file (nil: in memory).
    @ObservationIgnored let url: URL?
    /// Search uses the FTS5 index (false: LIKE).
    @ObservationIgnored private(set) var fullText: Bool
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored private var db: Database?
    /// Text edits not written yet, by note id.
    @ObservationIgnored private var pending: [Int64: (title: String, body: String)] = [:]
    @ObservationIgnored private var flushTask: Task<Void, Never>?

    /// Notes in the trash longer than this are deleted for good (the background job, daily).
    static let trashKeep: TimeInterval = 30 * 86_400
    /// Pause after the last keystroke before an edit is written.
    static let autosaveDelay: Duration = .milliseconds(600)

    // MARK: Shared store

    private static var current: NotesStore?

    /// The app's store, opened on first use. Headless runs (tests, renders, `--selftest`, which
    /// builds the real main window) keep it in memory, so they never create the file.
    static var shared: NotesStore {
        if let current { return current }
        let store = NotesStore(url: RenderMode.isHeadless ? nil : Paths.database("notes"))
        current = store
        return store
    }

    /// `--demo examples` swaps in sample data in memory, so the demo never writes the real file.
    static func useInstead(_ store: NotesStore) { current = store }

    /// Writes pending edits of the shared store (terminate hook).
    static func flushShared() { current?.flush() }

    // MARK: Opening

    /// Opens (or creates) the file and migrates it; `url: nil` keeps everything in memory.
    /// `fullText: false` searches with LIKE only (tests of the fallback). `seed` adds the sample
    /// notes once, when the database is new.
    init(url: URL?, now: @escaping () -> Date = Date.init, fullText: Bool = true, seed: Bool = true) {
        self.url = url
        self.now = now
        self.fullText = false
        do {
            db = try Database(url: url, migrations: Self.migrations)
        } catch {
            Log.error("notes: opening \(url?.lastPathComponent ?? "memory") failed: \(error)", "notes")
            problem = NotesText.storeProblem
            db = try? Database(url: nil, migrations: Self.migrations)
        }
        if fullText { self.fullText = setUpFullText() }
        if seed, meta("seeded") == nil { insertSamples() }
        reload()
    }

    /// Never edit a shipped migration: add the next one.
    static let migrations: [Database.Migration] = [
        .init(1, """
            CREATE TABLE collections(id INTEGER PRIMARY KEY, name TEXT NOT NULL, symbol TEXT NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE notes(id INTEGER PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL,
              collection_id INTEGER REFERENCES collections(id) ON DELETE SET NULL,
              pinned INTEGER NOT NULL DEFAULT 0, trashed_at REAL, created_at REAL NOT NULL, updated_at REAL NOT NULL);
            CREATE INDEX notes_updated ON notes(updated_at);
            CREATE TABLE notes_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            """),
        // where a note came from: added later, old rows count as typed
        .init(2, "ALTER TABLE notes ADD COLUMN source TEXT NOT NULL DEFAULT 'typed'"),
    ]

    /// The search index: an external-content FTS5 table over title and body, kept in sync by
    /// triggers, so every writer updates it (VoiceBud's history index). Not a migration: a SQLite
    /// without FTS5 must still open the notes, it only searches with LIKE then.
    static let fullTextSQL = """
        CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(title, body, content='notes', content_rowid='id',
          tokenize='unicode61 remove_diacritics 2');
        CREATE TRIGGER IF NOT EXISTS notes_fts_ai AFTER INSERT ON notes BEGIN
          INSERT INTO notes_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
        END;
        CREATE TRIGGER IF NOT EXISTS notes_fts_ad AFTER DELETE ON notes BEGIN
          INSERT INTO notes_fts(notes_fts, rowid, title, body) VALUES ('delete', old.id, old.title, old.body);
        END;
        CREATE TRIGGER IF NOT EXISTS notes_fts_au AFTER UPDATE OF title, body ON notes BEGIN
          INSERT INTO notes_fts(notes_fts, rowid, title, body) VALUES ('delete', old.id, old.title, old.body);
          INSERT INTO notes_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
        END;
        """

    private func setUpFullText() -> Bool {
        guard let db else { return false }
        do {
            let existed = try !db.query("SELECT name FROM sqlite_master WHERE name = 'notes_fts'") { $0.string("name") }.isEmpty
            try db.transaction {
                try db.executeScript(Self.fullTextSQL)
                // an index added to a database that already has notes starts empty
                if !existed { try db.execute("INSERT INTO notes_fts(notes_fts) VALUES('rebuild')") }
            }
            return true
        } catch {
            Log.warn("notes: no full-text index, searching with LIKE (\(error))", "notes")
            return false
        }
    }

    // MARK: Reading

    func note(_ id: Int64) -> NoteItem? { notes.first { $0.id == id } ?? trashed.first { $0.id == id } }
    func collection(_ id: Int64?) -> NoteCollection? { id.flatMap { id in collections.first { $0.id == id } } }
    func notes(in collectionID: Int64) -> [NoteItem] { notes.filter { $0.collectionID == collectionID } }
    var pinned: [NoteItem] { notes.filter(\.pinned) }
    func recent(_ count: Int) -> [NoteItem] { Array(notes.prefix(count)) }

    /// The collection new notes go to: the setting when that collection exists, else none.
    var defaultCollectionID: Int64? {
        let id = Int64(Settings.shared[.notesDefaultCollection])
        return collection(id)?.id
    }

    /// Live notes matching every word of `query` (prefix match, case and accents ignored with the
    /// index), last edited first. An empty query gives all notes; a query without letters or
    /// digits gives none.
    func search(_ query: String) -> [NoteItem] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return notes }
        guard let words = Self.searchWords(text) else { return [] }
        let ids = (fullText ? fullTextIDs(words) : nil) ?? likeIDs(words)
        return notes.filter { ids.contains($0.id) }
    }

    /// Letters and digits only, at most 12 words (VoiceBud's FTS input rule). Nil when nothing
    /// searchable is left.
    static func searchWords(_ input: String) -> [String]? {
        let words = input.split { !($0.isLetter || $0.isNumber) }.map(String.init).prefix(12)
        return words.isEmpty ? nil : Array(words)
    }

    /// Each word quoted and prefix-matched: `"pack"* "lis"*`.
    static func ftsQuery(_ words: [String]) -> String {
        words.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    /// Nil when the index cannot answer (missing or broken): the caller falls back to LIKE.
    private func fullTextIDs(_ words: [String]) -> Set<Int64>? {
        guard let db else { return nil }
        do {
            let ids = try db.query("SELECT rowid AS id FROM notes_fts WHERE notes_fts MATCH ?", [.text(Self.ftsQuery(words))]) {
                $0.int("id").map(Int64.init)
            }
            return Set(ids.compactMap { $0 })
        } catch {
            Log.warn("notes: full-text search failed, using LIKE (\(error))", "notes")
            fullText = false
            return nil
        }
    }

    private func likeIDs(_ words: [String]) -> Set<Int64> {
        guard let db else { return [] }
        let clause = words.indices.map { "(title LIKE ?\($0 + 1) ESCAPE '\\' OR body LIKE ?\($0 + 1) ESCAPE '\\')" }
            .joined(separator: " AND ")
        let args: [SQLValue] = words.map { word in
            .text("%" + word.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_") + "%")
        }
        let ids = (try? db.query("SELECT id FROM notes WHERE trashed_at IS NULL AND \(clause)", args) { $0.int("id").map(Int64.init) }) ?? []
        return Set(ids.compactMap { $0 })
    }

    // MARK: Writing

    @discardableResult
    func add(title: String, body: String, collectionID: Int64? = nil, source: NoteSource = .typed, pinned: Bool = false) -> NoteItem? {
        let at = now()
        let ok = write("add") {
            try $0.execute("""
                INSERT INTO notes(title, body, collection_id, pinned, created_at, updated_at, source)
                VALUES(?, ?, ?, ?, ?, ?, ?)
                """, [.text(title), .text(body), collectionID.map { .int($0) } ?? .null, .of(pinned), .of(at), .of(at),
                      .text(source.rawValue)])
        }
        guard ok, let id = db?.lastInsertRowID else { return nil }
        return note(id)
    }

    /// Keeps a text edit and writes it after `autosaveDelay` without further edits (the editor
    /// calls this on every change). `flush()` writes at once.
    func edit(_ id: Int64, title: String, body: String) {
        pending[id] = (title, body)
        isSaving = true
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// The edit not written yet for a note, if any.
    func draft(_ id: Int64) -> (title: String, body: String)? { pending[id] }

    /// Writes every pending edit (editor closes, app quits).
    func flush() {
        flushTask?.cancel()
        flushTask = nil
        let edits = pending
        pending = [:]
        isSaving = false
        guard !edits.isEmpty else { return }
        let at = now()
        write("save") { db in
            for (id, edit) in edits {
                guard let old = self.note(id), old.title != edit.title || old.body != edit.body else { continue }
                try db.execute("UPDATE notes SET title = ?, body = ?, updated_at = ? WHERE id = ?",
                               [.text(edit.title), .text(edit.body), .of(at), .int(id)])
            }
        }
    }

    func setPinned(_ id: Int64, _ on: Bool) {
        write("pin") { try $0.execute("UPDATE notes SET pinned = ? WHERE id = ?", [.of(on), .int(id)]) }
    }

    func move(_ id: Int64, to collectionID: Int64?) {
        write("move") {
            try $0.execute("UPDATE notes SET collection_id = ?, updated_at = ? WHERE id = ?",
                           [collectionID.map { .int($0) } ?? .null, .of(self.now()), .int(id)])
        }
    }

    /// Replaces the title (a suggestion taken over), keeping the body.
    func rename(_ id: Int64, to title: String) {
        flush()
        write("rename") {
            try $0.execute("UPDATE notes SET title = ?, updated_at = ? WHERE id = ?", [.text(title), .of(self.now()), .int(id)])
        }
    }

    /// Adds text at the end of a note's body, after a blank line (a summary taken over).
    func append(_ id: Int64, _ text: String) {
        flush()
        guard let old = note(id) else { return }
        let body = old.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text : old.body + "\n\n" + text
        write("append") {
            try $0.execute("UPDATE notes SET body = ?, updated_at = ? WHERE id = ?", [.text(body), .of(self.now()), .int(id)])
        }
    }

    func trash(_ id: Int64) {
        pending[id] = nil
        write("trash") { try $0.execute("UPDATE notes SET trashed_at = ?, pinned = 0 WHERE id = ?", [.of(self.now()), .int(id)]) }
    }

    func restore(_ id: Int64) {
        write("restore") { try $0.execute("UPDATE notes SET trashed_at = NULL WHERE id = ?", [.int(id)]) }
    }

    func delete(_ id: Int64) {
        pending[id] = nil
        write("delete") { try $0.execute("DELETE FROM notes WHERE id = ?", [.int(id)]) }
    }

    /// Deletes notes that have been in the trash longer than `keep`; returns how many.
    @discardableResult
    func purgeTrash(keep: TimeInterval = NotesStore.trashKeep) -> Int {
        let cutoff = now().addingTimeInterval(-keep)
        var removed = 0
        write("purge") { db in
            try db.execute("DELETE FROM notes WHERE trashed_at IS NOT NULL AND trashed_at < ?", [.of(cutoff)])
            removed = db.changes
        }
        return removed
    }

    /// Deletes every note and collection and adds the sample data again, in the UI language.
    func reloadSamples() {
        pending = [:]
        write("samples") { db in
            try db.execute("DELETE FROM notes")
            try db.execute("DELETE FROM collections")
        }
        insertSamples()
        reload()
    }

    // MARK: Internals

    /// Runs `body` in a transaction and re-reads the lists; logs and keeps the problem on failure.
    @discardableResult
    private func write(_ what: String, _ body: (Database) throws -> Void) -> Bool {
        guard let db else { return false }
        do {
            try db.transaction { try body(db) }
            reload()
            return true
        } catch {
            Log.error("notes: \(what) failed: \(error)", "notes")
            problem = NotesText.storeProblem
            return false
        }
    }

    /// Re-reads collections and notes from the file.
    func reload() {
        guard let db else { return }
        do {
            collections = try db.query(NoteCollection.self, "SELECT * FROM collections ORDER BY sort_order, id")
            let all = try db.query(NoteItem.self, "SELECT * FROM notes ORDER BY updated_at DESC, id DESC")
            notes = all.filter { !$0.isTrashed }
            trashed = all.filter(\.isTrashed).sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) }
        } catch {
            Log.error("notes: reading failed: \(error)", "notes")
            problem = NotesText.storeProblem
        }
    }

    private func meta(_ key: String) -> String? {
        guard let db, let rows = try? db.query("SELECT value FROM notes_meta WHERE key = ?", [.text(key)], { $0.string("value") })
        else { return nil }
        return rows.first ?? nil
    }

    private func insertSamples() {
        let at = now()
        write("seed") { db in
            for c in NotesSeed.collections {
                try db.execute("INSERT INTO collections(id, name, symbol, sort_order) VALUES(?, ?, ?, ?)",
                               [.int(c.id), .text(c.name()), .text(c.symbol), .of(c.order)])
            }
            for n in NotesSeed.notes {
                let updated = at.addingTimeInterval(-n.age)
                try db.execute("""
                    INSERT INTO notes(title, body, collection_id, pinned, created_at, updated_at, source)
                    VALUES(?, ?, ?, ?, ?, ?, ?)
                    """, [.text(n.title()), .text(n.body()), n.collection.map { .int($0) } ?? .null, .of(n.pinned),
                          .of(updated.addingTimeInterval(-n.written)), .of(updated), .text(n.source.rawValue)])
            }
            try db.execute("INSERT OR REPLACE INTO notes_meta(key, value) VALUES('seeded', ?)", [.text(Localizer.shared.lang.rawValue)])
        }
    }
}
