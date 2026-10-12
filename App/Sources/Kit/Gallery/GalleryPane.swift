import SwiftUI

/// Settings pane "Gallery": every `Registry.gallery` entry, grouped by area, each on a stage that
/// can be switched to light or dark independently of the window. Wide entries (whole window
/// samples) are scaled down to the stage, flexible ones fill it. ⌘F focuses the search.
struct GalleryPane: View {
    @State private var area: String
    @State private var query: String
    @State private var scheme: GalleryScheme
    @FocusState private var searchFocused: Bool
    @Environment(\.settingsHub) private var hub
    @Environment(\.colorScheme) private var windowScheme

    /// Renders pass a fixed filter, query and preview appearance.
    init(area: String? = nil, query: String = "", scheme: GalleryScheme = .window) {
        _area = State(initialValue: area ?? "")
        _query = State(initialValue: query)
        _scheme = State(initialValue: scheme)
    }

    var body: some View {
        let entries = Registry.orderedGallery
        let groups = GalleryModel.groups(entries, area: area.isEmpty ? nil : area, query: query)
        PaneScaffold(title: GalleryText.title, symbol: "square.grid.2x2.fill", tint: .indigo, layout: .fill) {
            SearchField(text: $query, prompt: GalleryText.searchPrompt, size: Metrics.searchFieldCompact)
                .focused($searchFocused)
        } content: {
            subBar(entries: entries, shown: groups.reduce(0) { $0 + $1.entries.count })
            if entries.isEmpty {
                EmptyState(symbol: "square.grid.2x2", title: GalleryText.emptyTitle, message: GalleryText.emptyMessage)
            } else if groups.isEmpty {
                EmptyState(symbol: "magnifyingglass", title: PatternsText.noResults, message: PatternsText.nothingFound(query))
            } else {
                PaneScroll {
                    LazyVStack(alignment: .leading, spacing: Space.xl) {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                areaHeader(group)
                                VStack(alignment: .leading, spacing: Space.pane) {
                                    ForEach(group.entries) { entry in
                                        GalleryEntryView(entry: entry, scheme: scheme.resolve(windowScheme))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Space.pane)
                    .padding(.top, Space.m)
                    .padding(.bottom, Space.l)
                }
            }
        }
        .onChange(of: hub?.searchRequest) { searchFocused = true }
    }

    private func areaHeader(_ group: GalleryModel.Group) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text(GalleryText.area(group.area)).font(TypeScale.headline).foregroundStyle(Theme(windowScheme).fg)
            CountBadge(group.entries.count, style: .pill)
        }
        .padding(.leading, Space.xxs)
        .padding(.bottom, Space.s)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func subBar(entries: [GalleryEntry], shown: Int) -> some View {
        let t = Theme(windowScheme)
        let areas = GalleryModel.areas(entries)
        return HStack(spacing: Space.s) {
            MenuPicker([("", GalleryText.allAreas)] + areas.map { ($0, GalleryText.area($0)) }, selection: $area)
                .accessibilityLabel(GalleryText.areaLabel)
            Text(GalleryText.count(shown))
                .font(TypeScale.count)
                .foregroundStyle(t.fg2)
                .contentTransition(.numericText())
            Spacer(minLength: Space.s)
            Segmented(GalleryScheme.allCases.map { ($0, $0.title) }, selection: $scheme)
                .accessibilityLabel(GalleryText.previewLabel)
        }
        .padding(.horizontal, Space.pane)
        .frame(height: Metrics.subBar)
        .overlay(alignment: .bottom) { Rectangle().fill(t.separator).frame(height: Metrics.hairline) }
    }
}

/// One entry: title and id above a stage in the chosen appearance.
struct GalleryEntryView: View {
    let entry: GalleryEntry
    /// Appearance of the stage (may differ from the window's).
    let scheme: ColorScheme
    @Environment(\.colorScheme) private var windowScheme

    var body: some View {
        let t = Theme(windowScheme)
        let stage = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text(entry.title()).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
                Spacer(minLength: Space.xs)
                // verbatim: the entry id is a code identifier (what to search for in the source)
                Text(verbatim: entry.id)
                    .font(TypeScale.caption.monospaced())
                    .foregroundStyle(t.fg3)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, Space.xxs)
            preview
                .environment(\.colorScheme, scheme)
                .padding(Space.m)
                .frame(maxWidth: .infinity)
                .background(shape.fill(stage.windowBg))
                .clipShape(shape)
                .overlay(shape.strokeBorder(t.cardStroke, lineWidth: Metrics.hairline))
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var preview: some View {
        switch GalleryFit.size(of: entry) {
        case .fixed(let ideal):
            GalleryFitLayout(ideal: ideal) {
                GeometryReader { geo in
                    entry.content()
                        .frame(width: ideal.width, height: ideal.height)
                        .scaleEffect(GalleryFit.scale(ideal: ideal, available: geo.size.width), anchor: .topLeading)
                }
            }
        case .flexible:
            entry.content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
