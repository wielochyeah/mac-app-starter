#if TESTING
import AppKit
import SwiftUI

final class SettingsHubTests: TestSuite {
    static func pane(_ id: String, _ group: SettingsGroup, _ order: Int = 0) -> SettingsPane {
        SettingsPane(id: id, group: group, order: order, title: { id }, symbol: "gear", tint: .graphite) { AnyView(EmptyView()) }
    }

    override class func register() {
        test("deep link resolution") {
            let ids = ["gallery", "general", "island", "about"]
            expectEqual(SettingsHub.resolve("island", current: "general", available: ids), "island")
            expectEqual(SettingsHub.resolve("nope", current: "about", available: ids), "about", "unknown id keeps the current pane")
            expectEqual(SettingsHub.resolve(nil, current: "about", available: ids), "about")
            expectEqual(SettingsHub.resolve(nil, current: "removed", available: ids), "general", "a pane that is gone falls back to General")
            expectEqual(SettingsHub.resolve(nil, current: nil, available: ["x", "y"]), "x")
            expectEqual(SettingsHub.resolve("x", current: nil, available: []), nil)
        }

        test("arrow keys step through panes and stop at the ends") {
            let ids = ["a", "b", "c"]
            expectEqual(SettingsHub.step(from: "a", by: 1, in: ids), "b")
            expectEqual(SettingsHub.step(from: "c", by: 1, in: ids), "c")
            expectEqual(SettingsHub.step(from: "a", by: -1, in: ids), "a")
            expectEqual(SettingsHub.step(from: "b", by: 5, in: ids), "c")
            expectEqual(SettingsHub.step(from: "gone", by: 1, in: ids), "a")
        }

        test("sidebar groups: content first, empty groups left out, label only below content") {
            let panes = [pane("general", .settings, 0), pane("history", .content, 0), pane("about", .settings, 1000)]
            let ordered = panes.sorted { ($0.group, $0.order, $0.id) < ($1.group, $1.order, $1.id) }
            let groups = SettingsHub.groups(ordered)
            expectEqual(groups.map(\.group), [.content, .settings])
            expectEqual(groups[1].panes.map(\.id), ["general", "about"])
            expectEqual(SettingsHub.showsLabel(for: .content, in: [.content, .settings]), false)
            expectEqual(SettingsHub.showsLabel(for: .settings, in: [.content, .settings]), true)
            let onlySettings = SettingsHub.groups([pane("general", .settings)])
            expectEqual(onlySettings.map(\.group), [.settings])
            expectEqual(SettingsHub.showsLabel(for: .settings, in: [.settings]), false, "no label when nothing sits above")
        }

        test("hub selects, steps and ignores unknown ids") {
            let panes = [pane("general", .settings, 0), pane("island", .settings, 100), pane("about", .settings, 1000)]
            let hub = SettingsHub(pane: "about", persists: false) { panes }
            expectEqual(hub.pane, "about")
            hub.select("island")
            expectEqual(hub.pane, "island")
            hub.select("missing")
            expectEqual(hub.pane, "island")
            hub.step(-1)
            expectEqual(hub.pane, "general")
            hub.requestSearch()
            expectEqual(hub.searchRequest, 1)
            expectEqual(SettingsHub(pane: "missing", persists: false) { panes }.pane, "general")
        }

        test("kit panes: General first and About last of the settings group, gallery in debug") {
            let panes = Registry.orderedSettingsPanes
            let general = panes.first { $0.id == "general" }
            let about = panes.first { $0.id == "about" }
            expect(general?.group == .settings && general?.order == 0)
            expect(about?.group == .settings && about?.order == 1000)
            let settingsGroup = panes.filter { $0.group == .settings }.map(\.id)
            expectEqual(settingsGroup.first, "general")
            expectEqual(settingsGroup.last, "about")
            expectEqual(panes.contains { $0.id == "gallery" && $0.group == .content }, GalleryKit.isVisible)
            expect(AppActions.settingsHandler != nil, "settings handler installed")
        }

        test("openSettings(pane:) selects the pane without a window when headless") {
            let before = SettingsHub.shared.pane
            defer { SettingsHub.shared.select(before) }
            AppActions.openSettings(pane: "about")
            expectEqual(SettingsHub.shared.pane, "about")
            AppActions.showAbout()
            expectEqual(SettingsHub.shared.pane, "about")
            AppActions.openSettings(pane: "general")
            expectEqual(SettingsHub.shared.pane, "general")
            expectEqual(SettingsController.isOpen, false, "no window in headless mode")
        }

        test("keys: ⌘F always, the rest only without a main menu") {
            let cmd: NSEvent.ModifierFlags = .command
            expectEqual(SettingsKeys.action(key: "f", flags: cmd, hasMainMenu: true), .search)
            expectEqual(SettingsKeys.action(key: "w", flags: cmd, hasMainMenu: true), nil)
            expectEqual(SettingsKeys.action(key: "w", flags: cmd, hasMainMenu: false), .close)
            expectEqual(SettingsKeys.action(key: ",", flags: cmd, hasMainMenu: false), .settings)
            expectEqual(SettingsKeys.action(key: "c", flags: cmd, hasMainMenu: false), .edit(#selector(NSText.copy(_:))))
            expectEqual(SettingsKeys.action(key: "z", flags: cmd, hasMainMenu: false), .edit(Selector(("undo:"))))
            expectEqual(SettingsKeys.action(key: "w", flags: [.command, .shift], hasMainMenu: false), nil)
            expectEqual(SettingsKeys.action(key: "f", flags: [.command, .option], hasMainMenu: false), nil)
            expectEqual(SettingsKeys.action(key: "f", flags: [], hasMainMenu: false), nil)
            expectEqual(SettingsKeys.action(key: "f", flags: [.command, .capsLock], hasMainMenu: true), .search, "caps lock does not count")
        }

        test("appearance mapping") {
            expectEqual(AppAppearance(stored: "system"), .system)
            expectEqual(AppAppearance(stored: "dark"), .dark)
            expectEqual(AppAppearance(stored: "sepia"), .system, "unknown values follow the Mac")
            expectEqual(AppAppearance.system.appearanceName, nil)
            expectEqual(AppAppearance.light.appearanceName, .aqua)
            expectEqual(AppAppearance.dark.appearanceName, .darkAqua)
            expectEqual(SettingKey<String>.appAppearance.defaultValue, "system")
        }

        test("reset removes every key except the setup state") {
            expectEqual(SettingsReset.keys(in: ["onboarding.done", "app.language", "island.style", "onboarding.step", "x"]),
                        ["app.language", "island.style", "x"])
            let store = Settings(fileURL: tempDir().appendingPathComponent("settings.json"))
            store[.onboardingDone] = true
            store[.appAppearance] = "dark"
            store[SettingKey<Int>("island.width", default: 0)] = 400
            SettingsReset.perform(on: store, applyToApp: false)
            let reread = Settings(fileURL: store.fileURL)
            expectEqual(reread[.onboardingDone], true)
            expectEqual(reread.hasValue(.appAppearance), false)
            expectEqual(reread[SettingKey<Int>("island.width", default: 0)], 0)
            expectEqual(Array(reread.values.keys), ["onboarding.done"])
        }

        test("notices: blocks and body without the leading title") {
            let text = """
            # Third-Party Notices

            Intro line one
            continues here.

            ## VoiceBud
            - Tokens
            * Window
            ---
            ### Small
            """
            let blocks = NoticesText.blocks(text)
            expectEqual(blocks, [.title("Third-Party Notices"), .paragraph("Intro line one continues here."), .heading("VoiceBud"),
                                 .item("Tokens"), .item("Window"), .rule, .heading("Small")])
            expectEqual(NoticesText.body(text).first, .paragraph("Intro line one continues here."))
            expectEqual(NoticesText.body("Plain").first, .paragraph("Plain"))
            expectEqual(NoticesText.blocks(""), [])
        }

        test("about: version line, data path, link details") {
            let os = OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 1)
            expectEqual(AboutInfo.versionLine(name: "Starter", version: "1.0.0", build: 7, os: os, arch: "arm64"),
                        "Starter 1.0.0 (7), macOS 26.0.1, arm64")
            let noPatch = OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0)
            expectEqual(AboutInfo.versionLine(name: "A", version: "2.0", build: 1, os: noPatch, arch: "arm64"), "A 2.0 (1), macOS 26.1, arm64")
            let folder = URL(fileURLWithPath: "/Users/kim/Library/Application Support/com.example.app")
            expectEqual(AboutInfo.displayPath(folder, home: "/Users/kim"), "~/Library/Application Support/com.example.app")
            expectEqual(AboutInfo.displayPath(folder, home: "/Users/ki"), folder.path, "a prefix that is not a folder is kept")
            if let web = URL(string: "https://example.com/help"), let mail = URL(string: "mailto:help@example.com") {
                expectEqual(AboutInfo.Link(title: "Web", url: web).detail, "example.com")
                expectEqual(AboutInfo.Link(title: "Mail", url: mail).detail, "help@example.com")
            }
            expectEqual(AboutInfo.configuredLinks.count, AppConfig.links.count)
        }

        test("settings and gallery scenes render in both appearances") {
            let scenes = Registry.orderedRenderScenes.filter { $0.id.hasPrefix("settings.") || $0.id.hasPrefix("gallery.") }
            for required in ["settings.general", "settings.about", "settings.window"] {
                expect(scenes.contains { $0.id == required }, "scene \(required) missing")
            }
            expectEqual(scenes.contains { $0.id == "settings.gallery" }, GalleryKit.isVisible)
            for scene in scenes {
                for appearance in Appearance.allCases {
                    guard let png = RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: .de),
                          let rep = NSBitmapImageRep(data: png) else { fail("\(scene.id) \(appearance): no image"); continue }
                    let alpha = rep.colorAt(x: rep.pixelsWide / 2, y: 1)?.alphaComponent ?? 0
                    expect(alpha > 0.99, "\(scene.id) \(appearance) top edge alpha \(alpha)")
                }
            }
        }
    }
}
#endif
