import SwiftUI

/// The settings window (hub) and its kit panes. Modules add panes with
///
///     Registry.settingsPanes.append(SettingsPane(id: "notes", group: .settings, order: 300,
///         title: { NotesText.pane }, symbol: "note.text", tint: .yellow) { AnyView(NotesPane()) })
///
/// and open the window with `AppActions.openSettings(pane: "notes")`. Content panes (`.content`)
/// sit on top of the sidebar, setting panes below the "Settings" label; General is order 0 and
/// About order 1000 of the settings group, so module panes go in between.
enum SettingsKit {
    static func register() {
        AppActions.settingsHandler = { pane in SettingsController.show(pane: pane) }
        Registry.settingsPanes += [
            SettingsPane(id: "general", group: .settings, order: 0, title: { SettingsText.general }, symbol: "gearshape.fill",
                         tint: .graphite) { AnyView(GeneralPane()) },
            SettingsPane(id: "about", group: .settings, order: 1000, title: { SettingsText.about }, symbol: "info.circle.fill",
                         tint: .accent) { AnyView(AboutPane()) },
        ]
        Registry.launchHooks.append { AppAppearance.apply() }
        Registry.selfTests.append(SelfTestCheck(id: "settings.panes") {
            let ids = Registry.orderedSettingsPanes.map(\.id)
            for required in ["general", "about"] where !ids.contains(required) { return "pane \(required) missing" }
            if Set(ids).count != ids.count { return "duplicate pane ids" }
            if SettingsHub.resolve("about", current: nil, available: ids) != "about" { return "deep link to about fails" }
            return nil
        })
        Registry.selfTests.append(SelfTestCheck(id: "settings.window") { SettingsController.checkWindow() })
        SettingsScenes.register()
    }
}

/// Render scenes and gallery entries of the settings window. Each scene builds its own hub
/// (`persists: false`), so renders never change the real selection.
enum SettingsScenes {
    /// Width of the detail column in the default window (900 minus sidebar 224 minus panel inset 8).
    static var paneSize: CGSize {
        CGSize(width: Metrics.settingsWindow.width - Metrics.sidebarWidth - Metrics.Sidebar.panelInset,
               height: Metrics.settingsWindow.height)
    }

    static func register() {
        Registry.renderScenes += [
            RenderScene(id: "settings.window", size: .zero) { AnyView(window(pane: "general")) },
            RenderScene(id: "settings.window-about", size: .zero) { AnyView(window(pane: "about")) },
            RenderScene(id: "settings.window-many", size: .zero) { AnyView(manyPanesWindow) },
            RenderScene(id: "settings.general", size: paneSize) { AnyView(GeneralPane()) },
            RenderScene(id: "settings.general-reset", size: paneSize) { AnyView(GeneralPane(confirmingReset: true)) },
            RenderScene(id: "settings.about", size: paneSize) { AnyView(AboutPane()) },
            RenderScene(id: "settings.about-full", size: CGSize(width: paneSize.width, height: Metrics.aboutFullRender)) { AnyView(AboutPane(info: sampleAbout, copied: true)) },
            // the bundled file of the render language; the sample only when the build has none
            RenderScene(id: "settings.notices", size: .zero) {
                AnyView(RenderBoard { NoticesSheet(text: AboutInfo.bundledNotices(Localizer.shared.lang) ?? SettingsSampleText.notices) {} })
            },
        ]
        Registry.gallery += [
            GalleryEntry(id: "settings.sidebar", area: "settings", title: { SettingsText.sidebarTitle }) { AnyView(SidebarSample()) },
            GalleryEntry(id: "settings.local-footer", area: "settings", title: { SettingsText.footerTitle }) { AnyView(LocalOnlyFooter()) },
        ]
    }

    static func window(pane: String) -> some View {
        RenderBoard { SettingsStaticWindow(hub: SettingsHub(pane: pane, persists: false)) }
    }

    /// The About pane with links, the notices row and a known version (the configured app has none).
    static var sampleAbout: AboutInfo {
        var info = AboutInfo()
        info.links = [(SettingsSampleText.website, "https://example.com"), (SettingsSampleText.feedback, "mailto:feedback@example.com")]
            .compactMap { title, link in URL(string: link).map { AboutInfo.Link(title: title, url: $0) } }
        if info.notices == nil { info.fixedNotices = SettingsSampleText.notices }
        return info
    }

    /// A project with many panes at the minimum window size: the list scrolls, the footer stays.
    static var manyPanesWindow: some View {
        let samples = SettingsSampleText.panes.enumerated().map { index, sample in
            SettingsPane(id: "sample.\(index)", group: sample.group, order: 100 + index, title: sample.title,
                         symbol: sample.symbol, tint: sample.tint) { AnyView(EmptyView()) }
        }
        let panes = (Registry.orderedSettingsPanes + samples).sorted { ($0.group, $0.order, $0.id) < ($1.group, $1.order, $1.id) }
        let hub = SettingsHub(pane: "general", persists: false) { panes }
        return RenderBoard {
            SettingsStaticWindow(hub: hub, size: Metrics.settingsWindowMin, footer: { AnyView(LocalOnlyFooter()) })
        }
    }
}

/// The sidebar on its own, as macOS 26 draws it (floating panel, no traffic lights), for the gallery.
private struct SidebarSample: View {
    var body: some View {
        SettingsSidebar(hub: SettingsHub(pane: "general", persists: false), top: Metrics.Sidebar.topAlone,
                        footer: { AnyView(LocalOnlyFooter()) })
            .frame(width: Metrics.sidebarWidth, height: Metrics.sidebarSample)
            .staticSidebarPanel()
            .environment(\.renderStatic, true)
    }
}
