import SwiftUI

// The sidebar of the settings window and the main window: macOS 26 draws it as a floating glass
// panel inset from the window edge. Renders imitate that panel with `staticSidebarPanel()`, because
// glass never draws offscreen. Values from VoiceBud's hub (HubSidebar / HubStaticWindow) and macOS 26
// Music for the native list of the main window.

extension Metrics {
    enum Sidebar {
        /// Column width range (ideal = `Metrics.sidebarWidth`).
        static let minWidth: CGFloat = 200
        static let maxWidth: CGFloat = 280
        /// First item below the top of the sidebar panel, clear of the traffic lights.
        static let top: CGFloat = 44
        /// Top inset when the sidebar is drawn on its own (gallery), without traffic lights.
        static let topAlone: CGFloat = 12
        /// Gap between the sidebar panel and the window edge (macOS 26 inset glass panel).
        static let panelInset: CGFloat = 8
        static let panelShadowRadius: CGFloat = 6
        static let panelShadowY: CGFloat = 1
        /// A row of the native sidebar list (main window; the settings sidebar uses `Metrics.sidebarRow`).
        static let listRow: CGFloat = 30
        /// Row symbols of the native list and the column they sit in (footer dots share it).
        static let symbol: CGFloat = 15
        static let symbolColumn: CGFloat = 22
        /// Leading inset of the native list's content from the panel edge (section titles, symbols, footer).
        static var contentInset: CGFloat { 2 * Space.xs }
        /// Section titles of the native list: gap above and the title's height.
        static let sectionTop: CGFloat = 14
        static let sectionHeight: CGFloat = 24
    }
}

extension View {
    /// The floating sidebar panel for renders: panel colour, hairline edge, soft shadow.
    func staticSidebarPanel() -> some View { modifier(StaticSidebarPanel()) }
}

private struct StaticSidebarPanel: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
        content
            .background(shape.fill(t.sidebarPanel))
            .overlay(shape.strokeBorder(t.sidebarPanelStroke, lineWidth: Metrics.hairline))
            .compositingGroup()
            .shadow(color: t.panelShadow, radius: Metrics.Sidebar.panelShadowRadius, y: Metrics.Sidebar.panelShadowY)
    }
}
