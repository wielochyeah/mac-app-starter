// Sample content for the window module's renders and gallery entries (never shown in the app).
// A personal library of collections, concrete enough to judge layout and length in both languages.

enum WindowSampleText {
    // MARK: Sidebar
    static var overview: String { tr(en: "Overview", de: "Übersicht") }
    static var favorites: String { tr(en: "Favorites", de: "Favoriten") }
    static var recent: String { tr(en: "Recently Opened", de: "Zuletzt geöffnet") }
    static var allEntries: String { tr(en: "All Entries", de: "Alle Einträge") }

    // MARK: Collections
    static var hikes: String { tr(en: "Autumn Hikes", de: "Herbstwanderungen") }
    static var recipes: String { tr(en: "Weeknight Recipes", de: "Rezepte für unter der Woche") }
    static var reading: String { tr(en: "Reading Pile", de: "Lesestapel") }
    static var garden: String { tr(en: "Balcony Garden", de: "Balkongarten") }
    static var workshop: String { tr(en: "Workshop Projects", de: "Werkstattprojekte") }
    static var photos: String { tr(en: "Photo Ideas", de: "Fotoideen") }
    static var italian: String { tr(en: "Everyday Italian", de: "Italienisch im Alltag") }
    static var practice: String { tr(en: "Practice Pieces", de: "Übungsstücke") }

    static var outdoor: String { tr(en: "Outdoor", de: "Draußen") }
    static var kitchen: String { tr(en: "Kitchen", de: "Küche") }
    static var books: String { tr(en: "Books", de: "Bücher") }
    static var making: String { tr(en: "Making", de: "Selbermachen") }
    static var learning: String { tr(en: "Learning", de: "Lernen") }

    /// "12 entries"
    static func entries(_ count: Int) -> String {
        count == 1 ? tr(en: "1 entry", de: "1 Eintrag")
            : tr(en: "\(Format.number(count)) entries", de: "\(Format.number(count)) Einträge")
    }

    // MARK: Overview page
    static var featured: String { tr(en: "Featured collection", de: "Ausgewählte Sammlung") }
    static var hikesSummary: String {
        tr(en: "Six routes with maps, notes and what to pack", de: "Sechs Touren mit Karten, Notizen und Packliste")
    }
    static var open: String { tr(en: "Open", de: "Öffnen") }
    static var addFavorite: String { tr(en: "Add to Favorites", de: "Zu Favoriten") }
    static var frequentlyUsed: String { tr(en: "Frequently Used", de: "Häufig genutzt") }
    static var collections: String { tr(en: "Collections", de: "Sammlungen") }

    // MARK: Detail page
    static var collection: String { tr(en: "Collection", de: "Sammlung") }
    /// "6 entries, 87.2 km in total"
    static func hikesMeta(_ count: Int, km: Double) -> String {
        tr(en: "\(entries(count)), \(Format.decimal(km))\u{202F}km in total",
           de: "\(entries(count)), insgesamt \(Format.decimal(km))\u{202F}km")
    }
    static var hikesDescription: String {
        tr(en: "Routes from the last two autumns with start point, length and packing list. Each entry links a map with your notes.",
           de: "Touren aus den letzten zwei Herbsten mit Startpunkt, Länge und Packliste. Jeder Eintrag verbindet eine Karte mit deinen Notizen.")
    }
    static var columnTitle: String { tr(en: "Title", de: "Titel") }
    static var columnRegion: String { tr(en: "Region", de: "Region") }
    static var columnLength: String { tr(en: "Length", de: "Länge") }
    static func km(_ value: Double) -> String { tr(en: "\(Format.decimal(value))\u{202F}km", de: "\(Format.decimal(value))\u{202F}km") }

    static var routeFeldberg: String { tr(en: "Feldberg loop", de: "Feldberg-Runde") }
    static var routeLahn: String { tr(en: "Along the Lahn", de: "Entlang der Lahn") }
    static var routeRheinsteig: String { tr(en: "Rheinsteig, stage 3", de: "Rheinsteig, Etappe 3") }
    static var routeVineyard: String { tr(en: "Vineyard path", de: "Weinbergweg") }
    static var routeRidge: String { tr(en: "Ridge trail", de: "Kammweg") }
    static var routeLake: String { tr(en: "Lake circuit", de: "Seerundweg") }

    // MARK: Search
    /// Matches the three outdoor collections through their kind.
    static var query: String { tr(en: "outdoor", de: "draußen") }
    static var queryNone: String { tr(en: "kayak", de: "Kajak") }
    static var searchPrompt: String { tr(en: "Search collections", de: "Sammlungen durchsuchen") }
    /// "3 results for “outdoor”"
    static func results(_ count: Int, _ query: String) -> String {
        count == 1 ? tr(en: "1 result for “\(query)”", de: "1 Treffer für „\(query)“")
            : tr(en: "\(Format.number(count)) results for “\(query)”", de: "\(Format.number(count)) Treffer für „\(query)“")
    }
}
