# Status Integration Welle 1

Stand: 2026-10-12, Branch `main` (Start: `68281d5`, S0 + S0b). Alle elf Stränge von Welle 1 sind mit `git merge --no-ff` zusammengeführt, `main` ist grün: Build, Tests, Selbsttest, `make check` und die Build-Matrix der CI. Nichts gepusht.

## Merge-Protokoll

| Reihenfolge | Strang | Merge-Commit | Konflikte |
|---|---|---|---|
| 1 | K (Starter-Werkzeuge) | `e8602b3` | keine |
| 2 | G1 (Regeln, Prüfungen, Hooks) | `e23fb4d` | keine |
| 3 | G2 (Doku, Agenten, CI) | `d54c1ae` | keine |
| 4 | J (Icon, DMG, Notarisierung) | `514f3ef` | keine |
| 5 | D (Onboarding, Berechtigungen) | `29891ef` | keine |
| 6 | E (Einstellungen, Galerie, Über) | `d7d46da` | keine (`gen_config.py` und Test automatisch: D `app.tagline`, E `app.links`, beide drin) |
| 7 | A (Fenster) | `b7c55b3` | `Kit/Main/AppDelegate.swift`, `Kit/Main/CommandLine.swift`; dazu der semantische Konflikt `AppIconImage` |
| 8 | B (Menüleiste, Hintergrund) | `d828b00` | keine |
| 9 | C (Insel) | `7c2628a` | keine |
| 10 | F (Kurzbefehle) | `aa2b2a4` | keine |
| 11 | H (Lokale KI) | `add6c6a` | `Kit/Main/CommandLine.swift` (Kopfkommentar) |

Commits nach den Merges:

| Commit | Inhalt |
|---|---|
| `c338d2b` docs(rules) | Werkzeuge-Tabelle in `rules/index.json` um die jetzt vorhandenen Pfade ergänzt, `make rules`; Modul-Markierungen in `CLAUDE.md` (`docs/KI.md`, `<!-- modul:ai -->`) und `tools/README.md` (`ai-worker/package.sh`, `<!-- modul:mlx -->`); DMG-Texte in `tools/README.md` als Code |
| `0b276a0` fix(texts) | Befunde von `check_texts`/`check_design` auf C, D, E, J behoben; Baseline verkleinert; „Dennoch öffnen“ in der Doku |
| `df6e9dd` test | `test_gen_config.py` mit Fixture statt echter `starter.json`; `ObservingTests` warten auf die Bedingung statt 50 ms |
| `aee4201` fix(settings) | `SettingsReset.keep` für `ai.usage` (H) und `background.loginItemAsked` (B); Doku-Beispiel in `GeneralPane.swift` ohne falschen Methodennamen |
| `70daae3` ci | `make check-texts`/`check-design` nehmen `CHECK_FLAGS`; die CI ruft sie mit `--ci` (veraltete Baseline-Einträge sind dort ein Fehler) |

## Konflikte und Lösung

- **`--background` (A und D).** Beide Stränge hatten das Flag, `Launch.isBackground` und die Erkennung des Anmeldeobjekt-Starts gebaut. Behalten: Ds API in `CommandLine.swift` (`Launch.noteLaunchEvent`, `Launch.isLoginItemLaunch`, `private(set) isBackground`, `--permission-probe`), weil Ds Tests sie nutzen und sie die Erkennung rein und testbar macht. As eigene `launchedAsLoginItem`-Eigenschaft im `AppDelegate` entfällt.
- **`AppDelegate` (A und D).** As Regel „Start und Dock-Klick teilen sich eine Regel“ (`AppDelegate.primaryWindow`, `openPrimaryWindow`, Test in `BackgroundLaunchTests`) bleibt; ob die Einrichtung offen ist, entscheidet jetzt Ds `OnboardingKit.opensAtLaunch(done:reopen:hasSteps:background: false)`. Damit gilt Ds Fortsetzen nach Neustart (`onboarding.reopen`) auch beim Start, und As Dock-Klick nach einem Hintergrundstart setzt eine unfertige Einrichtung fort. Hintergrundstart: kein Fenster (beide Seiten).
- **`--selftest [prefix]` (H) und `--permission-probe` (D)** im Kopfkommentar von `CommandLine.swift`: beide Zeilen behalten; der Code selbst hatte keinen Konflikt.
- **`AppIconImage` doppelt (A `Modules/Window/Pages/HomePage.swift`, D `Kit/Onboarding/OnboardingSteps.swift`).** Eine Fassung in `Kit/Design/Components/Icons.swift`, beide Stellen nutzen sie. Genommen ist Ds Fassung (lädt das Symbol einmal per `@State`, Squircle im Verhältnis 824/1024 wie eine Icon-Datei); die Startseite des Fensters zeigt das Squircle dadurch etwas kleiner als vorher (`window.home` en-hell gerendert und angesehen, passt).
- **`App/Sources/Kit/Shims`**: gab es auf keinem Strang, nichts zu entfernen.
- `Kit/Core/Registry.swift` (H `onDemand`), `Kit/Main/Modules.swift` (G2 `Features.register()`), `scripts/test.sh` (K `scripts/starter/tests`, H venv-Pfad), `Makefile` (K `probe`), `starter.json` (D `tagline`), `scripts/gen_config.py` und Test (D, E): automatisch zusammengeführt, Inhalt geprüft, beide Seiten drin.

## Checkliste: Anfragen und „außerhalb angefasst“ aus allen Statusberichten

`erledigt (Merge)` = mit dem Merge oder den Commits oben erledigt bzw. vom Strang selbst erledigt und auf `main` geprüft. `offen (Abgleich)` = bleibt für den Abgleich nach Welle 1.

### Außerhalb des eigenen Strangs angefasst

| Strang | Was | Stand |
|---|---|---|
| K | `Makefile` Ziel `probe`, `scripts/test.sh` führt `scripts/starter/tests` aus, `starter.lock.json` neu | erledigt (Merge) |
| G1 | nichts | erledigt (Merge) |
| G2 | `Kit/Main/Modules.swift` ruft `Features.register()`, `App/Sources/Features/Features.swift`, `Features/README.md`, `scripts/tests/test_claude_harness.py` | erledigt (Merge) |
| J | `scripts/doctor.sh` (dmgbuild in `build/tools-venv`), `scripts/tests/test_packaging.py` | erledigt (Merge) |
| D | `CommandLine.swift` (`--permission-probe`, `--background`, Start-Event), `AppDelegate.swift`, `gen_config.py` (`automation:<id>`, `app.tagline`) + Tests, `starter.json` `app.tagline`, Stubs `Permission.swift`/`OnboardingKit.swift` ersetzt | erledigt (Merge), Konflikt mit A gelöst |
| E | `gen_config.py` `app.links` + Test, `build.sh` bündelt `App/Resources/Notices/*.md`, `Kit/Design/SettingsTokens.swift` | erledigt (Merge) |
| A | `CommandLine.swift`/`AppDelegate.swift` (`--background`, Dock-Klick-Regel), `MainMenu.decorators`, `WindowHost.show(configure:)`, `BackgroundLaunchTests.swift` | erledigt (Merge), Konflikt mit D gelöst |
| B, C, F | nichts | erledigt (Merge) |
| H | `Registry.swift` `SelfTestCheck.onDemand`, `SelfTest.run(only:)`, `CommandLine.swift` `--selftest [präfix]`, `SelfTestFilterTests.swift`, `scripts/test.sh` venv-Pfad | erledigt (Merge) |

### Anfragen an andere Stränge, S0 und die Integration

| Von | An | Anfrage | Stand |
|---|---|---|---|
| K, G2 | G1 / Integration | `CLAUDE.md` Teil B: `docs/KI.md` mit `<!-- modul:ai -->` | erledigt (Merge, `c338d2b`) |
| K | J / Integration | `tools/README.md:33` nennt `ai-worker/` ohne Markierung | erledigt (Merge, `c338d2b`, `<!-- modul:mlx -->`) |
| K | Integration | `AppIconImage` doppelt | erledigt (Merge, in `Kit/Design`) |
| K | G1 | `commit-msg` ruft `check_commit_msg.py`, `pre-push` ruft `make check`, leere Identität lehnt ab | erledigt (Merge; check-kit „Hooks erfüllen die Soll-Liste“) |
| K | G2 | `ci.yml` mit `make check`, `docs/vorlagen/*`, README-Block `nur-im-starter`, Template-Probe | erledigt (Merge) |
| K | G2 | `docs/UEBERGABE.md`: für private Starter `--quelle git@github.com:wielochyeah/mac-app-starter.git` nennen | offen (Abgleich) |
| K | alle | neue Wurzeldateien brauchen einen Manifest-Eintrag | erledigt (Merge; check-kit: alle Dateien klassifiziert) |
| K | S0 | `gen_config.py` soll Module ablehnen, deren Ordner fehlt | offen (Abgleich) |
| G1 | Integration | `rules/index.json` `werkzeuge` um `.claude/agents`, `red-team.js`, `session-start.py`, `bin/starter`, `check_kit.py`, `icon.sh`, `docs/DESIGN.md`, dann `make rules` | erledigt (Merge, `c338d2b`) |
| G1 | G2 | CI: `check_commit_msg.py --bereich origin/main..HEAD` mit `fetch-depth: 0`, `check_texts.py --ci`, `check_design.py --ci`, `make check-rules` | erledigt (Merge + `70daae3` für `--ci`) |
| G1 | G2 | `.claude/settings.json`: `--no-verify`, `commit -n`, `core.hooksPath` sperren | erledigt (Merge; Deny-Liste + `guard-git.py`) |
| G1 | G2 | Hook `session-start` setzt Git-Identität aus `starter.json` | erledigt (Merge) |
| G1 | K | `bin/starter init`: nach Anrede-Wechsel und Leeren von `commit` `make rules`, `texts.personen` leeren, Hinweis bei `--anrede sie` | offen (Abgleich) |
| G1 | K | `remove` braucht keine Regeländerung (Information) | erledigt (Merge) |
| G1 | D, E, S0b | Stubs ersetzen bzw. Befunde beheben, Baseline verkleinern; Zweizeiler mit `// umbruch:`, `languageCrossHint` mit `// text-ausnahme:` | D/E: erledigt (Merge, `0b276a0`, Baseline 30 auf 20); die 20 übrigen Befunde in S0/S0b-Dateien (`AppForm.swift`, `DesignCatalog.swift`, `DesignTests.swift`, `OnboardingPage.swift`, Pfeile in `Registry.swift`/`Island.swift`/`Tokens.swift`/`SettingsRows.swift`, `DesignText.swift` Mittelpunkt, `PatternsText.swift` 156/166/167, `OnboardingStatusSlot.swift` 92): offen (Abgleich) |
| G1 | C, D, E, J | Befunde der neuen Prüfungen vor dem Merge beheben | erledigt (Merge, `0b276a0`) |
| G1 | Leitung | R8: will der Starter ausgewogene Zweizeiler überhaupt (`// umbruch:`)? | offen (Abgleich, Entscheidung) |
| G2 | S0 | `test_gen_config.py` liest echte `starter.json` | erledigt (Merge, `df6e9dd`) |
| G2 | S0 / Integration | `Features.register()` übernehmen, als Entscheidung in `docs/DECISIONS.md` | Code erledigt (Merge); DECISIONS-Eintrag offen (Abgleich) |
| G2 | G1 / K | Hook-Aufruf und Manifest `checks.hooks` abgleichen | erledigt (Merge; K `c269ca9`) |
| G2 | B | Doku-Beispiel in `BackgroundJobs.swift` ohne `await` | erledigt (B `2d16089`, als Test kompiliert) |
| G2 | K | Skills den Modulen zuordnen, Markierungen, `ersetzen`/`verschieben` in init | erledigt (Merge; check-kit 8 von 8) |
| G2 | K | CI-Aufrufe von `bin/starter` (`--non-interactive`, `--ohne-build`, `--ohne-netz`, Ablehnungen) | erledigt (Merge; Ks Probe im Integrationsklon) |
| G2 | J | DMG-Hinweis ohne „Rechtsklick, Öffnen“ | erledigt (Merge) |
| G2 | J | `make icon` soll sagen, dass das Symbol ein SF Symbol ist und vor der Weitergabe ersetzt werden muss | offen (Abgleich) |
| G2 | G1 | Regel „App nie normal starten“ in Teil A | erledigt (Merge; T-08) |
| G2 | Integration | `docs/screenshots/list.txt` gegen Szenen prüfen, dann `make shots && make readme-shots` | offen (Abgleich) |
| G2 | Integration | Skill-Beispiele und `docs/MODULE.md` gegen den gemergten Code typprüfen; Fensterbausteine (A) abgleichen | offen (Abgleich) |
| G2 | Integration | `THIRD_PARTY_NOTICES.md` um die VoiceBud-Übernahmen aus A bis J ergänzen | offen (Abgleich) |
| J | G | `tools/**` in den Prüfungen | erledigt (Merge; G1 prüft `tools/` ohne `gestaltung`, Befunde behoben) |
| J | G | „Dennoch öffnen“ statt „Trotzdem öffnen“ in VERTEILUNG, README und Doku | erledigt (Merge, `0b276a0`) |
| J | G | `make notarize` nur für DMGs aus `make dmg` mit `signing.notarize: true` beschreiben; `signing.notaryProfile`/`NOTARY_PROFILE` in der Signier-Anleitung | offen (Abgleich) |
| J | S0 / G | `DMG_NO_BUILD` statt `NO_BUILD` für `make dmg` | erledigt (Merge; keine Doku nennt `NO_BUILD` für `make dmg`, `tools/README.md` nennt `DMG_NO_BUILD`) |
| J | K | `tools/**`, Skripte und Test als Kit, `AppIcon.icns` als Projekt | erledigt (Merge; check-kit klassifiziert alles) |
| J | H | `ai-worker/package.sh` und ggf. `disable-library-validation` in `tools/entitlements.plist` | offen (Abgleich) |
| J | S0 | `LSHasLocalizedDisplayName`, damit Finder den übersetzten Namen zeigt | offen (Abgleich) |
| J | Leitung | Finder im Dunkelmodus und Icon-Rahmen auf macOS 26 ansehen | offen (Abgleich, nur interaktiv) |
| D | K | `bin/starter init` muss `app.tagline` erfragen oder leeren | offen (Abgleich) |
| D | Integration | `OnboardingTokens.swift` nach `Kit/Design/Patterns/PatternTokens.swift`, `onboardingCard` ersetzt S0bs `onboardingNarrow + 60` | offen (Abgleich) |
| D, B | Integration | `onboardingCard`/`BackgroundMetrics.stepCard` (460) als Token | offen (Abgleich) |
| D | G | Hinweise zu `languageCrossHint`, `KeyCaps`, `nativeName` | erledigt (Merge; `text-ausnahme` gesetzt, keine Befunde) |
| E | S0 | `RenderRunner`: gemessene Breite aufrunden (abgeschnittene Texte bei `size: .zero`) | offen (Abgleich) |
| E | D | „Einrichtung erneut zeigen“ über `AppActions.openOnboarding()` | erledigt (Merge) |
| E | G | Satz in `THIRD_PARTY_NOTICES.md` zur Anzeige in „Über“ an `App/Resources/Notices/<lang>.md` anpassen | offen (Abgleich) |
| E | F, H, B, A | Reset-Vertrag `SettingsReset.keep`/`didReset` | H, B: erledigt (Merge, `aee4201`); F: kein Eintrag nötig (folgt `Settings`); A: offen (Abgleich, ob `window.page`/`window.sidebarHidden` Zustand sind) |
| E | A | `Metrics.Window.sidebar*` auf `Metrics.Sidebar` umstellen, einen `sidebarTop` wählen (48 vs. 44) | offen (Abgleich) |
| E | Integration | Galerie als Bereich statt eigenem Fenster in `docs/DECISIONS.md` | offen (Abgleich) |
| A | E / S0 | Mindestgröße per SwiftUI: gilt auch für das Einstellungsfenster (760 x 500 hält nicht) | offen (Abgleich) |
| A | G2 | `WindowSearch.enable(page:prompt:)` in Skill `neue-ansicht` und `docs/MODULE.md` | offen (Abgleich) |
| A | Kit | Kandidaten `WindowTokens`, `StaticSidebar`, `PageScroll`, `Artwork` | offen (Abgleich) |
| B | A | Login-Start: `LoginItem.launchedAtLogin` (B) und `Launch.isBackground` (D) doppeln sich; B auf `Launch` umstellen | offen (Abgleich) |
| B | Kit | `ToggleRow`/`Row` dimmt gesperrte Zeilen nicht; textfähiges Rot; Kit-Hook „Onboarding fertig“; `Motion`-Sekunden für AppKit | offen (Abgleich) |
| B | Welle 2 | Beispieljob, Hintergrund-Abschnitt im Menüleisten-Feld, Hotkey zum Öffnen des Felds | offen (Abgleich) |
| C | Integration | `IslandLook`-Werte nach `Kit/Design/Island.swift` | offen (Abgleich) |
| C | G2 | Skill/Doku: `Island.shared.notchBusy`, `recording` schaltet den roten Punkt | offen (Abgleich) |
| F | S0 | `autoreleasepool` in `RenderRunner.png`; `ObservingTests` auf „warten bis Bedingung“ | `ObservingTests`: erledigt (Merge, `df6e9dd`); `RenderRunner`: offen (Abgleich) |
| F | E | `didReset` braucht keinen Hotkey-Eintrag; Doku-Kommentar nannte `reload()` | erledigt (Merge, `aee4201`) |
| H | J / Integration | `ai-worker/package.sh` (eingebettetes Python), bis dahin `mlx` nur für Entwickler | offen (Abgleich) |
| H | G | Fehlalarm „`--`“ bei `models--org--name` als Regel-Lücke | offen (Abgleich) |
| H | Kit | `ProgressRow.Phase.notStarted`, `AIWait`, einzeiliges Eingabefeld, gemeinsame Symbolgröße `Row`/`ProgressRow` | offen (Abgleich) |

### Offene Punkte (Liste)

1. G2 `docs/UEBERGABE.md`: `--quelle git@github.com:wielochyeah/mac-app-starter.git` für private Starter nennen (K).
2. `gen_config.py`: Module ablehnen, deren Ordner fehlt (K an S0).
3. `bin/starter init`: `make rules` nach Anrede-Wechsel und Leeren von `commit`, `texts.personen` leeren, Hinweis bei `--anrede sie` (G1 an K).
4. `bin/starter init`: `app.tagline` erfragen oder leeren (D an K).
5. 20 Baseline-Befunde in S0/S0b-Dateien beheben und die Baseline verkleinern (G1).
6. Entscheidung R8: ausgewogene Zweizeiler mit `// umbruch:` ja oder nein (G1 an Leitung).
7. `docs/DECISIONS.md`: Einträge für `Features.register()` (G2) und Galerie als Bereich (E).
8. `make icon`: Hinweis, dass das SF Symbol vor der Weitergabe ersetzt werden muss (G2 an J).
9. `docs/screenshots/list.txt` gegen die Szenen prüfen, `make shots && make readme-shots` (G2).
10. Skill-Beispiele und `docs/MODULE.md` gegen den gemergten Code typprüfen; `WindowSearch.enable` (A) und `Island.shared.notchBusy`/`recording` (C) in Skills und Doku (G2).
11. `THIRD_PARTY_NOTICES.md`: VoiceBud-Übernahmen aus A bis J ergänzen, Satz zur Anzeige in „Über“ anpassen (G2, E).
12. Signier-Doku: `make notarize` nur mit `signing.notarize: true`, `signing.notaryProfile`/`NOTARY_PROFILE` (J an G).
13. `ai-worker/package.sh` mit eingebettetem Python, Entitlement `disable-library-validation` prüfen (J, H).
14. `LSHasLocalizedDisplayName` für den übersetzten Namen in Finder (J an S0).
15. Finder im Dunkelmodus und Icon-Rahmen auf macOS 26 interaktiv ansehen (J an Leitung).
16. `OnboardingTokens.swift` nach `Kit/Design/Patterns/PatternTokens.swift`, ein Token für die 460-pt-Karte statt `onboardingNarrow + 60` (D, B).
17. `RenderRunner`: gemessene Breite aufrunden (E) und `autoreleasepool` in `png` (F).
18. Reset-Vertrag für A: `window.page`/`window.sidebarHidden` als Zustand behalten oder nicht.
19. `Metrics.Window.sidebar*` auf `Metrics.Sidebar`, einen `sidebarTop` wählen (E, A).
20. Mindestgröße des Einstellungsfensters wie beim Hauptfenster über SwiftUI halten (A an E).
21. Login-Start nur über `Launch.isBackground`; `LoginItem.launchedAtLogin` (B) darauf umstellen.
22. Kit-Kandidaten: `ToggleRow` dimmt gesperrte Zeilen, textfähiges Rot, Hook „Onboarding fertig“, `Motion`-Sekunden für AppKit (B); `WindowTokens`, `StaticSidebar`, `PageScroll`, `Artwork` (A); `IslandLook` nach `Kit/Design/Island.swift` (C); `ProgressRow.notStarted`, `AIWait`, Eingabefeld, gemeinsame Symbolgröße (H); `BigKeyCaps` (F).
23. Welle 2 (B): Beispieljob, Hintergrund-Abschnitt im Menüleisten-Feld, Hotkey zum Öffnen des Felds.
24. Regel-Fehlalarm `--` in `models--org--name` (H an G).

## Prüfung (Befehle und Ergebnisse, 2026-10-12, auf `70daae3`)

```
make build                     -> build/Starter.app (debug, window,menubar,island,background,hotkeys,ai,examples)
STARTER_HEADLESS=1 STARTER_DATA_DIR=<tmp> …/Starter --selftest -> "selftest: 27 checks, 0 failures"
make test                      -> Swift "352 tests, 0 failures"; scripts/tests "Ran 218 tests … OK";
                                  scripts/starter/tests "Ran 115 tests … OK"; ai-worker "Ran 23 tests … OK"
make check                     -> grün: rules_sync gültig; check_texts 20 bekannte Befunde, keine neuen, keine
                                  veralteten (auch mit --ci); check_design keine Befunde (187 Dateien);
                                  check-kit: Starter selbst, alle Dateien klassifiziert (Kit 274, gemeinsam 63,
                                  Projekt 16, nur im Starter 13), 8 von 8 Modulen entfernbar, Hooks und CI erfüllt
MODULES=menubar make test      -> Swift "163 tests, 0 failures", Python wie oben OK
MODULES=window make test       -> Swift "170 tests, 0 failures", Python OK
MODULES=<alle inkl. mlx> make test -> Swift "383 tests, 0 failures", Python OK
build/tests/run-tests 4x parallel, 3 Runden -> 12 von 12 Läufen "0 failures" (ObservingTests eingeschlossen)
python3 .github/ci_plan.py     -> combos window | menubar | window,menubar | menubar,island | menubar,background |
                                  window,hotkeys | window,ai | window,ai,mlx | alle
Build-Matrix (je make build MODULES=…, codesign --verify --strict, --selftest headless mit eigenem Datenordner):
  starter.json (Standard)       -> ok, codesign ok, 27 checks, 0 failures
  window                        -> ok, codesign ok, 19 checks, 0 failures
  menubar                       -> ok, codesign ok, 16 checks, 0 failures
  window,menubar                -> ok, codesign ok, 20 checks, 0 failures
  menubar,island                -> ok, codesign ok, 18 checks, 0 failures
  menubar,background            -> ok, codesign ok, 17 checks, 0 failures
  window,hotkeys                -> ok, codesign ok, 22 checks, 0 failures
  window,ai                     -> ok, codesign ok, 20 checks, 0 failures
  window,ai,mlx                 -> ok, codesign ok, 21 checks, 0 failures
  alle inkl. mlx und examples   -> ok, codesign ok, 28 checks, 0 failures
  CONFIG=release                -> ok, codesign ok, 27 checks, 0 failures
check_commit_msg.py auf jeder neuen Commit-Nachricht -> alle passen
NO_BUILD=1 make shots ONLY=window.home (en, hell) -> 1 PNG, angesehen: App-Symbol aus Kit/Design, Startseite intakt
pgrep (Starter.app, run-tests, worker.py) -> nichts übrig
```

Nicht ausgeführt: `make probe` (Template-Probe, rund 4 Minuten; K hat sie auf einem Integrationsklon desselben Stands grün gemeldet), `make shots` komplett, `make dmg`, interaktive Prüfungen (App nie normal gestartet, keine Berechtigungen, kein Anmeldeobjekt).

## Bekannte Schwächen

- Die Verschmelzung von A und D im `AppDelegate` ist nur über die reinen Regeln getestet (`BackgroundLaunchTests`, `OnboardingTests`); Start, Dock-Klick und Fortsetzen nach Neustart im echten Fenster prüft die Leitung.
- `AppIconImage` zeigt auf der Startseite des Fensters das Squircle jetzt im Icon-Verhältnis (kleiner als As Fassung); nur `window.home` en-hell angesehen.
- Die Umbruch-Ausnahmen in `PermissionText.swift` setzen Ds Absicht um; die grundsätzliche Entscheidung (R8) ist im Abgleich gefallen (E-22).

## Abgleich (Reconcile) nach Welle 1

Stand: 2026-10-12, Branch `main`, Start `70daae3`. Alle offenen Punkte der Liste oben sind bearbeitet; jeder Commit hat das Format `type(scope): subject` und besteht `check_commit_msg.py --bereich 70daae3..HEAD`. Nichts gepusht. Strang I (`strang/I`, Worktree `wt/I`) ist nicht angefasst.

### Ergebnis je Punkt

| Nr. | Punkt | Stand | Was und warum |
|---|---|---|---|
| 1 | `--quelle` für private Starter | erledigt | `docs/UEBERGABE.md` nennt `bin/starter sync --quelle git@github.com:wielochyeah/mac-app-starter.git` (`02f139b`) |
| 2 | `gen_config.py`: Module ohne Ordner ablehnen | erledigt | `MODULES=island` nach `remove island` bricht mit Meldung ab, Test in `test_gen_config.py` (`803712c`) |
| 3 | `init`: `make rules`, `texts.personen`, Hinweis bei `sie` | erledigt | `init` führt `scripts/rules_sync.py` aus (Fehler als Hinweis im Bericht), leert `texts.personen`, nimmt `--anrede du\|sie` (auch als Frage) und sagt bei `sie`, dass `make check-texts` die du-Texte des Kits listet (im Starter rund 130 Stellen, alle in `*Text.swift` und `InfoPlist.json`); ohne `--non-interactive` werden `--accent`, `--symbol`, `--anrede` zu Vorschlägen der Fragen (`f356c2d`, `3bd337b`) |
| 4 | `init`: `app.tagline` | erledigt | `init` entfernt die Unterzeile des Starters und sagt im Bericht, wie eine eigene gesetzt wird; ohne Unterzeile zeigt der Willkommensschritt nur den Namen (`f356c2d`) |
| 5 | 20 Baseline-Befunde | erledigt | alle behoben, `rules/baseline/texte.json` und `design.json` sind leer (`57c3b8c`); `check_texts`/`check_design` mit `--streng` und `--ci` ohne Befund |
| 6 | R8, ausgewogene Zweizeiler | entschieden | ja, aber nur als Unterzeile direkt unter dem Titel eines Schritts oder Bereichs, an einer Satzgrenze, mit `// umbruch:` (E-22 in `docs/DECISIONS.md`); die Fälle in `PermissionText` und `PatternsText` passen dazu |
| 7 | DECISIONS für `Features.register()` und Galerie | erledigt | E-20 und E-21, dazu E-23 (Reset-Vertrag) (`6813f05`) |
| 8 | `make icon` und SF Symbols | erledigt | Wortlaut der Human Interface Guidelines geprüft („prohibition against using symbols … in app icons, logos, or any other trademarked use“). `make icon` sagt es nach jedem Lauf, `make dmg` erinnert, solange `tools/icon/Icon.swift` ein SF Symbol zeichnet; `docs/VERTEILUNG.md` nennt die zwei Wege zu einem eigenen Motiv (`d7867b3`, `300cb55`) |
| 9 | `docs/screenshots/list.txt` | erledigt | `island.done-card` gab es nicht, jetzt `island.done`; alle fünf Einträge liegen nach `make shots` in `build/shots` (`57758ef`). `make readme-shots` und die PNGs bleiben für Welle 2 (X) |
| 10 | Skill-Beispiele und `MODULE.md` typprüfen, `WindowSearch.enable`, `notchBusy`, `recording` | erledigt | jedes Swift-Beispiel aus `docs/MODULE.md`, den Skills und den Doku-Kommentaren mit `swiftc -typecheck` gegen alle Quellen geprüft (Subagent, außerhalb des Repos); neun Beispiele kompilierten nicht, sieben Angaben stimmten nicht, alle korrigiert. `neue-ansicht` erklärt `WindowSearch.enable(page:prompt:)`, `\.windowSearch`, `NoResults` und den Ersatz der Startseite; `insel-zustand` und `MODULE.md` erklären `Island.shared.notchBusy` und `.levels(…, recording: true)` (`f3af185`, `2748517`) |
| 11 | `THIRD_PARTY_NOTICES.md` | erledigt | Übernahmen aus VoiceBud je Bereich (Onboarding, Einstellungen, Fenster, Menüleiste, Hintergrund, Insel, Kurzbefehle, lokale KI, Symbol und DMG); der Satz zu „Über“ nennt jetzt `App/Resources/Notices/<lang>.md`, die die App zeigt (`495bc5d`) |
| 12 | Signier-Doku | erledigt | `docs/VERTEILUNG.md` Abschnitt 4, `release-dmg`, README und E-15: notarisiert wird über `make dmg` mit `signing.notarize: true` und `signing.notaryProfile` oder `NOTARY_PROFILE`; `make notarize` reicht nur erneut ein (`188a1a0`). `SIGN_IDENTITY` gilt jetzt auch in `make build` (`300cb55`) |
| 13 | `ai-worker/package.sh` | dokumentiert, nicht gebaut | `docs/KI.md` „MLX in einer weitergegebenen App“: Release-Builds finden Worker und Python nur im eigenen Bundle, `make dmg` legt beides nicht hinein, die App zeigt MLX als „Nicht enthalten“; was `package.sh` tun muss (eigenständiges Python, signierte Bibliotheken, `disable-library-validation` mit Entscheidung, Mindest-macOS). `make dmg` sagt es in der Ausgabe (`f347b6e`) |
| 14 | `LSHasLocalizedDisplayName` | erledigt | Info.plist mit `LSHasLocalizedDisplayName` und dem Dateinamen als Grundwert von `CFBundleDisplayName`; der übersetzte Name kommt aus `<lang>.lproj/InfoPlist.strings`. Die Zieh-Zeile des DMG nennt den Namen je Sprache (`--app-label-de`) (`e769beb`) |
| 15 | Finder dunkel, Icon-Rahmen auf macOS 26 | übersprungen | nur interaktiv, Sache der Leitung |
| 16 | `OnboardingTokens.swift` und 460-pt-Karte | erledigt | Inhalt nach `Kit/Design/Patterns/PatternTokens.swift`, `Metrics.onboardingCard = 460` als eigenes Token; Muster-Beispiel und Anmelde-Schritt nutzen es, `BackgroundMetrics` und seine Design-Ausnahme entfallen (`bdec6c6`) |
| 17 | `RenderRunner`: Breite, `autoreleasepool` | erledigt | eine gemessene Szene wird in ihrer Breite aufgerundet plus 1 pt gelayoutet, das PNG behält die gemessene Breite (Ränder bleiben deckend, Test „design scenes have opaque edges“ grün); jeder `png`-Aufruf läuft in einem eigenen Pool (`1dba864`) |
| 18 | Reset-Vertrag `window.page`, `window.sidebarHidden` | entschieden | Zustand: `SettingsReset.keep("window.")`, Test in `WindowTests`, E-23 (`5319177`) |
| 19 | `Metrics.Window.sidebar*` und `sidebarTop` | erledigt | eine `Metrics.Sidebar` in `Kit/Design/Sidebar.swift`; erster Eintrag 44 pt unter dem Panel in beiden Fenstern (Hauptfenster vorher 48 ab Fensterkante, jetzt 52); `staticSidebarPanel()` zeichnet das Panel für Einstellungen, Galerie-Beispiel und Hauptfenster (`ac4ebe9`) |
| 20 | Mindestgröße des Einstellungsfensters | erledigt | `WindowHost` hält die Mindestgröße jedes größenveränderlichen Fensters über die SwiftUI-Wurzel und misst das Werkzeugleisten-Band des Fensters (Hauptfenster 52 pt, Einstellungen 66 pt); neuer Selbsttest `settings.window` verlangt genau 760 x 500, `window.chrome` weiter 900 x 600 (`955d3e0`) |
| 21 | Login-Start nur über `Launch.isBackground` | erledigt | `LoginItem.launchedAtLogin` und `isLoginLaunch` entfernt, der Fall „reopen“ des Tests liegt jetzt bei `Launch.isLoginItemLaunch` (`0bb17d0`) |
| 22 | Kit-Kandidaten mit zwei oder mehr Bereichen | zum Teil | übernommen: `Row` dimmt gesperrte Zeilen (Hintergrund, Insel), `Theme.strikeText` als textfähiges Rot mit Kontrasttest (Kit, Kurzbefehle, KI), `Metrics.disabledOpacity` (Kit, Fenster), `Registry.onboardingFinishedHooks` (Fenster, Hintergrund), das Seitenleisten-Panel (Einstellungen, Fenster), `InlineNotice(actionBelow:)` für schmale Karten (`2defbc0`, `c62fc80`, `81fb60b`). Übersprungen, weil nur ein Bereich sie nutzt: `Motion`-Sekunden für AppKit (nur das Menüleisten-Panel; die Ausblendzeiten der Insel gehören zu ihrer Choreografie), `IslandLook` (nur die Insel, geht mit `remove island`), `BigKeyCaps` (nur Kurzbefehle), gemeinsame Symbolgröße von `Row` und `ProgressRow` (nur der Bereich „Modelle“ mit `mlx` mischt beide; 4 pt Versatz bleibt dort), `WindowTokens`, `PageScroll`, `Artwork`, `ProgressRow.notStarted`, `AIWait`, Eingabefeld der KI, Unterleiste der Galerie, destruktiver Knopfstil |
| 23 | Welle 2 (B) | übersprungen | gehört zum Beispielstrang |
| 24 | Fehlalarm `--` in `models--org--name` | erledigt | der doppelte Bindestrich ohne Leerzeichen zählt nur noch zwischen genau zwei Wörtern (`alt--neu`, auch vor einem Punkt), nicht in Pfaden und Namen; Beispiele im Paket und Tests in `test_check_texts.py` (`dc8b4ac`) |

### Weitere Korrekturen

- **Doku gegen den Code (Punkt 3 des Auftrags):** ein Subagent hat README, `CLAUDE.md` Teil B und die Werkzeug-Tabelle, `AGENTS.md`, `CONTRIBUTING.md`, alle `docs/*.md`, `tools/README.md`, `App/Sources/Features/README.md` und die CI-Dateien Satz für Satz gegen Code, Makefile und Skripte geprüft, ein zweiter die Skills, Subagenten und `docs/MODULE.md`. 25 und 16 Abweichungen, alle behoben (`ea4a29a`, `a1318cf`, `f3af185`, `2748517`), darunter: `--permission-probe` und `--background` fehlten in `ARCHITEKTUR.md`, `--demo` stand bei den Werkzeug-Flags, `index.html` entsteht nur bei vollständigem Lauf, `Package.swift` wird nicht laufend geprüft, `requirements.lock` statt `requirements.txt`, Python 3.11 bis 3.13, der „Dennoch öffnen“-Hinweis gilt für jedes nicht notarisierte DMG, die Werkzeug-Tabelle nennt `SelfTestRunner` und alle Befehle von `bin/starter`.
- **Renders (Punkt 5):** `make shots` komplett (640 PNGs), Kontaktbögen je Bereich in en-hell und de-dunkel angesehen, dazu Einzelbilder. Behoben: die Freigabe-Notiz im Schritt „Mit dem Mac starten“ quetschte den deutschen Text neben dem Knopf in vier kurze Zeilen (jetzt Knopf unter dem Text); `island.pane` endete auf Deutsch an der Bildkante (Szene 40 pt höher). `island.done-hover` ist nicht abgeschnitten: die Karte hängt wie die echte Insel an der Bildschirmkante, und der lange Beispieltext läuft auf Deutsch bewusst in die Ausblendkante (scrollbar, Absicht von C).
- `CHANGELOG.md`: Hinweise für Projekte zu `init`, Finder-Namen, Notarisierung und `mlx` (`1cc0ec8`).

### Geänderte öffentliche APIs (für Strang I beim Merge von `main`)

- `Metrics.Window.sidebarMin`, `sidebarIdeal`, `sidebarMax`, `sidebarInset`, `sidebarTop`, `sidebarRow`, `sidebarSymbol`, `sidebarSymbolColumn`, `sidebarContentInset`, `sidebarSectionTop`, `sidebarSectionHeight` heißen jetzt `Metrics.Sidebar.minWidth`, `Metrics.sidebarWidth`, `Metrics.Sidebar.maxWidth`, `.panelInset`, `.top` (44 ab Panel), `.listRow`, `.symbol`, `.symbolColumn`, `.contentInset`, `.sectionTop`, `.sectionHeight`.
- `Metrics.Window.disabledOpacity` heißt `Metrics.disabledOpacity`.
- Entfernt: `LoginItem.launchedAtLogin`, `LoginItem.isLoginLaunch` (statt dessen `Launch.isBackground`, `Launch.isLoginItemLaunch`), `LoginWish.watch()`, `BackgroundMetrics.stepCard` (statt dessen `Metrics.onboardingCard`).
- `Kit/Onboarding/OnboardingTokens.swift` gibt es nicht mehr; dieselben Namen stehen in `Kit/Design/Patterns/PatternTokens.swift`.
- `MainWindowController.content(model:)` setzt keinen Mindestrahmen mehr und `configure` keine Größenoptionen; das tut `WindowHost` für jedes größenveränderliche Fenster.
- Neu: `Registry.onboardingFinishedHooks`, `Theme.strikeText`, `Metrics.disabledOpacity`, `Metrics.onboardingCard` (jetzt 460 fest), `View.staticSidebarPanel()`, `WindowHost.make(…)`, `InlineNotice(…, actionBelow:)`, `RenderRunner.layoutWidth(measured:)`, `SettingsController.checkWindow()`.
- Verhalten: `Row` dimmt gesperrte Zeilen; „Einstellungen zurücksetzen“ behält `window.*`; nach „Fertig“ öffnet das Hauptfenster über den Hook des Fenster-Moduls statt über `OnboardingWindow`.

### Prüfung (2026-10-12, auf dem Stand dieses Berichts)

```
make check                     -> grün (1:06 min): rules_sync gültig; check_texts 286 Dateien, keine Befunde;
                                  check_design 187 Dateien, keine Befunde; Baselines leer ({}); check-kit: Starter,
                                  alle Dateien klassifiziert (Kit 274, gemeinsam 63, Projekt 16, nur im Starter 14),
                                  8 von 8 Modulen entfernbar, Hooks und CI erfüllt; Build; Swift "355 tests, 0 failures",
                                  scripts/tests 220 OK, scripts/starter/tests 118 OK, ai-worker 23 OK
check_texts/check_design mit --ci und --streng -> keine Befunde
check_commit_msg.py --bereich 70daae3..HEAD    -> Autor und Format aller Commits passen
MODULES=menubar make test      -> Swift "165 tests, 0 failures", Python OK
MODULES=<alle inkl. mlx> make test -> Swift "386 tests, 0 failures", Python OK
python3 .github/ci_plan.py     -> combos window | menubar | window,menubar | menubar,island | menubar,background |
                                  window,hotkeys | window,ai | window,ai,mlx | alle
Build-Matrix (je make build MODULES=…, codesign --verify --strict, --selftest headless mit eigenem Datenordner):
  starter.json                  -> ok, codesign ok, 28 checks, 0 failures
  window                        -> ok, codesign ok, 20 checks, 0 failures
  menubar                       -> ok, codesign ok, 17 checks, 0 failures
  window,menubar                -> ok, codesign ok, 21 checks, 0 failures
  menubar,island                -> ok, codesign ok, 19 checks, 0 failures
  menubar,background            -> ok, codesign ok, 18 checks, 0 failures
  window,hotkeys                -> ok, codesign ok, 23 checks, 0 failures
  window,ai                     -> ok, codesign ok, 21 checks, 0 failures
  window,ai,mlx                 -> ok, codesign ok, 22 checks, 0 failures
  alle inkl. mlx und examples   -> ok, codesign ok, 29 checks, 0 failures
  CONFIG=release                -> ok, codesign ok, 28 checks, 0 failures
make probe (2:44 min)          -> "Ran 6 tests … OK": init grün, remove je Modul grün, ai vor mlx abgelehnt,
                                  menubar nach window abgelehnt, erstes Feature hält check-kit grün
Kopie mit init --non-interactive --anrede sie --ohne-netz --ohne-build:
                                  Bericht nennt Tagline, make rules (Anrede sie) und den Hinweis zu sie; check-rules
                                  gültig; check-texts listet 127 du-Stellen, alle in *Text.swift und InfoPlist.json;
                                  check-kit 275 Kit-Dateien unverändert
bin/starter strip-examples in dieser Kopie -> Build grün, --selftest 28 checks 0 failures, check-kit grün,
                                  keine Reste von Modules/Examples
make shots                     -> 640 PNGs + index.html (160 Szenen); angesehen: Kontaktbögen aller Bereiche en-light
                                  und de-dark, Einzelbilder island.done-hover de-dark, window.main en-light,
                                  settings.window de-dark, background.pane-unavailable de-light,
                                  hotkeys.recorder-states en-light, background.onboarding-approval de-dark,
                                  patterns.inline-notice de-light, island.pane de-dark (unterer Rand)
pgrep (Starter.app, run-tests, worker.py) -> nichts übrig
```

### Bekannte Schwächen des Abgleichs

- Das Werkzeugleisten-Band des echten Einstellungsfensters misst 66 pt (`contentLayoutRect`), Kopfband und Seitenleiste sind auf 52 pt gestaltet. Ob Ampeln und Kopfband im echten Fenster auf einer Linie sitzen, prüft die Leitung interaktiv.
- Die Mindestgrößen sind nur im unsichtbaren Fenster gemessen (Selbsttests), nicht durch Ziehen am echten Fenster.
- Finder mit `LSHasLocalizedDisplayName` nicht angesehen; laut Apple zeigt Finder den übersetzten Namen nur, solange das Bundle seinen Dateinamen behält.
- Die README-Bilder fehlen noch (`make readme-shots` in Welle 2); bis dahin zeigen die fünf Bildverweise in `README.md` ins Leere.
- Im Bereich „Modelle“ mit `mlx` stehen die Texte von Anbieter- und Modellzeilen weiter 4 pt versetzt (Punkt 22, übersprungen).
- `make dmg` und `make notarize` nicht ausgeführt (kein Developer-ID-Zertifikat, keine Notarisierung ohne Auftrag); geprüft sind die Skripte über `test_packaging.py` und `zsh -n`.

## Welle 2: Beispiele, Querverbindungen, Fassung 1.0.0

Stand: 2026-10-13, Branch `main`, Start `16e1db6`. Strang I ist zusammengeführt, die Befunde aus seinem Statusbericht sind in Skills, Doku und Kit eingearbeitet, Abschnitt X aus WAVE2.md (Begrüßung mit Insel, README-Rundgang, CHANGELOG 1.0.0) ist gebaut. Nichts gepusht.

### Merge von Strang I

- `86076b9` chore(merge): keine Konflikte. Strang I hatte `main` nach dem Abgleich schon hereingeholt (Merge-Basis `188a1a0`) und baut gegen `Metrics.Sidebar`, `Metrics.disabledOpacity`, `Launch` und `PatternTokens`; im Ordner `Modules/Examples` steht keiner der umbenannten oder entfernten Namen (`Metrics.Window.sidebar*`, `LoginItem.launchedAtLogin`, `isLoginLaunch`, `LoginWish.watch()`, `BackgroundMetrics`, `OnboardingTokens`). `Metrics.Window.tile` und `heroHeightCompact` gibt es weiter im Fenstermodul. Eine Anpassung war nicht nötig.
- Drei Commits auf `strang/I` (`5288ec0`, `662f17f`, `4cb1eb1`) sind Kopien von Commits, die auf `main` danach umformuliert wurden. `5288ec0` hat 102 Zeichen im Betreff; `check_commit_msg.py --bereich 16e1db6..HEAD` meldet ihn. Nicht umgeschrieben (fremder Branch); die CI prüft auf `main` den Bereich `origin/main..HEAD` und sieht ihn nach dem Push nicht. Ab `86076b9` bestehen alle Commits die Prüfung.

### Commits nach dem Merge

| Commit | Inhalt |
|---|---|
| `fc607d4` test(packaging) | `test_packaging.py` las die echte `starter.json` und erwartete den Namen „Starter“: nach `bin/starter init` war `make check` in jedem Projekt rot (gefunden mit init und strip-examples in einer Kopie; der Job `Template-Probe` der CI wäre daran gescheitert). Jetzt mit fester Konfiguration; der Bundle-Test sucht `build/<Name>.app` |
| `113468a` feat(design) | `Chip` liest `isEnabled` und dimmt auf `Metrics.disabledOpacity` wie Schalter, Knöpfe und `Row`; die KI-Knöpfe der Notizen setzen die Deckkraft nicht mehr selbst; `design.chip` zeigt einen gesperrten Chip |
| `a4e3d52` feat(patterns) | `ConfirmRow`: Rückfrage an Ort und Stelle (Abbrechen ist Hauptaktion und liegt auf Esc, die Aktion rot auf ruhigem Knopf). Ersetzt die zwei Kopien in „Allgemein“ und im Bereich „Notizen“; Szene und Galerie `patterns.confirm-row`, DESIGN.md, `neue-einstellung` |
| `2e1a412` feat(window) | `AppActions.openMainWindow(page:)`: der Handler bekommt die Seite, das Fenstermodul wählt sie (`WindowModule.open`) und zeigt das Fenster; ohne Modul `window` wie bisher die Einstellungen. `NotesNavigator.show` nutzt es; Test |
| `623c15b` feat(menubar) | Die Bühne der Panel-Szenen heißt `MenuBarPanelStage` und ist für Features offen; `examples.menubar` steht jetzt mit Menüleiste wie `menubar.panel` |
| `6cdbeb4` docs | die echte `#if`-Regel (siehe Punkt a) in `neues-feature`, ARCHITEKTUR, CONTRIBUTING, E-07, `pruefer-integration`, Kommentar in `Modules.swift` |
| `058e3a2` docs(skills) | Punkte b bis h |
| `2e8bcc6` docs(module) | Punkt i |
| `89e3ba0` ci | sechs Kombinationen mit `examples` in `.github/ci_plan.py` (jeder `#if`-Teil des Beispiels mit nur seinem Modul); fallen nach `strip-examples` weg. Test in `test_claude_harness.py`, UEBERGABE und ci.yml nennen rund 27 Mac-Jobs |
| `59f0ec7` feat(island) | Begrüßung mit der echten Insel (Abschnitt X) |
| `8ba3b3b` feat(examples) | die Insel der Begrüßung sichert mit dem Beispiel eine Schnellnotiz |
| `834f454` fix(dmg) | das DMG-Fenster trennte Version und Mindest-macOS und die zwei Sprachen der Gatekeeper-Frage mit Mittelpunkten (S-01), der Pfad nutzte `›`; jetzt Komma, Abstand im Layout und `>` |
| `d785801` feat(shots) | `scripts/readme-shots.sh` statt der Schleife im Makefile: verkleinert mit `sips` auf höchstens 1200 px (`README_MAX_WIDTH`), zeichnet `tools/icon.png` und `tools/dmg.png` mit den Werkzeugen aus `tools/`; Skill `screenshots` |
| `fbe9e6b` docs(readme) | Rundgang mit zwölf Bildern, Stand-Block 1.0.0 |
| `8977841` docs(changelog) | Abschnitt 1.0.0 (12.10.2026) |

### Befunde aus dem Statusbericht von Strang I

| Punkt | Stand | Was |
|---|---|---|
| a) „nie verschachtelt“ | erledigt | Regel wie T-03: genau ein Flag je `#if`, ohne `\|\|`, `&&`, `!` und `#elseif`, ein `#else`-Zweig bleibt stehen, für zwei Module zwei einfache Blöcke ineinander; `bin/starter remove` und `make check-kit` lösen beide auf (`6cdbeb4`) |
| b) `hintergrund-job` | erledigt | Anmelden im Start-Hook mit `guard !RenderMode.isHeadless, !RenderMode.isStatic` (sonst entsteht `background.sqlite` bei `--selftest`), Kit-`Database` nur auf dem MainActor über `await MainActor.run`, eigene `BackgroundJobs` mit `MemoryJobStore` und `NoJobScheduler` für Tests und Szenen |
| c) `neues-feature` headless | erledigt | geteilte Speicher bleiben headless im Speicher (`window.chrome` zeichnet das echte Fenster), Beispiel `shared` mit `RenderMode.isHeadless ? nil : Paths.database(…)` |
| d) `neue-ansicht` | erledigt | `WindowSearch.enable` stand schon da; neu: Renders über `RenderBoard { StaticMainWindow(…) }`, `ViewThatFits` braucht `idealWidth`, Detailseite über einer Liste mit Navigator und `AppActions.openMainWindow(page:)` (neu im Kit, `2e1a412`) |
| e) `ki-funktion` | erledigt | `structured` nur über Apples Anbieter, Auslesen als eigene Funktion, Test über `GeneratedContent(json:)`, Testdouble für den Fehlerweg `.unsupported` |
| f) `insel-zustand` | erledigt | Szenen über `IslandScenes.Sample` und `IslandScenes.stage(_:kind:)` (Zähler, „Dauert länger“, Aufklappen), Ergebniskarte hat Kopieren schon, nur ohne Ausklappen als Aktion; dazu `IslandWelcome.working`/`result` |
| g) `menueleisten-app` | erledigt | `Registry.menuItems` stehen schon unter „Aktionen“, eigener Abschnitt über `MenuBarSection`, Szenen auf `MenuBarPanelStage` (Kit-Änderung `623c15b`) |
| h) `kurzbefehl` | erledigt | Tests leiten Bereich und Schritt aus `HotkeyCenter.shared` ab (wie `HotkeysSceneTests` seit Strang I), eigene Szene mit `HotkeyCenter(backend: FakeHotkeyBackend(), store: MemoryHotkeyStore())` und `TableKeyboardLayout.us` |
| i) `docs/MODULE.md` | erledigt | Abschnitt `examples` mit Dateien, Einstellungen (`notes.defaultCollection`, `notes.layout`), drei Karten im Schritt „Funktionen“ statt eigenem Schritt, Szenen, Selbsttests, Demo |
| Kit-Kandidaten | zum Teil | übernommen: `Chip` dimmt gesperrt, `ConfirmRow` (zwei Bereiche), `openMainWindow(page:)`, `MenuBarPanelStage`. Offen: `ValueRow(capsule:)` bei zweistelligen Werten (von I nicht untersucht, hier auch nicht), Warten auf async in Tests ohne Modul `ai` (Harness) |

Jedes neue Swift-Beispiel in Skills und Doku-Kommentaren ist mit `swiftc -typecheck` gegen alle Quellen geprüft (Stubs für die erfundenen Feature-Namen, außerhalb des Repos): keine Fehler, keine Warnungen.

### Abschnitt X

- **Begrüßung:** `Registry.welcomeArt` (Kit) lässt ein Modul das Bild des Begrüßungsschritts ersetzen; ohne Eintrag bleiben Akzentschein und App-Symbol. Das Insel-Modul setzt es in `IslandWelcome.register()`: Bildschirmrand mit Menüleiste (App-Name links, WLAN und 9:41 rechts, die Mitte für die ganze Karte frei) und gezeichneter Notch, darauf die echten Insel-Ansichten mit eigenem Modell. In der laufenden App wächst die Insel aus der Notch, arbeitet, wird zur Ergebniskarte und faltet sich zurück, solange der Schritt zu sehen ist (`.task`); Renders und reduzierte Bewegung zeigen die Karte still. Ohne Beispiel meldet die Karte „Fertig, <App>: Hier meldet <App>, was erledigt ist.“, mit Beispiel eine gesicherte Schnellnotiz. Statt `#if MODUL_ISLAND` im Onboarding-Code ein Hook: das Kit kennt kein Modul (ARCHITEKTUR), und der Code liegt im Ordner des Moduls, der nur mit `MODUL_ISLAND` gebaut wird.
- **README:** `docs/screenshots/list.txt` mit zwölf Bildern (Übersicht, Notizseite mit KI, aufgeklappte Inselkarte, Menüleisten-Panel, Begrüßung, Sprache, Neustart-Schritt, Einstellungen „Allgemein“, „Insel und Kapsel“, „Modelle“, DMG-Fenster, App-Symbol), je höchstens 1200 px, zusammen 4,0 MB. Rundgang auf Deutsch, ein Satz je Bild.
- **CHANGELOG:** Abschnitt 1.0.0 (12.10.2026) mit Inhalt, Migrationen (keine) und Hinweisen für Projekte; `starter.json` `starter.version` bleibt 1.0.0.
- **Stand-Block:** Fassung 1.0.0 vom 12.10.2026, Bauunterlagen unter `docs/bau/`, `init` entfernt sie.

### Prüfung (2026-10-13, auf `8977841`)

```
make check                       -> grün (1:20 min): rules_sync gültig; check_texts 307 Dateien, keine Befunde;
                                    check_design 208 Dateien, keine Befunde; check-kit: alle Dateien klassifiziert
                                    (Kit 295, gemeinsam 64, Projekt 28, nur im Starter 15), 8 von 8 Modulen entfernbar,
                                    Hooks und CI erfüllt; Build; Swift "392 tests, 0 failures", scripts/tests 220 OK,
                                    scripts/starter/tests 118 OK, ai-worker 23 OK
check_texts/check_design --ci und --streng -> keine Befunde
check_commit_msg.py --bereich 86076b9..HEAD -> alle passen (5288ec0 davor, siehe Merge)
MODULES=<alle inkl. mlx> make test -> Swift "423 tests, 0 failures", Python OK
STARTER_HEADLESS=1 STARTER_DATA_DIR=<tmp> …/Starter --selftest -> "30 checks, 0 failures", Datenordner leer
python3 .github/ci_plan.py       -> 15 Kombinationen (9 bisherige, 6 mit examples)
Build-Matrix in einer Kopie von HEAD (je make build, codesign --verify --strict, --selftest headless, eigener Datenordner):
  starter.json                   -> 0 Warnungen, codesign ok, 30 checks, 0 failures, Datenordner leer
  window                         -> 0 Warnungen, codesign ok, 20 checks, 0 failures, leer
  menubar                        -> 0 Warnungen, codesign ok, 17 checks, 0 failures, leer
  window,menubar                 -> 0 Warnungen, codesign ok, 21 checks, 0 failures, leer
  menubar,island                 -> 0 Warnungen, codesign ok, 19 checks, 0 failures, leer
  menubar,background             -> 0 Warnungen, codesign ok, 18 checks, 0 failures, leer
  window,hotkeys                 -> 0 Warnungen, codesign ok, 23 checks, 0 failures, leer
  window,ai                      -> 0 Warnungen, codesign ok, 21 checks, 0 failures, leer
  window,ai,mlx                  -> 0 Warnungen, codesign ok, 22 checks, 0 failures, leer
  window,examples                -> 0 Warnungen, codesign ok, 22 checks, 0 failures, leer
  menubar,examples               -> 0 Warnungen, codesign ok, 19 checks, 0 failures, leer
  menubar,island,examples        -> 0 Warnungen, codesign ok, 21 checks, 0 failures, leer
  window,ai,examples             -> 0 Warnungen, codesign ok, 23 checks, 0 failures, leer
  menubar,hotkeys,examples       -> 0 Warnungen, codesign ok, 22 checks, 0 failures, leer
  window,background,examples     -> 0 Warnungen, codesign ok, 23 checks, 0 failures, leer
  menubar,ai,examples            -> 0 Warnungen, codesign ok, 20 checks, 0 failures, leer
  alle inkl. mlx und examples    -> 0 Warnungen, codesign ok, 31 checks, 0 failures, leer
  CONFIG=release                 -> 0 Warnungen, codesign ok, 30 checks, 0 failures, leer
make probe (2:47 min)            -> "Ran 6 tests … OK": init grün, remove je Modul grün, ai vor mlx abgelehnt,
                                    menubar nach window abgelehnt, examples entfernt
Kopie (git ls-files, git init, Commit), bin/starter init --non-interactive --name Probe --ohne-netz --ohne-build,
dann bin/starter strip-examples -> 20 Dateien gelöscht, Blöcke in Modules.swift und Markierungen in neues-feature,
                                    neue-ansicht, hintergrund-job und MODULE.md entfernt, ExamplesTests.swift gelöscht;
                                    make build grün, --selftest 28 checks 0 failures (Datenordner leer), make check grün
                                    (check-kit: 276 Kit-Dateien unverändert seit 1.0.0; Swift 357 tests, Python 220/118/23 OK);
                                    git grep NotesStore|NoteItem|NotesText|Notizen|ExamplesModule|MODUL_EXAMPLES|Modules/Examples:
                                    nur Doku-Beispiele, die es vor Strang I gab (neue-einstellung, Kommentare im Kit,
                                    Wortlisten), sowie README-Rundgang und CHANGELOG (siehe Schwächen)
make shots                       -> 744 PNGs + index.html (186 Szenen)
make readme-shots                -> 12 Bilder, je höchstens 1200 px, zusammen 4,0 MB
pgrep (Starter.app, Probe.app, run-tests, worker.py) -> nichts übrig
```

Angesehen (Read): jede Szene `examples.*` (25) und `onboarding.*` (14) in en-light und de-dark, als Kontaktbögen zu je vier Bildern; einzeln `onboarding.welcome` in allen vier Fassungen und zusätzlich mit `MODULES=window,island` (neutrale Karte, en-light, de-dark, de-light) und `MODULES=window` (Akzentschein, de-light), `patterns.confirm-row` de-dark, `settings.general-reset` en-light, `design.chip` de-light, `examples.menubar` de-dark, `examples.pane-confirm` de-dark, `examples.detail-unavailable` en-light, jedes der zwölf README-Bilder. Behoben nach dem Ansehen: Statussymbole der gezeichneten Menüleiste lagen unter der Karte (Mitte jetzt so breit wie die Karte, ohne Akku), deutscher Text der neutralen Karte und der Notiz-Text liefen in die Auslassung (kürzere Texte), Mittelpunkte und `›` im DMG-Fenster.

### Bekannte Schwächen

- Die Schleife der Begrüßungsinsel ist nie in der laufenden App gesehen worden (T-08): Zeiten und Federn sind nur im Code und im Modell geprüft (Test: Standbild, geschlossener Start, reduzierte Bewegung). Die Leitung sieht sie beim ersten `make run`.
- Der README-Rundgang und die Bilder in `docs/screenshots/` zeigen das Beispiel; nach `init` und `strip-examples` bleiben sie im Projekt, bis es README und `list.txt` ersetzt (Hinweis im CHANGELOG). `make readme-shots` scheitert dort an den fehlenden Szenen `examples.*`, bis die Liste angepasst ist.
- `make probe` führt nach `init` kein `make check` aus; deshalb blieb der Fehler in `test_packaging.py` bis jetzt unbemerkt. Die CI (`Template-Probe`) tut es.
- Betreff von `5288ec0` mit 102 Zeichen in der Geschichte von `main` (siehe Merge).
- Die CI baut jetzt rund 27 Mac-Jobs je Pull Request und auf `main` (sechs mehr für das Beispiel).
- Offen aus Strang I und nur interaktiv prüfbar: Fenster mit echter Seitenleiste und Suche, Editor mit Autosave und Esc, ⌥-Klick im Panel, die echte Insel bei Schnellnotiz und KI, der Kurzbefehl aus anderen Apps, die Aufgabe im echten Planer, „Im Finder zeigen“, `--demo examples`.
- Kit-Kandidaten `ValueRow(capsule:)` und das Warten auf async in Tests ohne Modul `ai` sind nicht bearbeitet.

## Prüfrunde und Korrekturen

Stand: 2026-10-13, Branch `main`, Start `2133257`. Das Abschlussreview vor 1.0.0 ging an drei Fix-Stränge: F1 (Werkzeuge, CI, Regeln für Agenten, Sicherheit, Aufbau des README), F2 (App-Code, Laufzeit, Sicherheit in der App, Gestaltung), F3 (Texte, Textregeln, Wortlaut der Doku). Ihre Statusberichte stehen in `docs/bau/status/F1.md`, `F2.md` und `F3.md`. Hier: Merge, Abgleich zwischen den Strängen und die Prüfung mit beiden Toolchains. Nichts gepusht.

### Was gefunden wurde und wer es behoben hat

| Bereich | Befunde | Strang |
|---|---|---|
| Werkzeuge und CI | Hooks liefen nur mit zsh auf einem Mac (Cloud-Agenten konnten nicht pushen), jede Änderung baute auf Macs, eine Vorlagen-Kopie galt als Starter, falscher Bereich der Commit-Prüfung, Warnungen nicht als Fehler, der Starter trug eine Commit-Identität, Make-Variablen konnten Befehle ausführen, Allow-Regeln mit `*`, Reste des Starters in neuen Projekten, Renders zeigten nur Muster statt des Projekts | F1 |
| Sicherheit der Werkzeuge | MLX-Pakete ohne Hashes, Actions nicht auf Commits festgelegt, Zertifikate und `.env` nicht in `.gitignore`, eingebetteter Code ohne eigene Entitlements, `com.example.*` mit Developer ID, Anweisungen von origin ungeprüft | F1 |
| Laufzeit | „Zur Notiz hinzufügen“ und „Titel übernehmen“ gingen verloren, Zurücksetzen erreichte die Hintergrundaufgaben nicht, Papierkorb verwarf Getipptes, hängender MLX-Worker blockierte, Werkzeugläufe ohne `STARTER_HEADLESS` öffneten echte Daten, zwei Prozesse migrierten gleichzeitig, Einrichtung öffnete nach entzogener Berechtigung bei jedem Start | F2 |
| Sicherheit in der App | Kopien aus Passwortmanagern gesichert, gelöschte Notizen in Datei und WAL lesbar, Protokoll mit Inhalten als `.public`, Modelle in Time Machine | F2 |
| Gestaltung | Nebentext 3,55:1, Info-Hinweise im Akzent, Artwork als Lila-Fläche, fehlende Einleitungszeilen, abgeschnittene Fensterkanten und Karten, leere Zustände oben, Statusfarben uneinheitlich | F2 |
| Texte | sechs Wörter für Berechtigung, Versprechen in Nutzungsbeschreibungen, Floskeln, uneinheitliche Begriffe (Einrichtung, Taste, Tastaturkurzbefehle, Statusmenü), Anführungszeichen, Einheiten, US-Englisch, Title Case, kurze Imperative (T1 bis T22); Regellücken R1 bis R5 (DMG-Texte, feste Begriffe, Anführungszeichen, Einheiten, Notices) | F3 |

### Merge

| Commit | Branch | Konflikte | danach |
|---|---|---|---|
| `a34cf3d` | `fix/F1` (28 Commits) | keine, `main` stand noch auf dem Abzweig | `make build` grün, `make test`: Swift 392 Tests, 0 Fehler; Python 248, 137, 28 OK |
| `58343a2` | `fix/F2` (23 Commits) | keine, F1 und F2 teilen keine Datei | `make build`, `make test`: 408 Tests, 0 Fehler; Python 248, 137, 28 OK; `check-rules`, `check-texts`, `check-design`, `check-kit` grün |
| `20ff541` | `fix/F3` (10 Commits) | 8 Dateien, unten | `make build`, `make test`: 408 Tests, 0 Fehler; Python 252, 137, 28 OK; `check_texts --streng` ohne Befund |

Konflikte beim Merge von F3, gelöst mit beiden Absichten:

- `README.md`: Aufbau von F1 (Bootstrap-Prompt und „Wann ein Projekt fertig ist“ in `docs/UEBERGABE.md`, Einleitung bis „Ein neues Projekt starten“ nur im Starter), Begriffe von F3.
- `docs/UEBERGABE.md`: Text von F1 (init mit `--non-interactive`, Anrede Sie, Tabelle der Reste) mit F3s „Begrüßungsschritt“ und „Nutzungsbeschreibungen“ samt Hinweis auf `make check-texts`; in §9 „Einrichtung“ und „erlaubt“.
- `App/Sources/Modules/Island/IslandText.swift`: F2s gemeinsame Schlüssel (`CommonText.islandAtNotch`, `CommonText.capsule`) und Hinweise mit höchstens drei Wörtern, F3s schmale Leerzeichen im langen Beispiel.
- `docs/DESIGN.md`: Inhalt von F2 (`fg3` nur für Platzhalter, Einleitungszeile, neutrale Info-Hinweise, `footnoteReserve`, Artwork als vierte Verlaufsfläche) im Wortlaut von F3 (Einrichtung, Statusmenü, Taste, widerrufen, Tastaturkurzbefehl).
- `docs/MODULE.md`, `docs/ARCHITEKTUR.md`, `tools/README.md`, Skill `neue-einstellung`: Inhalt von F1 (`.project`-Szenen, `#if`-Regel mit `check-design`, `tools/entitlements-map.json`, `order: 100`) im Wortlaut von F3.

### Abgleich nach dem Merge

| Punkt | Ergebnis | Commit |
|---|---|---|
| Neue und geänderte Texte von F2 gegen die Regeln von F3 | `SettingsText.generalIntro`, `IslandText.paneIntro`, `NotesText.clipboardConcealed`, `NotesText.clipboardEmpty`, `DesignText.failedBadge`, `CommonText.capsule` und die gekürzten Inselbeispiele bestehen jede Regel (`check_texts --streng` ohne Befund). Geändert: `CommonText.islandAtNotch` „Island at the notch“ (Kacheln in Satzschreibung wie „Ring and dot“, Entscheidung T14 von F3), Warnbeispiel „Only 2 GB free“ / „Nur 2 GB frei“ statt „Disk almost full“ (S-07: Zahl statt Adjektiv, weiter drei Wörter), `generalIntro` englisch „right away“ statt des doppeldeutigen „at once“ | `ce95642` |
| `PermissionText.firstUse` (F3 an F2) | entfernt: das lokale Netzwerk hat keinen Einrichtungsschritt, der Text hatte keinen Aufrufer | `ce95642` |
| Offene Punkte von F3 an F1 | `starter.manifest.json`: „im Stil von Musik“, Werkzeugleiste, Statusmenü, „Anmeldeobjekte & Erweiterungen“, Modultitel „Tastaturkurzbefehle“, „Einrichtungsschritt“; Bericht von init „Begrüßungsschritt“; Hinweis von check-kit „die Einrichtung zeigt noch keine Funktionskarte“; Tagline in `scripts/starter/tests/helpers.py` wie in `starter.json`; PR-Vorlage „Nutzungsbeschreibung“ | `649fc1c` |
| Begriffe in Texten, die F1 neben F3 schrieb | Skills `kurzbefehl`, `neuer-onboarding-schritt`, `neues-feature`, `screenshots`, `docs/MODULE.md`, `docs/ARCHITEKTUR.md`, beide `PLAN.md`-Vorlagen, `THIRD_PARTY_NOTICES.md`. `CLAUDE.md` Teil B zeigte auf den Bootstrap-Abschnitt im README, den es in einem Projekt nicht mehr gibt; jetzt `docs/UEBERGABE.md`, Abschnitt 4 | `b4dfaea` |
| F1 #8 Reihenfolge in der Registry | „Menüleiste“ 300 (geteilt mit „Modelle“) auf 250, „Hintergrund“ 310 auf 350, Beispiel in `SettingsKit` 100, wie `docs/MODULE.md`. `Registry.problems()` meldet zwei Einstellungsbereiche einer Gruppe oder zwei Einrichtungsschritte mit demselben `order`; Test in `RegistryTests`, wirkt im Selbsttest `kit.registry` jeder Modul-Kombination. Die Seitenleiste zeigt jetzt Insel und Kapsel, Menüleiste, Modelle, Hintergrund, Tastaturkurzbefehle | `041687b` |
| F1 m6 FAIL-Zeilen im grünen `make check` | `SelfTestRunner.run(only:report:)` (Standard: Fehler nach stderr, Summe nach stdout) und `PermissionProbe.answer(_:refused:)`; die Negativtests sammeln die Zeilen und prüfen sie wörtlich. Die Ausgabe von `make check` hat keine Zeile „selftest FAIL“ oder „cannot be probed“ mehr | `bf85812` |
| F1 m9 `Settings.inMemory()` | klein genug für Kit/Core: liest und schreibt nie eine Datei, startet mit den Standardwerten. Ersetzt die festen Temp-Dateien in `MenuBarScenes`, `BackgroundScenes` und der Notizen-KI-Szene (ein früherer Lauf hätte dort Werte hinterlassen können); Test, Hinweis im Skill `neue-einstellung` | `c7c7062` |
| F1 #5 Allow-Liste | nicht angefasst, für die Leitung | |
| F1 Anfrage 7 an F3 | Bezeichnung von `modul-bedingung`: „Modul-Bedingung, die T-03 nicht erlaubt“, `make rules` | `9825c7a` |
| `Package.swift` mit Xcode 27 | `swift build` brach ab („defaultLocalization not set“): der Zielpfad ist die Wurzel, SwiftPM nahm `build/gen/Resources/*.lproj` als Ressourcen und warnte über 207 weitere Dateien. Das Manifest schließt jetzt jeden Eintrag aus, der weder Quellordner ist noch auf dem Weg zu einem liegt. `docs/ARCHITEKTUR.md` sagt, wie der Weg geprüft ist | `1bd4420`, `9f94e39` |
| Render `island.pane` | F2s Einleitungszeile und die eigene Gruppe der Fußnote machten den deutschen Bereich rund 50 pt höher; die Szene (800 pt) schnitt die Gruppe „Vorschau“ ab, auch im README-Bild. Jetzt 850 pt | `3d61613` |
| Mustertexte | die Musterszenen nannten hell/dunkel „Darstellung“, „Allgemein“ sagt „Erscheinungsbild“ (S-15); „Darstellung“ bleibt für die Form der Insel mit eigenem Schlüssel. Sieben Texte ohne Aufrufer entfernt (`PatternsSampleText.islandDetail`, `capsuleDetail`, `grantedHint`, `restartHint`, `appearanceSubtitle`, `appearanceFootnote`, `NotesText.galleryEditor`) | `9fe6c78` |
| README | Wortlaut nach dem Umbau: Build mit Command Line Tools oder Xcode, was init mit den Bildern tut, was „Allgemein“ und „Modelle“ zeigen, `make run` nur für die Person am Mac, Datum 13.10.2026, kurze Sätze im Startabschnitt | `6fd44aa` |
| README-Bilder | `make shots`, `make readme-shots`, jedes der zwölf Bilder angesehen (unten) | `1aa9cb1` |
| CHANGELOG | 1.0.0 (13.10.2026) mit den Korrekturen der Prüfrunde in Inhalt und Hinweisen für Projekte, Begriffe wie in der App | `3efcfba` |

### Prüfung (2026-10-13, auf `9fe6c78`)

Command Line Tools (`DEVELOPER_DIR=/Library/Developer/CommandLineTools`, Swift 6.3.3, SDK 26.5; `pick-sdk` überspringt das 27.0-SDK dort, gebaut von Swift 6.4):

```
DEVELOPER_DIR=… make check        -> exit 0 (87 s), STRICT=1: rules_sync gültig (50 Regeln, 58 Begriffe);
                                     check_texts 314 Dateien, check_design 208 Dateien ohne Befund; check-kit: Kit 303,
                                     gemeinsam 65, Projekt 28, nur im Starter 18, 8 von 8 Modulen entfernbar;
                                     Build ohne Warnung; Swift "410 tests, 0 failures"; Python 252, 137, 28 OK;
                                     keine Zeile außer "ok …" und den Summen (kein "selftest FAIL")
vtool -show-build …/Starter       -> minos 26.0, sdk 26.5
STARTER_HEADLESS=1 STARTER_DATA_DIR=<leer> build/Starter.app/Contents/MacOS/Starter --selftest
                                  -> "selftest: 30 checks, 0 failures", exit 0, Datenordner leer
dasselbe ohne STARTER_HEADLESS    -> 30 checks, 0 failures, Datenordner leer (auf 9825c7a)
codesign --verify --strict build/Starter.app -> ok
DEVELOPER_DIR=… make typecheck    -> 15 Kombinationen ohne Fehler und Warnungen (94 s; auf 9825c7a ebenso, 107 s)
DEVELOPER_DIR=… make probe        -> "Ran 7 tests … OK" (285 s, auf 9825c7a): init grün (48 s), make check nach init
                                     exit 0 (93 s), remove je Modul exit 0, menubar nach window und ai vor mlx abgelehnt
make check-texts / check-design CHECK_FLAGS=--ci und --streng -> ohne Befund
DEVELOPER_DIR=… swift build       -> Absturz von swift-package (dyld: Symbol not found in BuildServerProtocol):
                                     gemischte Installation der Command Line Tools, nicht der Starter
```

Xcode 27 (Standard, `/Applications/Xcode.app`, Swift 6.4, SDK 27.0):

```
make check                        -> exit 0 (94 s), dieselben Zahlen: 410 Swift-Tests, 0 Fehler; Python 252, 137, 28 OK
vtool -show-build …/Starter       -> minos 26.0, sdk 27.0
--selftest headless               -> 30 checks, 0 failures, Datenordner leer
make typecheck                    -> 15 Kombinationen ohne Fehler und Warnungen (105 s)
make dmg                          -> exit 0 (46 s): build/dmg/Starter-1.0.0.dmg (4,4 MB, ULMO, ad hoc, Hinweis auf
                                     „Dennoch öffnen“, beide Sprachen); Warnungen wie vorgesehen: Bundle-ID
                                     com.example.starter und SF Symbol im App-Symbol. dmgbuild 1.6.5, ds-store 1.3.1,
                                     mac-alias 2.2.2 einmal mit --require-hashes in build/tools-venv installiert
hdiutil verify                    -> VALID
hdiutil attach -nobrowse -readonly -mountpoint <tmp> -> Inhalt: Starter.app, Applications -> /Applications,
                                     .background.tiff, .VolumeIcon.icns, .DS_Store; codesign --verify --strict --deep
                                     der App ok (adhoc, com.example.starter), Version 1.0.0, LSMinimumSystemVersion 26.0,
                                     minos 26.0, sdk 27.0, Resources: AppIcon.icns, Notices, de.lproj, en.lproj;
                                     hdiutil detach ok, danach kein Abbild des Starters eingehängt
swift build (Kopie aus git archive, vorher python3 scripts/gen_config.py)
                                  -> "Build complete!" ohne Warnung (9 s); swift build -c release ebenso (26 s);
                                     .build/debug/App --selftest headless: 30 checks, 0 failures, Datenordner leer
                                     (vor 1bd4420: Abbruch "defaultLocalization not set")
make shots                        -> 756 PNGs + index.html (189 Szenen, 59 s); gegen den Lauf davor geprüft (md5):
                                     nur menubar.project weicht ab (siehe Schwächen)
make readme-shots                 -> 12 Bilder, je höchstens 1200 px, zusammen 4,1 MB
```

CI-Plan (`python3 .github/ci_plan.py` mit `GITHUB_REPOSITORY`, `GITHUB_EVENT_NAME`, `GITHUB_EVENT_PATH`):

```
Starter, Push auf main (2133257..HEAD)      -> state=starter starter=true check=true full=true probes=true docs=false
Starter, Pull Request (kein Entwurf)        -> state=starter check=true full=false probes=false docs=false
someone/new-app vor init, Push und PR       -> state=needs-init, check, full, probes aus
initialisiertes Projekt (Kopie, init --non-interactive --name Probe --ohne-netz --ohne-build), Pull Request
                                            -> state=project starter=false check=true full=false probes=false docs=false
combos: 15 Kombinationen (14 aus COMBOS und alle Module), removals: je Modul, mlx vor ai, examples über strip-examples
```

Commit-Prüfung (`scripts/check_commit_msg.py`, mit `.github/commit-ausnahmen.txt`):

```
--bereich HEAD (ganze Geschichte von main)          -> "Das Format aller Commits in HEAD passt."
--github, erster Push von main (before 000…)        -> "… (erster Push von main, ganze Geschichte) passt."
--bereich 2133257..HEAD                             -> passt
```

Angesehen (Read): jedes der zwölf README-Bilder nach `make readme-shots` (Übersicht, Notizseite mit KI en-dunkel, aufgeklappte Inselkarte, Statusmenü, Begrüßungsschritt, Sprache, Neustart-Schritt, Einstellungen „Allgemein“ mit der neuen Reihenfolge, „Insel und Kapsel“ vor und nach `3d61613`, „Modelle“, DMG-Fenster, App-Symbol). Aus `build/shots` je en-hell und de-dunkel als Kontaktbögen: `onboarding.welcome`, `.features`, `.permission-missing`, `.done`, `.project`; `settings.window`, `.window-many`, `.general`, `.about`, `.notices`; `window.main`, `window.home`; `examples.overview`, `.trash`, `.detail-unavailable`, `.pane`, `.search-empty`, `.island-concealed`; `island.notice-warning`, `.done-hover`, `.tiles`, `.onboarding`, `.pane`, `.pane-narrow` (de-dunkel); `capsule.notice-info`; `menubar.panel`, `.pane`, `.project`; `background.pane`; `hotkeys.pane`, `.onboarding`; `ai.pane`, `ai.onboarding`; `design.badge`, `design.tokens`; `patterns.inline-notice`, `.confirm-row`, `.sample-pane`, `.onboarding-tile-picker` (de-dunkel); `gallery.light-stage`. Behoben nach dem Ansehen: abgeschnittenes `island.pane`, „Darstellung“ in `patterns.sample-pane`.

Danach: `pgrep` nach `Starter.app`, `Probe.app`, `run-tests`, `fake_worker` und dem SwiftPM-Binary findet nichts; kein DMG eingehängt.

### Bekannte Schwächen und Offenes

- `menubar.project` ist nicht deterministisch: die Szene zeigt den echten Notizen-Store, dessen Beispiele beim Start in der Startsprache und mit der Uhrzeit des Laufs entstehen. Auf Deutsch stehen dort englische Titel, die Zeiten wechseln von Lauf zu Lauf. Einzige Szene, die zwischen zwei `make shots` abweicht.
- KI-Texte sagen Lokalität zu („What you type stays on this device“, „Runs on this Mac, nothing is sent“, „Was du eingibst, geht nie ins Internet“). Apples Foundation Models laufen auf dem Gerät, ein Test des Starters belegt es nicht (S-06, S-07); die Muster von `zusage` erfassen diese Formen nicht. Entscheidung beim Auftraggeber.
- Allow-Liste (F1, Anfrage 5): `make check-light`, `make test-python`, `make typecheck` fragen weiter nach.
- `CommonText.openApp` hat keinen Aufrufer und bleibt als gemeinsames Wort für Projekte.
- SwiftPM läuft nur mit Xcode; mit den Command Line Tools allein stürzt `swift-package` auf diesem Mac ab. Eine laufende Prüfung von `swift build` gibt es nicht, nur den Typecheck des Manifests in den Python-Tests.
- `make probe` lief auf `9825c7a`; danach kamen nur `9fe6c78` (Mustertexte, entfernte Schlüssel) und dieser Bericht, geprüft mit `make check` und `make typecheck` beider Toolchains.
- Weiter offen aus den Statusberichten: F1 (guard-git liest nur Shell-Text, Minuten der CI geschätzt, `requirements.lock` nur offline geprüft), F2 (Randauslauf nur in Renders, Info-Hinweis der Insel im Akzent, Artwork bei `graphit` grau), F3 (Unterzeile „Einrichtung“ in „Allgemein“ zweizeilig, „Standard verwenden“ breit, Prüfung der Standardtexte bei Anrede Sie).
