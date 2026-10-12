import SwiftUI

// Hand-written environment keys (no @Entry: it needs Xcode's macro plugin).

private nonisolated struct WindowSearchKey: EnvironmentKey {
    static let defaultValue = ""
}

private nonisolated struct WindowPageInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// What the person typed into the toolbar search of the main window (empty when none). Pages
    /// that registered with `WindowSearch.enable(page:prompt:)` filter their content with it.
    var windowSearch: String {
        get { self[WindowSearchKey.self] }
        set { self[WindowSearchKey.self] = newValue }
    }

    /// The horizontal inset of the current content page; shelves scroll out to the window edge
    /// and use it to keep their first tile in line with the title.
    var windowPageInset: CGFloat {
        get { self[WindowPageInsetKey.self] }
        set { self[WindowPageInsetKey.self] = newValue }
    }
}

/// The frame of every content page in the main window: one scroll view, a large title, the same
/// insets everywhere, blocks stacked 32 pt apart.
///
///     PageScaffold(PageText.title, subtitle: PageText.count(items.count)) {
///         HeroHeader(…)
///         Shelf(PageText.recent, items: recent) { Tile(…) }
///     }
///
/// `accessory` sits on the title line (a chip or a button). `showsTitle: false` starts with the
/// first block (a hero carries the title itself).
struct PageScaffold<Content: View, Accessory: View>: View {
    let title: String
    var subtitle: String?
    var showsTitle: Bool
    let accessory: Accessory
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, subtitle: String? = nil, showsTitle: Bool = true,
         @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.showsTitle = showsTitle
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        let t = Theme(scheme)
        PageScroll {
            VStack(alignment: .leading, spacing: Space.pageBlock) {
                if showsTitle { header(t) }
                content
            }
            .padding(.horizontal, Space.page)
            .padding(.top, showsTitle ? Space.s : Space.m)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.windowPageInset, Space.page)
        .background(t.windowBg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func header(_ t: Theme) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(title)
                    .font(TypeScale.pageTitle)
                    .foregroundStyle(t.fg)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(TypeScale.lede).foregroundStyle(t.fg2).lineLimit(2)
                }
            }
            Spacer(minLength: Space.m)
            accessory
        }
    }
}

extension PageScaffold where Accessory == EmptyView {
    init(_ title: String, subtitle: String? = nil, showsTitle: Bool = true, @ViewBuilder content: () -> Content) {
        self.init(title, subtitle: subtitle, showsTitle: showsTitle, accessory: { EmptyView() }, content: content)
    }
}

/// A vertical `ScrollView` in the window (content runs under the macOS 26 toolbar glass, which
/// fades it); a top-aligned, clipped stack in renders, where scroll views cannot draw.
struct PageScroll<Content: View>: View {
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
            ScrollView(.vertical) {
                content.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// A section title inside a page: 17 pt semibold, optional "See All" on the right.
struct PageSectionTitle: View {
    let title: String
    var subtitle: String?
    var seeAll: (() -> Void)?
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, subtitle: String? = nil, seeAll: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.seeAll = seeAll
    }

    var body: some View {
        let t = Theme(scheme)
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.hair) {
                Text(title).font(TypeScale.headline).foregroundStyle(t.fg).lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(TypeScale.secondary).foregroundStyle(t.fg2).lineLimit(1)
                }
            }
            Spacer(minLength: Space.m)
            if let seeAll {
                Button(WindowText.seeAll, action: seeAll)
                    .buttonStyle(PlainStyle())
                    .font(TypeScale.bodyMedium)
                    .foregroundStyle(t.accentText)
            }
        }
    }
}
