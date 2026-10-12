import SwiftUI

// Modules contribute here (in `<Name>Module.register()`); Kit UIs read from here.
// Contributions are appended once at launch by `Modules.registerAll()`; Kit UIs read the
// `ordered…` accessors, which sort deterministically (order, then id).

/// A page in the main window's sidebar (the window module renders it).
struct AppPage: Identifiable {
    let id: String
    let section: PageSection
    let order: Int
    let title: () -> String
    let symbol: String
    let content: () -> AnyView
}

/// Sidebar sections of the main window. Titles in `KitText`.
enum PageSection: Int, CaseIterable, Comparable {
    case main, library, collections

    var title: String { KitText.section(self) }

    static func < (a: PageSection, b: PageSection) -> Bool { a.rawValue < b.rawValue }
}

/// A pane of the settings window (hub). VoiceBud layout: content panes on top, settings below.
struct SettingsPane: Identifiable {
    let id: String
    let group: SettingsGroup
    let order: Int
    let title: () -> String
    let symbol: String
    let tint: TintName
    let content: () -> AnyView
}

enum SettingsGroup: Int, CaseIterable, Comparable {
    case content, settings

    var title: String { KitText.settingsGroup(self) }

    static func < (a: SettingsGroup, b: SettingsGroup) -> Bool { a.rawValue < b.rawValue }
}

/// What an onboarding step gets from the onboarding window.
struct OnboardingContext {
    /// The step sets this to false while something must happen first (Continue is disabled).
    let canContinue: Binding<Bool>
    let next: () -> Void
    let back: () -> Void
    /// Index of this step among the included steps, and their count.
    let index: Int
    let count: Int

    var isFirst: Bool { index == 0 }
    var isLast: Bool { index == count - 1 }
}

struct OnboardingStep: Identifiable {
    let id: String
    let order: Int
    /// Evaluated when onboarding opens (e.g. only when a permission is missing).
    let isIncluded: () -> Bool
    let content: (OnboardingContext) -> AnyView
}

/// An item for the app menu / status item menu.
struct MenuItemContribution: Identifiable {
    let id: String
    let order: Int
    let title: () -> String
    let symbol: String?
    /// Key equivalent with modifiers as text, e.g. "⌘N", "⇧⌘K" (empty or nil for none).
    let shortcut: String?
    let action: () -> Void
}

/// A view rendered by `--render` / `make shots` to `build/shots/<lang>-<appearance>/<id>.png`.
/// Ids are `<area>.<name>`, e.g. "onboarding.welcome", "island.done-card", "design.card".
/// `size == .zero` renders at the view's fitting size.
struct RenderScene: Identifiable {
    let id: String
    let size: CGSize
    let content: () -> AnyView
}

/// A component shown in the gallery (Settings → Components in debug builds).
struct GalleryEntry: Identifiable {
    let id: String
    let area: String
    let title: () -> String
    let content: () -> AnyView
}

/// A check run by `--selftest`. Returns nil when fine, else what is wrong.
struct SelfTestCheck: Identifiable {
    let id: String
    let run: () -> String?
}

@MainActor enum Registry {
    static var pages: [AppPage] = []
    static var settingsPanes: [SettingsPane] = []
    static var onboardingSteps: [OnboardingStep] = []
    static var menuItems: [MenuItemContribution] = []
    static var renderScenes: [RenderScene] = []
    static var gallery: [GalleryEntry] = []
    static var launchHooks: [() -> Void] = []
    static var terminateHooks: [() -> Void] = []
    static var selfTests: [SelfTestCheck] = []
    /// Scripted loops for `--demo` (e.g. the island cycling through its states). Each runs once
    /// after launch hooks in a normal (non-tool) launch and drives itself from there.
    static var demoDrivers: [() -> Void] = []

    // MARK: Ordered views of the contributions

    static var orderedPages: [AppPage] {
        pages.sorted { ($0.section, $0.order, $0.id) < ($1.section, $1.order, $1.id) }
    }

    static var orderedSettingsPanes: [SettingsPane] {
        settingsPanes.sorted { ($0.group, $0.order, $0.id) < ($1.group, $1.order, $1.id) }
    }

    /// Only the steps whose `isIncluded()` is true right now.
    static var orderedOnboardingSteps: [OnboardingStep] {
        onboardingSteps.filter { $0.isIncluded() }.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    static var orderedMenuItems: [MenuItemContribution] {
        menuItems.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    static var orderedRenderScenes: [RenderScene] { renderScenes.sorted { $0.id < $1.id } }

    static var orderedGallery: [GalleryEntry] {
        gallery.sorted { ($0.area, $0.id) < ($1.area, $1.id) }
    }

    /// Duplicate ids and other contract violations, empty when fine.
    static func problems() -> [String] {
        var out: [String] = []
        func dupes(_ kind: String, _ ids: [String]) {
            var seen = Set<String>()
            for id in ids where !seen.insert(id).inserted { out.append("duplicate \(kind) id \(id)") }
        }
        dupes("page", pages.map(\.id))
        dupes("settings pane", settingsPanes.map(\.id))
        dupes("onboarding step", onboardingSteps.map(\.id))
        dupes("menu item", menuItems.map(\.id))
        dupes("render scene", renderScenes.map(\.id))
        dupes("gallery entry", gallery.map(\.id))
        dupes("self-test", selfTests.map(\.id))
        for scene in renderScenes where !scene.id.contains(".") {
            out.append("render scene id \(scene.id) needs an area prefix like \"design.\"")
        }
        return out
    }

    /// Runs `body` with empty contributions and restores them afterwards (tests).
    static func withScratch<T>(_ body: () throws -> T) rethrows -> T {
        let saved = (pages, settingsPanes, onboardingSteps, menuItems, renderScenes, gallery, launchHooks, terminateHooks, selfTests)
        let savedDemo = demoDrivers
        pages = []; settingsPanes = []; onboardingSteps = []; menuItems = []; renderScenes = []
        gallery = []; launchHooks = []; terminateHooks = []; selfTests = []; demoDrivers = []
        defer {
            (pages, settingsPanes, onboardingSteps, menuItems, renderScenes, gallery, launchHooks, terminateHooks, selfTests) = saved
            demoDrivers = savedDemo
        }
        return try body()
    }
}
