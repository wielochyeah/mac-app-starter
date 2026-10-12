import AppKit

/// Facts about the running app, from the generated `AppConfig` and the bundle.
enum AppInfo {
    static var name: String { AppConfig.name }
    /// The localized name shown to people.
    static var displayName: String { tr(en: AppConfig.displayName.en, de: AppConfig.displayName.de) }
    static var bundleId: String { AppConfig.bundleId }
    static var version: String { AppConfig.version }
    static var build: Int { AppConfig.build }
    static var symbol: String { AppConfig.symbol }
    static var copyright: String { AppConfig.copyright }

    /// True when running from a real `.app` (login items, permissions and notifications need one).
    static var isAppBundle: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    /// Whether a module was compiled in and enabled (see `Modules.compiled`).
    static func isEnabled(_ module: String) -> Bool { AppConfig.enabledModules.contains(module) }

    /// The app icon from the bundle (`AppIcon.icns`), one 512 px representation only (a full icns
    /// keeps ~8 MB decoded). Nil for bare binaries without the icon.
    static func icon() -> NSImage? {
        let candidates = [
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("../Resources/AppIcon.icns"),
        ]
        for case let url? in candidates {
            guard let full = NSImage(contentsOf: url) else { continue }
            let best = full.representations.min { abs($0.pixelsWide - 512) < abs($1.pixelsWide - 512) }
            guard let best else { return full }
            let image = NSImage(size: NSSize(width: 256, height: 256))
            image.addRepresentation(best)
            return image
        }
        return nil
    }
}
