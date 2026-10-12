import SwiftUI

// Tokens of the settings window (Kit/Settings) and the component gallery (Kit/Gallery), from
// VoiceBud's hub (ui/Hub.swift HubSidebar / HubStaticWindow, notes vb-onboarding-hub §3.2).
// `Metrics.Sidebar` is the macOS 26 floating sidebar; the main window (module window) should use
// it too instead of its own copy.

extension Metrics {
    /// The floating sidebar of a NavigationSplitView window on macOS 26 (and its render imitation).
    enum Sidebar {
        /// Column width range (ideal = `Metrics.sidebarWidth`).
        static let minWidth: CGFloat = 200
        static let maxWidth: CGFloat = 280
        /// Top inset of the first item, below the traffic lights.
        static let top: CGFloat = 44
        /// Top inset when the sidebar is drawn on its own (gallery), without traffic lights.
        static let topAlone: CGFloat = 12
        /// Gap between the static sidebar panel and the window edge (macOS 26 inset glass panel).
        static let panelInset: CGFloat = 8
        static let panelShadowRadius: CGFloat = 6
        static let panelShadowY: CGFloat = 1
    }

    /// App icon at the top of the About pane.
    static let aboutIcon: CGFloat = 96
    /// The band under the gallery header (area menu, count, light/dark switch), VoiceBud stats line.
    static let subBar: CGFloat = 38
    /// Gallery entries wider than this are drawn as flexible (they fill the stage).
    static let galleryFlexibleWidth: CGFloat = 2000
    /// Extra width offered to fixed-size gallery entries (see `GalleryFit.size(of:)`).
    static let gallerySlack: CGFloat = 8
    /// Height of the sidebar sample in the gallery (kit panes plus the opt-in footer).
    static let sidebarSample: CGFloat = 270
    /// Height of the `settings.about-full` render (every section visible, no scrolling).
    static let aboutFullRender: CGFloat = 860
    /// The third-party notices sheet: wide enough for an 80-column licence text in `TypeScale.code`.
    static let noticesSheet = CGSize(width: 600, height: 520)
}

extension Space {
    /// Sidebar horizontal padding (VoiceBud 10) and item padding inside it (8 = `xs`).
    static let sidebarX: CGFloat = 10
    /// Group label in the sidebar: 18 above, 5 below (VoiceBud).
    static let sidebarGroupTop: CGFloat = 18
    static let sidebarGroupBottom: CGFloat = 5
    /// Footer: dot to text 6, second line indented under the text (dot 7 + gap 6).
    static let sidebarFooterGap: CGFloat = 6
    static let sidebarFooterIndent: CGFloat = 13
    /// A list bullet's centre sits this far above the text baseline (about half the x-height of 12 pt).
    nonisolated static let bulletLift: CGFloat = 4
}

extension TypeScale {
    /// Licence texts and other verbatim blocks (80 columns fit `Metrics.noticesSheet`).
    static let code = Font.system(size: 10.5, design: .monospaced)
    /// Inline code in prose set in `secondary` (12 pt).
    static let codeInline = Font.system(size: 11, design: .monospaced)
}

extension Motion {
    /// How long a "Copied" chip stays before it turns back (VoiceBud HubHistoryRow).
    static let copiedHold: TimeInterval = 1.4
    /// How long a "done" status replaces a row's action (e.g. "Back to defaults").
    static let doneHold: TimeInterval = 2.4
}

/// Text colour of a destructive action on a secondary button ("Reset"), >= 4.5:1 on the button
/// in both schemes (SettingsHubTests).
nonisolated enum DestructiveHex {
    static let light: UInt32 = 0xC4162E
    static let dark: UInt32 = 0xFF9F99
}

extension Theme {
    var destructive: Color { Color(hex: dark ? DestructiveHex.dark : DestructiveHex.light) }
}
