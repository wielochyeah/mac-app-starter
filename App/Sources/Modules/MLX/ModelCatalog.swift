import Foundation

/// A model the MLX worker can run (ai-worker/models.json).
nonisolated struct ModelSpec: Codable, Equatable, Identifiable, Sendable {
    let id: String
    /// "fast" | "quality" (titles in MLXText).
    let role: String
    /// Brand name, not translated ("Qwen3 1.7B").
    let name: String
    var bits: Int?
    let repo: String
    /// Pinned Hugging Face commit; the download and the presence check use exactly this snapshot.
    var revision: String?
    let bytes: Int64
    /// Approximate memory while loaded.
    var ramGB: Double?
    var license: String?
    /// File patterns to download (nil: the catalog's list).
    var allow: [String]?
}

nonisolated struct ModelCatalog: Codable, Equatable, Sendable {
    enum Problem: Error, Equatable { case noModels, duplicateID(String), unknownDefault(String), badEntry(String) }

    var version: Int
    var defaultID: String
    var allow: [String]?
    var models: [ModelSpec]

    enum CodingKeys: String, CodingKey {
        case version, allow, models
        case defaultID = "default"
    }

    func model(_ id: String) -> ModelSpec? { models.first { $0.id == id } }
    var defaultModel: ModelSpec? { model(defaultID) }
    func patterns(for model: ModelSpec) -> [String] { model.allow ?? allow ?? [] }

    func validate() throws {
        guard !models.isEmpty else { throw Problem.noModels }
        var seen = Set<String>()
        for m in models {
            guard seen.insert(m.id).inserted else { throw Problem.duplicateID(m.id) }
            guard m.bytes > 0, m.repo.contains("/"), !m.name.isEmpty else { throw Problem.badEntry(m.id) }
        }
        guard model(defaultID) != nil else { throw Problem.unknownDefault(defaultID) }
    }

    static func load(_ url: URL) throws -> ModelCatalog {
        let catalog = try JSONDecoder().decode(ModelCatalog.self, from: Data(contentsOf: url))
        try catalog.validate()
        return catalog
    }

    /// The catalog next to the worker, else the built-in copy (renders, a missing ai-worker folder).
    static var current: ModelCatalog {
        if let dir = MLXPaths.workerDir, let catalog = try? load(dir.appendingPathComponent("models.json")) { return catalog }
        return builtIn
    }

    /// Mirror of ai-worker/models.json (MLXTests fails when they drift apart).
    static let builtIn = ModelCatalog(
        version: 1, defaultID: "small", allow: ["*.json", "*.safetensors", "*.jinja", "*.txt", "*.model"],
        models: [
            ModelSpec(id: "small", role: "fast", name: "Qwen3 1.7B", bits: 4, repo: "mlx-community/Qwen3-1.7B-4bit",
                      revision: "3b1b1768f8f8cf8351c712464f906e86c2b8269e", bytes: 984_013_244, ramGB: 1.6, license: "apache-2.0"),
            ModelSpec(id: "quality", role: "quality", name: "Qwen3.5 4B", bits: 4, repo: "mlx-community/Qwen3.5-4B-MLX-4bit",
                      revision: "32f3e8ecf65426fc3306969496342d504bfa13f3", bytes: 3_061_129_077, ramGB: 3.7, license: "apache-2.0"),
        ])
}

/// The Hugging Face cache layout on disk (`<hub>/models--org--name/{blobs,snapshots/<rev>}`),
/// read without the hub client (port of VoiceBud's `hf_snapshot`; same rules as download.py).
nonisolated enum HubCache {
    static func repoDir(hub: URL, repo: String) -> URL {
        hub.appendingPathComponent("models--" + repo.replacingOccurrences(of: "/", with: "--"), isDirectory: true)
    }

    /// The snapshot folder of a complete download: config.json plus a weights file whose blob exists
    /// (a link to a half-written blob does not count). nil revision: the newest snapshot.
    static func snapshot(hub: URL, repo: String, revision: String?) -> URL? {
        let fm = FileManager.default
        let snaps = repoDir(hub: hub, repo: repo).appendingPathComponent("snapshots", isDirectory: true)
        var names: [String]
        if let revision {
            names = [revision]
        } else {
            let all = (try? fm.contentsOfDirectory(at: snaps, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            names = all.sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a > b
            }.map(\.lastPathComponent)
        }
        for name in names {
            let snap = snaps.appendingPathComponent(name, isDirectory: true)
            guard fm.fileExists(atPath: snap.appendingPathComponent("config.json").path) else { continue }
            let files = (try? fm.contentsOfDirectory(atPath: snap.path)) ?? []
            // fileExists follows the symlink into blobs/
            if files.contains(where: { $0.hasSuffix(".safetensors") && fm.fileExists(atPath: snap.appendingPathComponent($0).path) }) {
                return snap
            }
        }
        return nil
    }

    /// Bytes in the repo's blob folder, finished and partial files alike.
    static func blobBytes(hub: URL, repo: String) -> Int64 {
        let folder = repoDir(hub: hub, repo: repo).appendingPathComponent("blobs", isDirectory: true)
        let keys: [URLResourceKey] = [.fileSizeKey, .isSymbolicLinkKey, .isRegularFileKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
        return files.reduce(0) { sum, url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isSymbolicLink != true, v.isRegularFile == true else { return sum }
            return sum + Int64(v.fileSize ?? 0)
        }
    }

    /// Deletes a model from the cache (the whole repo folder).
    static func remove(hub: URL, repo: String) throws {
        let dir = repoDir(hub: hub, repo: repo)
        if FileManager.default.fileExists(atPath: dir.path) { try FileManager.default.removeItem(at: dir) }
    }
}
