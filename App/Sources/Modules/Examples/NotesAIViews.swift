#if MODUL_AI
// the AI column belongs to the note page of the main window
#if MODUL_WINDOW
import SwiftUI

/// "Local AI" beside the editor: Summarize and Suggest Title, each a row with its button, the
/// result under it (streamed text, or title and tags) with what can be done with it. Without a
/// model the rows stay visible but off, and a notice says why and where to fix it.
struct NotesAISection: View {
    let note: NoteItem
    var session: NotesAISession
    var store: NotesStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let reason = session.availability.reason
        let empty = NotesAI.isEmpty(note)
        VStack(alignment: .leading, spacing: Space.s) {
            PageSectionTitle(NotesText.aiTitle, subtitle: NotesText.aiSubtitle)
            if let reason {
                InlineNotice(AIText.reasonHint(reason), title: AIText.reasonTitle(reason), kind: .warning,
                             actionTitle: NotesText.openModels) {
                    AppActions.openSettings(pane: "ai")
                }
            }
            Card {
                summaryRow(t, off: reason != nil || empty)
                Separator()
                titleRow(t, off: reason != nil || empty)
            }
            if empty && reason == nil {
                Footnote(NotesText.aiNeedsText)
            }
        }
    }

    // MARK: Summary

    @ViewBuilder
    private func summaryRow(_ t: Theme, off: Bool) -> some View {
        Row(NotesText.summarize, subtitle: NotesText.summarizeDetail, symbol: "text.append", tint: .indigo) {
            if session.isSummarizing {
                HStack(spacing: Space.xs) {
                    Spinner(size: NotesLook.spinner)
                    Chip(NotesText.stop) { session.cancelSummary() }.fixedSize()
                }
            } else {
                Chip(NotesText.summarizeButton) { session.summarize(note) }
                    .fixedSize()
                    .disabled(off)
                    .opacity(off ? Metrics.disabledOpacity : 1)
            }
        }
        switch session.summary {
        case .idle:
            EmptyView()
        case .running(let partial):
            result(t) {
                Text(partial.isEmpty ? NotesText.writing : partial)
                    .foregroundStyle(partial.isEmpty ? t.fg3 : t.prose)
            }
        case .done(let text):
            result(t) {
                Text(text).foregroundStyle(t.prose).textSelection(.enabled)
                HStack(spacing: Space.xs) {
                    Chip(NotesText.addToNote, symbol: "text.badge.plus") {
                        store.append(note.id, text)
                        session.clearSummary()
                    }
                    .fixedSize()
                    Chip(CommonText.copy, symbol: "doc.on.doc") { SystemPasteboard().write(text) }.fixedSize()
                    Spacer(minLength: 0)
                    clear { session.clearSummary() }
                }
                .padding(.top, Space.xxs)
            }
        case .failed(let message):
            result(t) {
                Text(message).foregroundStyle(t.warnText)
            }
        }
    }

    // MARK: Title

    @ViewBuilder
    private func titleRow(_ t: Theme, off: Bool) -> some View {
        Row(NotesText.suggestTitle, subtitle: NotesText.suggestTitleDetail, symbol: "textformat", tint: .indigo) {
            if session.isSuggesting {
                HStack(spacing: Space.xs) {
                    Spinner(size: NotesLook.spinner)
                    Chip(NotesText.stop) { session.cancelTitle() }.fixedSize()
                }
            } else {
                Chip(NotesText.suggestButton) { session.suggestTitle(note) }
                    .fixedSize()
                    .disabled(off)
                    .opacity(off ? Metrics.disabledOpacity : 1)
            }
        }
        switch session.suggestion {
        case .idle, .running:
            EmptyView()
        case .done(let found):
            result(t) {
                Text(found.title).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
                if !found.tags.isEmpty {
                    HStack(spacing: Space.xxs) {
                        ForEach(found.tags, id: \.self) { Badge($0, tone: .neutral) }
                    }
                }
                HStack(spacing: Space.xs) {
                    Chip(NotesText.useTitle, symbol: "checkmark") {
                        store.rename(note.id, to: found.title)
                        session.clearSuggestion()
                    }
                    .fixedSize()
                    Spacer(minLength: 0)
                    clear { session.clearSuggestion() }
                }
                .padding(.top, Space.xxs)
            }
        case .failed(let message):
            result(t) {
                Text(message).foregroundStyle(t.warnText)
            }
        }
    }

    // MARK: Parts

    /// The block under a row: indented to the row's text, reading size.
    private func result<Content: View>(_ t: Theme, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) { content() }
            .font(TypeScale.body)
            .lineSpacing(TypeScale.noteLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, NotesLook.resultInset)
            .padding(.trailing, Space.rowX)
            .padding(.bottom, Space.s)
    }

    private func clear(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark").symbolFont(NotesLook.clearGlyph, weight: .semibold)
        }
        .buttonStyle(PlainStyle())
        .foregroundStyle(Theme(scheme).fg3)
        .accessibilityLabel(NotesText.discard)
        .help(NotesText.discard)
    }
}
#endif
#endif
