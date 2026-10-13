// swift-tools-version: 6.2
//
// SECONDARY build path, for Xcode (File > Open… this folder) or a healthy SwiftPM (`swift build`).
// The default path is `make build` (scripts/build.sh: one swiftc call, no SwiftPM), because SwiftPM
// and Swift Testing crash on a mixed Command Line Tools install (see `make doctor`).
//
// Before building this way, generate the config once (and after every starter.json change):
//     python3 scripts/gen_config.py
// It writes build/gen/AppConfig.swift (compiled here) and build/gen/Info.plist (embedded here).
// Modules and the minimum macOS (app.minimumMacOS) come from starter.json, like in the default path; a missing or
// unreadable starter.json stops here instead of building some other module set. Tests run only through `make test`.

import Foundation
import PackageDescription

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let moduleDirs: [(key: String, dir: String)] = [
    ("window", "Window"), ("menubar", "MenuBar"), ("island", "Island"), ("background", "Background"),
    ("hotkeys", "Hotkeys"), ("ai", "AI"), ("mlx", "MLX"), ("examples", "Examples"),
]

func starterConfig() -> [String: Any] {
    let url = root.appendingPathComponent("starter.json")
    guard let data = try? Data(contentsOf: url) else { fatalError("Package.swift: \(url.path) is missing or unreadable") }
    guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
        fatalError("Package.swift: starter.json is not a JSON object (python3 scripts/gen_config.py names the problem)")
    }
    return json
}

let config = starterConfig()
guard let modules = config["modules"] as? [String: Bool] else { fatalError("Package.swift: starter.json has no modules") }
let unknown = Set(modules.keys).subtracting(moduleDirs.map(\.key))
if !unknown.isEmpty { fatalError("Package.swift: unknown modules in starter.json: \(unknown.sorted())") }
guard let minimumMacOS = (config["app"] as? [String: Any])?["minimumMacOS"] as? String else {
    fatalError("Package.swift: starter.json has no app.minimumMacOS")
}
let enabled = Set(modules.filter(\.value).map(\.key))
let active = moduleDirs.filter { enabled.contains($0.key) }

var swiftSettings: [SwiftSetting] = [.defaultIsolation(MainActor.self)]
swiftSettings += active.map { .define("MODUL_\($0.key.uppercased())") }

var linkerSettings: [LinkerSetting] = [
    .linkedLibrary("sqlite3"),
    .linkedFramework("AppKit"), .linkedFramework("SwiftUI"), .linkedFramework("ServiceManagement"), .linkedFramework("Carbon"),
    .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                  "-Xlinker", root.appendingPathComponent("build/gen/Info.plist").path]),
]
if enabled.contains("ai") { linkerSettings.append(.linkedFramework("FoundationModels")) }

let package = Package(
    name: "App",
    platforms: [.macOS(minimumMacOS)],
    targets: [
        .executableTarget(
            name: "App",
            path: ".",
            exclude: ["App/Sources/Features/README.md"],
            sources: ["App/Sources/Kit", "App/Sources/Features"]
                + active.map { "App/Sources/Modules/\($0.dir)" }
                + ["build/gen/AppConfig.swift"],
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
