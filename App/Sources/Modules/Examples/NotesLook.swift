import SwiftUI

/// Sizes and timings of the notes views, on top of Kit/Design and the window module's tokens.
enum NotesLook {
    /// Editor text area, and the narrowest editor beside the AI column.
    static let editorMinHeight: CGFloat = 260
    static let editorMinWidth: CGFloat = 400
    /// The AI column beside the editor.
    static let sideColumn: CGFloat = 340
    /// Result text under an AI row starts under the row's title (symbol 22 + gap 9 + row inset 12).
    static var resultInset: CGFloat { Space.rowX + Metrics.squircle + Space.iconGap }
    static var spinner: CGFloat { Metrics.spinner - Space.xxs }
    static let clearGlyph: CGFloat = 10
    /// Kit `Chip` does not dim when disabled; the kit buttons use 45 %.
    static let offOpacity = 0.45
    /// The Keyboard Shortcuts pane with one hotkey (render).
    static let hotkeyPaneHeight: CGFloat = 230
    /// Notes on the "Recently Edited" shelf and in the status menu panel.
    static let shelfCount = 10
    static let panelCount = 3
    /// The island grows into the capture activity before it turns into the done card.
    static let captureBeat: Duration = .milliseconds(450)

    /// A note's artwork glyph: its collection's symbol, else where it came from.
    static func symbol(_ note: NoteItem, in store: NotesStore) -> String {
        store.collection(note.collectionID)?.symbol ?? note.source.symbol
    }
}
