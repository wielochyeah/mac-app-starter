import SwiftUI

/// The component gallery: a settings pane listing every `Registry.gallery` entry. Shown in debug
/// builds, and in release builds when the setting `kit.showGallery` is true.
///
/// Modules add their components with
///
///     Registry.gallery.append(GalleryEntry(id: "island.states", area: "island",
///                                          title: { IslandText.galleryStates }) { AnyView(StatesSample()) })
enum GalleryKit {
    static var isVisible: Bool {
        GalleryModel.isVisible(debug: GalleryModel.isDebugBuild, setting: Settings.shared[.showGallery])
    }

    static func register() {
        guard isVisible else { return }
        Registry.settingsPanes.append(SettingsPane(id: "gallery", group: .content, order: 900, title: { GalleryText.title },
                                                   symbol: "square.grid.2x2.fill", tint: .indigo) { AnyView(GalleryPane()) })
        SettingsHubExtras.counts["gallery"] = { Registry.gallery.count }
        Registry.renderScenes += [
            RenderScene(id: "settings.gallery", size: .zero) { AnyView(SettingsScenes.window(pane: "gallery")) },
            RenderScene(id: "gallery.dark-stage", size: SettingsScenes.paneSize) {
                AnyView(GalleryPane(area: "patterns", scheme: .dark))
            },
            RenderScene(id: "gallery.light-stage", size: SettingsScenes.paneSize) {
                AnyView(GalleryPane(area: "settings", scheme: .light))
            },
            RenderScene(id: "gallery.no-results", size: SettingsScenes.paneSize) {
                AnyView(GalleryPane(query: GalleryText.sampleQuery))
            },
        ]
    }
}
