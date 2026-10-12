import AppKit
import SwiftUI

/// `--selftest`: quick in-process checks of the kit and every module's `Registry.selfTests`.
/// Prints one line per failure and a summary; exit code 0 when all pass. Shows no window.
enum SelfTestRunner {
    static func run() -> Int32 {
        var failures: [String] = []
        let checks = Registry.selfTests.sorted { $0.id < $1.id }
        for check in checks {
            if let problem = check.run() { failures.append("\(check.id): \(problem)") }
        }
        if NSApp.windows.contains(where: \.isVisible) { failures.append("kit.headless: a window became visible") }
        for f in failures { FileHandle.standardError.write(Data("selftest FAIL \(f)\n".utf8)) }
        print("selftest: \(checks.count) checks, \(failures.count) failures")
        return failures.isEmpty ? 0 : 1
    }

    /// The kit's own checks (registered by `KitModule`).
    static func registerKitChecks() {
        Registry.selfTests += [
            SelfTestCheck(id: "kit.modules") {
                Modules.compiled == AppConfig.enabledModules ? nil
                    : "compiled \(Modules.compiled.sorted()) but AppConfig says \(AppConfig.enabledModules.sorted())"
            },
            SelfTestCheck(id: "kit.registry") {
                let problems = Registry.problems()
                return problems.isEmpty ? nil : problems.joined(separator: "; ")
            },
            SelfTestCheck(id: "kit.policy") {
                let wanted: NSApplication.ActivationPolicy = .prohibited
                return NSApp.activationPolicy() == wanted ? nil : "activation policy is not .prohibited in self-test"
            },
            SelfTestCheck(id: "kit.language") {
                let saved = Localizer.shared.forced
                defer { Localizer.shared.forced = saved }
                Localizer.shared.forced = .de
                let de = CommonText.continue
                Localizer.shared.forced = .en
                let en = CommonText.continue
                return de == "Weiter" && en == "Continue" ? nil : "tr() did not switch (\(en), \(de))"
            },
            SelfTestCheck(id: "kit.settings") {
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("selftest-\(UUID().uuidString)")
                defer { try? FileManager.default.removeItem(at: dir) }
                let settings = Settings(fileURL: dir.appendingPathComponent("settings.json"))
                settings[.onboardingDone] = true
                return Settings(fileURL: settings.fileURL)[.onboardingDone] ? nil : "value did not persist"
            },
            SelfTestCheck(id: "kit.database") {
                do {
                    let db = try Database(url: nil, migrations: [.init(1, "CREATE TABLE t(x INTEGER)")])
                    try db.execute("INSERT INTO t(x) VALUES(?)", [42])
                    let x = try db.query("SELECT x FROM t") { $0.int("x") }.first ?? nil
                    return x == 42 && db.userVersion == 1 ? nil : "unexpected result"
                } catch {
                    return "\(error)"
                }
            },
            SelfTestCheck(id: "kit.symbol") {
                NSImage(systemSymbolName: AppConfig.symbol, accessibilityDescription: nil) != nil ? nil
                    : "app.symbol \"\(AppConfig.symbol)\" in starter.json is not an SF Symbol (icons would be blank)"
            },
            SelfTestCheck(id: "kit.render") {
                guard let scene = Registry.renderScenes.first(where: { $0.id == "design.buttons" }) else { return "design.buttons missing" }
                let png = RenderRunner.png(scene.content(), size: scene.size, appearance: .dark, lang: .de)
                return (png?.count ?? 0) > 1000 ? nil : "render produced no image"
            },
        ]
    }
}
