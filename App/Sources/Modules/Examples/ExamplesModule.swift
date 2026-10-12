import AppKit
import SwiftUI

// The example feature "Notes" (skill `neues-feature`): one small feature that uses every app form
// and module, each part in its own `#if MODUL_<NAME>` block, so it builds with any module set.
// `bin/starter strip-examples` deletes this folder and its tests once the project's first feature
// stands.
//
//   data       NotesStore (SQLite, migrations, FTS5 with LIKE fallback), NotesSeed, NotesModel
//   kit        settings pane "Notes", menu item "Save Clipboard as Note", onboarding features,
//              render scenes, self-tests, --demo examples
//   window     Overview, All Notes (search), Trash, a page per collection, the note page
//   menubar    the three notes edited last in the status menu panel
//   island     capture and AI progress
//   hotkeys    ⌃⌥N quick note from the clipboard
//   ai         Summarize (streamed), Suggest Title (structured)
//   background Empty Trash, daily

enum ExamplesModule {
    static func register() {
        Registry.settingsPanes.append(NotesPane.pane)
        Registry.menuItems.append(MenuItemContribution(id: "notes.capture", order: 100, title: { NotesText.captureAction },
                                                       symbol: "doc.on.clipboard", shortcut: nil) {
            NotesCapture.captureClipboard()
        })
        Registry.launchHooks.append { NotesDemo.prepare() }
        Registry.terminateHooks.append { NotesStore.flushShared() }
        Registry.demoDrivers.append { NotesDemo.run() }
        Registry.selfTests += selfTests
        NotesScenes.register()
        #if MODUL_WINDOW
        NotesPages.register()
        #endif
        #if MODUL_MENUBAR
        NotesMenuBar.register()
        #endif
        #if MODUL_HOTKEYS
        NotesHotkeys.register()
        #endif
        #if MODUL_BACKGROUND
        NotesBackground.register()
        #endif
        #if MODUL_AI
        NotesAI.register()
        #endif
    }

    /// SF Symbols the feature shows (the self-test checks they exist on this macOS).
    static var symbols: [String] {
        NotesSeed.collections.map(\.symbol) + NoteSource.allCases.map(\.symbol)
            + ["note.text", "house.fill", "trash", "square.grid.2x2.fill", "doc.on.doc", "pin", "pin.slash", "plus",
               "arrow.up.forward", "arrow.up.forward.app", "chevron.left", "sparkles", "text.append", "textformat",
               "text.badge.plus", "checkmark", "xmark", "lightbulb.fill", "folder", "exclamationmark.triangle.fill"]
    }

    private static var selfTests: [SelfTestCheck] {
        [
            // a store in memory: migrations, samples, index, search, trash
            SelfTestCheck(id: "examples.store") {
                let store = NotesStore(url: nil)
                if let problem = store.problem { return problem }
                guard store.notes.count == NotesSeed.notes.count, store.collections.count == NotesSeed.collections.count else {
                    return "samples missing (\(store.notes.count) notes, \(store.collections.count) collections)"
                }
                guard store.fullText else { return "no FTS5 index" }
                guard let first = store.notes.last, !store.search(first.title).isEmpty else { return "search found nothing" }
                store.trash(first.id)
                guard store.trashed.count == 1, store.purgeTrash(keep: -1) == 1 else { return "trash bookkeeping wrong" }
                return nil
            },
            SelfTestCheck(id: "examples.symbols") {
                let missing = symbols.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil }
                return missing.isEmpty ? nil : "unknown SF Symbols: \(missing.joined(separator: ", "))"
            },
        ]
    }
}
