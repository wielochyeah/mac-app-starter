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
            Localizer.shared.forced = .de
            expect(OnboardingText.languageCrossHint.hasPrefix("Prefer English"))
            let de = [OnboardingText.welcomeLede, OnboardingText.doneSubtitle, OnboardingText.doneFootnote, OnboardingText.done]
            Localizer.shared.forced = .en
            expect(OnboardingText.languageCrossHint.hasPrefix("Lieber auf Deutsch"))
            let en = [OnboardingText.welcomeLede, OnboardingText.doneSubtitle, OnboardingText.doneFootnote, OnboardingText.done]
            for (a, b) in zip(de, en) {
                expect(a != b && !a.contains("!") && !b.contains("!"), "\(a) / \(b)")
            }
            expectEqual(OnboardingText.welcomeNote(steps: 6), "6 steps. You can change everything later in Settings.")
        }
    }
}
#endif
