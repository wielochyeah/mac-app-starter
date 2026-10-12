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

        test("start page: steps aside for a page at the first place, stays otherwise") {
            let home = HomePage.page
            expectEqual(MainWindowModel.visible([home, page("start", .main, 0)]).map(\.id), ["start"])
            expectEqual(MainWindowModel.visible([home, page("first", .main, -1)]).map(\.id), ["first"])
            expectEqual(MainWindowModel.visible([home, page("lib", .library, 0)]).map(\.id), ["home", "lib"])
            expectEqual(MainWindowModel.visible([home, page("later", .main, 5)]).map(\.id), ["home", "later"])
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
                expect((-25...25).contains(r.hueShift), "hue \(r.hueShift)")
                expect((10...30).contains(abs(r.lightShift)), "light shift \(r.lightShift)")
                expect((-35...35).contains(r.lightHue), "light hue \(r.lightHue)")
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

        test("artwork: every accent keeps its hue family and white glyphs at 3:1 or more") {
            func hueDistance(_ a: ArtworkRGB, _ b: ArtworkRGB) -> Double {
                let d = abs(a.hsb.h - b.hsb.h) * 360
                return min(d, 360 - d)
            }
            let white = ArtworkRGB(hex: 0xFFFFFF)
            for accent in AccentName.allCases {
                let palette = AccentPalette.of(accent)
                let brand = ArtworkRGB(hex: palette.brand), top = ArtworkRGB(hex: palette.gradientTop)
                for i in 0..<300 {
                    let c = ArtworkRecipe(seed: "family-\(i)").colors(palette)
                    for rgb in [c.top, c.bottom, c.light] {
                        expect(white.contrast(rgb) >= 3, "\(accent) seed \(i): white on \(rgb) is \(white.contrast(rgb))")
                    }
                    guard accent != .graphit else { continue }   // grey has no hue to keep
                    expect(hueDistance(c.bottom, brand) <= 25.01, "\(accent) bottom hue")
                    expect(hueDistance(c.top, top) <= 25.01, "\(accent) top hue")
                    expect(hueDistance(c.light, top) <= 35.01, "\(accent) light hue")
                }
            }
        }

        test("artwork: capping the luminance keeps the hue and only darkens") {
            let yellow = ArtworkRGB(hex: 0xF6D74D)
            let capped = yellow.capped(luminance: ArtworkRecipe.maxLuminance)
            expect(capped.luminance <= ArtworkRecipe.maxLuminance + 1e-6 && capped.luminance > ArtworkRecipe.maxLuminance - 0.01)
            expect(abs(capped.hsb.h - yellow.hsb.h) < 1e-6 && abs(capped.hsb.s - yellow.hsb.s) < 1e-6)
            let dark = ArtworkRGB(hex: 0x303040)
            expect(dark.capped(luminance: 0.28) == dark, "dark colours stay as they are")
        }

        test("hero: white text keeps 4.5:1 across the text column for every accent") {
            let size = CGSize(width: 820, height: Metrics.Window.heroHeight)
            for accent in AccentName.allCases {
                for seed in ["hero-hikes", "hero-a", "hero-b", "hero-c"] {
                    let view = AnyView(HeroBackdrop(seed: seed, symbol: "figure.hiking").environment(\.artworkAccent, accent))
                    guard let png = RenderRunner.png(view, size: size, appearance: .dark, lang: .en),
                          let image = NSBitmapImageRep(data: png) else { return fail("no render") }
                    let scale = CGFloat(image.pixelsWide) / size.width
                    var worst = 21.0
                    for x in stride(from: Space.l, through: Space.l + Metrics.Window.heroTextWidth, by: 10) {
                        for y in stride(from: Space.l, through: size.height - Space.l, by: 10) {
                            guard let c = image.colorAt(x: Int(x * scale), y: Int(y * scale))?.usingColorSpace(.sRGB) else { continue }
                            let rgb = ArtworkRGB(r: c.redComponent, g: c.greenComponent, b: c.blueComponent)
                            worst = min(worst, ArtworkRGB(hex: 0xFFFFFF).contrast(rgb))
                        }
                    }
                    expect(worst >= 4.5, "\(accent) \(seed): \(worst)")
                }
            }
        }

        test("hero: the glyph shows only beside the text column") {
            expect(HeroBackdrop.showsGlyph(width: 820, height: Metrics.Window.heroHeight))
            expect(!HeroBackdrop.showsGlyph(width: 600, height: Metrics.Window.heroHeight), "minimum window: no glyph under the title")
        }

        test("list: a hovered row stands apart from a striped one in both schemes") {
            // stripe = rowHover (black 3.5 % / white 5 %), hover = listHover, both over the window
            let light = Contrast.ratio(Contrast.over(0x000000, 0.035, ThemeHex.windowBgLight),
                                       Contrast.over(0x000000, Theme.listHoverLight, ThemeHex.windowBgLight))
            let dark = Contrast.ratio(Contrast.over(0xFFFFFF, 0.05, ThemeHex.windowBgDark),
                                      Contrast.over(0xFFFFFF, Theme.listHoverDark, ThemeHex.windowBgDark))
            expect(light >= 1.1, "light \(light)")
            expect(dark >= 1.1, "dark \(dark)")
        }

        test("texts: tile lines and sidebar titles fit without truncation in both languages") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            @MainActor func width(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight = .regular) -> CGFloat {
                (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
            }
            for lang in Lang.allCases {
                Localizer.shared.forced = lang
                for block in BuildingBlock.all {   // start page shelf: 168 pt tiles, 12 pt subtitle
                    expect(width(block.detail(), 12) <= Metrics.Window.tile, "\(lang) \(block.detail()) \(width(block.detail(), 12))")
                }
                for c in WindowSamples.collections {   // grid tiles can shrink to 150 pt; 13 pt medium title
                    expect(width(c.name(), 13, .medium) <= Metrics.Window.tileMin, "\(lang) \(c.name())")
                }
                // sidebar title column: ideal width minus panel insets, symbol column and gap
                let titleColumn = Metrics.Window.sidebarIdeal - 2 * Metrics.Window.sidebarContentInset
                    - Metrics.Window.sidebarSymbolColumn - Space.xs
                for p in WindowSamples.sidebarPages {
                    expect(width(p.title(), 13) <= titleColumn, "\(lang) \(p.title())")
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
                             "detail-header", "artwork", "empty-page", "no-pages", "search-empty"] {
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
