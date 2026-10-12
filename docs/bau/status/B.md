# Status B (Menüleiste + Hintergrund)

Stand: 2026-10-12, Branch `strang/B` (von `main` 68281d5). Gebaut sind die Module `menubar` und `background` nach STRANDS.md Abschnitt B, nur gegen Kit-APIs (keine Typen anderer Stränge).

## Was gebaut ist

### Modul `menubar` (`App/Sources/Modules/MenuBar/`)

| Datei | Inhalt |
|---|---|
| `MenuBarStatus.swift` | `MenuBarState` (idle, busy, attention), `MenuBarStatus.shared` (`@Observable`: `state`, `message`, `line`; `idle` löscht die Meldung), `MenuBarIconStyle` (plain, marks, color), SettingKeys `menubar.iconStyle`, `menubar.statusText`, `menubar.visible`, reine Regeln `MenuBarPrefs` |
| `MenuBarIcon.swift` | Symbol aus `app.symbol` als Template-Bild; gezeichnete Zustände: drehender Ring unten rechts (busy, 12 Schritte je Umdrehung, Spur 30 %, ausgestanzt), roter Punkt oben rechts (attention, ausgestanzt), Akzentfarbe (Stil color). Jede Zeichnung hat Größe und `alignmentRect` des Symbols, Marken liegen auf dem Halbpunkt-Raster |
| `MenuBarController.swift` | `NSStatusItem` (quadratisch, mit Statustext variabel), Linksklick öffnet das Feld, Rechts-/⌃-/⌥-Klick das Menü; Bild, Text und Tooltip folgen Status, Einstellungen und Sprache live (`Observing.track`); Erscheinungsbild per KVO; Timer nur bei busy im Stil marks, nie bei „Bewegung reduzieren“ (Änderung wird beobachtet); Menü wird bei jedem Öffnen neu gebaut (`MenuBarMenu.entries`) |
| `MenuBarPanel.swift` | Registry `MenuBarPanel.sections` (`MenuBarSection(id:order:title:tiled:content:)`, Inhalt bekommt `MenuBarPanelContext.close`), Platzierung `MenuBarPanelPlacement` (zentriert unter dem Symbol, im sichtbaren Bildschirm gehalten, oben fest bei Höhenänderung), `MenuBarPanelController` (randloses, nicht aktivierendes `NSPanel`, Ebene popUpMenu, Einblenden 0,12 s, schließt bei Klick daneben, Esc, Fokusverlust, zweitem Klick aufs Symbol; baut den SwiftUI-Baum beim Öffnen und gibt ihn beim Schließen frei, danach `malloc_zone_pressure_relief`) |
| `MenuBarPanelView.swift` | Feld im Stil des Kontrollzentrums von macOS 26: 340 pt, `GlassSurface` Radius 26, Kopf (App-Symbol, Name, Statuszeile mit grauem Punkt / Spinner / rotem Punkt), Abschnitte als Kacheln, `Registry.menuItems` als „Aktionen“, Fußzeile Einstellungen / Fenster öffnen (nur mit Modul window) / Beenden (schrumpft per `ViewThatFits` auf das Symbol). Bausteine: `MenuBarTile`, `MenuBarActionRow`, `MenuBarToggle`, `MenuBarSymbolChip`, `MenuBarStatusLine` |
| `MenuBarPane.swift` | Einstellungsbereich „Menüleiste“ (id `menubar`, Gruppe settings, order 300): Stil als `TilePicker` mit echten Symbolen auf Menüleiste über Hintergrundbild, Fußnote je Stil, Schalter „Status neben dem Symbol“, „In der Menüleiste zeigen“ (nur mit Modul window, sonst bleibt das Symbol immer sichtbar) |
| `MenuBarScenes.swift` | Szenen und Galerie mit festen Beispieldaten |
| `MenuBarModule.swift` | `register()`: Bereich, Start-/Ende-Hooks, Selbsttest `menubar.icon`, Szenen; Hilfen `bitmap`, `inkedPixels`, `alpha` |
| `MenuBarText.swift` | `MenuBarText`, `MenuBarSampleText` |

Öffentliche API: `MenuBarStatus.shared.state/.message`, `MenuBarPanel.sections.append(…)`, `Registry.menuItems` (erscheinen im Feld und im Menü), `MenuBarController.openPanel()`.

### Modul `background` (`App/Sources/Modules/Background/`)

| Datei | Inhalt |
|---|---|
| `BackgroundJobs.swift` | `JobOutcome` (done(note:), nothingToDo, failed), `JobRecord`, reine Buchführung `JobBook`, `JobSchedule`, `BackgroundJobs.shared` (`@Observable`): `register(id:title:interval:tolerance:qos:exact:run:)` (Toleranz Standard ¼ Intervall, doppelte id wird ignoriert und geloggt), `start()`/`stop()`, `setEnabled`/`isEnabled` (persistiert `background.disabledJobs`), `runNow`, `perform(_:) async` (nie überlappend, Fehler werden mit `LocalizedError`-Text erfasst), `record`, `isRunning` |
| `JobStore.swift` | `JobStore`-Protokoll, `DatabaseJobStore` (Kit-`Database`, `background.sqlite`, Migration 1 `job_state`, Upsert; Datei entsteht erst beim ersten Laden, also erst mit einem Job), `MemoryJobStore` |
| `JobScheduling.swift` | `SystemJobScheduler` (`NSBackgroundActivityScheduler` mit `shouldDefer` → `.deferred`, `completion(.finished)` erst nach dem Lauf; `exact: true` → `Timer` im Modus `.common`), `NoJobScheduler` |
| `LoginItem.swift` | `LoginItem` über `SMAppService.mainApp`: `availability(bundlePath:isBundle:home:)` (nur /Applications oder ~/Applications; Gründe notBundle, diskImage, translocated, notInstalled), `map(SMAppService.Status)`, `needsChange` (macOS wird nur bei echter Änderung gerufen, in beide Richtungen), `setEnabled`, `openSystemSettings`; `LoginItemModel` (live oder feste Werte für Renders); `LoginItemStepRule` |
| `BackgroundPane.swift` | Bereich „Hintergrund“ (id `background`, order 310): Schalter „Beim Anmelden starten“ (gesperrt mit Begründung als Fußnote, wenn nicht verfügbar), Hinweis bei `requiresApproval` mit „Systemeinstellungen öffnen“, Fehlerhinweis, `ListCard` „Aufgaben“ mit `JobRow` (Titel, Intervall + letzter Lauf relativ, Fehlermeldung rot, Ergebnis-Badge oder Spinner „Läuft“, „Jetzt ausführen“ beim Hover, Schalter); leerer Zustand „Keine Aufgaben“ |
| `LoginItemStep.swift` | Onboarding-Schritt `background.login` (order 900, nur wenn `LoginItem.isAvailable`): „Mit dem Mac starten“, Schalter beim ersten Einrichten an (VoiceBud), später der Stand von macOS; wird beim Verlassen des Schritts angewendet |
| `BackgroundScenes.swift` | Szenen und Galerie mit festen Beispieljobs und fester Uhr |
| `BackgroundModule.swift` | `register()`: Bereich, Schritt, Start-Hook (plant nur im echten Programm, nie headless/Render), Ende-Hook, Selbsttest `background.jobs` |
| `BackgroundText.swift` | `BackgroundText` (Intervalle „Alle 15 Minuten“, „Stündlich“, „Täglich“, „Wöchentlich“; „vor 4 Minuten“, „gerade eben“), `BackgroundSampleText` |

Ein Beispieljob wird nicht ausgeliefert (kommt mit examples in der Integration).

### Szenen (`make shots ONLY=menubar.` / `ONLY=background.`)

`menubar.icon-states` (alle 3 Stile × 3 Zustände vierfach vergrößert auf Menüleisten-Stücken, dazu Originalgröße), `menubar.panel` (Feld mit Beispielabschnitten unter der Menüleiste), `menubar.panel-busy` (Statuszeile mit Spinner und Meldung), `menubar.panel-empty` (ohne Beiträge, Zustand attention), `menubar.pane`, `background.pane` (fünf Jobs: erledigt mit Notiz, Hover mit „Jetzt ausführen“, läuft, fehlgeschlagen, ausgeschaltet), `background.pane-unavailable` (Build-Ordner, keine Jobs), `background.onboarding`. Galerie: `menubar.icon`, `menubar.panel`, `menubar.toggle`, `background.jobs`.

## Entscheidungen

- **Feld als `NSPanel`, nicht `NSPopover`**: kein Pfeil, Ecken und Glas wie die Module des Kontrollzentrums; nicht aktivierend, damit die vordere App vorne bleibt. Liegt das Symbol nah am rechten Rand, hält die Platzierung das Feld 8 pt im Bildschirm (wie die Szene zeigt).
- **Zustandszeichen statt Animation des ganzen Symbols**: ein kleiner drehender Ring ist der einzige bewegte Teil; Stil „Schlicht“ ändert nie etwas, „Farbe“ färbt nur. Busy-Ring bleibt ein Template-Bild (macOS färbt hell/dunkel und gedrückt selbst); Punkt und Farbe brauchen gezeichnete Farben, deren Tinte aus dem Erscheinungsbild der echten Menüleiste kommt (VoiceBud).
- **Roter Punkt, kein oranger**: Orange ist in der Menüleiste die Mikrofon-Anzeige von macOS. Die Statuszeile im Feld nutzt dafür `t.strike` statt `StatusMark(.warn)`, damit beide Stellen gleich aussehen.
- **„In der Menüleiste zeigen“ nur mit Modul window**: ohne Hauptfenster wäre die App sonst unerreichbar (`MenuBarPrefs.isVisible`).
- **Menüpunkt „Fenster öffnen“** hängt an `AppInfo.isEnabled("window")` (Zeichenkette, kein Typ eines anderen Moduls) und ruft `AppActions.openMainWindow()`.
- **Job-Datensätze in SQLite** (Kit-`Database`), Schalter in den Settings (`background.disabledJobs`), weil sie eine Wahl der Person sind und zur Einstellungsdatei gehören.
- **`BackgroundJobs` mit eingespeisten Teilen** (Store, Scheduler, Settings oder `nil`, Uhr, laufende Ids): Tests ohne echten Scheduler und ohne Warten, Renders ohne Dateien.
- **Login-Item-Schritt wendet beim Verlassen an** (`onDisappear`), weil ein Modul-Schritt den Abschluss des Onboardings nicht sieht. Ändert nur, was sich von macOS unterscheidet; merkt sich `background.loginItemAsked`.
- Reihenfolge der Bereiche: Menüleiste 300, Hintergrund 310 (Kit: Allgemein 0, Über 1000).

## Aus VoiceBud übernommen (für THIRD_PARTY_NOTICES, MIT, Copyright (c) 2026 Anas Riad)

- `ui/MenuBarIcon.swift`: Template-Symbol im Ruhezustand, Zeichnen mit `NSImage(size:flipped:drawingHandler:)`, Punkt oben rechts in den Grenzen des Symbols (5 pt), `alignmentRect` des Symbols übernommen, quadratisches vs. variables Element, Erscheinungsbild per KVO und `performAsCurrentDrawingAppearance`, Timer im Modus `.common` nur wenn nötig.
- `ui/main.swift` `buildMenu`/`menuNeedsUpdate`: Menütitel bei jedem Öffnen neu (Sprachwechsel), „Einrichtung …“ im Menü.
- Speicherfreigabe beim Schließen (`malloc_zone_pressure_relief` nach 0,5 s) aus dem Hub.
- Login-Item-Verhalten aus `onboarding.py`: nur die installierte App, Schalter beim ersten Einrichten an, Änderung in beide Richtungen nur bei Unterschied.

## Kandidaten für Kit/Design

`MenuBarIconMetrics` (Punkt 5, Ring 7/1,5, Ausstanzung 1), `MenuBarPanelMetrics` (Breite 340, App-Symbol 32, Kreis 28, Zeilensymbol 13/18, Spinner 12, Ein-/Ausblenden 0,12/0,16 s), `BackgroundMetrics.stepCard` (460 = `onboardingNarrow + 60`, hat im Kit noch kein Token; S0b nutzt dieselbe Summe), die Bausteine `MenuBarTile`, `MenuBarToggle` (Kontrollzentrum-Schalter), `MenuBarSymbolChip` (Chip nur mit Symbol), `MenuBarStatusLine`, `JobRow`.

## Außerhalb meines Strangs angefasst

Nichts. Nur `App/Sources/Modules/MenuBar/**`, `App/Sources/Modules/Background/**`, `App/Tests/MenuBarTests.swift`, `App/Tests/BackgroundTests.swift` und dieser Bericht. Die Testdateien stehen in `#if TESTING` → `#if MODUL_MENUBAR` bzw. `#if MODUL_BACKGROUND` (zwei einfache Blöcke ineinander), damit `make test` mit jeder Modulauswahl baut und `bin/starter remove` sie leeren kann.

## Hinweise für die Integration und andere Stränge

- **Strang G (Prüfskripte)**: Mit einer Kopie der noch nicht eingecheckten Skripte aus `wt/G1` (`check_design.py`, `check_texts.py`, `rules/`) sind beide Module ohne Befund (`--streng`). Drei bewusste `// design-ausnahme:` stehen im Code: `NSColor.labelColor` für die Tinte der echten Menüleiste (zwei Zeilen in `MenuBarController.inks`), `NSColor.black` als Template-Farbe in `MenuBarIcon.ringed` (zwei Zeilen), `+ 60` in `BackgroundMetrics.stepCard`. `SMAppService` steht nur in `Modules/Background` (Regel `anmeldeobjekt` erlaubt das).
- **Strang A (Fenster)**: STRANDS A spricht von einem Start als Anmeldeobjekt mit `--background`. `SMAppService.mainApp` startet die App ohne Argumente, und `LaunchFlags` kennt `--background` nicht (unbekannte `--`-Flags beenden mit Code 2). Ein verlässliches Signal für „beim Anmelden gestartet“ gibt es hier nicht; die Integration muss entscheiden (z. B. Fenster beim Login-Start nicht öffnen, wenn ein Kit-Flag dafür kommt).
- **Strang D (Onboarding)**: Der Schritt `background.login` wendet seine Wahl in `onDisappear` an. Hält D alle Schritte gleichzeitig im Baum (z. B. nur per Deckkraft), feuert das nicht; dann bitte den Schritt beim Weitergehen aus dem Baum nehmen oder einen Abschluss-Hook im Kit anbieten.
- **Integration (wave 2)**: Beispieljob über `BackgroundJobs.shared.register` (examples), Abschnitt im Menüleisten-Feld für Hintergrund-Jobs (`MenuBarPanel.sections`), Hotkey zum Öffnen des Felds (`MenuBarController.openPanel()`).

## Bekannte Lücken

- Echtes Verhalten auf dem Bildschirm (Klick aufs Symbol, Feld öffnen/schließen bei Klick daneben, Rechtsklick-Menü über `performClick`, KVO beim Wechsel der Menüleiste hell/dunkel, Glas des Felds, Drehen des Rings) ist gebaut, aber nach Regel §2.17 nie gestartet worden; geprüft sind nur die reinen Regeln, die Zeichnungen und die Renders. Das übernimmt der Lead.
- `NSBackgroundActivityScheduler` und `SMAppService.register/unregister` sind nie wirklich aufgerufen worden (keine Anmeldeobjekte registrieren, kein Prozess bleibt). Ad-hoc-signierte Builds im Programme-Ordner sollten registrieren können; ungeprüft. `requiresApproval` ist nur als Zustand mit Text und Knopf gebaut.
- `MenuBarIcon` nutzt die Standardgröße von `NSImage(systemSymbolName:)` wie VoiceBud; bei sehr breiten Symbolen kann der Ring viel vom Glyph ausstanzen (in den Renders mit `sparkles` sauber).
- Hover auf Job-Zeilen und Aktionszeilen im Feld nur über `previewHovered` gerendert, nicht interaktiv probiert. VoiceOver nicht geprüft (Labels gesetzt).
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
