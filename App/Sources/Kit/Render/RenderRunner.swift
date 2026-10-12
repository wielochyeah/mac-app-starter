import AppKit
import SwiftUI

nonisolated enum Appearance: String, CaseIterable, Sendable {
    case light, dark
    var scheme: ColorScheme { self == .dark ? .dark : .light }
}

/// `--render <dir> [--only <prefix>] [--lang en|de] [--appearance light|dark]`
///
/// Renders every `Registry.renderScenes` entry (or those whose id starts with `--only`) to
/// `<dir>/<lang>-<appearance>/<id>.png` at 2x through `NSHostingView.cacheDisplay` (draws real
/// SwiftUI controls, no window, nothing on screen). Language goes through `Localizer.forced`,
/// appearance through `NSAppearance` plus the `colorScheme` environment. When rendering all
/// scenes in all languages and appearances, `<dir>/index.html` is a contact sheet.
enum RenderRunner {
    struct Options {
        var dir: URL
        var only: String?
        var langs: [Lang] = Lang.allCases
        var appearances: [Appearance] = Appearance.allCases
        var scale: CGFloat = 2
    }

    static func run(_ options: Options) -> Int32 {
        RenderMode.isStatic = true
        let scenes = Registry.orderedRenderScenes.filter { scene in
            guard let only = options.only, !only.isEmpty else { return true }
            return scene.id.hasPrefix(only)
        }
        guard !scenes.isEmpty else {
            FileHandle.standardError.write(Data("render: no scene matches \(options.only ?? "")\n".utf8))
            return 1
        }
        let previous = Localizer.shared.forced
        defer { Localizer.shared.forced = previous }
        var failures = 0
        var written = 0
        for lang in options.langs {
            Localizer.shared.forced = lang
            for appearance in options.appearances {
                let folder = options.dir.appendingPathComponent("\(lang.rawValue)-\(appearance.rawValue)", isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                for scene in scenes {
                    let url = folder.appendingPathComponent("\(scene.id).png")
                    guard let png = png(scene.content(), size: scene.size, appearance: appearance, lang: lang, scale: options.scale) else {
                        FileHandle.standardError.write(Data("render: FAILED \(lang.rawValue)-\(appearance.rawValue)/\(scene.id)\n".utf8))
                        failures += 1
                        continue
                    }
                    do {
                        try png.write(to: url, options: .atomic)
                        written += 1
                    } catch {
                        FileHandle.standardError.write(Data("render: cannot write \(url.path): \(error)\n".utf8))
                        failures += 1
                    }
                }
            }
        }
        let complete = options.only == nil && options.langs.count == Lang.allCases.count
            && options.appearances.count == Appearance.allCases.count
        if complete { writeIndex(scenes: scenes, dir: options.dir) }
        print("render: \(written) PNG(s) in \(options.dir.path)\(complete ? " + index.html" : "")\(failures > 0 ? ", \(failures) failed" : "")")
        return failures == 0 ? 0 : 1
    }

    /// One PNG of `view` at `scale` (default 2x, independent of the screen).
    static func png(_ view: AnyView, size: CGSize, appearance: Appearance, lang: Lang, scale: CGFloat = 2) -> Data? {
        let root = view
            .environment(\.colorScheme, appearance.scheme)
            .environment(\.renderStatic, true)
            .environment(\.locale, lang.locale)
            // without a window the backing scale is 1: SwiftUI would snap layout to whole points
            // and drop 0.5 pt hairlines that fall on a half point
            .environment(\.displayScale, scale)
        let host = NSHostingView(rootView: AnyView(root))
        host.appearance = NSAppearance(named: appearance == .dark ? .darkAqua : .aqua)
        var target = size
        if target == .zero {
            host.frame = NSRect(x: 0, y: 0, width: 10, height: 10)
            target = host.fittingSize
        }
        guard target.width >= 1, target.height >= 1 else { return nil }
        host.frame = NSRect(origin: .zero, size: target)
        host.layoutSubtreeIfNeeded()
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int((target.width * scale).rounded()),
                                         pixelsHigh: Int((target.height * scale).rounded()),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = target
        host.cacheDisplay(in: host.bounds, to: rep)
        // Capture colour-managed, then convert: the PNG holds exact sRGB token values (#1E1E20
        // stays #1E1E20). Retagging the bitmap as sRGB before drawing shifts dark colours.
        let srgb = rep.converting(to: .sRGB, renderingIntent: .default) ?? rep
        return srgb.representation(using: .png, properties: [:])
    }

    private static func writeIndex(scenes: [RenderScene], dir: URL) {
        var html = """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(AppConfig.name) renders</title>
        <style>
        :root { color-scheme: light dark; --bg: #f3f2ef; --fg: #1d1d1f; --muted: #6e6e73; --cell: #ffffff; }
        @media (prefers-color-scheme: dark) { :root { --bg: #111113; --fg: #f5f5f7; --muted: #98989d; --cell: #1e1e20; } }
        body { margin: 0; padding: 24px 16px; background: var(--bg); color: var(--fg); font: 13px -apple-system, system-ui, sans-serif; }
        h1 { font-size: 22px; margin: 0 0 4px; } p { color: var(--muted); margin: 0 0 24px; }
        section { margin: 0 0 32px; } h2 { font-size: 15px; margin: 0 0 10px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
        figure { margin: 0; background: var(--cell); border-radius: 10px; padding: 8px; }
        figure img { width: 100%; height: auto; display: block; border-radius: 6px; }
        figcaption { color: var(--muted); font-size: 11.5px; padding-top: 6px; }
        </style></head><body>
        <h1>\(AppConfig.name): \(scenes.count) scenes</h1>
        <p>en and de, light and dark. Rendered by <code>make shots</code>.</p>

        """
        for scene in scenes {
            html += "<section><h2>\(scene.id)</h2><div class=\"grid\">\n"
            for lang in Lang.allCases {
                for appearance in Appearance.allCases {
                    let path = "\(lang.rawValue)-\(appearance.rawValue)/\(scene.id).png"
                    html += "<figure><a href=\"\(path)\"><img src=\"\(path)\" alt=\"\(scene.id) \(lang.rawValue) \(appearance.rawValue)\" loading=\"lazy\"></a><figcaption>\(lang.rawValue), \(appearance.rawValue)</figcaption></figure>\n"
                }
            }
            html += "</div></section>\n"
        }
        html += "</body></html>\n"
        try? html.write(to: dir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    }
}
