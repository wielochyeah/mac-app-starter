import SwiftUI

extension SettingKey {
    /// The page selected in the main window's sidebar (restored on the next launch).
    static var windowPage: SettingKey<String> { .init("window.page", default: "") }
    /// The sidebar was hidden with ⌃⌘S or the toolbar button.
    static var windowSidebarHidden: SettingKey<Bool> { .init("window.sidebarHidden", default: false) }
}

/// A sidebar section with its pages, in display order.
struct SidebarGroup: Identifiable {
    let section: PageSection
    let pages: [AppPage]
    var id: Int { section.rawValue }
    /// The first section has no title (Music: Home, New, Radio sit on top without a header).
    var showsTitle: Bool { section != .main }
}

/// Pages that use the toolbar search. Only these show the search field, so it never sits there
/// without doing anything. The query reaches the page as `\.windowSearch`.
///
///     WindowSearch.enable(page: "library") { LibraryText.searchPrompt }
enum WindowSearch {
    private(set) static var prompts: [String: () -> String] = [:]

    static func enable(page id: String, prompt: @escaping () -> String = { CommonText.search }) {
        prompts[id] = prompt
    }

    static func disable(page id: String) { prompts[id] = nil }

    static func isEnabled(_ id: String?) -> Bool { id.map { prompts[$0] != nil } ?? false }
    static func prompt(_ id: String) -> String { prompts[id]?() ?? CommonText.search }

    /// Tests.
    static func reset() { prompts = [:] }
}

/// State of the main window: selected page, search query, sidebar visibility. One per app (there
/// is one main window); survives the window closing so reopening shows the same page.
@Observable final class MainWindowModel {
    static let shared = MainWindowModel(settings: .shared)

    @ObservationIgnored private let settings: Settings
    private(set) var selection: String?
    var query = ""
    var columnVisibility: NavigationSplitViewVisibility {
        didSet {
            // SwiftUI writes the binding back on its own; only a real change reaches the file
            let hidden = columnVisibility == .detailOnly
            if settings[.windowSidebarHidden] != hidden { settings[.windowSidebarHidden] = hidden }
        }
    }
    /// Set by ⌘F; the view focuses the search field and clears it, also when ⌘F opened the
    /// window and the view appears only now.
    var searchFocusPending = false

    init(settings: Settings) {
        self.settings = settings
        columnVisibility = settings[.windowSidebarHidden] ? .detailOnly : .all
        let saved = settings[.windowPage]
        selection = saved.isEmpty ? nil : saved
    }

    // MARK: Pure rules (tested)

    /// Sections in order, each with its pages in order; empty sections are left out.
    static func groups(_ pages: [AppPage]) -> [SidebarGroup] {
        let ordered = pages.sorted { ($0.section, $0.order, $0.id) < ($1.section, $1.order, $1.id) }
        return PageSection.allCases.compactMap { section in
            let inSection = ordered.filter { $0.section == section }
            return inSection.isEmpty ? nil : SidebarGroup(section: section, pages: inSection)
        }
    }

    /// The saved page when it still exists, else the first page (nil without pages).
    static func resolve(saved: String?, in pages: [AppPage]) -> String? {
        let ordered = groups(pages).flatMap(\.pages)
        if let saved, ordered.contains(where: { $0.id == saved }) { return saved }
        return ordered.first?.id
    }

    // MARK: State

    var pages: [AppPage] { Registry.orderedPages }

    /// The page shown in the detail column.
    var currentPage: AppPage? {
        let id = Self.resolve(saved: selection, in: pages)
        return pages.first { $0.id == id }
    }

    func select(_ id: String?) {
        guard let id, id != selection else { return }
        selection = id
        query = ""
        settings[.windowPage] = id
    }

    func toggleSidebar() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }

    /// The shown page has the toolbar search (Edit > Find is enabled only then).
    var hasSearch: Bool { WindowSearch.isEnabled(currentPage?.id) }

    func focusSearch() {
        guard hasSearch else { return }
        searchFocusPending = true
    }
}

/// Lines at the foot of the main window's sidebar (Music shows the account there; the starter
/// shows that everything stays on the Mac). Modules and features add their own:
///
///     WindowSidebarFooter.add(id: "sync", order: 10) { AnyView(SyncStatusLine()) }
enum WindowSidebarFooter {
    struct Item: Identifiable {
        let id: String
        let order: Int
        let content: () -> AnyView
    }

    private(set) static var items: [Item] = []

    static func add(id: String, order: Int, content: @escaping () -> AnyView) {
        items.removeAll { $0.id == id }
        items.append(Item(id: id, order: order, content: content))
    }

    static func remove(id: String) { items.removeAll { $0.id == id } }

    static var ordered: [Item] { items.sorted { ($0.order, $0.id) < ($1.order, $1.id) } }
}
