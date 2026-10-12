#if MODUL_BACKGROUND
import Foundation

// "Empty Trash" as a scheduled job (skill `hintergrund-job`): once a day, notes that have been in
// the trash for more than 30 days are deleted for good.

enum NotesBackground {
    static let jobID = "notes.trash"
    static let interval: TimeInterval = 86_400

    static func register() {
        // registering opens the job records: only in the running app, never in renders, tests or
        // --selftest
        Registry.launchHooks.append {
            guard !RenderMode.isHeadless, !RenderMode.isStatic else { return }
            register(in: .shared) { .shared }
        }
    }

    static func register(in jobs: BackgroundJobs, store: @escaping @MainActor () -> NotesStore) {
        jobs.register(id: jobID, title: { NotesText.trashJob }, interval: interval, qos: .utility) {
            await run(store)
        }
    }

    /// The job runs off the main actor; Kit `Database` belongs to the main actor, so the delete hops
    /// there (a handful of rows, it returns at once).
    nonisolated static func run(_ store: @escaping @MainActor () -> NotesStore) async -> JobOutcome {
        await MainActor.run { outcome(removed: store().purgeTrash()) }
    }

    static func outcome(removed: Int) -> JobOutcome {
        removed == 0 ? .nothingToDo : .done(note: NotesText.purged(removed))
    }
}
#endif
