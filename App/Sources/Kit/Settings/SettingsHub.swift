import SwiftUI

extension SettingKey {
    /// The pane shown last; the window reopens there unless a deep link asks for another one.
    static var settingsPane: SettingKey<String> { .init("kit.settingsPane", default: "general") }
}

/// State of the settings window (VoiceBud HubModel, reduced to what every app needs): the selected
/// pane, deep links, ↑/↓ steps and the ⌘F request. Renders build their own instance with
/// `persists: false`, so a scene never touches the real selection.
@Observable final class SettingsHub {
    static let shared = SettingsHub()

    /// Id of the selected pane (always one of `panes` once the window shows).
    private(set) var pane: String
    /// Bumped by ⌘F; a pane with a search field focuses it (`.onChange(of: hub.searchRequest)`).
    private(set) var searchRequest = 0

    @ObservationIgnored private let persists: Bool
    @ObservationIgnored private let source: () -> [SettingsPane]

    /// `source` defaults to the registry; tests pass their own panes.
    init(pane: String? = nil, persists: Bool = true, source: @escaping () -> [SettingsPane] = { Registry.orderedSettingsPanes }) {
        self.persists = persists
        self.source = source
        let stored = persists ? Settings.shared[.settingsPane] : SettingKey<String>.settingsPane.defaultValue
        self.pane = Self.resolve(pane, current: stored, available: source().map(\.id)) ?? stored
    }

    /// The panes in sidebar order (group, then order, then id).
    var panes: [SettingsPane] { source() }

    var selected: SettingsPane? { panes.first { $0.id == pane } ?? panes.first }

    /// Selects a pane by id (deep link, sidebar click). Unknown ids keep the current pane.
    func select(_ id: String?) {
        guard let next = Self.resolve(id, current: pane, available: panes.map(\.id)), next != pane else { return }
        pane = next
        if persists && !RenderMode.isStatic { Settings.shared[.settingsPane] = next }
    }

    /// Arrow up or down in the sidebar.
    func step(_ offset: Int) {
        select(Self.step(from: pane, by: offset, in: panes.map(\.id)))
    }

    func requestSearch() { searchRequest += 1 }

    // MARK: Rules (pure, tested)

    /// Which pane to show: the requested one if it exists, else the current one if it still exists,
    /// else General, else the first. Nil only when there are no panes at all.
    static func resolve(_ requested: String?, current: String?, available: [String]) -> String? {
        if let requested, available.contains(requested) { return requested }
        if let requested { Log.warn("settings: no pane \"\(public: requested)\"", "settings") }
        if let current, available.contains(current) { return current }
        if available.contains("general") { return "general" }
        return available.first
    }

    /// The id `offset` rows away, clamped at both ends (VoiceBud stops at the ends, no wrap).
    static func step(from current: String, by offset: Int, in ids: [String]) -> String {
        guard let i = ids.firstIndex(of: current) else { return ids.first ?? current }
        return ids[min(max(i + offset, 0), ids.count - 1)]
    }

    /// Panes grouped for the sidebar: content panes first, then the "Settings" group; empty groups
    /// are left out. Input order within a group is kept (the registry already sorts).
    static func groups(_ panes: [SettingsPane]) -> [(group: SettingsGroup, panes: [SettingsPane])] {
        SettingsGroup.allCases.sorted().compactMap { group in
            let members = panes.filter { $0.group == group }
            return members.isEmpty ? nil : (group, members)
        }
    }

    /// The sidebar shows a group label only above the settings group, and only when content panes
    /// sit above it (VoiceBud: content on top without a label, "Einstellungen" below).
    static func showsLabel(for group: SettingsGroup, in groups: [SettingsGroup]) -> Bool {
        group != groups.first
    }
}

/// What the hub shows besides the panes. Set by the kit, modules and projects at registration.
enum SettingsHubExtras {
    /// Counts next to sidebar items by pane id (VoiceBud: history total, dictionary terms). Nil or
    /// zero shows nothing.
    static var counts: [String: () -> Int?] = [:]

    /// The sidebar footer, off by default. VoiceBud shows "All local and offline" there; a project
    /// that really keeps everything on the Mac (no downloads, no sync, no API calls) can opt in:
    ///
    ///     SettingsHubExtras.sidebarFooter = { AnyView(LocalOnlyFooter()) }
    static var sidebarFooter: (() -> AnyView)?

    static func count(for pane: String) -> Int? {
        guard let n = counts[pane]?(), n > 0 else { return nil }
        return n
    }
}

/// Green dot, "All local and offline", "Nothing leaves your Mac" (VoiceBud's sidebar footer). Only
/// true for an app without any network use; see `SettingsHubExtras.sidebarFooter`.
struct LocalOnlyFooter: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: Space.hair) {
            HStack(spacing: Space.sidebarFooterGap) {
                Circle().fill(t.ok).frame(width: Metrics.dot, height: Metrics.dot)
                Text(CommonText.allLocal)
            }
            Text(CommonText.nothingLeaves).padding(.leading, Space.sidebarFooterIndent)
        }
        .font(TypeScale.subtitle)
        .foregroundStyle(t.fg2)
        .accessibilityElement(children: .combine)
    }
}
