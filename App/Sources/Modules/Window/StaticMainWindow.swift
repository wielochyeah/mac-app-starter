import SwiftUI

/// The main window for renders: offscreen captures cannot draw `NavigationSplitView`, its glass
/// sidebar or the toolbar, so this draws the same layout from tokens (VoiceBud's HubStaticWindow
/// approach): window chrome, the floating sidebar panel of macOS 26 with the same groups the real
/// sidebar shows, the toolbar band with the search capsule, and the page in the detail column.
struct StaticMainWindow<Detail: View>: View {
    let pages: [AppPage]
    let selection: String?
    var query: String?
    var searchPrompt: String?
    var size: CGSize
    let detail: Detail

    init(pages: [AppPage], selection: String?, query: String? = nil, searchPrompt: String? = nil,
         size: CGSize = Metrics.Window.size, @ViewBuilder detail: () -> Detail) {
        self.pages = pages
        self.selection = selection
        self.query = query
        self.searchPrompt = searchPrompt
        self.size = size
        self.detail = detail()
    }

    var body: some View {
        StaticWindow(size: size) {
            HStack(spacing: 0) {
                StaticSidebar(groups: MainWindowModel.groups(pages), selection: selection)
                    .frame(width: Metrics.sidebarWidth)
                    .padding(Metrics.Sidebar.panelInset)
                VStack(spacing: 0) {
                    StaticToolbar(query: query, prompt: searchPrompt)
                    detail
                        .environment(\.windowSearch, query ?? "")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }
}

/// The floating sidebar panel of the main window as renders draw it (`staticSidebarPanel`).
struct StaticSidebar: View {
    let groups: [SidebarGroup]
    let selection: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Image(systemName: "sidebar.left")
                    .symbolFont(Metrics.Window.toolbarGlyph)
                    .foregroundStyle(t.fg2)
            }
            .frame(height: Metrics.trafficLight)
            .padding(.top, Metrics.trafficInset - Metrics.Sidebar.panelInset)
            .padding(.trailing, Space.s)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(groups) { group in
                    if group.showsTitle {
                        Text(group.section.title)
                            .font(TypeScale.secondarySemibold)
                            .foregroundStyle(t.sideGroup)
                            .frame(height: Metrics.Sidebar.sectionHeight, alignment: .bottom)
                            .padding(.top, Metrics.Sidebar.sectionTop)
                            .padding(.leading, Metrics.Sidebar.contentInset - Space.xs)
                    }
                    ForEach(group.pages) { page in
                        StaticSidebarRow(title: page.title(), symbol: page.symbol, selected: page.id == selection)
                    }
                }
            }
            // the traffic light row above starts `trafficInset` below the window top, the panel `panelInset`
            .padding(.top, Metrics.Sidebar.top - (Metrics.trafficInset - Metrics.Sidebar.panelInset) - Metrics.trafficLight)
            .padding(.horizontal, Space.xs)
            Spacer(minLength: 0)
            SidebarFooterView()
        }
        .frame(maxHeight: .infinity)
        .staticSidebarPanel()
    }
}

private struct StaticSidebarRow: View {
    let title: String
    let symbol: String
    let selected: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.xs) {
            Image(systemName: symbol)
                .symbolFont(Metrics.Sidebar.symbol)
                .foregroundStyle(t.accent)
                .frame(width: Metrics.Sidebar.symbolColumn)
            Text(title)
                .font(TypeScale.body)
                .foregroundStyle(t.fg)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.xs)
        .frame(height: Metrics.Sidebar.listRow)
        .background {
            if selected { RoundedRectangle(cornerRadius: Radius.row, style: .continuous).fill(t.sideSel) }
        }
    }
}

/// The 52 pt toolbar band over the detail column with the search capsule on the right (only when
/// the page uses search, like the real window).
struct StaticToolbar: View {
    var query: String?
    var prompt: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        HStack {
            Spacer()
            if let prompt {
                GlassSurface(cornerRadius: Metrics.Window.toolbarSearch.height / 2) {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "magnifyingglass")
                            .symbolFont(Metrics.Window.tileButtonGlyph, weight: .medium)
                            .foregroundStyle(t.fg2)
                        let text = query ?? ""
                        Text(text.isEmpty ? prompt : text)
                            .font(TypeScale.body)
                            .foregroundStyle(text.isEmpty ? t.fg3 : t.fg)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Space.s)
                    .frame(width: Metrics.Window.toolbarSearch.width, height: Metrics.Window.toolbarSearch.height)
                }
            }
        }
        .padding(.horizontal, Space.m)
        .frame(height: Metrics.Window.toolbarBand)
    }
}
