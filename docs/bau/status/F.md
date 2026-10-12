# Status F (Modul Hotkeys)

Stand: 2026-10-12, Branch `strang/F` (von `main` 68281d5). Alles aus STRANDS.md Abschnitt F ist gebaut, getestet und gerendert.

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
| `HotkeysCatalog.swift` | Szenen und Galerie mit Beispiel-Hotkeys (nur hier, Fake-Backend, Speicher im RAM) |
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

- Der Bereich listet alle registrierten Hotkeys; der Onboarding-Schritt erscheint nur, wenn einer `showInOnboarding: true` hat (der erste nach `order`).
- `onRelease:` für Halten-und-Loslassen (wird auch gesendet, wenn der Hotkey während des Haltens weggenommen wird).
- Ohne Standard (`default: nil`) tut der Hotkey nichts, bis die Person einen setzt.

## Entscheidungen

- **Nur Tasten mit Sondertasten (oder F-Tasten allein)**, keine reinen Sondertasten-Akkorde wie VoiceBuds `ctrl+shift`: die bräuchten Eingabeüberwachung und einen Event-Tap (VoiceBud macht das im Python-Kern). Carbon `RegisterEventHotKey` braucht keine Freigabe. Sondertasten allein lehnt der Recorder mit Erklärung ab.
- **Regeln rein und injizierbar**: Layout, macOS-Liste und andere Hotkeys kommen über `ShortcutRules.Context`; die Tests laufen gegen feste US- und Deutsch-Tabellen, unabhängig vom Mac.
- **Speicherform je Hotkey** `hotkeys.<id>`: `"off"` oder `{"keyCode": 40, "modifiers": ["control", "option", "command"]}` (lesbar beim Bearbeiten von Hand); Standard = Schlüssel fehlt. Eine kaputte Angabe kostet nur diesen Hotkey (VoiceBud `LossyShortcut`). Eine Wahl gleich dem Standard wird als Standard gespeichert.
- **Gleiche Tasten zweimal**: nur der erste Hotkey (Anzeigereihenfolge) wird registriert, der zweite steht auf `inactive` (VoiceBud: "a key twice goes to the first mode only"). Der Recorder lässt das gar nicht erst zu.
- **⌫ beim Aufnehmen entfernt den Kurzbefehl** (mit Rückgängig, Standard holt ihn zurück); VoiceBud kannte "keiner" nicht, ein generisches Modul braucht es.
- **Backend als Protokoll**: Carbon im Programm, Fake in Tests, Renders und Galerie. `start()` tut im Headless-/Render-Lauf nichts, also erreicht bei `--selftest`, `--render` und `make test` nichts macOS.
- **Onboarding-Schritt ohne Pflicht**: "Weiter" geht immer; die Statuszeile wechselt von "Drück die Tasten einmal zum Ausprobieren" auf "Klappt", sobald der Hotkey auf diesem Schritt gedrückt wurde (Drücke davor zählen nicht). Die Karte hat eine feste Höhe (`Metrics.Hotkeys.stepCardArea`), damit die Seite bei einer langen Ablehnung nicht springt.
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
- **Strang G (Prüfskripte)**: `HotkeysTokens.swift` enthält bewusst Zahlenwerte (Modul-Tokens wie `Kit/Design/Patterns/PatternTokens.swift`); bitte als Token-Datei behandeln oder in Kit verschieben. `HotkeysCatalog.swift` nutzt feste Szenengrößen (wie `PatternsCatalog`). `KeyCodes.specialNames` ("Esc", "Help", "F5") und die Tastenkappe `"fn"` im Recorder sind Tastenbeschriftungen, keine UI-Texte. `ShortcutCatalogText.swift` heißt `…Text.swift`, enthält aber neben `tr()` die Tabellenstruktur.
- **Strang E**: Bereich kommt über `Registry.settingsPanes` (id `hotkeys`).
- **Strang D**: Schritt kommt über `Registry.onboardingSteps` (id `hotkeys`, order 600, `isIncluded` nur mit `showInOnboarding`-Hotkey).
- **Welle 2**: Examples kann einen Beispiel-Hotkey mit `showInOnboarding: true` registrieren; Menüleiste/Hauptmenü können `HotkeyCenter.shared.display(id)` neben Einträgen zeigen.
- **Kit-Kandidaten**: `BigKeyCaps` (+ `Metrics.Hotkeys`-Tokens), falls ein anderer Strang große Tastenkappen braucht.

## Bekannte Lücken

- Echte Carbon-Registrierung, der lokale Event-Monitor, Fokusverlust, Zeitlimit und Haptik sind gebaut, aber nicht interaktiv ausprobiert (Regel §2.17, App nie normal gestartet). Abgesichert über Fake-Backend und synthetische Events; die Abfolge Recorder → Pause → Registrierung → Rücknahme ist getestet.
- Belegt eine andere App die Tasten erst später, merkt das Modul es nicht (Carbon meldet das nicht); der Zustand wird bei jeder Neuregistrierung geprüft.
- Die Layout-Tabellen in den Tests sind Ausschnitte (Grund- und ⇧-Ebene vollständig, ⌥-Ebene für die geprüften Tasten).
- Die Testtexte prüfen englische Teilstrings (`make test` setzt `STARTER_LANG=en`).
- `Package.swift` nicht gebaut (SwiftPM stürzt auf diesem Mac ab, siehe S0).
- Tastenname "Help" bleibt in beiden Sprachen englisch (wie VoiceBud).

## Prüfung (Befehle und Ergebnisse, 2026-10-12)

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
