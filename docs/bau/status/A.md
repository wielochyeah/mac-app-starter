# Status A (Modul window, Hauptfenster im Stil von Musik)

Stand: 2026-10-12, Branch `strang/A`. Alles aus STRANDS.md Abschnitt A ist gebaut, getestet und gerendert; die Befunde der Prüfung sind eingearbeitet (Abschnitt „Prüfung durch die Reviewer“ unten).

## Was gebaut ist

| Bereich | Dateien (`App/Sources/Modules/Window/`) |
|---|---|
| Registrierung | `WindowModule.swift`: Startseite (tritt zurück, sobald eine andere Seite den ersten Platz belegt), `AppActions.mainWindowHandler`, Menü-Dekorator, Fußzeile „Alles lokal und offline“, Katalog, Start-Hook „nach der Einrichtung Hauptfenster öffnen“ |
| Fenster | `MainWindowController.swift` (auf `WindowHost`: vereinheitlichte Symbolleiste, volle Inhaltsfläche, Titel verborgen, Mindestgröße genau 900 x 600, Standard 1180 x 760, Vollbild, Rahmen-Autosave mit Freigabe beim Schließen aus `WindowHost`) |
| Inhalt | `MainWindowView.swift` (`NavigationSplitView`, native Seitenleiste aus `Registry.pages` nach `PageSection` gruppiert, erste Gruppe ohne Titel wie in Musik, Akzent-Symbole, Fußzeile, Suche in der Symbolleiste nur für Seiten, die sie einschalten), `MainWindowModel.swift` (Auswahl und Seitenleiste in Settings, `WindowSearch`, `WindowSidebarFooter`, `SidebarGroup`) |
| Menüs | `WindowMainMenu.swift` (+ `WindowMenuTarget` mit Menü-Validierung): Ablage (Schließen ⌘W, aus dem Fenster-Menü verschoben), Bearbeiten + Suchen ⌘F (nur aktiv, wenn die gezeigte Seite die Suche nutzt), Darstellung (Seitenleiste ein-/ausblenden ⌃⌘S, nur für das Hauptfenster als Schlüsselfenster, Titel folgt dem Zustand; Vollbild ⌃⌘F), Fenster + Hauptfenster ⌘0, Hilfe (Einrichtung erneut zeigen); alle Titel aus `WindowText`, folgen der Sprache |
| Bausteine | `Components/`: `PageScaffold` (+ `PageScroll`, `PageSectionTitle`, Umgebung `\.windowSearch`, `\.windowPageInset`), `HeroHeader` (+ `HeroBackdrop`, `HeaderAction`, `HeaderActions`, `OnArtworkButtonStyle`), `Shelf`, `Tile` (+ `ArtworkAction`, `ArtworkButton`), `TileGrid`, `ItemList` (+ `ItemListItem`, `ItemListColumns`), `DetailHeader`, `Artwork` (+ `ArtworkGlyph`, `ArtworkRecipe`, `ArtworkRGB`, Umgebung `\.artworkAccent`), `EmptyPage` (+ `EmptyPage.noPages`, `NoResults`), `WindowTokens.swift` |
| Startseite | `Pages/HomePage.swift`: App-Symbol, Name, Version, ein Satz, drei nächste Schritte mit Pfaden und Skill `neue-ansicht`, Regal der Bausteine, Hinweis zum Entfernen; `AppIconImage`, `BuildingBlock` |
| Renders | `StaticMainWindow.swift` (Fenster, schwebende Seitenleiste von macOS 26, Symbolleistenband mit Suchkapsel), `WindowCatalog.swift` (Galerie, Szenen, Selbsttests), `Samples/WindowSamples.swift`, `Samples/WindowSampleText.swift` |
| Texte | `WindowText.swift` (+ `WindowCodeNames` für Pfade und Bezeichner, sprachunabhängig) |
| Tests | `App/Tests/WindowTests.swift` (30 Tests), `App/Tests/BackgroundLaunchTests.swift` (3 Tests für die Kit-Ergänzungen) |

Szenen (je en/de × hell/dunkel, 64 PNGs): `window.main`, `window.home`, `window.detail`, `window.search`, `window.search-empty`, `window.no-pages`, `window.sidebar`, `window.page-scaffold`, `window.hero-header`, `window.shelf`, `window.tile` (normal, Hover, ausgewählt), `window.tile-grid`, `window.item-list` (Kopf, Streifen, Hover, Auswahl, Bild-Variante), `window.detail-header`, `window.artwork`, `window.empty-page`. Jede Szene ist auch ein Galerie-Eintrag (Bereich `window`).

Selbsttests (`--selftest`): `window.registration`, `window.symbols` (alle SF Symbols existieren), `window.chrome` (baut das echte Fenster unsichtbar mit einer Wegwerf-Settings-Datei: Symbolleiste mit Suchfeld, vereinheitlicht, Titel verborgen, Mindestgröße, Größe nach dem Layout, schreibt keine Einstellungen), `window.render`.

## API für Seiten (Module, Features, Projekte)

```swift
Registry.pages.append(AppPage(id: "library", section: .library, order: 0, title: { T.library }, symbol: "square.grid.2x2.fill") {
    AnyView(LibraryPage())
})
// eine Seite mit section: .main, order: 0 (oder kleiner) ersetzt die Startseite des Starters
// (MainWindowModel.visible); niemand muss Modules/Window ändern
WindowSearch.enable(page: "library") { T.searchPrompt }   // Suchfeld nur auf dieser Seite
@Environment(\.windowSearch) private var query           // in der Seite
WindowSidebarFooter.add(id: "sync", order: 10) { AnyView(SidebarStatusLine(text: T.synced)) }

PageScaffold(title, subtitle:, showsTitle:, accessory: { … }) { … }
HeroHeader(eyebrow:, title:, subtitle:, seed:, symbol:, primary: HeaderAction(…), secondary: …)
Shelf(title, subtitle:, seeAll:, items:, tileWidth:) { item in Tile(…) }
TileGrid(items:, minimum:, maximum:) { item in Tile(…) }
Tile(title:, subtitle:, seed:, symbol:, isSelected:, action: ArtworkAction(…), more:, previewHover:, open:)
ItemList(items: [ItemListItem], leading: .index|.artwork|.none, columns:, selection: Binding<String?>?, previewHovered:, open:) { item in /* Kontextmenü */ }
DetailHeader(eyebrow:, title:, subtitle:, meta:, description:, seed:, symbol:, primary:, secondary:)
Artwork(seed:, symbol:, placement: .center|.trailing|.none, cornerRadius:)
EmptyPage(symbol:, title:, message:, actionTitle:, action:) / EmptyPage.noResults(query) / EmptyPage.noPages
NoResults(query:)                                  // Suche ohne Treffer innerhalb von PageScaffold (Titel bleibt)
OnArtworkButtonStyle()                             // Zweitaktion auf Artwork (dunkle Fläche, weiße Schrift)
MainWindowController.show() / close() / isOpen      // sonst AppActions.openMainWindow()
SettingKey.windowPage ("window.page"), SettingKey.windowSidebarHidden ("window.sidebarHidden")
```

## Entscheidungen

- **Fenster über `WindowHost`, nicht eigener Controller-Code.** `WindowHost` hat schon Autosave mit VoiceBuds Freigabe-beim-Schließen, Freigabe der Views und `AppForm`. `MainWindowController` setzt nur die Chrome über den neuen `configure:`-Haken (vor dem Wiederherstellen des Rahmens und dem Zeigen).
- **Mindestgröße über SwiftUI, nicht nur `window.minSize`.** Versuch (`scratchpad/expA/t3.swift`): `NSHostingController` setzt `window.minSize` beim ersten Layout auf 0 x 0 zurück, auch mit `sizingOptions = []`. Lösung: Wurzel-View mit `.frame(minWidth: 900, maxWidth: .infinity, minHeight: 600 - 52, maxHeight: .infinity)` und `sizingOptions = [.minSize]` nur für das Hauptfenster; vorher `window.minSize`/`contentMinSize` auf 0 setzen. Eine schon gesetzte Mindestgröße (WindowHost setzt 900 x 600) wird sonst mit der 32-pt-Titelleiste umgerechnet und wächst dann um die Symbolleiste: Ergebnis war 900 x 620 (Messreihe: 547 → 599, 548 → 620, 549 → 601). Der Selbsttest verlangt jetzt genau 900 x 600. **Gilt auch für das Einstellungsfenster (Strang E / S0):** dessen `minSize` 760 x 500 hält aus demselben Grund nicht.
- **Symbolleiste:** `NavigationSplitView` legt die `NSToolbar` selbst an (Seitenleisten-Knopf, Suche), auch ohne Scene-Bridging. `.searchable` hängt nur an Seiten aus `WindowSearch`, damit kein Suchfeld ohne Wirkung dasteht (**Vertragsänderung gegenüber STRANDS §A**, siehe unten). ⌘F ist nur aktiv, wenn die gezeigte Seite die Suche nutzt; es öffnet das Hauptfenster und fokussiert die Suche (`.searchFocused`, macOS 15+), auch wenn das Fenster erst durch ⌘F entsteht (`searchFocusPending`, `onChange(initial:)`).
- **Auswahl:** `MainWindowModel.select` speichert `window.page` und leert die Suche; eine gespeicherte Seite, die es nicht mehr gibt, fällt auf die erste Seite zurück. Die Sichtbarkeit der Seitenleiste wird nur bei echter Änderung geschrieben (SwiftUI schreibt die Bindung von selbst zurück; sonst entstünde beim Öffnen eine Settings-Datei).
- **Artwork-Farben werden berechnet, nicht per `hueRotation`.** Offscreen-Renders verwerfen den `hueRotation`-Filter (alle Bilder waren gleich violett), das Fenster nicht: Renders hätten gelogen. `ArtworkRecipe` (FNV-1a + SplitMix64, nicht `hashValue`) dreht die Akzentfarben in HSB um höchstens ±25° (Lichtfleck höchstens ±35° vom Akzent), dazu Licht- und Schattenfleck; Ober-, Unter- und Lichtfarbe werden auf Leuchtdichte 0,28 abgedunkelt, damit weiße Glyphen bei jedem Akzent mindestens 3:1 haben (Rot bleibt rot/rosa, Orange und Grün werden dunkler statt gelb). Graphit bleibt grau (keine Sättigung).
- **Statische Fensteransicht** wie VoiceBuds HubStaticWindow: `NavigationSplitView`, Glas und Scroll-Views zeichnen offscreen nicht. Seitenleiste als schwebendes Panel (Radius 18, 8 pt Abstand), Gruppen kommen aus derselben `MainWindowModel.groups`-Regel wie im echten Fenster.
- **Regale in Renders:** eine zu breite Kachelreihe darf die Seite nicht verbreitern; eine unsichtbare Kachel gibt die Höhe, die Reihe hängt als Overlay daran und wird am Fensterrand abgeschnitten.
- **Starten:** `AppDelegate` öffnete das Hauptfenster schon (`AppActions.openMainWindow`, wenn kein Onboarding nötig ist); ein zusätzlicher Start-Hook hätte beim ersten Start Onboarding und Hauptfenster gleichzeitig geöffnet. Statt dessen: `--background` und Anmeldeobjekt-Start (Apple Event `keyAELaunchedAsLogInItem`) öffnen kein Fenster, und der Modul-Hook öffnet das Hauptfenster, sobald `onboarding.done` true wird.
- **Fußzeile „Alles lokal und offline“** registriert das Modul selbst (stimmt, solange das Projekt kein Netz nutzt; `WindowSidebarFooter.remove(id: "window.local")`).
- **Titelbild (Hero):** Abdunklung deckt die ganze Textspalte voll ab (0,55 Schwarz) und läuft erst rechts davon aus; Text durchgehend weiß; Zweitaktion mit `OnArtworkButtonStyle`, weil der Kit-Stil `.secondary` im Dunkelmodus auf hellem Artwork blass wird; das Glyph liegt über der Abdunklung und erscheint nur, wenn es neben der Textspalte Platz hat. Ein Test rendert `HeroBackdrop` für alle sechs Akzente und misst die Textspalte (mindestens 4,5:1).
- Gestreifte Listenzeilen; Hover `listHover` (Schwarz 9 % / Weiß 12 %, deutlich über dem Streifen, getestet); Auswahl volle Akzentfläche mit `onAccent`, solange das Fenster aktiv ist (`controlActiveState`), sonst `accentSoft` mit `accentText`.

## Aus VoiceBud übernommen (für THIRD_PARTY_NOTICES, MIT, Copyright (c) 2026 Anas Riad)

- Statische Fensterdarstellung für Renders (HubStaticWindow: schwebendes Seitenleisten-Panel 18/8, Fensterradius 26) → `StaticMainWindow`, `StaticSidebar`
- Seitenleisten-Fußzeile mit grünem 7-pt-Punkt „Alles lokal und offline“ (HubSidebar) → `SidebarStatusLine`, `WindowSidebarFooter`
- Tastenwege ⌘W/⌘F des Hubs → Menüs Ablage/Suchen (hier über das echte Hauptmenü, da eine Fenster-App eins hat)
- Auswahlring 2,5 pt, 4 pt außen, Radius 15 (HubTilePicker) → `Tile(isSelected:)`
- Muster „Renders über eine statische Umgebung, `\.renderStatic`“ → `PageScroll`, `Shelf`

## Außerhalb meines Strangs angefasst (klein, additiv)

- `Kit/Main/CommandLine.swift`: Flag `--background` (`LaunchFlags.background`), `Launch.isBackground`.
- `Kit/Main/AppDelegate.swift`: bei `Launch.isBackground` oder Start als Anmeldeobjekt (Apple Event) keine Fenster (auch kein Onboarding); setzt dann `Launch.isBackground = true`. Strang B (Anmeldeobjekt) und D (Onboarding „außer bei --background“) können das nutzen. Start und Dock-Klick teilen sich eine Regel (`AppDelegate.primaryWindow`, `openPrimaryWindow`): erst die Einrichtung, solange sie nicht fertig ist, sonst das Hauptfenster.
- `Kit/Main/MainMenu.swift`: `MainMenu.decorators: [(NSMenu) -> Void]`, laufen bei jedem `rebuild()` vor dem Setzen von `NSApp.mainMenu`.
- `Kit/Main/WindowHost.swift`: Parameter `configure: ((NSWindow) -> Void)? = nil` in `show(...)`, einmal für ein neues Fenster vor dem Wiederherstellen des Rahmens.
- `App/Tests/BackgroundLaunchTests.swift` (neu) für die Kit-Ergänzungen (3 Tests).

## Kandidaten für Kit/Design

`WindowTokens.swift` (`Metrics.Window`, `Space.page/pageBlock/tileGap`, `TypeScale.pageTitle/heroTitle/detailTitle`, `Radius.artworkSmall`, `Theme.onArtwork…/artworkScrim…`), `StaticSidebar` (Strang E braucht dasselbe Panel), `PageScroll` (wie `PaneScroll`, aber ohne `.clipped()`, damit der Inhalt unter das Glas der Symbolleiste läuft), `Artwork` (könnte auch Onboarding-Bilder und Hub-Kacheln füllen).

## Bekannte Lücken

- Das echte Fenster wurde nie auf dem Bildschirm gesehen (Regel: App nie normal starten). Geprüft ist es nur unsichtbar im Selbsttest (Symbolleiste mit Suche, Chrome, Größen). Offen für den Lead: Aussehen der nativen Seitenleiste neben den Render-Nachbildungen, Rahmen-Wiederherstellung nach Neustart, Dock-Klick, ⌃⌘S, ⌘F-Fokus, Vollbild, Hover auf Kacheln und Zeilen, Doppelklick und Kontextmenü in `ItemList`.
- Die Startseite zeigt das App-Symbol aus `AppIcon.icns`; solange Strang J es nicht erzeugt hat, steht dort das Akzent-Squircle mit `app.symbol`.
- `ItemList` hat keine Pfeiltasten-Navigation (eigene Zeilen statt `List`, damit Renders sie zeichnen).
- Die Titelleiste zeigt keinen Seitentitel (wie Musik); `window.title` bleibt der App-Name für Fenster-Menü und Mission Control.
- Nach dem Onboarding öffnet der Modul-Hook das Hauptfenster. Ob Strang D beim Abschluss `onboarding.done` setzt (Kit-Schlüssel aus S0), ist in Welle 2 zu prüfen.
- Hilfe-Menü hat nur „Einrichtung erneut zeigen“; es gibt keine Hilfe-Seiten.
- Barrierefreiheit: Labels/Traits gesetzt (Kacheln, Zeilen, Köpfe), nicht mit VoiceOver geprüft.
- Die Prüfskripte von Strang G1 (Stand im Worktree G1, Kopie im Scratch-Ordner) melden für `Modules/Window` keine Befunde. Für `Kit/Main` meldet `check_texts.py` einen Befund: `Kit/Main/AppForm.swift:3` („BAUPLAN“ im Kommentar, S-12); die Datei gehört S0, ich habe sie nicht angefasst.
- Wo Features sich registrieren, legt S0/K fest (es gibt noch keinen Feature-Haken in `Modules.swift`); die Startseite nennt deshalb nur `Registry.pages`.
- Auswahl in `ItemList` mit weißer Schrift auf `#8F6CF2` hat etwa 4:1; das ist die Kit-Regel für `onAccent` (mindestens 3:1 wie VoiceBud), aber unter 4,5:1 für 13-pt-Text.
- Die Einrückung der Fußzeile folgt den Render-Zeilen (16 pt); wie weit die native Seitenleiste von macOS 26 einrückt, ist nur am Bildschirm zu sehen.

## Prüfung (Befehle und Ergebnisse, 2026-10-12, nach den Review-Korrekturen)

```
make build                                    -> grün (window,menubar,island,background,hotkeys,ai,examples), 0 Warnungen
make build MODULES=window                     -> grün, 0 Warnungen; --selftest "12 checks, 0 failures"
make build MODULES=menubar                    -> grün, 0 Warnungen; --selftest "8 checks, 0 failures"
make build MODULES=window,menubar             -> grün, 0 Warnungen; --selftest "12 checks, 0 failures"
make build MODULES=window,menubar,island,background,hotkeys,ai,mlx,examples -> grün, 0 Warnungen; --selftest 12/0
make build CONFIG=release                     -> grün, 0 Warnungen
Selbsttests jeweils mit STARTER_HEADLESS=1 STARTER_DATA_DIR=<tmp> …/Starter --selftest: kein Fenster sichtbar,
                                                 kein Prozess bleibt, Datenordner leer
make test                                     -> "100 tests, 0 failures" + Python "Ran 11 tests … OK"
MODULES=menubar make test                     -> "70 tests, 0 failures" (WindowTests fallen mit dem Modul weg)
make check                                    -> grün (rules_sync/check_texts/check_design/check_kit noch nicht auf main, übersprungen)
make shots                                    -> 252 PNGs + index.html (64 davon window.*)
G1-Prüfskripte (Kopie) check_design/check_texts --streng auf Modules/Window und Kit/Main
                                              -> Modules/Window ohne Befund; Kit/Main/AppForm.swift:3 (S0)
```

Angesehen (Read) nach den Korrekturen: `window.main` en-dunkel und de-hell, `window.artwork` en-hell, `window.hero-header` de-hell, `window.detail` en-hell und de-dunkel, `window.sidebar` de-dunkel, `window.home` de-dunkel (plus eine hohe Probe 1180 x 1120 de-hell, damit die Baustein-Zeilen sichtbar sind), `window.search-empty` de-dunkel, `window.no-pages` en-hell, `window.page-scaffold` de-hell; dazu `window.artwork` (hell) und `window.hero-header` (dunkel) mit `accent` `rot` und `orange` in einer vorübergehend geänderten starter.json (danach zurückgesetzt).

## Prüfung durch die Reviewer (Befunde und was daraus wurde)

| # | Befund | Ergebnis |
|---|---|---|
| 1 | Suche nur per `WindowSearch.enable`, nirgends eingeschaltet, ⌘F wirkungslos | **Teilweise geändert, Vertrag bewusst abweichend.** Das Opt-in bleibt (ein Suchfeld ohne Wirkung auf der Startseite wäre schlechter); es ist jetzt als Vertragsänderung hier vermerkt, damit G2 den Skill `neue-ansicht` (Schritt 4) und `docs/MODULE.md` um `WindowSearch.enable(page:prompt:)` ergänzt. ⌘F ist nur noch aktiv, wenn die gezeigte Seite die Suche nutzt; die Startseite nennt `WindowSearch.enable`. |
| 2 | Keine Möglichkeit, die Startseite ohne Kit-Änderung zu ersetzen | **Behoben.** Die Startseite tritt zurück, sobald eine andere Seite `section: .main, order <= 0` hat (`MainWindowModel.visible`, getestet); Texte auf der Startseite nennen das statt `WindowModule.register()`. |
| 3, 12 | Hero-Text 2,4–2,9:1, Zweitaktion im Dunkelmodus 2,5:1 | **Behoben.** Abdunklung voll unter der Textspalte, Text ganz weiß, `OnArtworkButtonStyle`, Glyph über der Abdunklung und nur mit Platz. Render-Test über alle Akzente misst die Textspalte (≥ 4,5:1); mit der alten Abdunklung schlägt er fehl (3,7–4,2:1). |
| 4 | Mindesthöhe 620 statt 600, Selbsttest zu tolerant | **Behoben.** Ursache gemessen (vorher gesetztes `minSize` + Titelleiste/Symbolleiste); jetzt genau 900 x 600, Selbsttest verlangt Gleichheit. |
| 5, 16 | Hover auf gestreiften Zeilen unsichtbar, Auswahl nur schwach | **Behoben.** `listHover` mit Test (≥ 1,1:1 gegenüber dem Streifen in beiden Modi); Auswahl volle Akzentfläche bei aktivem Fenster. |
| 6 | ⌃⌘S wirkt aus jedem Fenster, auch bei geschlossenem Hauptfenster; statischer Titel | **Behoben.** Nur aktiv, wenn das Hauptfenster Schlüsselfenster ist; Titel „Seitenleiste einblenden/ausblenden“ je nach Zustand (Validierung, getestet). |
| 7 | `decorate` gibt Ziele vor der Prüfung frei | **Behoben.** `targets.removeAll()` nach der Prüfung; Test prüft, dass nach dem zweiten Durchlauf jeder Eintrag ein Ziel hat. |
| 8 | Dock-Klick nach Hintergrundstart überspringt die Einrichtung | **Behoben** (Kit/Main, außerhalb des Strangs): eine Regel für Start und Dock-Klick, getestet. |
| 9 | Regionsnamen als Literale | **Behoben.** In `WindowSampleText` (`Rhön` durch `Spessart` ersetzt, weil der Textcheck Umlaute im Englischen meldet). |
| 10 | Literale Werte in `Artwork`, Ausnahme-Kommentare uneinheitlich | **Behoben.** Faktoren als `Metrics.Window`-Tokens; Glyph voll weiß; `design-ausnahme` nur dort, wo `check_design.py` etwas findet (das Skript meldet überflüssige Ausnahmen selbst als Befund). |
| 11 | Zahlen im Bericht stimmen nicht | **Behoben.** Mindestgröße, Testzahlen (100 / 70) und G1-Befund oben korrigiert. |
| 13 | Artwork verlässt die Akzentfamilie, Glyph mit Rot kaum lesbar | **Behoben.** ±25°/±35°, Leuchtdichte ≤ 0,28; Test über 6 Akzente × 300 Seeds (Farbton und 3:1 für Weiß); mit `rot` und `orange` gerendert und angesehen. |
| 14 | Startseite und Beispieltexte abgeschnitten, vor allem Deutsch | **Behoben.** Reguläre Kachelbreite, kürzere Beschreibungen, „Feierabendküche“; Test misst Kachelzeilen und Seitenleistentitel in beiden Sprachen. |
| 15 | ⌘F immer aktiv, Startseite verspricht Suche, Fokus geht beim Öffnen verloren | **Behoben.** Siehe 1; Text sagt „Menüs“ statt „Suche“; Fokuswunsch bleibt stehen, bis die Ansicht erscheint. Ob der Fokus am echten Fenster ankommt, ist nur am Bildschirm prüfbar. |
| 17 | Fußzeile der Seitenleiste nicht bündig | **Behoben.** Gemeinsamer Einzug (16 pt), Punkt in der Symbolspalte, Text bündig mit den Zeilentiteln. |
| 18 | Menü- und UI-Wortlaut nicht nativ, Anglizismen | **Behoben.** Ein-/Ausblenden-Titel, „im selben Stil“, „Bild mit Schnellaktion“, „Zu Favoriten hinzufügen“. |
| 19 | Beispielszenen widersprechen sich | **Behoben.** Detailseite: „Tour hinzufügen“; Untertitel zählt die gezeigten Kacheln; Übersicht mit niedrigerem Titelbild, Liste beginnt im Fenster. |
| 20 | Kein Render für „keine Seiten“, Treffer-leer ersetzt den Seitenkopf | **Behoben.** Szene `window.no-pages`; `NoResults` innerhalb von `PageScaffold`, Titel und „0 Treffer für …“ bleiben. Eine Aktion „Suche löschen“ fehlt weiter (die Seite kann die Suche nicht zurücksetzen, nur das Modell). |

Vertragsänderung für die Integration: Suchfeld nur für Seiten mit `WindowSearch.enable(page:prompt:)`; Seiten lesen die Anfrage weiter über `\.windowSearch`. Betrifft `.claude/skills/neue-ansicht/SKILL.md` und `docs/MODULE.md` (Strang G2).
