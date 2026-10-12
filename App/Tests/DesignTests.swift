#if TESTING
import AppKit
import SwiftUI

final class DesignTests: TestSuite {
    override class func register() {
        test("contrast math matches WCAG") {
            expectEqual((Contrast.ratio(0xFFFFFF, 0x000000) * 100).rounded() / 100, 21)
            expectEqual(Contrast.ratio(0x777777, 0x777777), 1)
        }

        test("accent text >= 4.5:1 on window and card, both schemes") {
            for accent in AccentName.allCases {
                let p = AccentPalette.of(accent)
                for (text, backgrounds) in [(p.textLight, [ThemeHex.windowBgLight, ThemeHex.cardLight]),
                                            (p.textDark, [ThemeHex.windowBgDark, ThemeHex.cardDark])] {
                    for bg in backgrounds {
                        let r = Contrast.ratio(text, bg)
                        expect(r >= 4.5, "\(accent) text \(String(text, radix: 16)) on \(String(bg, radix: 16)) is \(r)")
                    }
                }
            }
        }

        test("selection ring >= 3:1 on window and card, both schemes") {
            for accent in AccentName.allCases {
                let p = AccentPalette.of(accent)
                for (ring, backgrounds) in [(p.ringLight, [ThemeHex.windowBgLight, ThemeHex.cardLight]),
                                            (p.ringDark, [ThemeHex.windowBgDark, ThemeHex.cardDark])] {
                    for bg in backgrounds {
                        let r = Contrast.ratio(ring, bg)
                        expect(r >= 3, "\(accent) ring on \(String(bg, radix: 16)) is \(r)")
                    }
                }
            }
        }

        test("text on the accent fill >= 3:1 (13 pt semibold button labels)") {
            for accent in AccentName.allCases {
                let p = AccentPalette.of(accent)
                let r = Contrast.ratio(p.onAccent, p.fill)
                expect(r >= 3, "\(accent) onAccent is \(r)")
            }
        }

        test("body text >= 7:1 on window and card") {
            expect(Contrast.ratio(ThemeHex.fgLight, ThemeHex.windowBgLight) >= 7)
            expect(Contrast.ratio(ThemeHex.fgLight, ThemeHex.cardLight) >= 7)
            expect(Contrast.ratio(ThemeHex.fgDark, ThemeHex.windowBgDark) >= 7)
            expect(Contrast.ratio(ThemeHex.fgDark, ThemeHex.cardDark) >= 7)
        }

        test("every design component has a scene and a gallery entry") {
            let scenes = Set(Registry.renderScenes.map(\.id))
            let gallery = Set(Registry.gallery.map(\.id))
            for name in ["buttons", "card", "row", "group-label", "separator", "footnote", "switch", "segmented", "chip",
                         "badge", "squircle", "keycaps", "progress", "spinner", "empty-state", "section-header", "glass"] {
                expect(scenes.contains("design.\(name)"), "scene design.\(name)")
                expect(gallery.contains("design.\(name)"), "gallery design.\(name)")
            }
        }

        test("renders are 2x and keep exact token colours") {
            let view = AnyView(Color(hex: ThemeHex.windowBgDark).frame(width: 40, height: 20))
            guard let png = RenderRunner.png(view, size: CGSize(width: 40, height: 20), appearance: .dark, lang: .en),
                  let rep = NSBitmapImageRep(data: png) else { return fail("no image") }
            expectEqual(rep.pixelsWide, 80)
            expectEqual(rep.pixelsHigh, 40)
            expectEqual(rep.colorSpace.colorSpaceModel, .rgb)
            expect(rep.colorSpace == .sRGB, "PNG is not sRGB: \(rep.colorSpace)")
            let c = rep.colorAt(x: 10, y: 10)
            let hex = c.map { (Int(($0.redComponent * 255).rounded()) << 16) | (Int(($0.greenComponent * 255).rounded()) << 8) | Int(($0.blueComponent * 255).rounded()) }
            expectEqual(hex, Int(ThemeHex.windowBgDark))
        }

        test("half-point hairlines survive the render") {
            let view = AnyView(VStack(spacing: 0) {
                Color.white.frame(height: 10.5)
                Rectangle().fill(Color.black).frame(height: Metrics.hairline)
                Color.white.frame(height: 9)
            }.frame(width: 20))
            guard let png = RenderRunner.png(view, size: CGSize(width: 20, height: 20), appearance: .light, lang: .en),
                  let rep = NSBitmapImageRep(data: png) else { return fail("no image") }
            let darkest = (0..<40).map { rep.colorAt(x: 10, y: $0)?.usingColorSpace(.sRGB)?.redComponent ?? 1 }.min() ?? 1
            expect(darkest < 0.2, "hairline missing (darkest \(darkest))")
        }

        test("every design scene renders in both appearances") {
            for scene in Registry.orderedRenderScenes where scene.id.hasPrefix("design.") {
                for appearance in Appearance.allCases {
                    let png = RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: .de)
                    expect((png?.count ?? 0) > 500, "\(scene.id) \(appearance)")
                }
            }
        }
    }
}
#endif
