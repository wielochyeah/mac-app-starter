import SwiftUI

/// One row of an `ItemList`.
struct ItemListItem: Identifiable {
    let id: String
    let title: String
    var secondary: String?
    /// Right-aligned, monospaced digits (a length, a count, a date).
    var meta: String?
    /// Artwork seed and glyph for `.artwork` rows (seed defaults to the id).
    var seed: String?
    var symbol: String?

    init(id: String, title: String, secondary: String? = nil, meta: String? = nil, seed: String? = nil, symbol: String? = nil) {
        self.id = id
        self.title = title
        self.secondary = secondary
        self.meta = meta
        self.seed = seed
        self.symbol = symbol
    }
}

/// Column titles above an `ItemList` (nil hides a column title, not the column).
struct ItemListColumns {
    var title: String
    var secondary: String?
    var meta: String?

    init(title: String, secondary: String? = nil, meta: String? = nil) {
        self.title = title
        self.secondary = secondary
        self.meta = meta
    }
}

/// Rows like a Music track list: number or small artwork, title, a secondary column, meta on the
/// right. Every other row is lightly striped; hover tints a row clearly above the stripe, a click
/// selects it (solid accent while the window is active, a soft tint when it is not), a double click
/// opens it, and `menu` adds a context menu.
///
///     ItemList(items: rows, leading: .index, columns: ItemListColumns(title: T.title, meta: T.length),
///              selection: $selected, open: { play($0) }) { item in
///         Button(CommonText.remove) { remove(item) }
///     }
struct ItemList<Menu: View>: View {
    enum Leading { case index, artwork, none }

    let items: [ItemListItem]
    var leading: Leading
    var columns: ItemListColumns?
    var selection: Binding<String?>?
    /// Draws one row as hovered (renders, gallery).
    var previewHovered: String?
    var open: ((ItemListItem) -> Void)?
    let menu: ((ItemListItem) -> Menu)?

    init(items: [ItemListItem], leading: Leading = .index, columns: ItemListColumns? = nil,
         selection: Binding<String?>? = nil, previewHovered: String? = nil, open: ((ItemListItem) -> Void)? = nil,
         @ViewBuilder menu: @escaping (ItemListItem) -> Menu) {
        self.items = items
        self.leading = leading
        self.columns = columns
        self.selection = selection
        self.previewHovered = previewHovered
        self.open = open
        self.menu = menu
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let columns { ItemListHeader(columns: columns, leading: leading, hasSecondary: hasSecondary) }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ItemListRow(item: item, index: index, leading: leading, hasSecondary: hasSecondary,
                            isSelected: selection?.wrappedValue == item.id, previewHovered: previewHovered == item.id,
                            select: { selection?.wrappedValue = item.id }, open: open.map { o in { o(item) } })
                    .contextMenu { if let menu { menu(item) } }
            }
        }
    }

    private var hasSecondary: Bool { items.contains { $0.secondary != nil } }
}

extension ItemList where Menu == EmptyView {
    init(items: [ItemListItem], leading: Leading = .index, columns: ItemListColumns? = nil,
         selection: Binding<String?>? = nil, previewHovered: String? = nil, open: ((ItemListItem) -> Void)? = nil) {
        self.items = items
        self.leading = leading
        self.columns = columns
        self.selection = selection
        self.previewHovered = previewHovered
        self.open = open
        self.menu = nil
    }
}

private struct ItemListHeader<Menu: View>: View {
    let columns: ItemListColumns
    let leading: ItemList<Menu>.Leading
    let hasSecondary: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            HStack(spacing: Space.s) {
                ItemListLeadingSpace(leading: leading)
                Text(columns.title).frame(maxWidth: .infinity, alignment: .leading)
                if hasSecondary {
                    Text(columns.secondary ?? "").frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(columns.meta ?? "").frame(width: Metrics.Window.listMeta, alignment: .trailing)
            }
            .font(TypeScale.secondaryMedium)
            .foregroundStyle(t.fg2)
            .lineLimit(1)
            .padding(.horizontal, Space.rowX)
            .padding(.vertical, Space.xs)
            Separator()
        }
        .accessibilityHidden(true)
    }
}

private struct ItemListLeadingSpace<Menu: View>: View {
    let leading: ItemList<Menu>.Leading

    var body: some View {
        switch leading {
        case .index: Color.clear.frame(width: Metrics.Window.listIndex, height: 1)
        case .artwork: Color.clear.frame(width: Metrics.Window.listArtwork, height: 1)
        case .none: EmptyView()
        }
    }
}

private struct ItemListRow<Menu: View>: View {
    let item: ItemListItem
    let index: Int
    let leading: ItemList<Menu>.Leading
    let hasSecondary: Bool
    let isSelected: Bool
    let previewHovered: Bool
    let select: () -> Void
    let open: (() -> Void)?

    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.controlActiveState) private var activeState

    /// Solid accent selection like macOS lists, while the window is key or active.
    private var strongSelection: Bool { isSelected && activeState != .inactive }

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.s) {
            switch leading {
            case .index:
                Text(Format.number(index + 1))
                    .font(TypeScale.secondary.monospacedDigit())
                    .foregroundStyle(strongSelection ? t.onAccent : isSelected ? t.accentText : t.fg3)
                    .frame(width: Metrics.Window.listIndex, alignment: .trailing)
            case .artwork:
                Artwork(seed: item.seed ?? item.id, symbol: item.symbol)
                    .frame(width: Metrics.Window.listArtwork, height: Metrics.Window.listArtwork)
            case .none:
                EmptyView()
            }
            Text(item.title)
                .font(TypeScale.body)
                .foregroundStyle(strongSelection ? t.onAccent : isSelected ? t.accentText : t.fg)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if hasSecondary {
                Text(item.secondary ?? "")
                    .font(TypeScale.body)
                    .foregroundStyle(strongSelection ? t.onAccent : t.fg2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(item.meta ?? "")
                .font(TypeScale.secondary.monospacedDigit())
                .foregroundStyle(strongSelection ? t.onAccent : t.fg2)
                .lineLimit(1)
                .frame(width: Metrics.Window.listMeta, alignment: .trailing)
        }
        .padding(.horizontal, Space.rowX)
        .frame(minHeight: leading == .artwork ? Metrics.Window.listRow : Metrics.sidebarRow)
        .background(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).fill(background(t)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { open?() }
        .simultaneousGesture(TapGesture().onEnded { select() })
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { open?() }
    }

    private func background(_ t: Theme) -> Color {
        if strongSelection { return t.accent }
        if isSelected { return t.accentSoft }
        if hovering || previewHovered { return t.listHover }
        return index.isMultiple(of: 2) ? .clear : t.rowHover
    }
}
