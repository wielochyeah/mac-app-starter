import AppKit
import SwiftUI

/// Settings pane "Menu Bar": icon style (tiles with the real icons), status text, and, when the
/// window module keeps the app reachable, whether the item shows at all.
struct MenuBarPane: View {
    var settings: Settings = .shared
    var windowModule = AppInfo.isEnabled("window")

    var body: some View {
        let style = Binding(get: { MenuBarIconStyle(setting: settings[.menuBarIconStyle]) },
                            set: { settings[.menuBarIconStyle] = $0.rawValue })
        let statusText = Binding(get: { settings[.menuBarStatusText] }, set: { settings[.menuBarStatusText] = $0 })
        let visible = Binding(get: { settings[.menuBarVisible] }, set: { settings[.menuBarVisible] = $0 })
        PaneScaffold(title: MenuBarText.paneTitle, symbol: "menubar.rectangle", tint: .indigo, subtitle: MenuBarText.paneIntro) {
            // the note explains the chosen style, so it sits right under the tiles
            SettingsSection(MenuBarText.iconSection, footnote: MenuBarText.styleNote(style.wrappedValue), footnoteLines: 2) {
                TilePicker(MenuBarIconStyle.allCases.map { TileOption($0, title: MenuBarText.styleName($0)) },
                           selection: style, tone: .settings) { value in
                    MenuBarStylePreview(style: value)
                }
            }
            SettingsSection(MenuBarText.displaySection) {
                ToggleRow(MenuBarText.statusText, subtitle: MenuBarText.statusTextDetail, isOn: statusText)
                if windowModule {
                    ToggleRow(MenuBarText.visible, subtitle: MenuBarText.visibleDetail, isOn: visible)
                }
            }
        }
    }
}

/// One of the icons as SwiftUI, drawn by `MenuBarIcon` in the colours of a menu bar over the
/// wallpaper (renders, tile previews).
struct MenuBarIconImage: View {
    let state: MenuBarState
    let style: MenuBarIconStyle
    var frame = 0
    var scale: CGFloat = 1
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let inks = MenuBarIcon.Inks.themed(label: NSColor(t.menuBarText), t)
        let image = MenuBarIcon.enlarged(MenuBarIcon.image(state: state, style: style, frame: frame, inks: inks), by: scale)
        if image.isTemplate {
            Image(nsImage: image).renderingMode(.template).foregroundStyle(t.menuBarText)
        } else {
            Image(nsImage: image)
        }
    }
}

/// A piece of menu bar over the wallpaper: what the icons sit on in previews and renders.
struct MenuBarBackdrop<Content: View>: View {
    var height: CGFloat = Metrics.Island.renderMenuBar
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(height: CGFloat = Metrics.Island.renderMenuBar, @ViewBuilder content: () -> Content) {
        self.height = height
        self.content = content()
    }

    var body: some View {
        let t = Theme(scheme)
        content
            .frame(maxWidth: .infinity, minHeight: height)
            .background(t.menuBarTint)
            .background(t.wallpaper)
    }
}

/// Tile preview of an icon style: the three states side by side in a menu bar over the desktop.
struct MenuBarStylePreview: View {
    let style: MenuBarIconStyle
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            HStack(spacing: Space.m) {
                ForEach(MenuBarState.allCases, id: \.self) { state in
                    MenuBarIconImage(state: state, style: style, scale: MenuBarIconMetrics.previewScale)
                }
            }
            .frame(maxWidth: .infinity, minHeight: MenuBarIconMetrics.previewBar)
            .background(t.menuBarTint)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(t.wallpaper)
        .accessibilityLabel(MenuBarText.styleName(style))
    }
}

extension MenuBarIconMetrics {
    /// Icons in the settings tiles.
    static let previewScale: CGFloat = 1.5
    /// Height of the menu bar band in the tile preview.
    static let previewBar: CGFloat = 36
}
