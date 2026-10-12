import Foundation
import FoundationModels
import Observation
import SwiftUI

// The local AI facade. Features call `LocalAI.shared`; it picks a provider (Apple Intelligence
// built in, MLX when that module is compiled in) from the setting `ai.provider`.
//
//     let summary = try await LocalAI.shared.respond(prompt: text, instructions: "Summarise in one sentence.")
//     for try await partial in LocalAI.shared.stream(prompt: question) { answer = partial }
//
// Everything runs on this Mac. Prompts and answers are never logged or stored (only counts and
// durations, see `AIUsage`). Cancel by cancelling the calling Task.

// MARK: - Availability and errors

/// Why no answer can come from a provider right now. Each has a status word, a title and a fix
/// hint in `AIText`.
nonisolated enum AIUnavailableReason: String, CaseIterable, Sendable {
    /// Apple Intelligence: this Mac cannot run it.
    case deviceNotEligible
    /// Apple Intelligence is switched off in System Settings.
    case appleIntelligenceOff
    /// Apple Intelligence is on, the model is still downloading.
    case modelNotReady
    /// MLX: not an Apple silicon Mac.
    case unsupportedHardware
    /// MLX: macOS older than the MLX build needs (26.2).
    case systemTooOld
    /// MLX: the worker or its Python environment is missing (`ai-worker/setup.sh`).
    case notInstalled
    /// MLX: the chosen model is not downloaded.
    case modelMissing
    case unknown

    /// Lower = the user can fix it here and now (preferred when explaining "automatic").
    var fixRank: Int {
        switch self {
        case .modelMissing, .appleIntelligenceOff: 0
        case .modelNotReady: 1
        case .notInstalled, .systemTooOld: 2
        case .deviceNotEligible, .unsupportedHardware, .unknown: 3
        }
    }
}

nonisolated enum AIAvailability: Equatable, Sendable {
    case available
    case unavailable(AIUnavailableReason)

    var isAvailable: Bool { self == .available }

    var reason: AIUnavailableReason? {
        if case .unavailable(let r) = self { return r }
        return nil
    }
}

/// Errors from `LocalAI`, each with a short user text (`AIText.error`).
nonisolated enum AIError: Error, Equatable, Sendable {
    case unavailable(AIUnavailableReason)
    case cancelled
    case timeout
    case contextTooLong
    case guardrail
    case unsupportedLanguage
    case busy
    /// The provider cannot do this (e.g. structured output on MLX).
    case unsupported
    /// The worker crashed; the next start waits this many seconds (restart backoff).
    case restarting(TimeInterval)
    case workerCrashed
    /// Anything else; the detail is for the log only, never shown.
    case failed(String)

    /// Maps any error (a CancellationError included) to an AIError.
    static func from(_ error: Error) -> AIError {
        if let e = error as? AIError { return e }
        if error is CancellationError { return .cancelled }
        return .failed(String(describing: error))
    }
}

// MARK: - Requests and providers

nonisolated struct AIRequest: Sendable {
    var prompt: String
    /// System instructions; the reply-language line is appended by `LocalAI`.
    var instructions: String?
    /// nil = the provider's default (scales with the prompt for MLX).
    var maxTokens: Int?
    /// nil = the provider's default (0 = greedy for MLX).
    var temperature: Double?
}

/// A local model behind `LocalAI`. Apple Intelligence (this module) and MLX (module mlx) implement it.
protocol LocalModelProvider: AnyObject {
    /// "apple", "mlx" (stored in the `ai.provider` setting).
    var id: String { get }
    /// Lower comes first in "automatic".
    var priority: Int { get }
    var title: String { get }
    /// Short name for the provider picker.
    var shortTitle: String { get }
    var detail: String { get }
    var symbol: String { get }
    var tint: TintName { get }
    var availability: AIAvailability { get }
    /// Re-reads availability (cheap; called when the pane opens and while it shows a problem).
    func refreshAvailability()
    func respond(_ request: AIRequest) async throws -> String
    /// Each element is the whole answer so far (not a delta).
    func stream(_ request: AIRequest) -> AsyncThrowingStream<String, Error>
}

/// A section another module adds to the Models pane and (optionally) to the Local AI step.
struct AIPaneSection: Identifiable {
    let id: String
    let order: Int
    let pane: () -> AnyView
    var onboarding: (() -> AnyView)?
}

// MARK: - Provider choice (pure, tested)

enum ProviderChoice {
    static let automatic = "auto"

    struct Candidate: Equatable {
        let id: String
        let availability: AIAvailability
    }

    /// The provider to use and what is wrong if none can answer. `candidates` in priority order.
    /// An explicit choice wins even when that provider is unavailable (the user picked it); an
    /// unknown id (a removed module) counts as automatic. Automatic takes the first available one,
    /// else the one whose problem is easiest to fix here.
    static func resolve(_ choice: String, _ candidates: [Candidate]) -> (id: String?, availability: AIAvailability) {
        if choice != automatic, let picked = candidates.first(where: { $0.id == choice }) {
            return (picked.id, picked.availability)
        }
        if let ready = candidates.first(where: { $0.availability.isAvailable }) {
            return (ready.id, .available)
        }
        let best = candidates.enumerated().min { a, b in
            let ra = a.element.availability.reason?.fixRank ?? 9, rb = b.element.availability.reason?.fixRank ?? 9
            return (ra, a.offset) < (rb, b.offset)
        }?.element
        guard let best else { return (nil, .unavailable(.unknown)) }
        return (best.id, best.availability)
    }
}

extension SettingKey {
    /// "auto" or a provider id ("apple", "mlx").
    static var aiProvider: SettingKey<String> { .init("ai.provider", default: ProviderChoice.automatic) }
    static var aiUsage: SettingKey<AIUsage> { .init("ai.usage", default: AIUsage()) }
}

// MARK: - Usage log (counts and durations only)

nonisolated struct AIUsage: Codable, Equatable, Sendable {
    var requests = 0
    var failures = 0
    var lastLatency: Double?
    var lastProvider: String?
    var lastAt: Date?

    mutating func record(provider: String, latency: Double?, ok: Bool, at date: Date) {
        requests += 1
        if !ok { failures += 1 }
        if ok, let latency {
            lastLatency = latency
            lastProvider = provider
            lastAt = date
        }
    }
}

// MARK: - The facade

@Observable final class LocalAI {
    static let shared = LocalAI()

    private(set) var providers: [any LocalModelProvider] = []
    /// Sections other modules add to the pane and step (MLX: its models).
    var sections: [AIPaneSection] = []
    /// Bumped by `refresh()` so views that show availability redraw.
    private(set) var revision = 0
    @ObservationIgnored var settings: Settings = .shared
    @ObservationIgnored var clock: () -> Date = Date.init

    init() {}

    func register(_ provider: any LocalModelProvider) {
        providers.removeAll { $0.id == provider.id }
        providers.append(provider)
        providers.sort { ($0.priority, $0.id) < ($1.priority, $1.id) }
    }

    func provider(_ id: String) -> (any LocalModelProvider)? { providers.first { $0.id == id } }

    var choice: String {
        get { settings[.aiProvider] }
        set { settings[.aiProvider] = newValue }
    }

    var usage: AIUsage { settings[.aiUsage] }

    private var resolved: (id: String?, availability: AIAvailability) {
        _ = revision
        return ProviderChoice.resolve(choice, providers.map { .init(id: $0.id, availability: $0.availability) })
    }

    /// The provider requests go to (nil when none is registered).
    var active: (any LocalModelProvider)? { resolved.id.flatMap(provider) }

    /// Whether `respond`/`stream` can answer now, and if not, why.
    var availability: AIAvailability { resolved.availability }

    func refresh() {
        for p in providers { p.refreshAvailability() }
        revision += 1
    }

    // MARK: Requests

    /// One answer. Throws `AIError`; cancelling the Task stops the model.
    func respond(prompt: String, instructions: String? = nil, maxTokens: Int? = nil, temperature: Double? = nil) async throws -> String {
        let (provider, request) = try prepare(prompt, instructions, maxTokens, temperature)
        let start = clock()
        do {
            let text = try await provider.respond(request)
            record(provider.id, start, ok: true)
            return text
        } catch {
            let e = AIError.from(error)
            if e != .cancelled { record(provider.id, start, ok: false) }
            throw e
        }
    }

    /// The answer as it grows: each element is the whole text so far.
    func stream(prompt: String, instructions: String? = nil, maxTokens: Int? = nil, temperature: Double? = nil) -> AsyncThrowingStream<String, Error> {
        let prepared: (any LocalModelProvider, AIRequest)
        do {
            prepared = try prepare(prompt, instructions, maxTokens, temperature)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        let (provider, request) = prepared
        let start = clock()
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    for try await snapshot in provider.stream(request) { continuation.yield(snapshot) }
                    // a cancelled iteration ends quietly; that is not an answer
                    try Task.checkCancellation()
                    self.record(provider.id, start, ok: true)
                    continuation.finish()
                } catch {
                    let e = AIError.from(error)
                    if e != .cancelled { self.record(provider.id, start, ok: false) }
                    continuation.finish(throwing: e)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Structured output with a schema built at run time (the `@Generable` macro needs Xcode).
    /// Only Apple Intelligence supports this; with another provider active it still uses Apple
    /// when available, else throws `.unsupported` / `.unavailable`.
    ///
    ///     let schema = DynamicGenerationSchema(name: "Note", properties: [
    ///         .init(name: "title", schema: .init(type: String.self))])
    ///     let content = try await LocalAI.shared.structured(prompt: text, schema: schema)
    ///     let title = try content.value(String.self, forProperty: "title")
    func structured(prompt: String, schema: DynamicGenerationSchema, dependencies: [DynamicGenerationSchema] = [],
                    instructions: String? = nil) async throws -> GeneratedContent {
        guard let apple = provider(AppleOnDeviceProvider.providerID) as? AppleOnDeviceProvider else { throw AIError.unsupported }
        guard apple.availability.isAvailable else {
            throw (active?.id == apple.id || active == nil) ? AIError.unavailable(apple.availability.reason ?? .unknown) : AIError.unsupported
        }
        let request = AIRequest(prompt: prompt, instructions: Self.instructions(instructions))
        let start = clock()
        do {
            let content = try await apple.structured(request, schema: schema, dependencies: dependencies)
            record(apple.id, start, ok: true)
            return content
        } catch {
            let e = AIError.from(error)
            if e != .cancelled { record(apple.id, start, ok: false) }
            throw e
        }
    }

    private func prepare(_ prompt: String, _ instructions: String?, _ maxTokens: Int?, _ temperature: Double?) throws -> (any LocalModelProvider, AIRequest) {
        let (id, availability) = resolved
        guard let id, let provider = provider(id) else { throw AIError.unavailable(.unknown) }
        if case .unavailable(let reason) = availability { throw AIError.unavailable(reason) }
        return (provider, AIRequest(prompt: prompt, instructions: Self.instructions(instructions), maxTokens: maxTokens,
                                    temperature: temperature))
    }

    /// The caller's instructions plus the reply-language line.
    static func instructions(_ base: String?) -> String {
        let base = base?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return base.isEmpty ? AIText.replyLanguage : base + "\n" + AIText.replyLanguage
    }

    private func record(_ provider: String, _ start: Date, ok: Bool) {
        var u = settings[.aiUsage]
        u.record(provider: provider, latency: clock().timeIntervalSince(start), ok: ok, at: clock())
        settings[.aiUsage] = u
    }
}
