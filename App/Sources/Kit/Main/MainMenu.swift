import AppKit

/// The app menu bar (shown while the app is `.regular`): app menu with About, Settings (⌘,),
/// module contributions (`Registry.menuItems`), Hide, Quit; Edit; Window. Titles follow the UI
/// language live.
enum MainMenu {
    private static var targets: [ClosureTarget] = []
    private static var tracking = false
    /// Modules that extend the standard menus (e.g. the window module adds File, View and Help).
    /// Each runs on every rebuild, after the kit menus are in place.
    static var decorators: [(NSMenu) -> Void] = []

    static func install() {
        rebuild()
        guard !tracking else { return }
        tracking = true
        Observing.track { _ = Localizer.shared.lang } onChange: { rebuild() }
    }

    static func rebuild() {
        targets.removeAll()
        let bar = NSMenu()

        let appMenu = NSMenu(title: AppInfo.displayName)
        appMenu.addItem(item(CommonText.aboutApp) { AppActions.showAbout() })
        appMenu.addItem(.separator())
        appMenu.addItem(item(CommonText.settingsMenu, key: ",") { AppActions.openSettings() })
        let contributions = Registry.orderedMenuItems
        if !contributions.isEmpty {
            appMenu.addItem(.separator())
            for c in contributions {
                let parsed = MenuShortcut.parse(c.shortcut)
                let entry = item(c.title(), key: parsed.key, modifiers: parsed.modifiers, action: c.action)
                if let symbol = c.symbol { entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
                appMenu.addItem(entry)
            }
        }
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: CommonText.hideApp, action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let others = NSMenuItem(title: CommonText.hideOthers, action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(others)
        appMenu.addItem(NSMenuItem(title: CommonText.showAll, action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: CommonText.quitApp, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        add(appMenu, to: bar)

        let edit = NSMenu(title: CommonText.edit)
        edit.addItem(NSMenuItem(title: CommonText.undo, action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: CommonText.redo, action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: CommonText.cut, action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: CommonText.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: CommonText.paste, action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: CommonText.selectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        add(edit, to: bar)

        let window = NSMenu(title: CommonText.window)
        window.addItem(NSMenuItem(title: CommonText.minimize, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        window.addItem(NSMenuItem(title: CommonText.zoom, action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        window.addItem(.separator())
        window.addItem(NSMenuItem(title: CommonText.close, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        add(window, to: bar)
        NSApp.windowsMenu = window

        for decorate in decorators { decorate(bar) }
        NSApp.mainMenu = bar
    }

    private static func add(_ menu: NSMenu, to bar: NSMenu) {
        let holder = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        holder.submenu = menu
        bar.addItem(holder)
    }

    private static func item(_ title: String, key: String = "", modifiers: NSEvent.ModifierFlags = .command,
                             action: @escaping () -> Void) -> NSMenuItem {
        let target = ClosureTarget(action)
        targets.append(target)
        let entry = NSMenuItem(title: title, action: #selector(ClosureTarget.fire(_:)), keyEquivalent: key)
        entry.keyEquivalentModifierMask = modifiers
        entry.target = target
        return entry
    }
}

/// Turns "⇧⌘K" into a key equivalent and modifier mask for NSMenuItem.
enum MenuShortcut {
    static func parse(_ text: String?) -> (key: String, modifiers: NSEvent.ModifierFlags) {
        guard let text, !text.isEmpty else { return ("", []) }
        var modifiers: NSEvent.ModifierFlags = []
        var key = ""
        for ch in text {
            switch ch {
            case "⌘": modifiers.insert(.command)
            case "⇧": modifiers.insert(.shift)
            case "⌥": modifiers.insert(.option)
            case "⌃": modifiers.insert(.control)
            default: key.append(ch)
            }
        }
        return (key.lowercased(), modifiers)
    }
}

/// Target object for closure-based menu items.
final class ClosureTarget: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func fire(_ sender: Any?) { action() }
}
