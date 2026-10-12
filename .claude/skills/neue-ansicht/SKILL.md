---
name: neue-ansicht
description: Legt eine Seite im Hauptfenster an (Eintrag in der Seitenleiste über AppPage, Seitengerüst, Bausteine im Stil von Apple Music, Suche, leere und Fehlerzustände, Render-Szene). Nutzen, wenn das Hauptfenster eine neue Ansicht bekommt. Gehört zum Modul window.
---

# Neue Ansicht im Hauptfenster

Gehört zum Modul `window`; `bin/starter remove window` entfernt diesen Skill mit dem Modul.

Ohne Hauptfenster zeigt eine Menüleisten-App ihre Inhalte im Statusmenü (Skill `menueleisten-app`) oder in den Einstellungen (Skill `neue-einstellung`). <!-- modul:menubar -->

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Seite | `App/Sources/Kit/Core/Registry.swift` | `AppPage(id:section:order:title:symbol:content:)`, Gruppen `PageSection.main`, `.library`, `.collections` |
| Hauptfenster | `App/Sources/Modules/Window/` | `MainWindowView` (Seitenleiste aus `Registry.pages`, Suche über `\.windowSearch`), Startseite `HomePage` |
| Bausteine | `App/Sources/Modules/Window/Components/` | `PageScaffold`, `HeroHeader`, `Shelf`, `Tile`, `TileGrid`, `ItemList`, `DetailHeader`, `Artwork`, `EmptyPage` |
| Texte | `<Name>Text.swift` im Feature-Ordner | Titel, Untertitel, Aktionen in beiden Sprachen |

## Schritte

1. In fünf Sekunden klar: Der Titel ist der Name der Ansicht, darunter eine Zeile, die die Frage der Nutzerin beantwortet. Genau eine Hauptaktion.
2. Gerüst: `PageScaffold` mit großem Titel und den Einzügen des Fensters. Inhalte aus den Bausteinen: `HeroHeader` für eine Detailseite mit Bild, `Shelf` für eine waagrechte Reihe mit „Alle anzeigen“, `TileGrid` für Raster, `ItemList` für Listen mit Index, Titel, Nebeninfo und Kontextmenü, `Artwork` für erzeugte Bilder aus Text und SF Symbol (keine Bilddateien).
3. Leer und Fehler: `EmptyPage` (Symbol, Titel, ein Satz, höchstens eine Aktion). Ein fehlender Wert nennt seinen Grund.
4. Suche: die Ansicht liest `@Environment(\.windowSearch)` und filtert mit `ListSearch.matches(_:query:)`; ohne Treffer `EmptyPage` mit dem Text aus `PatternsText`.
5. Registrieren im `register()` des Features: `Registry.pages.append(AppPage(id: "<feature>", section: .main, order: 10, title: { <Name>Text.title }, symbol: "<sf.symbol>", content: { AnyView(<Name>View()) }))`. Die Kennung ist eindeutig; die Startseite `home` hat `order: 0` und wird im Projekt ersetzt, sobald die erste eigene Seite steht.
6. Texte nur aus `<Name>Text`, Maße nur aus Tokens, Bewegung aus `Motion`, Hover und Auswahl mit den Zuständen der Bausteine.
7. Render-Szenen: `<feature>.page` in der Fenstergröße 1180 x 760 mit Beispieldaten, dazu je Zustand eine Szene (`<feature>.empty`, `<feature>.no-results`).

## Prüfen

- `make check`, `make build MODULES=window` und mit allen Modulen.
- `make shots ONLY=<feature>.` und `make shots ONLY=window.`; alle vier Fassungen jeder Szene mit dem Werkzeug Read ansehen. Deutsch ohne Kürzung, gemeinsame linke Kante, hell und dunkel gestaltet.
- Gegenprüfung mit dem Skill `red-team`.
