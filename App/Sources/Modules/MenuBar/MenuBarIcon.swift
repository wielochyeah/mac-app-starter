import AppKit

// The status item's image, drawn in code from the app's SF Symbol (`app.symbol` in starter.json).
// Ported from VoiceBud's MenuBarIcon: idle is the plain symbol as a template image (macOS tints
// it for light/dark menu bars and the pressed state); marks are drawn with
// `NSImage(size:flipped:drawingHandler:)` so they stay sharp at every backing scale, and every
// drawn image keeps the symbol's size and `alignmentRect`, so it sits exactly where the plain
// symbol sits (VoiceBud 05.10.: a redrawn copy in a variable item stood a hair off).

/// Geometry of the drawn marks, in points. Candidates for Kit/Design once a second module draws
/// status items.
enum MenuBarIconMetrics {
    /// The attention dot (VoiceBud's recording dot, 5 pt), top right inside the symbol's bounds.
    static let dot: CGFloat = 5
    /// The activity ring at the bottom right: outer diameter and line.
    static let ring: CGFloat = 7
    static let ringLine: CGFloat = 1.5
    /// Clear gap cut around a mark, so it reads against the glyph under it.
    static let knockout: CGFloat = 1
    /// Length of the turning arc and opacity of the ring's track.
    static let ringSweep: CGFloat = 120
    static let ringTrackAlpha: CGFloat = 0.3
    /// One turn of the ring in `frames` steps, one step every `frameInterval` (12 fps while busy).
    // design-ausnahme: frame rate of the drawn status item, no Motion token for AppKit timers (Kit candidate)
    static let frames = 12
    // design-ausnahme: frame rate of the drawn status item, no Motion token for AppKit timers (Kit candidate)
    static let frameInterval: TimeInterval = 1.0 / 12
    /// Enlargement of the icons in the `menubar.icon-states` render.
    static let renderScale: CGFloat = 4
}

enum MenuBarIcon {
    /// Colours of drawn (non-template) images: label ink of the menu bar's appearance, the app's
    /// accent, the alert dot.
    struct Inks {
        let label: NSColor
        let accent: NSColor
        let alert: NSColor

        /// The inks from the theme: `accentText` (>= 3:1 on the menu bar, the fill is not) and
        /// `strike`, the red of the panel's status dot. Used by the live item and every preview.
        static func themed(label: NSColor, _ t: Theme) -> Inks {
            Inks(label: label, accent: NSColor(t.accentText), alert: NSColor(t.strike))
        }
    }

    /// The template image macOS tints itself (idle, plain style, the busy ring).
    static func isTemplate(state: MenuBarState, style: MenuBarIconStyle) -> Bool {
        switch (style, state) {
        case (.plain, _), (_, .idle): true
        case (.marks, .busy): true
        case (.marks, .attention), (.color, .busy), (.color, .attention): false
        }
    }

    /// Whether the image changes over time (the busy ring); never under Reduce Motion.
    static func isAnimated(state: MenuBarState, style: MenuBarIconStyle, reduceMotion: Bool) -> Bool {
        state == .busy && style == .marks && !reduceMotion
    }

    /// The step after `frame` in the ring's turn.
    static func nextFrame(_ frame: Int) -> Int { (frame + 1) % MenuBarIconMetrics.frames }

    /// The symbol by name; a missing name (selftest `kit.symbol` catches it) falls back to a circle.
    /// With a colour it is drawn in that colour (not a template). Palette symbols apply a colour's
    /// opacity twice (0.85 ink came out 0.72, lighter than the template glyph next to it), so the
    /// palette gets the opaque colour and the opacity is applied once when drawing.
    static func symbol(_ name: String = AppInfo.symbol, color: NSColor? = nil) -> NSImage {
        let base = NSImage(systemSymbolName: name, accessibilityDescription: AppInfo.displayName)
            ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: AppInfo.displayName)
            ?? NSImage(size: NSSize(width: 16, height: 16))
        guard let color else {
            base.isTemplate = true
            return base
        }
        let opaque = color.withAlphaComponent(1)
        let palette = base.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [opaque])) ?? base
        let alpha = color.alphaComponent
        let image = NSImage(size: base.size, flipped: false) { bounds in
            palette.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: alpha)
            return true
        }
        image.isTemplate = false
        image.alignmentRect = base.alignmentRect
        image.accessibilityDescription = base.accessibilityDescription
        return image
    }

    /// The icon for a state in a style. `frame` turns the busy ring (0 when still).
    static func image(state: MenuBarState, style: MenuBarIconStyle, frame: Int = 0, inks: Inks,
                      symbol name: String = AppInfo.symbol) -> NSImage {
        switch (style, state) {
        case (.plain, _), (_, .idle):
            return symbol(name)
        case (.marks, .busy):
            return ringed(symbol(name), frame: frame)
        case (.marks, .attention), (.color, .attention):
            return dotted(symbol(name, color: inks.label), dot: inks.alert)
        case (.color, .busy):
            return symbol(name, color: inks.accent)
        }
    }

    // MARK: Geometry (pure, tested)

    /// Rounds to the half-point grid: whole pixels on Retina menu bars.
    static func snap(_ v: CGFloat) -> CGFloat { (v * 2).rounded() / 2 }

    /// The attention dot: top right, inside the symbol's bounds (non-flipped coordinates).
    static func dotRect(in size: NSSize) -> NSRect {
        let d = MenuBarIconMetrics.dot
        return NSRect(x: snap(size.width - d), y: snap(size.height - d), width: d, height: d)
    }

    /// The activity ring: bottom right, inside the symbol's bounds.
    static func ringRect(in size: NSSize) -> NSRect {
        let d = MenuBarIconMetrics.ring
        return NSRect(x: snap(size.width - d), y: 0, width: d, height: d)
    }

    /// Start and end angle (degrees, counter-clockwise from 3 o'clock) of the arc at `frame`; the
    /// arc starts at 12 o'clock and turns clockwise one step per frame.
    static func arc(frame: Int) -> (start: CGFloat, end: CGFloat) {
        let step = 360 / CGFloat(MenuBarIconMetrics.frames)
        let start = 90 - CGFloat(frame % MenuBarIconMetrics.frames) * step
        return (start, start - MenuBarIconMetrics.ringSweep)
    }

    // MARK: Drawing

    /// The symbol with the turning ring cut into its bottom right corner. A template image: the
    /// track is the ink at 30 %, the arc full ink.
    static func ringed(_ symbol: NSImage, frame: Int) -> NSImage {
        let size = symbol.size
        let ring = ringRect(in: size)
        let angles = arc(frame: frame)
        let image = NSImage(size: size, flipped: false) { bounds in
            symbol.draw(in: bounds)
            knockout(ring)
            let line = MenuBarIconMetrics.ringLine
            let center = NSPoint(x: ring.midX, y: ring.midY)
            let radius = (ring.width - line) / 2
            // design-ausnahme: template image, macOS uses only the alpha and tints it itself
            NSColor.black.withAlphaComponent(MenuBarIconMetrics.ringTrackAlpha).setStroke()
            let track = NSBezierPath(ovalIn: ring.insetBy(dx: line / 2, dy: line / 2))
            track.lineWidth = line
            track.stroke()
            // design-ausnahme: template image, macOS uses only the alpha and tints it itself
            NSColor.black.setStroke()
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: angles.start, endAngle: angles.end, clockwise: true)
            arc.lineWidth = line
            arc.lineCapStyle = .round
            arc.stroke()
            return true
        }
        image.isTemplate = true
        image.alignmentRect = symbol.alignmentRect
        image.accessibilityDescription = symbol.accessibilityDescription
        return image
    }

    /// The symbol with the alert dot at its top right, same size and alignment as the symbol alone
    /// (so it does not move when the dot comes).
    static func dotted(_ symbol: NSImage, dot color: NSColor) -> NSImage {
        let size = symbol.size
        let dot = dotRect(in: size)
        let image = NSImage(size: size, flipped: false) { bounds in
            symbol.draw(in: bounds)
            knockout(dot)
            color.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = false
        image.alignmentRect = symbol.alignmentRect
        image.accessibilityDescription = symbol.accessibilityDescription
        return image
    }

    /// Clears a ring around `rect` so the mark stands free of the glyph.
    private static func knockout(_ rect: NSRect) {
        guard let context = NSGraphicsContext.current else { return }
        let gap = MenuBarIconMetrics.knockout
        context.saveGraphicsState()
        context.compositingOperation = .clear
        NSBezierPath(ovalIn: rect.insetBy(dx: -gap, dy: -gap)).fill()
        context.restoreGraphicsState()
    }

    /// The same image `factor` times larger, still vector-sharp (renders, settings previews).
    static func enlarged(_ image: NSImage, by factor: CGFloat) -> NSImage {
        let size = NSSize(width: image.size.width * factor, height: image.size.height * factor)
        let big = NSImage(size: size, flipped: false) { bounds in
            image.draw(in: bounds)
            return true
        }
        big.isTemplate = image.isTemplate
        return big
    }
}
