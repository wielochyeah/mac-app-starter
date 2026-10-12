#if TESTING
import AppKit
import SwiftUI

final class OnboardingTests: TestSuite {
    static func step(_ id: String, _ order: Int, included: Bool = true) -> OnboardingStep {
        OnboardingStep(id: id, order: order, isIncluded: { included }) { _ in AnyView(EmptyView()) }
    }

    static var fiveSteps: [OnboardingStep] {
        [step("welcome", 0), step("language", 10), step("permission.microphone", 300), step("island", 500), step("done", 1000)]
    }

    static func settings() -> Settings { Settings(fileURL: tempDir().appendingPathComponent("settings.json")) }

    override class func register() {
        test("start index: top when done or new, else the saved step or the next one after it") {
            let steps = fiveSteps.map { (id: $0.id, order: $0.order) }
            expectEqual(OnboardingFlow.startIndex(steps: steps, done: false, resume: .none), 0)
            expectEqual(OnboardingFlow.startIndex(steps: steps, done: true, resume: .init(id: "island", order: 500)), 0)
            expectEqual(OnboardingFlow.startIndex(steps: steps, done: false, resume: .init(id: "island", order: 500)), 3)
            // the saved step is gone (module removed, permission dropped): continue with the next one
            expectEqual(OnboardingFlow.startIndex(steps: steps, done: false, resume: .init(id: "permission.camera", order: 301)), 3)
            expectEqual(OnboardingFlow.startIndex(steps: steps, done: false, resume: .init(id: "gone", order: 5000)), 0)
        }

        test("start index: a restart from a setup shown again from Settings comes back to its step") {
            let steps = fiveSteps.map { (id: $0.id, order: $0.order) }
            let island = OnboardingResumePoint(id: "island", order: 500)
            expectEqual(OnboardingFlow.startIndex(steps: steps, done: true, reopen: true, resume: island), 3)
            expectEqual(OnboardingFlow.startIndex(steps: steps, done: true, reopen: true, resume: .none), 0)
        }

        test("opens at launch: first run or a reopen, never without steps or in the background") {
            expect(OnboardingKit.opensAtLaunch(done: false, reopen: false, hasSteps: true, background: false))
            expect(!OnboardingKit.opensAtLaunch(done: true, reopen: false, hasSteps: true, background: false))
            expect(OnboardingKit.opensAtLaunch(done: true, reopen: true, hasSteps: true, background: false))
            expect(!OnboardingKit.opensAtLaunch(done: false, reopen: false, hasSteps: false, background: false))
            expect(!OnboardingKit.opensAtLaunch(done: false, reopen: true, hasSteps: true, background: true))
        }

        test("flow: a re-run restarted from a permission step reopens there once") {
            let store = settings()
            store[.onboardingDone] = true
            let first = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: store)
            expectEqual(first.index, 0, "shown again from Settings: from the top")
            first.go(to: 2)
            first.prepareRestart()
            first.isRelaunching = true
            first.leave()   // a window closing during the relaunch changes nothing
            expect(store[.onboardingReopen])
            // the new process
            let reopened = Settings(fileURL: store.fileURL)
            expect(OnboardingKit.opensAtLaunch(done: reopened[.onboardingDone], reopen: reopened[.onboardingReopen],
                                               hasSteps: true, background: false))
            let again = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: reopened)
            expectEqual(again.current?.id, "permission.microphone")
            expect(!reopened[.onboardingReopen], "used once")
            let later = Settings(fileURL: store.fileURL)
            expect(!OnboardingKit.opensAtLaunch(done: later[.onboardingDone], reopen: later[.onboardingReopen],
                                                hasSteps: true, background: false))
        }

        test("flow: closing the window by hand drops the reopen; a re-run also forgets its step") {
            let rerun = settings()
            rerun[.onboardingDone] = true
            let flow = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: rerun)
            flow.go(to: 2)
            flow.prepareRestart()   // asked for Screen Recording, then closed the window instead
            flow.leave()
            expect(!rerun[.onboardingReopen])
            expect(!rerun.hasValue(.onboardingResume))
            let first = settings()
            let firstFlow = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: first)
            firstFlow.go(to: 2)
            firstFlow.leave()
            expectEqual(first[.onboardingResume].id, "permission.microphone", "a first setup continues there next time")
        }

        test("lost permission: allowed at Done and missing or denied now reopens the setup there") {
            let mic = PermissionKind.microphone, ax = PermissionKind.accessibility, cam = PermissionKind.camera
            let allowed = [mic.id, ax.id]
            expectEqual(OnboardingKit.lostPermission(allowed: allowed, now: [(mic, .granted), (ax, .granted), (cam, .missing)]), nil,
                        "never allowed: not lost")
            expectEqual(OnboardingKit.lostPermission(allowed: allowed, now: [(mic, .granted), (ax, .missing)]), ax)
            expectEqual(OnboardingKit.lostPermission(allowed: allowed, now: [(mic, .denied), (ax, .missing)]), mic, "the first in step order")
            expectEqual(OnboardingKit.lostPermission(allowed: allowed, now: [(mic, .restartNeeded), (ax, .requested)]), nil)
            expectEqual(OnboardingKit.lostPermission(allowed: [], now: [(mic, .missing)]), nil)
        }

        test("flow: go(toStep:) jumps by id, unknown ids do nothing") {
            let flow = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: nil, startAt: 4)
            flow.go(toStep: "nope")
            expectEqual(flow.index, 4)
            flow.go(toStep: "permission.microphone")
            spin(1) { flow.index == 2 }
            expectEqual(flow.index, 2)
        }

        test("launch: --background and a login-item launch event mean no windows") {
            expect(LaunchFlags.parse(["app", "--background"]).background)
            expect(LaunchFlags.parse(["app", "--background"]).errors.isEmpty)
            let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEOpenApplication),
                                               targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                               transactionID: AETransactionID(kAnyTransactionID))
            expect(!Launch.isLoginItemLaunch(event))
            event.setParam(NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem)), forKeyword: AEKeyword(keyAEPropData))
            expect(Launch.isLoginItemLaunch(event))
            expect(!Launch.isLoginItemLaunch(nil))
            let reopen = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication),
                                                targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                                transactionID: AETransactionID(kAnyTransactionID))
            reopen.setParam(NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem)), forKeyword: AEKeyword(keyAEPropData))
            expect(!Launch.isLoginItemLaunch(reopen), "only the open event counts")
            expect(!Launch.isBackground, "tests are not launched at login")
        }

        test("registry steps: filtered by isIncluded, sorted by order then id") {
            Registry.withScratch {
                Registry.onboardingSteps = OnboardingKit.kitSteps(permissions: [.microphone, .accessibility], features: { [] })
                Registry.onboardingSteps += [step("module.later", 500), step("module.hidden", 450, included: false), step("a.same", 500)]
                expectEqual(Registry.orderedOnboardingSteps.map(\.id),
                            ["welcome", "language", "permission.microphone", "permission.accessibility", "a.same", "module.later", "done"])
            }
        }

        test("kit steps: features only with features, one step per permission in config order") {
            let features = OnboardingScenes.sampleFeatures
            let with = OnboardingKit.kitSteps(permissions: [.notifications], features: { features }).filter { $0.isIncluded() }
            expect(with.contains { $0.id == "features" })
            let steps = OnboardingKit.kitSteps(permissions: [.camera, .microphone], features: { [] })
            let included = steps.filter { $0.isIncluded() }.sorted { $0.order < $1.order }
            expect(!included.contains { $0.id == "features" })
            expectEqual(included.filter { $0.id.hasPrefix("permission.") }.map(\.order), [300, 301])
            expectEqual(included.first?.id, "welcome")
            expectEqual(included.last?.id, "done")
        }

        test("permissions in the onboarding: deduplicated, Local Network left to macOS") {
            expectEqual(OnboardingKit.onboardingPermissions([.microphone, .localNetwork, .microphone, .camera]), [.microphone, .camera])
        }

        test("features: at most three, by order") {
            let items = (0..<5).map { i in
                OnboardingFeature(id: "f\(i)", order: 10 - i, symbol: "star", title: { "\(i)" }, detail: { "" })
            }
            expectEqual(OnboardingFeatures.pick(items).map(\.id), ["f4", "f3", "f2"])
        }

        test("flow: next and back move, save the step, and Back waits one turn when the direction flips") {
            let store = settings()
            let flow = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: store)
            expectEqual(flow.index, 0)
            expect(flow.isFirst && flow.forward)
            flow.next()
            expectEqual(flow.index, 1)
            expectEqual(store[.onboardingResume], OnboardingResumePoint(id: "language", order: 10))
            flow.back()
            expect(!flow.forward, "direction flips first")
            expectEqual(flow.index, 1, "the index changes one runloop turn later")
            spin(1) { flow.index == 0 }
            expectEqual(flow.index, 0)
            flow.back()
            expectEqual(flow.index, 0, "no step before the first")
        }

        test("flow: reopens at the saved step (restart in the middle of the setup)") {
            let store = settings()
            let first = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: store)
            first.go(to: 2)
            expectEqual(store[.onboardingResume].id, "permission.microphone")
            // the app restarts: a new process, a new flow on the same settings file
            let again = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: Settings(fileURL: store.fileURL))
            expectEqual(again.current?.id, "permission.microphone")
        }

        test("flow: Done on the last step finishes once, marks done and forgets the step") {
            let store = settings()
            let flow = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: store, startAt: 4)
            var finished = 0
            flow.onFinish = { finished += 1 }
            flow.save()
            expect(flow.isLast)
            flow.next()
            flow.next()
            flow.finish()
            expectEqual(finished, 1, "Done pressed twice finishes once")
            expect(store[.onboardingDone])
            expect(!store.hasValue(.onboardingResume))
            // shown again later (from Settings): starts at the top
            let again = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: store)
            expectEqual(again.index, 0)
        }

        test("flow: renders write nothing") {
            let flow = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: nil, startAt: 2)
            flow.next()
            flow.next()
            flow.next()
            expectEqual(flow.index, 4)
        }

        test("footer: Continue, Done on the last step, canContinue disables and resets") {
            let flow = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: nil)
            expectEqual(flow.advance, OnboardingAdvance(isPrimary: true, title: CommonText.continue, isEnabled: true))
            flow.context.canContinue.wrappedValue = false
            expect(!flow.advance.isEnabled)
            flow.next()
            expect(flow.advance.isEnabled, "a new step starts enabled")
            flow.go(to: 4)
            expectEqual(flow.advance.title, OnboardingText.done)
        }

        test("footer: a permission step keeps Continue quiet until granted, Done names the restart") {
            let kinds: [PermissionKind] = [.microphone, .inputMonitoring]
            let rules = OnboardingKit.kitRules(permissions: kinds)
            let steps = OnboardingKit.kitSteps(permissions: kinds, features: { [] }).filter { $0.isIncluded() }.sorted { $0.order < $1.order }
            let micIndex = steps.firstIndex { $0.id == "permission.microphone" } ?? -1
            for (status, primary) in [(PermissionStatus.missing, false), (.requested, false), (.denied, false), (.granted, true)] {
                let flow = OnboardingFlow(steps: steps, monitor: .preview([.microphone: status]), settings: nil, rules: rules, startAt: micIndex)
                expectEqual(flow.advance.isPrimary, primary, "\(status)")
            }
            let restart = OnboardingFlow(steps: steps, monitor: .preview([.inputMonitoring: .restartNeeded]), settings: nil, rules: rules,
                                         startAt: steps.count - 1)
            expectEqual(restart.advance.title, OnboardingText.doneAndRestart)
            expect(restart.advance.isPrimary)
            let plain = OnboardingFlow(steps: steps, monitor: .preview([.inputMonitoring: .granted]), settings: nil, rules: rules,
                                       startAt: steps.count - 1)
            expectEqual(plain.advance.title, OnboardingText.done)
        }

        test("permission slot follows the status") {
            let monitor = PermissionMonitor.preview([:])
            let kinds: [(PermissionKind, PermissionStatus, OnboardingSlotState.Kind, Bool)] = [
                (.microphone, .missing, .action, true),
                (.microphone, .requested, .waiting, false),          // Apple's dialog is up: no button
                (.accessibility, .requested, .waiting, true),        // waiting for the switch: open Settings
                (.inputMonitoring, .denied, .denied, true),
                (.camera, .granted, .granted, false),
                (.screenRecording, .restartNeeded, .restartNeeded, true),
            ]
            for (kind, status, slot, hasButton) in kinds {
                let state = PermissionStep.slot(for: kind, status: status, monitor: monitor, restart: {})
                expectEqual(state.kind, slot, "\(kind.id) \(status)")
                expectEqual(state.button != nil, hasButton, "\(kind.id) \(status)")
            }
            // a dialog left unanswered for a while: System Settings as the way out
            let late = PermissionStep.slot(for: .notifications, status: .requested, monitor: monitor, waitedLong: true, restart: {})
            expectEqual(late.kind, .waiting)
            expect(late.button != nil)
        }

        test("permission slot: a restart kind saves the setup before macOS can restart the app") {
            let monitor = PermissionMonitor.preview([:])
            var prepared: [PermissionKind] = []
            for kind in [PermissionKind.inputMonitoring, .microphone] {
                for status in [PermissionStatus.missing, .denied] {
                    let state = PermissionStep.slot(for: kind, status: status, monitor: monitor,
                                                    willLeaveForRestart: { prepared.append(kind) }, restart: {})
                    state.button?.action()
                }
            }
            expectEqual(prepared, [.inputMonitoring, .inputMonitoring], "only Input Monitoring and Screen Recording")
        }

        test("kit registration: steps, rules, scenes and checks are there") {
            let ids = Set(Registry.onboardingSteps.map(\.id))
            expect(ids.isSuperset(of: ["welcome", "language", "features", "done"]))
            for kind in OnboardingKit.onboardingPermissions(PermissionsKit.configured) {
                expect(ids.contains("permission.\(kind.id)"), kind.id)
                expect(OnboardingKit.advanceRules["permission.\(kind.id)"] != nil, kind.id)
            }
            let scenes = Set(Registry.renderScenes.map(\.id))
            for name in ["welcome", "language", "features", "done", "done-restart", "permission-missing", "permission-requested",
                         "permission-denied", "permission-granted", "permission-restart"] {
                expect(scenes.contains("onboarding.\(name)"), name)
            }
            expect(AppActions.onboardingHandler != nil)
            expect(Registry.selfTests.contains { $0.id == "onboarding.window" })
        }

        test("the root view is exactly the onboarding window and every scene renders") {
            let flow = OnboardingFlow(steps: fiveSteps, monitor: .preview([:]), settings: nil)
            let size = NSHostingController(rootView: OnboardingRootView(flow: flow))
                .sizeThatFits(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
            expectEqual(size, Metrics.onboardingWindow)
            for scene in Registry.orderedRenderScenes where scene.id.hasPrefix("onboarding.") {
                let png = RenderRunner.png(scene.content(), size: scene.size, appearance: .dark, lang: .de)
                expect((png?.count ?? 0) > 10_000, "\(scene.id) did not render")
            }
        }

        test("texts: both languages, no exclamation marks, the cross hint is in the other language") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            @MainActor func texts() -> [String] {
                [OnboardingText.doneSubtitle, OnboardingText.doneFootnote, OnboardingText.done, OnboardingText.doneTitle(complete: false),
                 OnboardingText.doneMissing(["Mikrofon"], collapsed: false), OnboardingText.doneMissing(["A", "B"], collapsed: true),
                 OnboardingText.languageFootnote, OnboardingText.followMacDetail("X", offered: false)]
            }
            Localizer.shared.forced = .de
            expect(OnboardingText.languageCrossHint.hasPrefix("Prefer English"))
            let de = texts()
            Localizer.shared.forced = .en
            expect(OnboardingText.languageCrossHint.hasPrefix("Lieber auf Deutsch"))
            let en = texts()
            for (a, b) in zip(de, en) {
                expect(a != b && !a.contains("!") && !b.contains("!"), "\(a) / \(b)")
            }
            expectEqual(OnboardingText.welcomeNote(steps: 6), "Setup takes 6 short steps.")
        }

        test("welcome: the lede is the project's tagline, nothing when it is empty") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            Localizer.shared.forced = .en
            let lede = OnboardingText.welcomeLede
            expectEqual(lede, AppConfig.tagline.en.isEmpty ? nil : AppConfig.tagline.en)
            Localizer.shared.forced = .de
            if !AppConfig.tagline.de.isEmpty { expectEqual(OnboardingText.welcomeLede, AppConfig.tagline.de) }
        }

        test("done: All Set only when every permission is allowed") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            Localizer.shared.forced = .en
            expectEqual(OnboardingText.doneTitle(complete: true), "All Set")
            expectEqual(OnboardingText.doneTitle(complete: false), "Almost Done")
            expect(OnboardingText.doneMissing(["Input Monitoring"], collapsed: false).hasPrefix("Input Monitoring is not allowed yet."))
            expect(OnboardingText.doneMissing(["A", "B"], collapsed: false).hasPrefix("2 permissions"))
        }

        test("language: \"same as the Mac\" only when the Mac's first language is offered") {
            expect(OnboardingKit.macLanguageOffered(["de-DE", "en-US"]))
            expect(OnboardingKit.macLanguageOffered(["en-GB"]))
            expect(!OnboardingKit.macLanguageOffered(["fr-FR", "en-US"]), "English is the fallback here, not the Mac's language")
            expect(!OnboardingKit.macLanguageOffered([]))
        }
    }
}
#endif
