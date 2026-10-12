import Foundation

/// A dotted version like 1.2.3 (missing parts are 0). Compares numerically.
nonisolated struct Version: Comparable, CustomStringConvertible, Sendable, Hashable {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int = 0, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard let n = Int(part), n >= 0 else { return nil }
            numbers.append(n)
        }
        while numbers.count < 3 { numbers.append(0) }
        self.init(numbers[0], numbers[1], numbers[2])
    }

    var description: String { "\(major).\(minor).\(patch)" }

    static func < (a: Version, b: Version) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }

    /// The app's version from starter.json.
    static var app: Version { Version(AppConfig.version) ?? Version(0) }
    /// The mac-app-starter version this project was made from.
    static var starter: Version { Version(AppConfig.starterVersion) ?? Version(0) }
}
