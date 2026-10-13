import SwiftUI

/// A list of things in one card (apps, terms, jobs): a header row with title, count and an
/// optional search field; rows with a hover highlight (radius 10 `rowHover`, hairlines hidden next
/// to it, VoiceBud history); a calm empty state ("No apps yet" or "No results").
///
///     ListCard(MyText.apps, items: apps, query: $query, searchPrompt: MyText.searchApps,
///              matches: { app, q in ListSearch.matches(app.name, query: q) },
///              emptyTitle: MyText.noApps, emptyMessage: MyText.noAppsDetail) { app, hovered in
///         Row(app.name, symbol: app.symbol) { if hovered { Chip(CommonText.remove) { remove(app) } } }
///     }
struct ListCard<Item: Identifiable, RowContent: View>: View {
    let title: String
    let items: [Item]
    var query: Binding<String>?
    var searchPrompt: String
    var matches: ((Item, String) -> Bool)?
    let emptyTitle: String
    var emptyMessage: String?
    /// Shows a row as hovered without a pointer (renders, tests).
    var previewHovered: Item.ID?
    let row: (Item, Bool) -> RowContent
    @State private var hovered: Item.ID?
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, items: [Item], query: Binding<String>? = nil, searchPrompt: String = CommonText.search,
         matches: ((Item, String) -> Bool)? = nil, emptyTitle: String, emptyMessage: String? = nil,
         previewHovered: Item.ID? = nil, @ViewBuilder row: @escaping (_ item: Item, _ hovered: Bool) -> RowContent) {
        self.title = title
        self.items = items
        self.query = query
        self.searchPrompt = searchPrompt
        self.matches = matches
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.previewHovered = previewHovered
        self.row = row
    }

    private var text: String { query?.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }

    private var visible: [Item] {
        guard !text.isEmpty, let matches else { return items }
        return items.filter { matches($0, text) }
    }

    var body: some View {
        let t = Theme(scheme)
        let shown = visible
        Card {
            header(t, count: shown.count)
            Separator()
            if shown.isEmpty {
                empty(t)
            } else {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, item in
                    let isHovered = isHot(item.id)
                    let previousHovered = i > 0 && isHot(shown[i - 1].id)
                    if i > 0 { Separator().opacity(isHovered || previousHovered ? 0 : 1) }
                    row(item, isHovered)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                                .fill(isHovered ? t.rowHover : .clear)
                                .padding(.horizontal, Space.xxs)
                        )
                        .contentShape(Rectangle())
                        .onHover { inside in
                            withAnimation(Motion.fade) {
                                if inside { hovered = item.id } else if hovered == item.id { hovered = nil }
                            }
                        }
                }
            }
        }
    }

    private func isHot(_ id: Item.ID) -> Bool { hovered == id || previewHovered == id }

    private func header(_ t: Theme, count: Int) -> some View {
        HStack(spacing: Space.xs) {
            Text(title).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
            CountBadge(count, style: .pill)
            Spacer(minLength: Space.s)
            if let query, !items.isEmpty {
                SearchField(text: query, prompt: searchPrompt, size: Metrics.searchFieldCompact)
            }
        }
        .padding(.horizontal, Space.rowX)
        .frame(minHeight: Metrics.rowMinHeight)
    }

    private func empty(_ t: Theme) -> some View {
        VStack(spacing: Space.xxs) {
            if text.isEmpty {
                Text(emptyTitle).font(TypeScale.emptyTitle).foregroundStyle(t.fg)
                if let emptyMessage { Text(emptyMessage).font(TypeScale.paneIntro).foregroundStyle(t.fg2) }
            } else {
                Text(PatternsText.noResults).font(TypeScale.emptyTitle).foregroundStyle(t.fg)
                Text(PatternsText.nothingFound(text)).font(TypeScale.paneIntro).foregroundStyle(t.fg2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metrics.listEmptyPadding)
    }
}

/// Search matching for lists (pure; PatternsTests): every word of the query must appear in one of
/// the fields, ignoring case and diacritics ("uber" finds "Über").
enum ListSearch {
    static func matches(_ fields: String..., query: String) -> Bool {
        matches(fields, query: query)
    }

    static func matches(_ fields: [String], query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return true }
        let haystack = fields.joined(separator: "\n")
        return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}

/// The search field of pane headers and list cards (VoiceBud hub): `field` fill, radius 8,
/// magnifier, 12.5 pt text, clear button while there is text, Esc clears. A static stand-in in
/// renders (offscreen captures cannot draw `TextField`).
struct SearchField: View {
    @Binding var text: String
    var prompt: String
    var size: CGSize
    @Environment(\.colorScheme) private var scheme
    @Environment(\.renderStatic) private var renderStatic

    init(text: Binding<String>, prompt: String = CommonText.search, size: CGSize = Metrics.searchField) {
        _text = text
        self.prompt = prompt
        self.size = size
    }

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .symbolFont(11.5, weight: .medium)
                .foregroundStyle(t.fg3)
            if renderStatic {
                Text(text.isEmpty ? prompt : text)
                    .foregroundStyle(text.isEmpty ? t.fg3 : t.fg)
                    .lineLimit(1)
                Spacer(minLength: 0)
            } else {
                TextField("", text: $text, prompt: Text(prompt))
                    .textFieldStyle(.plain)
                    .foregroundStyle(t.fg)
                    .onExitCommand { text = "" }
            }
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(t.fg3)
                }
                .buttonStyle(PlainStyle())
                .accessibilityLabel(PatternsText.clearSearch)
            }
        }
        .font(TypeScale.search)
        .padding(.horizontal, 9)
        .frame(width: size.width, height: size.height)
        .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(t.field))
    }
}

/// A count next to a title: plain (sidebar, VoiceBud 11.5 monospaced, `fg2` for 4.5:1) or as a small pill
/// (list headers). Nothing is drawn for nil.
struct CountBadge: View {
    enum Style { case plain, pill }
    let count: Int?
    var style: Style
    @Environment(\.colorScheme) private var scheme

    init(_ count: Int?, style: Style = .plain) {
        self.count = count
        self.style = style
    }

    var body: some View {
        if let count {
            let t = Theme(scheme)
            switch style {
            case .plain:
                Text(Format.number(count)).font(TypeScale.count).foregroundStyle(t.fg2)
                    .contentTransition(.numericText())
            case .pill:
                Text(Format.number(count))
                    .font(TypeScale.badge.monospacedDigit())
                    .foregroundStyle(t.fg2)
                    .padding(.horizontal, 6)
                    .frame(minWidth: Metrics.badgeHeight, minHeight: Metrics.badgeHeight)
                    .background(Capsule().fill(t.chip))
                    .contentTransition(.numericText())
            }
        }
    }
}
