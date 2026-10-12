import AppKit
import SwiftUI

extension SettingKey {
    /// Shows the component gallery in release builds too (debug builds always show it). Set it in
    /// settings.json by hand: `"kit.showGallery": true`.
    static var showGallery: SettingKey<Bool> { .init("kit.showGallery", default: false) }
}

/// What the gallery shows (pure, tested): entries grouped by area in a fixed area order, filtered
/// by area and search text.
enum GalleryModel {
    struct Group: Identifiable {
        let area: String
        let entries: [GalleryEntry]
        var id: String { area }
    }

    /// Kit areas first (design, patterns, settings, onboarding, …), then modules, then anything else
    /// alphabetically.
    static let areaOrder = ["design", "patterns", "settings", "onboarding", "permissions", "gallery", "window", "menubar",
                            "island", "background", "hotkeys", "ai", "mlx", "examples"]

    static func areaRank(_ area: String) -> Int { areaOrder.firstIndex(of: area) ?? areaOrder.count }

    /// Areas present in `entries`, in display order.
    static func areas(_ entries: [GalleryEntry]) -> [String] {
        Set(entries.map(\.area)).sorted { (areaRank($0), $0) < (areaRank($1), $1) }
    }

    /// `area` nil = all areas. `query` matches title, id and area title (every word, case and
    /// accents ignored, like `ListSearch`).
    static func groups(_ entries: [GalleryEntry], area: String?, query: String) -> [Group] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return areas(entries).compactMap { a in
            guard area == nil || area == a else { return nil }
            let members = entries.filter { e in
                e.area == a && (q.isEmpty || ListSearch.matches(e.title(), e.id, GalleryText.area(a), query: q))
            }
            return members.isEmpty ? nil : Group(area: a, entries: members)
        }
    }

    /// Whether the gallery pane exists in this build.
    static func isVisible(debug: Bool, setting: Bool) -> Bool { debug || setting }

    static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

/// Preview appearance of the gallery stage.
enum GalleryScheme: String, CaseIterable {
    case window, light, dark

    func resolve(_ windowScheme: ColorScheme) -> ColorScheme {
        switch self {
        case .window: windowScheme
        case .light: .light
        case .dark: .dark
        }
    }

    var title: String {
        switch self {
        case .window: GalleryText.schemeWindow
        case .light: GalleryText.schemeLight
        case .dark: GalleryText.schemeDark
        }
    }
}

/// How a preview fits the stage (pure, tested): entries with a fixed size wider than the stage are
/// scaled down as a whole (window samples stay readable as pictures), flexible ones fill the width.
enum GalleryFit {
    enum Size: Equatable {
        case fixed(CGSize)
        case flexible
    }

    /// Classifies a measured ideal size.
    static func classify(_ measured: CGSize) -> Size {
        guard measured.width.isFinite, measured.height.isFinite, measured.width >= 1, measured.height >= 1,
              measured.width < Metrics.galleryFlexibleWidth else { return .flexible }
        return .fixed(measured)
    }

    /// Scale for a fixed size in `available` width: never above 1.
    nonisolated static func scale(ideal: CGSize, available: CGFloat) -> CGFloat {
        guard ideal.width > 0, available > 0 else { return 1 }
        return min(1, available / ideal.width)
    }

    private static var cache: [String: Size] = [:]

    /// The entry's ideal size, measured once per language (offscreen hosting controller, static
    /// mode so ScrollViews and glass take their render size).
    static func size(of entry: GalleryEntry) -> Size {
        let key = "\(entry.id)|\(Localizer.shared.lang.rawValue)"
        if let known = cache[key] { return known }
        // measured at the scale it is drawn at (text widths round differently at 1x), then rounded
        // up to whole points: a stage a hair narrower than the content truncates its labels
        let scale = RenderMode.isStatic ? 2 : (NSScreen.main?.backingScaleFactor ?? 2)
        let probe = NSHostingController(rootView: AnyView(entry.content()
            .environment(\.renderStatic, true)
            .environment(\.displayScale, scale)))
        let raw = probe.sizeThatFits(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
        // Slack: offered exactly its ideal width, an HStack with two shrinkable texts may still cut
        // one ("Wei…" in design.accents, German); a few points more and nothing is cut.
        let measured = classify(CGSize(width: (raw.width + Metrics.gallerySlack).rounded(.up), height: raw.height.rounded(.up)))
        cache[key] = measured
        return measured
    }
}

/// Lays out a fixed-size preview at `ideal` scaled to the offered width, keeping its aspect ratio.
nonisolated struct GalleryFitLayout: Layout {
    let ideal: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        Self.fitted(ideal, width: proposal.width)
    }

    /// `ideal` scaled into `width` (nil = no limit), aspect ratio kept.
    static func fitted(_ ideal: CGSize, width: CGFloat?) -> CGSize {
        let s = GalleryFit.scale(ideal: ideal, available: width ?? ideal.width)
        return CGSize(width: ideal.width * s, height: ideal.height * s)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for view in subviews {
            view.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        }
    }
}
