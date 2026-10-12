import Foundation

/// Where the MLX worker, its Python and the models are.
///
/// Worker folder (first that has worker.py): `<App>.app/Contents/Resources/ai-worker` (a packaged
/// build); debug builds also try `$STARTER_AI_WORKER`, `$STARTER_ROOT/ai-worker` and `ai-worker/`
/// next to the app's folders upwards (a dev build in `build/<Name>.app` finds the repo's folder).
/// Python: `<worker>/.venv/bin/python` (ai-worker/setup.sh) or a bundled
/// `Contents/Resources/python/bin/python3` (packaging); debug builds also honour `$STARTER_AI_PYTHON`.
/// A release build runs only Python from inside its own bundle, never one found in the folders
/// around it or named by the environment.
/// Models: `<Application Support>/<bundleId>/Models/huggingface` (app-private, removed with the
/// app's data; `STARTER_DATA_DIR` moves it for tests).
nonisolated enum MLXPaths {
    static var env: [String: String] { ProcessInfo.processInfo.environment }

    static var workerDir: URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        #if DEBUG
        if let custom = env["STARTER_AI_WORKER"], !custom.isEmpty { candidates.append(URL(fileURLWithPath: custom, isDirectory: true)) }
        #endif
        if let resources = Bundle.main.resourceURL { candidates.append(resources.appendingPathComponent("ai-worker", isDirectory: true)) }
        #if DEBUG
        if let root = env["STARTER_ROOT"], !root.isEmpty {
            candidates.append(URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("ai-worker", isDirectory: true))
        }
        var dir = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<4 {
            candidates.append(dir.appendingPathComponent("ai-worker", isDirectory: true))
            dir = dir.deletingLastPathComponent()
        }
        #endif
        return candidates.first { fm.fileExists(atPath: $0.appendingPathComponent("worker.py").path) }
    }

    static func python(workerDir: URL?) -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        #if DEBUG
        if let custom = env["STARTER_AI_PYTHON"], !custom.isEmpty { candidates.append(URL(fileURLWithPath: custom)) }
        #endif
        if let workerDir { candidates.append(workerDir.appendingPathComponent(".venv/bin/python")) }
        if let resources = Bundle.main.resourceURL { candidates.append(resources.appendingPathComponent("python/bin/python3")) }
        return candidates.first { fm.isExecutableFile(atPath: $0.path) }
    }

    static var hfHome: URL {
        Paths.appSupport.appendingPathComponent("Models", isDirectory: true).appendingPathComponent("huggingface", isDirectory: true)
    }

    static var hub: URL { hfHome.appendingPathComponent("hub", isDirectory: true) }

    /// The worker's and downloader's stderr (library output, tracebacks). Never the protocol.
    static var logFile: URL { Paths.caches.appendingPathComponent("mlx-worker.log") }

    /// Environment for both Python processes: our model folder, no user site packages, no
    /// .pyc files next to the scripts.
    static func environment(hfHome: URL = hfHome) -> [String: String] {
        var e = env
        e["HF_HOME"] = hfHome.path
        e.removeValue(forKey: "HF_HUB_CACHE")
        e["PYTHONUNBUFFERED"] = "1"
        e["PYTHONNOUSERSITE"] = "1"
        e["PYTHONDONTWRITEBYTECODE"] = "1"
        return e
    }

    /// Opens `url` for appending (created with its folder; truncated past 2 MB); nil when it cannot be written.
    static func appendHandle(_ url: URL) -> FileHandle? {
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let size = (try? fm.attributesOfItem(atPath: url.path)[.size]) as? Int, size > 2_000_000 { try? fm.removeItem(at: url) }
        if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: url) else { return nil }
        _ = try? handle.seekToEnd()
        return handle
    }
}
