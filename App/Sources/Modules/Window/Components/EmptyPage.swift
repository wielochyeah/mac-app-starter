import SwiftUI

/// A whole page with nothing to show yet: symbol, title, one calm sentence, at most one action.
/// `EmptyPage.noResults(query)` is the state of a search that found nothing.
struct EmptyPage: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.colorScheme) private var scheme

    init(symbol: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    /// The main window before any module or feature registered a page.
    static var noPages: EmptyPage {
        EmptyPage(symbol: "sidebar.left", title: WindowText.noPagesTitle, message: WindowText.noPagesMessage)
    }

    static func noResults(_ query: String) -> EmptyPage {
        EmptyPage(symbol: "magnifyingglass", title: WindowText.noResultsTitle, message: WindowText.noResultsMessage(query))
    }

    var body: some View {
        EmptyState(symbol: symbol, title: title, message: message, actionTitle: actionTitle, action: action)
            .padding(Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme(scheme).windowBg)
    }
}

/// An empty state inside a `PageScaffold` (a collection without entries, an empty trash): the page
/// keeps its title, the state sits centred in the space under it, as `EmptyPage` does on a page
/// without a title.
struct PageEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.windowPageRest) private var rest

    init(symbol: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        EmptyState(symbol: symbol, title: title, message: message, actionTitle: actionTitle, action: action)
            .frame(maxWidth: .infinity, minHeight: rest)
    }
}

/// A search without hits inside a `PageScaffold`: the page keeps its title and result line, this
/// block takes the place of the content.
///
///     PageScaffold(T.title, subtitle: T.results(found.count, query)) {
///         if found.isEmpty { NoResults(query: query) } else { TileGrid(…) }
///     }
struct NoResults: View {
    let query: String

    var body: some View {
        PageEmptyState(symbol: "magnifyingglass", title: WindowText.noResultsTitle, message: WindowText.noResultsMessage(query))
    }
}
