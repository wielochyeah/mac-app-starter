# Status B (Menüleiste + Hintergrund)

Stand: 2026-10-12, Branch `strang/B` (von `main` 68281d5), nach dem Review überarbeitet (Abschnitt „Review“ am Ende). Gebaut sind die Module `menubar` und `background` nach STRANDS.md Abschnitt B, nur gegen Kit-APIs (keine Typen anderer Stränge).

## Was gebaut ist

### Modul `menubar` (`App/Sources/Modules/MenuBar/`)

| Datei | Inhalt |
|---|---|
| `MenuBarStatus.swift` | `MenuBarState` (idle, busy, attention), `MenuBarStatus.shared` (`@Observable`: `state`, `message` (Statuszeile im Feld), `shortTitle` (ein, zwei Wörter neben dem Symbol), `line`; `idle` löscht beide), `MenuBarIconStyle` (plain, marks, color), SettingKeys `menubar.iconStyle`, `menubar.statusText`, `menubar.visible`, reine Regeln `MenuBarPrefs` (Titel neben dem Symbol: `shortTitle` oder Name des Zustands, höchstens 14 Zeichen) |
| `MenuBarIcon.swift` | Symbol aus `app.symbol` als Template-Bild; gezeichnete Zustände: drehender Ring unten rechts (busy, 12 Schritte je Umdrehung, Spur 30 %, ausgestanzt), roter Punkt oben rechts (attention, ausgestanzt), Akzent-Textfarbe `accentText` (Stil color, ≥ 3:1 auf der Menüleiste), Punkt in `strike` (dasselbe Rot wie im Feld). Farbige Glyphen bekommen die Deckkraft der Tinte genau einmal (Palette-Symbole wendeten sie doppelt an). Jede Zeichnung hat Größe und `alignmentRect` des Symbols, Marken liegen auf dem Halbpunkt-Raster |
| `MenuBarController.swift` | `NSStatusItem` (quadratisch, mit Statustext variabel), Linksklick öffnet das Feld, Rechts-/⌃-/⌥-Klick das Menü; Bild, Text und Tooltip folgen Status, Einstellungen und Sprache live (`Observing.track`); Erscheinungsbild per KVO; Timer nur bei busy im Stil marks, nie bei „Bewegung reduzieren“ (Änderung wird beobachtet); Menü wird bei jedem Öffnen neu gebaut (`MenuBarMenu.entries`) |
| `MenuBarPanel.swift` | Registry `MenuBarPanel.sections` (`MenuBarSection(id:order:title:tiled:content:)`, Inhalt bekommt `MenuBarPanelContext.close`), Platzierung `MenuBarPanelPlacement` (zentriert unter dem Symbol, im sichtbaren Bildschirm gehalten, oben fest bei Höhenänderung), `MenuBarPanelController` (randloses, nicht aktivierendes `NSPanel`, Größe wird gemessen, bevor die Größensteuerung des Hosting-Views abgeschaltet wird (`host(_:)`, Breite mindestens 340), Ebene popUpMenu, Einblenden 0,12 s, schließt bei Klick daneben, Esc, Fokusverlust, zweitem Klick aufs Symbol; baut den SwiftUI-Baum beim Öffnen und gibt ihn beim Schließen frei, danach `malloc_zone_pressure_relief`) |
| `MenuBarPanelView.swift` | Feld im Stil des Kontrollzentrums von macOS 26: 340 pt, `GlassSurface` Radius 26, Kopf bündig mit den Kacheln (App-Symbol, Name, Statuszeile; Punkt bzw. Spinner links bündig mit dem Namen), Abschnitte als Kacheln, `Registry.menuItems` als „Aktionen“, Fußzeile Einstellungen / Fenster öffnen (nur mit Modul window) / Beenden, immer mit Namen (passt es nicht, fallen bei allen Chips die Symbole weg). Bausteine: `MenuBarTile`, `MenuBarActionRow`, `MenuBarToggle`, `MenuBarStatusLine` |
| `MenuBarPane.swift` | Einstellungsbereich „Menüleiste“ (id `menubar`, Gruppe settings, order 300): Gruppe „Symbol“ mit dem Stil als `TilePicker` (echte Symbole auf Menüleiste über Hintergrundbild) und der Fußnote zum Stil direkt darunter; Gruppe „Anzeige“ mit „Status neben dem Symbol“ und „In der Menüleiste zeigen“ (nur mit Modul window, sonst bleibt das Symbol immer sichtbar) |
| `MenuBarScenes.swift` | Szenen und Galerie mit festen Beispieldaten |
| `MenuBarModule.swift` | `register()`: Bereich, Start-/Ende-Hooks, Selbsttest `menubar.icon`, Szenen; Hilfen `bitmap`, `inkedPixels`, `alpha` |
| `MenuBarText.swift` | `MenuBarText`, `MenuBarSampleText` |

Öffentliche API: `MenuBarStatus.shared.state/.message`, `MenuBarPanel.sections.append(…)`, `Registry.menuItems` (erscheinen im Feld und im Menü), `MenuBarController.openPanel()`.

### Modul `background` (`App/Sources/Modules/Background/`)

| Datei | Inhalt |
|---|---|
| `BackgroundJobs.swift` | `JobOutcome` (done(note:), nothingToDo, failed), `JobRecord`, reine Buchführung `JobBook` (mit `firstDelay`: überfällige oder nie gelaufene Jobs laufen 10 s nach dem Start, sonst nach dem Rest des Intervalls), `JobSchedule` (`defaultTolerance`), `BackgroundJobs.shared` (`@Observable`): `register(id:title:interval:tolerance:qos:exact:run:)` (Toleranz Standard ¼ Intervall, bei `exact` höchstens 1 s; doppelte id wird ignoriert und geloggt), `start()`/`stop()`, `setEnabled`/`isEnabled` (persistiert `background.disabledJobs`), `runNow`, `perform(_:) async` (nie überlappend, Fehler werden mit `LocalizedError`-Text erfasst), `record`, `isRunning` |
| `JobStore.swift` | `JobStore`-Protokoll, `DatabaseJobStore` (Kit-`Database`, `background.sqlite`, Migration 1 `job_state`, Upsert; Datei entsteht erst beim ersten Laden, also erst mit einem Job), `MemoryJobStore` |
| `JobScheduling.swift` | `JobScheduling.schedule(_:after:fire:)`; `SystemJobScheduler` (`NSBackgroundActivityScheduler` mit `shouldDefer` → `.deferred`, `completion(.finished)` erst nach dem Lauf; ein Nachholen vor Ablauf eines Intervalls ist ein einmaliger Timer, danach übernimmt macOS; `exact: true` → `Timer(fire:interval:)` im Modus `.common`; Generationszähler gegen alte Nachhol-Läufe), `NoJobScheduler` |
| `LoginItem.swift` | `LoginItem` über `SMAppService.mainApp`: `availability(bundlePath:isBundle:home:)` (nur /Applications oder ~/Applications; Gründe notBundle, diskImage, translocated, notInstalled), `map(SMAppService.Status)`, `needsChange` (macOS wird nur bei echter Änderung gerufen, in beide Richtungen), `setEnabled`, `openSystemSettings`; `LoginItemModel` (live oder feste Werte für Renders, auch mit Fehlertext); `LoginItemStepRule`; `LoginWish` (Wahl der Ersteinrichtung, angewendet erst wenn `onboardingDone` wahr ist); `launchedAtLogin` / `isLoginLaunch` (Start als Anmeldeobjekt aus dem Apple Event beim Start) |
| `BackgroundPane.swift` | Bereich „Hintergrund“ (id `background`, order 310): Schalter „Beim Anmelden starten“ (gesperrt mit Begründung als Fußnote, wenn nicht verfügbar), Hinweis bei `requiresApproval` mit „Systemeinstellungen öffnen“, Fehlerhinweis, `JobList` als Gruppe „Aufgaben“ (Gruppenlabel wie „Start“) mit `JobRow` (Titel, Intervall + letzter Lauf relativ, minütlich aktualisiert, Fehlermeldung in `warnText`, Ergebnis-Badge (grau, wenn ausgeschaltet) oder Spinner „Läuft“, „Jetzt ausführen“ beim Hover, im Kontextmenü und als VoiceOver-Aktion, Schalter); leerer Zustand „Keine Aufgaben“ in der Karte |
| `LoginItemStep.swift` | Onboarding-Schritt `background.login` (order 900, nur wenn `LoginItem.isAvailable`): „Mit dem Mac starten“. Ersteinrichtung: Schalter an (VoiceBud), die Wahl wird nur als Wunsch gespeichert (`background.loginItemWish`) und erst angewendet, wenn das Onboarding fertig ist; Zurück, Fenster schließen oder Beenden mittendrin registrieren nichts. Später erneut gezeigt: der Schalter wirkt sofort wie im Bereich. Bei `requiresApproval` ersetzt der Hinweis (Kartenbreite) die Fußnote |
| `BackgroundScenes.swift` | Szenen und Galerie mit festen Beispieljobs und fester Uhr |
| `BackgroundModule.swift` | `register()`: Bereich, Schritt, Start-Hook (liest `LoginItem.launchedAtLogin`; nur im echten Programm, nie headless/Render: `LoginWish.watch()` und Jobs planen), Ende-Hook, Selbsttest `background.jobs` |
| `BackgroundText.swift` | `BackgroundText` (Intervalle „Alle 15 Minuten“, „Stündlich“, „Täglich“, „Wöchentlich“; „vor 4 Minuten“, „gerade eben“), `BackgroundSampleText` |

Ein Beispieljob wird nicht ausgeliefert (kommt mit examples in der Integration).

### Szenen (`make shots ONLY=menubar.` / `ONLY=background.`)

`menubar.icon-states` (alle 3 Stile × 3 Zustände vierfach vergrößert auf Menüleisten-Stücken, dazu Originalgröße), `menubar.status-text` (Text neben dem Symbol: Zustandsnamen, Kurztitel, gekürzter langer Titel), `menubar.panel` (Feld mit Beispielabschnitten unter der Menüleiste), `menubar.panel-busy` (Statuszeile mit Spinner und Meldung), `menubar.panel-empty` (ohne Beiträge, Zustand attention), `menubar.panel-nowindow` und `menubar.pane-nowindow` (ohne Modul window), `menubar.pane`, `background.pane` (fünf Jobs: erledigt mit Notiz, Hover mit „Jetzt ausführen“, läuft, fehlgeschlagen, ausgeschaltet), `background.pane-unavailable` (Build-Ordner, keine Jobs), `background.pane-approval` (Freigabe nötig, Fehler beim Ändern, Job noch nie gelaufen), `background.onboarding`, `background.onboarding-approval`. Galerie: `menubar.icon`, `menubar.panel`, `menubar.toggle`, `background.jobs`.

## Entscheidungen

- **Feld als `NSPanel`, nicht `NSPopover`**: kein Pfeil, Ecken und Glas wie die Module des Kontrollzentrums; nicht aktivierend, damit die vordere App vorne bleibt. Liegt das Symbol nah am rechten Rand, hält die Platzierung das Feld 8 pt im Bildschirm (wie die Szene zeigt).
- **Zustandszeichen statt Animation des ganzen Symbols**: ein kleiner drehender Ring ist der einzige bewegte Teil; Stil „Schlicht“ ändert nie etwas, „Farbe“ färbt nur. Busy-Ring bleibt ein Template-Bild (macOS färbt hell/dunkel und gedrückt selbst); Punkt und Farbe brauchen gezeichnete Farben, deren Tinte aus dem Erscheinungsbild der echten Menüleiste kommt (VoiceBud).
- **Roter Punkt, kein oranger**: Orange ist in der Menüleiste die Mikrofon-Anzeige von macOS. Symbol und Statuszeile im Feld nutzen beide `t.strike` (nach dem Review auch das Symbol; vorher `systemRed`).
- **„In der Menüleiste zeigen“ nur mit Modul window**: ohne Hauptfenster wäre die App sonst unerreichbar (`MenuBarPrefs.isVisible`).
- **Menüpunkt „Fenster öffnen“** hängt an `AppInfo.isEnabled("window")` (Zeichenkette, kein Typ eines anderen Moduls) und ruft `AppActions.openMainWindow()`; gleicher Name im Feld und im Menü. Beenden heißt im Feld kurz „Beenden“, im Menü nach macOS-Brauch „Starter beenden“ (`CommonText.quitApp`).
- **Job-Datensätze in SQLite** (Kit-`Database`), Schalter in den Settings (`background.disabledJobs`), weil sie eine Wahl der Person sind und zur Einstellungsdatei gehören.
- **`BackgroundJobs` mit eingespeisten Teilen** (Store, Scheduler, Settings oder `nil`, Uhr, laufende Ids): Tests ohne echten Scheduler und ohne Warten, Renders ohne Dateien.
- **Login-Item-Schritt wendet erst nach dem Onboarding an** (`LoginWish`): der Schritt speichert in der Ersteinrichtung nur den Wunsch; ein Start-Hook beobachtet `onboardingDone` und wendet ihn an, sobald es wahr wird (oder beim nächsten Start). Ändert nur, was sich von macOS unterscheidet; merkt sich `background.loginItemAsked`. Ein Kit-Hook „Onboarding fertig“ würde die Beobachtung ersetzen.
- Reihenfolge der Bereiche: Menüleiste 300, Hintergrund 310 (Kit: Allgemein 0, Über 1000).

## Aus VoiceBud übernommen (für THIRD_PARTY_NOTICES, MIT, Copyright (c) 2026 Anas Riad)

- `ui/MenuBarIcon.swift`: Template-Symbol im Ruhezustand, Zeichnen mit `NSImage(size:flipped:drawingHandler:)`, Punkt oben rechts in den Grenzen des Symbols (5 pt), `alignmentRect` des Symbols übernommen, quadratisches vs. variables Element, Erscheinungsbild per KVO und `performAsCurrentDrawingAppearance`, Timer im Modus `.common` nur wenn nötig.
- `ui/main.swift` `buildMenu`/`menuNeedsUpdate`: Menütitel bei jedem Öffnen neu (Sprachwechsel), „Einrichtung …“ im Menü.
- Speicherfreigabe beim Schließen (`malloc_zone_pressure_relief` nach 0,5 s) aus dem Hub.
- Login-Item-Verhalten aus `onboarding.py`: nur die installierte App, Schalter beim ersten Einrichten an, Änderung in beide Richtungen nur bei Unterschied.

## Kandidaten für Kit/Design

`MenuBarIconMetrics` (Punkt 5, Ring 7/1,5, Ausstanzung 1, Bildrate 12/s), `MenuBarPanelMetrics` (Breite 340, App-Symbol 32, Kreis 28, Zeilensymbol 13/18, Spinner 12, Ein-/Ausblenden 0,12/0,16 s; `Motion` kennt nur SwiftUI-Animationen, für AppKit fehlen Sekunden-Token wie `Motion.panelFadeIn/Out`), `BackgroundMetrics.stepCard` (460 = `onboardingNarrow + 60`, hat im Kit noch kein Token; S0b nutzt dieselbe Summe), die Bausteine `MenuBarTile`, `MenuBarToggle` (Kontrollzentrum-Schalter), `MenuBarStatusLine`, `JobRow`.

Für das Kit (Besitzer S0b/E), aus dem Review: `ToggleRow`/`Row` dimmt Titel und Untertitel nicht, wenn die Zeile gesperrt ist (nur der Schalter wird blass; sichtbar in `background.pane-unavailable`). `Theme.strike` als Text (`Row.subtitleColor`) hat auf hellen Karten bei 11,5 pt nur ~4,2:1; ein textfähiges Rot fehlt (Hintergrund nutzt jetzt `warnText`). Ein Hook „Onboarding fertig“ (`Registry`) für Schritte, die eine Wahl erst am Ende anwenden.

## Außerhalb meines Strangs angefasst

Nichts. Nur `App/Sources/Modules/MenuBar/**`, `App/Sources/Modules/Background/**`, `App/Tests/MenuBarTests.swift`, `App/Tests/BackgroundTests.swift` und dieser Bericht. Die Testdateien stehen in `#if TESTING` → `#if MODUL_MENUBAR` bzw. `#if MODUL_BACKGROUND` (zwei einfache Blöcke ineinander), damit `make test` mit jeder Modulauswahl baut und `bin/starter remove` sie leeren kann.

## Hinweise für die Integration und andere Stränge

- **Strang G (Prüfskripte)**: Mit einer Kopie der noch nicht eingecheckten Skripte aus `wt/G1` (`check_design.py`, `check_texts.py`, `rules/`) sind beide Module ohne Befund (`--streng`). Drei bewusste `// design-ausnahme:` stehen im Code: `NSColor.labelColor` für die Tinte der echten Menüleiste (zwei Zeilen in `MenuBarController.inks`), `NSColor.black` als Template-Farbe in `MenuBarIcon.ringed` (zwei Zeilen), `+ 60` in `BackgroundMetrics.stepCard`. `SMAppService` steht nur in `Modules/Background` (Regel `anmeldeobjekt` erlaubt das).
- **Strang A (Fenster)**: STRANDS A spricht von einem Start als Anmeldeobjekt mit `--background`. `SMAppService.mainApp` startet die App ohne Argumente, und `LaunchFlags` kennt `--background` nicht. Stattdessen gibt es jetzt `LoginItem.launchedAtLogin` (Eigenschaft `keyAELaunchedAsLogInItem` des Start-Apple-Events, beim ersten Lesen festgehalten). Der Start-Hook des Fenstermoduls (und das Onboarding) sollte es in wave 2 lesen und beim Login-Start nichts öffnen. Gilt nur mit Modul background; ob macOS die Eigenschaft auch für `SMAppService.mainApp` setzt, ist ungeprüft.
- **Strang D (Onboarding)**: Der Schritt `background.login` braucht keinen bestimmten Aufbau mehr: er wendet nichts beim Verschwinden an, nur `onboardingDone == true` löst die Anwendung aus. Ein Kit-Hook „Onboarding fertig“ wäre sauberer (siehe Kandidaten). Überspringt jemand die Einrichtung, nachdem er den Schritt gesehen hat, und setzt das `onboardingDone`, gilt der Wunsch des Schritts (Standard an).
- **Integration (wave 2)**: Beispieljob über `BackgroundJobs.shared.register` (examples), Abschnitt im Menüleisten-Feld für Hintergrund-Jobs (`MenuBarPanel.sections`), Hotkey zum Öffnen des Felds (`MenuBarController.openPanel()`).

## Bekannte Lücken

- Echtes Verhalten auf dem Bildschirm (Klick aufs Symbol, Feld öffnen/schließen bei Klick daneben, Rechtsklick-Menü über `performClick`, KVO beim Wechsel der Menüleiste hell/dunkel, Glas des Felds, Drehen des Rings) ist gebaut, aber nach Regel §2.17 nie gestartet worden; geprüft sind nur die reinen Regeln, die Zeichnungen, die Renders und (neu) die Größenschritte von `open(from:)` im Test. Das übernimmt der Lead. Das Rechtsklick-Menü (`NSMenu`) lässt sich offscreen nicht rendern und hat keine Szene.
- Nicht-Template-Glyphen (Punkt, Stil Farbe) bekommen in der echten Menüleiste keine Vibrancy wie Template-Bilder; Tinte und Deckkraft stimmen jetzt, ein kleiner Unterschied auf farbigem Hintergrund kann bleiben (wie VoiceBud).
- Notizen von `.done(note:)` und Meldungen von `.failed` werden gespeichert, wie sie geschrieben wurden, und bleiben nach einem Sprachwechsel bis zum nächsten Lauf in der alten Sprache (dokumentiert in `BackgroundJobs`).
- `NSBackgroundActivityScheduler` und `SMAppService.register/unregister` sind nie wirklich aufgerufen worden (keine Anmeldeobjekte registrieren, kein Prozess bleibt). Ad-hoc-signierte Builds im Programme-Ordner sollten registrieren können; ungeprüft. `requiresApproval` ist nur als Zustand mit Text und Knopf gebaut.
- `MenuBarIcon` nutzt die Standardgröße von `NSImage(systemSymbolName:)` wie VoiceBud; bei sehr breiten Symbolen kann der Ring viel vom Glyph ausstanzen (in den Renders mit `sparkles` sauber).
- Hover auf Job-Zeilen und Aktionszeilen im Feld nur über `previewHovered` gerendert, nicht interaktiv probiert. VoiceOver nicht geprüft (Labels und die Aktion „Jetzt ausführen“ gesetzt). Der Chip „Jetzt ausführen“ erscheint weiter nur beim Hover; per Tastatur bleibt Kontextmenü (⌃-Klick) bzw. VoiceOver.
- Der Nachhol-Lauf nach dem Start ist ein einfacher Timer, nicht energiebewusst wie `NSBackgroundActivityScheduler`; erst danach übernimmt macOS. Echt gelaufen ist keiner von beiden.
- Kein Verlauf früherer Läufe (nur der letzte Lauf, Zähler `runs`/`failures`); keine Zeitbegrenzung für hängende Jobs.

## Prüfung (Befehle und Ergebnisse, 2026-10-12)

```
make build MODULES=menubar                -> grün, 0 Warnungen
make build MODULES=menubar,background     -> grün
make build MODULES=window,background      -> grün
make build MODULES=window                 -> grün (beide Module aus)
make build MODULES=window,menubar,island,background,hotkeys,ai,mlx,examples -> grün
make build                                -> grün (Standardmodule)
make build CONFIG=release                 -> grün (16 s)
STARTER_HEADLESS=1 …/Starter --selftest   -> "selftest: 10 checks, 0 failures" (neu: menubar.icon, background.jobs)
make test                                 -> "111 tests, 0 failures" (21 MenuBarTests, 23 BackgroundTests) + Python "Ran 11 tests … OK"
MODULES=window make test                  -> "67 tests, 0 failures" (Modultests ausgeblendet)
MODULES=menubar,background ONLY=MenuBar|Background make test -> 21 / 23 Tests, 0 Fehler
make check                                -> grün (Prüfskripte von G/K auf main noch nicht vorhanden, übersprungen)
check_design.py / check_texts.py --streng (Kopie aus wt/G1) auf beide Module und Tests -> keine Befunde
make shots ONLY=menubar. / ONLY=background. -> 20 + 12 PNGs
```

Tests: Stil-Fallback, Status (idle löscht Meldung, Wörter en/de), Sichtbarkeits- und Textregeln, Template-Tabelle, Animation nur busy/marks und nie mit „Bewegung reduzieren“, Ring-Schritte und Drehrichtung, Marken in den Grenzen auf dem Halbpunkt-Raster, jede Zeichnung mit Größe/`alignmentRect` des Symbols und sichtbaren Pixeln, Ring dreht (Alpha bei 12 Uhr in Schritt 0 vs. halbe Umdrehung, Mitte ausgestanzt), Punkt rot oben rechts, Vergrößerung, Klickregeln, Menüaufbau mit/ohne window und Sprache, Abschnittsreihenfolge, Platzierung (Mitte, rechter und linker Rand, Wachsen mit fester Oberkante), Registrierung, kein Statussymbol headless, jede Szene rendert hell/dunkel. Hintergrund: Buchführung, Fehlertexte, Spalten-Rundweg, SQLite über zwei Instanzen + keine Datei vor Benutzung, Registrierung (gespeicherte Datensätze, doppelte id), Planen/Abbrechen mit Fake-Scheduler, Schalter mit Persistenz, Lauf über Fake-Fire mit eingespeister Uhr, geworfener Fehler, keine Überlappung + „Jetzt ausführen“ trotz aus, Fire nach Ausschalten, Selbsttest, Intervall- und Relativtexte en/de, Badge-Töne, Verfügbarkeit des Login-Items (9 Pfade), Status-Abbildung, `needsChange`, Schalter-Startwert, Vorschaumodell, Registrierung (Schritt 900 nicht enthalten für dieses Binary, Start-Hook plant headless nichts), Szenen hell/dunkel.

Angesehen (Read): `menubar.icon-states` en-light und de-dark, `menubar.panel` de-dark und de-light, `menubar.panel-busy` en-light, `menubar.panel-empty` de-dark, `menubar.pane` de-light und en-dark, `background.pane` de-light und en-dark, `background.pane-unavailable` de-dark, `background.onboarding` en-dark, de-light und de-dark. Behoben nach dem Ansehen: abgeschnittene Fußzeilen-Chips auf Deutsch („Einstellun…“), orange Statusmarke neben rotem Symbolpunkt, Kachel-Vorschau nur als Streifen statt Schreibtisch mit Menüleiste, „Alle 7 Tage“ statt „Wöchentlich“, zu großer Abstand unter der Begründung, Schritt-Titel gleich dem Schaltertitel.

## Review (2026-10-12)

27 Befunde (davon drei doppelt gemeldet). Commits: `0400760`, `25bc643`, `f7d2c73`, `2d16089`, `baba35d`, `55e44a8`, `ad697e2`.

| # | Befund | Ergebnis |
|---|---|---|
| 1 | Feld öffnet 0 pt breit (blocker) | **Echt, behoben** (`0400760`): `fittingSize` wurde nach `sizingOptions = []` gelesen. Jetzt `MenuBarPanelController.host(_:)`: erst messen, dann abschalten, Breite ≥ 340. Test führt die Größenschritte von `open` aus (ohne Fenster nach vorn). |
| 2, 12 | Login-Schritt registriert bei Zurück/Schließen | **Echt, behoben** (`25bc643`): kein `onDisappear` mehr. Ersteinrichtung speichert nur `background.loginItemWish`; `LoginWish` wendet ihn an, wenn `onboardingDone` wahr wird (wie VoiceBud in `finish`). Später gezeigte Einrichtung wirkt sofort. Tests: Zurück/Schließen ändern nichts, Abschluss wendet einmal an, „aus“ schaltet ab. |
| 3 | Letzter Lauf wird beim Planen ignoriert | **Echt, behoben** (`f7d2c73`): `JobBook.firstDelay` (nie gelaufen oder überfällig → nach 10 s, sonst Rest des Intervalls, Uhr zurück → ein Intervall); `JobScheduling.schedule(_:after:fire:)`; System-Scheduler holt mit einmaligem Timer nach, danach `NSBackgroundActivityScheduler`. Tests mit Fake-Uhr und gespeicherten Datensätzen. |
| 4 | Doku-Beispiel kompiliert nicht; Notizen frieren die Sprache ein | **Echt**: Beispiel korrigiert (`MainActor.run`) und als Test kompiliert (`2d16089`). Eingefrorene Sprache **dokumentiert, nicht umgebaut**: ein übersetzbarer Notiz-Typ wäre eine neue API für einen Randfall; steht unter Lücken. |
| 5 | Punkt `systemRed` statt Token, anders als im Feld | **Echt, behoben** (`baba35d`): `MenuBarIcon.Inks.themed` (`strike`, `accentText`) im echten Symbol, Bereich und Renders. Hervorhebung im Szenenstreifen nutzt `chipActive` statt `.opacity(0.16)`. Ein-/Ausblendzeiten siehe 27. |
| 6, 13 | Statustext neben dem Symbol: langer Satz, keine Grenze, kein Render | **Echt, behoben** (`baba35d`): `MenuBarStatus.shortTitle`, sonst Name des Zustands („Braucht dich“), höchstens 14 Zeichen mit „…“; neue Szene `menubar.status-text`. |
| 7 | `exact`-Jobs mit 25 % Toleranz | **Echt, behoben** (`f7d2c73`): `JobSchedule.defaultTolerance` = min(1 s, Intervall/10) bei `exact`. |
| 8, 14 | „Jetzt ausführen“ nur per Hover | **Echt, behoben** (`55e44a8`): Kontextmenü und `accessibilityAction` auf jeder Zeile; der Chip bleibt Hover-Abkürzung. |
| 9, 19 | Stil-Fußnote unter den Schaltern | **Echt, behoben** (`baba35d`): Gruppe „Symbol“ (Kacheln + Fußnote), Gruppe „Anzeige“ (Schalter). Die Fußnote reserviert weiter zwei Zeilen, damit der Wechsel des Stils nichts verschiebt. |
| 10 | „zuletzt …“ aktualisiert sich nicht | **Echt, behoben** (`55e44a8`): `TimelineView(.periodic(by: 60))`, in Renders statisch. |
| 11 | Kein Signal für Start beim Anmelden | **Echt, behoben** (`25bc643`): `LoginItem.launchedAtLogin` aus dem Start-Apple-Event (`keyAELaunchedAsLogInItem`), im Start-Hook festgehalten; reine Prüfung `isLoginLaunch` getestet. Verdrahtung im Fenstermodul: wave 2. |
| 15 | Pfad „Anmeldeobjekte“ veraltet | **Echt, behoben** (`55e44a8`): „Allgemein > Anmeldeobjekte & Erweiterungen“ / „General > Login Items & Extensions“ in beiden Texten und im Kommentar. |
| 16 | Beenden auf Deutsch nur als Symbol | **Echt, behoben** (`baba35d`): Rückfall lässt bei allen Chips die Symbole weg, alle behalten ihren Namen; `MenuBarSymbolChip` entfernt. DE-Szenen neu angesehen. |
| 17 | Gleiche Aktion verschieden benannt | **Echt, behoben** (`baba35d`): „Fenster öffnen“ in Feld und Menü; Einstellungen aus `CommonText.settings`. Das kurze „Beenden“ im Feld bleibt bewusst neben „Starter beenden“ im Menü (macOS-Brauch im Menü, Platz im Feld). |
| 18 | Kopf im Feld versetzt | **Echt, behoben** (`baba35d`): Kopf ohne eigenen Einzug (bündig mit Kacheln und Fußzeile), Markierung links in einem 12-pt-Platz: Punkt und Spinner beginnen unter dem Namen, der Text springt nicht. |
| 20 | Glyph ändert den Ton mit dem Punkt | **Echt, behoben** (`baba35d`): Ursache war doppelt angewandte Deckkraft bei Palette-Symbolen (0,85 → 0,72), betrifft auch die echte Menüleiste. Jetzt deckende Palette + Deckkraft beim Zeichnen; Pixeltest `glyphAlpha`. |
| 21 | Stil Farbe mit Akzent-Füllung unter 3:1 | **Echt, behoben** (`baba35d`): `accentText`; gemessen 3,46:1 auf dem hellen Streifen (vorher 1,95:1). |
| 22 | Fehler in zwei Farben, Rot unter AA | **Echt, behoben** (`55e44a8`): Meldung in `warnText` (Ton des Badges, ≥ 4,5:1); Badge ausgeschalteter Jobs grau (`JobRow.tone(_:enabled:)`). |
| 23 | Zwei Arten von Gruppenköpfen | **Echt, behoben** (`55e44a8`): `JobList` als `SettingsSection` mit Gruppenlabel, ohne Zähler; leerer Zustand in der Karte. |
| 24 | Gesperrte Login-Zeile mit vollem Kontrast | **Echt, nicht im Strang behoben**: Ursache ist `ToggleRow`/`Row` im Kit (liest `isEnabled` nicht). Unter „Für das Kit“ gemeldet (S0b/E); Kit nicht angefasst. |
| 25 | Sichtbare Zustände ohne Render | **Echt, behoben** bis auf das Rechtsklick-Menü (`NSMenu` rendert offscreen nicht): neu `menubar.status-text`, `menubar.panel-nowindow`, `menubar.pane-nowindow`, `background.pane-approval` (Freigabe, Fehler, Job noch nie gelaufen), `background.onboarding-approval`. Hinweis jetzt in Kartenbreite und ersetzt die gleichlautende Fußnote; Onboarding-Render zeigt Schritt 6 von 7. |
| 26 | Textschliff | **Echt, behoben** (`baba35d`, `55e44a8`): „Ring und Punkt“ / „Ring and dot“, „zeigt die Menüleiste ein, zwei Wörter neben dem Symbol“, „öffne die App von dort“, neuer Untertitel „Starter ist da, sobald du dich anmeldest, …“, Zeile „Öffnet sich mit deinem Mac …“. |
| 27 | Bewegungs- und Deckkraftwerte außerhalb Kit/Design | **Teilweise**: Deckkraft → Token `chipActive`. Ein-/Ausblendzeiten (AppKit braucht Sekunden, `Motion` hat nur SwiftUI-Animationen) und Bildrate des Rings bleiben Modulkonstanten und stehen als Kit-Kandidaten oben; `// design-ausnahme:` lehnt `check_design.py` ohne Befund ab (`ad697e2`). |

### Prüfung nach dem Review

```
make build MODULES=menubar | menubar,background | window,background | window   -> grün, 0 Warnungen
make build MODULES=window,menubar,island,background,hotkeys,ai,mlx,examples      -> grün
make build / make build CONFIG=release                                          -> grün
STARTER_HEADLESS=1 …/Starter --selftest   -> "selftest: 10 checks, 0 failures"
make test                                 -> "119 tests, 0 failures" (MenuBarTests 23, BackgroundTests 29) + Python "Ran 11 tests … OK"
MODULES=window make test                  -> "67 tests, 0 failures"
make check                                -> grün (Prüfskripte von G/K auf main noch nicht vorhanden, übersprungen)
check_design.py / check_texts.py --streng (Kopie aus wt/G1) auf beide Module und Tests -> keine Befunde
make shots ONLY=menubar. / ONLY=background. -> 32 + 20 PNGs
```

Angesehen (Read) nach den Änderungen: `menubar.panel` de-light, `menubar.panel-busy` en-light, `menubar.panel-empty` de-dark, `menubar.panel-nowindow` en-dark, `menubar.status-text` de-dark und en-light, `menubar.icon-states` en-dark, `menubar.pane` de-light, `menubar.pane-nowindow` en-light, `background.pane` en-light und de-dark, `background.pane-approval` de-dark, `background.pane-unavailable` de-light, `background.onboarding` de-light, `background.onboarding-approval` de-light und en-dark. Nach dem Ansehen geändert: doppelte Zeilenbeschriftung in `menubar.status-text`, doppelte Pfadangabe (Fußnote + Hinweis) im Approval-Schritt.

Außerhalb des Strangs angefasst: weiterhin nichts.
