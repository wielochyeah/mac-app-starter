// Renders the DMG window background (1x and 2x PNG) and a preview with the icons where Finder will
// put them. Built and run by scripts/dmg.sh together with Kit/Design/Theme.swift and Tokens.swift,
// so colours and type are the app's own. Layout (window, icon size and positions) comes from
// tools/dmg/layout.json, the same file dmgbuild reads.
//
// Port of VoiceBud's packaging/dmg/Background.swift (MIT, Copyright (c) 2026 Anas Riad): the
// dotted gradient arrow, the drag line plus the one Gatekeeper step people get stuck on as a
// pill with lock.open.fill, the soft light behind the icon row, the preview output.
//
//   dmg-background --out <dir> --layout <layout.json> --icon <AppIcon.icns> --name <Name> [--name-de <Name>]
//                  --app-label <Finder label> --version <1.0.0> --min-macos <26.0>
//                  [--accent violett] [--lang en|de|both] [--no-hint]
// Writes <dir>/background.png, background@2x.png, preview.png.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DMGLayout: Decodable {
    struct Window: Decodable {
        let width: CGFloat
        let height: CGFloat
    }
    let window: Window
    let iconSize: CGFloat
    let textSize: CGFloat
    let app: [CGFloat]
    let applications: [CGFloat]
    let applicationsName: String

    var size: CGSize { CGSize(width: window.width, height: window.height) }
    var appCentre: CGPoint { CGPoint(x: app[0], y: app[1]) }
    var applicationsCentre: CGPoint { CGPoint(x: applications[0], y: applications[1]) }
}

struct Options {
    var out = ""
    var layout = ""
    var icon = ""
    var name = "App"
    /// German display name (app.displayName.de) when it differs.
    var nameDE = ""
    var appLabel = "App"
    var version = "1.0.0"
    var minimumMacOS = "26.0"
    var accent = AccentName.violett
    var lang = DMGLang.both
    var hint = true
}

/// Fixed geometry of the artwork (points in the 640 x 400 background). Kept here, not in Kit
/// tokens: it belongs to the DMG window, not to any app surface.
enum Art {
    static let headerY: CGFloat = 50
    static let arrowSize = CGSize(width: 130, height: 24)
    static let arrowLine: CGFloat = 2.5
    static let arrowDash: [CGFloat] = [0.1, 8]
    static let arrowHead = CGSize(width: 10, height: 9)
    static let glowRadius: CGFloat = 300
    static let glowOpacity = 0.16
    static let groundTint = 0.07
    static let pillFill = 0.78
    static let pillStroke = 0.32
    static let lockSize: CGFloat = 10.5
    static let labelGap: CGFloat = 4
}

// MARK: - Pieces

struct DottedArrow: View {
    let colors: [Color]
    let head: Color

    var body: some View {
        Canvas { ctx, size in
            let y = size.height / 2
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width - 4, y: y))
            var tip = Path()
            tip.move(to: CGPoint(x: size.width - 3 - Art.arrowHead.width, y: y - Art.arrowHead.height))
            tip.addLine(to: CGPoint(x: size.width - 3, y: y))
            tip.addLine(to: CGPoint(x: size.width - 3 - Art.arrowHead.width, y: y + Art.arrowHead.height))
            // a near-zero dash with round caps draws dots
            let dots = StrokeStyle(lineWidth: Art.arrowLine, lineCap: .round, lineJoin: .round, dash: Art.arrowDash)
            ctx.stroke(line, with: .linearGradient(Gradient(colors: colors), startPoint: .zero,
                                                    endPoint: CGPoint(x: size.width, y: 0)), style: dots)
            ctx.stroke(tip, with: .color(head), style: StrokeStyle(lineWidth: Art.arrowLine, lineCap: .round, lineJoin: .round))
        }
        .frame(width: Art.arrowSize.width, height: Art.arrowSize.height)
    }
}

/// The drag line and, for builds that are not notarized, the first-open step. One block per
/// language; the second language is quieter.
struct Hints: View {
    let o: Options
    let folder: String
    let t: Theme

    var body: some View {
        let langs = o.lang.languages
        VStack(spacing: Space.xs) {
            VStack(spacing: Space.hair) {
                ForEach(Array(langs.enumerated()), id: \.offset) { i, lang in
                    Text(DMGText.drag(lang == "de" && !o.nameDE.isEmpty ? o.nameDE : o.name, to: folder).text(lang))
                        .font(i == 0 ? TypeScale.bodySemibold : TypeScale.secondary)
                        .foregroundStyle(i == 0 ? t.fg : t.prose)
                }
            }
            if o.hint {
                HStack(alignment: .center, spacing: Space.xs) {
                    Image(systemName: "lock.open.fill")
                        .symbolFont(Art.lockSize, weight: .semibold)
                        .foregroundStyle(t.accentText)
                    VStack(alignment: .leading, spacing: Space.hair) {
                        ForEach(langs, id: \.self) { lang in
                            Text("\(DMGText.firstOpen.text(lang))\(Text(DMGText.openAnyway.text(lang)).bold())")
                                .font(TypeScale.subtitle)
                                .foregroundStyle(t.prose)
                        }
                    }
                }
                .padding(.horizontal, Space.s)
                .padding(.vertical, langs.count > 1 ? Space.xs : Space.xxs + Space.hair)
                .background(RoundedRectangle(cornerRadius: Radius.ring, style: .continuous).fill(Color.white.opacity(Art.pillFill)))
                .overlay(RoundedRectangle(cornerRadius: Radius.ring, style: .continuous)
                    .strokeBorder(t.ring.opacity(Art.pillStroke), lineWidth: 1))
            }
        }
        .fixedSize()
    }
}

struct Background: View {
    let o: Options
    let layout: DMGLayout

    var body: some View {
        let t = Theme(.light, accent: o.accent)
        let p = AccentPalette.of(o.accent)
        let size = layout.size
        let iconY = layout.appCentre.y
        ZStack {
            LinearGradient(colors: [Color(hex: 0xFCFCFD), Color(hex: Contrast.over(p.brand, Art.groundTint, 0xEFEFF3))],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: p.brand, opacity: Art.glowOpacity), .clear],
                           center: UnitPoint(x: 0.5, y: iconY / size.height), startRadius: 10, endRadius: Art.glowRadius)
            VStack(spacing: Space.hair) {
                Text(o.name).font(TypeScale.title).foregroundStyle(t.fg)
                Text(DMGText.versionLine(o.version, minimumMacOS: o.minimumMacOS))
                    .font(TypeScale.secondary).foregroundStyle(t.prose)
            }
            .position(x: size.width / 2, y: Art.headerY)
            DottedArrow(colors: [Color(hex: p.gradientTop, opacity: 0.55), Color(hex: p.brand)], head: Color(hex: p.brand))
                .position(x: (layout.appCentre.x + layout.applicationsCentre.x) / 2, y: iconY)
            // centred between the icon labels and the bottom edge, whatever the hints hold
            Hints(o: o, folder: layout.applicationsName, t: t)
                .position(x: size.width / 2, y: (iconY + layout.iconSize / 2 + 2 * layout.textSize + size.height) / 2)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// What Finder will show: the background, both icons at their positions, labels under them.
struct Preview: View {
    let o: Options
    let layout: DMGLayout
    let appIcon: NSImage
    let folder: NSImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            Background(o: o, layout: layout)
            item(appIcon, o.appLabel, at: layout.appCentre)
            item(folder, layout.applicationsName, at: layout.applicationsCentre)
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }

    private func item(_ image: NSImage, _ label: String, at centre: CGPoint) -> some View {
        VStack(spacing: Art.labelGap) {
            Image(nsImage: image).resizable().frame(width: layout.iconSize, height: layout.iconSize)
            Text(label).font(.system(size: layout.textSize)).foregroundStyle(Color.black)
        }
        .fixedSize()
        .alignmentGuide(.top) { d in d[VerticalAlignment.top] - (centre.y - layout.iconSize / 2) }
        .alignmentGuide(.leading) { d in d[HorizontalAlignment.center] - centre.x }
    }
}

// MARK: - Output

enum BackgroundError: Error, CustomStringConvertible {
    case usage(String)
    var description: String { if case .usage(let s) = self { return s }; return "" }
}

func writePNG<V: View>(_ view: V, scale: CGFloat, to url: URL) throws {
    let r = ImageRenderer(content: view)
    r.scale = scale
    guard let cg = r.cgImage, let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
        throw BackgroundError.usage("dmg-background: rendering \(url.lastPathComponent) failed")
    }
    try data.write(to: url)
}

@main
enum BackgroundTool {
    static func main() {
        do { try run(Array(CommandLine.arguments.dropFirst())) } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
    }

    static func parse(_ args: [String]) throws -> Options {
        var o = Options()
        var i = 0
        func value() throws -> String {
            guard i + 1 < args.count else { throw BackgroundError.usage("dmg-background: \(args[i]) needs a value") }
            i += 1
            return args[i]
        }
        while i < args.count {
            switch args[i] {
            case "--out": o.out = try value()
            case "--layout": o.layout = try value()
            case "--icon": o.icon = try value()
            case "--name": o.name = try value()
            case "--name-de": o.nameDE = try value()
            case "--app-label": o.appLabel = try value()
            case "--version": o.version = try value()
            case "--min-macos": o.minimumMacOS = try value()
            case "--accent":
                let v = try value()
                guard let a = AccentName(rawValue: v) else { throw BackgroundError.usage("dmg-background: unknown accent \(v)") }
                o.accent = a
            case "--lang":
                let v = try value()
                guard let l = DMGLang(rawValue: v) else { throw BackgroundError.usage("dmg-background: --lang en|de|both") }
                o.lang = l
            case "--no-hint": o.hint = false
            default: throw BackgroundError.usage("dmg-background: unknown argument \(args[i])")
            }
            i += 1
        }
        guard !o.out.isEmpty, !o.layout.isEmpty else { throw BackgroundError.usage("dmg-background: --out and --layout are required") }
        return o
    }

    static func run(_ args: [String]) throws {
        let o = try parse(args)
        let layout = try JSONDecoder().decode(DMGLayout.self, from: Data(contentsOf: URL(fileURLWithPath: o.layout)))
        let out = URL(fileURLWithPath: o.out, isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let background = Background(o: o, layout: layout)
        try writePNG(background, scale: 1, to: out.appendingPathComponent("background.png"))
        try writePNG(background, scale: 2, to: out.appendingPathComponent("background@2x.png"))
        let appIcon = NSImage(contentsOfFile: o.icon) ?? NSWorkspace.shared.icon(for: .applicationBundle)
        let folder = NSWorkspace.shared.icon(forFile: "/Applications")
        folder.size = NSSize(width: 256, height: 256)
        try writePNG(Preview(o: o, layout: layout, appIcon: appIcon, folder: folder), scale: 2,
                     to: out.appendingPathComponent("preview.png"))
    }
}
