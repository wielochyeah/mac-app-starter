---
name: neue-ansicht
description: Legt eine Seite im Hauptfenster an (Eintrag in der Seitenleiste über AppPage, Seitengerüst, Bausteine im Stil von Apple Music, Suche, leere und Fehlerzustände, Render-Szene). Nutzen, wenn das Hauptfenster eine neue Ansicht bekommt. Gehört zum Modul window.
---

# Neue Ansicht im Hauptfenster

Gehört zum Modul `window`; `bin/starter remove window` entfernt diesen Skill mit dem Modul. Code außerhalb von `App/Sources/Modules/Window/`, der Bausteine des Hauptfensters oder `WindowSearch` nutzt, steht in `#if MODUL_WINDOW` … `#endif`.

Ohne Hauptfenster zeigt eine Menüleisten-App ihre Inhalte im Statusmenü (Skill `menueleisten-app`) oder in den Einstellungen (Skill `neue-einstellung`). <!-- modul:menubar -->

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Seite | `App/Sources/Kit/Core/Registry.swift` | `AppPage(id:section:order:title:symbol:content:)`, Gruppen `PageSection.main`, `.library`, `.collections` |
| Hauptfenster | `App/Sources/Modules/Window/` | `MainWindowView` (Seitenleiste aus `Registry.pages`), Suche in der Werkzeugleiste über `WindowSearch.enable(page:prompt:)` und `\.windowSearch`, Startseite `HomePage` |
| Bausteine | `App/Sources/Modules/Window/Components/` | `PageScaffold`, `HeroHeader`, `Shelf`, `Tile`, `TileGrid`, `ItemList`, `DetailHeader`, `Artwork`, `EmptyPage`, `NoResults` |
| Öffnen von außen | `App/Sources/Kit/Main/AppActions.swift` | `AppActions.openMainWindow(page:)` wählt die Seite und holt das Fenster nach vorn; ohne Modul `window` öffnen sich die Einstellungen |
| Renders | `App/Sources/Modules/Window/StaticMainWindow.swift` | `StaticMainWindow(pages:selection:query:searchPrompt:detail:)`: das ganze Fenster mit Seitenleiste und Werkzeugleiste, ohne AppKit |
| Texte | `<Name>Text.swift` im Feature-Ordner | Titel, Untertitel, Aktionen in beiden Sprachen |

## Schritte

1. In fünf Sekunden klar: Der Titel ist der Name der Ansicht, darunter eine Zeile, die die Frage der Nutzerin beantwortet. Genau eine Hauptaktion.
2. Gerüst: `PageScaffold` mit großem Titel und den Einzügen des Fensters. Inhalte aus den Bausteinen: `HeroHeader` für eine Detailseite mit Bild, `Shelf` für eine waagrechte Reihe mit „Alle anzeigen“, `TileGrid` für Raster, `ItemList` für Listen mit Index, Titel, Nebeninfo und Kontextmenü, `Artwork` für erzeugte Bilder aus Text und SF Symbol (keine Bilddateien).
3. Leer und Fehler: `EmptyPage` (Symbol, Titel, ein Satz, höchstens eine Aktion). Ein fehlender Wert nennt seinen Grund.
4. Suche: Das Suchfeld in der Werkzeugleiste erscheint nur auf Seiten, die es im `register()` einschalten: `WindowSearch.enable(page: "<feature>") { <Name>Text.searchPrompt }` (`page` ist die Kennung der `AppPage`; ohne `prompt` steht dort `CommonText.search`). ⌘F springt dann ins Feld. Die Seite liest den Suchtext mit `@Environment(\.windowSearch) private var query` (leer ohne Eingabe, beim Seitenwechsel geleert) und filtert mit `ListSearch.matches(_:query:)`. Ohne Treffer bleiben Titel und Ergebniszeile stehen, `NoResults(query: query)` ersetzt den Inhalt im `PageScaffold` (Texte aus `WindowText`); eine ganz leere Seite nutzt `EmptyPage.noResults(query)`. Vorbild: `SampleLibraryPage` in `Samples/WindowSamples.swift`. Render-Szenen setzen den Suchtext über `StaticMainWindow(…, query: "…")` (Schritt 9).
5. Registrieren im `register()` des Features: `Registry.pages.append(AppPage(id: "<feature>", section: .main, order: 10, title: { <Name>Text.title }, symbol: "<sf.symbol>", content: { AnyView(<Name>View()) }))`. Die Kennung ist eindeutig. Die Startseite `home` hat `order: 0`; eine eigene Seite mit `section: .main` und `order: 0` (oder kleiner) ersetzt sie (`MainWindowModel.visible`), mit `order: 10` steht sie darunter.
6. Texte nur aus `<Name>Text`, Maße nur aus Tokens, Bewegung aus `Motion`, Hover und Auswahl mit den Zuständen der Bausteine.
7. Breite: Zwei Spalten, die im schmalen Fenster untereinander rutschen, wählt `ViewThatFits(in: .horizontal)` (erst `HStack`, dann `VStack`). Ein Teil mit `maxWidth: .infinity` und langem Text meldet seine ganze Textbreite als ideale Breite; ohne `.frame(minWidth: x, idealWidth: x, maxWidth: .infinity)` passt die breite Fassung nie, und die Spalten stehen immer untereinander.
8. Detailseite über einer Liste: Das Fenstermodul kennt keine Unterseiten. Ein `@Observable` Navigator des Features merkt sich, welches Element auf welcher Seite offen ist; die Seite zeigt dann statt der Liste die Detailansicht (`DetailHeader`, darüber ein Zurück-Link mit dem Titel der Seite, `Esc` schließt) und vergisst das Element in `.onDisappear`, wenn die Nutzerin über die Seitenleiste wechselt. Von außen (Statusmenü, Insel, Kurzbefehl) setzt der Code zuerst das Element und ruft dann `AppActions.openMainWindow(page: "<feature>")`. Vorbild: `NotesNavigator` und `NotesPageHost` in `App/Sources/Modules/Examples/NotesWindow.swift`. <!-- modul:examples -->
9. Render-Szenen: `<feature>.page` im ganzen Fenster (1180 x 760) mit Beispieldaten, dazu je Zustand eine Szene (`<feature>.empty`, `<feature>.no-results`). Gerendert wird die Seite in `StaticMainWindow`, das Seitenleiste und Werkzeugleiste ohne AppKit zeichnet:

   ```swift
   Registry.renderScenes.append(RenderScene(id: "tasks.page", size: .zero) {
       AnyView(RenderBoard {
           StaticMainWindow(pages: TasksFeature.pages, selection: "tasks", query: nil, searchPrompt: TasksText.searchPrompt) {
               TasksPage(store: TasksSamples.store())
           }
       })
   })
   ```

   `pages` ist die Seitenleiste der Szene, `selection` die markierte Seite, `query` kommt bei der Seite als `\.windowSearch` an und steht im Suchfeld, das nur mit `searchPrompt` erscheint. Die Seite bekommt ihre Beispieldaten hineingereicht, nie den geteilten Speicher.

## Prüfen

- `make check`, `make build MODULES=window` und mit allen Modulen.
- `make shots ONLY=<feature>.` und `make shots ONLY=window.`; alle vier Fassungen jeder Szene mit dem Werkzeug Read ansehen. Deutsch ohne Kürzung, gemeinsame linke Kante, hell und dunkel gestaltet.
- Gegenprüfung mit dem Skill `red-team`.
