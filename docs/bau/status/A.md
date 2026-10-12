# Status A (Modul window, Hauptfenster im Stil von Musik)

Stand: 2026-10-12, Branch `strang/A`. Alles aus STRANDS.md Abschnitt A ist gebaut, getestet und gerendert.

## Was gebaut ist

| Bereich | Dateien (`App/Sources/Modules/Window/`) |
|---|---|
| Registrierung | `WindowModule.swift`: Startseite, `AppActions.mainWindowHandler`, Menü-Dekorator, Fußzeile „Alles lokal und offline“, Katalog, Start-Hook „nach der Einrichtung Hauptfenster öffnen“ |
| Fenster | `MainWindowController.swift` (auf `WindowHost`: vereinheitlichte Symbolleiste, volle Inhaltsfläche, Titel verborgen, Mindestgröße 900 x 600, Standard 1180 x 760, Vollbild, Rahmen-Autosave mit Freigabe beim Schließen aus `WindowHost`) |
| Inhalt | `MainWindowView.swift` (`NavigationSplitView`, native Seitenleiste aus `Registry.pages` nach `PageSection` gruppiert, erste Gruppe ohne Titel wie in Musik, Akzent-Symbole, Fußzeile, Suche in der Symbolleiste nur für Seiten, die sie einschalten), `MainWindowModel.swift` (Auswahl und Seitenleiste in Settings, `WindowSearch`, `WindowSidebarFooter`, `SidebarGroup`) |
| Menüs | `WindowMainMenu.swift`: Ablage (Schließen ⌘W, aus dem Fenster-Menü verschoben), Bearbeiten + Suchen ⌘F, Darstellung (Seitenleiste ⌃⌘S, Vollbild ⌃⌘F), Fenster + Hauptfenster ⌘0, Hilfe (Einrichtung erneut zeigen); alle Titel aus `WindowText`, folgen der Sprache |
| Bausteine | `Components/`: `PageScaffold` (+ `PageScroll`, `PageSectionTitle`, Umgebung `\.windowSearch`, `\.windowPageInset`), `HeroHeader` (+ `HeaderAction`, `HeaderActions`), `Shelf`, `Tile` (+ `ArtworkAction`, `ArtworkButton`), `TileGrid`, `ItemList` (+ `ItemListItem`, `ItemListColumns`), `DetailHeader`, `Artwork` (+ `ArtworkRecipe`, `ArtworkRGB`), `EmptyPage`, `WindowTokens.swift` |
| Startseite | `Pages/HomePage.swift`: App-Symbol, Name, Version, ein Satz, drei nächste Schritte mit Pfaden und Skill `neue-ansicht`, Regal der Bausteine, Hinweis zum Entfernen; `AppIconImage`, `BuildingBlock` |
| Renders | `StaticMainWindow.swift` (Fenster, schwebende Seitenleiste von macOS 26, Symbolleistenband mit Suchkapsel), `WindowCatalog.swift` (Galerie, Szenen, Selbsttests), `Samples/WindowSamples.swift`, `Samples/WindowSampleText.swift` |
| Texte | `WindowText.swift` (+ `WindowCodeNames` für Pfade und Bezeichner, sprachunabhängig) |
| Tests | `App/Tests/WindowTests.swift` (22 Tests), `App/Tests/BackgroundLaunchTests.swift` (2 Tests für die Kit-Ergänzungen) |

Szenen (je en/de × hell/dunkel, 60 PNGs): `window.main`, `window.home`, `window.detail`, `window.search`, `window.search-empty`, `window.sidebar`, `window.page-scaffold`, `window.hero-header`, `window.shelf`, `window.tile` (normal, Hover, ausgewählt), `window.tile-grid`, `window.item-list` (Kopf, Streifen, Hover, Auswahl, Bild-Variante), `window.detail-header`, `window.artwork`, `window.empty-page`. Jede Szene ist auch ein Galerie-Eintrag (Bereich `window`).

Selbsttests (`--selftest`): `window.registration`, `window.symbols` (alle SF Symbols existieren), `window.chrome` (baut das echte Fenster unsichtbar mit einer Wegwerf-Settings-Datei: Symbolleiste mit Suchfeld, vereinheitlicht, Titel verborgen, Mindestgröße, Größe nach dem Layout, schreibt keine Einstellungen), `window.render`.

## API für Seiten (Module, Features, Projekte)

```swift
Registry.pages.append(AppPage(id: "library", section: .library, order: 0, title: { T.library }, symbol: "square.grid.2x2.fill") {
    AnyView(LibraryPage())
})
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
EmptyPage(symbol:, title:, message:, actionTitle:, action:) / EmptyPage.noResults(query)
MainWindowController.show() / close() / isOpen      // sonst AppActions.openMainWindow()
SettingKey.windowPage ("window.page"), SettingKey.windowSidebarHidden ("window.sidebarHidden")
```

## Entscheidungen

- **Fenster über `WindowHost`, nicht eigener Controller-Code.** `WindowHost` hat schon Autosave mit VoiceBuds Freigabe-beim-Schließen, Freigabe der Views und `AppForm`. `MainWindowController` setzt nur die Chrome über den neuen `configure:`-Haken (vor dem Wiederherstellen des Rahmens und dem Zeigen).
- **Mindestgröße über SwiftUI, nicht nur `window.minSize`.** Versuch (`scratchpad/expA/t3.swift`): `NSHostingController` setzt `window.minSize` beim ersten Layout auf 0 x 0 zurück, auch mit `sizingOptions = []`. Lösung: Wurzel-View mit `.frame(minWidth: 900, minHeight: 600 - 52)` und `sizingOptions = [.minSize]` nur für das Hauptfenster. Der Selbsttest prüft das am echten Fenster. **Gilt auch für das Einstellungsfenster (Strang E / S0):** dessen `minSize` 760 x 500 hält aus demselben Grund nicht.
- **Symbolleiste:** `NavigationSplitView` legt die `NSToolbar` selbst an (Seitenleisten-Knopf, Suche), auch ohne Scene-Bridging. `.searchable` hängt nur an Seiten aus `WindowSearch`, damit kein Suchfeld ohne Wirkung dasteht. ⌘F öffnet das Hauptfenster und fokussiert die Suche (`.searchFocused`, macOS 15+).
- **Auswahl:** `MainWindowModel.select` speichert `window.page` und leert die Suche; eine gespeicherte Seite, die es nicht mehr gibt, fällt auf die erste Seite zurück. Die Sichtbarkeit der Seitenleiste wird nur bei echter Änderung geschrieben (SwiftUI schreibt die Bindung von selbst zurück; sonst entstünde beim Öffnen eine Settings-Datei).
- **Artwork-Farben werden berechnet, nicht per `hueRotation`.** Offscreen-Renders verwerfen den `hueRotation`-Filter (alle Bilder waren gleich violett), das Fenster nicht: Renders hätten gelogen. `ArtworkRecipe` (FNV-1a + SplitMix64, nicht `hashValue`) dreht die Akzentfarben in HSB um ±60°, dazu Licht- und Schattenfleck; alles getestet. Graphit bleibt grau (keine Sättigung).
- **Statische Fensteransicht** wie VoiceBuds HubStaticWindow: `NavigationSplitView`, Glas und Scroll-Views zeichnen offscreen nicht. Seitenleiste als schwebendes Panel (Radius 18, 8 pt Abstand), Gruppen kommen aus derselben `MainWindowModel.groups`-Regel wie im echten Fenster.
- **Regale in Renders:** eine zu breite Kachelreihe darf die Seite nicht verbreitern; eine unsichtbare Kachel gibt die Höhe, die Reihe hängt als Overlay daran und wird am Fensterrand abgeschnitten.
- **Starten:** `AppDelegate` öffnete das Hauptfenster schon (`AppActions.openMainWindow`, wenn kein Onboarding nötig ist); ein zusätzlicher Start-Hook hätte beim ersten Start Onboarding und Hauptfenster gleichzeitig geöffnet. Statt dessen: `--background` und Anmeldeobjekt-Start (Apple Event `keyAELaunchedAsLogInItem`) öffnen kein Fenster, und der Modul-Hook öffnet das Hauptfenster, sobald `onboarding.done` true wird.
- **Fußzeile „Alles lokal und offline“** registriert das Modul selbst (stimmt, solange das Projekt kein Netz nutzt; `WindowSidebarFooter.remove(id: "window.local")`).
- Gestreifte Listenzeilen, Hover `chip`, Auswahl `accentSoft` mit `accentText` (Kontrast durch die Badge-Tests des Kits abgedeckt).

## Aus VoiceBud übernommen (für THIRD_PARTY_NOTICES, MIT, Copyright (c) 2026 Anas Riad)

- Statische Fensterdarstellung für Renders (HubStaticWindow: schwebendes Seitenleisten-Panel 18/8, Fensterradius 26) → `StaticMainWindow`, `StaticSidebar`
- Seitenleisten-Fußzeile mit grünem 7-pt-Punkt „Alles lokal und offline“ (HubSidebar) → `SidebarStatusLine`, `WindowSidebarFooter`
- Tastenwege ⌘W/⌘F des Hubs → Menüs Ablage/Suchen (hier über das echte Hauptmenü, da eine Fenster-App eins hat)
- Auswahlring 2,5 pt, 4 pt außen, Radius 15 (HubTilePicker) → `Tile(isSelected:)`
- Muster „Renders über eine statische Umgebung, `\.renderStatic`“ → `PageScroll`, `Shelf`

## Außerhalb meines Strangs angefasst (klein, additiv)

- `Kit/Main/CommandLine.swift`: Flag `--background` (`LaunchFlags.background`), `Launch.isBackground`.
- `Kit/Main/AppDelegate.swift`: bei `Launch.isBackground` oder Start als Anmeldeobjekt (Apple Event) keine Fenster (auch kein Onboarding); setzt dann `Launch.isBackground = true`. Strang B (Anmeldeobjekt) und D (Onboarding „außer bei --background“) können das nutzen.
- `Kit/Main/MainMenu.swift`: `MainMenu.decorators: [(NSMenu) -> Void]`, laufen bei jedem `rebuild()` vor dem Setzen von `NSApp.mainMenu`.
- `Kit/Main/WindowHost.swift`: Parameter `configure: ((NSWindow) -> Void)? = nil` in `show(...)`, einmal für ein neues Fenster vor dem Wiederherstellen des Rahmens.
- `App/Tests/BackgroundLaunchTests.swift` (neu) für die zwei Kit-Ergänzungen.

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
- Die Prüfskripte von Strang G1 (Stand im Worktree G1, Kopie im Scratch-Ordner) melden für `Modules/Window` und `Kit/Main`-Änderungen keine Befunde; `Kit/Main/AppForm.swift:3` („BAUPLAN“ im Kommentar) gehört S0.

## Prüfung (Befehle und Ergebnisse, 2026-10-12)

```
make build                                    -> grün (window,menubar,island,background,hotkeys,ai,examples), 0 Warnungen
make build MODULES=window                     -> grün; --selftest "12 checks, 0 failures"
make build MODULES=menubar                    -> grün; --selftest "8 checks, 0 failures"
make build MODULES=window,menubar             -> grün; --selftest "12 checks, 0 failures"
make build MODULES=window,menubar,island,background,hotkeys,ai,mlx,examples -> grün; --selftest 12/0
make build CONFIG=release                     -> grün
STARTER_HEADLESS=1 STARTER_DATA_DIR=<tmp> …/Starter --selftest -> "selftest: 12 checks, 0 failures", exit 0,
                                                 kein Fenster sichtbar, kein Prozess bleibt, Datenordner leer
make test                                     -> "91 tests, 0 failures" + Python "Ran 11 tests … OK"
MODULES=menubar make test                     -> "67 tests, 0 failures" (WindowTests fallen mit dem Modul weg)
make check                                    -> grün (Prüfskripte von G/K noch nicht auf main, übersprungen)
make shots                                    -> 248 PNGs + index.html (60 davon window.*)
G1-Prüfskripte (Kopie) check_design/check_texts --streng auf Modules/Window -> keine Befunde
```

Angesehen (Read): `window.main` de-hell und en-dunkel, `window.detail` de-hell, `window.home` de-dunkel und en-hell, `window.search` de-hell, `window.search-empty` de-dunkel, `window.tile` en-hell, `window.item-list` de-dunkel, `window.artwork` en-hell und en-dunkel, `window.page-scaffold` de-hell, `window.detail-header` de-dunkel, `window.shelf` en-hell, `window.hero-header` en-hell, `window.sidebar` de-dunkel.
Behoben nach dem Ansehen: zu breite Kachelreihe schob die ganze Seite nach links (Overlay-Lösung), Regal begann 32 pt zu weit rechts, alle Artworks gleich violett (`hueRotation` fehlt offscreen, Farben jetzt berechnet), helle Artworks mit schwachem Glyph-Kontrast (Oberfarbe dunkler, Schatten stärker), abgeschnittener Pfad in Schritt 2 (zwei Zeilen), Suchkapsel zu nah am Fensterrand (16 pt), Beschreibung im Detailkopf ohne Lesebreite (max. 640).
