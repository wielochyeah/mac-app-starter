#if TESTING
import Foundation

/// Generated config (scripts/gen_config.py) matches the compile flags and starter.json.
final class ConfigTests: TestSuite {
    override class func register() {
        test("AppConfig modules match the compile flags") {
            expectEqual(AppConfig.enabledModules, Modules.compiled)
            expect(AppConfig.enabledModules.contains("window") || AppConfig.enabledModules.contains("menubar"))
        }

        test("Info.plist matches the module list") {
            let url = repoRoot.appendingPathComponent("build/gen/Info.plist")
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] ?? [:]
            expectEqual(plist["LSUIElement"] as? Bool, !AppConfig.enabledModules.contains("window"))
            expectEqual(plist["CFBundleIdentifier"] as? String, AppConfig.bundleId)
            expectEqual(plist["LSMinimumSystemVersion"] as? String, AppConfig.minimumMacOS)
            expectEqual(plist["CFBundleShortVersionString"] as? String, AppConfig.version)
            expectEqual(plist["CFBundleExecutable"] as? String, AppConfig.name)
        }

        test("InfoPlist.strings exist for every language") {
            for lang in Lang.allCases {
                let url = repoRoot.appendingPathComponent("build/gen/Resources/\(lang.rawValue).lproj/InfoPlist.strings")
                let text = try String(contentsOf: url, encoding: .utf8)
                expect(text.contains("\"CFBundleDisplayName\""), lang.rawValue)
                let parsed = try PropertyListSerialization.propertyList(from: Data(text.utf8), format: nil) as? [String: String]
                expectEqual(parsed?["CFBundleName"], AppConfig.name)
            }
        }

        test("AppConfig values come from starter.json") {
            let data = try Data(contentsOf: repoRoot.appendingPathComponent("starter.json"))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let app = json["app"] as? [String: Any] ?? [:]
            expectEqual(app["name"] as? String, AppConfig.name)
            expectEqual(app["bundleId"] as? String, AppConfig.bundleId)
            expectEqual(app["accent"] as? String, AppConfig.accent.rawValue)
            expectEqual(app["build"] as? Int, AppConfig.build)
        }
    }
}
#endif
