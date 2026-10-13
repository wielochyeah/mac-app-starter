#if TESTING
import Foundation
import SQLite3

private struct Note: RowDecodable, Equatable {
    let id: Int
    let text: String
    let pinned: Bool

    init(id: Int, text: String, pinned: Bool) {
        self.id = id
        self.text = text
        self.pinned = pinned
    }

    init(row: SQLRow) throws {
        id = try row.require("id", SQLRow.int)
        text = try row.require("text", SQLRow.string)
        pinned = row.bool("pinned") ?? false
    }
}

/// A second process in the middle of migration 1 of the same new file: it holds the write lock
/// for `seconds`, then sets the version and lets go.
private nonisolated func otherOpenerMigrating(_ path: String, holdFor seconds: Double) {
    var db: OpaquePointer?
    sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
    sqlite3_exec(db, "BEGIN IMMEDIATE; CREATE TABLE notes(id INTEGER PRIMARY KEY, text TEXT NOT NULL);", nil, nil, nil)
    Thread.sleep(forTimeInterval: seconds)
    sqlite3_exec(db, "PRAGMA user_version = 1; COMMIT;", nil, nil, nil)
    sqlite3_close(db)
}

final class DatabaseTests: TestSuite {
    static let v1 = Database.Migration(1, "CREATE TABLE notes(id INTEGER PRIMARY KEY, text TEXT NOT NULL)")
    static let v2 = Database.Migration(2, "ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0; CREATE INDEX notes_pinned ON notes(pinned)")

    override class func register() {
        test("migrations run in order and set user_version") {
            let url = tempDir().appendingPathComponent("db.sqlite")
            let db = try Database(url: url, migrations: [v1])
            expectEqual(db.userVersion, 1)
            try db.execute("INSERT INTO notes(text) VALUES(?)", ["first"])
            db.close()
            let db2 = try Database(url: url, migrations: [v1, v2])
            expectEqual(db2.userVersion, 2)
            let notes = try db2.query(Note.self, "SELECT * FROM notes")
            expectEqual(notes, [Note(id: 1, text: "first", pinned: false)])
        }

        test("reopening runs nothing twice") {
            let url = tempDir().appendingPathComponent("db.sqlite")
            _ = try Database(url: url, migrations: [v1, v2])
            let again = try Database(url: url, migrations: [v1, v2])
            expectEqual(again.userVersion, 2)
        }

        test("file databases use WAL") {
            let db = try Database(url: tempDir().appendingPathComponent("db.sqlite"), migrations: [v1])
            expectEqual(db.journalMode, "wal")
        }

        test("a newer schema is refused") {
            let url = tempDir().appendingPathComponent("db.sqlite")
            _ = try Database(url: url, migrations: [v1, v2])
            expectThrows { _ = try Database(url: url, migrations: [v1]) }
        }

        test("migration numbers must be 1, 2, 3") {
            expectThrows { _ = try Database(url: nil, migrations: [.init(2, "SELECT 1")]) }
            expectThrows { _ = try Database(url: nil, migrations: [v1, v1]) }
        }

        test("a failing migration rolls back") {
            let url = tempDir().appendingPathComponent("db.sqlite")
            _ = try Database(url: url, migrations: [v1])
            expectThrows { _ = try Database(url: url, migrations: [v1, .init(2, "CREATE TABLE x(a); NOT SQL")]) }
            let db = try Database(url: url, migrations: [v1])
            expectEqual(db.userVersion, 1)
            expectEqual(try db.query("SELECT name FROM sqlite_master WHERE name = 'x'") { $0.string("name") }.count, 0)
        }

        test("typed values and parameters") {
            let db = try Database(url: nil, migrations: [.init(1, "CREATE TABLE t(i INTEGER, d REAL, s TEXT, b BLOB, n TEXT)")])
            try db.execute("INSERT INTO t VALUES(?, ?, ?, ?, ?)", [.int(42), .double(1.5), "text ä", .blob(Data([1, 2, 3])), nil])
            let row = try db.query("SELECT * FROM t") { $0 }.first
            expectEqual(row?.int("i"), 42)
            expectEqual(row?.double("d"), 1.5)
            expectEqual(row?.string("s"), "text ä")
            expectEqual(row?.data("b"), Data([1, 2, 3]))
            expectEqual(row?["n"], SQLValue.null)
            expectEqual(db.lastInsertRowID, 1)
        }

        test("two openers migrating the same new file: the second sees the first's work") {
            let path = tempDir().appendingPathComponent("race.sqlite").path
            var setup: OpaquePointer?
            sqlite3_open_v2(path, &setup, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
            sqlite3_exec(setup, "PRAGMA journal_mode = WAL;", nil, nil, nil)
            sqlite3_close(setup)
            let p = path
            Thread.detachNewThread { otherOpenerMigrating(p, holdFor: 0.5) }
            Thread.sleep(forTimeInterval: 0.1)   // it read version 0 and holds the lock now
            do {
                let db = try Database(url: URL(fileURLWithPath: path), migrations: [v1, v2])
                expectEqual(db.userVersion, 2, "migration 1 skipped, migration 2 applied")
                try db.execute("INSERT INTO notes(text, pinned) VALUES('a', 1)")
            } catch {
                fail("second opener failed: \(error)")
            }
        }

        test("deleted rows are overwritten (secure_delete)") {
            let db = try Database(url: tempDir().appendingPathComponent("s.sqlite"), migrations: [v1])
            expectEqual(try db.query("PRAGMA secure_delete") { $0.int("secure_delete") }.first, 1)
        }

        test("transactions roll back on error") {
            let db = try Database(url: nil, migrations: [v1])
            expectThrows {
                try db.transaction {
                    try db.execute("INSERT INTO notes(text) VALUES('a')")
                    try db.execute("INSERT INTO notes(text) VALUES(NULL)")
                }
            }
            expectEqual(try db.query("SELECT count(*) AS n FROM notes") { $0.int("n") }.first, 0)
        }
    }
}
#endif
