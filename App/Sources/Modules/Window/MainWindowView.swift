import SwiftUI

/// The main window's content: a native `NavigationSplitView` (macOS 26 draws the sidebar as a
/// floating glass panel and the toolbar as glass), sidebar from `Registry.pages` grouped by
/// `PageSection`, the selected page in the detail column, and the toolbar search for pages that
/// enabled it (`WindowSearch`).
struct MainWindowView: View {
    @State private var model: MainWindowModel
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var scheme

    init(model: MainWindowModel = .shared) {
        _model = State(initialValue: model)
    }

    var body: some View {
        let t = Theme(scheme)
        NavigationSplitView(columnVisibility: $model.columnVisibility) {
            MainSidebar(groups: MainWindowModel.groups(model.pages),
                        selection: Binding(get: { model.currentPage?.id }, set: { model.select($0) }))
                .navigationSplitViewColumnWidth(min: Metrics.Window.sidebarMin, ideal: Metrics.Window.sidebarIdeal,
                                                max: Metrics.Window.sidebarMax)
        } detail: {
            detail(t)
        }
        .tint(t.accent)
        .onChange(of: model.searchFocusPending, initial: true) { _, pending in
            guard pending else { return }
            model.searchFocusPending = false
            // the toolbar's search field exists only after this layout pass
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    @ViewBuilder
    private func detail(_ t: Theme) -> some View {
        let page = model.currentPage
        let content = Group {
            if let page {
                page.content()
            } else {
                EmptyPage(symbol: "sidebar.left", title: WindowText.noPagesTitle, message: WindowText.noPagesMessage)
            }
        }
        .id(page?.id)
        .environment(\.windowSearch, model.query)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(t.windowBg)

        if let page, WindowSearch.isEnabled(page.id) {
            content
                .searchable(text: $model.query, placement: .toolbar, prompt: Text(WindowSearch.prompt(page.id)))
                .searchFocused($searchFocused)
        } else {
            content
        }
    }
}

/// The native sidebar list: accent SF Symbols, section titles from `PageSection`, footer lines.
private struct MainSidebar: View {
    let groups: [SidebarGroup]
    @Binding var selection: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        List(selection: $selection) {
            ForEach(groups) { group in
                if group.showsTitle {
                    Section(group.section.title) { rows(group, t) }
                } else {
                    rows(group, t)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooterView()
        }
        .accessibilityLabel(WindowText.sidebar)
    }

    private func rows(_ group: SidebarGroup, _ t: Theme) -> some View {
        ForEach(group.pages) { page in
            Label {
                Text(page.title())
            } icon: {
                Image(systemName: page.symbol).foregroundStyle(t.accent)
            }
            .tag(page.id)
        }
    }
}

/// The status lines at the foot of the sidebar (`WindowSidebarFooter`), below a hairline. Lines
/// and hairline share the rows' leading inset, so the dot sits under the row symbols.
struct SidebarFooterView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let items = WindowSidebarFooter.ordered
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Space.xs) {
                Separator()
                ForEach(items) { item in item.content() }
            }
            .padding(.horizontal, Metrics.Window.sidebarContentInset)
            .padding(.bottom, Space.s)
        }
    }
}

/// A footer line: a 7 pt dot and a short status (VoiceBud "Alles lokal und offline").
struct SidebarStatusLine: View {
    let text: String
    var ok = true
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.xs) {
            Circle().fill(ok ? t.ok : t.warn).frame(width: Metrics.dot, height: Metrics.dot)
                .frame(width: Metrics.Window.sidebarSymbolColumn)
            Text(text).font(TypeScale.subtitle).foregroundStyle(t.fg2).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
