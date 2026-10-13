#if MODUL_AI
import FoundationModels
import Observation
import SwiftUI

// Local AI for notes (skill `ki-funktion`): "Summarize" streams a short summary, "Suggest Title"
// asks for structured output (title + up to three tags) through `DynamicGenerationSchema`. Both run
// on this Mac through `LocalAI`, can be cancelled, and say plainly when no model is available.
// Instructions are fixed and in the UI language; the note only goes in as the prompt. Nothing is
// logged or stored except what the person takes over into the note.

enum NotesAI {
    /// The note text sent to the model is cut here (the on-device model has a small context).
    static let promptLimit = 6000

    static func register() {
        OnboardingFeatures.items.append(OnboardingFeature(id: "notes.ai", order: 30, symbol: "sparkles", tint: .indigo,
                                                          title: { NotesText.featureAITitle },
                                                          detail: { NotesText.featureAIDetail }))
        // the real model, only when named: --selftest examples.ai
        Registry.selfTests.append(SelfTestCheck(id: "examples.ai.live", onDemand: true) { liveCheck() })
    }

    /// Title and text of the note, the text cut at `promptLimit` characters.
    static func prompt(for note: NoteItem) -> String {
        let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let cut = body.count > promptLimit ? String(body.prefix(promptLimit)) : body
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? cut : title + "\n\n" + cut
    }

    /// A note with nothing to work on.
    static func isEmpty(_ note: NoteItem) -> Bool {
        prompt(for: note).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var summaryInstructions: String { NotesText.summaryInstructions }
    static var titleInstructions: String { NotesText.titleInstructions }

    /// `{ "title": String, "tags": [String] (at most 3) }`.
    static var titleSchema: DynamicGenerationSchema {
        DynamicGenerationSchema(name: "NoteTitle", description: "A title for a personal note", properties: [
            .init(name: "title", description: "Short title, at most six words, no quotes",
                  schema: DynamicGenerationSchema(type: String.self)),
            .init(name: "tags", description: "Up to three one-word tags",
                  schema: DynamicGenerationSchema(arrayOf: DynamicGenerationSchema(type: String.self), maximumElements: 3)),
        ])
    }

    /// Reads the model's answer; throws when the title is missing or empty. Tags are trimmed,
    /// without "#", without duplicates (case ignored), at most three.
    static func decodeTitle(_ content: GeneratedContent) throws -> NoteTitleSuggestion {
        let raw = try content.value(String.self, forProperty: "title")
        let title = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”„«»'.")))
        guard !title.isEmpty else { throw AIError.failed("empty title") }
        let rawTags = (try? content.value([String].self, forProperty: "tags")) ?? []
        var seen = Set<String>()
        var tags: [String] = []
        for tag in rawTags {
            let clean = tag.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "#,.")))
            guard !clean.isEmpty, seen.insert(clean.lowercased()).inserted else { continue }
            tags.append(clean)
            if tags.count == 3 { break }
        }
        return NoteTitleSuggestion(title: title, tags: tags)
    }

    /// `--selftest examples.ai`: the real model summarizes a sample note in the UI language.
    private static func liveCheck() -> String? {
        let ai = LocalAI.shared
        ai.refresh()
        if case .unavailable(let reason) = ai.availability { return "no model: \(reason.rawValue)" }
        let note = NoteItem(id: 0, title: NotesSampleText.meetingTitle, body: NotesSampleText.meetingBody, collectionID: nil,
                        pinned: false, trashedAt: nil, createdAt: Date(), updatedAt: Date(), source: .typed)
        let session = NotesAISession(ai: ai, showsProgress: false)
        session.summarize(note)
        guard AIWait.until(timeout: 60, { !session.isSummarizing }) else { return "summary timed out" }
        switch session.summary {
        case .done(let text):
            Log.info("notes: live summary has \(public: text.count) characters", "notes")
            return nil
        case .failed(let message): return "summary failed: \(message)"
        default: return "summary ended without text"
        }
    }
}

/// The AI work on one note: the summary (streamed, each step the whole text so far) and the title
/// suggestion. Starting one again cancels the run before; a cancelled run goes back to idle.
@Observable final class NotesAISession {
    enum Summary: Equatable {
        case idle
        case running(String)
        case done(String)
        case failed(String)
    }

    enum Suggestion: Equatable {
        case idle
        case running
        case done(NoteTitleSuggestion)
        case failed(String)
    }

    private(set) var summary: Summary
    private(set) var suggestion: Suggestion

    @ObservationIgnored let ai: LocalAI
    /// Shows progress and results in the island (the app; never tests or renders).
    @ObservationIgnored let showsProgress: Bool
    @ObservationIgnored private var summaryTask: Task<Void, Never>?
    @ObservationIgnored private var titleTask: Task<Void, Never>?
    /// Bumped per run: a run that was replaced or cancelled never writes its result.
    @ObservationIgnored private var summaryRun = 0
    @ObservationIgnored private var titleRun = 0

    init(ai: LocalAI = .shared, showsProgress: Bool = true, summary: Summary = .idle, suggestion: Suggestion = .idle) {
        self.ai = ai
        self.showsProgress = showsProgress
        self.summary = summary
        self.suggestion = suggestion
    }

    var availability: AIAvailability { ai.availability }

    var isSummarizing: Bool {
        if case .running = summary { return true }
        return false
    }

    var isSuggesting: Bool { suggestion == .running }

    // MARK: Summary

    func summarize(_ note: NoteItem) {
        cancelSummary()
        summaryRun += 1
        let run = summaryRun
        summary = .running("")
        let stream = ai.stream(prompt: NotesAI.prompt(for: note), instructions: NotesAI.summaryInstructions)
        #if MODUL_ISLAND
        if showsProgress { NotesIsland.working(NotesText.summarizing) { [weak self] in self?.cancelSummary() } }
        #endif
        summaryTask = Task { [weak self] in
            var last = ""
            do {
                for try await part in stream {
                    guard let self, self.summaryRun == run else { return }
                    last = part
                    self.summary = .running(part)
                }
                try Task.checkCancellation()
                guard let self, self.summaryRun == run else { return }
                let text = last.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    self.finishSummary(failed: .failed("empty answer"))
                } else {
                    self.summary = .done(text)
                    #if MODUL_ISLAND
                    if self.showsProgress { NotesIsland.summarized(note, text) }
                    #endif
                }
            } catch {
                guard let self, self.summaryRun == run else { return }
                self.finishSummary(failed: AIError.from(error))
            }
        }
    }

    func cancelSummary() {
        summaryTask?.cancel()
        summaryTask = nil
        guard isSummarizing else { return }
        summaryRun += 1
        summary = .idle
        #if MODUL_ISLAND
        if showsProgress { NotesIsland.stopped() }
        #endif
    }

    /// Back to the start (the person closed the result).
    func clearSummary() {
        cancelSummary()
        summary = .idle
    }

    private func finishSummary(failed error: AIError) {
        if error == .cancelled {
            summary = .idle
        } else {
            summary = .failed(AIText.error(error))
        }
        #if MODUL_ISLAND
        if showsProgress { NotesIsland.failed(error) }
        #endif
    }

    // MARK: Title

    func suggestTitle(_ note: NoteItem) {
        cancelTitle()
        titleRun += 1
        let run = titleRun
        suggestion = .running
        let ai = self.ai
        #if MODUL_ISLAND
        if showsProgress { NotesIsland.working(NotesText.suggesting) { [weak self] in self?.cancelTitle() } }
        #endif
        titleTask = Task { [weak self] in
            do {
                let content = try await ai.structured(prompt: NotesAI.prompt(for: note), schema: NotesAI.titleSchema,
                                                      instructions: NotesAI.titleInstructions)
                try Task.checkCancellation()
                let found = try NotesAI.decodeTitle(content)
                guard let self, self.titleRun == run else { return }
                self.suggestion = .done(found)
                #if MODUL_ISLAND
                if self.showsProgress { NotesIsland.suggested(found) }
                #endif
            } catch {
                guard let self, self.titleRun == run else { return }
                let e = AIError.from(error)
                self.suggestion = e == .cancelled ? .idle : .failed(AIText.error(e))
                #if MODUL_ISLAND
                if self.showsProgress { NotesIsland.failed(e) }
                #endif
            }
        }
    }

    func cancelTitle() {
        titleTask?.cancel()
        titleTask = nil
        guard isSuggesting else { return }
        titleRun += 1
        suggestion = .idle
        #if MODUL_ISLAND
        if showsProgress { NotesIsland.stopped() }
        #endif
    }

    func clearSuggestion() {
        cancelTitle()
        suggestion = .idle
    }
}

/// The sessions per note, so a summary keeps running while the person looks at another page.
@Observable final class NotesAIBoard {
    static let shared = NotesAIBoard()

    @ObservationIgnored private var sessions: [Int64: NotesAISession] = [:]
    @ObservationIgnored let make: () -> NotesAISession

    init(make: @escaping () -> NotesAISession = { NotesAISession() }) {
        self.make = make
    }

    /// The session of a note, made on first use (not observed: making one is no change to show).
    func session(for id: Int64) -> NotesAISession {
        if let session = sessions[id] { return session }
        let session = make()
        sessions[id] = session
        return session
    }

    /// Renders and the demo put prepared sessions in.
    func set(_ session: NotesAISession, for id: Int64) { sessions[id] = session }
}

private nonisolated struct NotesAIBoardKey: EnvironmentKey {
    static let defaultValue: NotesAIBoard? = nil
}

extension EnvironmentValues {
    /// The AI sessions the note page shows (nil: `NotesAIBoard.shared`).
    var notesAIBoard: NotesAIBoard? {
        get { self[NotesAIBoardKey.self] }
        set { self[NotesAIBoardKey.self] = newValue }
    }
}

/// A provider for renders: a fixed availability, and an answer that never arrives (renders show
/// prepared sessions instead).
final class NotesPreviewModel: LocalModelProvider {
    let id = "apple"
    let priority = 0
    let availability: AIAvailability
    var title: String { AIText.apple }
    var shortTitle: String { AIText.appleShort }
    var detail: String { AIText.appleDetail }
    let symbol = "cpu"
    let tint = TintName.indigo

    init(_ availability: AIAvailability) { self.availability = availability }

    func refreshAvailability() {}
    func respond(_ request: AIRequest) async throws -> String { throw AIError.unsupported }
    func stream(_ request: AIRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish(throwing: AIError.unsupported) }
    }

    /// A `LocalAI` with only this provider (settings in memory, never written).
    static func localAI(_ availability: AIAvailability) -> LocalAI {
        let ai = LocalAI()
        ai.settings = Settings.inMemory()
        ai.register(NotesPreviewModel(availability))
        return ai
    }
}
#endif
