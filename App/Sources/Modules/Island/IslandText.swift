import Foundation

// Texts of the island module. German with "du"; no middle dots, no all-caps (VoiceBud SPEC §0).

enum IslandText {
    /// Between a title and its dim detail: an en space and a thin space, never a middle dot.
    static let metaGap = "\u{2002}\u{2009}"

    /// "7 s": seconds counter of a slow progress (narrow no-break space like `Format.seconds`).
    static func counter(_ seconds: Int) -> String {
        tr(en: "\(seconds)\u{202F}s", de: "\(seconds)\u{202F}s")
    }

    /// "42%" / "42 %"
    static func percent(_ fraction: Double) -> String {
        let n = Int((min(max(fraction, 0), 1) * 100).rounded())
        return tr(en: "\(n)%", de: "\(n)\u{202F}%")
    }

    static var takesLonger: String { tr(en: "Taking longer", de: "Dauert länger") }
    static var stillWorking: String { tr(en: "Still working", de: "Läuft noch") }
    static var copyText: String { tr(en: "Copy text", de: "Text kopieren") }

    // MARK: Settings pane

    static var pane: String { tr(en: "Island & Capsule", de: "Insel und Kapsel") }
    static var paneIntro: String {
        tr(en: "While the app works, it shows progress and results at the top of the screen.",
           de: "Während die App arbeitet, zeigt sie Fortschritt und Ergebnis oben am Bildschirm.")
    }

    static func style(_ style: IslandStyle) -> String {
        switch style {
        case .auto: tr(en: "Automatic", de: "Automatisch")
        case .island: CommonText.islandAtNotch
        case .capsule: CommonText.capsule
        }
    }

    /// The footnote under the style tiles. `dodges`: the app reports when another app uses the
    /// notch (`Island.shared.notchBusy`); only then do Automatic and Island differ.
    static func styleNote(_ style: IslandStyle, dodges: Bool) -> String {
        switch style.shown(dodges: dodges) {
        case .auto where dodges:
            tr(en: "Grows out of the notch on a Mac that has one and moves below it while another app uses the notch. Screens without a notch get the capsule below the menu bar.",
               de: "Wächst auf einem Mac mit Notch seitlich aus ihr heraus und rückt darunter, solange eine andere App sie nutzt. Bildschirme ohne Notch bekommen die Kapsel unter der Menüleiste.")
        case .auto:
            tr(en: "Grows out of the notch on a Mac that has one. Screens without a notch get the capsule below the menu bar.",
               de: "Wächst auf einem Mac mit Notch seitlich aus ihr heraus. Bildschirme ohne Notch bekommen die Kapsel unter der Menüleiste.")
        case .island:
            tr(en: "Always grows out of the notch, even while another app uses it. Screens without a notch still get the capsule.",
               de: "Wächst immer aus der Notch, auch solange eine andere App sie nutzt. Bildschirme ohne Notch bekommen trotzdem die Kapsel.")
        case .capsule:
            tr(en: "Floats as a capsule below the menu bar, on every screen.",
               de: "Schwebt auf jedem Bildschirm als Kapsel unter der Menüleiste.")
        }
    }

    static var confirmation: String { tr(en: "Show confirmation", de: "Bestätigung anzeigen") }
    static var confirmationDetail: String { tr(en: "How long a finished card stays", de: "So lange bleibt eine fertige Karte stehen") }
    static var stays: String { tr(en: "Stays", de: "Bleibt") }

    static func confirmChoice(_ seconds: Double) -> String {
        seconds >= IslandTiming.stays ? stays : Format.seconds(seconds)
    }

    static var hoverExpand: String { tr(en: "Expand on hover", de: "Karte unter dem Zeiger aufklappen") }
    static var hoverExpandDetail: String {
        tr(en: "The card then shows the whole text with “Copy” and stays open while the pointer is on it. Off: the card stays small and shows only its buttons.",
           de: "Die Karte zeigt dann den ganzen Text mit „Kopieren“ und bleibt offen, solange der Zeiger darauf ist. Aus: Die Karte bleibt klein und zeigt nur ihre Tasten.")
    }

    static var feedback: String { tr(en: "Feedback", de: "Rückmeldung") }
    static var sounds: String { tr(en: "Sounds", de: "Töne") }
    static var soundsDetail: String { tr(en: "A quiet sound when something starts and when it is done", de: "Ein leiser Ton beim Start und wenn etwas fertig ist") }
    static var haptics: String { tr(en: "Trackpad feedback", de: "Trackpad-Rückmeldung") }
    static var hapticsDetail: String {
        tr(en: "A light tick on the trackpad when the pointer reaches a card or a button (Force Touch trackpads)",
           de: "Ein spürbarer Tipp im Trackpad, wenn der Zeiger eine Karte oder eine Taste erreicht (Force-Touch-Trackpads)")
    }
    static var hideInFullscreen: String { tr(en: "Hide in full screen", de: "Im Vollbild ausblenden") }
    static var hideInFullscreenDetail: String {
        tr(en: "Stays hidden while an app fills the whole screen", de: "Bleibt verborgen, solange eine App den ganzen Bildschirm füllt")
    }

    static var preview: String { tr(en: "Preview", de: "Vorschau") }
    static var previewDetail: String {
        tr(en: "Plays a short sequence at the top of this screen", de: "Spielt eine kurze Folge oben auf diesem Bildschirm ab")
    }
    static var showPreview: String { tr(en: "Show Preview", de: "Vorschau zeigen") }
    static var stopPreview: String { tr(en: "Stop Preview", de: "Vorschau stoppen") }

    // MARK: Onboarding

    static var onboardingTitle: String { pane }
    static var onboardingSubtitle: String {
        tr(en: "How \(AppInfo.displayName) shows what it is doing.", de: "So zeigt \(AppInfo.displayName), was gerade passiert.")
    }
    static var onboardingNote: String {
        // the pane's name never breaks across lines
        let place = pane.replacingOccurrences(of: " ", with: "\u{00A0}")
        return tr(en: "Screens without a notch always show the capsule. You can change this later in Settings > \(place).",
                  de: "Bildschirme ohne Notch zeigen immer die Kapsel. Du kannst das später unter Einstellungen > \(place) ändern.")
    }

    // MARK: Welcome art

    static var welcomeTitle: String { CommonText.done }
    static var welcomeBody: String {
        tr(en: "Here \(AppInfo.displayName) reports what it has done.", de: "Hier meldet \(AppInfo.displayName), was erledigt ist.")
    }
    static var welcomeArtLabel: String {
        tr(en: "The island grows out of the notch and shows what the app did",
           de: "Die Insel wächst aus der Notch und zeigt, was die App getan hat")
    }

    // MARK: Gallery

    static var galleryStates: String { tr(en: "Island and capsule states", de: "Zustände von Insel und Kapsel") }
    static var galleryStage: String { tr(en: "Island preview stage", de: "Vorschaubühne der Insel") }
    static var galleryGlyphs: String { tr(en: "Island glyphs", de: "Zeichen der Insel") }
}

/// Sample contents for renders, previews and `--demo` (fixed, so renders are deterministic).
enum IslandSampleText {
    static var focus: String { tr(en: "Focus", de: "Fokus") }
    static var preparing: String { tr(en: "Preparing", de: "Wird vorbereitet") }
    static var exporting: String { tr(en: "Exporting", de: "Export läuft") }
    static var saved: String { tr(en: "Saved to Reports", de: "In Berichte gesichert") }
    static var savedDetail: String { tr(en: "3 files", de: "3 Dateien") }
    static var savedBody: String {
        tr(en: "Quarterly report.pdf, the slides and the chart sheet are in Documents/Reports. The originals stay in the project folder.",
           de: "Quartalsbericht.pdf, die Folien und das Diagrammblatt liegen in Dokumente/Berichte. Die Originale bleiben im Projektordner.")
    }
    static var savedLong: String {
        tr(en: """
            Quarterly report.pdf, the slides and the chart sheet are in Documents/Reports. The originals stay in the project folder.

            The report has 14 pages. Charts 3 and 5 use the new colors, and the table on page 9 fits the page again.

            Two notes are still open: the source for the market figures on page 4, and whether the appendix should list every interview. Both are marked yellow in the slides.

            The export ran at full quality. The PDF is 4.2\u{202F}MB, the slides 18\u{202F}MB.

            Next week the numbers for the third quarter come in, with a second chart sheet.
            """,
           de: """
            Quartalsbericht.pdf, die Folien und das Diagrammblatt liegen in Dokumente/Berichte. Die Originale bleiben im Projektordner.

            Der Bericht hat 14 Seiten. Die Diagramme 3 und 5 nutzen die neuen Farben, und die Tabelle auf Seite 9 passt wieder auf die Seite.

            Zwei Punkte sind noch offen: die Quelle für die Marktzahlen auf Seite 4 und ob der Anhang jedes Interview aufführen soll. Beide sind in den Folien gelb markiert.

            Der Export lief in voller Qualität. Das PDF hat 4,2\u{202F}MB, die Folien 18\u{202F}MB.

            Nächste Woche kommen die Zahlen für das dritte Quartal, mit einem zweiten Diagrammblatt.
            """)
    }
    static var showInFinder: String { tr(en: "Show in Finder", de: "Im Finder zeigen") }
    // notices are one short line: at most three words (DESIGN §6)
    static var noticeInfo: String { tr(en: "Sync at 9:00", de: "Abgleich um 9:00") }
    static var noticeSuccess: String { tr(en: "Link copied", de: "Link kopiert") }
    static var noticeWarning: String { tr(en: "Only 2\u{202F}GB free", de: "Nur 2\u{202F}GB frei") }
    static var noticeError: String { tr(en: "File not saved", de: "Datei nicht gesichert") }
}
