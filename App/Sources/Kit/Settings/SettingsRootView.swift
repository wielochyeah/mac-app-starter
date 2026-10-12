import SwiftUI

// The settings window (VoiceBud HubRootView / HubSidebar / HubDetail / HubStaticWindow, notes
// vb-onboarding-hub §3.1–3.2): a NavigationSplitView whose sidebar lists `Registry.settingsPanes`
// with gradient squircles, content panes on top and the "Settings" group below; the detail column
// shows the pane, whose header band sits in the window's 52 pt toolbar band.

/// The window's root view.
struct SettingsRootView: View {
    let hub: SettingsHub

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(hub: hub)
                .navigationSplitViewColumnWidth(min: Metrics.sidebarMinWidth, ideal: Metrics.sidebarWidth,
                                                max: Metrics.sidebarMaxWidth)
        } detail: {
            SettingsDetail(hub: hub)
                .ignoresSafeArea(.container, edges: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: Metrics.settingsWindowMin.width, minHeight: Metrics.settingsWindowMin.height)
    }
}

/// The same window without NavigationSplitView, for renders: macOS 26 draws the sidebar as a
/// floating glass panel inset 8 pt, which this imitates with `sidebarPanel` (glass never draws
/// offscreen).
struct SettingsStaticWindow: View {
    let hub: SettingsHub
    var size: CGSize = Metrics.settingsWindow
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let panel = RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
        StaticWindow(size: size, chrome: .settings) {
            HStack(spacing: 0) {
                SettingsSidebar(hub: hub)
                    .frame(width: Metrics.sidebarWidth)
                    .background(panel.fill(t.sidebarPanel))
                    .overlay(panel.strokeBorder(t.sidebarPanelStroke, lineWidth: Metrics.hairline))
                    .shadow(color: t.panelShadow, radius: Metrics.sidebarPanelShadowRadius, y: Metrics.sidebarPanelShadowY)
                    .padding([.leading, .top, .bottom], Metrics.sidebarPanelInset)
                SettingsDetail(hub: hub)
            }
        }
    }
}

/// The selected pane, filling the detail column.
struct SettingsDetail: View {
    let hub: SettingsHub
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let pane = hub.selected {
                pane.content().id(pane.id)
            } else {
                EmptyState(symbol: "gearshape", title: SettingsText.noPanesTitle, message: SettingsText.noPanesMessage)
            }
        }
        .environment(\.settingsHub, hub)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme(scheme).windowBg)
    }
}

/// Sidebar: one 34 pt item per pane (squircle 22, title 13, count), the selection background
/// springs between items, ↑/↓ move it, footer at the bottom.
struct SettingsSidebar: View {
    let hub: SettingsHub
    @Environment(\.renderStatic) private var renderStatic
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var ns

    var body: some View {
        let t = Theme(scheme)
        let groups = SettingsHub.groups(hub.panes)
        let order = groups.map(\.group)
        VStack(alignment: .leading, spacing: Space.hair) {
            ForEach(groups, id: \.group) { entry in
                if SettingsHub.showsLabel(for: entry.group, in: order) {
                    Text(entry.group.title)
                        .font(TypeScale.secondarySemibold)
                        .foregroundStyle(t.sideGroup)
                        .padding(.leading, Space.sidebarX)
                        .padding(.top, Space.sidebarGroupTop)
                        .padding(.bottom, Space.sidebarGroupBottom)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(entry.panes) { pane in item(pane, t) }
            }
            Spacer(minLength: Space.s)
            if let footer = SettingsHubExtras.sidebarFooter {
                footer()
                    .padding(.horizontal, Space.sidebarX)
                    .padding(.top, Space.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { Rectangle().fill(t.separator).frame(height: Metrics.hairline) }
            }
        }
        .padding(.horizontal, Space.sidebarX)
        .padding(.top, Metrics.sidebarTop)
        .padding(.bottom, Space.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea(.container, edges: .top)
        .animation(Motion.adaptive(Motion.selection, reduce: reduceMotion), value: hub.pane)
        .focusable(!renderStatic)
        .focusEffectDisabled()
        .onKeyPress(.downArrow) { hub.step(1); return .handled }
        .onKeyPress(.upArrow) { hub.step(-1); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(CommonText.settings)
    }

    private func item(_ pane: SettingsPane, _ t: Theme) -> some View {
        let selected = hub.pane == pane.id
        return Button { hub.select(pane.id) } label: {
            HStack(spacing: Space.iconGap) {
                SquircleIcon(symbol: pane.symbol, tint: pane.tint)
                Text(pane.title())
                    .font(TypeScale.body)
                    .foregroundStyle(t.fg)
                    .lineLimit(1)
                Spacer(minLength: Space.xxs)
                CountBadge(SettingsHubExtras.count(for: pane.id))
            }
            .padding(.horizontal, Space.xs)
            .frame(height: Metrics.sidebarRow)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .fill(t.sideSel)
                        .matchedGeometryEffect(id: "selection", in: ns)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - The hub in the environment (panes reach ⌘F and deep links through it)

private nonisolated struct SettingsHubKey: EnvironmentKey {
    static let defaultValue: SettingsHub? = nil
}

extension EnvironmentValues {
    /// The settings window's state for panes inside it (nil elsewhere, e.g. in the gallery).
    var settingsHub: SettingsHub? {
        get { self[SettingsHubKey.self] }
        set { self[SettingsHubKey.self] = newValue }
    }
}
