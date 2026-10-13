#if TESTING
import AppKit
import SwiftUI

final class PatternsTests: TestSuite {
    override class func register() {
        test("OnboardingCentered: centred, lifted 12 pt, never above 24 pt") {
            // 460 pt area (560 window - 68 footer - 32 titlebar), 200 pt content: (460-200)/2-12 = 118
            expectEqual(OnboardingCentered.top(content: 200, available: 460), 118)
            // tall content clamps to the minimum
            expectEqual(OnboardingCentered.top(content: 440, available: 460), 24)
            expectEqual(OnboardingCentered.top(content: 600, available: 460), 24)
            // rounded to whole points
            expectEqual(OnboardingCentered.top(content: 201, available: 460), 118)
            expectEqual(OnboardingCentered.top(content: 100, available: 300, minTop: 0, lift: 0), 100)
        }

        test("OnboardingCentered places the page at the computed top") {
            let content = Color.black.frame(width: 100, height: 200)
            let view = AnyView(OnboardingCentered { content }.frame(width: 300, height: 460).background(Color.white))
            guard let png = RenderRunner.png(view, size: CGSize(width: 300, height: 460), appearance: .light, lang: .en),
                  let rep = NSBitmapImageRep(data: png) else { return fail("no image") }
            // 2x: top edge at 118 pt = pixel row 236; row 234 white, row 238 black
            let dark = { (y: Int) in (rep.colorAt(x: 300, y: y)?.usingColorSpace(.sRGB)?.redComponent ?? 1) < 0.2 }
            let first = (0..<rep.pixelsHigh).first(where: dark)
            expect(!dark(234), "row above the page is not empty (first dark row \(String(describing: first)))")
            expect(dark(238), "page does not start at 118 pt (first dark row \(String(describing: first)))")
        }

        test("rich text: app links become links, everything else stays text") {
            expectEqual(RichTextLinks.parse("Click [Show in Finder](app://reveal) and drag."),
                        [.text("Click "), .link(title: "Show in Finder", action: "reveal"), .text(" and drag.")])
            expectEqual(RichTextLinks.parse("[A](app://one)[B](app://two-2)"),
                        [.link(title: "A", action: "one"), .link(title: "B", action: "two-2")])
            expectEqual(RichTextLinks.parse("No links here."), [.text("No links here.")])
            expectEqual(RichTextLinks.parse(""), [])
            expectEqual(RichTextLinks.parse(RichTextLinks.markdown(title: "Hilfe öffnen", action: "help")),
                        [.link(title: "Hilfe öffnen", action: "help")])
        }

        test("rich text: malformed or foreign links are plain text") {
            for s in ["[web](https://example.com)", "[open](app://)", "[](app://x)", "[open](app://x", "[open app://x)",
                      "[open](app://Reveal)", "[open](app://re veal)", "**bold** _x_ [y]"] {
                let parts = RichTextLinks.parse(s)
                expect(!parts.contains(where: \.isLink), "\(s) produced a link: \(parts)")
                expectEqual(parts.map { if case .text(let t) = $0 { t } else { "" } }.joined(), s, "text changed")
            }
            // a bracket before a real link does not swallow it
            expectEqual(RichTextLinks.parse("[x] then [go](app://go)"),
                        [.text("[x] then "), .link(title: "go", action: "go")])
        }

        test("rich text: URL round trip and attributed links") {
            let parts = RichTextLinks.parse("Open [Settings](app://open-settings) now")
            let attributed = RichTextLinks.attributed(parts)
            let links = attributed.runs.compactMap(\.link)
            expectEqual(links.count, 1)
            expectEqual(links.first.flatMap(RichTextLinks.action(of:)), "open-settings")
            expectEqual(String(attributed.characters), "Open Settings now")
            expectEqual(RichTextLinks.action(of: URL(string: "https://reveal")!), nil)
        }

        test("byte texts follow the UI language and the total's unit") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            Localizer.shared.forced = .en
            expectEqual(ByteText.size(900_000_000), "900\u{202F}MB")
            expectEqual(ByteText.size(3_035_000_000), "3.0\u{202F}GB")
            expectEqual(ByteText.size(12_000), "12\u{202F}KB")
            expectEqual(ByteText.progress(done: 1_400_000_000, total: 3_000_000_000), "1.4 of 3.0\u{202F}GB")
            expectEqual(ByteText.progress(done: 90_000_000, total: 230_000_000), "90 of 230\u{202F}MB")
            Localizer.shared.forced = .de
            expectEqual(ByteText.size(3_035_000_000), "3,0\u{202F}GB")
            expectEqual(ByteText.progress(done: 1_400_000_000, total: 3_000_000_000), "1,4 von 3,0\u{202F}GB")
        }

        test("progress fraction is clamped and absent when idle") {
            expectEqual(ProgressRow.Phase.running(done: 50, total: 100).fraction, 0.5)
            expectEqual(ProgressRow.Phase.running(done: 150, total: 100).fraction, 1)
            expectEqual(ProgressRow.Phase.paused(done: 5, total: 0).fraction, 0)
            expectEqual(ProgressRow.Phase.done(total: 1).fraction, nil)
            expectEqual(ProgressRow.Phase.waiting(total: 1).fraction, nil)
        }

        test("list search: every word, any field, case and accents ignored") {
            expect(ListSearch.matches("Mail", "Reads the open message", query: "mail"))
            expect(ListSearch.matches("Mail", "Reads the open message", query: "OPEN mail"))
            expect(ListSearch.matches("Über", query: "uber"))
            expect(ListSearch.matches("Notes", query: "  "))
            expect(!ListSearch.matches("Mail", "Reads the open message", query: "mail xcode"))
        }

        test("tile picker arrow keys clamp at the ends") {
            let values = ["a", "b", "c"]
            expectEqual(TilePicker<String, EmptyView>.step(from: "a", by: 1, in: values), "b")
            expectEqual(TilePicker<String, EmptyView>.step(from: "c", by: 1, in: values), "c")
            expectEqual(TilePicker<String, EmptyView>.step(from: "a", by: -1, in: values), "a")
            expectEqual(TilePicker<String, EmptyView>.step(from: "x", by: 1, in: values), "a")
        }

        test("status slot keys differ per visible state") {
            let keys = [OnboardingSlotState.action {}, .waiting(), .waiting(button: .openSettings {}), .denied(),
                        .denied(button: .openSettings {}), .granted(), .restartNeeded {}].map(\.key)
            expectEqual(Set(keys).count, keys.count)
            expectEqual(OnboardingSlotState.granted().key, OnboardingSlotState.granted().key)
        }

        test("every pattern has a scene and a gallery entry, the old samples are gone") {
            let scenes = Set(Registry.renderScenes.map(\.id))
            let gallery = Set(Registry.gallery.map(\.id))
            for name in ["onboarding-page", "onboarding-header", "onboarding-hero", "onboarding-footnote", "onboarding-hint",
                         "onboarding-status-slot", "onboarding-tile-picker", "onboarding-rich-text", "onboarding-footer",
                         "pane-scaffold", "settings-section", "toggle-row", "picker-row", "value-row", "button-row", "confirm-row", "link-row",
                         "navigation-row", "inline-notice", "progress-row", "list-card", "count-badge", "search-field",
                         "sample-pane", "sample-step", "sample-permission"] {
                expect(scenes.contains("patterns.\(name)"), "scene patterns.\(name)")
                expect(gallery.contains("patterns.\(name)"), "gallery patterns.\(name)")
            }
            expect(!scenes.contains("design.sample-settings") && !scenes.contains("design.sample-onboarding"))
        }

        test("every pattern scene renders in both appearances with opaque edges") {
            for scene in Registry.orderedRenderScenes where scene.id.hasPrefix("patterns.") {
                for appearance in Appearance.allCases {
                    guard let png = RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: .de),
                          let rep = NSBitmapImageRep(data: png) else { fail("\(scene.id) \(appearance): no image"); continue }
                    let (w, h) = (rep.pixelsWide, rep.pixelsHigh)
                    for (x, y) in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)] {
                        let alpha = rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
                        expect(alpha > 0.99, "\(scene.id) \(appearance) pixel (\(x), \(y)) alpha \(alpha)")
                    }
                }
            }
        }
    }
}
#endif
