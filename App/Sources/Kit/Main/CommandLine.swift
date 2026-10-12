import AppKit

/// Command-line flags of the app binary.
///
///     <App> --render <dir> [--only <prefix>] [--lang en|de] [--appearance light|dark]
///     <App> --selftest
///
/// Environment: `STARTER_HEADLESS=1` (no windows, activation policy `.prohibited`),
/// `STARTER_LANG=en|de`, `STARTER_DATA_DIR=<dir>`, `STARTER_LOG=stderr`.
struct LaunchFlags: Equatable {
    var renderDir: URL?
    var only: String?
    var lang: Lang?
    var appearance: Appearance?
    var selftest = false
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
            default:
                break   // macOS adds its own arguments (-NSDocumentRevisionsDebugMode, -AppleLanguages …)
            }
            i += 1
        }
        if flags.renderDir == nil && (flags.only != nil || flags.lang != nil || flags.appearance != nil) {
            flags.errors.append("--only, --lang and --appearance need --render <dir>")
        }
        return flags
    }
}

enum Launch {
    /// Kept alive for the app's lifetime (NSApplication.delegate is weak).
    private static var delegate: AppDelegate?

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

        let delegate = AppDelegate()
        Launch.delegate = delegate
        app.delegate = delegate
        app.run()
        exit(0)
    }
}
