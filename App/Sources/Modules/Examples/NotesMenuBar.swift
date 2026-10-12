#if MODUL_MENUBAR
import AppKit
import SwiftUI

// Notes in the status menu panel (skill `menueleisten-app`): the three notes edited last. A click
// copies one, ⌥-click opens it. Saving the clipboard is the panel's action below (it comes from
// `Registry.menuItems`, so the right-click menu and the app menu have it too).

enum NotesMenuBar {
    static func register() {
        MenuBarPanel.sections.append(section { NotesStore.shared })
    }

    static func section(store: @escaping () -> NotesStore) -> MenuBarSection {
        MenuBarSection(id: "notes", order: 20, title: { NotesText.menuTitle }) { panel in
            AnyView(NotesPanelSection(store: store(), close: panel.close))
        }
    }

    /// ⌥-click opens, a plain click copies.
    static func clicked(_ note: NoteItem, option: Bool = NSEvent.modifierFlags.contains(.option), close: () -> Void) {
        close()
        if option {
            NotesActions.open(note.id)
        } else {
            NotesActions.copy(note)
        }
    }
}

struct NotesPanelSection: View {
    var store: NotesStore
    let close: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let recent = store.recent(NotesLook.panelCount)
        VStack(alignment: .leading, spacing: 0) {
            if recent.isEmpty {
                Text(NotesText.panelEmpty)
                    .font(TypeScale.secondary)
                    .foregroundStyle(t.fg2)
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, Space.xxs)
            } else {
                ForEach(recent) { note in
                    MenuBarActionRow(note.shownTitle, symbol: NotesLook.symbol(note, in: store),
                                     shortcut: NotesText.edited(note.updatedAt, now: store.now())) {
                        NotesMenuBar.clicked(note, close: close)
                    }
                    .help(NotesText.panelRowHelp)
                }
                Text(NotesText.panelHint)
                    .font(TypeScale.caption)
                    .foregroundStyle(t.fg3)
                    .padding(.horizontal, Space.xs)
                    .padding(.top, Space.xxs)
                    .padding(.bottom, Space.xxs)
            }
        }
    }
}
#endif
