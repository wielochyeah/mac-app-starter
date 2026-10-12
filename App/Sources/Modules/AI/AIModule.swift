import FoundationModels
import SwiftUI

/// Module `ai`: local language models behind `LocalAI.shared` (Apple Intelligence built in; the
/// `mlx` module adds an MLX provider). Contributes the settings pane "Models" (id `ai`), the
/// onboarding step "Local AI" (id `ai`, order 400), render scenes `ai.*`, gallery entries and
/// self-tests (`--selftest ai` also asks the real model).
enum AIModule {
    static func register() {
        LocalAI.shared.register(AppleOnDeviceProvider())

        Registry.settingsPanes.append(SettingsPane(id: "ai", group: .settings, order: 300, title: { AIText.pane },
                                                   symbol: "cpu", tint: .indigo) { AnyView(AISettingsPane()) })
        Registry.onboardingSteps.append(OnboardingStep(id: "ai", order: 400, isIncluded: { true }) { _ in
            AnyView(AIOnboardingStep())
        })
        AIScenes.register()
        registerSelfTests()
    }

    private static func registerSelfTests() {
        Registry.selfTests += [
            SelfTestCheck(id: "ai.providers") {
                let ai = LocalAI.shared
                guard ai.provider(AppleOnDeviceProvider.providerID) != nil else { return "Apple provider not registered" }
                let ids = ai.providers.map(\.id)
                guard Set(ids).count == ids.count else { return "duplicate provider ids \(ids)" }
                guard ai.active != nil else { return "no active provider" }
                return nil
            },
            SelfTestCheck(id: "ai.live.apple", onDemand: true) { liveApple() },
        ]
    }

    /// `--selftest ai`: a German question, a streamed answer and a structured answer from Apple
    /// Intelligence. Prints answers and times; fails when the model is unavailable.
    private static func liveApple() -> String? {
        let apple = AppleOnDeviceProvider()
        guard apple.availability.isAvailable else {
            return "Apple Intelligence unavailable (\(apple.availability.reason?.rawValue ?? "?"))"
        }
        let saved = Localizer.shared.forced
        Localizer.shared.forced = .de
        defer { Localizer.shared.forced = saved }
        let request = AIRequest(prompt: "Wofür ist die Menüleiste auf dem Mac da? Antworte in einem Satz.",
                                instructions: LocalAI.instructions(nil))

        var t = Date()
        switch AIWait.run(timeout: 60, { try await apple.respond(request) }) {
        case .value(let text):
            print("ai.live.apple respond (\(String(format: "%.2f", Date().timeIntervalSince(t))) s): \(text)")
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "empty answer" }
        case .failure(let e): return "respond failed: \(e)"
        case .timedOut: return "respond timed out after 60 s"
        }

        t = Date()
        var snapshots: [String] = []
        let streamed = AIWait.run(timeout: 60) { () async throws -> String in
            for try await s in apple.stream(AIRequest(prompt: "Zähle von eins bis fünf, mit Kommas.", instructions: request.instructions)) {
                snapshots.append(s)
            }
            return snapshots.last ?? ""
        }
        switch streamed {
        case .value(let text):
            print("ai.live.apple stream (\(snapshots.count) snapshots, \(String(format: "%.2f", Date().timeIntervalSince(t))) s): \(text)")
            if snapshots.count < 2 { return "stream gave \(snapshots.count) snapshot(s)" }
            for (a, b) in zip(snapshots, snapshots.dropFirst()) where b.count < a.count {
                return "stream snapshots do not grow: \(a) -> \(b)"
            }
        case .failure(let e): return "stream failed: \(e)"
        case .timedOut: return "stream timed out"
        }

        t = Date()
        let schema = DynamicGenerationSchema(name: "Idee", properties: [
            .init(name: "name", description: "Ein kurzer App-Name", schema: .init(type: String.self)),
            .init(name: "satz", description: "Ein Satz, was die App tut", schema: .init(type: String.self)),
        ])
        let structured = AIWait.run(timeout: 60) { () async throws -> (String, String) in
            let c = try await apple.structured(AIRequest(prompt: "Erfinde eine kleine Mac-App für Notizen.", instructions: request.instructions),
                                               schema: schema, dependencies: [])
            return (try c.value(String.self, forProperty: "name"), try c.value(String.self, forProperty: "satz"))
        }
        switch structured {
        case .value(let (name, sentence)):
            print("ai.live.apple structured (\(String(format: "%.2f", Date().timeIntervalSince(t))) s): \(name) / \(sentence)")
            if name.isEmpty || sentence.isEmpty { return "structured answer has empty fields" }
        case .failure(let e): return "structured failed: \(e)"
        case .timedOut: return "structured timed out"
        }
        return nil
    }
}
