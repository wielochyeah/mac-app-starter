#if TESTING
#if MODUL_ISLAND
import AppKit
import SwiftUI

// Island module: screen geometry, width maths, meter maths, settings, and the controller's state
// machine driven by a manual clock, a fake panel and hand-made screens (nothing goes on screen).

/// A clock the tests advance by hand; runs due work in time order.
final class ManualScheduler: IslandScheduling {
    var now = Date(timeIntervalSinceReferenceDate: 1_000)
    private struct Item {
        var at: Date
        let every: Double?
        let task: IslandTask
        let work: () -> Void
        let seq: Int
    }
    private var items: [Item] = []
    private var seq = 0

    @discardableResult func after(_ seconds: Double, _ work: @escaping () -> Void) -> IslandTask {
        add(at: now.addingTimeInterval(seconds), every: nil, work)
    }

    func every(_ seconds: Double, tolerance: Double, _ work: @escaping () -> Void) -> IslandTask {
        add(at: now.addingTimeInterval(seconds), every: seconds, work)
    }

    private func add(at: Date, every: Double?, _ work: @escaping () -> Void) -> IslandTask {
        let task = IslandTask()
        seq += 1
        items.append(Item(at: at, every: every, task: task, work: work, seq: seq))
        return task
    }

    /// Repeating timers alive right now.
    var repeating: Int { items.filter { $0.every != nil && !$0.task.isCancelled }.count }

    func advance(_ seconds: Double) {
        let end = now.addingTimeInterval(seconds)
        while true {
            items.removeAll { $0.task.isCancelled }
            guard let next = items.filter({ $0.at <= end }).min(by: { ($0.at, $0.seq) < ($1.at, $1.seq) }),
                  let i = items.firstIndex(where: { $0.seq == next.seq }) else { break }
            now = next.at
            if let every = next.every {
                items[i].at = next.at.addingTimeInterval(every)
            } else {
                items.remove(at: i)
            }
            next.work()
        }
        now = end
    }
}

final class FakeIslandHost: IslandSurfaceHost {
    var isVisible = false
    var isReallyOnScreen = true
    var frame: CGRect = .zero
    var alpha: CGFloat = 1
    var orderIns: [CGRect] = []
    var orderOuts = 0
    var clickThrough = true
    var rebuilds = 0

    func prepare() {}
    func orderIn(frame: CGRect, front: Bool) {
        self.frame = frame
        alpha = 0
        isVisible = front
        orderIns.append(frame)
    }
    func fade(to alpha: CGFloat, duration: Double) { self.alpha = alpha }
    func orderOut() {
        isVisible = false
        alpha = 1
        orderOuts += 1
    }
    func move(to origin: CGPoint) { frame.origin = origin }
    func setClickThrough(_ on: Bool) { clickThrough = on }
    func rebuild() {
        rebuilds += 1
        isVisible = false
    }
}

/// A 14" MacBook Pro (notch 185 × 32, menu bar 33) and an external display without notch to its
/// right, 200 pt lower.
private enum Screens {
    static let mbp = IslandScreen(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                  visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949),
                                  safeTop: 32, auxLeftWidth: 663.5, auxRightWidth: 663.5, displayID: 1, scale: 2)
    static let external = IslandScreen(frame: CGRect(x: 1512, y: -200, width: 2560, height: 1440),
                                       visibleFrame: CGRect(x: 1512, y: -200, width: 2560, height: 1415),
                                       displayID: 2, scale: 1)
}

/// The controller with fakes around it.
private final class Rig {
    let clock = ManualScheduler()
    let host = FakeIslandHost()
    var screens = [Screens.mbp, Screens.external]
    var mouse = CGPoint(x: 700, y: 500)
    var prefs = IslandPrefs()
    var sounds: [String] = []
    var busy = false
    private(set) var island: Island!

    init() {
        let deps = Island.Dependencies(
            scheduler: clock,
            makeHost: { [host] _, _ in host },
            screens: { [unowned self] in self.screens },
            mouse: { [unowned self] in self.mouse },
            prefs: { [unowned self] in self.prefs },
            isFullscreen: { _ in false },
            headless: false,
            playSound: { [unowned self] in self.sounds.append($0) },
            haptic: {})
        island = Island(deps: deps)
        island.notchBusy = { [unowned self] in self.busy }
    }

    var model: IslandModel { island.model }

    /// present + the 16 ms grow + the 60 ms until swaps
    func show(_ content: IslandContent) {
        island.present(content)
        clock.advance(0.1)
    }

    /// Puts the card where the views would report it (canvas points) and the pointer on it.
    func pointerOnCard() {
        let panel = CGRect(origin: IslandScreenGeometry(Screens.mbp).panelOrigin(for: IslandLook.canvas), size: IslandLook.canvas)
        model.cardFrame = CGRect(x: 120, y: 0, width: 400, height: 90)
        mouse = CGPoint(x: panel.minX + 320, y: panel.maxY - 60)
    }
}

final class IslandGeometryTests: TestSuite {
    override class func register() {
        test("notch measured from the menu bar areas, never hard-coded") {
            let g = IslandScreenGeometry(Screens.mbp)
            expectEqual(g.notch, CGSize(width: 185, height: 32))
            expectEqual(g.notchMidX, 756)
            expectEqual(g.menuBarHeight, 33)
            expectEqual(g.safeTop, 32)
            expectEqual(g.drawnNotch, CGSize(width: 185, height: 32))
        }

        test("an off-centre notch is centred on the left area's edge, not the screen") {
            var s = Screens.mbp
            s.auxLeftWidth = 600
            s.auxRightWidth = 727
            let g = IslandScreenGeometry(s)
            expectEqual(g.notch?.width, 185)
            expectEqual(g.notchMidX, 600 + 92.5)
        }

        test("no notch: centre of the screen, menu bar from the visible frame") {
            let g = IslandScreenGeometry(Screens.external)
            expect(g.notch == nil)
            expectEqual(g.notchMidX, 1512 + 1280)
            expectEqual(g.menuBarHeight, 25)
            expectEqual(g.drawnNotch, CGSize(width: Metrics.Island.renderNotch.width, height: 25))
        }

        test("menu bar that hides itself: notch height, or 24 without a notch") {
            var notched = Screens.mbp
            notched.visibleFrame = notched.frame
            expectEqual(IslandScreenGeometry(notched).menuBarHeight, 32)
            var plain = Screens.external
            plain.visibleFrame = plain.frame
            expectEqual(IslandScreenGeometry(plain).menuBarHeight, 24)
        }

        test("degenerate notch values are ignored") {
            var s = Screens.mbp
            s.auxLeftWidth = 740
            s.auxRightWidth = 740
            expect(IslandScreenGeometry(s).notch == nil, "32 pt wide notch is noise")
            s.auxRightWidth = nil
            expect(IslandScreenGeometry(s).notch == nil)
        }

        test("panel origin: flush with the screen top, centred on the notch, whole pixels") {
            let size = IslandLook.canvas
            let g = IslandScreenGeometry(Screens.mbp)
            expectEqual(g.panelOrigin(for: size), CGPoint(x: 756 - 320, y: 982 - 400))
            var odd = Screens.mbp
            odd.auxLeftWidth = 663.3
            let o = IslandScreenGeometry(odd).panelOrigin(for: size)
            expectEqual(o.x * 2, (o.x * 2).rounded(), "x on a 2x pixel")
            let ext = IslandScreenGeometry(Screens.external).panelOrigin(for: CGSize(width: 641, height: 400))
            expectEqual(ext.x, ext.x.rounded(), "x on a 1x pixel")
            expectEqual(ext.y, 1240 - 400)
        }

        test("screen under the pointer, top row included, else the first") {
            let screens = [Screens.mbp, Screens.external]
            expectEqual(IslandScreen.containing(CGPoint(x: 2000, y: 100), in: screens)?.displayID, 2)
            expectEqual(IslandScreen.containing(CGPoint(x: 700, y: 982), in: screens)?.displayID, 1, "top edge row")
            expectEqual(IslandScreen.containing(CGPoint(x: 700, y: 0), in: screens)?.displayID, 1, "outside: first")
            expectEqual(IslandScreen.containing(CGPoint(x: 1512, y: 100), in: screens)?.displayID, 2, "left edge belongs right")
            expect(IslandScreen.containing(.zero, in: []) == nil)
        }

        test("island or capsule per style, notch and a busy notch") {
            let notch = IslandScreenGeometry(Screens.mbp), plain = IslandScreenGeometry(Screens.external)
            expectEqual(notch.kind(style: .auto, notchBusy: false), .notch)
            expectEqual(notch.kind(style: .auto, notchBusy: true), .capsule)
            expectEqual(notch.kind(style: .island, notchBusy: true), .notch)
            expectEqual(notch.kind(style: .capsule, notchBusy: false), .capsule)
            for style in IslandStyle.allCases { expectEqual(plain.kind(style: style, notchBusy: false), .capsule) }
            expectEqual(notch.capsuleTop(style: .capsule, notchBusy: false), 33 + 8)
            expectEqual(notch.capsuleTop(style: .auto, notchBusy: true), 32 + 8, "dodge: directly under the notch")
            expectEqual(plain.capsuleTop(style: .auto, notchBusy: true), 25 + 8)
        }

        test("pointer on the card: canvas to screen, slack, menu bar strip when entering") {
            let panel = CGRect(x: 436, y: 582, width: 640, height: 400)
            let card = CGRect(x: 120, y: 0, width: 400, height: 90)
            // card spans x 556…956, y 892…982 on screen
            expect(Island.pointer(CGPoint(x: 700, y: 940), isOn: card, panel: panel, notch: 32, entering: true))
            expect(!Island.pointer(CGPoint(x: 700, y: 970), isOn: card, panel: panel, notch: 32, entering: true), "menu bar strip")
            expect(Island.pointer(CGPoint(x: 700, y: 970), isOn: card, panel: panel, notch: 32, entering: false), "staying inside")
            expect(Island.pointer(CGPoint(x: 700, y: 970), isOn: card, panel: panel, notch: nil, entering: true), "capsule: no strip")
            expect(Island.pointer(CGPoint(x: 555.5, y: 900), isOn: card, panel: panel, notch: nil, entering: true), "1 pt slack")
            expect(!Island.pointer(CGPoint(x: 540, y: 900), isOn: card, panel: panel, notch: nil, entering: true))
            expect(!Island.pointer(CGPoint(x: 700, y: 950), isOn: .zero, panel: panel, notch: nil, entering: true), "no card yet")
        }
    }
}

final class IslandLayoutTests: TestSuite {
    override class func register() {
        let notch = CGSize(width: 185, height: 32)

        test("collapsed: 8 pt narrower than the notch") {
            expectEqual(IslandLayout.notchWidth(.notice(text: "x"), notch: notch, shown: false), 177)
            expectEqual(IslandLayout.notchWidth(nil, notch: notch, shown: true), 177)
        }

        test("compact ears: at least 50 pt each side; text widens them symmetrically") {
            expectEqual(IslandLayout.notchWidth(.levels([]), notch: notch, shown: true), 185 + 100)
            let short = IslandLayout.notchWidth(.activity(symbol: "timer", title: "I"), notch: notch, shown: true)
            expectEqual(short, 285)
            let title = "Synchronising"
            let w = IslandLayout.notchWidth(.activity(symbol: "timer", title: title), notch: notch, shown: true)
            let left = IslandLook.badge + IslandLook.earSpacing + IslandLayout.width(title, font: IslandLook.titleFont)
            expectEqual(w, 185 + 2 * (IslandLook.earPad + left))
            let long = IslandLayout.notchWidth(.activity(symbol: "timer", title: String(repeating: "Long title ", count: 8)),
                                               notch: notch, shown: true)
            expectEqual(long, Metrics.Island.liveWidth, "capped, the title is cut")
        }

        test("progress: counter and percent widen the right ear; the slow card is wide enough for Cancel") {
            let plain = IslandLayout.notchWidth(.progress(title: "Go"), notch: notch, shown: true)
            let counting = IslandLayout.notchWidth(.progress(title: "Go", fraction: 0.5), notch: notch, shown: true, slowCounting: true)
            expect(counting > plain)
            let hint = IslandLayout.notchWidth(.progress(title: "Go"), notch: notch, shown: true, slowHint: true)
            expect(hint >= 185 + 2 * IslandLook.cardWing)
        }

        test("cards: done 400, unfolded 470; notices as narrow as possible, at most 400") {
            expectEqual(IslandLayout.notchWidth(.done(title: "x"), notch: notch, shown: true), 400)
            expectEqual(IslandLayout.notchWidth(.done(title: "x"), notch: notch, shown: true, expanded: true), 470)
            expectEqual(IslandLayout.notchWidth(.notice(text: "Ok"), notch: notch, shown: true), 285)
            let long = String(repeating: "A long message ", count: 10)
            expectEqual(IslandLayout.notchWidth(.notice(text: long), notch: notch, shown: true), 400)
            expectEqual(IslandLayout.capsuleNoticeWidth("Ok"), IslandLook.noticeMinCapsule)
            expectEqual(IslandLayout.capsuleNoticeWidth(long), 400)
        }

        test("paragraphs: blank lines split, single breaks stay, whitespace trimmed") {
            expectEqual(IslandLayout.paragraphs("Hi Anna,\n\n  first line\nsecond  \n\n\n\nBye\r\nNils"),
                        ["Hi Anna,", "first line\nsecond", "Bye\nNils"])
            expectEqual(IslandLayout.paragraphs("  \n \n"), [])
            expectEqual(IslandLayout.preview("Hi Anna,\n\nfirst\nsecond"), "Hi Anna, first second")
        }

        test("timer and counters") {
            expectEqual(IslandLayout.timer(4.9), "0:04")
            expectEqual(IslandLayout.timer(754), "12:34")
            expectEqual(IslandLayout.timer(-3), "0:00")
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            Localizer.shared.forced = .en
            expectEqual(IslandText.percent(0.424), "42%")
            expectEqual(IslandText.percent(1.7), "100%")
            Localizer.shared.forced = .de
            expectEqual(IslandText.percent(0.424), "42\u{202F}%")
            expectEqual(IslandText.counter(12), "12\u{202F}s")
        }

        test("meter: dots in silence, bands folded into 4 bars within 2…14 pt, calm synthetic motion") {
            expectEqual(IslandMeterMath.targets(t: 1, bands: [0, 0.01, 0]), Array(repeating: IslandLook.meterMin, count: 4))
            let loud = IslandMeterMath.targets(t: 1, bands: [0.6, 0.85, 0.74, 0.55, 0.42, 0.3, 0.18])
            expectEqual(loud.count, 4)
            expect(loud.allSatisfy { $0 >= IslandLook.meterMin && $0 <= IslandLook.meterMax })
            expect(loud.contains { $0 > 8 }, "speech is visible")
            expectEqual(IslandMeterMath.fold([1, 1, 0, 0], into: 2), [1, 0])
            expectEqual(IslandMeterMath.fold([0.5], into: 4), [0.5, 0.5, 0.5, 0.5], "fewer bands than bars")
            for t in stride(from: 0.0, to: 6, by: 0.37) {
                expect(IslandMeterMath.targets(t: t, bands: []).allSatisfy { $0 >= IslandLook.meterMin && $0 <= IslandLook.meterMax })
            }
        }

        test("meter smoothing: fast attack, slow release, time-corrected") {
            let up = IslandMeterMath.step([2], toward: [12], frames: 1)[0]
            expectEqual(up, 2 + 10 * 0.3)
            let down = IslandMeterMath.step([12], toward: [2], frames: 1)[0]
            expectEqual(down, 12 - 10 * 0.1)
            let twoFrames = IslandMeterMath.step([2], toward: [12], frames: 2)[0]
            let stepped = IslandMeterMath.step(IslandMeterMath.step([2], toward: [12], frames: 1), toward: [12], frames: 1)[0]
            expect(abs(twoFrames - stepped) < 0.0001, "two frames at once = two single frames")
        }
    }
}

final class IslandModelTests: TestSuite {
    override class func register() {
        test("confirmation: at least 0.3 s, 60 s or more stays") {
            expectEqual(IslandPrefs(confirmSeconds: 3).confirmDelay, 3)
            expectEqual(IslandPrefs(confirmSeconds: 0.1).confirmDelay, 0.3)
            expect(IslandPrefs(confirmSeconds: 60).confirmDelay == nil)
            expectEqual(IslandPane.nearestChoice(2.6), 3)
            expectEqual(IslandPane.nearestChoice(500), IslandTiming.stays)
        }

        test("settings keys and defaults") {
            let dir = tempDir()
            let s = Settings(fileURL: dir.appendingPathComponent("settings.json"))
            expectEqual(s[.islandStyle], "auto")
            expectEqual(s[.islandConfirmSeconds], 3)
            expect(s[.islandHoverExpand] && !s[.islandSounds] && s[.islandHaptics] && !s[.islandHideInFullscreen])
            s[.islandStyle] = "capsule"
            expectEqual(Settings(fileURL: s.fileURL)[.islandStyle], "capsule")
        }

        test("content: bands, expand, badge, actions compare without closures") {
            let a = IslandContent.levels([0.1, 0.2], symbol: "mic.fill")
            expectEqual(a.withoutBands, .levels([], symbol: "mic.fill"))
            expectEqual(a.bands, [0.1, 0.2])
            expect(!IslandContent.done(title: "x").canExpand)
            expect(IslandContent.done(title: "x", body: "text").canExpand)
            expect(!IslandContent.done(title: "x", body: "  \n").canExpand)
            expect(IslandContent.done(title: "x", actions: [IslandAction(id: "a", title: "A") {}]).canExpand)
            expectEqual(IslandBadgeKind(.notice(text: "x", kind: .success)), .check(.accent))
            expectEqual(IslandBadgeKind(.progress(title: "x", symbol: "bolt", tint: .teal)), .symbol("bolt", .teal))
            expectEqual(IslandAction(id: "a", title: "A") {}, IslandAction(id: "a", title: "A", perform: { _ = 1 }))
            expect(IslandContent.levels([]).isRunning && !IslandContent.notice(text: "x").isRunning)
        }

        test("every state has an island and a capsule scene, plus pane and onboarding") {
            let ids = Set(Registry.renderScenes.map(\.id))
            for sample in IslandScenes.samples {
                expect(ids.contains("island.\(sample.id)"), "island.\(sample.id)")
                expect(ids.contains("capsule.\(sample.id)"), "capsule.\(sample.id)")
            }
            expect(IslandScenes.samples.count >= 10)
            for id in ["island.pane", "island.onboarding", "capsule.no-notch"] { expect(ids.contains(id), id) }
            expect(Registry.settingsPanes.contains { $0.id == "island" })
            expect(Registry.onboardingSteps.contains { $0.id == "island.appearance" && $0.order == 500 })
            expect(Registry.selfTests.contains { $0.id == "island.headless" })
            expect(!Registry.demoDrivers.isEmpty)
        }

        test("--demo runs the island loop unless another area is named") {
            expect(IslandDemo.wanted(["app", "--demo"]))
            expect(IslandDemo.wanted(["app", "--demo", "island"]))
            expect(!IslandDemo.wanted(["app", "--demo", "menubar"]))
            expect(!IslandDemo.wanted(["app"]))
        }

        test("renders: island and capsule states draw black on the wallpaper in both appearances") {
            for id in ["island.levels", "capsule.done"] {
                guard let scene = Registry.renderScenes.first(where: { $0.id == id }) else { return fail("missing \(id)") }
                for appearance in Appearance.allCases {
                    guard let png = RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: .de),
                          let rep = NSBitmapImageRep(data: png) else { return fail("no image for \(id)") }
                    expectEqual(rep.pixelsWide, Int(scene.size.width * 2))
                    // the island's centre column, just under the menu bar: black surface
                    let y = id.hasPrefix("island") ? 20 : Int((Metrics.Island.renderMenuBar + 8 + 20) * 2)
                    let c = rep.colorAt(x: rep.pixelsWide / 2, y: y)?.usingColorSpace(.sRGB)
                    expect((c?.brightnessComponent ?? 1) < 0.05, "\(id) \(appearance): not black at the centre")
                    // a corner: wallpaper, not black
                    let corner = rep.colorAt(x: 4, y: rep.pixelsHigh - 4)?.usingColorSpace(.sRGB)
                    expect((corner?.brightnessComponent ?? 0) > 0.05, "\(id) \(appearance): corner is black")
                }
            }
        }
    }
}

final class IslandControllerTests: TestSuite {
    override class func register() {
        test("present: ordered in transparent at the notch, grows on the next frame, then swaps") {
            let r = Rig()
            r.island.present(.levels([0.5]))
            expectEqual(r.host.orderIns, [CGRect(x: 756 - 320, y: 982 - 400, width: 640, height: 400)])
            expectEqual(r.host.alpha, 0)
            expect(!r.model.presented, "first frame collapsed")
            expectEqual(r.model.kind, .notch)
            expectEqual(r.model.notch, CGSize(width: 185, height: 32))
            expect(r.island.isPresenting)
            r.clock.advance(0.016)
            expect(r.model.presented)
            expectEqual(r.host.alpha, 1)
            expect(!r.model.contentSwap)
            r.clock.advance(0.06)
            expect(r.model.contentSwap, "from now on glyphs swap")
            expectEqual(r.sounds, ["Tink"])
            expectEqual(r.model.bands, [0.5])
            expectEqual(r.model.content, .levels([]), "bands live outside the observed content")
        }

        test("notice hides itself after 2.5 s: collapse, fade, order out, reset") {
            let r = Rig()
            r.show(.notice(text: "x", kind: .error))
            r.clock.advance(2.39)
            expect(r.model.presented)
            r.clock.advance(0.03)  // 2.52 s
            expect(!r.island.isPresenting, "dismiss started")
            r.clock.advance(0.03)
            expect(!r.model.presented, "collapsed after 20 ms")
            expectEqual(r.host.orderOuts, 0)
            r.clock.advance(0.5)
            expectEqual(r.host.orderOuts, 1)
            expect(r.model.content == nil && !r.host.isVisible)
            expectEqual(r.clock.repeating, 0, "no timer left while idle")
        }

        test("done card: confirmation time from settings; 60 s stays") {
            let r = Rig()
            r.prefs.confirmSeconds = 1.5
            r.show(.progress(title: "x"))
            r.island.update(.done(title: "y"))
            expectEqual(r.sounds, ["Tink", "Pop"])
            r.clock.advance(1.4)
            expect(r.island.isPresenting)
            r.clock.advance(0.2)
            expect(!r.island.isPresenting)

            let stay = Rig()
            stay.prefs.confirmSeconds = 60
            stay.show(.done(title: "y"))
            stay.clock.advance(300)
            expect(stay.island.isPresenting && stay.model.presented)
            stay.island.dismiss()
            stay.clock.advance(1)
            expect(stay.model.content == nil)
        }

        test("update in place: same take, no new panel; bands-only updates do not touch the content") {
            let r = Rig()
            r.show(.activity(symbol: "timer", title: "A"))
            r.island.update(.progress(title: "B", fraction: 0.3))
            expectEqual(r.host.orderIns.count, 1)
            expectEqual(r.model.phase, .progress)
            r.island.update(.levels([0.1], symbol: "mic.fill"))
            let content = r.model.content
            r.island.update(.levels([0.9, 0.2], symbol: "mic.fill"))
            expectEqual(r.model.content, content)
            expectEqual(r.model.bands, [0.9, 0.2])
            r.island.update(.levels([0.9], symbol: "waveform"))
            expectEqual(r.model.content, .levels([], symbol: "waveform"), "a new symbol is a content change")
        }

        test("update while nothing shows presents; present while showing morphs on the same screen") {
            let r = Rig()
            r.island.update(.notice(text: "x"))
            expectEqual(r.host.orderIns.count, 1)
            r.clock.advance(0.1)
            r.island.present(.activity(symbol: "timer", title: "A"))
            expectEqual(r.host.orderIns.count, 1, "morph, no regrow")
            expect(r.model.presented && r.model.contentSwap)
            r.mouse = CGPoint(x: 2000, y: 100)
            r.island.present(.activity(symbol: "timer", title: "A"))
            expectEqual(r.host.orderIns.count, 2, "other screen: new take")
            expectEqual(r.model.kind, .capsule, "no notch there")
            expectEqual(r.model.capsuleTop, 25 + 8)
            expectEqual(r.host.orderIns.last?.origin.x, 1512 + 1280 - 320)
        }

        test("update right after present (before the first frame) stays in the same take") {
            let r = Rig()
            r.island.present(.levels([0.1]))
            r.island.update(.levels([0.2]))
            r.island.update(.progress(title: "x"))
            r.clock.advance(0.1)
            expectEqual(r.host.orderIns.count, 1)
            expect(r.model.presented && r.model.phase == .progress)
        }

        test("present during a dismiss starts over") {
            let r = Rig()
            r.show(.notice(text: "x"))
            r.island.dismiss()
            r.clock.advance(0.1)
            r.island.present(.activity(symbol: "timer", title: "A"))
            r.clock.advance(1)
            expectEqual(r.host.orderOuts, 0, "the old order-out was cancelled")
            expect(r.model.presented && r.model.phase == .activity)
        }

        test("island or capsule is decided once per take") {
            let r = Rig()
            r.show(.activity(symbol: "timer", title: "A"))
            r.prefs.style = .capsule
            r.island.update(.progress(title: "B"))
            expectEqual(r.model.kind, .notch, "mid-take: unchanged")
            r.island.dismiss()
            r.clock.advance(1)
            r.show(.activity(symbol: "timer", title: "A"))
            expectEqual(r.model.kind, .capsule)
            r.island.dismiss()
            r.clock.advance(1)
            r.prefs.style = .auto
            r.busy = true
            r.show(.activity(symbol: "timer", title: "A"))
            expectEqual(r.model.kind, .capsule, "another app holds the notch")
            expectEqual(r.model.capsuleTop, 32 + 8)
        }

        test("progress that takes longer: counter at 5 s, card at 10 s, reset when done") {
            let r = Rig()
            r.show(.progress(title: "x"))
            r.clock.advance(4.8)
            expect(r.model.slowSince == nil)
            r.clock.advance(0.2)
            expect(r.model.slowSince != nil && !r.model.slowHint)
            r.island.update(.progress(title: "x", fraction: 0.5))
            r.clock.advance(5)
            expect(r.model.slowHint, "fraction updates keep the clock")
            r.island.update(.done(title: "y"))
            expect(r.model.slowSince == nil && !r.model.slowHint)
        }

        test("Cancel on a slow progress: pointer tracked only once the card is down") {
            let r = Rig()
            var cancelled = false
            r.show(.progress(title: "x", cancel: IslandAction(id: "c", title: "Cancel") { cancelled = true }))
            expectEqual(r.clock.repeating, 1, "only the heal timer")
            r.clock.advance(10)
            expectEqual(r.clock.repeating, 2, "plus hover polling")
            r.pointerOnCard()
            r.mouse.x += 2
            r.clock.advance(0.1)
            expect(r.model.acceptsClicks && !r.host.clickThrough)
            expectEqual(r.model.hover, .none, "a progress never unfolds")
            r.model.content?.cancelAction?.perform()
            expect(cancelled)
        }

        test("hover: parked pointer waits, entering unfolds and freezes the timer, leaving folds after 0.6 s") {
            let r = Rig()
            r.prefs.confirmSeconds = 3
            r.pointerOnCard()  // the pointer rests where the card appears
            r.show(.done(title: "y", body: "Some text"))
            r.clock.advance(0.5)
            expectEqual(r.model.hover, .none, "parked pointer does not count")
            r.mouse.x += 3
            r.clock.advance(0.1)
            expectEqual(r.model.hover, .expanded)
            expect(r.model.acceptsClicks && !r.host.clickThrough)
            r.clock.advance(10)
            expect(r.island.isPresenting, "held while the pointer is on it")
            r.mouse = CGPoint(x: 100, y: 100)
            r.clock.advance(0.1)
            expect(r.host.clickThrough, "click-through again at once")
            expectEqual(r.model.hover, .expanded, "grace")
            r.clock.advance(0.6)
            expectEqual(r.model.hover, .collapsed)
            // remaining was ~2.4 s: hides then, not after 0.8 s
            r.clock.advance(1.0)
            expect(r.island.isPresenting)
            r.clock.advance(1.5)
            expect(!r.island.isPresenting)
        }

        test("hover: the menu bar strip does not unfold the notch card; a card without text does not track") {
            let r = Rig()
            r.show(.done(title: "y", body: "text"))
            r.model.cardFrame = CGRect(x: 120, y: 0, width: 400, height: 90)
            r.mouse = CGPoint(x: r.host.frame.midX, y: r.host.frame.maxY - 10)
            r.clock.advance(0.1)
            expectEqual(r.model.hover, .none)
            r.mouse.y -= 40
            r.clock.advance(0.1)
            expectEqual(r.model.hover, .expanded)

            let plain = Rig()
            plain.show(.done(title: "y"))
            expectEqual(plain.clock.repeating, 0)
            let off = Rig()
            off.prefs.hoverExpand = false
            off.show(.done(title: "y", body: "text"))
            expectEqual(off.clock.repeating, 0)
        }

        test("screens change: re-placed, moved when the display is gone, dismissed when a card loses it") {
            let r = Rig()
            r.show(.levels([]))
            r.screens = [Screens.external, Screens.mbp]
            r.island.screensChanged()
            expectEqual(r.host.orderIns.count, 1, "same display: only re-placed")
            r.screens = [Screens.external]
            r.mouse = CGPoint(x: 2000, y: 100)
            r.island.screensChanged()
            expectEqual(r.host.orderIns.count, 2, "running content restarts on the screen under the pointer")
            expectEqual(r.model.kind, .capsule)

            let card = Rig()
            card.show(.done(title: "y"))
            card.screens = [Screens.external]
            card.island.screensChanged()
            card.clock.advance(1)
            expect(card.model.content == nil, "quick dismiss")
        }

        test("self-heal: running content that is not really on screen is rebuilt and shown again") {
            let r = Rig()
            r.show(.levels([]))
            expectEqual(r.clock.repeating, 1, "heal timer while running")
            r.host.isReallyOnScreen = false
            r.clock.advance(0.3)
            expectEqual(r.host.rebuilds, 1, "the 0.35 s check")
            expectEqual(r.host.orderIns.count, 2)
            r.host.isReallyOnScreen = true
            r.clock.advance(2)
            expectEqual(r.host.orderIns.count, 2, "stays once on screen")
            r.island.update(.done(title: "y"))
            expectEqual(r.clock.repeating, 0, "no heal timer for cards")
        }

        test("headless: nothing ordered front, the virtual pointer drives hover") {
            let clock = ManualScheduler()
            let host = FakeIslandHost()
            let island = Island(deps: Island.Dependencies(
                scheduler: clock, makeHost: { _, _ in host }, screens: { [Screens.mbp] }, mouse: { .zero },
                prefs: { IslandPrefs() }, isFullscreen: { _ in false }, headless: true, playSound: { _ in }, haptic: {}))
            island.present(.done(title: "y", body: "text"))
            clock.advance(0.1)
            expect(!host.isVisible, "never ordered front")
            expect(island.model.presented)
            island.testPointer(inside: true)
            expectEqual(island.model.hover, .expanded)
            island.testPointer(inside: false)
            clock.advance(0.7)
            expectEqual(island.model.hover, .collapsed)
            island.stop()
            expect(island.model.content == nil)
        }
    }
}
#endif
#endif
