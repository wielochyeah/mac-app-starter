import AppKit
import SwiftUI

/// The menu bar app form: a status item with the app's symbol and states, a SwiftUI panel on left
/// click, a menu on right click, and the settings pane "Menu Bar". Without the window module the
/// app is an accessory app (no Dock icon, `LSUIElement`); AppForm handles that.
///
/// Public API for features and other modules:
/// - `MenuBarStatus.shared.state = .busy | .attention | .idle`, `.message` for the status line
/// - `MenuBarPanel.sections.append(MenuBarSection(…))` for a tile in the panel
/// - `Registry.menuItems` items appear in the panel (Actions) and in the right-click menu
/// - `MenuBarController.openPanel()` opens the panel from code
enum MenuBarModule {
    static func register() {
        Registry.settingsPanes.append(SettingsPane(id: "menubar", group: .settings, order: 250, title: { MenuBarText.paneTitle },
                                                   symbol: "menubar.rectangle", tint: .indigo) { AnyView(MenuBarPane()) })
        Registry.launchHooks.append { MenuBarController.install() }
        Registry.terminateHooks.append { MenuBarController.uninstall() }
        Registry.selfTests.append(SelfTestCheck(id: "menubar.icon") { MenuBarSelfTest.icons() })
        MenuBarScenes.register()
    }
}

enum MenuBarSelfTest {
    /// Every state in every style draws something, at the symbol's size, as the right image kind.
    static func icons() -> String? {
        let inks = MenuBarIcon.Inks.themed(label: .black, Theme(.light))
        let plain = MenuBarIcon.symbol()
        for style in MenuBarIconStyle.allCases {
            for state in MenuBarState.allCases {
                let image = MenuBarIcon.image(state: state, style: style, frame: 3, inks: inks)
                if image.size != plain.size { return "\(style)/\(state): size \(image.size) differs from the symbol \(plain.size)" }
                if image.isTemplate != MenuBarIcon.isTemplate(state: state, style: style) { return "\(style)/\(state): wrong template flag" }
                if MenuBarIcon.inkedPixels(image) == 0 { return "\(style)/\(state): draws nothing" }
            }
        }
        return nil
    }
}

extension MenuBarIcon {
    /// The image drawn into a bitmap at `scale` (self-test and tests).
    static func bitmap(_ image: NSImage, scale: CGFloat = 2) -> NSBitmapImageRep? {
        let width = Int((image.size.width * scale).rounded(.up)), height = Int((image.size.height * scale).rounded(.up))
        guard width > 0, height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// Pixels with any opacity when drawn at 2x.
    static func inkedPixels(_ image: NSImage) -> Int {
        guard let rep = bitmap(image) else { return 0 }
        var count = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.02 { count += 1 }
        }
        return count
    }

    /// The highest opacity of the glyph when drawn at 2x, leaving out `excluding` (image
    /// coordinates, e.g. the dot): drawn glyphs must carry the ink's opacity once, like templates.
    static func glyphAlpha(_ image: NSImage, excluding: NSRect = .null) -> CGFloat {
        guard let rep = bitmap(image) else { return 0 }
        var high: CGFloat = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                let point = NSPoint(x: (CGFloat(x) + 0.5) / 2, y: (CGFloat(rep.pixelsHigh - 1 - y) + 0.5) / 2)
                if excluding.contains(point) { continue }
                high = max(high, rep.colorAt(x: x, y: y)?.alphaComponent ?? 0)
            }
        }
        return high
    }

    /// Opacity at a point (image coordinates, origin bottom left) when drawn at 2x.
    static func alpha(_ image: NSImage, at point: NSPoint) -> CGFloat {
        guard let rep = bitmap(image) else { return 0 }
        let x = min(max(Int(point.x * 2), 0), rep.pixelsWide - 1)
        let y = min(max(rep.pixelsHigh - 1 - Int(point.y * 2), 0), rep.pixelsHigh - 1)   // bitmap rows run top down
        return rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
    }
}
