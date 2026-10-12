import SwiftUI

// Sizes of the settings window's sidebar, About header and gallery stage, from VoiceBud's hub
// (ui/Hub.swift HubSidebar / HubStaticWindow, notes vb-onboarding-hub §3.2). Kept next to the hub;
// candidates for Kit/Design once a second window needs them.

extension Metrics {
    /// Sidebar column width range of the NavigationSplitView (ideal = `sidebarWidth`).
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarMaxWidth: CGFloat = 280
    /// Top inset of the sidebar items under the traffic lights (macOS 26 floating sidebar).
    static let sidebarTop: CGFloat = 44
    /// Gap between the static sidebar panel and the window edge (macOS 26 inset glass panel).
    static let sidebarPanelInset: CGFloat = 8
    static let sidebarPanelShadowRadius: CGFloat = 6
    static let sidebarPanelShadowY: CGFloat = 1
    /// App icon at the top of the About pane.
    static let aboutIcon: CGFloat = 96
    /// The band under the gallery header (area menu, count, light/dark switch), VoiceBud stats line.
    static let subBar: CGFloat = 38
    /// Gallery entries wider than this are drawn as flexible (they fill the stage).
    static let galleryFlexibleWidth: CGFloat = 2000
    /// Extra width offered to fixed-size gallery entries (see `GalleryFit.size(of:)`).
    static let gallerySlack: CGFloat = 8
    /// Height of the sidebar sample in the gallery.
    static let sidebarSample: CGFloat = 340
    /// Height of the `settings.about-full` render (every section visible, no scrolling).
    static let aboutFullRender: CGFloat = 860
    /// The third-party notices sheet.
    static let noticesSheet = CGSize(width: 560, height: 480)
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
