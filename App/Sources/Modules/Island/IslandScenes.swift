import SwiftUI

/// Render scenes and gallery entries of the island module: every state as island and as
/// capsule on a menu-bar backdrop (`island.<state>`, `capsule.<state>`), the capsule on a Mac
/// without notch, the settings pane and the onboarding step.
enum IslandScenes {
    struct Sample {
        let id: String
        var crop = IslandLook.crop
        let content: () -> IslandContent
        var configure: (IslandModel) -> Void = { _ in }
    }

    /// The states, the same list for island and capsule.
    static var samples: [Sample] {
        [
            Sample(id: "activity") { .activity(symbol: "timer", title: IslandSampleText.focus, detail: "24:13") },
            Sample(id: "progress") { .progress(title: IslandSampleText.preparing) },
            Sample(id: "progress-fraction") {
                .progress(title: IslandSampleText.exporting, fraction: 0.42, symbol: "square.and.arrow.up")
            },
            Sample(id: "progress-counting", content: { .progress(title: IslandSampleText.preparing) }) {
                $0.slowSince = Date(timeIntervalSinceNow: -7)
            },
            Sample(id: "progress-slow", content: {
                .progress(title: IslandSampleText.preparing, cancel: IslandAction(id: "cancel", title: CommonText.cancel) {})
            }) {
                $0.slowSince = Date(timeIntervalSinceNow: -12)
                $0.slowHint = true
            },
            Sample(id: "levels") { .levels(IslandPreviewModel.speechBands, symbol: "mic.fill") },
            Sample(id: "done") {
                .done(title: IslandSampleText.saved, detail: IslandSampleText.savedDetail, body: IslandSampleText.savedBody)
            },
            Sample(id: "done-hover", crop: IslandLook.hoverCrop, content: {
                .done(title: IslandSampleText.saved, detail: IslandSampleText.savedDetail, body: IslandSampleText.savedLong,
                      actions: [IslandAction(id: "reveal", title: IslandSampleText.showInFinder, symbol: "folder") {}])
            }) { $0.hover = .expanded },
            Sample(id: "done-copied", crop: IslandLook.hoverCrop, content: {
                .done(title: IslandSampleText.saved, detail: IslandSampleText.savedDetail, body: IslandSampleText.savedBody)
            }) {
                $0.hover = .expanded
                $0.stillCopied = true
            },
            Sample(id: "notice-info") { .notice(text: IslandSampleText.noticeInfo, kind: .info) },
            Sample(id: "notice-success") { .notice(text: IslandSampleText.noticeSuccess, kind: .success) },
            Sample(id: "notice-warning") { .notice(text: IslandSampleText.noticeWarning, kind: .warning) },
            Sample(id: "notice-error") { .notice(text: IslandSampleText.noticeError, kind: .error) },
        ]
    }

    static func stage(_ sample: Sample, kind: IslandModel.Kind, notch: Bool = true) -> AnyView {
        AnyView(IslandStage(model: IslandPreviewModel.make(sample.content(), kind: kind, canvas: sample.crop, notch: notch,
                                                           configure: sample.configure),
                            notch: notch))
    }

    static func register() {
        for sample in samples {
            Registry.renderScenes.append(RenderScene(id: "island.\(sample.id)", size: sample.crop) { stage(sample, kind: .notch) })
            Registry.renderScenes.append(RenderScene(id: "capsule.\(sample.id)", size: sample.crop) { stage(sample, kind: .capsule) })
        }
        if let levels = samples.first(where: { $0.id == "levels" }) {
            Registry.renderScenes.append(RenderScene(id: "capsule.no-notch", size: levels.crop) {
                stage(levels, kind: .capsule, notch: false)
            })
        }
        Registry.renderScenes.append(RenderScene(id: "island.pane", size: paneSize) {
            AnyView(IslandPane().frame(width: paneSize.width, height: paneSize.height))
        })
        Registry.renderScenes.append(RenderScene(id: "island.onboarding", size: .zero) { AnyView(OnboardingSample()) })
        Registry.renderScenes.append(RenderScene(id: "island.tiles", size: .zero) { AnyView(TilesSample()) })

        Registry.gallery.append(GalleryEntry(id: "island.states", area: "island", title: { IslandText.galleryStates }) {
            AnyView(StatesSample())
        })
        Registry.gallery.append(GalleryEntry(id: "island.stage", area: "island", title: { IslandText.galleryStage }) {
            AnyView(IslandStyleStage(style: .auto).frame(width: Metrics.onboardingColumn))
        })
        Registry.gallery.append(GalleryEntry(id: "island.glyphs", area: "island", title: { IslandText.galleryGlyphs }) {
            AnyView(GlyphsSample())
        })
    }

    static let paneSize = CGSize(width: 680, height: 760)
}

/// The onboarding step in the onboarding window on the render desk (like Patterns' samples).
private struct OnboardingSample: View {
    var body: some View {
        RenderBoard {
            StaticWindow(size: Metrics.onboardingWindow, chrome: .onboarding) {
                OnboardingFrame {
                    IslandOnboardingStep()
                } footer: {
                    OnboardingFooter(count: 6, index: 3, back: {}, advance: {})
                }
            }
        }
    }
}

/// The three style tiles at settings and onboarding sizes.
private struct TilesSample: View {
    @State private var style = IslandStyle.auto
    @State private var large = IslandOnboardingStep.Choice.island

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SettingsSection {
                TilePicker(IslandStyle.allCases.map { TileOption($0, title: IslandText.style($0)) }, selection: $style,
                           tone: .settings) { IslandStyleTile(style: $0) }
            }
            SettingsSection(tone: .onboarding) {
                TilePicker([TileOption(IslandOnboardingStep.Choice.island, title: IslandText.style(.island)),
                            TileOption(IslandOnboardingStep.Choice.capsule, title: IslandText.style(.capsule))],
                           selection: $large, previewHeight: Metrics.tilePreviewLarge) { c in
                    IslandStyleTile(style: c == .capsule ? .capsule : .island)
                }
            }
        }
        .frame(width: Metrics.onboardingColumn)
        .padding(Space.l)
        .background(Theme(scheme).windowBg)
    }

    @Environment(\.colorScheme) private var scheme
}

/// A few states stacked, for the gallery.
private struct StatesSample: View {
    var body: some View {
        VStack(spacing: Space.s) {
            ForEach(["levels", "progress-fraction", "done", "notice-error"], id: \.self) { id in
                if let sample = IslandScenes.samples.first(where: { $0.id == id }) {
                    IslandScenes.stage(sample, kind: .notch)
                        .frame(width: sample.crop.width, height: sample.crop.height / 2, alignment: .top)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
            }
        }
    }
}

/// Badges, ring, meter and buttons on black.
private struct GlyphsSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                IslandBadge(kind: .symbol("mic.fill", .accent))
                IslandBadge(kind: .symbol("bolt.fill", .amber))
                IslandBadge(kind: .check(.accent))
                ForEach(IslandNoticeKind.allCases, id: \.self) { IslandBadge(kind: .notice($0)) }
                IslandRecDot()
            }
            HStack(spacing: Space.s) {
                IslandRing(tint: .accent, still: IslandLook.stillTime / 5)
                IslandRing(tint: .teal, fraction: 0.42)
                IslandPercent(fraction: 0.42)
                IslandMeter(tint: .accent, bands: { IslandPreviewModel.speechBands }, still: IslandLook.stillTime)
                IslandMeter(tint: .sky, bands: { [] }, still: IslandLook.stillTime)
            }
            HStack(spacing: Space.xs) {
                IslandCopyButton(text: "", still: true)
                IslandCopyButton(text: "", still: true, stillCopied: true)
                IslandButton(title: IslandSampleText.showInFinder, symbol: "folder", still: true) {}
            }
        }
        .padding(Space.m)
        .background(RoundedRectangle(cornerRadius: Radius.Island.capsuleCard, style: .continuous).fill(IslandPalette.surface))
        .environment(\.colorScheme, .dark)
    }
}
