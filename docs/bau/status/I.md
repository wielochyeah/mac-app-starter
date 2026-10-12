# Status I (Modul examples: „Notizen“)

Stand: 2026-10-12, Branch `strang/I` (Worktree `wt/I`), `main` zuletzt mit `4cb1eb1` hineingeführt; die Prüfung unten lief auf dem zusammengeführten Stand. Gebaut ist alles aus WAVE2.md Abschnitt I: ein kleines Notiz-Feature, das jede App-Form und jedes Modul nutzt, jeweils in eigenen `#if MODUL_<X>`-Blöcken, gebaut nach den Skills `neues-feature`, `neue-ansicht`, `neue-einstellung`, `insel-zustand`, `menueleisten-app`, `hintergrund-job`, `kurzbefehl` und `ki-funktion`. `bin/starter strip-examples` entfernt es ohne Rest.

## Was gebaut ist

| Teil | Wo | Inhalt |
|---|---|---|
| Daten | `NotesModel.swift`, `NotesStore.swift`, `NotesSeed.swift` | `NoteItem` (id, Titel, Text, Sammlung, angeheftet, `trashedAt`, erstellt, bearbeitet, Quelle `typed`/`clipboard`/`ai`), `NoteCollection` (id, Name, Symbol, Reihenfolge). `NotesStore` (`@Observable`, einziger Datenzugang der UI): eigene Datei `notes.sqlite` über Kit-`Database`, Migration 1 (Tabellen) und 2 (`source`-Spalte, zeigt „neue Migration statt ändern“), FTS5-Index als External-Content-Tabelle mit Triggern (VoiceBud-Muster), außerhalb der Migrationen angelegt, damit ein SQLite ohne FTS5 die Notizen trotzdem öffnet; Suche jedes Wortes als Präfix, Groß/Klein und Akzente egal, Rückfall auf `LIKE`, wenn der Index fehlt oder kaputt ist. Beispieldaten (4 Sammlungen, 10 Notizen) in der UI-Sprache beim ersten Öffnen, gemerkt in `notes_meta`. Text-Änderungen werden gesammelt und nach 0,6 s Pause geschrieben (`edit`/`flush`), alles andere sofort. Kann die Datei nicht geöffnet werden, läuft der Store im Speicher und der Bereich sagt es. Headless (Tests, Renders, `--selftest`) bleibt `NotesStore.shared` im Speicher |
| Aktionen | `NotesActions.swift` | Schnellnotiz aus der Zwischenablage (`NotesPasteboard`-Protokoll, Titel aus der ersten Zeile, höchstens 60 Zeichen am Wort gekürzt), Kopieren, Öffnen (mit `window` die Notizseite, ohne `window` der Einstellungsbereich: `#if`/`#else`) |
| Fenster (`#if MODUL_WINDOW`) | `NotesWindow.swift`, `NotesDetail.swift` | „Übersicht“ (main/0, ersetzt die Startseite des Starters über `MainWindowModel.visible`): Kopfbild mit der zuletzt bearbeiteten angehefteten Notiz, Regale „Zuletzt bearbeitet“ und „Angeheftet“, Liste „Alle Sammlungen“. „Alle Notizen“ (library) mit Suchfeld der Symbolleiste (`WindowSearch.enable`) und FTS-Suche, „Papierkorb“ (Zurücklegen, sofort löschen per Kontextmenü), eine Seite je Sammlung (`TileGrid` oder `ItemList`, Wahl in `notes.layout`). Notizseite über der Seite, von der sie geöffnet wurde (`NotesNavigator`, Zurück-Link mit Esc): `DetailHeader` (Kopieren, Anheften), Editor (Titel, Text, Sammlung, „Gesichert“, In den Papierkorb), leere neue Notizen verschwinden beim Verlassen. Daneben (schmal: darunter, `ViewThatFits`) die KI-Spalte |
| Menüleiste (`#if MODUL_MENUBAR`) | `NotesMenuBar.swift` | Abschnitt „Notizen“ im Feld: die drei zuletzt bearbeiteten, Klick kopiert, ⌥-Klick öffnet; „Zwischenablage als Notiz sichern“ kommt als `Registry.menuItems`-Eintrag (Feld „Aktionen“, Rechtsklick-Menü und App-Menü) |
| Insel (`#if MODUL_ISLAND`) | `NotesIsland.swift` | Schnellnotiz: `.activity` „Sichert“, dann `.done` „In Notizen gesichert“ mit Sammlung, Text und „Öffnen“ (Kopieren hat die Karte selbst; ist „Beim Überfahren ausklappen“ aus, kommt „Kopieren“ als Aktion dazu), leere Zwischenablage als Hinweis; KI-Arbeit als `.progress` (zählt ab 5 s, „Abbrechen“ ab 10 s), Ergebnis als `.done`, Fehler als `.notice` |
| Kurzbefehl (`#if MODUL_HOTKEYS`) | `NotesHotkeys.swift` | „Schnellnotiz aus der Zwischenablage“, Standard ⌃⌥N, `showInOnboarding: true`; Test gegen die Regeln auf US- und deutscher Belegung |
| KI (`#if MODUL_AI`) | `NotesAI.swift`, `NotesAIViews.swift` (zusätzlich `#if MODUL_WINDOW`) | „Zusammenfassung“ (gestreamt in die Notizseite, „In die Notiz“, Kopieren, Verwerfen) und „Titel“ (strukturiert über `DynamicGenerationSchema`: Titel + bis zu 3 Stichwörter, „Übernehmen“), beide abbrechbar, ein Lauf schreibt nie über einen neueren. Anweisungen fest im Code und in der UI-Sprache, die Notiz geht nur als Prompt hinein (auf 6000 Zeichen gekürzt). Ohne Modell: Hinweis mit Grund und „Modelle öffnen“, Knöpfe gedimmt. On-Demand-Selbsttest `examples.ai.live` |
| Hintergrund (`#if MODUL_BACKGROUND`) | `NotesBackground.swift` | Aufgabe „Papierkorb leeren“, täglich, löscht Notizen, die länger als 30 Tage im Papierkorb liegen; angemeldet im Start-Hook (nie headless/Render) |
| Onboarding | in den Modulteilen | drei Karten über `OnboardingFeatures`: Schnellnotiz (hotkeys), Sammlungen (window), Lokale KI (ai), nur was gebaut ist |
| Einstellungen | `NotesPane.swift` | Bereich „Notizen“ (Inhalt-Gruppe, 100): Anzahl, Papierkorb, Standardsammlung für neue Notizen und Schnellnotizen, Datei mit „Im Finder zeigen“, „Beispieldaten neu laden“ mit Bestätigung an Ort und Stelle |
| Demo | `NotesDemo.swift` | `--demo examples` (oder `--demo` ohne Insel-Modul): Beispieldaten im Speicher, Fenster, Schnellnotiz aus festem Text (die echte Zwischenablage bleibt unberührt), Notiz öffnen, zusammenfassen. Nur für die Person am Mac, nicht ausgeführt |
| Texte, Maße | `NotesText.swift`, `NotesLook.swift` | `NotesText` und `NotesSampleText`, du-Form; Maße und Zeiten des Moduls |
| Registrierung | `ExamplesModule.swift` | Bereich, Menüeintrag, Hooks, Demo, Selbsttests `examples.store` und `examples.symbols`, Szenen, je Modul ein `#if`-Block |
| Szenen | `NotesScenes.swift`, `NotesWindowScenes.swift`, `NotesIslandScenes.swift` | 25 Szenen `examples.*` (siehe Prüfung), Galerie `examples.tile`, `examples.ai` |
| Tests | `App/Tests/ExamplesTests.swift` | 34 Tests (`#if TESTING` → `#if MODUL_EXAMPLES`, Modulteile in eigenen Blöcken) |

## Entscheidungen

- **Typname `NoteItem` statt `Note`**: `App/Tests/DatabaseTests.swift` hat ein dateiprivates `Note`, das mit einem modulweiten `Note` kollidiert („invalid redeclaration“). Ein Projekt soll sein eigenes `Note` bauen können, solange die Beispiele noch da sind.
- **Collection-Seiten im Start-Hook**: Sammlungen liegen in der Datenbank; ihre Seiten kommen, sobald die App die Datei geöffnet hat (nie in Renders, Tests, `--selftest`). „Beispieldaten neu laden“ legt dieselben Sammlungs-ids wieder an, damit Seiten und die Standardsammlung gültig bleiben.
- **Navigation zur Notiz**: Das Fenstermodul hat keine Unterseiten. `NotesNavigator` legt die Notiz über die Seite, von der sie kam; von außen (Insel, Menüleiste, Kurzbefehl) wählt `NotesNavigator.show` die Seite über `MainWindowModel.shared.select` und ruft `AppActions.openMainWindow()`. Am Fenstermodul nichts geändert.
- **Menüeintrag ohne `#if`**: `Registry.menuItems` ist Kit; der Eintrag erscheint so auch im App-Menü reiner Fenster-Apps. Im Menüleisten-Feld steht er unter „Aktionen“, der Abschnitt „Notizen“ wiederholt ihn nicht („einmal sagen“). Kein Tastenkürzel am Eintrag: der globale Kurzbefehl ist änderbar, ein festes Kürzel im Menü wäre dann falsch.
- **Hintergrund-Aufgabe nicht im `register()`**: `BackgroundJobs.register` öffnet `background.sqlite`; im `register()` angemeldet, entstünde die Datei auch bei `--selftest` in Application Support. Deshalb im Start-Hook mit `!RenderMode.isHeadless && !RenderMode.isStatic`. Die Arbeit ist `nonisolated`, das Löschen springt auf den MainActor (Kit-`Database` ist MainActor-isoliert).
- **KI-Spalte nur auf der Notizseite**: `NotesAIViews.swift` steht in `#if MODUL_AI` → `#if MODUL_WINDOW` (zwei einfache Blöcke ineinander); die KI-Logik (`NotesAI.swift`) braucht kein Fenster und baut auch mit `menubar,ai,examples`.
- **Kopieren in der Insel**: Die aufgeklappte Fertig-Karte hat einen eigenen Kopieren-Knopf; eine zweite Aktion „Kopieren“ käme doppelt. Nur wenn Karten nicht aufklappen (Einstellung), kommt sie als Aktion dazu.
- **`--demo`**: Die Insel spielt bei `--demo` ohne Bereich ihre eigene Schleife; die Notiz-Demo läuft deshalb nur mit `--demo examples` (oder ohne Insel-Modul).
- **Abgedimmte Chips**: Kit-`Chip` liest `isEnabled` nicht; die KI-Knöpfe nutzen `Metrics.disabledOpacity` selbst (Kit-Kandidat unten).

## Aus VoiceBud übernommen (MIT, Copyright (c) 2026 Anas Riad)

- `history.py` (`SCHEMA`): FTS5 als External-Content-Tabelle mit Triggern für Einfügen, Löschen, Ändern → `NotesStore.fullTextSQL`
- `ui/HistoryStore.swift` (`search`, `ftsQuery`): Wörter nur aus Buchstaben und Ziffern, höchstens 12, jedes in Anführungszeichen mit Präfix-`*`; ohne suchbare Wörter kein Treffer; Rückfall auf `LIKE … ESCAPE '\'` → `NotesStore.searchWords`, `ftsQuery`, `likeIDs`

## Außerhalb meines Strangs angefasst

- `App/Tests/HotkeysTests.swift` (Strang F, `HotkeysSceneTests`): Der Test verlangte, dass die App selbst keinen Kurzbefehl anmeldet; mit dem Beispiel stimmt das nicht mehr. Jetzt: Bereich genau dann, wenn `HotkeyCenter.shared` einen Kurzbefehl hat, Schritt genau dann, wenn einer `showInOnboarding` hat. Grün mit und ohne examples (`make test`, `MODULES=window,hotkeys`).
- Im Fenstermodul nichts: der Mechanismus, die Startseite zu ersetzen (`MainWindowModel.visible`, Seite in `.main` mit `order <= 0`), war schon da.

## Probleme in Skills und Doku (nicht geändert, für G2/Leitung)

1. **„nie verschachtelt“** (`neues-feature`, `docs/ARCHITEKTUR.md`, BAUPLAN §2.5 sagt beides): Braucht ein Teil zwei Module (KI-Spalte auf der Fensterseite, Insel-Meldung einer KI-Aktion, Papierkorb-Untertitel mit/ohne Hintergrund), müssen zwei einfache Blöcke ineinander stehen; `bin/starter remove` und check-kit können das. Vorschlag: „ein Flag je `#if`; braucht ein Teil zwei Module, zwei einfache Blöcke ineinander, nie `&&`/`||`“.
2. **`hintergrund-job` Schritt 2** („Anmelden im `register()`“): legt `background.sqlite` schon bei `--selftest` an (siehe Entscheidungen). Besser im Start-Hook mit `guard !RenderMode.isHeadless, !RenderMode.isStatic`. Außerdem fehlt: Kit-`Database` ist MainActor-isoliert, eine Aufgabe mit Datenbankzugriff muss `await MainActor.run { … }` nutzen; das Beispiel mit `nonisolated` gilt nur für Arbeit ohne Kit-Typen.
3. **`neues-feature` Schritt 6**: „nichts startet Fenster, wenn headless“ reicht nicht. Der Selbsttest `window.chrome` baut das echte Hauptfenster und zeichnet die erste Seite; ein Feature, das dort seine Datenbank lazy öffnet, legt die Datei bei `--selftest` in Application Support an. Hinweis ergänzen: geteilte Stores headless im Speicher halten.
4. **`neue-ansicht` Schritt 4**: `WindowSearch.enable(page:prompt:)` fehlt (ohne den Aufruf erscheint kein Suchfeld; steht auch in INTEGRATION.md als offen). Es fehlt außerdem: wie Renders einer Seite entstehen (`RenderBoard { StaticMainWindow(pages:selection:query:searchPrompt:) { … } }`), dass `ViewThatFits` neben langen Texten ein `idealWidth` braucht, und wie man eine Detailseite über einer Liste öffnet (das Fenstermodul hat dafür nichts; Kandidat `AppActions.openMainWindow(page:)`).
5. **`ki-funktion` Schritt 7**: `structured` geht nur über `AppleOnDeviceProvider` (Cast in `LocalAI.structured`); ein `LocalModelProvider`-Testdouble kann strukturierte Antworten nicht liefern. Testbar sind Prompt, Schema und das Auslesen über `GeneratedContent(json:)`; der Fake prüft den Fehlerweg (`.unsupported`). Hinzufügen.
6. **`insel-zustand` Schritt 6**: wie die Szenen entstehen, fehlt: `IslandScenes.Sample(id:crop:content:configure:)` und `IslandScenes.stage(_:kind:)` (Zähler und „Dauert länger“ über `slowSince`/`slowHint`, Aufklappen über `hover = .expanded`). Außerdem: eine Fertig-Karte mit Text hat Kopieren schon eingebaut.
7. **`menueleisten-app`**: Einträge aus `Registry.menuItems` stehen im Feld unter „Aktionen“; ein Abschnitt soll dieselbe Aktion nicht noch einmal als Knopf haben. Die Bühne der Feld-Szenen (`PanelStage`) ist privat; ein Feature baut sich eine eigene (Hintergrundbild + `MenuBarPanelView(close:sections:actions:status:showsWindowAction:)`).
8. **`kurzbefehl`**: Wer einen echten Kurzbefehl anmeldet, macht `HotkeysSceneTests` rot (jetzt behoben, siehe oben). Für eigene Szenen fehlt der Hinweis auf `HotkeyCenter(backend: FakeHotkeyBackend(), store: MemoryHotkeyStore())` mit `layout = TableKeyboardLayout.us`.
9. **`docs/MODULE.md` examples**: nennt „Onboarding-Schritt“; gebaut sind (laut WAVE2) drei Karten im Kit-Schritt „Funktionen“. Vorschlag für den Abschnitt: Zweck, Dateien (Tabelle oben), Einstellungsschlüssel `notes.defaultCollection`, `notes.layout`, Szenen `examples.*`, Demo `--demo examples`.

## Kandidaten für Kit

- `Chip` dimmt nicht, wenn er gesperrt ist (`isEnabled`); hier mit `Metrics.disabledOpacity` von außen gelöst.
- Bestätigungszeile an Ort und Stelle (`ResetConfirmation` in `GeneralPane` ist privat; `NotesReloadConfirmation` ist eine Kopie).
- `ValueRow(capsule: true)` wirkte bei zweistelligen Werten am linken Rand der Kapsel abgeschnitten (frühe `examples.pane`-Fassung, nicht weiter untersucht); hier ohne Kapsel.
- `AppActions.openMainWindow(page:)` statt `MainWindowModel.shared.select` aus Features.
- `AIWaitFree`-artiges Warten auf async in Tests ohne das ai-Modul (Harness).

## Bekannte Lücken

- Nie interaktiv geprüft (Regel: App nie normal starten): Fenster mit echter Seitenleiste und Suche, Editor mit Autosave und Tastatur (Esc zurück), ⌥-Klick im Feld, die echte Insel bei Schnellnotiz und KI, der Kurzbefehl aus anderen Apps, die Aufgabe im echten Planer, „Im Finder zeigen“, `--demo examples`. Der Lead prüft das.
- Das echte Modell ist nur über den Selbsttest geprüft (`--selftest examples.ai`: deutsche Zusammenfassung in ca. 1,5 s); „Titel vorschlagen“ mit dem echten Modell nicht (strukturierte Antwort testet `AIModule` selbst).
- Die `LIKE`-Suche ist nur für ASCII unabhängig von Groß/Klein (SQLite); Umlaute findet sie nur in der geschriebenen Form.
- Keine Pfeiltasten-Navigation in Listen (Kit-`ItemList`), keine eigene Sammlung anlegen oder umbenennen (Beispiel bewusst klein).
- Ändert sich die Liste der Sammlungen zur Laufzeit, kommen neue Seiten erst beim nächsten Start (Registry ist nicht beobachtbar).

## Prüfung (Befehle und Ergebnisse)

```
make build                                   -> grün (window,menubar,island,background,hotkeys,ai,examples), 0 Warnungen
MODULES=… make build + STARTER_HEADLESS=1 STARTER_DATA_DIR=<tmp> …/Starter --selftest (Datenordner danach leer):
  window,examples                            -> grün, 0 Warnungen, 22 checks, 0 failures
  menubar,examples                           -> grün, 0 Warnungen, 19 checks, 0 failures
  menubar,island,examples                    -> grün, 0 Warnungen, 21 checks, 0 failures
  window,ai,examples                         -> grün, 0 Warnungen, 23 checks, 0 failures
  menubar,hotkeys,examples                   -> grün, 0 Warnungen, 22 checks, 0 failures
  window,background,examples                 -> grün, 0 Warnungen, 23 checks, 0 failures
  menubar,ai,examples                        -> grün, 0 Warnungen, 20 checks, 0 failures
  alle inkl. mlx                             -> grün, 0 Warnungen, 31 checks, 0 failures
STARTER_LANG=de … --selftest examples.ai     -> 1 check, 0 failures (Apple-Modell, 216 Zeichen, ca. 1,5 s)
make test                                    -> Swift "389 tests, 0 failures" (34 ExamplesTests), Python 220 + 117 + 23 OK
MODULES=menubar,examples ONLY=Examples make test -> 22 tests, 0 failures
MODULES=window,examples ONLY=Examples make test  -> 24 tests, 0 failures
make check                                   -> grün: rules_sync gültig, check_texts und check_design ohne neue Befunde,
                                                check-kit 8 von 8 Modulen entfernbar, Build, Tests
bin/starter strip-examples (Kopie aus git ls-files, git init + Commit, ohne origin)
                                             -> 20 Dateien gelöscht, Blöcke in Modules.swift, Markierungen in
                                                neues-feature/SKILL.md und docs/MODULE.md entfernt, ExamplesTests.swift
                                                leer und gelöscht, modules.examples gestrichen, make build grün;
                                                make test in der Kopie "355 tests, 0 failures". check-kit meldet dort nur,
                                                dass ein Starter ohne init kein Modul verlieren soll (Lock, starter.json):
                                                in einem Projekt nach bin/starter init gilt das nicht
git grep Notes|Notizen|Examples in der Kopie -> nur Treffer, die auf main schon vor Strang I da waren (Werkzeugnamen
                                                strip-examples, Modultabellen, Doku-Beispiele wie NotesText in
                                                neue-einstellung, Wortlisten in rules/, Musterszenen im Kit)
make shots ONLY=examples.                    -> 100 PNGs (25 Szenen × en/de × hell/dunkel)
pgrep Starter                                -> nichts übrig
```

Angesehen (Read, jede Szene in allen vier Fassungen, als 2×2-Bogen): `examples.overview`, `all`, `search` (FTS: „sommer“ findet zwei Notizen über den Text), `search-empty`, `collection`, `collection-list`, `trash`, `empty`, `detail`, `detail-streaming`, `detail-done`, `detail-unavailable`, `pane`, `pane-confirm`, `onboarding`, `menubar`, `menubar-empty`, `island-saving`, `island-saved`, `capsule-saved`, `island-empty`, `island-summarizing`, `capsule-summarizing`, `hotkey`, `background`; zum Vergleich `window.main` und die Insel- und Feld-Szenen der Module (gleiche Bühnen und Bausteine). Nach dem Ansehen behoben: Editor und KI-Spalte untereinander statt nebeneinander (`ViewThatFits` ohne `idealWidth`), zentrierter Titel im Editor, umbrochenes „Zusammenfassun-g“ (Spalte 340, Knopf „Erstellen“), deutsche Titel auf Kacheln gekürzt (kürzere Beispieltitel), englischer Text in der deutschen Insel-Karte (Beispiel beim Registrieren statt beim Rendern gebaut), zwei Haus-Symbole in der Seitenleiste (Sammlung „Zuhause“ jetzt `sofa.fill`), doppelter Titel „Notizen“ im Bereich (Gruppe heißt „Inhalt“), abgeschnittene Kapsel bei „10“, gesperrte KI-Knöpfe sahen aktiv aus, leere Sammlungsspalte im Papierkorb, Suchbeispiel mit nur einem Treffer.
