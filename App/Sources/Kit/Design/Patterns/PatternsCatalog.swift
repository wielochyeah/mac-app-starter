import SwiftUI

/// Registers every pattern as a gallery entry and a `patterns.<name>` render scene, plus composed
/// samples built only from patterns (`patterns.sample-pane`, `patterns.sample-step`,
/// `patterns.sample-permission`). Called from `DesignKit.register()`.
enum PatternsKit {
    static func register() {
        for item in catalog {
            Registry.gallery.append(GalleryEntry(id: "patterns.\(item.id)", area: "patterns", title: item.title, content: item.view))
            Registry.renderScenes.append(RenderScene(id: "patterns.\(item.id)", size: item.size) {
                item.specimen ? AnyView(Specimen(width: item.width) { item.view() }) : item.view()
            })
        }
    }

    /// Scene names (without the `patterns.` prefix), for tests.
    static var names: [String] { catalog.map(\.id) }

    private struct Item {
        let id: String
        let title: () -> String
        var size: CGSize = .zero
        var specimen = true
        var width: CGFloat = 560
        let view: () -> AnyView
    }

    private static var catalog: [Item] {
        [
            Item(id: "onboarding-page", title: { PatternsText.onboardingPage }, specimen: false) { AnyView(PageSample()) },
            Item(id: "onboarding-header", title: { PatternsText.onboardingHeader }, width: 640) { AnyView(HeaderSample()) },
            Item(id: "onboarding-hero", title: { PatternsText.onboardingHero }, width: 720) { AnyView(HeroSample()) },
            Item(id: "onboarding-footnote", title: { PatternsText.onboardingFootnote }) { AnyView(OnboardingFootnoteSample()) },
            Item(id: "onboarding-hint", title: { PatternsText.onboardingHint }, width: 608) { AnyView(HintSample()) },
            Item(id: "onboarding-status-slot", title: { PatternsText.statusSlot }) { AnyView(StatusSlotSample()) },
            Item(id: "onboarding-tile-picker", title: { PatternsText.tilePicker }, width: 600) { AnyView(TilePickerSample()) },
            Item(id: "onboarding-rich-text", title: { PatternsText.richText }) { AnyView(RichTextSample()) },
            Item(id: "onboarding-footer", title: { PatternsText.onboardingFooter }, width: 720) { AnyView(FooterSample()) },
            Item(id: "pane-scaffold", title: { PatternsText.paneScaffold }, specimen: false) { AnyView(PaneScaffoldSample()) },
            Item(id: "settings-section", title: { PatternsText.settingsSection }) { AnyView(SectionSample()) },
            Item(id: "toggle-row", title: { PatternsText.toggleRow }) { AnyView(ToggleRowSample()) },
            Item(id: "picker-row", title: { PatternsText.pickerRow }) { AnyView(PickerRowSample()) },
            Item(id: "value-row", title: { PatternsText.valueRow }) { AnyView(ValueRowSample()) },
            Item(id: "button-row", title: { PatternsText.buttonRow }) { AnyView(ButtonRowSample()) },
            Item(id: "link-row", title: { PatternsText.linkRow }) { AnyView(LinkRowSample()) },
            Item(id: "navigation-row", title: { PatternsText.navigationRow }) { AnyView(NavigationRowSample()) },
            Item(id: "inline-notice", title: { PatternsText.inlineNotice }) { AnyView(NoticeSample()) },
            Item(id: "progress-row", title: { PatternsText.progressRow }) { AnyView(ProgressRowSample()) },
            Item(id: "list-card", title: { PatternsText.listCard }) { AnyView(ListCardSample()) },
            Item(id: "count-badge", title: { PatternsText.countBadge }) { AnyView(CountBadgeSample()) },
            Item(id: "search-field", title: { PatternsText.searchField }) { AnyView(SearchFieldSample()) },
            Item(id: "sample-pane", title: { PatternsText.samplePane }, specimen: false) { AnyView(SamplePane()) },
            Item(id: "sample-step", title: { PatternsText.sampleStep }, specimen: false) { AnyView(SampleLanguageStep()) },
            Item(id: "sample-permission", title: { PatternsText.samplePermission }, specimen: false) { AnyView(SamplePermissionStep()) },
        ]
    }
}

// MARK: - Shared sample data (fixed, so renders are deterministic)

private enum SampleData {
    static let gb: Int64 = 1_000_000_000
    static let mb: Int64 = 1_000_000

    struct App: Identifiable {
        let id: Int
        let name: String
        let detail: String
        let symbol: String
        let tint: TintName
    }

    static var apps: [App] {
        PatternsSampleText.sampleApps.enumerated().map { i, a in App(id: i, name: a.name, detail: a.detail, symbol: a.symbol, tint: a.tint) }
    }
}

/// An onboarding window on the render desk, with footer.
private struct SampleWindow<Page: View>: View {
    var index = 1
    var count = 6
    var advanceIsPrimary = true
    var advanceTitle = CommonText.continue
    let page: Page

    init(index: Int = 1, count: Int = 6, advanceIsPrimary: Bool = true, advanceTitle: String = CommonText.continue,
         @ViewBuilder page: () -> Page) {
        self.index = index
        self.count = count
        self.advanceIsPrimary = advanceIsPrimary
        self.advanceTitle = advanceTitle
        self.page = page()
    }

    var body: some View {
        RenderBoard {
            StaticWindow(size: Metrics.onboardingWindow, chrome: .onboarding) {
                OnboardingFrame {
                    page
                } footer: {
                    OnboardingFooter(count: count, index: index, advanceTitle: advanceTitle, advanceIsPrimary: advanceIsPrimary,
                                     back: index > 0 ? {} : nil, advance: {})
                }
            }
        }
    }
}

/// Mini previews for tile pickers: the wallpaper with an island, a capsule or nothing.
private enum StylePreviewKind: Hashable { case island, capsule, off }

private struct StylePreview: View {
    let kind: StylePreviewKind
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        ZStack(alignment: .top) {
            Rectangle().fill(t.wallpaper)
            t.menuBarTint.frame(height: 9)
            switch kind {
            case .island:
                UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5, style: .continuous)
                    .fill(IslandPalette.surface)
                    .frame(width: 74, height: 13)
                    .overlay {
                        HStack {
                            Circle().fill(IslandPalette.rec).frame(width: 4, height: 4)
                            Spacer()
                            Capsule().fill(IslandAccent.of().line).frame(width: 10, height: 3)
                        }
                        .padding(.horizontal, 7)
                    }
            case .capsule:
                Capsule().fill(IslandPalette.surface)
                    .frame(width: 40, height: 13)
                    .overlay(Circle().fill(IslandPalette.rec).frame(width: 4, height: 4).offset(x: -10))
                    .padding(.top, 17)
            case .off:
                EmptyView()
            }
        }
    }
}

// MARK: - Onboarding specimens

private struct PageSample: View {
    var body: some View {
        SampleWindow(index: 0) {
            OnboardingPage {
                OnboardingHero { HeroArt() }.padding(.bottom, Space.l)
                OnboardingHeader(title: PatternsSampleText.welcomeTitle, subtitle: PatternsSampleText.welcomeLede, large: true)
            }
        }
    }
}

/// Wallpaper, menu bar tint and the app's squircle: a stand-in for a project's own hero art.
private struct HeroArt: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        ZStack {
            Rectangle().fill(t.wallpaper)
            VStack { t.menuBarTint.frame(height: Metrics.Island.renderMenuBar); Spacer() }
            SquircleIcon(symbol: AppInfo.symbol, tint: .accent, size: 72)
                .shadow(color: t.heroShadow, radius: 10, y: 4)
        }
    }
}

private struct HeaderSample: View {
    var body: some View {
        VStack(spacing: Space.l) {
            OnboardingHeader(title: PatternsSampleText.welcomeTitle, subtitle: PatternsSampleText.welcomeLede, large: true)
            OnboardingHeader(title: PatternsSampleText.language, subtitle: PatternsSampleText.languageSubtitle)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HeroSample: View {
    var body: some View {
        VStack(spacing: Space.l) {
            HStack(spacing: Space.l) {
                OnboardingHero(symbol: "globe", tint: .sky)
                OnboardingHero(symbol: "accessibility", tint: .blue)
                OnboardingHero(symbol: "mic.fill", tint: .orange)
                OnboardingHero(symbol: AppInfo.symbol)
            }
            OnboardingHero { HeroArt() }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingFootnoteSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSection(tone: .onboarding) {
                ToggleRow(PatternsSampleText.openAtLogin, subtitle: PatternsSampleText.openAtLoginDetail, isOn: .constant(true))
            }
            OnboardingFootnote(PatternsSampleText.languageFootnote, lines: 2)
        }
    }
}

private struct HintSample: View {
    var body: some View {
        VStack(spacing: Space.s) {
            OnboardingHint([PatternsSampleText.accessibilityHint, PatternsSampleText.accessibilityRevealHint])
            OnboardingHint(PatternsSampleText.missingHint)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatusSlotSample: View {
    var body: some View {
        VStack(spacing: Space.s) {
            OnboardingStatusSlot(.action {})
            OnboardingStatusSlot(.waiting())
            OnboardingStatusSlot(.waiting(PatternsText.waitingForSwitch, button: .openSettings {}))
            OnboardingStatusSlot(.denied(button: .openSettings {}))
            OnboardingStatusSlot(.granted())
            OnboardingStatusSlot(.restartNeeded {})
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TilePickerSample: View {
    @State private var style = StylePreviewKind.island
    @State private var settingsStyle = StylePreviewKind.capsule

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Card {
                TilePicker([TileOption(.island, title: PatternsSampleText.island, badge: DesignText.recommended),
                            TileOption(.capsule, title: PatternsSampleText.capsule)],
                           selection: $style, previewHeight: Metrics.tilePreviewLarge) { StylePreview(kind: $0) }
            }
            SettingsSection(PatternsSampleText.appearance) {
                TilePicker([TileOption(.island, title: PatternsSampleText.island),
                            TileOption(.capsule, title: PatternsSampleText.capsule),
                            TileOption(.off, title: PatternsSampleText.off, detail: PatternsSampleText.offDetail)],
                           selection: $settingsStyle, tone: .settings) { StylePreview(kind: $0) }
                ToggleRow(PatternsSampleText.sounds, subtitle: PatternsSampleText.soundsDetail, isOn: .constant(false))
            }
        }
    }
}

private struct RichTextSample: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            OnboardingRichText(PatternsSampleText.linkSample)
                .font(TypeScale.body)
                .foregroundStyle(Theme(scheme).prose)
            OnboardingRichText(PatternsSampleText.accessibilityRevealHint)
                .font(TypeScale.secondary)
                .foregroundStyle(Theme(scheme).prose)
        }
    }
}

private struct FooterSample: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            OnboardingFooter(count: 6, index: 0, back: nil, advance: {})
            Separator()
            OnboardingFooter(count: 6, index: 2, advanceIsPrimary: false, back: {}, advance: {})
            Separator()
            OnboardingFooter(count: 6, index: 5, advanceTitle: CommonText.done, back: {}, advance: {})
        }
        .background(Theme(scheme).windowBg)
    }
}

// MARK: - Settings specimens

private struct PaneScaffoldSample: View {
    @State private var query = ""

    var body: some View {
        PaneScaffold(title: PatternsSampleText.general, symbol: "gearshape.fill", tint: .graphite,
                     subtitle: PatternsSampleText.generalIntro) {
            SearchField(text: $query)
        } content: {
            SettingsSection(PatternsSampleText.behavior) {
                ToggleRow(PatternsSampleText.openAtLogin, subtitle: PatternsSampleText.openAtLoginDetail, isOn: .constant(true))
            }
        }
        .frame(width: 680, height: 290)
    }
}

private struct SectionSample: View {
    var body: some View {
        SettingsSection(PatternsSampleText.behavior, footnote: PatternsSampleText.behaviorNote) {
            ToggleRow(PatternsSampleText.openAtLogin, subtitle: PatternsSampleText.openAtLoginDetail, isOn: .constant(true))
            ToggleRow(PatternsSampleText.sounds, subtitle: PatternsSampleText.soundsDetail, isOn: .constant(false))
            ValueRow(PatternsSampleText.confirmation, value: Format.seconds(1.5), capsule: true)
        }
    }
}

private struct ToggleRowSample: View {
    var body: some View {
        SettingsSection {
            ToggleRow(PatternsSampleText.openAtLogin, subtitle: PatternsSampleText.openAtLoginDetail, isOn: .constant(true))
            ToggleRow(PatternsSampleText.sounds, symbol: "speaker.wave.2.fill", tint: .red, isOn: .constant(false))
        }
    }
}

private struct PickerRowSample: View {
    @State private var lang = "system"
    @State private var appearance = "system"

    var body: some View {
        SettingsSection {
            PickerRow(PatternsSampleText.interface, subtitle: PatternsSampleText.interfaceDetail,
                      options: [("system", PatternsSampleText.system), ("de", Lang.de.nativeName), ("en", Lang.en.nativeName)],
                      selection: $lang)
            PickerRow(PatternsSampleText.appearance, subtitle: PatternsSampleText.appearanceDetail,
                      options: [("system", PatternsSampleText.system), ("light", PatternsSampleText.light), ("dark", PatternsSampleText.dark)],
                      selection: $appearance, style: .menu)
        }
    }
}

private struct ValueRowSample: View {
    var body: some View {
        SettingsSection {
            ValueRow(PatternsSampleText.used, value: ByteText.size(2_400 * SampleData.mb))
            ValueRow(PatternsSampleText.confirmation, value: Format.seconds(3), capsule: true)
        }
    }
}

private struct ButtonRowSample: View {
    var body: some View {
        SettingsSection {
            ButtonRow(PatternsSampleText.dataFolder, subtitle: PatternsSampleText.dataFolderDetail,
                      button: PatternsSampleText.showInFinder) {}
            ButtonRow(PatternsSampleText.deleteHistory, subtitle: PatternsSampleText.deleteHistoryDetail,
                      button: PatternsSampleText.delete, style: .secondary) {}
        }
    }
}

private struct LinkRowSample: View {
    var body: some View {
        SettingsSection {
            LinkRow(PatternsSampleText.privacy, subtitle: PatternsSampleText.privacyDetail, symbol: "hand.raised.fill", tint: .blue) {}
            LinkRow(PatternsSampleText.help, subtitle: PatternsSampleText.helpDetail) {}
        }
    }
}

private struct NavigationRowSample: View {
    var body: some View {
        SettingsSection {
            NavigationRow(PatternsSampleText.shortcuts, symbol: "command", tint: .graphite, value: PatternsSampleText.shortcutsDetail) {}
            NavigationRow(PatternsSampleText.models, subtitle: PatternsSampleText.noWaitNote) {}
        }
    }
}

private struct NoticeSample: View {
    var body: some View {
        VStack(spacing: Space.s) {
            InlineNotice(PatternsSampleText.noticeInfo, title: PatternsSampleText.noticeInfoTitle,
                         actionTitle: PatternsSampleText.turnOn) {}
            InlineNotice(PatternsSampleText.noWaitNote, kind: .success)
            InlineNotice(PatternsSampleText.noticeWarn, kind: .warning)
            InlineNotice(PatternsSampleText.noticeError, kind: .error)
        }
    }
}

private struct ProgressRowSample: View {
    var body: some View {
        SettingsSection(PatternsSampleText.models, footnote: PatternsSampleText.offlineNote, footnoteLines: 2) {
            ProgressRow(role: PatternsSampleText.speechModel, name: PatternsSampleText.speechModelName, symbol: "waveform",
                        tint: .violet, phase: .done(total: 820 * SampleData.mb))
            ProgressRow(role: PatternsSampleText.textModel, name: PatternsSampleText.textModelName, symbol: "text.alignleft",
                        tint: .teal, phase: .running(done: 1_400 * SampleData.mb, total: 3 * SampleData.gb))
            ProgressRow(role: PatternsSampleText.embedModel, name: PatternsSampleText.embedModelName, symbol: "magnifyingglass",
                        tint: .indigo, phase: .paused(done: 90 * SampleData.mb, total: 230 * SampleData.mb)) {}
            ProgressRow(role: PatternsSampleText.embedModel, name: PatternsSampleText.embedModelName, symbol: "magnifyingglass",
                        tint: .indigo, phase: .waiting(total: 230 * SampleData.mb))
        }
    }
}

private struct ListCardSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.pane) {
            AppList(query: "", previewHovered: 1)
            AppList(query: "Xcode", previewHovered: nil)
            AppList(query: "", previewHovered: nil, items: [])
        }
    }
}

private struct AppList: View {
    @State var query: String
    let previewHovered: Int?
    var items = SampleData.apps

    var body: some View {
        ListCard(PatternsSampleText.apps, items: items, query: $query, searchPrompt: PatternsSampleText.searchApps,
                 matches: { app, q in ListSearch.matches(app.name, app.detail, query: q) },
                 emptyTitle: PatternsSampleText.noApps, emptyMessage: PatternsSampleText.noAppsDetail,
                 previewHovered: previewHovered) { app, hovered in
            Row(app.name, subtitle: app.detail, symbol: app.symbol, tint: app.tint) {
                if hovered { Chip(CommonText.remove) {} }
            }
        }
    }
}

private struct CountBadgeSample: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.l) {
            HStack(spacing: Space.iconGap) {
                SquircleIcon(symbol: "clock.fill", tint: .violet)
                Text(PatternsSampleText.apps).font(TypeScale.body).foregroundStyle(t.fg)
                CountBadge(1284)
            }
            HStack(spacing: Space.xs) {
                Text(PatternsSampleText.apps).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
                CountBadge(4, style: .pill)
                CountBadge(128, style: .pill)
            }
        }
    }
}

private struct SearchFieldSample: View {
    @State private var empty = ""
    @State private var filled = "Mail"

    var body: some View {
        HStack(spacing: Space.m) {
            SearchField(text: $empty, prompt: PatternsSampleText.searchApps)
            SearchField(text: $filled, size: Metrics.searchFieldCompact)
        }
    }
}

// MARK: - Composed samples (only patterns)

/// A whole settings pane: intro, segmented and menu pickers, switches, a value capsule, downloads,
/// a notice, buttons, links and navigation.
private struct SamplePane: View {
    @State private var lang = "system"
    @State private var appearance = "system"
    @State private var openAtLogin = true
    @State private var sounds = false

    var body: some View {
        PaneScaffold(title: PatternsSampleText.general, symbol: "gearshape.fill", tint: .graphite,
                     subtitle: PatternsSampleText.generalIntro) {
            SettingsSection(PatternsSampleText.language) {
                PickerRow(PatternsSampleText.interface, subtitle: PatternsSampleText.interfaceDetail,
                          options: [("system", PatternsSampleText.system), ("de", Lang.de.nativeName), ("en", Lang.en.nativeName)],
                          selection: $lang)
                PickerRow(PatternsSampleText.appearance, subtitle: PatternsSampleText.appearanceDetail,
                          options: [("system", PatternsSampleText.system), ("light", PatternsSampleText.light), ("dark", PatternsSampleText.dark)],
                          selection: $appearance, style: .menu)
            }
            SettingsSection(PatternsSampleText.behavior, footnote: PatternsSampleText.behaviorNote) {
                ToggleRow(PatternsSampleText.openAtLogin, subtitle: PatternsSampleText.openAtLoginDetail, isOn: $openAtLogin)
                ToggleRow(PatternsSampleText.sounds, subtitle: PatternsSampleText.soundsDetail, isOn: $sounds)
                ValueRow(PatternsSampleText.confirmation, value: Format.seconds(1.5), capsule: true)
            }
            SettingsSection(PatternsSampleText.models, footnote: PatternsSampleText.noWaitNote) {
                ProgressRow(role: PatternsSampleText.speechModel, name: PatternsSampleText.speechModelName, symbol: "waveform",
                            tint: .violet, phase: .done(total: 820 * SampleData.mb))
                ProgressRow(role: PatternsSampleText.textModel, name: PatternsSampleText.textModelName, symbol: "text.alignleft",
                            tint: .teal, phase: .running(done: 1_400 * SampleData.mb, total: 3 * SampleData.gb))
            }
            InlineNotice(PatternsSampleText.noticeWarn, kind: .warning)
            SettingsSection(PatternsSampleText.storage) {
                ButtonRow(PatternsSampleText.dataFolder, subtitle: PatternsSampleText.dataFolderDetail,
                          button: PatternsSampleText.showInFinder) {}
                ValueRow(PatternsSampleText.used, value: ByteText.size(2_400 * SampleData.mb))
                NavigationRow(PatternsSampleText.shortcuts, value: PatternsSampleText.shortcutsDetail) {}
                LinkRow(PatternsSampleText.privacy, subtitle: PatternsSampleText.privacyDetail) {}
            }
        }
        .frame(width: 680, height: 960)
    }
}

/// The language step, as in VoiceBud's setup (docs/screenshots/setup-language.png): the segment
/// follows the UI language and switches it, like the real step.
private struct SampleLanguageStep: View {
    private let localizer = Localizer.shared
    @State private var openAtLogin = true

    var body: some View {
        let lang = Binding(get: { localizer.lang.rawValue }, set: { localizer.choice = Lang(rawValue: $0) })
        SampleWindow(index: 1) {
            OnboardingPage {
                OnboardingHero(symbol: "globe", tint: .sky).padding(.bottom, Space.m)
                OnboardingHeader(title: PatternsSampleText.language, subtitle: PatternsSampleText.languageSubtitle)
                    .padding(.bottom, Space.xs)
                OnboardingNote(PatternsSampleText.languageCrossHint).padding(.bottom, Space.l)
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSection(tone: .onboarding) {
                        PickerRow(PatternsSampleText.app, subtitle: PatternsSampleText.appDetail,
                                  options: [("en", Lang.en.nativeName), ("de", Lang.de.nativeName)], selection: lang)
                        ToggleRow(PatternsSampleText.openAtLogin, subtitle: PatternsSampleText.openAtLoginDetail, isOn: $openAtLogin)
                    }
                    OnboardingFootnote(PatternsSampleText.languageFootnote, lines: 2)
                }
                .frame(width: Metrics.onboardingCard)
            }
        }
    }
}

/// A permission step waiting for the user's switch in System Settings (VoiceBud
/// onboarding-04b-bedienungshilfen-wartet): Continue is secondary while the slot holds the action.
private struct SamplePermissionStep: View {
    var body: some View {
        let slot = OnboardingSlotState.waiting(PatternsText.waitingForSwitch, button: .openSettings {})
        SampleWindow(index: 3, advanceIsPrimary: false) {
            OnboardingPage {
                OnboardingHero(symbol: "accessibility", tint: .blue).padding(.bottom, Space.m)
                OnboardingHeader(title: PatternsSampleText.accessibility, subtitle: PatternsSampleText.accessibilitySubtitle)
                    .padding(.bottom, Space.l)
                OnboardingStatusSlot(slot).padding(.bottom, Space.s)
                OnboardingHint([PatternsSampleText.accessibilityHint, PatternsSampleText.accessibilityRevealHint], key: slot.key)
            }
        }
    }
}
