// Texts of the MLX module (provider row, model section, download notes).

enum MLXText {
    static var title: String { tr(en: "MLX", de: "MLX") }
    static var detail: String { tr(en: "Your own model on this Mac", de: "Eigenes Modell auf diesem Mac") }
    static var section: String { tr(en: "MLX Models", de: "MLX-Modelle") }

    static var model: String { tr(en: "Model", de: "Modell") }
    static func role(_ role: String) -> String {
        switch role {
        case "fast": tr(en: "Fast", de: "Schnell")
        case "quality": tr(en: "Precise", de: "Genau")
        default: role
        }
    }
    static func roleTitle(_ role: String) -> String {
        switch role {
        case "fast": tr(en: "Fast model", de: "Schnelles Modell")
        case "quality": tr(en: "Precise model", de: "Genaues Modell")
        default: role
        }
    }
    /// "Needs about 1.6 GB of memory while it runs" (`ByteText`, decimal units like Finder).
    static func memory(_ gb: Double) -> String {
        let size = ByteText.size(Int64((gb * 1_000_000_000).rounded()))
        return tr(en: "Needs about \(size) of memory while it runs", de: "Braucht im Betrieb etwa \(size) Arbeitsspeicher")
    }

    // Footnotes under the download rows (VoiceBud's three states, plus "nothing yet").
    static var noteOffline: String {
        tr(en: "No internet connection. The download continues where it stopped when you try again.",
           de: "Keine Verbindung zum Internet. Der Download macht dort weiter, wo er aufgehört hat, wenn du es erneut versuchst.")
    }
    static var noteFailed: String {
        tr(en: "The download stopped. Try again; what has arrived is kept.",
           de: "Der Download ist stehen geblieben. Versuche es erneut, der heruntergeladene Teil bleibt erhalten.")
    }
    static var noteRunning: String {
        tr(en: "You don’t have to wait. The download runs in the background.",
           de: "Du musst nicht warten. Der Download läuft im Hintergrund.")
    }
    static var noteReady: String {
        tr(en: "The model is on your Mac. From now on MLX needs no internet.",
           de: "Das Modell ist auf deinem Mac. Ab jetzt braucht MLX kein Internet mehr.")
    }
    static var noteNothing: String {
        tr(en: "A model is only downloaded when you click “Download”. After that everything runs offline.",
           de: "Ein Modell wird erst heruntergeladen, wenn du auf „Herunterladen“ klickst. Danach läuft alles offline.")
    }
    /// Under the rows while MLX is not set up (the rows then have no Download chip).
    static func noteNotInstalled(developer: Bool) -> String {
        developer
            ? tr(en: "Downloads work once ai-worker/setup.sh has run.", de: "Downloads gehen, sobald ai-worker/setup.sh gelaufen ist.")
            : tr(en: "This version of the app cannot download MLX models.", de: "Diese Version der App kann keine MLX-Modelle herunterladen.")
    }

    static var storage: String { tr(en: "Storage", de: "Speicher") }
    static func storageDetail(_ size: String) -> String {
        tr(en: "\(size) in the app’s data folder", de: "\(size) im Datenordner der App")
    }
    static var deleteModels: String { tr(en: "Delete Models", de: "Modelle löschen") }
    static var deleteConfirm: String { tr(en: "Delete the downloaded models?", de: "Heruntergeladene Modelle löschen?") }
    static var deleteConfirmDetail: String {
        tr(en: "You can download them again anytime.", de: "Du kannst sie jederzeit wieder herunterladen.")
    }
    static var delete: String { tr(en: "Delete", de: "Löschen") }

    // Gallery and render titles
    static var galleryPane: String { tr(en: "Models pane with MLX", de: "Bereich Modelle mit MLX") }
}
