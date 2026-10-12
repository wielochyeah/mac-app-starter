import AppKit
import SwiftUI

// Render scenes and gallery entries of the menu bar module, with fixed sample content (renders
// are deterministic; nothing here runs in the app).

enum MenuBarScenes {
    static let ids = ["menubar.icon-states", "menubar.panel", "menubar.panel-busy", "menubar.panel-empty", "menubar.pane"]

    static func register() {
        Registry.renderScenes.append(RenderScene(id: "menubar.icon-states", size: .zero) { AnyView(IconStatesBoard()) })
        Registry.renderScenes.append(RenderScene(id: "menubar.panel", size: .zero) {
            AnyView(PanelStage(status: MenuBarStatus(), sections: MenuBarSamples.sections, actions: MenuBarSamples.actions))
        })
        Registry.renderScenes.append(RenderScene(id: "menubar.panel-busy", size: .zero) {
            AnyView(PanelStage(status: MenuBarStatus(state: .busy, message: MenuBarSampleText.importing),
                               sections: MenuBarSamples.sections, actions: MenuBarSamples.actions, itemState: .busy))
        })
        Registry.renderScenes.append(RenderScene(id: "menubar.panel-empty", size: .zero) {
            AnyView(PanelStage(status: MenuBarStatus(state: .attention), sections: [], actions: [], itemState: .attention))
        })
        Registry.renderScenes.append(RenderScene(id: "menubar.pane", size: .zero) {
            AnyView(MenuBarPane(settings: MenuBarSamples.settings(), windowModule: true)
                .frame(width: MenuBarSamples.paneSize.width, height: MenuBarSamples.paneSize.height))
        })

        Registry.gallery.append(GalleryEntry(id: "menubar.icon", area: "menubar", title: { MenuBarText.galleryIcon }) {
            AnyView(IconStatesBoard())
        })
        Registry.gallery.append(GalleryEntry(id: "menubar.panel", area: "menubar", title: { MenuBarText.galleryPanel }) {
            AnyView(MenuBarPanelView(close: {}, sections: MenuBarSamples.sections, actions: MenuBarSamples.actions,
                                     status: MenuBarStatus(), showsWindowAction: true))
        })
        Registry.gallery.append(GalleryEntry(id: "menubar.toggle", area: "menubar", title: { MenuBarText.galleryToggle }) {
            AnyView(QuickToggles().frame(width: MenuBarPanelMetrics.width))
        })
    }
}

enum MenuBarSamples {
    /// The settings pane in the settings window's detail column (900 - sidebar 224).
    static let paneSize = CGSize(width: 676, height: 470)
    /// The stage around the panel: a piece of desktop with the menu bar on top.
    static let stageWidth: CGFloat = 560

    static var sections: [MenuBarSection] {
        [
            MenuBarSection(id: "sample.quick", order: 0, tiled: false) { _ in AnyView(QuickToggles()) },
            MenuBarSection(id: "sample.recent", order: 10, title: { MenuBarSampleText.recent }) { panel in
                AnyView(ForEach(Array(MenuBarSampleText.recentItems.enumerated()), id: \.offset) { _, entry in
                    MenuBarActionRow(entry.title, symbol: entry.symbol) { panel.close() }
                })
            },
        ]
    }

    static var actions: [MenuItemContribution] {
        [
            MenuItemContribution(id: "sample.new", order: 0, title: { MenuBarSampleText.newItem }, symbol: "plus", shortcut: "⌘N") {},
            MenuItemContribution(id: "sample.folder", order: 1, title: { MenuBarSampleText.openFolder }, symbol: "folder",
                                 shortcut: "⇧⌘O") {},
        ]
    }

    /// Settings for pane renders: defaults, never written (the file is never saved unless changed).
    static func settings() -> Settings {
        Settings(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("starter-render-menubar-unused.json"))
    }

    /// 9:41 today in the local calendar (the clock in renders).
    static var clock: Date {
        Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date(timeIntervalSince1970: 1_791_000_000)) ?? Date()
    }
}

/// Two Control Center-style toggles side by side.
private struct QuickToggles: View {
    @State private var pause = false
    @State private var sounds = true

    var body: some View {
        HStack(spacing: Space.xs) {
            MenuBarToggle(MenuBarSampleText.pause, symbol: "pause.fill", isOn: $pause)
            MenuBarToggle(MenuBarSampleText.sounds, symbol: "speaker.wave.2.fill", isOn: $sounds)
        }
    }
}

/// A menu bar strip at real size: our item (highlighted while its panel is open) among a few
/// system items and the clock.
private struct MenuBarStrip: View {
    var itemState: MenuBarState = .idle
    var highlighted = true
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        MenuBarBackdrop {
            HStack(spacing: Space.m) {
                Spacer(minLength: 0)
                MenuBarIconImage(state: itemState, style: .marks)
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, Space.xxs)
                    .background(RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .fill(highlighted ? t.menuBarText.opacity(0.16) : .clear))
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent")
                Image(systemName: "switch.2")
                Text(Format.time(MenuBarSamples.clock)).font(TypeScale.bodyMedium)
            }
            .font(TypeScale.bodyMedium)
            .foregroundStyle(t.menuBarText)
            .padding(.horizontal, Space.m)
        }
    }
}

/// The panel hanging under the menu bar on the desktop, kept inside the screen edge like the
/// real placement does near the right corner.
private struct PanelStage: View {
    let status: MenuBarStatus
    let sections: [MenuBarSection]
    let actions: [MenuItemContribution]
    var itemState: MenuBarState = .idle
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            MenuBarStrip(itemState: itemState)
            HStack {
                Spacer(minLength: 0)
                MenuBarPanelView(close: {}, sections: sections, actions: actions, status: status, showsWindowAction: true)
            }
            .padding(.top, Space.xxs)
            .padding(.trailing, Space.xs)
            .padding(.bottom, Space.xxl)
        }
        .frame(width: MenuBarSamples.stageWidth)
        .background(t.wallpaper)
    }
}

/// Every state in every style, four times enlarged on menu bar pieces, plus the real size.
private struct IconStatesBoard: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(MenuBarText.actualSize).font(TypeScale.groupLabel).foregroundStyle(t.fg2)
                MenuBarBackdrop {
                    HStack(spacing: Space.l) {
                        ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                            HStack(spacing: Space.s) {
                                ForEach(MenuBarState.allCases, id: \.self) { state in
                                    MenuBarIconImage(state: state, style: style, frame: 1)
                                }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            Grid(alignment: .leading, horizontalSpacing: Space.m, verticalSpacing: Space.m) {
                GridRow {
                    Color.clear.frame(width: 1, height: 1)
                    ForEach(MenuBarState.allCases, id: \.self) { state in
                        Text(MenuBarText.stateName(state)).font(TypeScale.groupLabel).foregroundStyle(t.fg2)
                    }
                }
                ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                    GridRow {
                        Text(MenuBarText.styleName(style)).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
                        ForEach(MenuBarState.allCases, id: \.self) { state in
                            MenuBarBackdrop(height: MenuBarIconMetrics.renderCell.height) {
                                MenuBarIconImage(state: state, style: style, frame: 1, scale: MenuBarIconMetrics.renderScale)
                            }
                            .frame(width: MenuBarIconMetrics.renderCell.width)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                                .strokeBorder(t.tileEdge, lineWidth: Metrics.hairline))
                        }
                    }
                }
            }
        }
        .padding(Space.l)
        .background(t.windowBg)
    }
}

extension MenuBarIconMetrics {
    /// One enlarged icon on its piece of menu bar in `menubar.icon-states`.
    static let renderCell = CGSize(width: 150, height: 104)
}
