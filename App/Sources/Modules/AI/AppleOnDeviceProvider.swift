import Foundation
import FoundationModels
import Observation

/// Apple Intelligence's on-device model (FoundationModels): no download, no extra RAM in the app,
/// German and English among its languages. A fresh session per request (no hidden history).
/// Structured output uses `DynamicGenerationSchema`; the `@Generable` macro needs Xcode's plugin.
@Observable final class AppleOnDeviceProvider: LocalModelProvider {
    static let providerID = "apple"

    let id = AppleOnDeviceProvider.providerID
    let priority = 0
    var title: String { AIText.apple }
    var shortTitle: String { AIText.appleShort }
    var detail: String { AIText.appleDetail }
    let symbol = "apple.intelligence"
    let tint = TintName.indigo
    private(set) var availability: AIAvailability = .unavailable(.unknown)

    init() { refreshAvailability() }

    func refreshAvailability() {
        let now = Self.map(SystemLanguageModel.default.availability)
        if now != availability { availability = now }
    }

    /// FoundationModels availability → ours (pure, tested).
    nonisolated static func map(_ availability: SystemLanguageModel.Availability) -> AIAvailability {
        switch availability {
        case .available: .available
        case .unavailable(.deviceNotEligible): .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled): .unavailable(.appleIntelligenceOff)
        case .unavailable(.modelNotReady): .unavailable(.modelNotReady)
        case .unavailable: .unavailable(.unknown)
        }
    }

    /// FoundationModels errors → ours (pure, tested).
    nonisolated static func map(_ error: Error) -> AIError {
        if let e = error as? AIError { return e }
        if error is CancellationError { return .cancelled }
        guard let e = error as? LanguageModelSession.GenerationError else { return .failed(String(describing: error)) }
        switch e {
        case .exceededContextWindowSize: return .contextTooLong
        case .assetsUnavailable: return .unavailable(.modelNotReady)
        case .guardrailViolation, .refusal: return .guardrail
        case .unsupportedLanguageOrLocale: return .unsupportedLanguage
        case .rateLimited, .concurrentRequests: return .busy
        case .unsupportedGuide, .decodingFailure: return .failed(String(describing: e))
        @unknown default: return .failed(String(describing: e))
        }
    }

    private func session(_ request: AIRequest) throws -> LanguageModelSession {
        guard availability.isAvailable else { throw AIError.unavailable(availability.reason ?? .unknown) }
        guard SystemLanguageModel.default.supportsLocale(Localizer.shared.lang.locale) else { throw AIError.unsupportedLanguage }
        return LanguageModelSession(instructions: request.instructions)
    }

    private func options(_ request: AIRequest) -> GenerationOptions {
        GenerationOptions(temperature: request.temperature, maximumResponseTokens: request.maxTokens)
    }

    func respond(_ request: AIRequest) async throws -> String {
        do {
            let s = try session(request)
            return try await s.respond(to: request.prompt, options: options(request)).content
        } catch {
            throw Self.map(error)
        }
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    let s = try self.session(request)
                    for try await snapshot in s.streamResponse(to: request.prompt, options: self.options(request)) {
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func structured(_ request: AIRequest, schema: DynamicGenerationSchema, dependencies: [DynamicGenerationSchema]) async throws -> GeneratedContent {
        do {
            let s = try session(request)
            let generation = try GenerationSchema(root: schema, dependencies: dependencies)
            return try await s.respond(to: request.prompt, schema: generation, options: options(request)).content
        } catch {
            throw Self.map(error)
        }
    }
}
