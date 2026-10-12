import Foundation

/// The sample data a new notes database starts with ("Reload Sample Data" adds it again), written
/// in the UI language of that moment. Collections keep fixed ids, so pages and the default
/// collection setting survive a reload.
enum NotesSeed {
    struct Collection {
        let id: Int64
        let name: () -> String
        let symbol: String
        let order: Int
    }

    struct Sample {
        let title: () -> String
        let body: () -> String
        let collection: Int64?
        var pinned = false
        var source: NoteSource = .typed
        /// Seconds since the last edit, and how long before that it was created.
        let age: TimeInterval
        var written: TimeInterval = 600
    }

    static let work: Int64 = 1
    static let home: Int64 = 2
    static let travel: Int64 = 3
    static let ideas: Int64 = 4

    static let collections: [Collection] = [
        Collection(id: work, name: { NotesSampleText.work }, symbol: "briefcase.fill", order: 0),
        Collection(id: home, name: { NotesSampleText.home }, symbol: "sofa.fill", order: 1),
        Collection(id: travel, name: { NotesSampleText.travel }, symbol: "airplane", order: 2),
        Collection(id: ideas, name: { NotesSampleText.ideas }, symbol: "lightbulb.fill", order: 3),
    ]

    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 3600
    private static let day: TimeInterval = 86_400

    static let notes: [Sample] = [
        Sample(title: { NotesSampleText.meetingTitle }, body: { NotesSampleText.meetingBody }, collection: work, pinned: true,
               age: 25 * minute),
        Sample(title: { NotesSampleText.dentistTitle }, body: { NotesSampleText.dentistBody }, collection: nil, age: 2 * hour,
               written: 120),
        Sample(title: { NotesSampleText.packingTitle }, body: { NotesSampleText.packingBody }, collection: travel, pinned: true,
               age: 3 * hour, written: 2 * day),
        Sample(title: { NotesSampleText.billTitle }, body: { NotesSampleText.billBody }, collection: home, age: day + 2 * hour),
        Sample(title: { NotesSampleText.soupTitle }, body: { NotesSampleText.soupBody }, collection: home, source: .clipboard,
               age: 2 * day, written: 0),
        Sample(title: { NotesSampleText.bikeTitle }, body: { NotesSampleText.bikeBody }, collection: home, age: 4 * day),
        Sample(title: { NotesSampleText.giftsTitle }, body: { NotesSampleText.giftsBody }, collection: ideas, pinned: true,
               age: 6 * day, written: 3 * day),
        Sample(title: { NotesSampleText.booksTitle }, body: { NotesSampleText.booksBody }, collection: ideas, source: .clipboard,
               age: 9 * day, written: 0),
        Sample(title: { NotesSampleText.trainTitle }, body: { NotesSampleText.trainBody }, collection: travel, source: .clipboard,
               age: 12 * day, written: 0),
        Sample(title: { NotesSampleText.requestsTitle }, body: { NotesSampleText.requestsBody }, collection: work, source: .ai,
               age: 15 * day, written: 0),
    ]
}
