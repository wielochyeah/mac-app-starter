import AppKit

/// Owns the status item. Left click opens the panel; right click, ⌃-click or ⌥-click opens the
/// menu (`Registry.menuItems`, Open window, Settings…, Setup…, Quit). The icon, the optional status
/// text and the tooltip follow `MenuBarStatus.shared`, the menu bar settings and the UI language
/// live. Never installed headless or while rendering.
final class MenuBarController: NSObject, NSMenuDelegate {
    private(set) static var shared: MenuBarController?

    private var item: NSStatusItem?
    private let menu = NSMenu()
    private var menuTargets: [ClosureTarget] = []
    private let panel = MenuBarPanelController()
    private var timer: Timer?
    private var frame = 0
    private var appearance: NSKeyValueObservation?
    private var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    static func install() {
        guard shared == nil, !RenderMode.isHeadless, !RenderMode.isStatic else { return }
        let controller = MenuBarController()
        shared = controller
        controller.start()
    }

    static func uninstall() {
        shared?.stop()
        shared = nil
    }

    /// Opens the panel from code (e.g. a hotkey or a notification click).
    static func openPanel() {
        guard let controller = shared, let button = controller.item?.button else { return }
        if !controller.panel.isOpen { controller.panel.toggle(from: button) }
    }

    private func start() {
        menu.delegate = self
        menu.autoenablesItems = false
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        Observing.track({ [weak self] in
            self?.readInputs()
        }, while: { [weak self] in
            self != nil
        }, onChange: { [weak self] in
            self?.update()
        })
        update()
    }

    private func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        removeItem()
    }

    /// Everything the item shows depends on (read inside `Observing.track`).
    private func readInputs() {
        let status = MenuBarStatus.shared
        _ = status.state
        _ = status.message
        _ = status.shortTitle
        _ = Settings.shared[.menuBarIconStyle]
        _ = Settings.shared[.menuBarStatusText]
        _ = Settings.shared[.menuBarVisible]
        _ = Localizer.shared.lang
    }

    // MARK: Item

    private func update() {
        let visible = MenuBarPrefs.isVisible(setting: Settings.shared[.menuBarVisible], windowModule: AppInfo.isEnabled("window"))
        guard visible else {
            removeItem()
            return
        }
        let item = self.item ?? makeItem()
        guard let button = item.button else { return }
        let status = MenuBarStatus.shared
        let style = MenuBarIconStyle(setting: Settings.shared[.menuBarIconStyle])
        if MenuBarIcon.isAnimated(state: status.state, style: style, reduceMotion: reduceMotion) {
            startTimer()
        } else {
            stopTimer()
            frame = 0
        }
        button.image = MenuBarIcon.image(state: status.state, style: style, frame: frame, inks: inks(for: button))
        let title = MenuBarPrefs.title(state: status.state, short: status.shortTitle, showsText: Settings.shared[.menuBarStatusText])
        button.title = title
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        // one symbol sits in the square item, exactly where the plain symbol sits (VoiceBud)
        item.length = title.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength
        button.toolTip = MenuBarText.tooltip(status.line)
        button.setAccessibilityLabel(MenuBarText.tooltip(status.line))
    }

    private func makeItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // macOS remembers where the person dragged the item (⌘-drag)
        item.autosaveName = "\(AppInfo.bundleId).status"
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            // the menu bar turns light or dark with the wallpaper: drawn colours follow
            appearance = button.observe(\.effectiveAppearance) { [weak self] _, _ in
                DispatchQueue.main.async { self?.update() }
            }
        }
        self.item = item
        return item
    }

    private func removeItem() {
        stopTimer()
        panel.close()
        appearance = nil
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    /// Label ink of the menu bar's current appearance, the accent (its contrast-tested text
    /// colour: the fill is below 3:1 on a light menu bar) and the alert red (`strike`, the same red
    /// as the panel's status dot).
    private func inks(for button: NSStatusBarButton) -> MenuBarIcon.Inks {
        // design-ausnahme: the status item's ink follows the real menu bar (wallpaper decides), no Theme token knows it
        var label = NSColor.labelColor
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            // design-ausnahme: resolved for the menu bar's own appearance (VoiceBud MenuBarIcon)
            label = NSColor.labelColor.usingColorSpace(.sRGB) ?? .labelColor
        }
        let dark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return MenuBarIcon.Inks.themed(label: label, Theme(dark ? .dark : .light))
    }

    // MARK: Busy animation (only while busy in style "marks", never under Reduce Motion)

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: MenuBarIconMetrics.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // .common keeps it turning while the menu is open
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let button = item?.button else { return }
        frame = MenuBarIcon.nextFrame(frame)
        let style = MenuBarIconStyle(setting: Settings.shared[.menuBarIconStyle])
        button.image = MenuBarIcon.image(state: MenuBarStatus.shared.state, style: style, frame: frame, inks: inks(for: button))
    }

    @objc private func displayOptionsChanged() {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        update()
    }

    // MARK: Clicks

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if MenuBarClick.opensMenu(rightClick: event?.type == .rightMouseDown, modifiers: event?.modifierFlags ?? []) {
            showMenu()
        } else {
            panel.toggle(from: sender)
        }
    }

    private func showMenu() {
        panel.close()
        guard let item, let button = item.button else { return }
        rebuildMenu()
        item.menu = menu
        button.performClick(nil)   // tracks the menu until it closes
        item.menu = nil
    }

    /// Titles are set again each time the menu opens: the language can change in Settings and
    /// modules add items at launch (VoiceBud `menuNeedsUpdate`).
    func menuNeedsUpdate(_ menu: NSMenu) { rebuildMenu() }

    private func rebuildMenu() {
        menu.removeAllItems()
        menuTargets.removeAll()
        for entry in MenuBarMenu.entries(contributions: Registry.orderedMenuItems, windowModule: AppInfo.isEnabled("window")) {
            guard let entry else {
                menu.addItem(.separator())
                continue
            }
            let target = ClosureTarget(entry.action)
            menuTargets.append(target)
            let parsed = MenuShortcut.parse(entry.shortcut)
            let menuItem = NSMenuItem(title: entry.title, action: #selector(ClosureTarget.fire(_:)), keyEquivalent: parsed.key)
            menuItem.keyEquivalentModifierMask = parsed.modifiers
            menuItem.target = target
            if let symbol = entry.symbol { menuItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            menu.addItem(menuItem)
        }
    }
}

/// Which click opens the menu instead of the panel (pure, tested).
enum MenuBarClick {
    static func opensMenu(rightClick: Bool, modifiers: NSEvent.ModifierFlags) -> Bool {
        rightClick || modifiers.contains(.control) || modifiers.contains(.option)
    }
}

/// The status item's menu (pure list, tested; `nil` is a separator).
enum MenuBarMenu {
    struct Entry {
        let id: String
        let title: String
        let symbol: String?
        let shortcut: String?
        let action: () -> Void
    }

    static func entries(contributions: [MenuItemContribution], windowModule: Bool) -> [Entry?] {
        var out: [Entry?] = contributions.map {
            Entry(id: $0.id, title: $0.title(), symbol: $0.symbol, shortcut: $0.shortcut, action: $0.action)
        }
        if !out.isEmpty { out.append(nil) }
        if windowModule {
            out.append(Entry(id: "menubar.open-window", title: MenuBarText.openWindow, symbol: nil, shortcut: nil) {
                AppActions.openMainWindow()
            })
        }
        out.append(Entry(id: "menubar.settings", title: CommonText.settingsMenu, symbol: nil, shortcut: "⌘,") {
            AppActions.openSettings()
        })
        out.append(Entry(id: "menubar.setup", title: MenuBarText.setupMenu, symbol: nil, shortcut: nil) {
            AppActions.openOnboarding()
        })
        out.append(nil)
        out.append(Entry(id: "menubar.quit", title: CommonText.quitApp, symbol: nil, shortcut: "⌘Q") {
            AppActions.quit()
        })
        return out
    }
}
