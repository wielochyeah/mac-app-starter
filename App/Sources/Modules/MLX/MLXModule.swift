import SwiftUI

/// Module `mlx` (needs `ai`, off by default): an MLX provider for `LocalAI` backed by the Python
/// worker in ai-worker/, model downloads with progress, the MLX section in the Models pane and on
/// the Local AI step, render scenes `ai.pane-mlx*`/`ai.onboarding-mlx`, and self-tests
/// (`--selftest mlx` runs a real model: ai-worker/setup.sh and a downloaded model first).
enum MLXModule {
    static func register() {
        let provider = MLXProvider.standard()
        LocalAI.shared.register(provider)
        LocalAI.shared.sections.append(AIPaneSection(id: "mlx", order: 10, pane: { AnyView(MLXPaneSection(provider: provider)) },
                                                     onboarding: { AnyView(MLXOnboardingSection(provider: provider)) }))
        Registry.terminateHooks.append {
            provider.downloads.stopAll()
            provider.client.shutdown()
        }
        MLXScenes.register()
        Registry.selfTests += [
            SelfTestCheck(id: "mlx.catalog") {
                guard let dir = MLXPaths.workerDir else { return nil }   // a build without ai-worker uses the built-in copy
                do {
                    let file = try ModelCatalog.load(dir.appendingPathComponent("models.json"))
                    return file == ModelCatalog.builtIn ? nil : "ai-worker/models.json and ModelCatalog.builtIn differ"
                } catch {
                    return "ai-worker/models.json: \(error)"
                }
            },
            SelfTestCheck(id: "mlx.download", onDemand: true) { MLXLiveCheck.download(provider) },
            SelfTestCheck(id: "mlx.live", onDemand: true) { MLXLiveCheck.run(provider) },
        ]
    }
}

/// `--selftest mlx`: the real worker with the chosen model answers a German prompt (cold, then
/// warm), streams, pings while busy, cancels and shuts down. Prints timings.
enum MLXLiveCheck {
    /// `--selftest mlx.download`: downloads the chosen model through `ModelDownloads` (the network,
    /// as the user's Download button does; a no-op when it is there). Prints progress in 10 % steps.
    static func download(_ provider: MLXProvider) -> String? {
        guard let model = provider.selected else { return "no model in the catalog" }
        let downloads = provider.downloads
        if downloads.isPresent(model) {
            print("mlx.download \(model.repo) is already on disk")
            return nil
        }
        let start = Date()
        var lastStep = -1
        downloads.start(model.id)
        AIWait.until(timeout: 3 * 3600) {
            switch downloads.state(model.id) {
            case .running(let done, let total):
                let step = total > 0 ? Int(Double(done) / Double(total) * 10) : 0
                if step != lastStep {
                    lastStep = step
                    print("mlx.download \(step * 10) % (\(done) of \(total) bytes, \(Int(Date().timeIntervalSince(start))) s)")
                }
                return false
            case .queued: return false
            case .done, .paused, .notStarted: return true
            }
        }
        switch downloads.state(model.id) {
        case .done:
            print("mlx.download done in \(Int(Date().timeIntervalSince(start))) s, \(HubCache.blobBytes(hub: downloads.hub, repo: model.repo)) bytes")
            provider.refreshAvailability()
            return provider.availability.isAvailable ? nil : "downloaded, but MLX is \(provider.availability)"
        case .paused(let done, let total, let problem):
            return "download stopped (\(problem)) at \(done) of \(total): \(downloads.lastProblem ?? "-")"
        default:
            downloads.stopAll()
            return "download did not finish"
        }
    }

    static func run(_ provider: MLXProvider) -> String? {
        provider.refreshAvailability()
        if case .unavailable(let reason) = provider.availability {
            let hint = reason == .modelMissing
                ? " (ai-worker/.venv/bin/python ai-worker/download.py --model \(provider.selected?.id ?? "small") --hf-home \"\(MLXPaths.hfHome.path)\")"
                : reason == .notInstalled ? " (run ai-worker/setup.sh)" : ""
            return "MLX unavailable: \(reason.rawValue)\(hint)"
        }
        guard let model = provider.selected, let path = provider.downloads.path(model) else { return "no model path" }
        print("mlx.live model \(model.repo) at \(path.path)")
        let client = provider.client
        let system = "Antworte kurz auf Deutsch."

        var t = Date()
        var pieces = 0
        let cold = AIWait.run(timeout: 180) {
            try await client.generate(prompt: "Wofür ist die Menüleiste auf dem Mac da? Ein Satz.", system: system, model: path.path,
                                      maxTokens: 120) { _ in pieces += 1 }
        }
        switch cold {
        case .value(let r):
            print("mlx.live cold (\(String(format: "%.2f", Date().timeIntervalSince(t))) s, load \(r.stats.loadSeconds ?? 0) s, \(r.stats.tokens ?? 0) tokens, \(r.stats.tokensPerSecond ?? 0) tok/s, \(pieces) pieces, peak \(r.stats.peakMB ?? 0) MB): \(r.text)")
            if r.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "empty answer" }
            if pieces < 2 { return "no streamed pieces" }
        case .failure(let e): return "cold request failed: \(e) (\(client.lastProblem ?? "-"))"
        case .timedOut: return "cold request timed out"
        }

        t = Date()
        var snapshots: [String] = []
        let warm = AIWait.run(timeout: 60) { () async throws -> String in
            for try await s in provider.stream(AIRequest(prompt: "Nenne drei Farben, mit Kommas.", instructions: system, maxTokens: 40)) {
                snapshots.append(s)
            }
            return snapshots.last ?? ""
        }
        switch warm {
        case .value(let text):
            print("mlx.live warm via provider (\(String(format: "%.2f", Date().timeIntervalSince(t))) s, \(snapshots.count) snapshots): \(text)")
            if text.isEmpty { return "empty streamed answer" }
        case .failure(let e): return "warm request failed: \(e)"
        case .timedOut: return "warm request timed out"
        }

        // cancel after the first piece; ping while it runs
        t = Date()
        var task: Task<MLXWorkerClient.GenerateResult, Error>?
        var gotPiece = false
        let cancelled = AIWait.run(timeout: 30) { () async throws -> String in
            task = Task { @MainActor in
                try await client.generate(prompt: "Erzähl eine lange Geschichte über einen Leuchtturm.", system: system, model: path.path,
                                          maxTokens: 800) { _ in gotPiece = true }
            }
            while !gotPiece { try await Task.sleep(for: .milliseconds(20)) }
            let pong = try await client.ping()
            task?.cancel()
            do {
                _ = try await task!.value
                return "finished instead of stopping"
            } catch {
                return "\(AIError.from(error)) busy=\(pong.busy)"
            }
        }
        switch cancelled {
        case .value(let s):
            print("mlx.live cancel (\(String(format: "%.2f", Date().timeIntervalSince(t))) s): \(s)")
            if !s.hasPrefix("cancelled") || !s.hasSuffix("busy=true") { return "cancel: \(s)" }
        case .failure(let e): return "cancel test failed: \(e)"
        case .timedOut: return "cancel test timed out"
        }

        client.shutdown()
        AIWait.until(timeout: 3) { !client.isRunning }
        if client.isRunning { return "worker still running after shutdown" }
        print("mlx.live worker starts: \(client.starts), crashes: \(client.crashes)")
        return nil
    }
}

/// Render scenes with MLX (fixed sample states).
enum MLXScenes {
    static func register() {
        AIScenes.scene("ai.pane-mlx", height: AIRenderSize.paneMLX) { AnyView(pane(.ready)) }
        AIScenes.scene("ai.pane-mlx-setup", height: AIRenderSize.paneMLX) { AnyView(pane(.notInstalled)) }
        AIScenes.scene("ai.onboarding-mlx") {
            AnyView(AIStepWindow { AIOnboardingContent(model: model(.download), sections: sections(.download)) })
        }
        Registry.gallery.append(GalleryEntry(id: "ai.pane-mlx", area: "ai", title: { MLXText.galleryPane }) { AnyView(pane(.ready)) })
    }

    enum State { case ready, notInstalled, download }

    static let mb: Int64 = 1_000_000

    static func mlxInfo(_ availability: AIAvailability) -> AIProviderInfo {
        AIProviderInfo(id: MLXProvider.providerID, title: MLXText.title, shortTitle: MLXText.title, detail: MLXText.detail,
                       symbol: "square.stack.3d.up.fill", tint: .teal, availability: availability)
    }

    static func model(_ state: State) -> AIPaneModel {
        switch state {
        case .ready:
            AIPaneModel(providers: [AISample.apple(.available), mlxInfo(.available)], choice: ProviderChoice.automatic,
                        activeID: AppleOnDeviceProvider.providerID, availability: .available,
                        usage: AIUsage(requests: 9, failures: 0, lastLatency: 0.6, lastProvider: MLXProvider.providerID))
        case .notInstalled:
            AIPaneModel(providers: [AISample.apple(.unavailable(.deviceNotEligible)), mlxInfo(.unavailable(.notInstalled))],
                        choice: ProviderChoice.automatic, activeID: MLXProvider.providerID,
                        availability: .unavailable(.notInstalled), usage: AIUsage())
        case .download:
            AIPaneModel(providers: [AISample.apple(.unavailable(.appleIntelligenceOff)), mlxInfo(.unavailable(.modelMissing))],
                        choice: ProviderChoice.automatic, activeID: AppleOnDeviceProvider.providerID,
                        availability: .unavailable(.appleIntelligenceOff), usage: AIUsage())
        }
    }

    static func sectionModel(_ state: State) -> MLXSectionModel {
        let catalog = ModelCatalog.builtIn
        let states: [String: ModelDownloads.State] = switch state {
        case .ready: ["small": .done, "quality": .running(done: 1_400 * mb, total: 3_061 * mb)]
        case .notInstalled: [:]
        case .download: [:]
        }
        let selected = catalog.defaultID
        return MLXSectionModel(
            rows: catalog.models.map { MLXSectionModel.row($0, states[$0.id] ?? .notStarted) }, selected: selected,
            options: catalog.models.map { ($0.id, MLXText.role($0.role)) }, memoryGB: catalog.defaultModel?.ramGB,
            footnote: MLXSectionModel.footnote(states, selected: selected, installed: state != .notInstalled),
            bytesOnDisk: state == .ready ? 2_384 * mb : 0, installed: state != .notInstalled)
    }

    static func sections(_ state: State) -> [AIPaneSection] {
        let m = sectionModel(state)
        return [AIPaneSection(id: "mlx", order: 10, pane: { AnyView(MLXSectionContent(model: m, selected: .constant(m.selected))) },
                              onboarding: { AnyView(MLXOnboardingContent(row: m.rows.first { $0.id == m.selected })) })]
    }

    static func pane(_ state: State) -> some View {
        let m = model(state)
        return AIPaneContent(model: m, choice: .constant(m.choice), trial: state == .ready ? AISample.trial(.available) : AITrial(),
                             sections: sections(state))
            .frame(width: AIScenes.paneWidth)
    }
}
