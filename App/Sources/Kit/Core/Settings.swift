import Foundation
import Observation

/// A typed settings key. Declare keys next to the code that owns them:
///
///     extension SettingKey {
///         static var islandStyle: SettingKey<String> { .init("island.style", default: "auto") }
///     }
///     Settings.shared[.islandStyle] = "capsule"
///
/// Names are dotted, module first (`island.style`). Custom value types must be declared
/// `nonisolated struct …: Codable, Sendable` (the app builds with default MainActor isolation, and a
/// main-actor-isolated Codable conformance cannot satisfy this Sendable type parameter).
struct SettingKey<Value: Codable & Sendable>: Sendable {
    let name: String
    let defaultValue: Value

    init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

/// Any JSON value. Lets the store keep keys it does not know (written by a newer version or by hand).
nonisolated enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int64.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "not a JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    /// Converts any Encodable value (round trip through JSON).
    init<T: Encodable>(encoding value: T) throws {
        self = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    /// Decodes this value as `T`, nil when it does not fit.
    func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

/// The app's settings: one JSON object in `~/Library/Application Support/<bundleId>/settings.json`.
///
/// - Reads are typed through `SettingKey`; a missing or broken value gives the key's default.
/// - Every write saves at once, atomically (temp file + rename).
/// - Keys this version does not know are kept; a save merges only the keys changed here into what
///   is on disk, so another writer's keys survive.
/// - A file that is not valid JSON is moved aside to `settings.json.broken` on the next save.
/// - `@Observable`: SwiftUI views that read a key redraw when any key changes.
@Observable final class Settings {
    static let shared = Settings(fileURL: Paths.settingsFile)

    let fileURL: URL
    private(set) var values: [String: JSONValue] = [:]
    /// The last save error, for diagnostics (nil after a good save).
    private(set) var lastError: String?

    @ObservationIgnored private var dirty: Set<String> = []
    @ObservationIgnored private var fileWasBroken = false

    init(fileURL: URL) {
        self.fileURL = fileURL
        reload()
    }

    subscript<V>(key: SettingKey<V>) -> V {
        get { values[key.name]?.decode(V.self) ?? key.defaultValue }
        set {
            guard let value = try? JSONValue(encoding: newValue) else {
                Log.error("settings: cannot encode \(key.name)", "settings")
                return
            }
            guard values[key.name] != value else { return }
            values[key.name] = value
            dirty.insert(key.name)
            save()
        }
    }

    /// Back to the default (the key is removed from the file).
    func reset<V>(_ key: SettingKey<V>) {
        guard values[key.name] != nil else { return }
        values.removeValue(forKey: key.name)
        dirty.insert(key.name)
        save()
    }

    /// True when the file holds a value for this key (valid or not).
    func hasValue<V>(_ key: SettingKey<V>) -> Bool { values[key.name] != nil }

    /// Re-reads the file (changes made elsewhere). Unsaved changes are dropped.
    func reload() {
        dirty.removeAll()
        switch Self.read(fileURL) {
        case .missing:
            values = [:]
            fileWasBroken = false
        case .broken:
            values = [:]
            fileWasBroken = true
            Log.warn("settings: \(fileURL.lastPathComponent) is not valid JSON, using defaults", "settings")
        case .ok(let object):
            values = object
            fileWasBroken = false
        }
    }

    private enum ReadResult { case missing, broken, ok([String: JSONValue]) }

    private static func read(_ url: URL) -> ReadResult {
        guard let data = try? Data(contentsOf: url) else { return .missing }
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: data), case .object(let object) = value else {
            return .broken
        }
        return .ok(object)
    }

    private func save() {
        do {
            let fm = FileManager.default
            try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            var merged: [String: JSONValue] = [:]
            switch Self.read(fileURL) {
            case .ok(let onDisk): merged = onDisk
            case .missing: break
            case .broken:
                // keep the unreadable file for the person who edited it by hand
                let aside = fileURL.appendingPathExtension("broken")
                try? fm.removeItem(at: aside)
                try fm.moveItem(at: fileURL, to: aside)
            }
            fileWasBroken = false
            for name in dirty {
                if let value = values[name] { merged[name] = value } else { merged.removeValue(forKey: name) }
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(JSONValue.object(merged)).write(to: fileURL, options: .atomic)
            // what is on disk now is the truth (keys written by others included)
            values = merged
            dirty.removeAll()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            Log.error("settings: save failed: \(error.localizedDescription)", "settings")
        }
    }
}

extension SettingKey {
    /// Set when the person finished (or skipped) onboarding.
    static var onboardingDone: SettingKey<Bool> { .init("onboarding.done", default: false) }
}
