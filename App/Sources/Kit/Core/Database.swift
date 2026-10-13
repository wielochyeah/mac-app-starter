import Foundation
import SQLite3

/// A value bound to or read from SQLite.
nonisolated enum SQLValue: Equatable, Sendable {
    case null
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
}

extension SQLValue: ExpressibleByIntegerLiteral, ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByNilLiteral {
    init(integerLiteral value: Int64) { self = .int(value) }
    init(stringLiteral value: String) { self = .text(value) }
    init(floatLiteral value: Double) { self = .double(value) }
    init(nilLiteral: ()) { self = .null }
}

extension SQLValue {
    static func of(_ value: Int) -> SQLValue { .int(Int64(value)) }
    static func of(_ value: Bool) -> SQLValue { .int(value ? 1 : 0) }
    static func of(_ value: String?) -> SQLValue { value.map(SQLValue.text) ?? .null }
    static func of(_ value: Date) -> SQLValue { .double(value.timeIntervalSince1970) }
}

/// One result row. Columns are read by name with typed accessors.
struct SQLRow {
    let columns: [String: SQLValue]

    subscript(_ name: String) -> SQLValue { columns[name] ?? .null }

    func int(_ name: String) -> Int? {
        switch self[name] {
        case .int(let v): Int(v)
        case .double(let v): Int(v)
        default: nil
        }
    }

    func double(_ name: String) -> Double? {
        switch self[name] {
        case .double(let v): v
        case .int(let v): Double(v)
        default: nil
        }
    }

    func string(_ name: String) -> String? {
        if case .text(let v) = self[name] { return v }
        return nil
    }

    func data(_ name: String) -> Data? {
        switch self[name] {
        case .blob(let v): v
        case .text(let v): Data(v.utf8)
        default: nil
        }
    }

    func bool(_ name: String) -> Bool? { int(name).map { $0 != 0 } }
    func date(_ name: String) -> Date? { double(name).map(Date.init(timeIntervalSince1970:)) }

    /// Throws `Database.Failure.missingColumn` instead of returning nil (for required columns).
    func require<T>(_ name: String, _ read: (SQLRow) -> (String) -> T?) throws -> T {
        guard let value = read(self)(name) else { throw Database.Failure.missingColumn(name) }
        return value
    }
}

/// Types that can be built from a row: `try db.query(Note.self, "SELECT * FROM notes")`.
protocol RowDecodable {
    init(row: SQLRow) throws
}

/// A tiny sqlite3 wrapper: numbered migrations (`PRAGMA user_version`), WAL, typed rows. No ORM.
///
///     let db = try Database(url: Paths.database("notes"), migrations: [
///         .init(1, "CREATE TABLE notes(id INTEGER PRIMARY KEY, text TEXT NOT NULL, created REAL NOT NULL)"),
///         .init(2, "ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0"),
///     ])
///     try db.execute("INSERT INTO notes(text, created) VALUES(?, ?)", ["Hello", .of(Date())])
///
/// Migrations run in order, each in its own transaction, and are never edited once shipped:
/// add a new one instead. A database written by a newer app version (higher `user_version`)
/// is refused rather than guessed at.
final class Database {
    struct Migration: Sendable {
        let version: Int
        let sql: String
        init(_ version: Int, _ sql: String) {
            self.version = version
            self.sql = sql
        }
    }

    enum Failure: Error, CustomStringConvertible {
        case open(String)
        case prepare(String, sql: String)
        case step(String, sql: String)
        case migration(Int, String)
        case newerSchema(found: Int, known: Int)
        case badMigrations(String)
        case missingColumn(String)
        case closed

        var description: String {
            switch self {
            case .open(let m): "open: \(m)"
            case .prepare(let m, let sql): "prepare: \(m) (\(sql))"
            case .step(let m, let sql): "step: \(m) (\(sql))"
            case .migration(let v, let m): "migration \(v): \(m)"
            case .newerSchema(let found, let known): "database schema \(found) is newer than this app knows (\(known))"
            case .badMigrations(let m): "migrations: \(m)"
            case .missingColumn(let c): "missing column \(c)"
            case .closed: "database is closed"
            }
        }
    }

    nonisolated(unsafe) private var handle: OpaquePointer?
    let url: URL?

    /// Opens (creating if needed) the file and migrates it. `url == nil` gives an in-memory database.
    init(url: URL?, migrations: [Migration]) throws {
        self.url = url
        if let url {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        let path = url?.path ?? ":memory:"
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(handle)
            handle = nil
            throw Failure.open(message)
        }
        sqlite3_busy_timeout(handle, 3000)
        // secure_delete: deleted rows are overwritten in the file, not left in free pages
        try executeScript("PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON; PRAGMA synchronous = NORMAL; PRAGMA secure_delete = ON;")
        try migrate(migrations)
    }

    deinit { sqlite3_close_v2(handle) }

    func close() {
        sqlite3_close_v2(handle)
        handle = nil
    }

    /// `PRAGMA user_version`: the number of the last migration applied.
    var userVersion: Int {
        (try? query("PRAGMA user_version") { $0.int("user_version") ?? 0 }.first) ?? 0
    }

    /// `wal` for file databases (`memory` in memory).
    var journalMode: String {
        (try? query("PRAGMA journal_mode") { $0.string("journal_mode") ?? "" }.first) ?? ""
    }

    var lastInsertRowID: Int64 { sqlite3_last_insert_rowid(handle) }
    var changes: Int { Int(sqlite3_changes(handle)) }

    /// Runs one statement with `?` parameters.
    func execute(_ sql: String, _ args: [SQLValue] = []) throws {
        let statement = try prepare(sql, args)
        defer { sqlite3_finalize(statement) }
        var rc = sqlite3_step(statement)
        while rc == SQLITE_ROW { rc = sqlite3_step(statement) }
        guard rc == SQLITE_DONE else { throw Failure.step(errorMessage, sql: sql) }
    }

    /// Runs several `;`-separated statements without parameters.
    func executeScript(_ sql: String) throws {
        guard let handle else { throw Failure.closed }
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? errorMessage
            sqlite3_free(error)
            throw Failure.step(message, sql: sql)
        }
    }

    func query<T>(_ sql: String, _ args: [SQLValue] = [], _ map: (SQLRow) throws -> T) throws -> [T] {
        let statement = try prepare(sql, args)
        defer { sqlite3_finalize(statement) }
        var out: [T] = []
        let count = sqlite3_column_count(statement)
        var names: [String] = []
        for i in 0..<count { names.append(String(cString: sqlite3_column_name(statement, i))) }
        while true {
            let rc = sqlite3_step(statement)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw Failure.step(errorMessage, sql: sql) }
            var columns: [String: SQLValue] = [:]
            for i in 0..<count { columns[names[Int(i)]] = Self.column(statement, i) }
            out.append(try map(SQLRow(columns: columns)))
        }
        return out
    }

    func query<T: RowDecodable>(_ type: T.Type, _ sql: String, _ args: [SQLValue] = []) throws -> [T] {
        try query(sql, args) { try T(row: $0) }
    }

    /// Runs `body` in a transaction; any error rolls it back and is rethrown.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try executeScript("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try executeScript("COMMIT")
            return result
        } catch {
            try? executeScript("ROLLBACK")
            throw error
        }
    }

    // MARK: - Internals

    private func migrate(_ migrations: [Migration]) throws {
        let versions = migrations.map(\.version)
        guard versions.isEmpty || versions == Array(1...versions.count) else {
            throw Failure.badMigrations("versions must be 1, 2, 3 … in order (got \(versions))")
        }
        let current = userVersion
        let known = versions.last ?? 0
        if current > known { throw Failure.newerSchema(found: current, known: known) }
        for migration in migrations where migration.version > current {
            do {
                try transaction {
                    // another process (a second copy of the app) may have migrated while this one
                    // waited for the write lock: read the version again under the lock
                    let now = try storedVersion()
                    if now > known { throw Failure.newerSchema(found: now, known: known) }
                    guard now < migration.version else { return }
                    try executeScript(migration.sql)
                    try executeScript("PRAGMA user_version = \(migration.version)")
                }
            } catch let failure as Failure {
                if case .newerSchema = failure { throw failure }
                throw Failure.migration(migration.version, "\(failure)")
            } catch {
                throw Failure.migration(migration.version, "\(error)")
            }
        }
    }

    private func storedVersion() throws -> Int {
        try query("PRAGMA user_version") { $0.int("user_version") ?? 0 }.first ?? 0
    }

    /// Rewrites the full-text index `table` in one piece and empties the write-ahead log, so text
    /// that was deleted is no longer in the file (FTS5 keeps old index segments until they are
    /// merged, the WAL keeps old pages until a checkpoint). Call after deleting for good.
    func compact(fullText table: String? = nil) throws {
        if let table { try execute("INSERT INTO \(table)(\(table)) VALUES('optimize')") }
        try executeScript("PRAGMA wal_checkpoint(TRUNCATE)")
    }

    private var errorMessage: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "closed"
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func prepare(_ sql: String, _ args: [SQLValue]) throws -> OpaquePointer? {
        guard let handle else { throw Failure.closed }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Failure.prepare(errorMessage, sql: sql)
        }
        for (offset, value) in args.enumerated() {
            let i = Int32(offset + 1)
            let rc: Int32 = switch value {
            case .null: sqlite3_bind_null(statement, i)
            case .int(let v): sqlite3_bind_int64(statement, i, v)
            case .double(let v): sqlite3_bind_double(statement, i, v)
            case .text(let v): sqlite3_bind_text(statement, i, v, -1, Self.transient)
            case .blob(let v): v.withUnsafeBytes { sqlite3_bind_blob(statement, i, $0.baseAddress, Int32($0.count), Self.transient) }
            }
            guard rc == SQLITE_OK else {
                sqlite3_finalize(statement)
                throw Failure.prepare("bind \(i): \(errorMessage)", sql: sql)
            }
        }
        return statement
    }

    private static func column(_ statement: OpaquePointer?, _ i: Int32) -> SQLValue {
        switch sqlite3_column_type(statement, i) {
        case SQLITE_INTEGER: return .int(sqlite3_column_int64(statement, i))
        case SQLITE_FLOAT: return .double(sqlite3_column_double(statement, i))
        case SQLITE_TEXT: return .text(String(cString: sqlite3_column_text(statement, i)))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(statement, i))
            guard count > 0, let bytes = sqlite3_column_blob(statement, i) else { return .blob(Data()) }
            return .blob(Data(bytes: bytes, count: count))
        default: return .null
        }
    }
}
