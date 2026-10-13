import Foundation

/// Every visible text of the example feature "Notes".
enum NotesText {
    // MARK: Pages
    static var overview: String { tr(en: "Overview", de: "Übersicht") }
    static var allNotes: String { tr(en: "All Notes", de: "Alle Notizen") }
    static var trash: String { tr(en: "Trash", de: "Papierkorb") }
    static var searchPrompt: String { tr(en: "Search Notes", de: "Notizen durchsuchen") }
    static var pinnedNote: String { tr(en: "Pinned", de: "Angeheftet") }
    static var lastEdited: String { tr(en: "Last edited", de: "Zuletzt bearbeitet") }
    static var recentlyEdited: String { tr(en: "Recently Edited", de: "Zuletzt bearbeitet") }
    static var pinned: String { tr(en: "Pinned", de: "Angeheftet") }
    static var allCollections: String { tr(en: "All Collections", de: "Alle Sammlungen") }
    static var open: String { tr(en: "Open", de: "Öffnen") }
    static var newNote: String { tr(en: "New Note", de: "Neue Notiz") }
    static var tiles: String { tr(en: "Tiles", de: "Kacheln") }
    static var list: String { tr(en: "List", de: "Liste") }
    static var noCollection: String { tr(en: "No collection", de: "Ohne Sammlung") }
    static var untitled: String { tr(en: "Untitled", de: "Ohne Titel") }

    static func count(_ n: Int) -> String {
        n == 1 ? tr(en: "1 note", de: "1 Notiz") : tr(en: "\(Format.number(n)) notes", de: "\(Format.number(n)) Notizen")
    }

    static func overviewSubtitle(notes: Int, collections: Int) -> String {
        let c = collections == 1
            ? tr(en: "1 collection", de: "1 Sammlung")
            : tr(en: "\(Format.number(collections)) collections", de: "\(Format.number(collections)) Sammlungen")
        return tr(en: "\(count(notes)) in \(c)", de: "\(count(notes)) in \(c)")
    }

    static func results(_ n: Int, _ query: String) -> String {
        n == 1 ? tr(en: "1 result for “\(query)”", de: "1 Treffer für „\(query)“")
            : tr(en: "\(Format.number(n)) results for “\(query)”", de: "\(Format.number(n)) Treffer für „\(query)“")
    }

    static var emptyTitle: String { tr(en: "No notes yet", de: "Noch keine Notizen") }
    static var emptyMessage: String {
        tr(en: "Write a new note, or copy some text and save it from the menu bar.",
           de: "Schreibe eine neue Notiz oder kopiere einen Text und sichere ihn über die Menüleiste.")
    }

    static var collectionEmptyTitle: String { tr(en: "Nothing in here yet", de: "Hier liegt noch nichts") }
    static var collectionEmptyMessage: String {
        tr(en: "New notes on this page go into this collection.", de: "Neue Notizen auf dieser Seite landen in dieser Sammlung.")
    }

    static var collectionMissingTitle: String { tr(en: "Collection not found", de: "Sammlung nicht gefunden") }
    static var collectionMissingMessage: String {
        tr(en: "It was removed when the sample data was reloaded.", de: "Sie wurde beim Neuladen der Beispieldaten entfernt.")
    }

    static var trashSubtitleAuto: String {
        tr(en: "Notes are deleted for good after 30 days in the trash.",
           de: "Notizen werden nach 30 Tagen im Papierkorb endgültig gelöscht.")
    }

    static var trashSubtitleManual: String {
        tr(en: "Notes stay here until you delete them.", de: "Notizen bleiben hier, bis du sie löschst.")
    }

    static var trashEmptyTitle: String { tr(en: "The trash is empty", de: "Der Papierkorb ist leer") }
    static var trashEmptyMessage: String {
        tr(en: "Notes you move to the trash wait here before they are deleted.",
           de: "Notizen, die du in den Papierkorb legst, warten hier, bevor sie gelöscht werden.")
    }

    static var columnTitle: String { tr(en: "Title", de: "Titel") }
    static var columnCollection: String { tr(en: "Collection", de: "Sammlung") }
    static var columnEdited: String { tr(en: "Edited", de: "Bearbeitet") }
    static var columnTrashed: String { tr(en: "Removed", de: "Entfernt") }
    static var trashHint: String {
        tr(en: "Right-click a note to put it back or delete it now.",
           de: "Ein Rechtsklick auf eine Notiz legt sie zurück oder löscht sie sofort.")
    }
    static var restore: String { tr(en: "Put Back", de: "Zurücklegen") }
    static var deleteNow: String { tr(en: "Delete Now", de: "Sofort löschen") }

    // MARK: Note
    static var pin: String { tr(en: "Pin", de: "Anheften") }
    static var unpin: String { tr(en: "Unpin", de: "Loslösen") }
    static var moveToTrash: String { tr(en: "Move to Trash", de: "In den Papierkorb legen") }
    static var titleLabel: String { tr(en: "Title", de: "Titel") }
    static var bodyLabel: String { tr(en: "Text", de: "Text") }
    static var bodyPlaceholder: String { tr(en: "Start writing", de: "Hier schreiben") }
    static var saving: String { tr(en: "Saving", de: "Wird gesichert") }
    static var saved: String { tr(en: "Saved", de: "Gesichert") }

    /// "9:41", "Yesterday", "Monday", "Oct 5": short, for lists and tiles.
    static func edited(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        let locale = Localizer.shared.lang.locale
        if cal.isDate(date, inSameDayAs: now) { return Format.time(date) }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: yesterday) {
            return tr(en: "Yesterday", de: "Gestern")
        }
        if let week = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)), date >= week {
            return date.formatted(.dateTime.weekday(.wide).locale(locale))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    /// "Edited today at 9:41, from the clipboard".
    static func meta(_ note: NoteItem, now: Date) -> String {
        let cal = Calendar.current
        let date = note.updatedAt
        let time = Format.time(date)
        let when: String
        if cal.isDate(date, inSameDayAs: now) {
            when = tr(en: "Edited today at \(time)", de: "Heute um \(time) bearbeitet")
        } else if let yesterday = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: yesterday) {
            when = tr(en: "Edited yesterday at \(time)", de: "Gestern um \(time) bearbeitet")
        } else {
            let day = date.formatted(.dateTime.day().month(.wide).locale(Localizer.shared.lang.locale))
            when = tr(en: "Edited on \(day)", de: "Am \(day) bearbeitet")
        }
        switch note.source {
        case .typed: return when
        case .clipboard: return tr(en: "\(when), from the clipboard", de: "\(when), aus der Zwischenablage")
        case .ai: return tr(en: "\(when), written by the local model", de: "\(when), vom lokalen Modell geschrieben")
        }
    }

    // MARK: Local AI
    static var aiTitle: String { tr(en: "Local AI", de: "Lokale KI") }
    static var aiSubtitle: String { tr(en: "Runs on this Mac, nothing is sent", de: "Läuft auf diesem Mac, nichts wird gesendet") }
    static var openModels: String { tr(en: "Open Models", de: "Modelle öffnen") }
    static var aiNeedsText: String { tr(en: "Write some text first.", de: "Schreibe zuerst etwas Text.") }
    static var summarize: String { tr(en: "Summary", de: "Zusammenfassung") }
    static var summarizeDetail: String { tr(en: "Two or three sentences", de: "Zwei bis drei Sätze") }
    static var summarizeButton: String { tr(en: "Write", de: "Erstellen") }
    static var suggestTitle: String { tr(en: "Title", de: "Titel") }
    static var suggestTitleDetail: String { tr(en: "A short title and tags", de: "Kurzer Titel und Stichwörter") }
    static var suggestButton: String { tr(en: "Suggest", de: "Vorschlagen") }
    static var stop: String { tr(en: "Stop", de: "Stoppen") }
    static var writing: String { tr(en: "Writing", de: "Schreibt") }
    static var addToNote: String { tr(en: "Add to Note", de: "Zur Notiz hinzufügen") }
    static var useTitle: String { tr(en: "Use Title", de: "Übernehmen") }
    static var discard: String { tr(en: "Discard", de: "Verwerfen") }
    static var summarizing: String { tr(en: "Summarizing", de: "Fasst zusammen") }
    static var suggesting: String { tr(en: "Finding a title", de: "Sucht einen Titel") }
    static var summaryReady: String { tr(en: "Summary ready", de: "Zusammenfassung fertig") }
    static var titleReady: String { tr(en: "Title suggested", de: "Titel vorgeschlagen") }

    // MARK: Instructions for the model (prompt text, not UI)
    static var summaryInstructions: String {
        tr(en: "Summarize the note in two or three short sentences. Keep names, dates and numbers. Add nothing that is not in the note. Reply with the summary only.",
           de: "Fasse die Notiz in zwei bis drei kurzen Sätzen zusammen. Behalte Namen, Daten und Zahlen. Füge nichts hinzu, was nicht in der Notiz steht. Antworte nur mit der Zusammenfassung.")
    }

    static var titleInstructions: String {
        tr(en: "Suggest a short title for the note, at most six words, and up to three one-word tags. Use words from the note.",
           de: "Schlage einen kurzen Titel für die Notiz vor, höchstens sechs Wörter, und bis zu drei Stichwörter aus je einem Wort. Nimm Wörter aus der Notiz.")
    }

    // MARK: Capture, island, status menu
    static var captureAction: String { tr(en: "Save Clipboard as Note", de: "Zwischenablage als Notiz sichern") }
    static var islandSaving: String { tr(en: "Saving", de: "Sichert") }
    static var islandSaved: String { tr(en: "Saved to Notes", de: "In Notizen gesichert") }
    static var clipboardEmpty: String { tr(en: "The clipboard has no text", de: "Die Zwischenablage enthält keinen Text") }
    static var copiedNotice: String { tr(en: "Note copied", de: "Notiz kopiert") }
    static var menuTitle: String { tr(en: "Notes", de: "Notizen") }
    static var panelEmpty: String { tr(en: "No notes yet", de: "Noch keine Notizen") }
    static var panelHint: String { tr(en: "Click copies, ⌥-click opens", de: "Klick kopiert, ⌥-Klick öffnet") }
    static var panelRowHelp: String { tr(en: "Click to copy, Option-click to open", de: "Klicken zum Kopieren, mit Wahltaste zum Öffnen") }

    // MARK: Hotkey, background job
    static var hotkeyTitle: String { tr(en: "Quick note from the clipboard", de: "Schnellnotiz aus der Zwischenablage") }
    static var hotkeySubtitle: String { tr(en: "Saves the copied text as a new note", de: "Sichert den kopierten Text als neue Notiz") }
    static var trashJob: String { tr(en: "Empty trash", de: "Papierkorb leeren") }

    static func purged(_ n: Int) -> String {
        n == 1 ? tr(en: "1 note deleted", de: "1 Notiz gelöscht")
            : tr(en: "\(Format.number(n)) notes deleted", de: "\(Format.number(n)) Notizen gelöscht")
    }

    // MARK: Onboarding features
    static var featureQuickTitle: String { tr(en: "Quick note", de: "Schnellnotiz") }

    static func featureQuickDetail(_ keys: String?) -> String {
        guard let keys else {
            return tr(en: "Copy some text and save it as a note from any app.",
                      de: "Kopiere einen Text und sichere ihn aus jeder App als Notiz.")
        }
        return tr(en: "Copy some text and press \(keys) in any app. It becomes a note.",
                  de: "Kopiere einen Text und drücke in jeder App \(keys). Daraus wird eine Notiz.")
    }

    static var featureCollectionsTitle: String { tr(en: "Collections", de: "Sammlungen") }
    static var featureCollectionsDetail: String {
        tr(en: "Work, home, travel: each collection has its own page in the window.",
           de: "Arbeit, Zuhause, Reisen: Jede Sammlung hat eine eigene Seite im Fenster.")
    }

    static var featureAITitle: String { tr(en: "Local AI", de: "Lokale KI") }
    static var featureAIDetail: String {
        tr(en: "Summaries and title suggestions come from a model on this Mac.",
           de: "Zusammenfassungen und Titelvorschläge kommen von einem Modell auf diesem Mac.")
    }

    // MARK: Settings pane
    static var paneTitle: String { tr(en: "Notes", de: "Notizen") }
    static var paneIntro: String {
        tr(en: "The example feature of the starter. Remove it with bin/starter strip-examples.",
           de: "Die Beispielfunktion des Starters. Du entfernst sie mit bin/starter strip-examples.")
    }
    static var notesSection: String { tr(en: "Contents", de: "Inhalt") }
    static var notesCount: String { tr(en: "Notes", de: "Notizen") }
    static var trashCount: String { tr(en: "In the trash", de: "Im Papierkorb") }
    static var trashCountDetail: String { tr(en: "Not counted above", de: "Oben nicht mitgezählt") }
    static var defaultCollection: String { tr(en: "New notes go to", de: "Neue Notizen landen in") }
    static var defaultCollectionDetail: String {
        tr(en: "Also notes saved from the clipboard", de: "Auch Notizen aus der Zwischenablage")
    }
    static var storageSection: String { tr(en: "Storage", de: "Speicherort") }
    static var storageNote: String {
        tr(en: "Notes are stored in one file on this Mac.",
           de: "Die Notizen liegen in einer Datei auf diesem Mac.")
    }
    static var storageFile: String { tr(en: "Database", de: "Datenbank") }
    static var showInFinder: String { tr(en: "Show in Finder", de: "Im Finder zeigen") }
    static var inMemory: String { tr(en: "In memory", de: "Im Arbeitsspeicher") }
    static var inMemoryDetail: String { tr(en: "Changes are lost when the app quits", de: "Änderungen gehen beim Beenden verloren") }
    static var samplesSection: String { tr(en: "Sample Data", de: "Beispieldaten") }
    static var reloadSamples: String { tr(en: "Reload sample data", de: "Beispieldaten neu laden") }
    static var reloadSamplesDetail: String {
        tr(en: "Replaces every note with the samples, in the current language",
           de: "Ersetzt alle Notizen durch die Beispiele in der aktuellen Sprache")
    }
    static var reloadButton: String { tr(en: "Reload", de: "Neu laden") }
    static var reloaded: String { tr(en: "Sample data reloaded", de: "Beispieldaten neu geladen") }
    static var reloadConfirmTitle: String { tr(en: "Replace all notes?", de: "Alle Notizen ersetzen?") }
    static var reloadConfirmText: String {
        tr(en: "Your notes, the trash and the collections are deleted and the samples come back. This cannot be undone.",
           de: "Deine Notizen, der Papierkorb und die Sammlungen werden gelöscht, die Beispiele kommen zurück. Das lässt sich nicht widerrufen.")
    }
    static var reloadConfirmButton: String { tr(en: "Replace", de: "Ersetzen") }
    static var storeProblem: String {
        tr(en: "The notes file could not be opened or written. Changes are kept only until the app quits.",
           de: "Die Notizdatei ließ sich nicht öffnen oder schreiben. Änderungen bleiben nur bis zum Beenden erhalten.")
    }

    // MARK: Gallery
    static var galleryTile: String { tr(en: "Note tile", de: "Notiz als Kachel") }
    static var galleryEditor: String { tr(en: "Note editor", de: "Notiz-Editor") }
    static var galleryAI: String { tr(en: "Local AI for a note", de: "Lokale KI für eine Notiz") }
}

/// Sample notes (the first launch and "Reload sample data"), the demo and the render scenes.
enum NotesSampleText {
    static var work: String { tr(en: "Work", de: "Arbeit") }
    static var home: String { tr(en: "Home", de: "Zuhause") }
    static var travel: String { tr(en: "Travel", de: "Reisen") }
    static var ideas: String { tr(en: "Ideas", de: "Ideen") }

    static var meetingTitle: String { tr(en: "Team meeting on Thursday", de: "Teamrunde am Donnerstag") }
    static var meetingBody: String {
        tr(en: "Topics: summer vacation plan, the new way we answer customer requests, who covers for Jana in August.\nJana takes the minutes. Room 3.12 is free from 10.",
           de: "Themen: Urlaubsplan für den Sommer, der neue Ablauf für Kundenanfragen, wer Jana im August vertritt.\nJana schreibt das Protokoll. Raum 3.12 ist ab 10 Uhr frei.")
    }

    static var dentistTitle: String { tr(en: "Dentist appointment", de: "Termin beim Zahnarzt") }
    static var dentistBody: String {
        tr(en: "Call the practice before Friday and move the appointment on the 14th to the week after.",
           de: "Vor Freitag in der Praxis anrufen und den Termin am 14. auf die Woche danach legen.")
    }

    static var packingTitle: String { tr(en: "Packing list for Lisbon", de: "Packliste Lissabon") }
    static var packingBody: String {
        tr(en: "Passport, charger, a light rain jacket for Sintra.\nComfortable shoes: the streets are steep and the stones are smooth.\nTake tram 28 before nine in the morning, later it is full.",
           de: "Reisepass, Ladekabel, leichte Regenjacke für Sintra.\nBequeme Schuhe: Die Straßen sind steil und das Pflaster ist glatt.\nTram 28 morgens vor neun nehmen, danach ist sie voll.")
    }

    static var billTitle: String { tr(en: "Check the utility bill", de: "Nebenkosten prüfen") }
    static var billBody: String {
        tr(en: "The bill came on Monday. Heating costs more than last year: compare the meter reading from January with the bill.\nObjections are possible for 30 days.",
           de: "Die Abrechnung kam am Montag. Die Heizkosten sind höher als im Vorjahr: Zählerstand vom Januar mit der Abrechnung vergleichen.\nEinspruch ist 30 Tage lang möglich.")
    }

    static var soupTitle: String { tr(en: "Red lentil soup", de: "Rote Linsensuppe") }
    static var soupBody: String {
        tr(en: "250 g red lentils, one onion, two carrots, one liter of stock.\nFry onion and carrots, add the lentils, simmer for 20 minutes.\nSeason with lemon and cumin.",
           de: "250 g rote Linsen, eine Zwiebel, zwei Möhren, ein Liter Brühe.\nZwiebel und Möhren anbraten, Linsen dazu, 20 Minuten köcheln lassen.\nMit Zitrone und Kreuzkümmel abschmecken.")
    }

    static var bikeTitle: String { tr(en: "Bike service", de: "Fahrrad zur Inspektion") }
    static var bikeBody: String {
        tr(en: "The rear brake squeaks and the front light flickers. The bike shop on Hill Street is open until 6 on Tuesdays.",
           de: "Die Bremse hinten quietscht, das Licht vorn flackert. Die Werkstatt in der Bergstraße hat dienstags bis 18 Uhr offen.")
    }

    static var giftsTitle: String { tr(en: "Gift ideas for Mom", de: "Geschenkideen für Mama") }
    static var giftsBody: String {
        tr(en: "A cooking class for two, a photo book of last summer, new garden gloves (size 7).",
           de: "Kochkurs für zwei, ein Fotobuch vom letzten Sommer, neue Gartenhandschuhe (Größe 7).")
    }

    static var booksTitle: String { tr(en: "Book tips from Lukas", de: "Buchtipps von Lukas") }
    static var booksBody: String {
        tr(en: "“Kairos” by Jenny Erpenbeck, “The Overstory” by Richard Powers. Lukas lends me the first one.",
           de: "„Kairos“ von Jenny Erpenbeck, „Die Wurzeln des Lebens“ von Richard Powers. Lukas leiht mir das erste.")
    }

    static var trainTitle: String { tr(en: "Train to Hamburg", de: "Zug nach Hamburg") }
    static var trainBody: String {
        tr(en: "Leaves Frankfurt at 7:54, arrives in Hamburg at 11:38. Seat 64 in coach 23 is booked.",
           de: "Ab Frankfurt 7:54, an Hamburg 11:38. Platz 64 in Wagen 23 ist reserviert.")
    }

    static var requestsTitle: String { tr(en: "Handling requests", de: "Ablauf Kundenanfragen") }
    static var requestsBody: String {
        tr(en: "Requests now arrive in one shared inbox. Whoever takes one marks it. Every request gets an answer within two working days.",
           de: "Anfragen kommen jetzt in ein gemeinsames Postfach. Wer eine übernimmt, markiert sie. Jede Anfrage bekommt innerhalb von zwei Arbeitstagen eine Antwort.")
    }

    /// The text `--demo examples` saves as if it had been copied.
    /// Short enough for one line of the folded card in the setup's welcome art.
    static var welcomeClip: String {
        tr(en: "Pick up the package at the post office by 6 pm.", de: "Paket bis 18 Uhr bei der Post abholen.")
    }
    static var demoClip: String {
        tr(en: "Pick up the package at the post office, open until 6 pm. Bring an ID and the notice card.",
           de: "Paket bei der Post abholen, geöffnet bis 18 Uhr. Ausweis und Benachrichtigungskarte mitnehmen.")
    }

    // render scenes
    static var searchQuery: String { tr(en: "summer", de: "sommer") }
    static var searchNone: String { tr(en: "invoice", de: "Rechnung") }
    static var summaryPartial: String {
        tr(en: "The team meets on Thursday to plan the summer vacation and the new way",
           de: "Das Team plant am Donnerstag den Urlaub im Sommer und den neuen Ablauf")
    }
    static var summaryDone: String {
        tr(en: "The team meets on Thursday to plan the summer vacation and the new way of answering customer requests. It also decides who covers for Jana in August.",
           de: "Das Team plant am Donnerstag den Urlaub im Sommer und den neuen Ablauf für Kundenanfragen. Außerdem klärt es, wer Jana im August vertritt.")
    }
    static var suggestedTitle: String { tr(en: "Thursday team meeting", de: "Teamrunde: Urlaub und Anfragen") }
    static var suggestedTags: [String] { [tr(en: "team", de: "Team"), tr(en: "vacation", de: "Urlaub"), tr(en: "requests", de: "Anfragen")] }
}
