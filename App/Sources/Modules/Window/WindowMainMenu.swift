import AppKit

/// The standard menus of a window app on top of the kit's (App, Edit, Window): File with Close,
/// Find in Edit, View with the sidebar and full screen, the main window in Window (⌘0), Help.
/// Installed as a `MainMenu` decorator, so it follows the UI language like the kit menus.
enum WindowMainMenu {
    private static var targets: [WindowMenuTarget] = []

    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        MainMenu.decorators.append { bar in decorate(bar) }
    }

    /// Adds File, View and Help and moves Close (⌘W) from Window to File. Idempotent per bar.
    static func decorate(_ bar: NSMenu) {
        guard bar.items.first(where: { $0.submenu?.identifier == Self.fileID }) == nil else { return }
        // a new bar: the targets of the old one go (menu items hold their target weakly)
        targets.removeAll()

        // Window: Close moves to File (one ⌘W), the main window gets ⌘0 like Music
        let windowMenu = bar.items.compactMap(\.submenu).first { menu in
            menu.items.contains { $0.action == #selector(NSWindow.performMiniaturize(_:)) }
        }
        if let windowMenu {
            if let close = windowMenu.items.firstIndex(where: { $0.action == #selector(NSWindow.performClose(_:)) }) {
                windowMenu.removeItem(at: close)
                if close > 0, close - 1 < windowMenu.items.count, windowMenu.items[close - 1].isSeparatorItem {
                    windowMenu.removeItem(at: close - 1)
                }
            }
            windowMenu.addItem(.separator())
            windowMenu.addItem(item(AppInfo.displayName, key: "0") { AppActions.openMainWindow() })
        }

        let file = NSMenu(title: WindowText.fileMenu)
        file.identifier = fileID
        file.addItem(NSMenuItem(title: CommonText.close, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        insert(file, in: bar, at: min(1, bar.items.count))

        let editIndex = bar.items.firstIndex { item in
            item.submenu?.items.contains { $0.action == #selector(NSText.selectAll(_:)) } ?? false
        }
        if let editIndex, let edit = bar.items[editIndex].submenu {
            edit.addItem(.separator())
            // only while the shown page has the toolbar search; opens the window if it is closed
            edit.addItem(item(WindowText.find, key: "f", isEnabled: { MainWindowModel.shared.hasSearch }) {
                AppActions.openMainWindow()
                MainWindowModel.shared.focusSearch()
            })
        }

        let view = NSMenu(title: WindowText.viewMenu)
        // only for the main window while it is key; the title says what a click does
        view.addItem(item(sidebarTitle(), key: "s", modifiers: [.command, .control],
                          isEnabled: { MainWindowController.isKey }, title: sidebarTitle) {
            MainWindowModel.shared.toggleSidebar()
        })
        view.addItem(.separator())
        let fullScreen = NSMenuItem(title: WindowText.enterFullScreen, action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        view.addItem(fullScreen)
        insert(view, in: bar, at: editIndex.map { $0 + 1 } ?? bar.items.count)

        let help = NSMenu(title: CommonText.help)
        help.addItem(item(WindowText.showSetup) { AppActions.openOnboarding() })
        insert(help, in: bar, at: bar.items.count)
        if NSApp != nil { NSApp.helpMenu = help }
    }

    static let fileID = NSUserInterfaceItemIdentifier("window.menu.file")

    private static func insert(_ menu: NSMenu, in bar: NSMenu, at index: Int) {
        let holder = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        holder.submenu = menu
        bar.insertItem(holder, at: index)
    }

    static func sidebarTitle() -> String {
        MainWindowModel.shared.columnVisibility == .detailOnly ? WindowText.showSidebar : WindowText.hideSidebar
    }

    private static func item(_ title: String, key: String = "", modifiers: NSEvent.ModifierFlags = .command,
                             isEnabled: (() -> Bool)? = nil, title dynamicTitle: (() -> String)? = nil,
                             action: @escaping () -> Void) -> NSMenuItem {
        let target = WindowMenuTarget(action: action, isEnabled: isEnabled, title: dynamicTitle)
        targets.append(target)
        let entry = NSMenuItem(title: title, action: #selector(WindowMenuTarget.fire(_:)), keyEquivalent: key)
        entry.keyEquivalentModifierMask = modifiers
        entry.target = target
        return entry
    }
}

/// Target of the window module's menu items: runs a closure and, through menu validation, can
/// disable the item or change its title right before the menu shows (and before a key equivalent
/// fires, so a disabled ⌘F does nothing).
final class WindowMenuTarget: NSObject, NSMenuItemValidation {
    private let action: () -> Void
    private let isEnabled: (() -> Bool)?
    private let title: (() -> String)?

    init(action: @escaping () -> Void, isEnabled: (() -> Bool)? = nil, title: (() -> String)? = nil) {
        self.action = action
        self.isEnabled = isEnabled
        self.title = title
    }

    @objc func fire(_ sender: Any?) {
        guard isEnabled?() ?? true else { return }
        action()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if let title { menuItem.title = title() }
        return isEnabled?() ?? true
    }
}
