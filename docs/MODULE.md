# Module

Jedes Modul ist ein Ordner unter `App/Sources/Modules/<Name>/` mit `<Name>Module.register()`, eingeschaltet in `starter.json` (`modules`) und als Compiler-Flag `MODUL_<NAME>` gebaut. Ein Modul nutzt nur das Kit und meldet alles über die Registry an: Seiten, Einstellungsbereiche, Onboarding-Schritte, Menüeinträge, Galerie-Einträge, Render-Szenen, Selbsttests. Einstellungsschlüssel tragen das Präfix des Moduls.

| Modul | Form oder Aufgabe | Standard | braucht | Entfernen |
|---|---|---|---|---|
| `window` | Fenster-App mit Seitenleiste im Stil von Apple Music | an | | `bin/starter remove window` | <!-- modul:window -->
| `menubar` | Menüleisten-App mit Statussymbol und Panel | an | | `bin/starter remove menubar` | <!-- modul:menubar -->
| `island` | Insel an der Notch, Kapsel ohne Notch | an | | `bin/starter remove island` | <!-- modul:island -->
| `background` | geplante Aufgaben, Start beim Anmelden | an | | `bin/starter remove background` | <!-- modul:background -->
| `hotkeys` | globale Kurzbefehle | an | | `bin/starter remove hotkeys` | <!-- modul:hotkeys -->
| `ai` | lokale KI mit Apple Foundation Models | an | | `bin/starter remove ai` (nach `mlx`) | <!-- modul:ai -->
| `mlx` | eigene Modelle über einen MLX-Worker in Python | aus | `ai` | `bin/starter remove mlx` | <!-- modul:mlx -->
| `examples` | Beispiel-Feature, das alle Module nutzt | an | | `bin/starter strip-examples` | <!-- modul:examples -->

Mindestens `window` oder `menubar` bleibt; ohne beide sind die Einstellungen nicht erreichbar, und `bin/starter remove` lehnt das ab. Mit `window` hat die App ein Dock-Symbol (`.regular`), ohne `window` lebt sie nur in der Menüleiste (`.accessory`, `LSUIElement`).

`bin/starter remove <modul>` löscht den Ordner des Moduls und alles, was `starter.manifest.json` ihm zuordnet (Tests, Skills, Werkzeuge), entfernt jeden `#if MODUL_<NAME>` … `#endif`-Block in allen Swift-Dateien (bei `#else` bleibt dieser Teil), Zeilen mit `<!-- modul:<name> -->` und Abschnitte zwischen `<!-- modul:<name>:anfang -->` und `<!-- modul:<name>:ende -->` in Markdown (in YAML, Shell und Python `# modul:<name>`) und das Modul aus `starter.json`; danach baut es (`--ohne-build` lässt das aus, `--probelauf` zeigt nur, was passieren würde). Ein Commit je entferntem Modul.

`make build MODULES=a,b` baut eine andere Auswahl, ohne `starter.json` zu ändern.

<!-- modul:window:anfang -->
## window: Fenster-App

- **Zweck:** Hauptfenster im Stil von Apple Music unter macOS 26: `NavigationSplitView` mit Seitenleiste aus Systemglas, Werkzeugleiste mit Suche, Seiten aus Bausteinen (großer Titel, Kopf mit Bild, Reihen von Kacheln, Raster, Listen, Detailseite). ⌘, öffnet die Einstellungen.
- **Dateien:** `MainWindowController` (Fenster 1180 x 760, mindestens 900 x 600, Rahmen gespeichert, Dock-Klick öffnet wieder), `MainWindowView` (Seitenleiste aus `Registry.pages` nach `PageSection`, Auswahl gespeichert, Fußzeile der Seitenleiste über `WindowSidebarFooter.add(id:order:content:)`, Suchfeld in der Werkzeugleiste nur für Seiten mit `WindowSearch.enable(page:prompt:)`, der Suchtext kommt als `\.windowSearch` an), `WindowMainMenu` (ergänzt das Menü des Kits um Ablage, Suchen, Darstellung, ⌘0 im Fenster-Menü und Hilfe), `Components/` (`PageScaffold`, `HeroHeader`, `Shelf`, `Tile`, `TileGrid`, `ItemList`, `DetailHeader`, `Artwork`, `EmptyPage`, `NoResults`), `HomePage` als Startseite eines frischen Projekts.
- **Einstellungen:** gewählte Seite und ausgeblendete Seitenleiste (Präfix `window.`; ein Zustand, „Einstellungen zurücksetzen“ behält sie).
- **Onboarding:** keiner.
- **Szenen:** `window.main` (ganzes Fenster), `window.home`, je Baustein eine Szene.
- **Skill:** `neue-ansicht`.
- **Öffnen:** `AppActions.openMainWindow()` holt das Fenster nach vorn, `AppActions.openMainWindow(page:)` wählt vorher eine Seite.
- **Ohne das Modul:** `AppActions.openMainWindow()` öffnet die Einstellungen (eine Seite wird ignoriert); die App läuft als Menüleisten-App.
<!-- modul:window:ende -->

<!-- modul:menubar:anfang -->
## menubar: Menüleisten-App

- **Zweck:** Statussymbol aus `app.symbol` mit den Zuständen `idle`, `busy` (dezente Bewegung, ruht bei reduzierter Bewegung) und `attention` (Punkt). Klick öffnet ein Panel im Stil der Module im Kontrollzentrum (abgerundet, Glas, 340 pt breit) mit Kopf, Abschnitten und Fußzeile; Rechtsklick oder ⌥-Klick öffnet ein Menü aus `Registry.menuItems`.
- **Dateien:** `MenuBarController`, `MenuBarStatus.shared.state`, `MenuBarPanel.sections` (Abschnitte mit Kennung, Reihenfolge und View).
- **Einstellungen:** Bereich „Menüleiste“ mit Statustext und Stil des Symbols (Präfix `menubar.`).
- **Onboarding:** keiner.
- **Szenen:** `menubar.panel`, `menubar.icon-states`.
- **Skill:** `menueleisten-app`.
<!-- modul:menubar:ende -->

<!-- modul:island:anfang -->
## island: Insel und Kapsel

- **Zweck:** Rückmeldung, die aus der Notch wächst (Insel), auf Macs ohne Notch eine Kapsel unter der Menüleiste. Zustände: Tätigkeit, Fortschritt (Sekundenzähler ab 5 s, Hinweis mit Abbruch ab 10 s), Pegel (mit `recording: true` roter Aufnahmepunkt, in der Kapsel mit Laufzeit), Ergebniskarte mit Aufklappen beim Überfahren und Kopieren, Hinweis (Info, Erfolg, Warnung, Fehler, verschwindet nach 2,5 s). Mehrere Bildschirme, Selbstheilung nach Bildschirmwechseln, Töne standardmäßig aus, reduzierte Bewegung blendet über.
- **Dateien:** `IslandScreenGeometry` (Notch je Bildschirm, Höhe der Menüleiste), `IslandPanel` (randloses, nicht aktivierendes Panel, durchklickbar, im Leerlauf ausgeblendet), `NotchShape`, `IslandView`, `CapsuleView`, `IslandContent`, `Island.shared` mit `present(_:)`, `update(_:)`, `dismiss()`, `isPresenting` und `notchBusy` (vom Projekt gesetzt: belegt eine andere App die Notch, erscheint `auto` als Kapsel unter der Notch).
- **Einstellungen:** Bereich „Insel und Kapsel“ mit Darstellung (`island.style`: `auto`, `capsule`, dazu `island` nur, wenn `Island.shared.notchBusy` gesetzt ist; mit Vorschau), Dauer der Bestätigung, „Beim Überfahren ausklappen“, Töne, Trackpad-Rückmeldung, „Im Vollbild ausblenden“ und „Vorschau zeigen“.
- **Onboarding:** „Insel und Kapsel“ (order 500, nur auf Macs mit Notch), Kachelwahl Insel oder Kapsel mit den echten Ansichten.
- **Szenen:** jeder Zustand als `island.<zustand>` und `capsule.<zustand>`, dazu `island.pane`, `island.onboarding`.
- **Skill:** `insel-zustand`. `--demo` durchläuft alle Zustände in der laufenden App (nur für die Person am Mac).
<!-- modul:island:ende -->

<!-- modul:background:anfang -->
## background: Hintergrund

- **Zweck:** geplante Aufgaben über `NSBackgroundActivityScheduler` mit Intervall, Toleranz und Dienstgüte; letzter Lauf, Ergebnis und Dauer werden gespeichert; Schalter und „Jetzt ausführen“ je Aufgabe. Start beim Anmelden über `SMAppService.mainApp`, nur aus einem installierten Ort.
- **Dateien:** `BackgroundJobs` (`register(id:title:interval:tolerance:qos:exact:run:)`, `runNow(_:)`), `LoginItem` (`isAvailable` mit Begründung).
- **Einstellungen:** Bereich „Hintergrund“ mit Anmeldeobjekt und Liste der Aufgaben (Präfix `background.`).
- **Onboarding:** „Mit dem Mac starten“ (order 900), nur wenn `LoginItem.isAvailable`; die Wahl gilt erst nach „Fertig“ (`Registry.onboardingFinishedHooks`).
- **Szenen:** `background.pane`, `background.onboarding`.
- **Skill:** `hintergrund-job`.
<!-- modul:background:ende -->

<!-- modul:hotkeys:anfang -->
## hotkeys: Kurzbefehle

- **Zweck:** globale Kurzbefehle über Carbon `RegisterEventHotKey` (ohne Berechtigung für Eingabeüberwachung), änderbar durch die Nutzerin, ohne Neustart neu angemeldet. Regeln lehnen Kurzbefehle des Systems, Standardbefehle von Apps, Kombinationen, die auf der aktuellen Belegung ein Zeichen tippen, und Doppelungen ab; jede Ablehnung nennt den Grund in beiden Sprachen und schlägt eine freie Variante vor.
- **Dateien:** `KeyCombo` (Anzeige mit ⌃⌥⇧⌘ und Tastennamen der Belegung), `HotkeyCenter` (`register(id:title:default:action:)`), `ShortcutRules`, `ShortcutRecorder`.
- **Einstellungen:** Bereich „Kurzbefehle“; Änderungen der Nutzerin mit Präfix `hotkeys.`.
- **Onboarding:** „Dein Kurzbefehl“ (order 600), nur wenn ein Kurzbefehl mit `showInOnboarding: true` angemeldet ist.
- **Szenen:** `hotkeys.pane`, `hotkeys.recorder-states`, `hotkeys.onboarding`.
- **Skill:** `kurzbefehl`.
<!-- modul:hotkeys:ende -->

<!-- modul:ai:anfang -->
## ai: lokale KI

- **Zweck:** Sprachmodell auf dem Mac über Apple Foundation Models: Antwort, Streaming, strukturierte Antworten, Abbruch, Verfügbarkeit mit Text für die Nutzerin. Einzelheiten in `docs/KI.md`.
- **Dateien:** `LocalAI`, `LocalModelProvider`, `AppleOnDeviceProvider`, Fehlertexte, Zähler der Aufrufe.
- **Einstellungen:** Bereich „Modelle“ mit Anbieter, Verfügbarkeit, Testfeld (Präfix `ai.`).
- **Onboarding:** „Lokale KI“ (order 400).
- **Szenen:** `ai.pane` (verfügbar, nicht verfügbar), `ai.onboarding`, `ai.download-rows`.
- **Skill:** `ki-funktion`.
- **Entfernen:** zuerst `mlx`, falls vorhanden.
<!-- modul:ai:ende -->

<!-- modul:mlx:anfang -->
## mlx: Modelle über MLX

- **Zweck:** eigene Modelle über einen Python-Worker mit `mlx-lm`, Modellkatalog, Downloads mit Fortschritt. Aus im Starter.
- **Dateien:** `App/Sources/Modules/MLX/` (`MLXWorkerClient`, `MLXProvider`, `ModelDownloads`), `ai-worker/` (Worker, `requirements.txt`, `setup.sh`, `models.json`, `download.py`, `fake_worker.py`, Tests).
- **Einstellungen:** Download-Zeilen im Bereich „Modelle“ (Präfix `mlx.`).
- **Onboarding:** Download-Zeilen im Schritt „Lokale KI“.
- **Einschalten:** `"mlx": true` in `starter.json`, `ai-worker/setup.sh` ausführen (Python 3.12 aus Homebrew oder uv, wird nicht automatisch installiert).
<!-- modul:mlx:ende -->

<!-- modul:examples:anfang -->
## examples: Beispiele

- **Zweck:** ein vollständiges Beispiel-Feature, das Seite, Einstellung, Onboarding-Schritt, Insel, Statusmenü, Hintergrund-Aufgabe, Kurzbefehl und KI nutzt, jeweils in eigenen `#if`-Blöcken, mit Texten, Speicher, Szenen und Tests. Vorlage für das erste eigene Feature.
- **Entfernen:** `bin/starter strip-examples`, sobald das erste eigene Feature steht.
<!-- modul:examples:ende -->

## Kit (nicht entfernbar)

| Bereich | Ordner | Inhalt |
|---|---|---|
| Core | `Kit/Core/` | Sprache, Einstellungen, Datenbank, Registry, Render-Modus, Pfade, Protokoll |
| Design | `Kit/Design/` | Tokens, Komponenten, Muster (`docs/DESIGN.md`) |
| Texte | `Kit/Texts/` | gemeinsame Wörter (`CommonText`, `KitText`) |
| Onboarding | `Kit/Onboarding/` | Fenster 720 x 560, Ablauf, Schritte Begrüßung (0), Sprache (10), Funktionen (20), Berechtigungen (300 und folgende), Fertig (1000) |
| Berechtigungen | `Kit/Permissions/` | Arten, Status, Anfrage, Links in die Systemeinstellungen, Abfrage während jemand hinsieht, Neustart |
| Einstellungen | `Kit/Settings/` | Fenster 900 x 620 mit Seitenleiste (Gruppen Inhalt und Einstellungen), Bereiche „Allgemein“ (Sprache, Erscheinungsbild, Einrichtung erneut zeigen, zurücksetzen) und „Über“ |
| Galerie | `Kit/Gallery/` | jeder Baustein aus `Registry.gallery`, in Debug-Builds oder mit `kit.showGallery` |
| Render | `Kit/Render/` | `--render` für `make shots` |
| Main | `Kit/Main/` | Start, Flags, Aktivierungsrichtlinie, Fenster, Hauptmenü, Modulliste, Selbsttest |
