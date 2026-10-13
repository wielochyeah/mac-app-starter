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

        // Deliberate exception, matching VoiceBud: white on violet is 3.75:1. 13 pt semibold is not
        // WCAG "large text" (that starts at 14 pt bold), so this is below AA on purpose.
        test("text on the accent fill >= 3:1, both schemes") {
            for accent in AccentName.allCases {
                let p = AccentPalette.of(accent)
                for dark in [false, true] {
                    let r = Contrast.ratio(p.onAccent, p.fill(dark: dark))
                    expect(r >= 3, "\(accent) onAccent on \(dark ? "dark" : "light") fill is \(r)")
                }
            }
        }

        // On and off must read apart without the knob position: at least VoiceBud's violet (2.2:1).
        test("accent fill stands apart from switch-off and track-off, both schemes") {
            let offs: [(dark: Bool, name: String, color: UInt32)] = [
                (false, "switchOff", ThemeHex.switchOffLight),
                (false, "trackOff", ThemeHex.trackOffLight),
                (true, "switchOff", Contrast.over(0xFFFFFF, ThemeHex.switchOffDarkAlpha, ThemeHex.cardDark)),
                (true, "trackOff", Contrast.over(0xFFFFFF, ThemeHex.trackOffDarkAlpha, ThemeHex.windowBgDark)),
            ]
            for accent in AccentName.allCases {
                let p = AccentPalette.of(accent)
                for off in offs {
                    let r = Contrast.ratio(p.fill(dark: off.dark), off.color)
                    expect(r >= 2.2, "\(accent) \(off.dark ? "dark" : "light") fill vs \(off.name) is \(r)")
                }
            }
        }

        test("badge text >= 4.5:1 on its tint over window and card, both schemes") {
            @MainActor func check(_ name: String, text: (Bool) -> UInt32, tint: (Bool) -> (color: UInt32, alpha: Double)) {
                for dark in [false, true] {
                    for bg in dark ? [ThemeHex.windowBgDark, ThemeHex.cardDark] : [ThemeHex.windowBgLight, ThemeHex.cardLight] {
                        let t = tint(dark)
                        let r = Contrast.ratio(text(dark), Contrast.over(t.color, t.alpha, bg))
                        expect(r >= 4.5, "\(name) badge \(dark ? "dark" : "light") on \(String(bg, radix: 16)) is \(r)")
                    }
                }
            }
            for accent in AccentName.allCases {
                let p = AccentPalette.of(accent)
                check("\(accent)", text: { $0 ? p.textDark : p.textLight },
                      tint: { (p.fill(dark: $0), $0 ? ThemeHex.accentSoftDark : ThemeHex.accentSoftLight) })
            }
            check("ok", text: { $0 ? ThemeHex.ok : ThemeHex.okTextLight },
                  tint: { (ThemeHex.ok, $0 ? ThemeHex.okSoftDark : ThemeHex.okSoftLight) })
            check("warn", text: { $0 ? ThemeHex.warn : ThemeHex.warnTextLight },
                  tint: { (ThemeHex.warn, $0 ? ThemeHex.warnSoftDark : ThemeHex.warnSoftLight) })
            check("neutral", text: { $0 ? ThemeHex.fgDark : ThemeHex.fgLight },
                  tint: { ($0 ? 0xFFFFFF : 0x000000, $0 ? ThemeHex.chipDark : ThemeHex.chipLight) })
        }

        test("red text >= 4.5:1 and the red mark >= 3:1 on window and card, both schemes") {
            for dark in [false, true] {
                for bg in dark ? [ThemeHex.windowBgDark, ThemeHex.cardDark] : [ThemeHex.windowBgLight, ThemeHex.cardLight] {
                    let text = Contrast.ratio(dark ? ThemeHex.strikeDark : ThemeHex.strikeTextLight, bg)
                    expect(text >= 4.5, "strikeText \(dark ? "dark" : "light") on \(String(bg, radix: 16)) is \(text)")
                    let mark = Contrast.ratio(dark ? ThemeHex.strikeDark : ThemeHex.strikeLight, bg)
                    expect(mark >= 3, "strike \(dark ? "dark" : "light") on \(String(bg, radix: 16)) is \(mark)")
                }
            }
        }

        test("body text >= 7:1 on window and card") {
            expect(Contrast.ratio(ThemeHex.fgLight, ThemeHex.windowBgLight) >= 7)
            expect(Contrast.ratio(ThemeHex.fgLight, ThemeHex.cardLight) >= 7)
            expect(Contrast.ratio(ThemeHex.fgDark, ThemeHex.windowBgDark) >= 7)
            expect(Contrast.ratio(ThemeHex.fgDark, ThemeHex.cardDark) >= 7)
        }

        test("secondary text (fg2, prose, sideGroup) >= 4.5:1 on window, card and sidebar panel, both schemes") {
            for dark in [false, true] {
                let base = dark ? ThemeHex.secondaryDark : ThemeHex.secondaryLight
                let grounds: [(String, UInt32)] = dark
                    ? [("window", ThemeHex.windowBgDark), ("card", ThemeHex.cardDark), ("sidebar", ThemeHex.sidebarPanelDark)]
                    : [("window", ThemeHex.windowBgLight), ("card", ThemeHex.cardLight), ("sidebar", ThemeHex.sidebarPanelLight)]
                let tokens: [(String, Double)] = dark
                    ? [("fg2", ThemeHex.fg2Dark), ("prose", ThemeHex.fg2Dark), ("sideGroup", ThemeHex.sideGroupDark)]
                    : [("fg2", ThemeHex.fg2Light), ("prose", ThemeHex.proseLight), ("sideGroup", ThemeHex.sideGroupLight)]
                for (name, alpha) in tokens {
                    for (ground, bg) in grounds {
                        let r = Contrast.ratio(Contrast.over(base, alpha, bg), bg)
                        expect(r >= 4.5, "\(name) \(dark ? "dark" : "light") on \(ground) is \(r)")
                    }
                }
            }
        }

        test("an info notice: prose >= 4.5:1 and its fg2 symbol >= 3:1 on the neutral fill, both schemes") {
            for dark in [false, true] {
                let base = dark ? ThemeHex.secondaryDark : ThemeHex.secondaryLight
                for bg in dark ? [ThemeHex.windowBgDark, ThemeHex.cardDark] : [ThemeHex.windowBgLight, ThemeHex.cardLight] {
                    let fill = dark ? Contrast.over(0xFFFFFF, ThemeHex.noticeNeutralDark, bg) : Contrast.over(0x000000, ThemeHex.noticeNeutralLight, bg)
                    let prose = Contrast.ratio(Contrast.over(base, dark ? ThemeHex.fg2Dark : ThemeHex.proseLight, fill), fill)
                    expect(prose >= 4.5, "notice text \(dark ? "dark" : "light") on \(String(bg, radix: 16)) is \(prose)")
                    let symbol = Contrast.ratio(Contrast.over(base, dark ? ThemeHex.fg2Dark : ThemeHex.fg2Light, fill), fill)
                    expect(symbol >= 3, "notice symbol \(dark ? "dark" : "light") is \(symbol)")
                }
            }
        }

        // fg3 is below 4.5:1 on purpose: it may only colour placeholders (shown while a field is
        // empty), disabled or paused states and decorative glyphs, never text people have to read.
        test("fg3 only for placeholders, paused states and decorative glyphs") {
            let allowed = ["isEmpty ?", "Image(systemName", "Circle()", "case .paused", "(\"fg3\""]
            let sources = repoRoot.appendingPathComponent("App/Sources")
            guard let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else { return fail("no sources") }
            var uses = 0
            for case let url as URL in files where url.pathExtension == "swift" && url.lastPathComponent != "Theme.swift" {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let lines = text.components(separatedBy: "\n")
                for (i, line) in lines.enumerated() where line.contains(".fg3") {
                    uses += 1
                    let context = lines[max(0, i - 3)...i].joined(separator: "\n")
                    expect(allowed.contains { context.contains($0) },
                           "\(url.lastPathComponent):\(i + 1) uses fg3 for something that is not a placeholder or a glyph: \(line)")
                }
            }
            expect(uses > 0, "the scan found the sources")
        }

        test("every design component has a scene and a gallery entry") {
            let scenes = Set(Registry.renderScenes.map(\.id))
            let gallery = Set(Registry.gallery.map(\.id))
            for name in ["buttons", "card", "row", "group-label", "separator", "footnote", "switch", "segmented", "chip",
                         "badge", "squircle", "keycaps", "progress", "spinner", "empty-state", "section-header", "glass", "island"] {
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

        test("measured scenes are laid out a little wider than their ideal width") {
            expectEqual(RenderRunner.layoutWidth(measured: 142.3), 144)
            expectEqual(RenderRunner.layoutWidth(measured: 320), 321)
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

        test("design scenes have opaque edges (no empty pixel row from fractional sizes)") {
            for scene in Registry.orderedRenderScenes where scene.id.hasPrefix("design.") {
                for appearance in Appearance.allCases {
                    guard let png = RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: .de),
                          let rep = NSBitmapImageRep(data: png) else { fail("\(scene.id) \(appearance): no image"); continue }
                    let (w, h) = (rep.pixelsWide, rep.pixelsHigh)
                    for (x, y) in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w / 2, 0), (w / 2, h - 1), (0, h / 2), (w - 1, h / 2)] {
                        let alpha = rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
                        expect(alpha > 0.99, "\(scene.id) \(appearance) pixel (\(x), \(y)) alpha \(alpha)")
                    }
                }
            }
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
