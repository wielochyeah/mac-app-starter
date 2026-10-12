import AppKit

/// Command-line flags of the app binary.
///
///     <App> --render <dir> [--only <prefix>] [--lang en|de] [--appearance light|dark]
///     <App> --selftest
///     <App> --demo        normal launch, no onboarding, runs every `Registry.demoDrivers` entry
///                         (scripted loops such as the island's); fails when no module adds one
///     <App> --background  normal launch without opening windows (login item start); also set when
///                         macOS launched the app as a login item
///
/// Unknown `--` flags are errors (exit 2), so a mistyped tool flag never starts the GUI app.
/// Single-dash arguments are macOS's own (`-NSDocumentRevisionsDebugMode YES`, `-psn_…`) and pass.
///
/// Environment: `STARTER_HEADLESS=1` (no windows, activation policy `.prohibited`),
/// `STARTER_LANG=en|de`, `STARTER_DATA_DIR=<dir>`, `STARTER_LOG=stderr`.
struct LaunchFlags: Equatable {
    var renderDir: URL?
    var only: String?
    var lang: Lang?
    var appearance: Appearance?
    var selftest = false
    var demo = false
    var background = false
    var errors: [String] = []

    var isTool: Bool { renderDir != nil || selftest }

    static func parse(_ arguments: [String]) -> LaunchFlags {
        var flags = LaunchFlags()
        var i = 1
        func value(_ name: String) -> String? {
            guard i + 1 < arguments.count, !arguments[i + 1].hasPrefix("--") else {
                flags.errors.append("\(name) needs a value")
                return nil
            }
            i += 1
            return arguments[i]
        }
        while i < arguments.count {
            let arg = arguments[i]
            switch arg {
            case "--render":
                if let v = value(arg) { flags.renderDir = URL(fileURLWithPath: (v as NSString).expandingTildeInPath, isDirectory: true) }
            case "--only":
                flags.only = value(arg)
            case "--lang":
                if let v = value(arg) {
                    if let lang = Lang(rawValue: v) { flags.lang = lang } else { flags.errors.append("--lang must be en or de") }
                }
            case "--appearance":
                if let v = value(arg) {
                    if let a = Appearance(rawValue: v) { flags.appearance = a } else { flags.errors.append("--appearance must be light or dark") }
                }
            case "--selftest":
                flags.selftest = true
            case "--demo":
                flags.demo = true
            case "--background":
                flags.background = true
            default:
                // macOS adds its own single-dash arguments (-NSDocumentRevisionsDebugMode, -AppleLanguages …)
                if arg.hasPrefix("--") { flags.errors.append("unknown flag \(arg)") }
            }
            i += 1
        }
        if flags.renderDir == nil && (flags.only != nil || flags.lang != nil || flags.appearance != nil) {
            flags.errors.append("--only, --lang and --appearance need --render <dir>")
        }
        if flags.demo && flags.isTool {
            flags.errors.append("--demo cannot be combined with --render or --selftest")
        }
        return flags
    }
}

enum Launch {
    /// Kept alive for the app's lifetime (NSApplication.delegate is weak).
    private static var delegate: AppDelegate?
    /// True for `--demo`: AppDelegate skips onboarding and runs `Registry.demoDrivers`.
    private(set) static var isDemo = false
    /// True for `--background` (or a login-item launch, see AppDelegate): no window opens at launch.
    static var isBackground = false

    static func run(_ flags: LaunchFlags) -> Never {
        if !flags.errors.isEmpty {
            for e in flags.errors { FileHandle.standardError.write(Data("\(AppConfig.name): \(e)\n".utf8)) }
            exit(2)
        }
        let app = NSApplication.shared
        if flags.isTool || RenderMode.isHeadless {
            // no Dock icon, no menu bar, never activates; windows are never ordered front
            app.setActivationPolicy(.prohibited)
            HeadlessWindows.install()
        }
        Modules.registerAll()

        if let dir = flags.renderDir {
            var options = RenderRunner.Options(dir: dir, only: flags.only)
            if let lang = flags.lang { options.langs = [lang] }
            if let appearance = flags.appearance { options.appearances = [appearance] }
            exit(RenderRunner.run(options))
        }
        if flags.selftest {
            exit(SelfTestRunner.run())
        }

        if flags.demo {
            guard !Registry.demoDrivers.isEmpty else {
                FileHandle.standardError.write(Data("\(AppConfig.name): --demo: no enabled module provides a demo (Registry.demoDrivers is empty)\n".utf8))
                exit(2)
            }
            isDemo = true
        }
        isBackground = flags.background
        let delegate = AppDelegate()
        Launch.delegate = delegate
        app.delegate = delegate
        app.run()
        exit(0)
    }
}
