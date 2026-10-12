#if TESTING
#if MODUL_MENUBAR
import AppKit
import SwiftUI

final class MenuBarTests: TestSuite {
    static let inks = MenuBarIcon.Inks(label: .black, accent: .systemPurple, alert: NSColor(srgbRed: 1, green: 0.23, blue: 0.19, alpha: 1))

    static func withLang(_ lang: Lang, _ body: () -> Void) {
        let saved = Localizer.shared.forced
        Localizer.shared.forced = lang
        defer { Localizer.shared.forced = saved }
        body()
    }

    override class func register() {
        // MARK: State and settings

        test("icon style setting falls back to marks") {
            expectEqual(MenuBarIconStyle(setting: "plain"), .plain)
            expectEqual(MenuBarIconStyle(setting: "color"), .color)
            expectEqual(MenuBarIconStyle(setting: "marks"), .marks)
            expectEqual(MenuBarIconStyle(setting: "sparkly"), .marks)
            expectEqual(MenuBarIconStyle(setting: ""), .marks)
            expectEqual(SettingKey<String>.menuBarIconStyle.defaultValue, "marks")
        }

        test("status: idle clears the message, line falls back to the state's words") {
            let status = MenuBarStatus()
            expectEqual(status.line, MenuBarText.statusLine(.idle))
            status.state = .busy
            status.message = "Importing"
            expectEqual(status.line, "Importing")
            status.state = .attention
            expectEqual(status.message, "Importing", "attention keeps the message")
            status.state = .idle
            expectEqual(status.message, nil)
            expectEqual(status.line, MenuBarText.statusLine(.idle))
        }

        test("status words exist in both languages and differ per state") {
            for lang in Lang.allCases {
                withLang(lang) {
                    let lines = MenuBarState.allCases.map(MenuBarText.statusLine)
                    expectEqual(Set(lines).count, 3, "\(lang)")
                    expect(lines.allSatisfy { !$0.isEmpty })
                }
            }
            withLang(.de) { expectEqual(MenuBarText.statusLine(.busy), "Arbeitet …") }
            withLang(.en) { expectEqual(MenuBarText.statusLine(.busy), "Working…") }
        }

        test("visibility: the item can only be hidden when the window module keeps the app reachable") {
            expect(MenuBarPrefs.isVisible(setting: true, windowModule: true))
            expect(!MenuBarPrefs.isVisible(setting: false, windowModule: true))
            expect(MenuBarPrefs.isVisible(setting: false, windowModule: false))
            expect(MenuBarPrefs.isVisible(setting: true, windowModule: false))
        }

        test("status text shows only with the setting on and only while not idle") {
            expectEqual(MenuBarPrefs.title(state: .busy, line: "Sync", showsText: true), "Sync")
            expectEqual(MenuBarPrefs.title(state: .attention, line: "Look", showsText: true), "Look")
            expectEqual(MenuBarPrefs.title(state: .idle, line: "Ready", showsText: true), "")
            expectEqual(MenuBarPrefs.title(state: .busy, line: "Sync", showsText: false), "")
        }

        // MARK: Icon rules and geometry

        test("template images where macOS may tint, drawn colours otherwise") {
            for state in MenuBarState.allCases { expect(MenuBarIcon.isTemplate(state: state, style: .plain), "plain \(state)") }
            for style in MenuBarIconStyle.allCases { expect(MenuBarIcon.isTemplate(state: .idle, style: style), "idle \(style)") }
            expect(MenuBarIcon.isTemplate(state: .busy, style: .marks))
            expect(!MenuBarIcon.isTemplate(state: .attention, style: .marks))
            expect(!MenuBarIcon.isTemplate(state: .busy, style: .color))
            expect(!MenuBarIcon.isTemplate(state: .attention, style: .color))
        }

        test("only the busy ring animates, never under Reduce Motion") {
            for style in MenuBarIconStyle.allCases {
                for state in MenuBarState.allCases {
                    let animated = MenuBarIcon.isAnimated(state: state, style: style, reduceMotion: false)
                    expectEqual(animated, state == .busy && style == .marks, "\(style) \(state)")
                    expect(!MenuBarIcon.isAnimated(state: state, style: style, reduceMotion: true))
                }
            }
        }

        test("ring frames wrap and the arc turns clockwise one step per frame") {
            let n = MenuBarIconMetrics.frames
            expectEqual(MenuBarIcon.nextFrame(0), 1)
            expectEqual(MenuBarIcon.nextFrame(n - 1), 0)
            var frame = 0
            for _ in 0..<n { frame = MenuBarIcon.nextFrame(frame) }
            expectEqual(frame, 0, "a full turn returns to the start")
            let a0 = MenuBarIcon.arc(frame: 0), a1 = MenuBarIcon.arc(frame: 1)
            expectEqual(a0.start, 90)
            expectEqual(a0.start - a0.end, MenuBarIconMetrics.ringSweep)
            expectEqual(a0.start - a1.start, 360 / CGFloat(n))
            expectEqual(MenuBarIcon.arc(frame: n).start, a0.start)
        }

        test("marks sit inside the symbol's bounds on the half-point grid") {
            for size in [NSSize(width: 16, height: 15), NSSize(width: 17.3, height: 15.6), NSSize(width: 21.25, height: 13.5)] {
                for rect in [MenuBarIcon.dotRect(in: size), MenuBarIcon.ringRect(in: size)] {
                    expect(rect.minX >= -0.25 && rect.maxX <= size.width + 0.25, "\(rect) in \(size)")
                    expect(rect.minY >= 0 && rect.maxY <= size.height + 0.25, "\(rect) in \(size)")
                    expectEqual((rect.minX * 2).rounded(), rect.minX * 2, "x on the grid \(rect)")
                    expectEqual((rect.minY * 2).rounded(), rect.minY * 2, "y on the grid \(rect)")
                }
                expect(MenuBarIcon.dotRect(in: size).minY > MenuBarIcon.ringRect(in: size).maxY - 0.5, "dot above the ring")
            }
        }

        // MARK: Drawing

        test("every image keeps the symbol's size and alignment, and draws") {
            let plain = MenuBarIcon.symbol()
            expect(plain.size.width > 8 && plain.size.height > 8, "symbol size \(plain.size)")
            for style in MenuBarIconStyle.allCases {
                for state in MenuBarState.allCases {
                    let image = MenuBarIcon.image(state: state, style: style, frame: 2, inks: inks)
                    expectEqual(image.size, plain.size, "\(style) \(state)")
                    expectEqual(image.alignmentRect, plain.alignmentRect, "\(style) \(state)")
                    expectEqual(image.isTemplate, MenuBarIcon.isTemplate(state: state, style: style), "\(style) \(state)")
                    expect(MenuBarIcon.inkedPixels(image) > 20, "\(style) \(state) draws")
                }
            }
            expectEqual(MenuBarSelfTest.icons(), nil)
        }

        test("the busy ring turns: the arc covers 12 o'clock at frame 0, not half a turn later") {
            let symbol = MenuBarIcon.symbol()
            let ring = MenuBarIcon.ringRect(in: symbol.size)
            let top = NSPoint(x: ring.midX, y: ring.maxY - MenuBarIconMetrics.ringLine / 2)
            let start = MenuBarIcon.ringed(symbol, frame: 0)
            let half = MenuBarIcon.ringed(symbol, frame: MenuBarIconMetrics.frames / 2)
            expect(MenuBarIcon.alpha(start, at: top) > 0.8, "arc at 12 o'clock: \(MenuBarIcon.alpha(start, at: top))")
            let track = MenuBarIcon.alpha(half, at: top)
            expect(track > 0.1 && track < 0.5, "only the track at 12 o'clock half a turn later: \(track)")
            let center = NSPoint(x: ring.midX, y: ring.midY)
            expect(MenuBarIcon.alpha(start, at: center) < 0.05, "the ring is hollow (knocked out)")
        }

        test("the attention dot is drawn in the alert colour at the top right") {
            let symbol = MenuBarIcon.symbol()
            let image = MenuBarIcon.image(state: .attention, style: .marks, inks: inks)
            let dot = MenuBarIcon.dotRect(in: symbol.size)
            guard let rep = MenuBarIcon.bitmap(image) else { return fail("no bitmap") }
            let x = Int(dot.midX * 2), y = rep.pixelsHigh - 1 - Int(dot.midY * 2)
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return fail("no pixel") }
            expect(color.alphaComponent > 0.9, "dot opaque")
            expect(color.redComponent > 0.8 && color.greenComponent < 0.4, "dot red: \(color)")
        }

        test("enlarged images keep the template flag and scale") {
            let image = MenuBarIcon.image(state: .busy, style: .marks, inks: inks)
            let big = MenuBarIcon.enlarged(image, by: 4)
            expectEqual(big.size, NSSize(width: image.size.width * 4, height: image.size.height * 4))
            expect(big.isTemplate)
            expect(!MenuBarIcon.enlarged(MenuBarIcon.image(state: .attention, style: .marks, inks: inks), by: 2).isTemplate)
        }

        // MARK: Clicks, menu, panel

        test("right click, control-click and option-click open the menu, a plain click the panel") {
            expect(MenuBarClick.opensMenu(rightClick: true, modifiers: []))
            expect(MenuBarClick.opensMenu(rightClick: false, modifiers: .control))
            expect(MenuBarClick.opensMenu(rightClick: false, modifiers: .option))
            expect(!MenuBarClick.opensMenu(rightClick: false, modifiers: []))
            expect(!MenuBarClick.opensMenu(rightClick: false, modifiers: .command))
        }

        test("menu: contributions first, then window, settings, setup, quit") {
            let items = [
                MenuItemContribution(id: "b", order: 1, title: { "B" }, symbol: "star", shortcut: "⇧⌘B") {},
                MenuItemContribution(id: "a", order: 0, title: { "A" }, symbol: nil, shortcut: nil) {},
            ]
            let ids = MenuBarMenu.entries(contributions: items, windowModule: true).map { $0?.id ?? "-" }
            expectEqual(ids, ["b", "a", "-", "menubar.open-window", "menubar.settings", "menubar.setup", "-", "menubar.quit"])
            let noWindow = MenuBarMenu.entries(contributions: [], windowModule: false).map { $0?.id ?? "-" }
            expectEqual(noWindow, ["menubar.settings", "menubar.setup", "-", "menubar.quit"])
            let settings = MenuBarMenu.entries(contributions: [], windowModule: false).compactMap { $0 }.first { $0.id == "menubar.settings" }
            expectEqual(settings?.shortcut, "⌘,")
            expectEqual(MenuShortcut.parse(settings?.shortcut).key, ",")
        }

        test("menu titles follow the UI language") {
            withLang(.de) {
                let titles = MenuBarMenu.entries(contributions: [], windowModule: true).compactMap { $0?.title }
                expect(titles.contains(CommonText.settingsMenu))
                expect(titles.contains("Einrichtung …"), "\(titles)")
            }
        }

        test("panel sections are ordered by order, then id") {
            let saved = MenuBarPanel.sections
            defer { MenuBarPanel.sections = saved }
            MenuBarPanel.sections = [
                MenuBarSection(id: "z", order: 5) { _ in AnyView(EmptyView()) },
                MenuBarSection(id: "b", order: 1) { _ in AnyView(EmptyView()) },
                MenuBarSection(id: "a", order: 1, tiled: false) { _ in AnyView(EmptyView()) },
            ]
            expectEqual(MenuBarPanel.orderedSections.map(\.id), ["a", "b", "z"])
            expect(!MenuBarPanel.orderedSections[0].tiled)
        }

        test("panel placement: centred under the item, inside the screen, below the menu bar") {
            let visible = NSRect(x: 0, y: 0, width: 1512, height: 949)   // menu bar above y 949
            let size = NSSize(width: 340, height: 300)
            let middle = MenuBarPanelPlacement.frame(below: NSRect(x: 700, y: 949, width: 32, height: 33), size: size, visible: visible)
            expectEqual(middle.midX, 716)
            expectEqual(middle.maxY, 949 - Space.xxs)
            expectEqual(middle.size, size)
            let right = MenuBarPanelPlacement.frame(below: NSRect(x: 1400, y: 949, width: 32, height: 33), size: size, visible: visible)
            expectEqual(right.maxX, 1512 - Space.xs, "kept inside the right edge")
            let left = MenuBarPanelPlacement.frame(below: NSRect(x: 10, y: 949, width: 32, height: 33), size: size, visible: visible)
            expectEqual(left.minX, Space.xs, "kept inside the left edge")
            let grown = MenuBarPanelPlacement.resized(middle, height: 420)
            expectEqual(grown.maxY, middle.maxY, "top edge stays")
            expectEqual(grown.height, 420)
        }

        // MARK: Registration and scenes

        test("register adds the pane, hooks, self-test and scenes") {
            Registry.withScratch {
                MenuBarModule.register()
                expectEqual(Registry.settingsPanes.map(\.id), ["menubar"])
                expectEqual(Registry.settingsPanes.first?.group, .settings)
                expectEqual(Registry.launchHooks.count, 1)
                expectEqual(Registry.terminateHooks.count, 1)
                expectEqual(Registry.selfTests.map(\.id), ["menubar.icon"])
                expectEqual(Registry.renderScenes.map(\.id).sorted(), MenuBarScenes.ids.sorted())
                expectEqual(Registry.problems(), [])
            }
        }

        test("the launch hook installs nothing headless") {
            MenuBarController.install()
            expect(MenuBarController.shared == nil, "no status item in tests")
        }

        test("every menubar scene renders in both appearances") {
            for scene in Registry.orderedRenderScenes where scene.id.hasPrefix("menubar.") {
                for appearance in Appearance.allCases {
                    guard let png = RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: .de),
                          let rep = NSBitmapImageRep(data: png) else { fail("\(scene.id) \(appearance): no image"); continue }
                    expect(rep.pixelsWide > 200 && rep.pixelsHigh > 100, "\(scene.id) \(rep.pixelsWide)x\(rep.pixelsHigh)")
                    let alpha = rep.colorAt(x: 0, y: 0)?.alphaComponent ?? 0
                    expect(alpha > 0.99, "\(scene.id) \(appearance): opaque corner")
                }
            }
        }
    }
}
#endif
#endif
