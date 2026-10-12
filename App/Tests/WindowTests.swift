#if TESTING
#if MODUL_WINDOW
import AppKit
import SwiftUI

final class WindowTests: TestSuite {
    static func page(_ id: String, _ s: PageSection, _ o: Int) -> AppPage {
        AppPage(id: id, section: s, order: o, title: { id }, symbol: "music.note") { AnyView(EmptyView()) }
    }

    static func scratchSettings() -> Settings {
        Settings(fileURL: tempDir().appendingPathComponent("settings.json"))
    }

    override class func register() {
        // MARK: Sidebar and selection

        test("groups: sections in order, pages by order then id, empty sections left out") {
            let groups = MainWindowModel.groups([page("mix", .collections, 0), page("b", .main, 1), page("a", .main, 1), page("top", .main, 0)])
            expectEqual(groups.map(\.section), [.main, .collections])
            expectEqual(groups[0].pages.map(\.id), ["top", "a", "b"])
            expectEqual(groups[1].pages.map(\.id), ["mix"])
            expect(!groups[0].showsTitle && groups[1].showsTitle, "only the first section is untitled")
        }

        test("resolve: saved page if it still exists, else the first page") {
            let pages = [page("lib", .library, 0), page("home", .main, 0)]
            expectEqual(MainWindowModel.resolve(saved: "lib", in: pages), "lib")
            expectEqual(MainWindowModel.resolve(saved: "gone", in: pages), "home")
            expectEqual(MainWindowModel.resolve(saved: nil, in: pages), "home")
            expectEqual(MainWindowModel.resolve(saved: "x", in: []), nil)
        }

        test("model: selection persists, clears the search, survives a new model") {
            let settings = scratchSettings()
            let model = MainWindowModel(settings: settings)
            model.query = "garden"
            model.select("library")
            expectEqual(model.query, "")
            expectEqual(settings[.windowPage], "library")
            expectEqual(MainWindowModel(settings: Settings(fileURL: settings.fileURL)).selection, "library")
        }

        test("model: selecting nil or the same page changes nothing") {
            let settings = scratchSettings()
            let model = MainWindowModel(settings: settings)
            model.select(nil)
            expect(!FileManager.default.fileExists(atPath: settings.fileURL.path), "no write for nil")
            model.select("a")
            model.query = "q"
            model.select("a")
            expectEqual(model.query, "q")
        }

        test("model: sidebar visibility persists only on a real change") {
            let settings = scratchSettings()
            let model = MainWindowModel(settings: settings)
            expect(model.columnVisibility == .all)
            model.columnVisibility = .all
            expect(!FileManager.default.fileExists(atPath: settings.fileURL.path), "writing back the same value must not create the file")
            model.toggleSidebar()
            expect(settings[.windowSidebarHidden])
            expect(MainWindowModel(settings: Settings(fileURL: settings.fileURL)).columnVisibility == .detailOnly)
            model.toggleSidebar()
            expect(!settings[.windowSidebarHidden])
        }

        test("model: focus search only on a page with search") {
            let model = MainWindowModel(settings: scratchSettings())
            guard let id = model.currentPage?.id else { return fail("no page") }
            let had = WindowSearch.isEnabled(id)
            defer { if had { WindowSearch.enable(page: id) } else { WindowSearch.disable(page: id) } }
            WindowSearch.disable(page: id)
            model.focusSearch()
            expect(!model.hasSearch && !model.searchFocusPending, "no search, no focus request")
            WindowSearch.enable(page: id)
            model.focusSearch()
            expect(model.hasSearch && model.searchFocusPending)
        }

        // MARK: Search and footer registries

        test("search: only enabled pages, prompt per page") {
            WindowSearch.enable(page: "test.search") { "Find things" }
            defer { WindowSearch.disable(page: "test.search") }
            expect(WindowSearch.isEnabled("test.search"))
            expect(!WindowSearch.isEnabled("test.other"))
            expect(!WindowSearch.isEnabled(nil))
            expectEqual(WindowSearch.prompt("test.search"), "Find things")
        }

        test("sidebar footer: same id replaces, ordered by order then id") {
            WindowSidebarFooter.add(id: "test.b", order: 5) { AnyView(EmptyView()) }
            WindowSidebarFooter.add(id: "test.a", order: 5) { AnyView(EmptyView()) }
            WindowSidebarFooter.add(id: "test.b", order: -1) { AnyView(EmptyView()) }
            defer { WindowSidebarFooter.remove(id: "test.a"); WindowSidebarFooter.remove(id: "test.b") }
            let ids = WindowSidebarFooter.ordered.map(\.id).filter { $0.hasPrefix("test.") }
            expectEqual(ids, ["test.b", "test.a"])
        }

        // MARK: Artwork

        test("artwork: FNV-1a matches the reference values") {
            expectEqual(ArtworkRecipe.hash(""), 0xcbf2_9ce4_8422_2325)
            expectEqual(ArtworkRecipe.hash("a"), 0xaf63_dc4c_8601_ec8c)
        }

        test("artwork: same seed same recipe, different seeds differ") {
            expect(ArtworkRecipe(seed: "hikes") == ArtworkRecipe(seed: "hikes"))
            let recipes = (0..<50).map { ArtworkRecipe(seed: "seed-\($0)") }
            expectEqual(Set(recipes.map(\.hueShift)).count, 50)
        }

        test("artwork: recipe values stay in their ranges") {
            for i in 0..<500 {
                let r = ArtworkRecipe(seed: "s\(i)")
                expect((-60...60).contains(r.hueShift), "hue \(r.hueShift)")
                expect((20...70).contains(abs(r.lightShift)), "light shift \(r.lightShift)")
                expect((0.9...1.15).contains(r.saturation))
                expect((0...1).contains(r.light.x) && (0...1).contains(r.light.y))
                expect((0...1).contains(r.start.x) && (0...1).contains(r.end.y))
            }
        }

        test("artwork: HSB round trip and hue rotation") {
            let violet = ArtworkRGB(hex: 0x8F6CF2)
            let back = violet.rotated(0)
            expect(abs(back.r - violet.r) < 1e-9 && abs(back.g - violet.g) < 1e-9 && abs(back.b - violet.b) < 1e-9)
            let red = ArtworkRGB(hex: 0xFF0000)
            let green = red.rotated(120)
            expect(abs(green.g - 1) < 1e-9 && green.r < 1e-9 && green.b < 1e-9, "\(green)")
            let gray = ArtworkRGB(hex: 0x6E6E73).rotated(90, saturation: 0)
            expect(abs(gray.r - gray.g) < 1e-9 && abs(gray.g - gray.b) < 1e-9, "no saturation is grey")
            let dark = ArtworkRGB(hex: 0xFFFFFF).rotated(0, brightness: 0.5)
            expect(abs(dark.r - 0.5) < 1e-9)
        }

        test("artwork: colours stay in the accent's family and in range") {
            for accent in AccentName.allCases {
                let palette = AccentPalette.of(accent)
                for i in 0..<100 {
                    let c = ArtworkRecipe(seed: "c\(i)").colors(palette)
                    for rgb in [c.top, c.bottom, c.light, c.shade] {
                        expect([rgb.r, rgb.g, rgb.b].allSatisfy { (0...1).contains($0) }, "\(accent) \(rgb)")
                    }
                    expect(c.shade.hsb.b < c.bottom.hsb.b + 1e-9, "shade is darker")
                }
            }
        }

        // MARK: Samples

        test("sample search: outdoor matches three, kayak none, empty shows all") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            for lang in Lang.allCases {
                Localizer.shared.forced = lang
                expectEqual(WindowSamples.matching(WindowSampleText.query).map(\.id), ["hikes", "garden", "photos"])
                expect(WindowSamples.matching(WindowSampleText.queryNone).isEmpty)
                expectEqual(WindowSamples.matching("  ").count, WindowSamples.collections.count)
            }
        }

        test("plural texts") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            Localizer.shared.forced = .de
            expectEqual(WindowSampleText.entries(1), "1 Eintrag")
            expectEqual(WindowSampleText.entries(12), "12 Einträge")
            Localizer.shared.forced = .en
            expectEqual(WindowSampleText.entries(1), "1 entry")
            expectEqual(WindowSampleText.results(3, "x"), "3 results for “x”")
        }

        // MARK: Menus

        test("menus: File, Edit, View, Window, Help in order, one ⌘W, idempotent") {
            MainMenu.rebuild()
            guard let bar = NSApp.mainMenu else { return fail("no main menu") }
            WindowMainMenu.decorate(bar)   // a second pass must not add menus again
            let titles = bar.items.map(\.title)
            expectEqual(titles.count, 6, "\(titles)")
            expectEqual(Array(titles.dropFirst()), [WindowText.fileMenu, CommonText.edit, WindowText.viewMenu, CommonText.window, CommonText.help])
            let all = bar.items.compactMap(\.submenu).flatMap(\.items)
            let closeKeys = all.filter { $0.keyEquivalent == "w" && $0.keyEquivalentModifierMask == .command }
            expectEqual(closeKeys.count, 1)
            expect(all.contains { $0.keyEquivalent == "s" && $0.keyEquivalentModifierMask == [.command, .control] }, "⌃⌘S")
            expect(all.contains { $0.action == #selector(NSWindow.toggleFullScreen(_:)) }, "full screen")
            expect(all.contains { $0.keyEquivalent == "f" && $0.keyEquivalentModifierMask == .command }, "⌘F")
            expect(all.contains { $0.keyEquivalent == "0" }, "⌘0 main window")
            expect(NSApp.helpMenu === bar.items.last?.submenu)
            // the second pass must not free the targets of the first (menu items hold them weakly)
            let closureItems = all.filter { $0.action == #selector(WindowMenuTarget.fire(_:)) }
            expect(closureItems.allSatisfy { $0.target != nil }, "every closure item keeps its target")
            expectEqual(closureItems.filter { $0.target is WindowMenuTarget }.count, 4, "Find, sidebar, main window, setup")
        }

        test("menus: Find only with search, sidebar only for the key main window, title follows the state") {
            MainMenu.rebuild()
            guard let bar = NSApp.mainMenu else { return fail("no main menu") }
            let all = bar.items.compactMap(\.submenu).flatMap(\.items)
            @MainActor func validate(_ item: NSMenuItem?) -> Bool {
                guard let item, let target = item.target as? WindowMenuTarget else { return false }
                return target.validateMenuItem(item)
            }
            let find = all.first { $0.keyEquivalent == "f" && $0.keyEquivalentModifierMask == .command }
            let sidebar = all.first { $0.keyEquivalent == "s" && $0.keyEquivalentModifierMask == [.command, .control] }
            guard let id = MainWindowModel.shared.currentPage?.id else { return fail("no page") }
            let had = WindowSearch.isEnabled(id)
            defer { if had { WindowSearch.enable(page: id) } else { WindowSearch.disable(page: id) } }
            WindowSearch.disable(page: id)
            expect(!validate(find), "Find disabled without search")
            WindowSearch.enable(page: id)
            expect(validate(find), "Find enabled with search")
            expect(!MainWindowController.isOpen && !validate(sidebar), "sidebar item disabled without the main window")
            let hidden = MainWindowModel.shared.columnVisibility == .detailOnly
            expectEqual(sidebar?.title, hidden ? WindowText.showSidebar : WindowText.hideSidebar)
        }

        test("menus follow the language") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved; MainMenu.rebuild() }
            Localizer.shared.forced = .de
            MainMenu.rebuild()
            expect(NSApp.mainMenu?.items.map(\.title).contains("Darstellung") == true)
            expect(NSApp.mainMenu?.items.map(\.title).contains("Ablage") == true)
        }

        // MARK: Registration and renders

        test("registration: home page, handler, scenes and gallery entries") {
            expect(Registry.pages.contains { $0.id == HomePage.id && $0.section == .main && $0.order == 0 })
            expect(AppActions.mainWindowHandler != nil)
            let scenes = Set(Registry.renderScenes.map(\.id))
            let gallery = Set(Registry.gallery.map(\.id))
            for name in WindowCatalog.names {
                expect(scenes.contains("window.\(name)"), "scene window.\(name)")
                expect(gallery.contains("window.\(name)"), "gallery window.\(name)")
            }
            for required in ["main", "home", "page-scaffold", "hero-header", "shelf", "tile", "tile-grid", "item-list",
                             "detail-header", "artwork", "empty-page"] {
                expect(WindowCatalog.names.contains(required), required)
            }
        }

        test("every SF Symbol the module draws exists") {
            let missing = WindowCatalog.symbols.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil }
            expect(missing.isEmpty, "\(missing)")
        }

        test("every window scene renders in both appearances") {
            for scene in Registry.orderedRenderScenes where scene.id.hasPrefix("window.") {
                for appearance in Appearance.allCases {
                    let png = RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: .de)
                    expect((png?.count ?? 0) > 2000, "\(scene.id) \(appearance)")
                }
            }
        }

        test("window.main is the size of the window on the desk") {
            guard let scene = Registry.renderScenes.first(where: { $0.id == "window.main" }),
                  let png = RenderRunner.png(scene.content(), size: scene.size, appearance: .light, lang: .en),
                  let image = NSBitmapImageRep(data: png) else { return fail("no render") }
            let expected = (Metrics.Window.size.width + 2 * Metrics.deskPadding) * 2
            expectEqual(CGFloat(image.pixelsWide), expected)
        }

        test("the live window builds offscreen with its chrome") {
            expectEqual(WindowCatalog.checkLiveWindow(), nil)
        }
    }
}
#endif
#endif
