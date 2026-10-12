import AppKit
import SwiftUI

/// Opens and focuses the main window. The window itself comes from `WindowHost` (one per id,
/// frame autosave that the closing window gives up so a reopen can claim it, views released on
/// close, activation policy through `AppForm`); this adds the main window's chrome: unified
/// toolbar, full-size content, hidden title, 900 x 600 minimum, full screen.
///
/// Reopen paths: Dock click (`applicationShouldHandleReopen`), Window menu ⌘0, `AppActions.openMainWindow()`.
enum MainWindowController {
    static let id = "main"

    static var isOpen: Bool { WindowHost.window(id) != nil }
    /// The main window is open and takes the keyboard (View menu items act on it only then).
    static var isKey: Bool { WindowHost.window(id)?.isKeyWindow == true }

    static func show() {
        WindowHost.show(id: id, style: .main, size: Metrics.Window.size, minSize: Metrics.Window.minSize,
                        title: { AppInfo.displayName }, configure: configure) {
            content()
        }
    }

    static func close() { WindowHost.close(id) }

    static func content(model: MainWindowModel = .shared) -> AnyView {
        AnyView(MainWindowView(model: model))
    }

    /// The chrome of a new main window (also used by the self-test on a window it builds itself).
    /// `WindowHost` holds the 900 x 600 minimum through the SwiftUI root.
    static func configure(_ window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.collectionBehavior.insert(.fullScreenPrimary)
    }
}
