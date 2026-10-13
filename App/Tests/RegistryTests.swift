#if TESTING
import AppKit
import SwiftUI

final class RegistryTests: TestSuite {
    static func pane(_ id: String, _ group: SettingsGroup, _ order: Int) -> SettingsPane {
        SettingsPane(id: id, group: group, order: order, title: { id }, symbol: "gear", tint: .graphite) { AnyView(EmptyView()) }
    }

    static func page(_ id: String, _ s: PageSection, _ o: Int) -> AppPage {
        AppPage(id: id, section: s, order: o, title: { id }, symbol: "music.note") { AnyView(EmptyView()) }
    }

    static func step(_ id: String, _ o: Int, _ included: Bool) -> OnboardingStep {
        OnboardingStep(id: id, order: o, isIncluded: { included }) { _ in AnyView(EmptyView()) }
    }

    override class func register() {
        test("settings panes: group, then order, then id") {
            Registry.withScratch {
                Registry.settingsPanes = [pane("z", .settings, 0), pane("b", .content, 5), pane("a", .settings, 0), pane("c", .content, 1)]
                expectEqual(Registry.orderedSettingsPanes.map(\.id), ["c", "b", "a", "z"])
            }
        }

        test("pages: section, then order") {
            Registry.withScratch {
                Registry.pages = [page("lib", .library, 0), page("home", .main, 1), page("now", .main, 0), page("mix", .collections, 0)]
                expectEqual(Registry.orderedPages.map(\.id), ["now", "home", "lib", "mix"])
            }
        }

        test("onboarding steps: only included ones, by order") {
            Registry.withScratch {
                Registry.onboardingSteps = [step("done", 100, true), step("perm", 50, false), step("welcome", 0, true), step("lang", 10, true)]
                expectEqual(Registry.orderedOnboardingSteps.map(\.id), ["welcome", "lang", "done"])
            }
        }

        test("menu items and scenes are ordered") {
            Registry.withScratch {
                Registry.menuItems = [
                    MenuItemContribution(id: "b", order: 1, title: { "b" }, symbol: nil, shortcut: nil) {},
                    MenuItemContribution(id: "a", order: 1, title: { "a" }, symbol: nil, shortcut: "⇧⌘K") {},
                    MenuItemContribution(id: "c", order: 0, title: { "c" }, symbol: nil, shortcut: nil) {},
                ]
                expectEqual(Registry.orderedMenuItems.map(\.id), ["c", "a", "b"])
                Registry.renderScenes = [RenderScene(id: "x.b", size: .zero) { AnyView(EmptyView()) },
                                         RenderScene(id: "x.a", size: .zero) { AnyView(EmptyView()) }]
                expectEqual(Registry.orderedRenderScenes.map(\.id), ["x.a", "x.b"])
            }
        }

        test("problems finds duplicates and bad scene ids") {
            Registry.withScratch {
                Registry.settingsPanes = [pane("a", .settings, 0), pane("a", .content, 1)]
                Registry.renderScenes = [RenderScene(id: "noarea", size: .zero) { AnyView(EmptyView()) }]
                let problems = Registry.problems()
                expect(problems.contains("duplicate settings pane id a"), "\(problems)")
                expect(problems.contains { $0.contains("noarea") }, "\(problems)")
            }
        }

        test("withScratch restores contributions") {
            let before = Registry.renderScenes.count
            let art = Registry.welcomeArt != nil
            Registry.withScratch {
                Registry.renderScenes = []
                Registry.welcomeArt = art ? nil : { AnyView(EmptyView()) }
            }
            expectEqual(Registry.renderScenes.count, before)
            expectEqual(Registry.welcomeArt != nil, art)
            expect(before > 0)
        }

        test("the registered app has no problems") {
            expectEqual(Registry.problems(), [])
        }

        test("menu shortcut parsing") {
            let p = MenuShortcut.parse("⇧⌘K")
            expectEqual(p.key, "k")
            expectEqual(p.modifiers, [.command, .shift])
            expectEqual(MenuShortcut.parse(nil).key, "")
        }
    }
}

final class AppFormTests: TestSuite {
    override class func register() {
        test("activation policy rules") {
            expectEqual(AppForm.policy(windowModule: true, headless: false, openWindows: 0), .regular)
            expectEqual(AppForm.policy(windowModule: false, headless: false, openWindows: 0), .accessory)
            expectEqual(AppForm.policy(windowModule: false, headless: false, openWindows: 2), .regular)
            expectEqual(AppForm.policy(windowModule: true, headless: true, openWindows: 1), .prohibited)
            expectEqual(AppForm.policy(windowModule: false, headless: true, openWindows: 1), .prohibited)
        }

        test("launch flags") {
            let f = LaunchFlags.parse(["app", "--render", "/x/shots", "--only", "design.", "--lang", "de", "--appearance", "dark"])
            expectEqual(f.renderDir?.path, "/x/shots")
            expectEqual(f.only, "design.")
            expectEqual(f.lang, .de)
            expectEqual(f.appearance, .dark)
            expectEqual(f.errors, [])
            expect(LaunchFlags.parse(["app", "--selftest"]).selftest)
            expect(!LaunchFlags.parse(["app", "--lang", "fr", "--render", "/x"]).errors.isEmpty)
            expect(!LaunchFlags.parse(["app", "--only", "x"]).errors.isEmpty)
            expect(!LaunchFlags.parse(["app", "--render"]).errors.isEmpty)
            expectEqual(LaunchFlags.parse(["app", "-NSDocumentRevisionsDebugMode", "YES"]).errors, [])
            expectEqual(LaunchFlags.parse(["app", "-psn_0_12345", "-AppleLanguages", "(de)"]).errors, [])
        }

        test("launch flags: unknown double-dash flags are errors, --demo parses") {
            expectEqual(LaunchFlags.parse(["app", "--selftst"]).errors, ["unknown flag --selftst"])
            expect(!LaunchFlags.parse(["app", "--rendr", "build/shots"]).errors.isEmpty)
            let demo = LaunchFlags.parse(["app", "--demo"])
            expect(demo.demo && demo.errors.isEmpty && !demo.isTool)
            expect(!LaunchFlags.parse(["app", "--demo", "--selftest"]).errors.isEmpty)
        }

        test("tool runs are headless without STARTER_HEADLESS; normal launches and --demo follow it") {
            for args in [["app", "--render", "/x"], ["app", "--selftest"], ["app", "--permission-probe", "microphone"]] {
                let flags = LaunchFlags.parse(args)
                expect(flags.isTool, "\(args)")
                expect(RenderMode.headless(environment: [:], tool: flags.isTool), "\(args) headless")
            }
            expect(!RenderMode.headless(environment: [:], tool: LaunchFlags.parse(["app", "--demo"]).isTool), "the demo is a real launch")
            expect(!RenderMode.headless(environment: ["STARTER_HEADLESS": "0"], tool: false))
            expect(RenderMode.headless(environment: ["STARTER_HEADLESS": "1"], tool: false))
        }
    }
}
#endif
