import SwiftUI

/// Sample data for renders: the seed in memory at a fixed time (9:41), so every render is the same.
enum NotesSamples {
    static var now: Date {
        Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date(timeIntervalSince1970: 1_791_000_000)) ?? Date()
    }

    static func store(seed: Bool = true) -> NotesStore { NotesStore(url: nil, now: { now }, seed: seed) }

    /// The store with two notes in the trash.
    static func storeWithTrash() -> NotesStore {
        let store = store()
        for title in [NotesSampleText.bikeTitle, NotesSampleText.dentistTitle] {
            if let note = store.notes.first(where: { $0.title == title }) { store.trash(note.id) }
        }
        return store
    }

    static func meeting(in store: NotesStore) -> NoteItem? { store.notes.first { $0.title == NotesSampleText.meetingTitle } }

    /// The settings pane in the settings window's detail column.
    static let paneSize = CGSize(width: 676, height: 560)
}

/// Render scenes `examples.*` and gallery entries: every page and state of the feature, each part
/// only when its module is compiled.
enum NotesScenes {
    static func register() {
        scene("pane") {
            NotesPane(store: NotesSamples.store(), location: NotesPane.usualLocation)
                .frame(width: NotesSamples.paneSize.width, height: NotesSamples.paneSize.height)
        }
        scene("pane-confirm") {
            NotesPane(store: NotesSamples.store(), location: NotesPane.usualLocation, confirmingReload: true)
                .frame(width: NotesSamples.paneSize.width, height: NotesSamples.paneSize.height)
        }
        scene("onboarding") { NotesOnboardingSample() }
        #if MODUL_WINDOW
        NotesWindowScenes.register()
        #endif
        #if MODUL_MENUBAR
        scene("menubar") { NotesPanelSample(store: NotesSamples.store()) }
        scene("menubar-empty") { NotesPanelSample(store: NotesSamples.store(seed: false)) }
        #endif
        #if MODUL_ISLAND
        NotesIslandScenes.register()
        #endif
        #if MODUL_HOTKEYS
        scene("hotkey") { NotesHotkeySample() }
        #endif
        #if MODUL_BACKGROUND
        scene("background") { NotesJobSample() }
        #endif
    }

    static func scene<Content: View>(_ name: String, size: CGSize = .zero, @ViewBuilder _ content: @escaping () -> Content) {
        Registry.renderScenes.append(RenderScene(id: "examples.\(name)", size: size) { AnyView(content()) })
    }

    static func gallery<Content: View>(_ name: String, title: @escaping () -> String, @ViewBuilder _ content: @escaping () -> Content) {
        Registry.gallery.append(GalleryEntry(id: "examples.\(name)", area: "examples", title: title) { AnyView(content()) })
    }
}

/// The onboarding's features step with the cards this build adds.
private struct NotesOnboardingSample: View {
    var body: some View {
        let features = OnboardingFeatures.pick(OnboardingFeatures.items.filter { $0.id.hasPrefix("notes.") })
        RenderBoard {
            StaticWindow(size: Metrics.onboardingWindow, chrome: .onboarding) {
                OnboardingFrame {
                    FeaturesStep(features: features)
                } footer: {
                    OnboardingFooter(count: 6, index: 2, back: {}, advance: {})
                }
            }
        }
    }
}

#if MODUL_MENUBAR
/// The status menu panel with the notes section, hanging under the menu bar on the desktop (the
/// menu bar module's stage), with "Save Clipboard as Note" among the actions.
private struct NotesPanelSample: View {
    let store: NotesStore

    var body: some View {
        let capture = MenuItemContribution(id: "notes.capture", order: 100, title: { NotesText.captureAction },
                                           symbol: "doc.on.clipboard", shortcut: nil) {}
        MenuBarPanelStage(status: MenuBarStatus(), sections: [NotesMenuBar.section { store }], actions: [capture],
                          showsWindowAction: AppInfo.isEnabled("window"))
    }
}
#endif

#if MODUL_HOTKEYS
/// The Keyboard Shortcuts pane with the quick note (fake backend, US layout, nothing registered
/// with macOS).
private struct NotesHotkeySample: View {
    private let center: HotkeyCenter = {
        let center = HotkeyCenter(backend: FakeHotkeyBackend(), store: MemoryHotkeyStore())
        center.layout = TableKeyboardLayout.us
        center.register(id: NotesHotkeys.id, title: { NotesText.hotkeyTitle }, subtitle: { NotesText.hotkeySubtitle },
                        default: NotesHotkeys.standard, showInOnboarding: true) {}
        return center
    }()

    var body: some View {
        HotkeysPane(center: center)
            .frame(width: NotesSamples.paneSize.width, height: NotesLook.hotkeyPaneHeight)
    }
}
#endif

#if MODUL_BACKGROUND
/// The Background pane's task list with "Empty trash", last run three hours ago.
private struct NotesJobSample: View {
    private let jobs: BackgroundJobs = {
        let end = NotesSamples.now.addingTimeInterval(-3 * 3600)
        let store = MemoryJobStore([NotesBackground.jobID: JobRecord(lastStart: end.addingTimeInterval(-0.02), lastEnd: end,
                                                                     outcome: NotesBackground.outcome(removed: 2), runs: 9)])
        let jobs = BackgroundJobs(store: store, scheduler: NoJobScheduler(), settings: nil, now: { NotesSamples.now })
        NotesBackground.register(in: jobs) { NotesSamples.store() }
        return jobs
    }()

    var body: some View {
        Specimen(width: NotesSamples.paneSize.width) { JobList(jobs: jobs) }
    }
}
#endif
