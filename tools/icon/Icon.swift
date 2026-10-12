// Programmatic app icon: a light squircle on Apple's macOS grid with the project's SF Symbol
// (starter.json app.symbol) in the accent colour (app.accent). Built and run by scripts/icon.sh
// together with Kit/Design/Theme.swift and Tokens.swift, so the colours are the app's own.
//
// Layer technique ported from VoiceBud's assets/icon-source/Icon.swift (MIT, Copyright (c) 2026
// Anas Riad): 1024 canvas, 824 body, continuous radius 185, two drop shadows, pearl surface with
// highlight, vignette and tinted sheen, inside-only gradient strokes for the rim, glyph with glow,
// glass rim, outer hairline, and pixel-snapped small masters for 16/32/64 px.
//
//   icon master <out.png> [px]            the large master (default 1024)
//   icon small <out.png> <16|32|64>       pixel-snapped small master
//   icon iconset <dir>                    every file iconutil needs (icon_16x16.png … icon_512x512@2x.png)
//   icon preview <out.png>                master at 640 px on light and dark grounds
//   icon smallcheck <out.png>             downscaled master vs. small master, magnified, light and dark
//   icon dock <out.png> [<png|icns|self>…]  128 / 64 / 32 px rows on light and dark docks
//   icon selftest                         checks grid snapping, glyph placement and colour contrast
// Options: --accent <violett|rot|blau|gruen|orange|graphit>  --symbol <SF Symbol name>

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Colour

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let deviceGray = CGColorSpaceCreateDeviceGray()

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: sRGB, components: [
        CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
        CGFloat(hex & 0xFF) / 255, a])!
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: sRGB, colors: stops.map { $0.1 } as CFArray, locations: stops.map { $0.0 })!
}

/// `a` mixed into `b` by `t` (0 = b, 1 = a).
func mix(_ a: UInt32, into b: UInt32, _ t: Double) -> UInt32 { Contrast.over(a, t, b) }

/// The colours of one icon, all derived from the accent palette in Kit/Design/Theme.swift.
struct IconColors {
    let brand: UInt32
    let ink: UInt32       // the glyph's body: brand, darkened until it stands 3:1 off the darkest surface
    let top: UInt32       // light end of the glyph gradient (large sizes only: a highlight, not ink)
    let deep: UInt32      // dark end of the glyph gradient
    let surfaceTop: UInt32
    let surfaceMid: UInt32
    let surfaceBottom: UInt32
    let sheen: UInt32

    init(_ accent: AccentName) {
        let p = AccentPalette.of(accent)
        brand = p.brand
        surfaceTop = 0xFFFFFF
        surfaceMid = mix(p.brand, into: 0xF5F5F8, 0.035)
        surfaceBottom = mix(p.brand, into: 0xDFE0E6, 0.10)
        // surfaceBottom is the darkest point of the body, so 3:1 there holds everywhere on it
        let surface = surfaceBottom
        func darkened(_ from: Double) -> UInt32 {
            var shade = from
            while Contrast.ratio(mix(0x000000, into: p.brand, shade), surface) < 3.05 && shade < 0.6 { shade += 0.02 }
            return mix(0x000000, into: p.brand, shade)
        }
        ink = darkened(0)
        top = mix(p.gradientTop, into: ink, 0.55)
        // the dark end: the brand a quarter darker, more for light accents (orange)
        deep = darkened(0.26)
        sheen = p.gradientTop
    }
}

// MARK: - Parameters (1024-canvas units, y down)

struct Params {
    var body = CGRect(x: 100, y: 100, width: 824, height: 824)
    var radius: CGFloat = 185
    /// Longest side of the glyph's ink, and its centre below the body centre (optical lift < 0).
    var glyph: CGFloat = 520
    var glyphDY: CGFloat = -4
    var weight: NSFont.Weight = .semibold
    /// Pixel size the glyph box snaps to (small masters), nil = free.
    var snapPixels: Int? = nil
    var shadow: CGFloat = 1
    var lift: CGFloat = 0.30         // the glyph's soft shadow on the surface
    var glow: CGFloat = 0.34         // accent light around the glyph
    var pool: CGFloat = 0.20         // accent light spilling below the glyph
    var sheen: CGFloat = 0.6         // faint accent reflection in the lower left
    var gloss: CGFloat = 0.30        // white gloss on the glyph's upper half
    /// Light highlight at the top of the glyph gradient. Off for the small masters: there every
    /// pixel of the glyph is ink (3:1 on the surface), or the small parts of a symbol wash out.
    var highlight = true
    var glass: CGFloat = 1           // light rim along the top of the body
    var hairline: CGFloat = 2        // outer edge, in units
    var hairlineAlpha: CGFloat = 0.10

    /// Small masters: body and glyph on whole pixels, heavier glyph, no glow (a downscale smears),
    /// glyph only in ink colours (no highlight, no gloss).
    static func small(_ px: Int) -> Params {
        var p = Params()
        p.highlight = false
        let u = 1024 / CGFloat(px)
        let inset = (CGFloat(px) * 100 / 1024).rounded()          // 16 -> 2, 32 -> 3, 64 -> 6
        let side = CGFloat(px) - 2 * inset
        p.body = CGRect(x: inset * u, y: inset * u, width: side * u, height: side * u)
        p.radius = side * u * 185 / 824
        p.glyphDY = 0
        if px <= 16 {
            p.glyph = 8 * u; p.snapPixels = 8; p.weight = .semibold
            p.shadow = 0.7; p.lift = 0; p.glow = 0; p.pool = 0.10; p.sheen = 0; p.gloss = 0
            p.glass = 1.2; p.hairline = 0.8 * u; p.hairlineAlpha = 0.16
        } else if px <= 32 {
            p.glyph = 16 * u; p.snapPixels = 16; p.weight = .semibold
            p.shadow = 0.8; p.lift = 0.12; p.glow = 0.12; p.pool = 0.14; p.sheen = 0.3; p.gloss = 0
            p.glass = 1.1; p.hairline = 0.7 * u; p.hairlineAlpha = 0.14
        } else {
            p.glyph = 33 * u; p.snapPixels = 33; p.weight = .semibold
            p.lift = 0.22; p.glow = 0.22; p.gloss = 0; p.hairline = 0.6 * u; p.hairlineAlpha = 0.12
        }
        return p
    }
}

enum IconError: Error, CustomStringConvertible {
    case unknownSymbol(String), unknownAccent(String), usage(String)
    var description: String {
        switch self {
        case .unknownSymbol(let s): "icon: \"\(s)\" is not an SF Symbol on this Mac (app.symbol in starter.json; the SF Symbols app lists the names)"
        case .unknownAccent(let a): "icon: unknown accent \"\(a)\" (\(AccentName.allCases.map(\.rawValue).joined(separator: ", ")))"
        case .usage(let s): s
        }
    }
}

// MARK: - Glyph mask (DeviceGray, white = ink, device space y up)

/// Draws the symbol and returns its coverage as a DeviceGray image (white = ink). NSImage does not
/// draw into a DeviceGray context, so it goes through RGBA and keeps the alpha channel.
func symbolCoverage(_ img: NSImage, in rect: CGRect, width w: Int, height h: Int) -> (image: CGImage, bytes: [UInt8]) {
    let rgba = makeContext(w, h)
    drawSymbol(img, in: rect, rgba)
    let src = rgba.data!.assumingMemoryBound(to: UInt8.self)
    var alpha = [UInt8](repeating: 0, count: w * h)
    for row in 0..<h { for x in 0..<w { alpha[row * w + x] = src[row * rgba.bytesPerRow + x * 4 + 3] } }
    let provider = CGDataProvider(data: Data(alpha) as CFData)!
    let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w, space: deviceGray,
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
                        decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    return (image, alpha)
}

/// The symbol's ink bounds inside its image, as fractions (x from the left, y from the bottom).
func inkFractions(_ img: NSImage) -> CGRect {
    let scale: CGFloat = 4, pad = 4
    let w = Int((img.size.width * scale).rounded(.up)) + 2 * pad
    let h = Int((img.size.height * scale).rounded(.up)) + 2 * pad
    let draw = CGRect(x: CGFloat(pad), y: CGFloat(pad), width: img.size.width * scale, height: img.size.height * scale)
    let data = symbolCoverage(img, in: draw, width: w, height: h).bytes
    var minX = w, maxX = -1, minRow = h, maxRow = -1
    for row in 0..<h {
        for x in 0..<w where data[row * w + x] > 12 {
            minX = min(minX, x); maxX = max(maxX, x); minRow = min(minRow, row); maxRow = max(maxRow, row)
        }
    }
    guard maxX >= 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
    // memory row 0 is the top of the bitmap
    let left = (CGFloat(minX) - draw.minX) / draw.width
    let right = (CGFloat(maxX + 1) - draw.minX) / draw.width
    let bottom = (CGFloat(h - (maxRow + 1)) - draw.minY) / draw.height
    let top = (CGFloat(h - minRow) - draw.minY) / draw.height
    return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
}

func drawSymbol(_ img: NSImage, in rect: CGRect, _ ctx: CGContext) {
    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.current = previous
}

func symbolImage(_ name: String, weight: NSFont.Weight) throws -> NSImage {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { throw IconError.unknownSymbol(name) }
    return base.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 200, weight: weight)) ?? base
}

/// Where the glyph's ink lands, in device pixels (y up), for an icon of `px` pixels.
func glyphInkRect(_ p: Params, ink: CGRect, img: NSImage, px: Int) -> CGRect {
    let s = CGFloat(px) / 1024
    let inkAspect = (ink.width * img.size.width) / (ink.height * img.size.height)
    var w = inkAspect >= 1 ? p.glyph : p.glyph * inkAspect
    var h = inkAspect >= 1 ? p.glyph / inkAspect : p.glyph
    w *= s; h *= s
    let cx = p.body.midX * s
    let cyDown = (p.body.midY + p.glyphDY) * s
    if p.snapPixels != nil {
        w = max(1, w.rounded()); h = max(1, h.rounded())
        let x0 = (cx - w / 2).rounded()
        let y0Down = (cyDown - h / 2).rounded()
        return CGRect(x: x0, y: CGFloat(px) - y0Down - h, width: w, height: h)
    }
    return CGRect(x: cx - w / 2, y: CGFloat(px) - cyDown - h / 2, width: w, height: h)
}

func glyphMask(_ p: Params, symbol: String, px: Int) throws -> (mask: CGImage, ink: CGRect) {
    let img = try symbolImage(symbol, weight: p.weight)
    let ink = inkFractions(img)
    let target = glyphInkRect(p, ink: ink, img: img, px: px)
    // scale the whole image so its ink fills `target`
    let drawW = target.width / ink.width, drawH = target.height / ink.height
    let draw = CGRect(x: target.minX - ink.minX * drawW, y: target.minY - ink.minY * drawH, width: drawW, height: drawH)
    return (symbolCoverage(img, in: draw, width: px, height: px).image, target)
}

// MARK: - Drawing. The CTM maps 1024 units (y down) to the bitmap; `s` = pixels per unit
// (shadow blur and offsets are not scaled by the CTM).

func bodyPath(_ p: Params) -> CGPath {
    RoundedRectangle(cornerRadius: p.radius, style: .continuous).path(in: p.body).cgPath
}

func strokeInside(_ ctx: CGContext, _ path: CGPath, width: CGFloat, _ g: CGGradient, from a: CGPoint, to b: CGPoint) {
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    ctx.addPath(path); ctx.setLineWidth(width * 2)
    ctx.replacePathWithStrokedPath(); ctx.clip()
    ctx.drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

/// Runs `draw` in device pixels (y up), keeping the clip.
func inDevice(_ ctx: CGContext, _ draw: () -> Void) {
    ctx.saveGState()
    ctx.concatenate(ctx.ctm.inverted())
    draw()
    ctx.restoreGState()
}

/// The glyph as an RGBA image in one colour (its shape for shadows and glow).
func solidGlyph(_ mask: CGImage, _ color: CGColor, px: Int) -> CGImage {
    let ctx = makeContext(px, px)
    ctx.clip(to: CGRect(x: 0, y: 0, width: px, height: px), mask: mask)
    ctx.setFillColor(color); ctx.fill(CGRect(x: 0, y: 0, width: px, height: px))
    return ctx.makeImage()!
}

func drawIcon(_ ctx: CGContext, _ p: Params, _ c: IconColors, symbol: String, px: Int) throws {
    let s = CGFloat(px) / 1024
    let bp = bodyPath(p)
    let (mask, ink) = try glyphMask(p, symbol: symbol, px: px)
    let full = CGRect(x: 0, y: 0, width: px, height: px)
    let top = p.body.minY, bottom = p.body.maxY, mid = p.body.midX

    // 1. drop shadow: soft and wide, plus a tight contact shadow
    for (dy, blur, a) in [(10.0, 26.0, 0.30), (1.5, 3.0, 0.18)] as [(CGFloat, CGFloat, CGFloat)] {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -dy * s), blur: blur * s, color: rgb(0x000000, a * p.shadow))
        ctx.addPath(bp); ctx.setFillColor(rgb(0xE6E7EB)); ctx.fillPath()
        ctx.restoreGState()
    }

    ctx.saveGState()
    ctx.addPath(bp); ctx.clip()

    // 2. pearl surface, faintly tinted by the accent
    ctx.drawLinearGradient(gradient([(0, rgb(c.surfaceTop)), (0.45, rgb(c.surfaceMid)), (1, rgb(c.surfaceBottom))]),
                           start: CGPoint(x: mid, y: top), end: CGPoint(x: mid, y: bottom), options: [])
    let hl = CGPoint(x: mid, y: top + p.body.height * 0.28)
    ctx.drawRadialGradient(gradient([(0, rgb(0xFFFFFF, 0.6)), (1, rgb(0xFFFFFF, 0))]),
                           startCenter: hl, startRadius: 0, endCenter: hl, endRadius: p.body.width * 0.58, options: [])
    let vg = CGPoint(x: mid, y: top + p.body.height * 0.39)
    ctx.drawRadialGradient(gradient([(0, rgb(0x9AA0B4, 0)), (0.7, rgb(0x9AA0B4, 0)), (1, rgb(0x8A90A6, 0.16))]),
                           startCenter: vg, startRadius: 0, endCenter: vg, endRadius: p.body.width * 0.87, options: [])
    if p.sheen > 0 {
        let a = CGPoint(x: p.body.minX + p.body.width * 0.09, y: bottom - p.body.height * 0.03)
        ctx.drawRadialGradient(gradient([(0, rgb(c.sheen, 0.42 * p.sheen)), (1, rgb(c.sheen, 0))]),
                               startCenter: a, startRadius: 0, endCenter: a, endRadius: p.body.width * 0.62, options: [])
    }

    // 3. accent light spilling below the glyph
    let inkBottomDown = (CGFloat(px) - ink.minY) / s
    if p.pool > 0 {
        ctx.saveGState()
        ctx.translateBy(x: mid, y: inkBottomDown - p.body.height * 0.02)
        ctx.scaleBy(x: 1.6, y: 1)
        let r = p.body.width * 0.28
        ctx.drawRadialGradient(gradient([(0, rgb(c.brand, p.pool)), (0.45, rgb(c.brand, p.pool * 0.42)), (1, rgb(c.brand, 0))]),
                               startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: r, options: [])
        ctx.restoreGState()
    }

    // 4. inner edge: light at the top, a whisper of thickness at the bottom
    let edgeScale = p.body.width / 824
    strokeInside(ctx, bp, width: 5 * edgeScale,
                 gradient([(0, rgb(0xFFFFFF, 0.95)), (0.22, rgb(0xFFFFFF, 0.25)), (0.5, rgb(0xFFFFFF, 0))]),
                 from: CGPoint(x: mid, y: top), to: CGPoint(x: mid, y: bottom))
    strokeInside(ctx, bp, width: 3 * edgeScale,
                 gradient([(0.6, rgb(0x5A6075, 0)), (1, rgb(0x5A6075, 0.22))]),
                 from: CGPoint(x: mid, y: top), to: CGPoint(x: mid, y: bottom))

    // 5. glyph: soft lift shadow and accent glow, then the gradient fill and a gloss
    inDevice(ctx) {
        if p.lift > 0 {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -16 * s), blur: 30 * s, color: rgb(c.deep, p.lift))
            ctx.draw(solidGlyph(mask, rgb(c.brand), px: px), in: full)
            ctx.restoreGState()
        }
        if p.glow > 0 {
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 44 * s, color: rgb(c.brand, p.glow))
            ctx.draw(solidGlyph(mask, rgb(c.brand), px: px), in: full)
            ctx.restoreGState()
        }
        ctx.saveGState()
        ctx.clip(to: full, mask: mask)
        let stops: [(CGFloat, CGColor)] = p.highlight ? [(0, rgb(c.top)), (0.55, rgb(c.ink)), (1, rgb(c.deep))]
                                                      : [(0, rgb(c.ink)), (1, rgb(c.deep))]
        ctx.drawLinearGradient(gradient(stops),
                               start: CGPoint(x: ink.midX, y: ink.maxY), end: CGPoint(x: ink.midX, y: ink.minY),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        if p.gloss > 0 {
            ctx.drawLinearGradient(gradient([(0, rgb(0xFFFFFF, p.gloss)), (1, rgb(0xFFFFFF, 0))]),
                                   start: CGPoint(x: ink.midX, y: ink.maxY), end: CGPoint(x: ink.midX, y: ink.midY),
                                   options: [])
        }
        ctx.restoreGState()
    }

    // 6. glass: a light rim along the top of the outline, keeps it apart from dark docks
    if p.glass > 0 {
        strokeInside(ctx, bp, width: 3 * edgeScale,
                     gradient([(0, rgb(0xFFFFFF, min(1, 0.34 * p.glass))), (0.10, rgb(0xFFFFFF, 0.16 * p.glass)), (0.2, rgb(0xFFFFFF, 0))]),
                     from: CGPoint(x: mid, y: top), to: CGPoint(x: mid, y: bottom))
    }
    ctx.restoreGState()   // body clip

    // 7. outer hairline so the light body holds its edge on white backgrounds
    ctx.saveGState()
    ctx.addPath(bp); ctx.clip()
    ctx.addPath(bp); ctx.setLineWidth(p.hairline); ctx.setStrokeColor(rgb(0x000000, p.hairlineAlpha)); ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Output

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    return ctx
}

func renderIcon(_ p: Params, _ c: IconColors, symbol: String, px: Int) throws -> CGImage {
    let ctx = makeContext(px, px)
    let s = CGFloat(px) / 1024
    ctx.translateBy(x: 0, y: CGFloat(px)); ctx.scaleBy(x: s, y: -s)
    try drawIcon(ctx, p, c, symbol: symbol, px: px)
    return ctx.makeImage()!
}

/// The master for large sizes, the snapped small masters for 16 / 32 / 64.
func renderAny(_ c: IconColors, symbol: String, px: Int) throws -> CGImage {
    try renderIcon(px <= 64 ? .small(px) : Params(), c, symbol: symbol, px: px)
}

func savePNG(_ img: CGImage, _ path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw IconError.usage("icon: cannot write \(path)")
    }
    CGImageDestinationAddImage(dest, img, nil)
    guard CGImageDestinationFinalize(dest) else { throw IconError.usage("icon: cannot write \(path)") }
}

func downscale(_ img: CGImage, _ px: Int) -> CGImage {
    let ctx = makeContext(px, px)
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: px, height: px))
    return ctx.makeImage()!
}

func loadImage(_ path: String, minWidth: Int) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    let all = (0..<CGImageSourceGetCount(src)).compactMap { CGImageSourceCreateImageAtIndex(src, $0, nil) }
    return all.filter { $0.width >= minWidth }.min { $0.width < $1.width } ?? all.max { $0.width < $1.width }
}

// MARK: - Commands

@main
enum IconTool {
    static func main() {
        do { try run(Array(CommandLine.arguments.dropFirst())) } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
    }

    static func run(_ raw: [String]) throws {
        var accent = AccentName.violett, symbol = "sparkles", args: [String] = []
        var i = 0
        while i < raw.count {
            switch raw[i] {
            case "--accent" where i + 1 < raw.count:
                guard let a = AccentName(rawValue: raw[i + 1]) else { throw IconError.unknownAccent(raw[i + 1]) }
                accent = a; i += 2
            case "--symbol" where i + 1 < raw.count:
                symbol = raw[i + 1]; i += 2
            default:
                args.append(raw[i]); i += 1
            }
        }
        let usage = IconError.usage("usage: icon master|small|iconset|preview|smallcheck|dock <out> … | selftest  [--accent a] [--symbol s]")
        if args.first == "selftest" { return try selfTest(symbol: symbol) }
        guard args.count >= 2 else { throw usage }
        let c = IconColors(accent)
        let out = args[1]
        switch args[0] {
        case "master":
            let px = args.count > 2 ? Int(args[2]) ?? 1024 : 1024
            try savePNG(try renderIcon(Params(), c, symbol: symbol, px: px), out)

        case "small":
            guard args.count > 2, let px = Int(args[2]), [16, 32, 64].contains(px) else { throw usage }
            try savePNG(try renderIcon(.small(px), c, symbol: symbol, px: px), out)

        case "iconset":
            // iconutil names: icon_<pt>x<pt>[@2x].png; every file rendered at its own pixel size
            let entries: [(String, Int)] = [
                ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
            var cache: [Int: CGImage] = [:]
            for (name, px) in entries {
                let img = try cache[px] ?? renderAny(c, symbol: symbol, px: px)
                cache[px] = img
                try savePNG(img, "\(out)/icon_\(name).png")
            }

        case "preview":
            let ctx = makeContext(1340, 680)
            let icon = try renderIcon(Params(), c, symbol: symbol, px: 1024)
            for (k, ground) in [ThemeHex.windowBgLight, ThemeHex.windowBgDark].enumerated() {
                ctx.setFillColor(rgb(ground)); ctx.fill(CGRect(x: k * 670, y: 0, width: 670, height: 680))
                ctx.draw(icon, in: CGRect(x: k * 670 + 15, y: 20, width: 640, height: 640))
            }
            try savePNG(ctx.makeImage()!, out)

        case "smallcheck":
            let big = try renderIcon(Params(), c, symbol: symbol, px: 1024)
            let sizes = [64, 32, 16]
            let ctx = makeContext(1640, 380 * sizes.count)
            for (row, px) in sizes.enumerated() {
                let mag = CGFloat(320 / px)
                let y = CGFloat(380 * (sizes.count - 1 - row) + 20)
                let imgs = [downscale(big, px), try renderIcon(.small(px), c, symbol: symbol, px: px)]
                for (k, ground) in [ThemeHex.windowBgLight, ThemeHex.windowBgDark].enumerated() {
                    let x0 = CGFloat(k * 820)
                    ctx.setFillColor(rgb(ground)); ctx.fill(CGRect(x: x0, y: y - 20, width: 820, height: 380))
                    for (j, img) in imgs.enumerated() {
                        let xx = x0 + 20 + CGFloat(j) * 400
                        ctx.interpolationQuality = .none
                        ctx.draw(img, in: CGRect(x: xx, y: y, width: CGFloat(px) * mag, height: CGFloat(px) * mag))
                        ctx.interpolationQuality = .high
                        ctx.draw(img, in: CGRect(x: xx + CGFloat(px) * mag + 6, y: y, width: CGFloat(px), height: CGFloat(px)))
                    }
                }
            }
            try savePNG(ctx.makeImage()!, out)

        case "dock":
            let names = args.count > 2 ? Array(args[2...]) : ["self"]
            let sizes: [CGFloat] = [128, 64, 32], rowH: [CGFloat] = [150, 80, 46]
            let w = CGFloat(names.count) * 140 + 20, h = 2 * rowH.reduce(0, +)
            let ctx = makeContext(Int(w), Int(h))
            var y = h
            for ground in [ThemeHex.windowBgLight, ThemeHex.windowBgDark] {
                for (k, size) in sizes.enumerated() {
                    y -= rowH[k]
                    ctx.setFillColor(rgb(ground)); ctx.fill(CGRect(x: 0, y: y, width: w, height: rowH[k]))
                    for (j, n) in names.enumerated() {
                        let px = Int(size)
                        let img: CGImage
                        if n == "self" {
                            img = try renderAny(c, symbol: symbol, px: px)
                        } else if let file = loadImage(n, minWidth: px) {
                            img = file.width == px ? file : downscale(file, px)
                        } else { throw IconError.usage("icon: cannot read \(n)") }
                        ctx.draw(img, in: CGRect(x: 20 + CGFloat(j) * 140 + (128 - size) / 2, y: y + (rowH[k] - size) / 2,
                                                 width: size, height: size))
                    }
                }
            }
            try savePNG(ctx.makeImage()!, out)

        default:
            throw usage
        }
    }
}

// MARK: - Self test (run by scripts/icon.sh and scripts/tests/test_packaging.py)

func selfTest(symbol: String) throws {
    var failures: [String] = []
    func check(_ ok: Bool, _ message: @autoclosure () -> String) { if !ok { failures.append(message()) } }
    func whole(_ v: CGFloat) -> Bool { abs(v - v.rounded()) < 0.001 }
    let img = try symbolImage(symbol, weight: .semibold)
    let ink = inkFractions(img)
    check(ink.width > 0 && ink.width <= 1 && ink.height > 0 && ink.height <= 1, "ink bounds \(ink)")

    for px in [16, 32, 64] {
        let p = Params.small(px), s = CGFloat(px) / 1024
        let body = CGRect(x: p.body.minX * s, y: p.body.minY * s, width: p.body.width * s, height: p.body.height * s)
        check([body.minX, body.minY, body.maxX, body.maxY].allSatisfy(whole), "\(px) px: body \(body) not on whole pixels")
        let r = glyphInkRect(p, ink: ink, img: img, px: px)
        check([r.minX, r.minY, r.width, r.height].allSatisfy(whole), "\(px) px: glyph \(r) not on whole pixels")
        check(abs(r.midX - body.midX) <= 0.5 && abs(r.midY - body.midY) <= 0.5, "\(px) px: glyph \(r) off centre")
        check(body.insetBy(dx: 1, dy: 1).contains(r), "\(px) px: glyph \(r) touches the edge of \(body)")
        let coverage = symbolCoverage(img, in: r, width: px, height: px).bytes.reduce(0) { $0 + Int($1) }
        check(coverage > 0, "\(px) px: glyph mask is empty")
    }
    let master = Params(), r = glyphInkRect(master, ink: ink, img: img, px: 1024)
    check(master.body.insetBy(dx: master.radius * 0.3, dy: master.radius * 0.3).contains(r), "master glyph \(r) too large")

    // small masters draw the glyph in ink colours only (no highlight, no white gloss) ...
    for px in [16, 32, 64] {
        let p = Params.small(px)
        check(!p.highlight && p.gloss == 0, "\(px) px: glyph has a highlight or gloss (light parts fall below 3:1)")
    }
    // ... and both ink colours stand 3:1 off the darkest surface for every accent. The large
    // sizes add the light highlight at the top of the glyph on top of that.
    for accent in AccentName.allCases {
        let c = IconColors(accent)
        for (name, colour) in [("ink", c.ink), ("dark end", c.deep)] {
            for (where_, surface) in [("top", c.surfaceTop), ("middle", c.surfaceMid), ("bottom", c.surfaceBottom)] {
                let ratio = Contrast.ratio(colour, surface)
                check(ratio >= 3, "\(accent.rawValue): glyph \(name) \(String(format: "%.2f", ratio)):1 on the \(where_) of the surface")
            }
        }
        check(Contrast.luminance(c.surfaceTop) > Contrast.luminance(c.surfaceBottom), "\(accent.rawValue): surface not lighter at the top")
    }
    do { _ = try symbolImage("no.such.symbol.x", weight: .regular); failures.append("unknown symbol accepted") } catch {}

    if failures.isEmpty { print("icon selftest: ok") } else {
        throw IconError.usage("icon selftest: " + failures.joined(separator: "; "))
    }
}
