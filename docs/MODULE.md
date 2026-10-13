# Module

Jedes Modul ist ein Ordner unter `App/Sources/Modules/<Name>/` mit `<Name>Module.register()`, eingeschaltet in `starter.json` (`modules`) und als Compiler-Flag `MODUL_<NAME>` gebaut. Ein Modul nutzt nur das Kit und meldet alles über die Registry an: Seiten, Einstellungsbereiche, Einrichtungsschritte, Menüeinträge, Galerie-Einträge, Render-Szenen, Selbsttests. Einstellungsschlüssel tragen das Präfix des Moduls.

| Modul | Form oder Aufgabe | Standard | braucht | Entfernen |
|---|---|---|---|---|
| `window` | Fenster-App mit Seitenleiste im Stil von Musik | an | | `bin/starter remove window` | <!-- modul:window -->
| `menubar` | Menüleisten-App mit Statussymbol und Statusmenü | an | | `bin/starter remove menubar` | <!-- modul:menubar -->
| `island` | Insel an der Notch, Kapsel ohne Notch | an | | `bin/starter remove island` | <!-- modul:island -->
| `background` | geplante Aufgaben, Start beim Anmelden | an | | `bin/starter remove background` | <!-- modul:background -->
| `hotkeys` | globale Tastaturkurzbefehle | an | | `bin/starter remove hotkeys` | <!-- modul:hotkeys -->
| `ai` | lokale KI mit Apple Foundation Models | an | | `bin/starter remove ai` (nach `mlx`) | <!-- modul:ai -->
| `mlx` | eigene Modelle über einen MLX-Worker in Python | aus | `ai` | `bin/starter remove mlx` | <!-- modul:mlx -->
| `examples` | Beispiel-Feature, das alle Module nutzt | an | | `bin/starter strip-examples` | <!-- modul:examples -->

Mindestens `window` oder `menubar` bleibt; ohne beide sind die Einstellungen nicht erreichbar, und `bin/starter remove` lehnt das ab. Mit `window` hat die App ein Dock-Symbol (`.regular`), ohne `window` lebt sie nur in der Menüleiste (`.accessory`, `LSUIElement`).

`bin/starter remove <modul>` löscht den Ordner des Moduls und alles, was `starter.manifest.json` ihm zuordnet (Tests, Skills, Werkzeuge), entfernt jeden `#if MODUL_<NAME>` … `#endif`-Block in allen Swift-Dateien (bei `#else` bleibt dieser Teil), Zeilen mit `<!-- modul:<name> -->` und Abschnitte zwischen `<!-- modul:<name>:anfang -->` und `<!-- modul:<name>:ende -->` in Markdown (in YAML, Shell und Python `# modul:<name>`) und das Modul aus `starter.json`; danach baut es (`--ohne-build` lässt das aus, `--probelauf` zeigt nur, was passieren würde). Ein Commit je entferntem Modul.

`make build MODULES=a,b` baut eine andere Auswahl, ohne `starter.json` zu ändern.

## Reihenfolge in der Registry

Jedes Modul hat für seine Einstellungsbereiche und Einrichtungsschritte einen eigenen Bereich von `order`-Werten; zwei Beiträge teilen sich nie einen Wert. Eigene Funktionen des Projekts nehmen die freien Bereiche, in Zehnerschritten.

| `order` | Einstellungsbereich (Gruppe `.settings`, unter den Inhalten) |
|---|---|
| 0 | Allgemein (Kit) |
| 100 bis 199 | Funktionen des Projekts |
| 200 bis 249 | Insel und Kapsel (`island`, 200) | <!-- modul:island -->
| 250 bis 299 | Menüleiste (`menubar`, 250) | <!-- modul:menubar -->
| 300 bis 349 | Modelle (`ai`, 300; `mlx` ist ein Abschnitt darin) | <!-- modul:ai -->
| 350 bis 399 | Hintergrund (`background`, 350) | <!-- modul:background -->
| 400 bis 449 | Tastaturkurzbefehle (`hotkeys`, 400) | <!-- modul:hotkeys -->
| 1000 | Über (Kit) |

Die Gruppe `.content` steht oben; dort beginnen Bereiche der Funktionen bei 100 (Beispiel „Notizen“), die Galerie des Kits (nur in Debug-Builds) hat 900. Die Reihenfolge der Einrichtungsschritte steht im Skill `neuer-onboarding-schritt`: Kit 0 bis 20, Funktionen 30 bis 299, Berechtigungen 300 bis 399, dann `ai` 400, `island` 500, `hotkeys` 600, `background` 900, Fertig 1000.

<!-- modul:window:anfang -->
## window: Fenster-App

- **Zweck:** Hauptfenster im Stil von Musik unter macOS 26: `NavigationSplitView` mit Seitenleiste aus Systemglas, Werkzeugleiste mit Suche, Seiten aus Bausteinen (großer Titel, Kopf mit Bild, Reihen von Kacheln, Raster, Listen, Detailseite). ⌘, öffnet die Einstellungen.
- **Dateien:** `MainWindowController` (Fenster 1180 x 760, mindestens 900 x 600, Rahmen gespeichert, Dock-Klick öffnet wieder), `MainWindowView` (Seitenleiste aus `Registry.pages` nach `PageSection`, Auswahl gespeichert, Fußzeile der Seitenleiste über `WindowSidebarFooter.add(id:order:content:)`, Suchfeld in der Werkzeugleiste nur für Seiten mit `WindowSearch.enable(page:prompt:)`, der Suchtext kommt als `\.windowSearch` an), `WindowMainMenu` (ergänzt das Menü des Kits um Ablage, Suchen, Darstellung, ⌘0 im Fenster-Menü und Hilfe), `Components/` (`PageScaffold`, `HeroHeader`, `Shelf`, `Tile`, `TileGrid`, `ItemList`, `DetailHeader`, `Artwork`, `EmptyPage`, `NoResults`), `HomePage` als Startseite eines frischen Projekts.
- **Einstellungen:** gewählte Seite und ausgeblendete Seitenleiste (Präfix `window.`; ein Zustand, „Einstellungen zurücksetzen“ behält sie).
- **Einrichtung:** kein Schritt.
- **Szenen:** `window.main` (ganzes Fenster), `window.home`, je Baustein eine Szene.
- **Skill:** `neue-ansicht`.
- **Öffnen:** `AppActions.openMainWindow()` holt das Fenster nach vorn, `AppActions.openMainWindow(page:)` wählt vorher eine Seite.
- **Ohne das Modul:** `AppActions.openMainWindow()` öffnet die Einstellungen (eine Seite wird ignoriert); die App läuft als Menüleisten-App.
<!-- modul:window:ende -->

<!-- modul:menubar:anfang -->
## menubar: Menüleisten-App

- **Zweck:** Statussymbol aus `app.symbol` mit den Zuständen `idle`, `busy` (dezente Bewegung, ruht bei reduzierter Bewegung) und `attention` (Punkt). Klick öffnet das Statusmenü im Stil der Module im Kontrollzentrum (abgerundet, Glas, 340 pt breit) mit Kopf, Abschnitten und Fußzeile; Rechtsklick oder ⌥-Klick öffnet ein Menü aus `Registry.menuItems`.
- **Dateien:** `MenuBarController`, `MenuBarStatus.shared.state`, `MenuBarPanel.sections` (Abschnitte mit Kennung, Reihenfolge und View).
- **Einstellungen:** Bereich „Menüleiste“ mit Statustext und Stil des Symbols (Präfix `menubar.`).
- **Einrichtung:** kein Schritt.
- **Szenen:** `menubar.panel`, `menubar.icon-states` mit Beispieldaten; `menubar.project` zeigt das Statusmenü des Projekts mit seinen eigenen Abschnitten und Menüeinträgen. Eigene Abschnitte rendern Features auf `MenuBarPanelStage` (Menüleiste, Schreibtisch, Statusmenü).
- **Skill:** `menueleisten-app`.
<!-- modul:menubar:ende -->

<!-- modul:island:anfang -->
## island: Insel und Kapsel

- **Zweck:** Rückmeldung, die aus der Notch wächst (Insel), auf Macs ohne Notch eine Kapsel unter der Menüleiste. Zustände: Tätigkeit, Fortschritt (Sekundenzähler ab 5 s, Hinweis mit Abbruch ab 10 s), Pegel (mit `recording: true` roter Aufnahmepunkt, in der Kapsel mit Laufzeit), Ergebniskarte, die unter dem Zeiger mit „Kopieren“ aufklappt, Hinweis (Info, Erfolg, Warnung, Fehler, verschwindet nach 2,5 s). Mehrere Bildschirme, Selbstheilung nach Bildschirmwechseln, Töne standardmäßig aus, reduzierte Bewegung blendet über.
- **Dateien:** `IslandScreenGeometry` (Notch je Bildschirm, Höhe der Menüleiste), `IslandPanel` (randloses, nicht aktivierendes Panel, durchklickbar, im Leerlauf ausgeblendet), `NotchShape`, `IslandView`, `CapsuleView`, `IslandContent`, `Island.shared` mit `present(_:)`, `update(_:)`, `dismiss()`, `isPresenting` und `notchBusy` (vom Projekt gesetzt: belegt eine andere App die Notch, erscheint `auto` als Kapsel unter der Notch).
- **Einstellungen:** Bereich „Insel und Kapsel“ mit Darstellung (`island.style`: `auto`, `capsule`, dazu `island` nur, wenn `Island.shared.notchBusy` gesetzt ist; mit Vorschau), Dauer der Bestätigung, „Karte unter dem Zeiger aufklappen“, Töne, Trackpad-Rückmeldung, „Im Vollbild ausblenden“ und „Vorschau zeigen“.
- **Einrichtung:** „Insel und Kapsel“ (order 500, nur auf Macs mit Notch), Kachelwahl Insel oder Kapsel mit den echten Ansichten. Dazu das Bild im Begrüßungsschritt (`Registry.welcomeArt`): die echte Insel wächst aus einer gezeichneten Notch, arbeitet, wird zur Ergebniskarte und faltet sich zurück; in Renders und mit reduzierter Bewegung steht die Karte still. Was sie zeigt, wählt ein Feature über `IslandWelcome.working` und `IslandWelcome.result`.
- **Szenen:** jeder Zustand als `island.<zustand>` und `capsule.<zustand>`, dazu `island.pane`, `island.onboarding`.
- **Skill:** `insel-zustand`. `--demo` durchläuft alle Zustände in der laufenden App (nur für die Person am Mac).
<!-- modul:island:ende -->

<!-- modul:background:anfang -->
## background: Hintergrund

- **Zweck:** geplante Aufgaben über `NSBackgroundActivityScheduler` mit Intervall, Toleranz und Dienstgüte; letzter Lauf, Ergebnis und Dauer werden gespeichert; Schalter und „Jetzt ausführen“ je Aufgabe. Start beim Anmelden über `SMAppService.mainApp`, nur aus einem installierten Ort.
- **Dateien:** `BackgroundJobs` (`register(id:title:interval:tolerance:qos:exact:run:)`, `runNow(_:)`), `LoginItem` (`isAvailable` mit Begründung).
- **Einstellungen:** Bereich „Hintergrund“ mit Anmeldeobjekt und Liste der Aufgaben (Präfix `background.`).
- **Einrichtung:** „Mit dem Mac starten“ (order 900), nur wenn `LoginItem.isAvailable`; die Wahl gilt erst nach „Fertig“ (`Registry.onboardingFinishedHooks`).
- **Szenen:** `background.pane`, `background.onboarding`.
- **Skill:** `hintergrund-job`.
<!-- modul:background:ende -->

<!-- modul:hotkeys:anfang -->
## hotkeys: Tastaturkurzbefehle

- **Zweck:** globale Tastaturkurzbefehle über Carbon `RegisterEventHotKey` (ohne Berechtigung für Eingabeüberwachung), änderbar durch die Nutzerin, ohne Neustart neu angemeldet. Regeln lehnen Kurzbefehle des Systems, Standardbefehle von Apps, Kombinationen, die auf der aktuellen Belegung ein Zeichen tippen, und Doppelungen ab; jede Ablehnung nennt den Grund in beiden Sprachen und schlägt eine freie Variante vor.
- **Dateien:** `KeyCombo` (Anzeige mit ⌃⌥⇧⌘ und Tastennamen der Belegung), `HotkeyCenter` (`register(id:title:default:action:)`), `ShortcutRules`, `ShortcutRecorder`.
- **Einstellungen:** Bereich „Tastaturkurzbefehle“; Änderungen der Nutzerin mit Präfix `hotkeys.`.
- **Einrichtung:** „Dein Tastaturkurzbefehl“ (order 600), nur wenn ein Kurzbefehl mit `showInOnboarding: true` angemeldet ist.
- **Szenen:** `hotkeys.pane`, `hotkeys.recorder-states`, `hotkeys.onboarding`.
- **Skill:** `kurzbefehl`.
<!-- modul:hotkeys:ende -->

<!-- modul:ai:anfang -->
## ai: lokale KI

- **Zweck:** Sprachmodell auf dem Mac über Apple Foundation Models: Antwort, Streaming, strukturierte Antworten, Abbruch, Verfügbarkeit mit Text für die Nutzerin. Einzelheiten in `docs/KI.md`.
- **Dateien:** `LocalAI`, `LocalModelProvider`, `AppleOnDeviceProvider`, Fehlertexte, Zähler der Aufrufe.
- **Einstellungen:** Bereich „Modelle“ mit Anbieter, Verfügbarkeit, Testfeld (Präfix `ai.`).
- **Einrichtung:** „Lokale KI“ (order 400).
- **Szenen:** `ai.pane` (verfügbar, nicht verfügbar), `ai.onboarding`, `ai.download-rows`.
- **Skill:** `ki-funktion`.
- **Entfernen:** zuerst `mlx`, falls vorhanden.
<!-- modul:ai:ende -->

<!-- modul:mlx:anfang -->
## mlx: Modelle über MLX

- **Zweck:** eigene Modelle über einen Python-Worker mit `mlx-lm`, Modellkatalog, Downloads mit Fortschritt. Aus im Starter.
- **Dateien:** `App/Sources/Modules/MLX/` (`MLXWorkerClient`, `MLXProvider`, `ModelDownloads`), `ai-worker/` (Worker, `requirements.txt`, `setup.sh`, `models.json`, `download.py`, `fake_worker.py`, Tests).
- **Einstellungen:** Download-Zeilen im Bereich „Modelle“ (Präfix `mlx.`).
- **Einrichtung:** Download-Zeilen im Schritt „Lokale KI“.
- **Einschalten:** `"mlx": true` in `starter.json`, `ai-worker/setup.sh` ausführen (Python 3.12 aus Homebrew oder uv, wird nicht automatisch installiert).
<!-- modul:mlx:ende -->

<!-- modul:examples:anfang -->
## examples: Beispiele

- **Zweck:** das Beispiel-Feature „Notizen“, gebaut, wie die Skills ein Feature bauen lassen: eigene Daten, Seiten im Hauptfenster, ein Abschnitt im Statusmenü, Rückmeldungen in der Insel, ein Kurzbefehl, lokale KI, eine Hintergrund-Aufgabe und ein Einstellungsbereich, jeder Bezug auf ein Modul in einem eigenen `#if MODUL_<NAME>`-Block (für zwei Module zwei Blöcke ineinander). Vorlage für das erste eigene Feature.
- **Dateien:** alles unter `App/Sources/Modules/Examples/`, Tests in `App/Tests/ExamplesTests.swift`.

  | Teil | Dateien | Inhalt |
  |---|---|---|
  | Daten | `NotesModel`, `NotesStore`, `NotesSeed` | eigene Datei `notes.sqlite` über `Database` mit zwei Migrationen, Volltextsuche (FTS5) mit Rückfall auf `LIKE`, Beispieldaten in der Sprache der Oberfläche; headless nur im Speicher |
  | Aktionen | `NotesActions` | Schnellnotiz aus der Zwischenablage, Kopieren, Öffnen (mit Fenster die Notizseite, sonst der Einstellungsbereich) |
  | Fenster | `NotesWindow`, `NotesDetail` | Übersicht (ersetzt die Startseite), Alle Notizen mit Suche, Papierkorb, eine Seite je Sammlung, Notizseite über der Liste (`NotesNavigator`) |
  | Statusmenü | `NotesMenuBar` | Abschnitt mit den drei zuletzt bearbeiteten Notizen |
  | Insel | `NotesIsland` | Sichern als Tätigkeit, dann Ergebniskarte; KI-Arbeit als Fortschritt mit Abbrechen |
  | Kurzbefehl | `NotesHotkeys` | ⌃⌥N, Schnellnotiz aus der Zwischenablage |
  | KI | `NotesAI`, `NotesAIViews` | Zusammenfassung (gestreamt) und Titelvorschlag (strukturiert), abbrechbar, mit Aus-Zustand |
  | Hintergrund | `NotesBackground` | „Papierkorb leeren“ täglich, angemeldet im Start-Hook |
  | Einstellungen | `NotesPane` | Bereich „Notizen“ (Gruppe Inhalt) mit Anzahl, Standardsammlung, Speicherort und „Beispieldaten neu laden“ |
  | Registrierung | `ExamplesModule`, `NotesScenes`, `NotesWindowScenes`, `NotesIslandScenes`, `NotesDemo`, `NotesText`, `NotesLook` | Bereich, Menüeintrag, Hooks, Selbsttests, Szenen, Demo, Texte und Maße |

- **Einstellungen:** `notes.defaultCollection` (Sammlung für neue Notizen und Schnellnotizen), `notes.layout` (Raster oder Liste auf Sammlungsseiten).
- **Einrichtung:** kein eigener Schritt. Drei Karten im Kit-Schritt „Funktionen“ über `OnboardingFeatures`: Schnellnotiz (mit `hotkeys`), Sammlungen (mit `window`), Lokale KI (mit `ai`), jeweils nur, wenn das Modul gebaut ist; der Kurzbefehl steht im Schritt „Dein Tastaturkurzbefehl“. Mit `island` sichert die Insel im Begrüßungsschritt eine Schnellnotiz.
- **Szenen:** `examples.*` für jede Seite und jeden Zustand (leer, Suche ohne Treffer, KI läuft, KI nicht verfügbar, Insel und Kapsel, Statusmenü, Bereich, Rückfrage).
- **Selbsttests:** `examples.store`, `examples.symbols`; `examples.ai.live` nur benannt (`--selftest examples.ai`), fragt das echte Modell.
- **Demo:** `--demo examples` legt Beispieldaten in den Speicher, öffnet das Fenster, sichert eine Schnellnotiz aus festem Text und fasst sie zusammen (nur für die Person am Mac).
- **Skills:** `neues-feature` mit allen Skills, die es nennt.
- **Entfernen:** `bin/starter strip-examples`, sobald das erste eigene Feature steht.
<!-- modul:examples:ende -->

## Kit (nicht entfernbar)

| Bereich | Ordner | Inhalt |
|---|---|---|
| Core | `Kit/Core/` | Sprache, Einstellungen, Datenbank, Registry, Render-Modus, Pfade, Protokoll |
| Design | `Kit/Design/` | Tokens, Komponenten, Muster (`docs/DESIGN.md`) |
| Texte | `Kit/Texts/` | gemeinsame Wörter (`CommonText`, `KitText`) |
| Einrichtung | `Kit/Onboarding/` | Fenster 720 x 560, Ablauf, Schritte Begrüßung (0, Bild über `Registry.welcomeArt` ersetzbar), Sprache (10), Funktionen (20), Berechtigungen (300 und folgende), Fertig (1000); Szenen `onboarding.*` mit Beispieldaten, `onboarding.project` mit jedem Schritt des Projekts |
| Berechtigungen | `Kit/Permissions/` | Arten, Status, Anfrage, Links in die Systemeinstellungen, Abfrage während jemand hinsieht, Neustart |
| Einstellungen | `Kit/Settings/` | Fenster 900 x 620 mit Seitenleiste (Gruppen Inhalt und Einstellungen), Bereiche „Allgemein“ (Sprache, Erscheinungsbild, Einrichtung erneut zeigen, zurücksetzen) und „Über“ |
| Galerie | `Kit/Gallery/` | jeder Baustein aus `Registry.gallery`, in Debug-Builds oder mit `kit.showGallery` |
| Render | `Kit/Render/` | `--render` für `make shots` |
| Main | `Kit/Main/` | Start, Flags, Aktivierungsrichtlinie, Fenster, Hauptmenü, Modulliste, Selbsttest |
