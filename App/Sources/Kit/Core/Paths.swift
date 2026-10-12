import Foundation

/// Where the app keeps its files. `STARTER_DATA_DIR` moves everything (tests, renders, demos).
nonisolated enum Paths {
    /// ~/Library/Application Support/<bundleId> (created on first use)
    static var appSupport: URL {
        if let custom = ProcessInfo.processInfo.environment["STARTER_DATA_DIR"], !custom.isEmpty {
            return ensure(URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true))
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ensure(base.appendingPathComponent(AppConfig.bundleId, isDirectory: true))
    }

    /// The settings store (see `Settings`).
    static var settingsFile: URL { appSupport.appendingPathComponent("settings.json") }

    /// A SQLite database file in Application Support, e.g. `Paths.database("history")`.
    static func database(_ name: String = "app") -> URL {
        appSupport.appendingPathComponent("\(name).sqlite")
    }

    /// ~/Library/Caches/<bundleId> (or <STARTER_DATA_DIR>/Caches): files that can be rebuilt.
    static var caches: URL {
        if let custom = ProcessInfo.processInfo.environment["STARTER_DATA_DIR"], !custom.isEmpty {
            return ensure(appSupport.appendingPathComponent("Caches", isDirectory: true))
        }
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return ensure(base.appendingPathComponent(AppConfig.bundleId, isDirectory: true))
    }

    /// Downloaded models and other large, re-downloadable data.
    static var models: URL { ensure(appSupport.appendingPathComponent("Models", isDirectory: true)) }

    @discardableResult
    static func ensure(_ dir: URL) -> URL {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
