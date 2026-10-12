#if MODUL_ISLAND
import SwiftUI

/// Quick capture and the AI progress in the island and in the capsule, on the island module's
/// menu bar backdrop.
enum NotesIslandScenes {
    static func register() {
        // built when the scene renders, in the language of that render
        let saved = { NotesIsland.sample }
        add("island-saving", kind: .notch) { NotesIsland.saving }
        add("island-saved", kind: .notch, sample: IslandScenes.Sample(id: "", crop: IslandLook.hoverCrop, content: saved) {
            $0.hover = .expanded
        })
        add("capsule-saved", kind: .capsule) { saved() }
        add("island-empty", kind: .notch) { NotesIsland.clipboardEmpty }
        add("island-summarizing", kind: .notch, sample: IslandScenes.Sample(id: "", content: {
            NotesIsland.progress(NotesText.summarizing) {}
        }) {
            $0.slowSince = Date(timeIntervalSinceNow: -12)
            $0.slowHint = true
        })
        add("capsule-summarizing", kind: .capsule, sample: IslandScenes.Sample(id: "", content: {
            NotesIsland.progress(NotesText.summarizing) {}
        }) {
            $0.slowSince = Date(timeIntervalSinceNow: -7)
        })
    }

    private static func add(_ name: String, kind: IslandModel.Kind, content: @escaping () -> IslandContent) {
        add(name, kind: kind, sample: IslandScenes.Sample(id: "", content: content))
    }

    private static func add(_ name: String, kind: IslandModel.Kind, sample: IslandScenes.Sample) {
        Registry.renderScenes.append(RenderScene(id: "examples.\(name)", size: sample.crop) { IslandScenes.stage(sample, kind: kind) })
    }
}
#endif
