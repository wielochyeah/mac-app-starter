import Foundation

/// Where job records live between launches.
protocol JobStore: AnyObject {
    func load() throws -> [String: JobRecord]
    func save(_ id: String, _ record: JobRecord) throws
}

/// `background.sqlite` in Application Support (Kit `Database`). The file is created on the first
/// load, i.e. only once a job is registered.
final class DatabaseJobStore: JobStore {
    private let url: URL?
    private var database: Database?

    static let migrations: [Database.Migration] = [
        .init(1, """
        CREATE TABLE job_state(
            id TEXT PRIMARY KEY,
            last_start REAL,
            last_end REAL,
            outcome TEXT,
            detail TEXT,
            runs INTEGER NOT NULL DEFAULT 0,
            failures INTEGER NOT NULL DEFAULT 0
        )
        """),
    ]

    /// `url: nil` keeps everything in memory (tests).
    init(url: URL? = Paths.database("background")) {
        self.url = url
    }

    private func open() throws -> Database {
        if let database { return database }
        let db = try Database(url: url, migrations: Self.migrations)
        database = db
        return db
    }

    func load() throws -> [String: JobRecord] {
        let rows = try open().query("SELECT * FROM job_state") { row -> (String, JobRecord) in
            let id = try row.require("id", SQLRow.string)
            var record = JobRecord()
            record.lastStart = row.date("last_start")
            record.lastEnd = row.date("last_end")
            record.outcome = Self.outcome(kind: row.string("outcome"), detail: row.string("detail"))
            record.runs = row.int("runs") ?? 0
            record.failures = row.int("failures") ?? 0
            return (id, record)
        }
        return Dictionary(rows, uniquingKeysWith: { first, _ in first })
    }

    func save(_ id: String, _ record: JobRecord) throws {
        let (kind, detail) = Self.columns(record.outcome)
        try open().execute("""
            INSERT INTO job_state(id, last_start, last_end, outcome, detail, runs, failures) VALUES(?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET last_start = excluded.last_start, last_end = excluded.last_end,
                outcome = excluded.outcome, detail = excluded.detail, runs = excluded.runs, failures = excluded.failures
            """, [.text(id), record.lastStart.map(SQLValue.of) ?? .null, record.lastEnd.map(SQLValue.of) ?? .null,
                  .of(kind), .of(detail), .of(record.runs), .of(record.failures)])
    }

    /// Outcome as two columns: kind ("done" | "nothing" | "failed") and detail.
    static func columns(_ outcome: JobOutcome?) -> (String?, String?) {
        switch outcome {
        case nil: (nil, nil)
        case .done(let note): ("done", note)
        case .nothingToDo: ("nothing", nil)
        case .failed(let message): ("failed", message)
        }
    }

    /// Unknown kinds (written by a newer version) read as no outcome.
    static func outcome(kind: String?, detail: String?) -> JobOutcome? {
        switch kind {
        case "done": .done(note: detail)
        case "nothing": .nothingToDo
        case "failed": .failed(detail ?? "")
        default: nil
        }
    }
}

/// Records in memory (tests and renders).
final class MemoryJobStore: JobStore {
    private(set) var records: [String: JobRecord]
    private(set) var saves = 0

    init(_ records: [String: JobRecord] = [:]) { self.records = records }

    func load() throws -> [String: JobRecord] { records }

    func save(_ id: String, _ record: JobRecord) throws {
        records[id] = record
        saves += 1
    }
}
