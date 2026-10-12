import Foundation
import Observation

extension SettingKey {
    /// The catalog id of the model MLX answers with (ai-worker/models.json).
    static var mlxModel: SettingKey<String> { .init("mlx.model", default: "") }
}

/// `LocalModelProvider` for the MLX worker (module mlx): a catalog model, downloaded on request,
/// run by ai-worker/worker.py through `MLXWorkerClient`.
@Observable final class MLXProvider: LocalModelProvider {
    static let providerID = "mlx"

    let id = MLXProvider.providerID
    let priority = 10
    var title: String { MLXText.title }
    var shortTitle: String { MLXText.title }
    var detail: String { MLXText.detail }
    let symbol = "square.stack.3d.up.fill"
    let tint = TintName.teal
    private(set) var availability: AIAvailability = .unavailable(.unknown)

    let client: MLXWorkerClient
    let downloads: ModelDownloads
    @ObservationIgnored var settings: Settings
    /// Whether the worker folder and its Python exist (injected in tests).
    @ObservationIgnored var isInstalled: () -> Bool

    init(client: MLXWorkerClient, downloads: ModelDownloads, settings: Settings = .shared, isInstalled: @escaping () -> Bool) {
        self.client = client
        self.downloads = downloads
        self.settings = settings
        self.isInstalled = isInstalled
        refreshAvailability()
    }

    /// The app's provider: worker and Python found by `MLXPaths`, models in Application Support.
    static func standard() -> MLXProvider {
        let client = MLXWorkerClient {
            guard let dir = MLXPaths.workerDir, let python = MLXPaths.python(workerDir: dir) else { return nil }
            return .init(executable: python, arguments: ["-u", dir.appendingPathComponent("worker.py").path, "--idle", "300"],
                         environment: MLXPaths.environment(), log: MLXPaths.logFile)
        }
        let provider = MLXProvider(client: client, downloads: .standard()) {
            MLXPaths.python(workerDir: MLXPaths.workerDir) != nil
        }
        provider.downloads.onFinished = { [weak provider] _ in
            provider?.refreshAvailability()
            LocalAI.shared.refresh()
        }
        return provider
    }

    /// The chosen catalog model (the catalog's default when unset or unknown).
    var selected: ModelSpec? {
        let catalog = downloads.catalog
        return catalog.model(settings[.mlxModel]) ?? catalog.defaultModel
    }

    func select(_ id: String) {
        guard downloads.catalog.model(id) != nil else { return }
        settings[.mlxModel] = id
        refreshAvailability()
    }

    func refreshAvailability() {
        downloads.refresh()
        let now = Self.availability(appleSilicon: Self.isAppleSilicon, systemOK: Self.systemOK, installed: isInstalled(),
                                    modelPresent: selected.map(downloads.isPresent) ?? false)
        if now != availability { availability = now }
    }

    /// The checks in order of what has to be fixed first (pure, tested).
    nonisolated static func availability(appleSilicon: Bool, systemOK: Bool, installed: Bool, modelPresent: Bool) -> AIAvailability {
        if !appleSilicon { return .unavailable(.unsupportedHardware) }
        if !systemOK { return .unavailable(.systemTooOld) }
        if !installed { return .unavailable(.notInstalled) }
        if !modelPresent { return .unavailable(.modelMissing) }
        return .available
    }

    nonisolated static var isAppleSilicon: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }

    /// The MLX wheel for macOS 26 is built for 26.2: older systems load it and fail on the first GPU call.
    nonisolated static var systemOK: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 2, patchVersion: 0))
    }

    func respond(_ request: AIRequest) async throws -> String {
        try await run(request, onToken: nil).text
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                var text = ""
                do {
                    let result = try await self.run(request) { piece in
                        text += piece
                        continuation.yield(text)
                    }
                    if result.text != text { continuation.yield(result.text) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: AIError.from(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func run(_ request: AIRequest, onToken: ((String) -> Void)?) async throws -> MLXWorkerClient.GenerateResult {
        refreshAvailability()
        if case .unavailable(let reason) = availability { throw AIError.unavailable(reason) }
        guard let model = selected, let path = downloads.path(model) else { throw AIError.unavailable(.modelMissing) }
        let maxTokens = request.maxTokens ?? WorkerBudget.maxTokens(promptCharacters: request.prompt.count)
        return try await client.generate(prompt: request.prompt, system: request.instructions, model: path.path, maxTokens: maxTokens,
                                         temperature: request.temperature ?? 0, onToken: onToken)
    }
}
