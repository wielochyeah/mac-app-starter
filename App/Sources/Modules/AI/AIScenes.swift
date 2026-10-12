import SwiftUI

/// Render scenes and gallery entries of the AI module, from fixed sample states (never the real
/// availability of the Mac that renders): `ai.pane`, `ai.pane-unavailable`, `ai.pane-not-ready`,
/// `ai.onboarding`, `ai.onboarding-unavailable`, `ai.download-rows`.
enum AIScenes {
    /// A settings pane as the hub shows it: window width minus sidebar.
    static let paneWidth = Metrics.settingsWindow.width - Metrics.sidebarWidth

    static func register() {
        scene("ai.pane", height: AIRenderSize.pane) { AnyView(pane(.available)) }
        scene("ai.pane-unavailable", height: AIRenderSize.paneProblem) { AnyView(pane(.appleOff)) }
        scene("ai.pane-not-ready", height: AIRenderSize.paneProblem) { AnyView(pane(.notReady)) }
        scene("ai.onboarding") { AnyView(AIStepWindow { AIOnboardingContent(model: AISample.model(.available)) }) }
        scene("ai.onboarding-unavailable") { AnyView(AIStepWindow { AIOnboardingContent(model: AISample.model(.appleOff)) }) }
        scene("ai.download-rows") { AnyView(Specimen(width: Metrics.onboardingColumn) { AISampleRows() }) }

        Registry.gallery += [
            GalleryEntry(id: "ai.pane", area: "ai", title: { AIText.galleryPane }) { AnyView(pane(.available)) },
            GalleryEntry(id: "ai.onboarding", area: "ai", title: { AIText.galleryStep }) {
                AnyView(AIStepWindow { AIOnboardingContent(model: AISample.model(.available)) })
            },
            GalleryEntry(id: "ai.download-rows", area: "ai", title: { AIText.galleryRows }) { AnyView(AISampleRows()) },
        ]
    }

    static func scene(_ id: String, height: CGFloat? = nil, _ content: @escaping () -> AnyView) {
        let size = height.map { CGSize(width: paneWidth, height: $0) } ?? .zero
        Registry.renderScenes.append(RenderScene(id: id, size: size, content: content))
    }

    static func pane(_ state: AISample.State, sections: [AIPaneSection] = [], providers: [AIProviderInfo]? = nil) -> some View {
        var model = AISample.model(state)
        if let providers { model.providers = providers }
        return AIPaneContent(model: model, choice: .constant(model.choice), trial: AISample.trial(state), sections: sections)
            .frame(width: paneWidth)
    }
}

/// Heights of the pane renders (the pane fills the window; renders need a fixed height).
enum AIRenderSize {
    static let pane: CGFloat = Metrics.settingsWindow.height
    static let paneProblem: CGFloat = Metrics.settingsWindow.height
    static let paneMLX: CGFloat = 1060
}

/// An onboarding window on the render desk with this step's page and the kit footer.
struct AIStepWindow<Page: View>: View {
    let page: Page

    init(@ViewBuilder page: () -> Page) { self.page = page() }

    var body: some View {
        RenderBoard {
            StaticWindow(size: Metrics.onboardingWindow, chrome: .onboarding) {
                OnboardingFrame { page } footer: {
                    OnboardingFooter(count: 7, index: 4, back: {}, advance: {})
                }
            }
        }
    }
}

/// Fixed sample states.
enum AISample {
    enum State { case available, appleOff, notReady }

    static let gb: Int64 = 1_000_000_000
    static let mb: Int64 = 1_000_000

    static func apple(_ availability: AIAvailability) -> AIProviderInfo {
        AIProviderInfo(id: AppleOnDeviceProvider.providerID, title: AIText.apple, shortTitle: AIText.appleShort,
                       detail: AIText.appleDetail, symbol: "apple.intelligence", tint: .indigo, availability: availability)
    }

    static func model(_ state: State) -> AIPaneModel {
        switch state {
        case .available:
            AIPaneModel(providers: [apple(.available)], choice: ProviderChoice.automatic, activeID: AppleOnDeviceProvider.providerID,
                        availability: .available,
                        usage: AIUsage(requests: 14, failures: 1, lastLatency: 1.2, lastProvider: AppleOnDeviceProvider.providerID))
        case .appleOff:
            AIPaneModel(providers: [apple(.unavailable(.appleIntelligenceOff))], choice: ProviderChoice.automatic,
                        activeID: AppleOnDeviceProvider.providerID, availability: .unavailable(.appleIntelligenceOff), usage: AIUsage())
        case .notReady:
            AIPaneModel(providers: [apple(.unavailable(.modelNotReady))], choice: ProviderChoice.automatic,
                        activeID: AppleOnDeviceProvider.providerID, availability: .unavailable(.modelNotReady), usage: AIUsage())
        }
    }

    static func trial(_ state: State) -> AITrial {
        switch state {
        case .available: AITrial(prompt: AIText.trySample, answer: AIText.sampleAnswer, latency: 1.2, provider: AIText.apple)
        case .appleOff, .notReady: AITrial()
        }
    }

    /// One row per phase, for `ai.download-rows`.
    static var rows: [ModelRowItem] {
        [
            ModelRowItem(id: "a", role: AIText.sampleFastRole, name: "Qwen3 1.7B", symbol: "hare.fill", tint: .teal,
                         phase: .notStarted(total: 984 * mb)),
            ModelRowItem(id: "b", role: AIText.sampleFastRole, name: "Qwen3 1.7B", symbol: "hare.fill", tint: .teal,
                         phase: .queued(total: 984 * mb)),
            ModelRowItem(id: "c", role: AIText.sampleQualityRole, name: "Qwen3.5 4B", symbol: "text.alignleft", tint: .indigo,
                         phase: .running(done: 1_400 * mb, total: 3_061 * mb)),
            ModelRowItem(id: "d", role: AIText.sampleQualityRole, name: "Qwen3.5 4B", symbol: "text.alignleft", tint: .indigo,
                         phase: .paused(done: 1_400 * mb, total: 3_061 * mb)),
            ModelRowItem(id: "e", role: AIText.sampleFastRole, name: "Qwen3 1.7B", symbol: "hare.fill", tint: .teal,
                         phase: .done(total: 984 * mb)),
        ]
    }
}

private struct AISampleRows: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.pane) {
            SettingsSection(AIText.modelsSection) {
                ForEach(AISample.rows) { ModelRowView(item: $0) }
            }
            SettingsSection(tone: .onboarding) {
                ForEach(AISample.rows.prefix(3)) { ModelRowView(item: $0) }
            }
        }
    }
}
