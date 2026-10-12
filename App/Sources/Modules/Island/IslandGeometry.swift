import AppKit

/// What the island needs to know about one display. Built from an `NSScreen`, or by hand in
/// tests (notch / no notch, several screens, auto-hiding menu bar).
struct IslandScreen: Equatable {
    var frame: CGRect
    var visibleFrame: CGRect
    /// `safeAreaInsets.top`: the camera housing band, 0 without a notch.
    var safeTop: CGFloat
    /// Widths of `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` (the menu bar left and right
    /// of the notch), nil when the screen has none.
    var auxLeftWidth: CGFloat?
    var auxRightWidth: CGFloat?
    var displayID: UInt32?
    var scale: CGFloat

    init(frame: CGRect, visibleFrame: CGRect, safeTop: CGFloat = 0, auxLeftWidth: CGFloat? = nil,
         auxRightWidth: CGFloat? = nil, displayID: UInt32? = nil, scale: CGFloat = 2) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeTop = safeTop
        self.auxLeftWidth = auxLeftWidth
        self.auxRightWidth = auxRightWidth
        self.displayID = displayID
        self.scale = scale
    }

    init(_ screen: NSScreen) {
        self.init(frame: screen.frame, visibleFrame: screen.visibleFrame, safeTop: screen.safeAreaInsets.top,
                  auxLeftWidth: screen.auxiliaryTopLeftArea?.width, auxRightWidth: screen.auxiliaryTopRightArea?.width,
                  displayID: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
                  scale: screen.backingScaleFactor)
    }

    static var all: [IslandScreen] { NSScreen.screens.map(IslandScreen.init) }

    /// The screen under `point` (screen coordinates; the top edge row counts, like
    /// `NSMouseInRect` on unflipped coordinates), else the first one.
    static func containing(_ point: CGPoint, in screens: [IslandScreen]) -> IslandScreen? {
        screens.first { s in
            point.x >= s.frame.minX && point.x < s.frame.maxX && point.y > s.frame.minY && point.y <= s.frame.maxY
        } ?? screens.first
    }
}

/// Notch and menu bar of one screen, measured, never hard-coded (VoiceBud IslandScreenGeometry).
struct IslandScreenGeometry: Equatable {
    let frame: CGRect
    /// The camera housing, nil without one.
    let notch: CGSize?
    /// The notch's centre (from the left menu bar width, not the screen centre).
    let notchMidX: CGFloat
    /// Menu bar height; when it hides automatically the notch height, or 24 without a notch.
    let menuBarHeight: CGFloat
    let safeTop: CGFloat
    let displayID: UInt32?
    let scale: CGFloat

    /// Fallback menu bar height on screens without notch whose menu bar hides itself.
    static let fallbackMenuBar: CGFloat = 24
    /// Notches narrower than this are measurement noise.
    static let minNotchWidth: CGFloat = 40

    init(_ screen: IslandScreen) {
        frame = screen.frame
        scale = screen.scale
        displayID = screen.displayID
        safeTop = screen.safeTop
        if screen.safeTop > 0, let l = screen.auxLeftWidth, let r = screen.auxRightWidth,
           screen.frame.width - l - r > Self.minNotchWidth {
            let w = screen.frame.width - l - r
            notch = CGSize(width: w, height: screen.safeTop)
            notchMidX = screen.frame.minX + l + w / 2
        } else {
            notch = nil
            notchMidX = screen.frame.midX
        }
        let gap = screen.frame.maxY - screen.visibleFrame.maxY
        menuBarHeight = gap > 1 ? gap : (notch?.height ?? Self.fallbackMenuBar)
    }

    /// The panel's origin: top edge flush with the screen top, centred on the notch, on whole pixels.
    func panelOrigin(for size: CGSize) -> CGPoint {
        let s = max(scale, 1)
        let x = ((notchMidX - size.width / 2) * s).rounded() / s
        return CGPoint(x: x, y: frame.maxY - size.height)
    }

    /// The notch the island grows from; screens without one get a stand-in the capsule ignores.
    var drawnNotch: CGSize {
        notch ?? CGSize(width: Metrics.Island.renderNotch.width, height: menuBarHeight)
    }

    /// Island or capsule for a new take (decided once per take, never mid-way).
    func kind(style: IslandStyle, notchBusy: Bool) -> IslandModel.Kind {
        guard notch != nil else { return .capsule }
        switch style {
        case .capsule: return .capsule
        case .island: return .notch
        case .auto: return notchBusy ? .capsule : .notch
        }
    }

    /// The capsule's top: 8 pt below the menu bar, or below the notch when another notch app
    /// holds it (dodge).
    func capsuleTop(style: IslandStyle, notchBusy: Bool) -> CGFloat {
        let dodge = style == .auto && notchBusy && notch != nil
        return (dodge ? (notch?.height ?? menuBarHeight) : menuBarHeight) + Metrics.Island.capsuleTop
    }
}

/// Widths of the island for a content: ears sized to what they hold, cards at fixed widths.
/// Pure maths (IslandTests), shared by the notch island and the previews.
enum IslandLayout {
    static func width(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    /// Badge plus title (an empty title: the badge alone).
    private static func titled(_ title: String) -> CGFloat {
        title.isEmpty ? IslandLook.badge : IslandLook.badge + IslandLook.earSpacing + width(title, font: IslandLook.titleFont)
    }

    /// Width of the content in the left and right ear (without the 14 pt outer padding).
    static func ears(_ content: IslandContent, slowCounting: Bool = false) -> (left: CGFloat, right: CGFloat) {
        let badge = IslandLook.badge
        switch content {
        case .activity(_, let title, let detail, _):
            let right = detail.map { width($0, font: IslandLook.detailFont) } ?? 0
            return (titled(title), right)
        case .progress(let title, let fraction, _, _, _):
            var right = IslandLook.spinnerFrame
            if let fraction { right += IslandLook.glyphGap + width(IslandText.percent(fraction), font: IslandLook.counterFont) }
            // two digits: the ear is sized once when counting starts, not every second
            if slowCounting { right += IslandLook.glyphGap + width(IslandText.counter(88), font: IslandLook.counterFont) }
            return (titled(title), right)
        case .levels(_, _, _, let recording):
            return (recording ? badge + IslandLook.earSpacing + Metrics.Island.recDot : badge, IslandLook.meterWidth)
        case .done, .notice:
            return (badge, 0)
        }
    }

    /// Body width of the notch island (without the ears' concave corners).
    ///   - shown: false = collapsed behind the hardware notch (8 pt narrower, so any real corner
    ///     radius hides it)
    ///   - expanded: a hovered done card
    ///   - slowCounting: a slow progress counts its seconds
    ///   - slowHint: the "takes longer" card is down
    static func notchWidth(_ content: IslandContent?, notch: CGSize, shown: Bool, expanded: Bool = false,
                           slowCounting: Bool = false, slowHint: Bool = false) -> CGFloat {
        guard shown, let content else { return notch.width - Metrics.Island.collapsedInset }
        let widest = max(Metrics.Island.liveWidth, notch.width + 2 * Metrics.Island.compactWing)
        switch content {
        case .done:
            return expanded ? Metrics.Island.liveWidth : Metrics.Island.doneWidth
        case .notice(let text, _):
            return noticeWidth(text, notch: notch.width)
        default:
            let ears = ears(content, slowCounting: slowCounting)
            let wing = max(Metrics.Island.compactWing, IslandLook.earPad + max(ears.left, ears.right))
            var w = notch.width + 2 * wing
            if slowHint { w = max(w, notch.width + 2 * IslandLook.cardWing) }
            return min(w, widest)
        }
    }

    /// Notice on the notch: as narrow as the compact island, wider only when the text needs it.
    static func noticeWidth(_ text: String, notch: CGFloat) -> CGFloat {
        min(Metrics.Island.doneWidth,
            max(notch + 2 * Metrics.Island.compactWing, width(text, font: IslandLook.noticeFont) + 2 * Metrics.Island.bodyPad))
    }

    /// Notice in the capsule: badge, gap, text and the card's paddings.
    static func capsuleNoticeWidth(_ text: String) -> CGFloat {
        let chrome = IslandLook.noticeLeading + IslandLook.badge + IslandLook.actionGap + IslandLook.noticeTrailing
        return min(Metrics.Island.doneWidth, max(IslandLook.noticeMinCapsule, width(text, font: IslandLook.noticeFont) + chrome))
    }

    /// A done card's body as paragraphs: blank lines separate them, single breaks stay inside
    /// (greeting, sign-off), whitespace at line ends goes.
    static func paragraphs(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var out: [[String]] = [[]]
        for raw in normalized.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if !(out.last ?? []).isEmpty { out.append([]) }
            } else {
                out[out.count - 1].append(line)
            }
        }
        return out.filter { !$0.isEmpty }.map { $0.joined(separator: "\n") }
    }

    /// One line for the folded card.
    static func preview(_ text: String) -> String {
        paragraphs(text).joined(separator: " ").replacingOccurrences(of: "\n", with: " ")
    }

    /// "m:ss" for the elapsed timer.
    static func timer(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
