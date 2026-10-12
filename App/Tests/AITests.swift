#if TESTING
#if MODUL_AI
import AppKit
import FoundationModels
import Observation
import SwiftUI

/// A provider without a model: answers "echo: <prompt>" word by word, records what it got.
final class FakeAIProvider: LocalModelProvider {
    let id: String
    let priority: Int
    var availability: AIAvailability
    var title: String { id }
    var shortTitle: String { id }
    var detail: String { "" }
    let symbol = "cpu"
    let tint = TintName.indigo
    var requests: [AIRequest] = []
    var failWith: AIError?
    var wordDelay: Duration = .zero
    var sawCancel = false
    /// What the next `refreshAvailability()` reads (the system changed behind the app's back).
    var live: AIAvailability?
    var refreshes = 0

    init(_ id: String, priority: Int = 0, availability: AIAvailability = .available) {
        self.id = id
        self.priority = priority
        self.availability = availability
    }

    func refreshAvailability() {
        refreshes += 1
        if let live { availability = live }
    }

    func respond(_ request: AIRequest) async throws -> String {
        requests.append(request)
        if let failWith { throw failWith }
        return "echo: " + request.prompt
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<String, Error> {
        requests.append(request)
        let words = ("echo: " + request.prompt).split(separator: " ").map(String.init)
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                var text = ""
                for w in words {
                    if self.wordDelay != .zero { try? await Task.sleep(for: self.wordDelay) }
                    if Task.isCancelled {
                        self.sawCancel = true
                        continuation.finish(throwing: CancellationError())
                        return
                    }
                    text += text.isEmpty ? w : " " + w
                    continuation.yield(text)
                }
                if let failWith = self.failWith { continuation.finish(throwing: failWith) } else { continuation.finish() }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// A count that observation callbacks may bump from any thread.
nonisolated final class AINotifyCount: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    var value: Int { lock.withLock { n } }
    func add() { lock.withLock { n += 1 } }
}

final class AITests: TestSuite {
    static func makeAI(_ providers: [FakeAIProvider]) -> LocalAI {
        let ai = LocalAI()
        ai.settings = Settings(fileURL: tempDir().appendingPathComponent("settings.json"))
        for p in providers { ai.register(p) }
        return ai
    }

    override class func register() {
        test("automatic picks the first available provider by priority") {
            let r = ProviderChoice.resolve("auto", [.init(id: "apple", availability: .available),
                                                    .init(id: "mlx", availability: .available)])
            expectEqual(r.id, "apple")
            let fallback = ProviderChoice.resolve("auto", [.init(id: "apple", availability: .unavailable(.deviceNotEligible)),
                                                           .init(id: "mlx", availability: .available)])
            expectEqual(fallback.id, "mlx")
            expectEqual(fallback.availability, .available)
        }

        test("automatic with nothing available explains the easiest fix") {
            let r = ProviderChoice.resolve("auto", [.init(id: "apple", availability: .unavailable(.deviceNotEligible)),
                                                    .init(id: "mlx", availability: .unavailable(.modelMissing))])
            expectEqual(r.id, "mlx")
            expectEqual(r.availability, .unavailable(.modelMissing))
            let tie = ProviderChoice.resolve("auto", [.init(id: "apple", availability: .unavailable(.appleIntelligenceOff)),
                                                      .init(id: "mlx", availability: .unavailable(.modelMissing))])
            expectEqual(tie.id, "apple", "same rank: priority order")
            let none = ProviderChoice.resolve("auto", [])
            expect(none.id == nil)
            expectEqual(none.availability, .unavailable(.unknown))
        }

        test("an explicit choice wins, a removed provider counts as automatic") {
            let c: [ProviderChoice.Candidate] = [.init(id: "apple", availability: .available),
                                                 .init(id: "mlx", availability: .unavailable(.modelMissing))]
            let picked = ProviderChoice.resolve("mlx", c)
            expectEqual(picked.id, "mlx")
            expectEqual(picked.availability, .unavailable(.modelMissing))
            expectEqual(ProviderChoice.resolve("gone", c).id, "apple")
        }

        test("Apple availability maps to our reasons") {
            expectEqual(AppleOnDeviceProvider.map(.available), .available)
            expectEqual(AppleOnDeviceProvider.map(.unavailable(.deviceNotEligible)), .unavailable(.deviceNotEligible))
            expectEqual(AppleOnDeviceProvider.map(.unavailable(.appleIntelligenceNotEnabled)), .unavailable(.appleIntelligenceOff))
            expectEqual(AppleOnDeviceProvider.map(.unavailable(.modelNotReady)), .unavailable(.modelNotReady))
        }

        test("Apple errors map to short user errors") {
            let ctx = LanguageModelSession.GenerationError.Context(debugDescription: "x")
            typealias G = LanguageModelSession.GenerationError
            expectEqual(AppleOnDeviceProvider.map(G.exceededContextWindowSize(ctx)), .contextTooLong)
            expectEqual(AppleOnDeviceProvider.map(G.guardrailViolation(ctx)), .guardrail)
            expectEqual(AppleOnDeviceProvider.map(G.unsupportedLanguageOrLocale(ctx)), .unsupportedLanguage)
            expectEqual(AppleOnDeviceProvider.map(G.rateLimited(ctx)), .busy)
            expectEqual(AppleOnDeviceProvider.map(G.concurrentRequests(ctx)), .busy)
            expectEqual(AppleOnDeviceProvider.map(G.assetsUnavailable(ctx)), .unavailable(.modelNotReady))
            expectEqual(AppleOnDeviceProvider.map(CancellationError()), .cancelled)
            expectEqual(AppleOnDeviceProvider.map(AIError.timeout), .timeout)
            if case .failed = AppleOnDeviceProvider.map(G.decodingFailure(ctx)) {} else { fail("decoding failure is .failed") }
        }

        test("every reason and error has both languages") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            var errors: [AIError] = [.cancelled, .timeout, .contextTooLong, .guardrail, .unsupportedLanguage, .busy, .unsupported,
                                     .restarting(5), .workerCrashed, .failed("x")]
            errors += AIUnavailableReason.allCases.map { .unavailable($0) }
            for reason in AIUnavailableReason.allCases {
                Localizer.shared.forced = .en
                let en = [AIText.statusWord(reason), AIText.reasonTitle(reason), AIText.reasonHint(reason)]
                Localizer.shared.forced = .de
                let de = [AIText.statusWord(reason), AIText.reasonTitle(reason), AIText.reasonHint(reason)]
                expect(!en.contains("") && !de.contains(""), "\(reason)")
                expect(en != de, "\(reason) has German texts")
            }
            for e in errors {
                Localizer.shared.forced = .de
                expect(!AIText.error(e).isEmpty, "\(e)")
            }
            Localizer.shared.forced = .de
            expect(AIText.error(.restarting(4.2)).contains("5"), "rounds the wait up")
        }

        test("respond goes to the active provider with the reply-language line") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            Localizer.shared.forced = .de
            let apple = FakeAIProvider("apple")
            let ai = makeAI([apple])
            let out = AIWait.run(timeout: 5) { try await ai.respond(prompt: "hallo", instructions: "Kurz.") }
            guard case .value(let text) = out else { return fail("no answer: \(out)") }
            expectEqual(text, "echo: hallo")
            expectEqual(apple.requests.first?.instructions, "Kurz.\nAntworte auf Deutsch.")
            expectEqual(ai.usage.requests, 1)
            expectEqual(ai.usage.failures, 0)
            expectEqual(ai.usage.lastProvider, "apple")
            expect(ai.usage.lastLatency != nil)
        }

        test("unavailable provider throws its reason and nothing reaches it") {
            let apple = FakeAIProvider("apple", availability: .unavailable(.appleIntelligenceOff))
            let ai = makeAI([apple])
            let out = AIWait.run(timeout: 5) { try await ai.respond(prompt: "x") }
            guard case .failure(let e) = out else { return fail("expected an error") }
            expectEqual(e as? AIError, .unavailable(.appleIntelligenceOff))
            expect(apple.requests.isEmpty)
            expectEqual(ai.availability, .unavailable(.appleIntelligenceOff))
        }

        test("automatic falls back to the second provider") {
            let apple = FakeAIProvider("apple", availability: .unavailable(.deviceNotEligible))
            let mlx = FakeAIProvider("mlx", priority: 10)
            let ai = makeAI([mlx, apple])
            expectEqual(ai.providers.map(\.id), ["apple", "mlx"], "sorted by priority")
            expectEqual(ai.active?.id, "mlx")
            _ = AIWait.run(timeout: 5) { try await ai.respond(prompt: "x") }
            expectEqual(mlx.requests.count, 1)
            ai.choice = "apple"
            expectEqual(ai.active?.id, "apple")
            expectEqual(ai.availability, .unavailable(.deviceNotEligible))
        }

        test("a request re-reads availability: switched on after launch, no pane opened") {
            let apple = FakeAIProvider("apple", availability: .unavailable(.appleIntelligenceOff))
            let ai = makeAI([apple])
            apple.live = .available
            let out = AIWait.run(timeout: 5) { try await ai.respond(prompt: "x") }
            guard case .value(let text) = out else { return fail("no answer: \(out)") }
            expectEqual(text, "echo: x")
            let streamed = AIWait.run(timeout: 5) { () async throws -> String in
                var last = ""
                for try await s in ai.stream(prompt: "y") { last = s }
                return last
            }
            guard case .value("echo: y") = streamed else { return fail("stream: \(streamed)") }
        }

        test("automatic falls back as soon as the first provider is switched off") {
            let apple = FakeAIProvider("apple")
            let mlx = FakeAIProvider("mlx", priority: 10)
            let ai = makeAI([apple, mlx])
            apple.live = .unavailable(.appleIntelligenceOff)
            _ = AIWait.run(timeout: 5) { try await ai.respond(prompt: "x") }
            expectEqual(apple.requests.count, 0)
            expectEqual(mlx.requests.count, 1)
        }

        test("refresh notifies observers only when availability changed") {
            let apple = FakeAIProvider("apple")
            let ai = makeAI([apple])
            let notified = AINotifyCount()
            withObservationTracking { _ = ai.availability } onChange: { notified.add() }
            ai.refresh()
            expectEqual(notified.value, 0, "nothing changed")
            expectEqual(apple.refreshes, 1)
            apple.live = .unavailable(.modelNotReady)
            ai.refresh()
            expectEqual(notified.value, 1)
            expectEqual(ai.availability, .unavailable(.modelNotReady))
        }

        test("failures are counted, cancellations are not") {
            let apple = FakeAIProvider("apple")
            apple.failWith = .busy
            let ai = makeAI([apple])
            let out = AIWait.run(timeout: 5) { try await ai.respond(prompt: "x") }
            guard case .failure(let e) = out else { return fail("expected an error") }
            expectEqual(e as? AIError, .busy)
            expectEqual(ai.usage.failures, 1)
            apple.failWith = .cancelled
            _ = AIWait.run(timeout: 5) { try await ai.respond(prompt: "x") }
            expectEqual(ai.usage.requests, 1)
        }

        test("stream yields the growing answer") {
            let ai = makeAI([FakeAIProvider("apple")])
            var seen: [String] = []
            let out = AIWait.run(timeout: 5) { () async throws -> Int in
                for try await s in ai.stream(prompt: "eins zwei drei") { seen.append(s) }
                return seen.count
            }
            guard case .value = out else { return fail("stream failed: \(out)") }
            expectEqual(seen, ["echo:", "echo: eins", "echo: eins zwei", "echo: eins zwei drei"])
            expectEqual(ai.usage.requests, 1)
        }

        test("cancelling the consumer stops the provider's stream") {
            let apple = FakeAIProvider("apple")
            apple.wordDelay = .milliseconds(50)
            let ai = makeAI([apple])
            let out = AIWait.run(timeout: 5) { () async throws -> Void in
                let task = Task { @MainActor in
                    for try await _ in ai.stream(prompt: String(repeating: "w ", count: 50)) {}
                }
                try await Task.sleep(for: .milliseconds(120))
                task.cancel()
                _ = await task.result
            }
            guard case .value = out else { return fail("\(out)") }
            expect(AIWait.until(timeout: 2) { apple.sawCancel }, "provider saw the cancel")
            expectEqual(ai.usage.requests, 0, "a cancelled stream is not counted")
        }

        test("structured output needs Apple and says so") {
            let ai = makeAI([FakeAIProvider("mlx")])
            let schema = DynamicGenerationSchema(name: "N", properties: [.init(name: "t", schema: .init(type: String.self))])
            let out = AIWait.run(timeout: 5) { try await ai.structured(prompt: "x", schema: schema) }
            guard case .failure(let e) = out else { return fail("expected an error") }
            expectEqual(e as? AIError, .unsupported)
        }

        test("try it: Stop shows no finished time, an old run never touches a new one") {
            let p = FakeAIProvider("a")
            p.wordDelay = .milliseconds(80)
            let ai = makeAI([p])
            let trial = AITrial()
            trial.prompt = "a b c d e f g h i j"
            trial.send(ai)
            expect(AIWait.until(timeout: 5) { !trial.answer.isEmpty }, "first piece")
            trial.stop()
            _ = AIWait.until(timeout: 0.4) { false }
            expect(!trial.running)
            expect(trial.latency == nil, "a stopped answer has no answer time")
            trial.send(ai)
            expect(trial.running)
            _ = AIWait.until(timeout: 0.3) { false }
            expect(trial.running, "the replaced run did not end the new one")
            expect(trial.latency == nil)
            expect(AIWait.until(timeout: 5) { !trial.running }, "the new run finishes")
            expectEqual(trial.answer, "echo: a b c d e f g h i j")
            expect(trial.latency != nil)
            trial.prompt = "   "
            trial.send(ai)
            expect(!trial.running, "an empty field sends nothing")
        }

        test("usage keeps only counts and durations") {
            var u = AIUsage()
            u.record(provider: "apple", latency: 1.5, ok: true, at: Date(timeIntervalSince1970: 10))
            u.record(provider: "mlx", latency: 9, ok: false, at: Date(timeIntervalSince1970: 20))
            expectEqual(u.requests, 2)
            expectEqual(u.failures, 1)
            expectEqual(u.lastLatency, 1.5)
            expectEqual(u.lastProvider, "apple")
            let json = String(decoding: (try? JSONEncoder().encode(u)) ?? Data(), as: UTF8.self)
            expect(!json.contains("prompt"), json)
        }

        test("the module registers pane, step, scenes and the Apple provider") {
            expect(Registry.settingsPanes.contains { $0.id == "ai" })
            expect(Registry.onboardingSteps.contains { $0.id == "ai" && $0.order == 400 })
            for id in ["ai.pane", "ai.pane-unavailable", "ai.pane-not-ready", "ai.onboarding", "ai.onboarding-unavailable", "ai.download-rows"] {
                expect(Registry.renderScenes.contains { $0.id == id }, id)
            }
            expect(LocalAI.shared.provider("apple") != nil)
        }

        test("ai scenes render in both appearances and languages") {
            for scene in Registry.renderScenes where scene.id.hasPrefix("ai.") {
                for (appearance, lang) in [(Appearance.light, Lang.de), (.dark, .en)] {
                    let png = RenderRunner.png(scene.content(), size: scene.size, appearance: appearance, lang: lang)
                    expect((png?.count ?? 0) > 5_000, "\(scene.id) \(appearance) \(lang)")
                }
            }
        }
    }
}
#endif
#endif
