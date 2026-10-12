import SwiftUI

// STUB (S0): shows every Registry.gallery entry in a settings pane (debug builds only).
// Strand E replaces this folder with the real gallery and keeps `GalleryKit.register()`.

enum GalleryKit {
    static func register() {
        #if DEBUG
        Registry.settingsPanes.append(SettingsPane(id: "gallery", group: .content, order: 900, title: { GalleryText.title },
                                                   symbol: "square.grid.2x2.fill", tint: .indigo) { AnyView(GalleryPaneStub()) })
        #endif
    }
}

private struct GalleryPaneStub: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Registry.orderedGallery) { entry in
                    GroupLabel(entry.title(), top: Space.pane)
                    entry.content()
                }
            }
            .padding(.horizontal, Space.pane)
            .padding(.bottom, Space.l)
            .frame(maxWidth: Metrics.settingsColumn, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
    }
}
