import SwiftUI

// A settings pane (VoiceBud HubPaneHeader + HubSettingsColumn + HubScroll, notes §3.2):
// a 52 pt header band with the pane's squircle and title that sits in the window's toolbar band,
// below it one scrolling column, max 640 pt wide and anchored left under the title.

/// Every settings pane (kit and modules) starts with this, so all panes line up.
///
///     PaneScaffold(title: MyText.pane, symbol: "bell.badge.fill", tint: .red) {
///         SettingsSection(MyText.behavior, footnote: MyText.note) {
///             ToggleRow(MyText.sounds, isOn: $sounds)
///         }
///     }
///
/// `layout: .fill` hands the whole area below the header to the content (own list, own scroll),
/// `trailing` goes on the right of the header (a search field).
struct PaneScaffold<Content: View, Trailing: View>: View {
    enum Layout { case column, fill }

    let title: String
    var symbol: String?
    var tint: TintName
    var subtitle: String?
    var layout: Layout
    let trailing: Trailing
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(title: String, symbol: String? = nil, tint: TintName = .accent, subtitle: String? = nil, layout: Layout = .column,
         @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.subtitle = subtitle
        self.layout = layout
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            SectionHeader(title, symbol: symbol, tint: tint) { trailing }
            switch layout {
            case .column:
                SettingsColumn {
                    VStack(alignment: .leading, spacing: 0) {
                        if let subtitle { PaneIntro(subtitle).padding(.bottom, Space.paneIntroBottom) }
                        VStack(alignment: .leading, spacing: Space.pane) { content }
                    }
                }
            case .fill:
                VStack(spacing: 0) { content }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(t.windowBg)
    }
}

extension PaneScaffold where Trailing == EmptyView {
    init(title: String, symbol: String? = nil, tint: TintName = .accent, subtitle: String? = nil, layout: Layout = .column,
         @ViewBuilder content: () -> Content) {
        self.init(title: title, symbol: symbol, tint: tint, subtitle: subtitle, layout: layout, trailing: { EmptyView() },
                  content: content)
    }
}

/// One or two sentences under the header band that say what the pane is for (12.5 `fg2`).
struct PaneIntro: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(TypeScale.paneIntro)
            .foregroundStyle(Theme(scheme).fg2)
            .lineSpacing(TypeScale.footnoteLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}

/// A `ScrollView` in the window; a clipped, top-aligned stack in renders (offscreen captures cannot
/// draw `NSScrollView`). Clipped either way: on macOS 26 a scroll view lets content run up under
/// the titlebar, where the pane header sits.
struct PaneScroll<Content: View>: View {
    let content: Content
    @Environment(\.renderStatic) private var renderStatic

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        if renderStatic {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    VStack(spacing: 0) { content }.fixedSize(horizontal: false, vertical: true)
                }
                .clipped()
        } else {
            ScrollView {
                content.frame(maxWidth: .infinity)
            }
            .clipped()
        }
    }
}

/// The settings column: padding 20 / 16 top / 24 bottom, at most 640 pt, anchored left so title and
/// cards share one edge. Children are stacked 20 pt apart (the gap between setting groups).
struct SettingsColumn<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        PaneScroll {
            VStack(alignment: .leading, spacing: Space.pane) { content }
                .padding(.horizontal, Space.pane)
                .padding(.top, Space.m)
                .padding(.bottom, Space.l)
                .frame(maxWidth: Metrics.settingsColumn, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A group of settings: label above (12.5 semibold `fg2`), the rows in one `Card` with hairlines
/// between them (added automatically, also around rows that appear conditionally), and an optional
/// footnote below. When the footnote changes with a choice, `footnoteReserve` lists every text it
/// can show, so the section keeps the height of the longest one (`footnoteLines`: fixed lines).
///
///     SettingsSection(MyText.language, footnote: MyText.languageNote) {
///         PickerRow(MyText.interface, options: …, selection: $lang)
///         if showsMore { ToggleRow(…) }
///     }
struct SettingsSection<Content: View>: View {
    var title: String?
    var footnote: String?
    var footnoteLines: Int
    var footnoteReserve: [String]
    var tone: TextTone
    let content: Content

    init(_ title: String? = nil, footnote: String? = nil, footnoteLines: Int = 0, footnoteReserve: [String] = [],
         tone: TextTone = .settings, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footnote = footnote
        self.footnoteLines = footnoteLines
        self.footnoteReserve = footnoteReserve
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title { GroupLabel(title) }
            Card {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        if i > 0 { Separator() }
                        row
                    }
                }
            }
            if let footnote {
                Footnote(footnote, lines: footnoteLines, reserve: footnoteReserve, tone: tone)
                    .transaction { $0.animation = nil }   // swaps, never animates (VoiceBud)
            }
        }
        .tone(tone)
    }
}

// MARK: - Text tone in the environment

private nonisolated struct TextToneKey: EnvironmentKey {
    static let defaultValue: TextTone = .settings
}

extension EnvironmentValues {
    /// The small-text tone rows pick up from their `SettingsSection` (settings 11.5 `fg2`,
    /// onboarding 12 `prose`), so a section used on a setup step needs `tone:` only once.
    var textTone: TextTone {
        get { self[TextToneKey.self] }
        set { self[TextToneKey.self] = newValue }
    }
}

extension View {
    func tone(_ tone: TextTone) -> some View { environment(\.textTone, tone) }
}
