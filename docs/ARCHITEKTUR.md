# Architektur

Wie die App aufgebaut ist: ein Prozess, ein Kit, Module als Compiler-Flags, eine Registry als einzige Verbindung zwischen ihnen, und ein Build ohne Xcode. Gestaltung steht in `docs/DESIGN.md`, die Module einzeln in `docs/MODULE.md`.

## 1. Prozessmodell

Die App ist ein einziger AppKit-Prozess mit SwiftUI-Ansichten, gebaut aus allen Swift-Dateien in einem Aufruf von `swiftc`.

Einzige Ausnahme ist das Modul `mlx`: es startet einen Python-Worker (`docs/KI.md`). <!-- modul:mlx -->

Ablauf eines Starts:

1. `App/Sources/Kit/Main/Entry.swift` ist der Einstieg (`@main enum Entry`, nicht unter `TESTING`). `LaunchFlags.parse` liest die Kommandozeile.
2. Werkzeug-Flags laufen vor jedem Fenster, Menü und Statussymbol und beenden den Prozess:

   | Flag | Wirkung |
   |---|---|
   | `--render <ordner> [--only <präfix>] [--lang en\|de] [--appearance light\|dark]` | rendert jede `RenderScene` nach `<ordner>/<sprache>-<erscheinung>/<szene>.png`, bei einem vollständigen Lauf (ohne `--only`, `--lang`, `--appearance`) dazu `index.html` |
   | `--selftest [präfix]` | führt jede `SelfTestCheck` aus `Registry.selfTests` aus, außer den langsamen (`onDemand`); mit Präfix nur die passenden, langsame eingeschlossen. Exit 0 oder 1 |
   | `--permission-probe <id>` | schreibt den Stand einer Berechtigung, wie ihn ein frischer Prozess sieht, und endet (Kit/Permissions fragt so die Bildschirmaufnahme ab) |

   Unbekannte Flags mit `--` beenden mit Exit 2, damit ein vertipptes Werkzeug nie die App öffnet. Zwei Flags starten die App normal, aber anders:

   | Flag | Wirkung |
   |---|---|
   | `--demo` | ohne Einrichtung; jeder Eintrag aus `Registry.demoDrivers` läuft (für die Person am Mac) |
   | `--background` | ohne Einrichtung und ohne Hauptfenster (`Launch.isBackground`); ein Start als Anmeldeobjekt zählt ebenso |
3. Sonst startet `NSApplication` mit `AppDelegate`: `Modules.registerAll()` hat Kit und Module registriert, `AppForm.applyActivationPolicy()` setzt `.regular` (mit `window`) oder `.accessory`, `MainMenu.install()` legt das Hauptmenü an, alle `Registry.launchHooks` laufen.
4. Mit `STARTER_HEADLESS=1` endet der Start hier: Aktivierungsrichtlinie `.prohibited`, kein Fenster, keine Einrichtung. So laufen Tests und Werkzeuge auf Macs, auf denen nichts aufgehen soll.
5. Beim ersten Start öffnet die Einrichtung, später das Hauptfenster (mit `window`); mit `--background` und beim Start als Anmeldeobjekt keines von beiden. Menüleiste, Insel und Hintergrund laufen ohne Fenster weiter; die App endet nicht mit dem letzten Fenster.
6. Beim Beenden laufen alle `Registry.terminateHooks` (Worker beenden, Daten schreiben).

## 2. Kit, Module, Features

```
App/Sources/
  Kit/        immer dabei, gehört dem Starter
    Core/       Lang (tr, Localizer, Format), Settings, Database, Registry, RenderMode, Paths, Log, AppInfo, Version, Observing
    Design/     Theme und Tokens, Komponenten, Patterns (Muster für Einrichtung und Einstellungen), Seitenleiste (`Metrics.Sidebar`), Island-Tokens, Katalog
    Texts/      CommonText, KitText, DesignText
    Main/       Entry, CommandLine, AppDelegate, AppForm, AppActions, WindowHost, MainMenu, HeadlessWindows, Modules, SelfTest
    Onboarding/ Fenster, Ablauf, Kit-Schritte
    Settings/   Einstellungsfenster (Hub), Kit-Bereiche Allgemein und Über
    Permissions/ Arten, Status, Anfrage, Systemeinstellungen
    Gallery/    Galerie aller Bausteine
    Render/     RenderRunner
  Modules/    entfernbar, je Ordner ein Modul mit <Name>Module.register()
    Window/ MenuBar/ Island/ Background/ Hotkeys/ AI/ MLX/ Examples/
  Features/   Funktionen des Projekts, gehören dem Projekt
```

- **Kit** kennt kein Modul. Es stellt Bausteine und die Registry bereit und liest daraus, was Module und Features beitragen.
- **Module** nutzen nur das Kit, nie einander direkt. Was ein Modul von einem anderen braucht, steht in `#if MODUL_<NAME>` … `#endif`, damit `bin/starter remove` es ohne Reste entfernen kann (T-03): genau ein Flag je `#if`, ohne `||`, `&&`, `!` und `#elseif`. Ein `#else`-Zweig bleibt nach dem Entfernen stehen. Braucht Code zwei Module, stehen zwei einfache Blöcke ineinander (`#if MODUL_AI` außen, `#if MODUL_WINDOW` innen). `bin/starter remove` löst jeden Block für sich auf; `make check-kit` und `make check-design` melden jede andere Form.
- **Features** nutzen Kit und, in eigenen `#if`-Blöcken, Module. Jedes meldet sich mit einer Zeile in `Features.register()` an (`App/Sources/Features/Features.swift`); `Modules.registerAll()` ruft das nach dem Kit und allen Modulen auf.
- `App/Sources/Kit/Main/Modules.swift` ist die einzige Stelle, die Module aufzählt.

## 3. Registry

`App/Sources/Kit/Core/Registry.swift` ist die einzige Verbindung zwischen Kit, Modulen und Features. Jeder Beitrag wird beim Start einmal angehängt; Oberflächen lesen sortierte Listen (`orderedPages`, `orderedSettingsPanes`, `orderedOnboardingSteps`, `orderedMenuItems`, `orderedRenderScenes`, `orderedGallery`).

| Liste | Typ | wer liest |
|---|---|---|
| `pages` | `AppPage` (id, `PageSection`, order, Titel, Symbol, Inhalt) | Hauptfenster (Modul `window`) |
| `settingsPanes` | `SettingsPane` (id, `SettingsGroup` content oder settings, order, Titel, Symbol, Farbe, Inhalt) | Einstellungsfenster |
| `onboardingSteps` | `OnboardingStep` (id, order, `isIncluded`, Inhalt mit `OnboardingContext`) | Einrichtung |
| `menuItems` | `MenuItemContribution` (id, order, Titel, Symbol, Tastenkürzel, Aktion) | Hauptmenü, Statusmenü |
| `renderScenes` | `RenderScene` (id `<bereich>.<name>`, Größe, Inhalt) | `--render`, `make shots` |
| `gallery` | `GalleryEntry` (id, Bereich, Titel, Inhalt) | Galerie in den Einstellungen (Debug-Builds oder `kit.showGallery`) |
| `selfTests` | `SelfTestCheck` (id, Prüfung) | `--selftest` |
| `launchHooks`, `terminateHooks`, `demoDrivers` | Funktionen | Start, Ende, `--demo` |
| `welcomeArt` | `(() -> AnyView)?`, Bild 672 x 200 | Begrüßungsschritt der Einrichtung (ohne Eintrag: Akzentschein mit App-Symbol; mit Modul `island`: die echte Insel) |
| `onboardingFinishedHooks` | Funktionen mit `firstTime` | nach „Fertig“ in der Einrichtung (nicht beim Neustart für eine Berechtigung); das Fenster-Modul öffnet so das Hauptfenster, das Hintergrund-Modul wendet die Wahl „Beim Anmelden starten“ an |

`Registry.problems()` meldet doppelte Kennungen und Szenen ohne Bereichspräfix; ein Test prüft das.

**Fenster öffnen** geht nur über `AppActions` (`openSettings(pane:)`, `openOnboarding()`, `openMainWindow(page:)`, `showAbout()`, `quit()`). Kit und Module setzen beim Start die passenden Handler. Ohne Modul `window` fällt `openMainWindow()` auf die Einstellungen zurück; Aufrufer brauchen kein `#if`.

**Fenster** entstehen über `WindowHost.show(id:style:size:minSize:title:configure:content:)`: `NSWindow` mit `NSHostingController`, Titel folgt der Sprache, die Mindestgröße eines größenveränderlichen Fensters hält die SwiftUI-Wurzel (ein bloßes `window.minSize` setzt `NSHostingController` beim ersten Layout zurück), Views werden beim Schließen freigegeben, `AppForm` zählt offene Fenster und schaltet eine Accessory-App vorübergehend auf `.regular`, bis das letzte Kit-Fenster zu ist. `WindowHost.make(…)` baut ein Fenster, ohne es zu zeigen oder anzumelden; die Selbsttests `window.chrome` und `settings.window` prüfen damit Werkzeugleiste und Mindestgröße.

## 4. Sprache

`Localizer.shared` (`@Observable`) hält die Sprache: sie folgt den bevorzugten Sprachen des Macs, bis die Nutzerin eine wählt (`choice`, gespeichert unter `app.language`); `STARTER_LANG=en|de` erzwingt eine (`forced`, nie gespeichert). `tr(en:de:)` liest `Localizer.shared.lang`, deshalb zeichnet SwiftUI bei einem Wechsel neu. `Format` formatiert Zahlen, Dauer und Datum in der Sprache der Oberfläche. Die Nutzungsbeschreibungen der Berechtigungen erzeugt der Build aus `App/Resources/InfoPlist.json` als `<lang>.lproj/InfoPlist.strings`.

## 5. Einstellungen

`Settings.shared` (`@Observable`) liest und schreibt `~/Library/Application Support/<bundleId>/settings.json`: ein flaches JSON-Objekt mit Schlüsseln wie `island.style`. Jeder Schreibzugriff speichert sofort atomar und mischt nur die geänderten Schlüssel in den Dateistand; fremde Schlüssel bleiben. Kaputte Werte fallen auf den Standard des `SettingKey` zurück, eine unlesbare Datei wird beim nächsten Speichern beiseitegelegt. `STARTER_DATA_DIR` lenkt alle Daten für Tests und Renders in einen anderen Ordner.

## 6. Datenbank

`Database(url:migrations:)` öffnet eine SQLite-Datei (oder mit `url: nil` eine im Speicher) im WAL-Modus und spielt fehlende Migrationen in einer Transaktion ein; `PRAGMA user_version` hält die Nummer. Abfragen binden Werte als `SQLValue` und lesen Zeilen als `SQLRow` oder als eigenen Typ, der `RowDecodable` erfüllt. Ein Feature oder Modul führt seine eigene Datei (`Paths.database("<name>")`), damit das Entfernen eines Moduls keine fremden Tabellen berührt.

## 7. Render-Modus

`--render` setzt `RenderMode.isStatic` und die Umgebung `\.renderStatic`: Bewegung steht still, Scrollansichten zeichnen ihren ganzen Inhalt, `GlassSurface` zeichnet eine Fläche in Token-Farbe statt Glas, AppKit-Bedienelemente bekommen SwiftUI-Stellvertreter. `RenderRunner` zeichnet über `NSHostingView.cacheDisplay` in ein Bitmap mit Faktor 2 und Displayskala 2 (sonst verschwinden Haarlinien) und rechnet in sRGB um. Größe `.zero` bedeutet: so groß, wie die Ansicht sein will. Renders zeigen nie ein Fenster.

## 8. Build ohne Xcode

```
starter.json ──gen_config.py──> build/gen/AppConfig.swift, Info.plist, App.entitlements, Resources/<lang>.lproj, app.env
App/Sources/Kit/**, Features/**, Modules/<eingeschaltet>/** + AppConfig.swift ──swiftc (ein Aufruf)──> Binary
Binary + Info.plist + Resources ──> build/<Name>.app ──codesign──> fertig
```

- `scripts/pick-sdk.sh` wählt das neueste SDK, dessen Swift-Version der Compiler lesen kann; `SDKROOT` wird exportiert, damit auch der Linker es nutzt.
- Flags: `-swift-version 6 -default-isolation MainActor`, `-target arm64-apple-macosx<minimumMacOS>`, `-parse-as-library`, je Modul `-D MODUL_<NAME>`, Frameworks AppKit, SwiftUI, ServiceManagement, Carbon, sqlite3, mit `ai` FoundationModels; Debug `-Onone -g`, Release `-O -wmo`.
- `Info.plist` wird zusätzlich ins Binary eingebettet (`-sectcreate __TEXT __info_plist`).
- Gebaut wird in einen temporären Ordner, danach ersetzt das neue Bundle das alte.
- `make test` baut dieselben Quellen mit `App/Tests/**` und `-D TESTING` zu `build/tests/run-tests` und führt es mit `STARTER_HEADLESS=1` aus; danach laufen die Python-Tests in `scripts/tests/` und `scripts/starter/tests/`.
- Mit dem Modul `mlx` laufen in `make test` auch die Python-Tests in `ai-worker/tests/`. <!-- modul:mlx -->

## 9. Package.swift

`Package.swift` ist der zweite Weg für Xcode oder ein intaktes SwiftPM: dieselben Quellen, dieselben Modul-Flags aus `starter.json`, `build/gen/AppConfig.swift` vorher mit `python3 scripts/gen_config.py` erzeugen. Tests laufen nur über `make test`. Weil SwiftPM auf Macs mit gemischten Command Line Tools abstürzt, wurde das Manifest beim Bau des Starters einmal typgeprüft; eine laufende Prüfung dieses Wegs gibt es nicht. `make doctor` sagt, ob SwiftPM auf dem eigenen Mac läuft.

## 10. Tests

- Swift: `App/Tests/Harness/Harness.swift` stellt `TestSuite` mit `test("…") { … }`, `expect`, `expectEqual`, `expectThrows`, `fail`, `tempDir()` und `repoRoot` bereit; Testklassen werden über die ObjC-Laufzeit gefunden. `make test ONLY=<präfix>` wählt aus.
- Python: `unittest` in `scripts/tests/` (Werkzeuge, Hooks, Workflow) und `scripts/starter/tests/` (`bin/starter`, check-kit); `make probe` führt die langsame Template-Probe aus `scripts/starter/tests/probe_starter.py` aus.
- Python im Modul `mlx`: `unittest` in `ai-worker/tests/` (Worker). <!-- modul:mlx -->
- Selbsttest: `--selftest` prüft zur Laufzeit, was nur im fertigen Bundle prüfbar ist (Symbol vorhanden, Konfiguration passt, Registry ohne Doppelungen, Module melden ihre Prüfungen an).
