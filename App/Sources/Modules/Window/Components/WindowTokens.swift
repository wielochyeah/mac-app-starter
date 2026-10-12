import SwiftUI

// Sizes and colours of the main window and its content blocks, on top of Kit/Design. They live
// next to the window module (removed with it) and are candidates for Kit/Design once a second
// area needs them. Values follow macOS 26 Music / Finder and VoiceBud's hub where it has one.

extension Metrics {
    enum Window {
        /// Default and minimum size of the main window.
        static let size = CGSize(width: 1180, height: 760)
        static let minSize = CGSize(width: 900, height: 600)
        /// Sidebar column widths (native NavigationSplitView).
        static let sidebarMin: CGFloat = 200
        static let sidebarIdeal: CGFloat = Metrics.sidebarWidth
        static let sidebarMax: CGFloat = 280
        /// The floating sidebar panel macOS 26 draws, imitated in renders: inset from the window edge.
        static let sidebarInset: CGFloat = 8
        /// First sidebar row starts below the traffic lights.
        static let sidebarTop: CGFloat = 48
        static let sidebarRow: CGFloat = 30
        static let sidebarSymbol: CGFloat = 15
        static let sidebarSymbolColumn: CGFloat = 22
        /// Leading inset of sidebar content from the panel edge (section titles, row symbols, footer).
        static var sidebarContentInset: CGFloat { 2 * Space.xs }
        static let sidebarSectionTop: CGFloat = 14
        static let sidebarSectionHeight: CGFloat = 24
        /// The toolbar band above the detail column (macOS 26 unified toolbar, 52 pt like the hub).
        static let toolbarBand: CGFloat = Metrics.paneHeader
        /// Toolbar search field in renders (macOS 26 draws a glass capsule).
        static let toolbarSearch = CGSize(width: 220, height: 32)
        static let toolbarGlyph: CGFloat = 15

        /// Content pages.
        static let tile: CGFloat = 168
        static let tileMin: CGFloat = 150
        static let tileMax: CGFloat = 200
        static let tileButton: CGFloat = 30
        static let tileButtonGlyph: CGFloat = 12
        static let heroHeight: CGFloat = 280
        /// A lower hero when more of the page should show above the fold.
        static let heroHeightCompact: CGFloat = 220
        static let heroTextWidth: CGFloat = 460
        static let detailArtwork: CGFloat = 220
        static let listArtwork: CGFloat = 32
        static let listRow: CGFloat = 44
        static let listIndex: CGFloat = 24
        static let listMeta: CGFloat = 84
        static let homeIcon: CGFloat = Metrics.squircleLarge
        static let stepNumber: CGFloat = 24
        /// Artwork glyph as a share of the artwork's shorter side.
        static let artworkGlyph: CGFloat = 0.36
        static let artworkGlyphWide: CGFloat = 0.62
        /// Glyph shadow radius and drop, and the wide glyph's distance from the trailing edge, as
        /// shares of the artwork's shorter side (they scale from list rows to the hero).
        static let artworkGlyphShadow: CGFloat = 0.05
        static let artworkGlyphShadowY: CGFloat = 0.015
        static let artworkGlyphTrailing: CGFloat = 0.3
        /// Disabled buttons on artwork (the kit buttons use the same 45 %).
        static let disabledOpacity: Double = 0.45
        /// Opacity of the shade spot at its centre.
        static let artworkShadeStrength: Double = 0.75
        /// Below this side length artwork uses the small radius.
        static let artworkSmall: CGFloat = 64
    }
}

extension Space {
    /// Horizontal inset of content pages (title, shelves, grids, lists).
    static var page: CGFloat { xl }
    /// Gap between the blocks of a content page (hero, shelves, lists).
    static var pageBlock: CGFloat { xl }
    /// Gap between tiles in shelves and grids.
    static var tileGap: CGFloat { pane }
}

extension TypeScale {
    /// Large title at the top of a content page (Music "Home").
    static var pageTitle: Font { intro }
    /// Title over the hero artwork.
    static var heroTitle: Font { display }
    /// Album-like header title.
    static var detailTitle: Font { intro }
}

extension Radius {
    /// Artwork below `Metrics.Window.artworkSmall` (list rows).
    static var artworkSmall: CGFloat { keyCap }
}

// Generated artwork looks the same in light and dark, so the colours that sit on it are fixed
// (white text and glyphs, a dark scrim) instead of following the scheme.
extension Theme {
    /// Text and glyphs on generated artwork.
    var onArtwork: Color { squircleGlyph }
    /// Scrim under text on artwork (hero) and under hover buttons (tiles).
    // design-ausnahme: fixed scrim on artwork, same in both schemes
    var artworkScrim: Color { Color.black.opacity(0.55) }
    // design-ausnahme: fixed scrim on artwork, same in both schemes
    var artworkScrimLight: Color { Color.black.opacity(0.28) }
    /// Buttons on artwork (tile hover, the hero's secondary action).
    // design-ausnahme: fixed button fill on artwork, same in both schemes
    var artworkButton: Color { Color.black.opacity(0.42) }
    // design-ausnahme: fixed button edge on artwork, same in both schemes
    var artworkButtonEdge: Color { Color.white.opacity(0.22) }
    /// A hovered list row: clearly darker than the stripe (`rowHover`) in both schemes.
    var listHover: Color { dark ? .white.opacity(Self.listHoverDark) : .black.opacity(Self.listHoverLight) }
    static let listHoverLight = 0.09
    static let listHoverDark = 0.12
    /// Hairline around artwork.
    var artworkEdge: Color { dark ? .white.opacity(0.08) : .black.opacity(0.08) }
    /// Shadow of artwork and of glyphs on it.
    var artworkShadow: Color { .black.opacity(dark ? 0.4 : 0.22) }
}

extension Color {
    /// Artwork colours are computed from the accent palette (`ArtworkRecipe.colors`).
    init(artwork c: ArtworkRGB) {
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: 1)
    }
}
