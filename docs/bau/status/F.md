# Status F (Modul Hotkeys)

Stand: 2026-10-12 (nach Review-Runde 1), Branch `strang/F` (von `main` 68281d5). Alles aus STRANDS.md Abschnitt F ist gebaut, getestet und gerendert; die Befunde des Reviews stehen unten unter "Review".

## Was gebaut ist

Alles in `App/Sources/Modules/Hotkeys/`, Tests in `App/Tests/HotkeysTests.swift`.

| Datei | Inhalt |
|---|---|
| `KeyCombo.swift` | `KeyModifiers` (OptionSet mit Carbon-Bits, Glyphen ⌃⌥⇧⌘, Namen für settings.json, aus `NSEvent.ModifierFlags`), `KeyCombo` (keyCode + Modifier, prüft beim Lesen), `HotkeyChoice` (`.standard` / `.off` / `.combo`), `SettingKey.hotkey(id)` = `hotkeys.<id>` |
| `KeyboardLayout.swift` | Protokoll `KeyboardLayout` (was eine Taste tippt, Tottasten), `SystemKeyboardLayout` (TIS + `UCKeyTranslate`), `keyName` / `menuToken` / `caps` / `label`, `KeyCodes` (Sondertasten, Ziffernblock, F-Tasten, Editier- und Medientasten), `SystemShortcuts.read()` (`CopySymbolicHotKeys`) |
| `ShortcutCatalogText.swift` | Die 178 Einträge aus VoiceBud (was eine Kombination in macOS, fast jeder App, Textfeldern, Terminal, gängigen Apps tut) plus ⌘-Einzeltasten, alle als `tr(en:de:)` |
| `ShortcutRules.swift` | Regelwerk: `judge(_:in:) -> Verdict` (`.take(combo, note:)` / `.refuse(grund)`), `suggestion(for:in:)` (freie Variante ⌃⌥⌘ → ⌃⇧⌘ → ⌥⇧⌘ → ⌃⌥⇧⌘), `clash`; rein, alles kommt über `Context` (Layout, macOS-Liste, andere Hotkeys, VoiceOver, App-Name) |
| `HotkeyCenter.swift` | `@Observable HotkeyCenter.shared`: `register(id:title:subtitle:default:order:showInOnboarding:onRelease:action:)`, `set/choice/combo/display`, `status` je Hotkey (`active/off/inactive/heldElsewhere/failed`), `pressed`, `pressCount`, `pause`, `probe`, `start/stop`; `HotkeyBackend`- und `HotkeyStore`-Protokolle, `SettingsHotkeyStore`, `MemoryHotkeyStore`, reines `plan()` |
| `CarbonHotkeys.swift` | `CarbonHotkeyBackend` (erst exklusiv, bei -9878 normal registrieren und "von anderer App gehalten" melden, Probe), `FakeHotkeyBackend` (Tests, Renders) |
| `ShortcutRecorder.swift` | `@Observable ShortcutRecorder`: lokaler Event-Monitor (schluckt die Tasten), Regeln, Vorschlag, Notiz + Rückgängig, Standard, ⌫ entfernt, Esc bricht ab, 25-s-Zeitlimit, Fokusverlust, Rücknahme wenn macOS ablehnt oder eine andere App die Tasten hält, Haptik; `Event` (aus `NSEvent` oder synthetisch) |
| `ShortcutRecorderRow.swift` | `ShortcutRecorderRow` (auf `Row`, Ton aus der `SettingsSection`), `BigKeyCaps` (große Tasten mit Beschriftung, leuchten beim Drücken) |
| `HotkeysViews.swift` | `HotkeysPane` (Bereich "Kurzbefehle", leerer Zustand), `HotkeysOnboardingStep` (Schritt "Dein Kurzbefehl") |
| `HotkeysModule.swift` | Registrierung: Einstellungsbereich, Onboarding-Schritt, Launch-/Terminate-Hook, zwei Selbsttests, Katalog |
| `HotkeysCatalog.swift` | Szenen und Galerie mit Beispiel-Hotkeys (nur hier, Fake-Backend, Speicher im RAM, festes US-Layout) |
| `TableKeyboardLayout.swift` | Layout aus einer festen Tabelle (`TableKeyboardLayout.us`), damit die Szenen auf jedem Mac gleich aussehen; die Tests ergänzen eine deutsche Tabelle |
| `HotkeysText.swift` | Alle Texte (`HotkeysText`, `HotkeysSampleText`), du-Form |
| `HotkeysTokens.swift` | Modul-Tokens: `Metrics.Hotkeys.*`, `Space.shortcutRowGap/recordingPlaceholderX`, `TypeScale.keyWord/keyLetter` |

### So benutzt ein Projekt das Modul

```swift
// z. B. in FeatureModule.register() oder in einem Launch-Hook
HotkeyCenter.shared.register(id: "quick-window", title: { MyText.quickWindow }, subtitle: { MyText.quickWindowDetail },
                             default: KeyCombo(keyCode: 40, modifiers: [.option, .shift, .command]),   // ⌥⇧⌘K
                             showInOnboarding: true) { QuickWindow.toggle() }
HotkeyCenter.shared.display("quick-window")   // "⌥⇧⌘K" für Menüs, nil wenn keiner gesetzt
```

- Der Bereich "Kurzbefehle" kommt mit dem ersten registrierten Hotkey dazu (`HotkeyCenter.shared.onRegister`), ein Projekt ohne Hotkey zeigt ihn nicht. Er listet alle registrierten Hotkeys; der Onboarding-Schritt erscheint nur, wenn einer `showInOnboarding: true` hat (der erste nach `order`).
- Ein Standard ohne ⌃, ⌥ oder ⌘ (außer F-Tasten) wird verworfen; einen Standard, den die Regeln ablehnen würden (etwa ⌘Q), meldet der Selbsttest `hotkeys.standards` bei `--selftest` als Fehler.
- `onRelease:` für Halten-und-Loslassen (wird auch gesendet, wenn der Hotkey während des Haltens weggenommen wird).
- Ohne Standard (`default: nil`) tut der Hotkey nichts, bis die Person einen setzt.

## Entscheidungen

- **Nur Tasten mit Sondertasten (oder F-Tasten allein)**, keine reinen Sondertasten-Akkorde wie VoiceBuds `ctrl+shift`: die bräuchten Eingabeüberwachung und einen Event-Tap (VoiceBud macht das im Python-Kern). Carbon `RegisterEventHotKey` braucht keine Freigabe. Sondertasten allein lehnt der Recorder mit Erklärung ab.
- **Regeln rein und injizierbar**: Layout, macOS-Liste und andere Hotkeys kommen über `ShortcutRules.Context`; die Tests laufen gegen feste US- und Deutsch-Tabellen, unabhängig vom Mac.
- **Speicherform je Hotkey** `hotkeys.<id>`: `"off"` oder `{"keyCode": 40, "modifiers": ["control", "option", "command"]}` (lesbar beim Bearbeiten von Hand); Standard = Schlüssel fehlt. Eine kaputte Angabe kostet nur diesen Hotkey (VoiceBud `LossyShortcut`). Eine Wahl gleich dem Standard wird als Standard gespeichert.
- **Gleiche Tasten zweimal**: nur der erste Hotkey (Anzeigereihenfolge) wird registriert, der zweite steht auf `duplicate(of:)` und sagt das in seiner Zeile und auf dem Schritt (VoiceBud: "a key twice goes to the first mode only"). Der Recorder lässt das gar nicht erst zu; vorkommen kann es, wenn ein neuer Standard im Code auf die eigene Wahl einer Person trifft.
- **Einstellungen folgen**: Nach `start()` beobachtet die Zentrale den Speicher (`Observing.track` über `Settings`); "Einstellungen zurücksetzen" oder `Settings.reload()` nach einer Handänderung wirken sofort. `reloadChoices()` gibt es zusätzlich für einen ausdrücklichen Abgleich.
- **Pause gezählt, ein Recorder zur Zeit**: jedes `pause(true)` braucht sein `pause(false)`; startet ein zweiter Recorder (Einstellungen und Onboarding offen), bricht der erste ab.
- **⌫ beim Aufnehmen entfernt den Kurzbefehl** (mit Rückgängig, Standard holt ihn zurück); VoiceBud kannte "keiner" nicht, ein generisches Modul braucht es.
- **Backend als Protokoll**: Carbon im Programm, Fake in Tests, Renders und Galerie. `start()` tut im Headless-/Render-Lauf nichts, also erreicht bei `--selftest`, `--render` und `make test` nichts macOS.
- **Onboarding-Schritt ohne Pflicht**: "Weiter" geht immer. Die Statuszeile folgt dem echten Zustand: "Aufnahme läuft" beim Aufnehmen, Warnung bei fehlendem Kurzbefehl, bei Tasten einer anderen App, bei Ablehnung durch macOS und bei doppelten Tasten, sonst "Drück die Tasten einmal zum Ausprobieren" und "Klappt", sobald der Hotkey auf diesem Schritt gedrückt wurde (Drücke davor und vor dem letzten Tastenwechsel zählen nicht). Der Platz der großen Tasten bleibt auch ohne Kurzbefehl reserviert, und die Karte hat eine Mindesthöhe (`Metrics.Hotkeys.stepCardArea`, reicht für die längste Begründung), damit die Seite nicht springt; wird sie doch länger, wächst sie statt abzuschneiden. Beim Aufnehmen stehen Anleitung und Begründung auf dem Schritt in voller Breite unter dem Titel, der Vorschlag darunter; die Zeile zeigt dort keine Tastenkappen (die großen darüber zeigen sie schon).
- **Pane** `id "hotkeys"`, Gruppe `.settings`, Reihenfolge 400, Symbol `command`, Tönung `.indigo`. **Schritt** `id "hotkeys"`, Reihenfolge 600.
- **Optimizer-Absturz** (Swift 6.3, Release, CopyPropagation "Found ownership error") an einer Closure-Suche über die Bedeutungstabelle: als Schleife geschrieben, Kommentar im Code.

## Aus VoiceBud übernommen (für THIRD_PARTY_NOTICES, MIT, Copyright (c) 2026 Anas Riad)

- `ui/Hotkeys.swift` `HotkeyCenter` → `HotkeyCenter` + `CarbonHotkeyBackend` (exklusiv, dann normal; synthetisches Loslassen; Pause; Probe; Layout-Benachrichtigung)
- `ui/ShortcutRules.swift` → `ShortcutRules` (Regelreihenfolge [2]–[20], Texte der Begründungen und Hinweise, Vorschlag), `ShortcutCatalogText` (Tabelle `named`, `commandOnly`), `KeyboardLayout`/`SystemKeyboardLayout` (`typedInfo`, `keyName`, `menuToken`, `specialNames`, `keypad`, `functionKeys`, `topRow`, `editingKeys`, `mediaKeys`), `SystemShortcuts` (`systemShortcuts()`), `needed`, `deadElsewhere`
- `ui/Hub.swift` `HubShortcutRecorder` → `ShortcutRecorder`; `HubShortcutsGroup`-Zeile → `ShortcutRecorderRow`
- `ui/Model.swift` `KeyCombo`, `LossyShortcut` (Idee) → `KeyCombo`, `HotkeyChoice`
- `ui/Onboarding.swift` `OnboardingBigKeys`, `OnboardingKeys.word` → `BigKeyCaps`, `HotkeysText.capWord`
- `ui/HubRender.swift` `--selftest-shortcuts` (Fälle) → `App/Tests/HotkeysTests.swift`

Nicht übernommen (VoiceBud-spezifisch): Akkorde aus Sondertasten (`judgeChord`, `systemStarts`, Akkord-Teile von `clash`), IPC `hotkeys_pause`, Texterkennungs-Sonderfälle, macOS-15.0/15.1-Meldung zu -9868 (Mindestversion ist 26).

## Außerhalb meines Strangs angefasst

Nichts. (`App/Tests/HotkeysTests.swift` ist der eigene Test des Moduls, in `#if TESTING` / `#if MODUL_HOTKEYS`.)

## Hinweise für andere Stränge und die Integration

- **S0 / alle mit Render-Tests**: Viele `RenderRunner.png`-Aufrufe in einem Test hinterlassen Sekunden an SwiftUI-Arbeit auf dem Main-Thread (die Hosting-Views leben bis zum Ende des Autorelease-Pools). Danach scheiterte `ObservingTests/track calls onChange on every change` (wartet nur 50 ms) in etwa jedem dritten Lauf. Mein Test rendert deshalb jede Szene in einem eigenen `autoreleasepool` und wartet danach, bis der Main-Actor frei ist: 0 von 12 Läufen rot. Kandidat für Kit: `autoreleasepool` direkt in `RenderRunner.png`, und `ObservingTests.spin` auf "warten bis Bedingung" umstellen.
- **Strang K**: Modulpfade für `hotkeys`: `App/Sources/Modules/Hotkeys/**` und `App/Tests/HotkeysTests.swift`.
- **Strang G (Prüfskripte)**: Mit den Skripten und Regeln von `strang/G1` laufen `check_texts.py` und `check_design.py` (auch `--streng`) auf dem Modul ohne Befund. Die zwei Schriftgrößen der großen Tasten in `HotkeysTokens.swift` tragen `// design-ausnahme:` (Kit-Kandidat). `KeyCodes.specialNames` ("Esc", "Help", "F5") und die Tastenkappe `"fn"` im Recorder sind Tastenbeschriftungen, keine UI-Texte.
- **Strang E**: `SettingsReset.didReset` braucht keinen Eintrag für Hotkeys (der Doku-Kommentar dort nennt beispielhaft `HotkeyCenter.shared.reload()`; die Methode heißt `reloadChoices()` und ist nur für einen ausdrücklichen Abgleich nötig, die Zentrale folgt `Settings` selbst).
- **Strang E**: Bereich kommt über `Registry.settingsPanes` (id `hotkeys`), aber erst mit dem ersten registrierten Hotkey.
- **Strang D**: Schritt kommt über `Registry.onboardingSteps` (id `hotkeys`, order 600, `isIncluded` nur mit `showInOnboarding`-Hotkey).
- **Welle 2**: Examples kann einen Beispiel-Hotkey mit `showInOnboarding: true` registrieren; Menüleiste/Hauptmenü können `HotkeyCenter.shared.display(id)` neben Einträgen zeigen.
- **Kit-Kandidaten**: `BigKeyCaps` (+ `Metrics.Hotkeys`-Tokens), falls ein anderer Strang große Tastenkappen braucht.

## Bekannte Lücken

- Echte Carbon-Registrierung, der lokale Event-Monitor, Fokusverlust, Zeitlimit und Haptik sind gebaut, aber nicht interaktiv ausprobiert (Regel §2.17, App nie normal gestartet). Abgesichert über Fake-Backend und synthetische Events; die Abfolge Recorder → Pause → Registrierung → Rücknahme ist getestet.
- Belegt eine andere App die Tasten erst später, merkt das Modul es nicht (Carbon meldet das nicht); der Zustand wird bei jeder Neuregistrierung geprüft.
- Die Layout-Tabellen in den Tests sind Ausschnitte (Grund- und ⇧-Ebene vollständig, ⌥-Ebene für die geprüften Tasten).
- Die Testtexte prüfen englische Teilstrings (`make test` setzt `STARTER_LANG=en`); die deutschen Texte sind in den PNGs (de-light, de-dark) angesehen.
- Ist der Kurzbefehl auf dem Schritt entfernt, bleibt der Platz der großen Tasten leer (gewollt, damit die Seite stehen bleibt).
- `Package.swift` nicht gebaut (SwiftPM stürzt auf diesem Mac ab, siehe S0).
- Tastenname "Help" bleibt in beiden Sprachen englisch (wie VoiceBud).

## Prüfung vor dem Review (Befehle und Ergebnisse, 2026-10-12)

```
make build                                          -> grün (window,menubar,island,background,hotkeys,ai,examples), 0 Warnungen
make build MODULES=menubar                          -> grün (ohne hotkeys)
make build MODULES=window,hotkeys                   -> grün
make build MODULES=menubar,hotkeys                  -> grün
make build MODULES=window,menubar,island,background,hotkeys,ai,mlx,examples -> grün
make build CONFIG=release                           -> grün (nach dem Schleifen-Umbau; vorher swift-frontend-Absturz)
STARTER_HEADLESS=1 …/Starter --selftest             -> "selftest: 10 checks, 0 failures" (default, release, window+hotkeys,
                                                       menubar+hotkeys, alle Module); ohne hotkeys "8 checks, 0 failures"
make test                                           -> "116 tests, 0 failures" (49 neue in HotkeysTests) + Python "Ran 11 tests … OK"
MODULES=menubar make test                           -> "67 tests, 0 failures"
MODULES=menubar,hotkeys make test                   -> "116 tests, 0 failures"
build/tests/run-tests 12x hintereinander            -> 0 Fehlläufe
make check                                          -> grün (fehlende Prüfskripte von G/K übersprungen)
make shots ONLY=hotkeys.                            -> 28 PNGs (7 Szenen × en/de × hell/dunkel)
```

Testinhalt: 17 Regel-Tests mit rund 70 Fällen gegen US- und Deutsch-Tabellen (Menübefehle, ⌘-Einzeltasten, Zeichen nach Layout inkl. ⌘Z/⌘Y-Tausch, Textsystem, Editier-/Navigationstasten, Terminal, macOS an/aus/immer, F-Tasten und Medientasten, ⌥-Zeichen nötig/selten/Tottaste (⌥L = @ deutsch, ⌥N = ~, ⌥E = €, ⌥⇧7 = \, ⌥Y = ¥), gängige Apps, VoiceOver, eigene Hotkeys, Vorschlag, gleiche Begründung bei jedem Lauf, beide Sprachen je Tabelleneintrag); Anzeige (Glyphenreihenfolge, Tastennamen je Layout, ß bleibt ß, Leertaste/Ziffernblock übersetzt); Speicherung (lesbares JSON, kaputte Werte, ein Schlüssel je Hotkey, Standard entfernt den Schlüssel); Center (erst nach Start registriert, Neuregistrierung ohne Neustart, doppelte Tasten, gehalten/abgelehnt, Drücken/Loslassen, Pause mit synthetischem Loslassen, Stop/Unregister, Reihenfolge, `plan`); Recorder (Übernahme, Ablehnung + Vorschlag übernehmen, Notiz + Rückgängig, Sondertasten allein, zwei Tasten, fn allein/mit Taste, Loslassen ohne Drücken, Esc, Wiederholung, ⌫ + Rückgängig + Standard, Konflikt auch bei Standard, Rücknahme wenn eine andere App die Tasten hält, NSEvent-Umwandlung); Szenen registriert und in beiden Erscheinungen gerendert.

Angesehen (Read): `hotkeys.recorder-states` de-light und en-dark (Vergleich mit VoiceBud `docs/screenshots/hub-kurzbefehle.png`: roter Grund mit Ring um die gedrückten Tasten, "⌃⌥⌘W übernehmen", Notiz mit Rückgängig/Standard/Ändern), `hotkeys.pane` de-light, de-dark, en-dark, `hotkeys.pane-empty` de-dark, en-light, `hotkeys.onboarding` de-light (Vergleich mit VoiceBud `onboarding-07-probediktat-light.png`: große Tasten mit ctrl/alt/cmd), `hotkeys.onboarding-pressed` en-dark (Tasten in Akzentfarbe, "Works"), `hotkeys.onboarding-refused` de-dark und en-light (Seite springt nicht), `hotkeys.big-keys` en-light, de-dark. Behoben nach dem Ansehen: Untertitel des Schritts wiederholte den Zeilen-Untertitel (jetzt eigener Satz mit dem Titel), Tasten-Muster abgeschnitten (jetzt untereinander), Bereichsszene zu hoch (Leerraum).

## Review (Runde 1, 2026-10-12)

Alle 16 Befunde geprüft; alle waren echt und sind behoben (Commit `bc05bca`), nichts übersprungen.

| # | Befund | Ergebnis |
|---|---|---|
| 1 | Schritt schneidet lange deutsche Ablehnung ab (feste Höhe 170) | behoben: Mindesthöhe statt fester Höhe; beim Aufnehmen steht der Text in voller Breite unter dem Titel. Neue Szenen `hotkeys.onboarding-refused-long` (⇧⌘5, in macOS an) und `hotkeys.onboarding-caught` (längste Begründung); beide passen in 170 pt, die Seite steht |
| 2 | Zentrale folgt `Settings` nicht ("Einstellungen zurücksetzen" lässt alte Tasten registriert) | behoben: `followStore()` per `Observing.track` ab `start()`, `reloadChoices()`; Test setzt eigene Tasten, löscht den Schlüssel in `Settings` und erwartet Standard registriert |
| 3, 10 | G1-Prüfungen rot (EN "Press keys …", Schriftgrößen, Szenenbreite, Glyphen in Kommentaren) | behoben: "Press keys…", `// design-ausnahme:` an den zwei Schrift-Tokens, Szenenbreite `Sample.paneSize.width`, Kommentare in Worten. `check_texts.py` und `check_design.py` von `strang/G1` (auch `--streng`): keine Befunde |
| 4 | Gespeicherte und Code-Standards ungeprüft (Hand-Edit "A", ⌘Q als Standard) | behoben: `KeyCombo.isShortcut`; gespeicherte Nicht-Kurzbefehle gelten als Standard, `set` lehnt sie ab, solche Standards werden verworfen; Selbsttest `hotkeys.standards` und `Log.warn` bei `register` für Standards, die die Regeln ablehnen |
| 5 | Pause als ein Wahrheitswert für alle Recorder | behoben: Pausen gezählt, nur ein Recorder hört zu (ein zweiter Start bricht den ersten ab); zwei Tests |
| 6 | Registrierungsproblem ohne Vorschlag, doppelte Tasten stumm | behoben: der Recorder nimmt nach Rücknahme weiter auf und bietet eine freie Variante an (Vorschläge prüfen per `probe`, ob eine andere App sie hält; auch bei "abgefangen"); neuer Status `duplicate(of:)` mit Begründung in Zeile und Statuszeile, Szene im Zustandskatalog |
| 7 | Force-Unwraps in `ShortcutRules.judge` | behoben: Text in der Suche gebunden |
| 8 | Statuszeile des Schritts widerspricht der Zeile | behoben: `statusLine(center:recorder:id:tried:)` aus dem echten Zustand (Aufnahme, kein Kurzbefehl, gehalten, abgelehnt, doppelt), "Klappt" zählt nach einem Tastenwechsel neu; Test und Szenen `hotkeys.onboarding-recording`, `-held` |
| 9 | Zustand ohne Kurzbefehl: falscher Untertitel, Seite springt, keine Szene | behoben: eigener Untertitel, reservierter Platz der großen Tasten, Statustext je nach Standard ("Klick auf Ändern oder Standard"), Szene `hotkeys.onboarding-off` |
| 11 | Deutsche Ablehnung im Schritt in schmaler Spalte, Glyphengruppen brechen um | behoben: gestapelte Zeile auf dem Schritt (siehe 1), geschützte Leerzeichen in "(⌃ ⌥ ⇧ ⌘)", "Esc bricht ab", "⌫ entfernt" und geschützter Bindestrich in "F-Taste" |
| 12 | Doppelte Anweisungen, Infinitiv, Rückgängig und Standard gleich | behoben: angehängt wird nur "Esc bricht ab." / "Esc cancels." (jede Begründung sagt schon, was stattdessen); "Drück die Tasten …"; "Rückgängig" nur, wenn es etwas anderes bringt als "Standard"; `alreadyUsed` sagt jetzt auch "Nimm eine andere Kombination." |
| 13 | "Keiner" mit 2,2:1 Kontrast | behoben: `fg2` statt `fg3` |
| 14 | Szenen hängen vom Layout des Build-Macs ab | behoben: `TableKeyboardLayout.us` für alle Szenen und die Galerie (Tabelle aus den Tests in den Modulordner verschoben) |
| 15 | Vage Texte ("vermutlich …"), holprige Fußnote | behoben: die drei unbestätigten Bedeutungen entfernt (dann greift "macOS belegt … selbst"), Fußnote "… und sagt dir, was die Kombination dort tut", EN "As a Starter shortcut, it would stop working everywhere." |
| 16 | Leerer Bereich als Standard ausgeliefert; Tasten im Schritt doppelt | behoben: Bereich kommt erst mit dem ersten Hotkey; die Zeile auf dem Schritt zeigt keine Tastenkappen |

### Prüfung nach dem Review (2026-10-12)

```
make build                                          -> grün, 0 Warnungen; --selftest "11 checks, 0 failures"
make build MODULES=menubar                          -> grün; --selftest "8 checks, 0 failures"
make build MODULES=window,hotkeys / menubar,hotkeys -> grün; --selftest je "11 checks, 0 failures"
make build MODULES=window,menubar,island,background,hotkeys,ai,mlx,examples -> grün; "11 checks, 0 failures"
make build CONFIG=release                           -> grün, 0 Warnungen; "11 checks, 0 failures"
make test                                           -> "127 tests, 0 failures" (60 in HotkeysTests) + Python "Ran 11 tests … OK"
MODULES=menubar make test                           -> "67 tests, 0 failures"
MODULES=menubar,hotkeys make test                   -> "127 tests, 0 failures"
build/tests/run-tests 12x hintereinander            -> 0 Fehlläufe
make check                                          -> grün (Prüfskripte von G/K auf diesem Branch noch nicht da)
strang/G1 check_texts.py --streng (Modul + Test)    -> "keine neuen Befunde", Exit 0
strang/G1 check_design.py --streng (Modul)          -> "keine neuen Befunde", Exit 0
make shots ONLY=hotkeys.                            -> 48 PNGs (12 Szenen × en/de × hell/dunkel)
```

Angesehen (Read): `hotkeys.onboarding-refused-long` und `-caught` de-light (längste Begründungen passen, Titel bleibt auf derselben Höhe wie im Grundzustand), `hotkeys.onboarding-off` de-dark (Untertitel ohne "diese Tasten", Platz bleibt, Seite springt nicht), `hotkeys.onboarding` en-light (Zeile ohne doppelte Tasten), `hotkeys.onboarding-recording` de-light und en-dark ("Aufnahme läuft", Anleitung in voller Breite, "F-Taste" bricht nicht mehr um), `hotkeys.onboarding-held` en-dark (Warnung statt "Ausprobieren"), `hotkeys.onboarding-refused` de-dark (Begründung in zwei Zeilen, Vorschlag darunter), `hotkeys.recorder-states` de-light (neuer Zustand "Gleiche Tasten", "Keiner" lesbar, kein doppeltes Rückgängig), `hotkeys.pane` en-light.

Außerhalb meines Strangs angefasst: weiterhin nichts.
