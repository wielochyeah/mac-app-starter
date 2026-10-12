// Texts of the local AI module (settings pane "Models", onboarding step "Local AI", errors).

enum AIText {
    // MARK: Pane and step
    static var pane: String { tr(en: "Models", de: "Modelle") }
    static var paneIntro: String {
        tr(en: "A language model on your Mac reads and writes text. What you type stays on this device.",
           de: "Ein Sprachmodell auf deinem Mac liest und schreibt Text. Was du eingibst, bleibt auf diesem Gerät.")
    }
    static var stepTitle: String { tr(en: "Local AI", de: "Lokale KI") }
    static var stepSubtitle: String {
        tr(en: "Text is processed by a model on your Mac.\nWhat you type never goes to the internet.",
           de: "Text verarbeitet ein Modell auf deinem Mac.\nWas du eingibst, geht nie ins Internet.")
    }
    static var stepReady: String {
        tr(en: "Everything is in place. You can change the model later in Settings.",
           de: "Alles bereit. Das Modell kannst du später in den Einstellungen wechseln.")
    }
    static var stepLater: String {
        tr(en: "You can continue now and switch it on later.", de: "Du kannst jetzt weitergehen und das später einschalten.")
    }

    // MARK: Providers
    static var providerSection: String { tr(en: "Provider", de: "Anbieter") }
    static var providerChoice: String { tr(en: "Use", de: "Verwenden") }
    static var providerChoiceDetail: String {
        tr(en: "Automatic picks Apple Intelligence and falls back to MLX.",
           de: "Automatisch nimmt Apple Intelligence, sonst MLX.")
    }
    static var automatic: String { tr(en: "Automatic", de: "Automatisch") }
    static var apple: String { tr(en: "Apple Intelligence", de: "Apple Intelligence") }
    static var appleShort: String { tr(en: "Apple", de: "Apple") }
    static var appleDetail: String { tr(en: "Built into macOS, no download", de: "In macOS enthalten, ohne Download") }
    static var inUse: String { tr(en: "In use", de: "Aktiv") }

    // MARK: Availability
    static func status(_ availability: AIAvailability) -> String {
        switch availability {
        case .available: PatternsText.ready
        case .unavailable(let reason): statusWord(reason)
        }
    }

    static func statusWord(_ reason: AIUnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceOff: tr(en: "Switched off", de: "Ausgeschaltet")
        case .modelNotReady: tr(en: "Getting ready", de: "Wird vorbereitet")
        case .deviceNotEligible, .unsupportedHardware: tr(en: "Not supported", de: "Nicht unterstützt")
        case .systemTooOld: tr(en: "Needs update", de: "Update nötig")
        case .notInstalled: tr(en: "Not set up", de: "Nicht eingerichtet")
        case .modelMissing: tr(en: "No model", de: "Kein Modell")
        case .unknown: tr(en: "Unavailable", de: "Nicht verfügbar")
        }
    }

    static func reasonTitle(_ reason: AIUnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceOff: tr(en: "Apple Intelligence is off", de: "Apple Intelligence ist aus")
        case .modelNotReady: tr(en: "The model is still loading", de: "Das Modell lädt noch")
        case .deviceNotEligible: tr(en: "This Mac has no Apple Intelligence", de: "Dieser Mac hat kein Apple Intelligence")
        case .unsupportedHardware: tr(en: "Needs a Mac with Apple silicon", de: "Braucht einen Mac mit Apple-Chip")
        case .systemTooOld: tr(en: "macOS is too old for MLX", de: "macOS ist zu alt für MLX")
        case .notInstalled: tr(en: "MLX is not set up", de: "MLX ist nicht eingerichtet")
        case .modelMissing: tr(en: "No model downloaded yet", de: "Noch kein Modell geladen")
        case .unknown: tr(en: "No model available", de: "Kein Modell verfügbar")
        }
    }

    /// What to do about it, one or two sentences.
    static func reasonHint(_ reason: AIUnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceOff:
            tr(en: "Turn on Apple Intelligence in System Settings. macOS then loads the model in the background.",
               de: "Schalte Apple Intelligence in den Systemeinstellungen ein. macOS lädt das Modell danach im Hintergrund.")
        case .modelNotReady:
            tr(en: "macOS is downloading the model in the background. This can take a few minutes.",
               de: "macOS lädt das Modell im Hintergrund. Das kann einige Minuten dauern.")
        case .deviceNotEligible:
            tr(en: "Text features need another model here, for example MLX.",
               de: "Für Textfunktionen braucht es hier ein anderes Modell, zum Beispiel MLX.")
        case .unsupportedHardware:
            tr(en: "MLX runs only on Macs with an M chip.", de: "MLX läuft nur auf Macs mit M-Chip.")
        case .systemTooOld:
            tr(en: "MLX needs macOS 26.2 or later. Update macOS in System Settings.",
               de: "MLX braucht macOS 26.2 oder neuer. Aktualisiere macOS in den Systemeinstellungen.")
        case .notInstalled:
            tr(en: "Run ai-worker/setup.sh once in the project folder. It creates the Python environment for MLX.",
               de: "Führe einmal ai-worker/setup.sh im Projektordner aus. Es richtet die Python-Umgebung für MLX ein.")
        case .modelMissing:
            tr(en: "Download a model below. After that it works offline.",
               de: "Lade unten ein Modell. Danach geht alles offline.")
        case .unknown:
            tr(en: "Check the provider below.", de: "Sieh dir den Anbieter unten an.")
        }
    }

    static var openAISettings: String { tr(en: "Open System Settings", de: "Systemeinstellungen öffnen") }

    /// The step's footnote when no model can answer: the hint, with a link when System Settings fixes it.
    static func onboardingHint(_ reason: AIUnavailableReason, link: Bool) -> String {
        let hint = reasonHint(reason)
        return link ? hint + " [" + openAISettings + "](app://fix)" : hint + " " + stepLater
    }
    static var softwareUpdate: String { tr(en: "Open Software Update", de: "Softwareupdate öffnen") }

    // MARK: Try it
    static var trySection: String { tr(en: "Try it", de: "Ausprobieren") }
    static var tryPlaceholder: String { tr(en: "Ask something", de: "Frag etwas") }
    static var trySample: String {
        tr(en: "Explain in one sentence what a menu bar app is.",
           de: "Erkläre in einem Satz, was eine Menüleisten-App ist.")
    }
    static var send: String { tr(en: "Send", de: "Senden") }
    static var stop: String { tr(en: "Stop", de: "Stopp") }
    static var thinking: String { tr(en: "Writing", de: "Schreibt") }
    static var tryNote: String {
        tr(en: "The answer comes from the model in use. Nothing is saved.",
           de: "Die Antwort kommt vom aktiven Modell. Gespeichert wird nichts.")
    }
    static func answered(in seconds: Double, by provider: String) -> String {
        tr(en: "\(provider), \(Format.seconds(seconds))", de: "\(provider), \(Format.seconds(seconds))")
    }

    // MARK: Usage
    static var usageSection: String { tr(en: "Usage", de: "Nutzung") }
    static var requests: String { tr(en: "Requests", de: "Anfragen") }
    static var failures: String { tr(en: "Failed", de: "Fehlgeschlagen") }
    static var lastAnswer: String { tr(en: "Last answer", de: "Letzte Antwort") }
    static var noAnswerYet: String { tr(en: "None yet", de: "Noch keine") }
    static var usageNote: String {
        tr(en: "Only counts and times are kept, never your text.",
           de: "Gezählt werden nur Anzahl und Dauer, nie dein Text.")
    }

    // MARK: Models (rows; MLX fills them)
    static var modelsSection: String { tr(en: "Models on this Mac", de: "Modelle auf diesem Mac") }
    static var download: String { tr(en: "Download", de: "Herunterladen") }
    static var queued: String { tr(en: "Queued", de: "In Warteschlange") }

    // MARK: Errors (short, for the try-it field and the island)
    static func error(_ error: AIError) -> String {
        switch error {
        case .unavailable(let reason): reasonTitle(reason)
        case .cancelled: tr(en: "Stopped", de: "Abgebrochen")
        case .timeout: tr(en: "The model took too long and was stopped.", de: "Das Modell hat zu lange gebraucht und wurde gestoppt.")
        case .contextTooLong: tr(en: "The text is too long for this model.", de: "Der Text ist zu lang für dieses Modell.")
        case .guardrail:
            tr(en: "The model declined to answer this.", de: "Darauf antwortet das Modell nicht.")
        case .unsupportedLanguage:
            tr(en: "The model does not support this language.", de: "Das Modell kann diese Sprache nicht.")
        case .busy: tr(en: "The model is busy. Try again in a moment.", de: "Das Modell ist beschäftigt. Versuch es gleich noch mal.")
        case .unsupported: tr(en: "This model cannot do that.", de: "Das kann dieses Modell nicht.")
        case .restarting(let seconds):
            tr(en: "The model stopped unexpectedly. Next try in \(Format.number(Int(seconds.rounded(.up)))) s.",
               de: "Das Modell ist unerwartet beendet. Nächster Versuch in \(Format.number(Int(seconds.rounded(.up)))) s.")
        case .workerCrashed: tr(en: "The model stopped unexpectedly.", de: "Das Modell ist unerwartet beendet.")
        case .failed: tr(en: "The model could not answer.", de: "Das Modell konnte nicht antworten.")
        }
    }

    // MARK: Instructions for the model (prompt text, not UI)
    /// Appended to every request's instructions so the answer comes in the UI language.
    static var replyLanguage: String { tr(en: "Answer in English.", de: "Antworte auf Deutsch.") }

    // MARK: Gallery and render titles
    static var galleryPane: String { tr(en: "Models pane", de: "Bereich Modelle") }
    static var galleryStep: String { tr(en: "Local AI step", de: "Schritt Lokale KI") }
    static var galleryRows: String { tr(en: "Model downloads", de: "Modell-Downloads") }

    // MARK: Sample content for renders and the gallery (fixed, so renders are deterministic)
    static var sampleFastRole: String { tr(en: "Fast model", de: "Schnelles Modell") }
    static var sampleQualityRole: String { tr(en: "Precise model", de: "Genaues Modell") }
    static var sampleAnswer: String {
        tr(en: "A menu bar app lives as a small icon at the top of the screen and opens a compact panel when you click it.",
           de: "Eine Menüleisten-App sitzt als kleines Symbol oben am Bildschirm und öffnet beim Klick ein kompaktes Feld.")
    }
}
