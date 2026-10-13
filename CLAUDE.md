# CLAUDE.md

Verbindliche Regeln für jede Session und jeden Subagenten. Teil A gilt in jedem Projekt, das aus dem Starter entsteht, und wird nur über `rules/` geändert. Teil B verweist auf das Projekt.

<!-- regeln:anfang -->
## Teil A: Allgemeine Regeln

Erzeugt mit `make rules` aus `rules/`. Änderungen nur dort, nie in diesem Abschnitt.

Diese Regeln gelten für jede Session und jeden Subagenten in diesem Repository. Wer gegen eine Regel verstößt, hat seine Aufgabe nicht erfüllt, auch wenn alle Tests grün sind.

Die einzige Quelle der Regeln ist `rules/`. Teil A dieser Datei, die Wortlisten der Prüfungen (`rules/generated/begriffe.json`) und die Schreibregeln für KI-Texte (`rules/generated/ki-schreibregeln.json`) entstehen daraus mit `make rules`; `make check` prüft, dass alle drei übereinstimmen, und führt jedes Beispiel der Sprachpakete als Test aus.

### Rangfolge bei Widerspruch

1. `docs/agents/VORGABEN.md`: neue Vorgaben des Auftraggebers, bis sie in `rules/` eingearbeitet sind
2. `CLAUDE.md`: Teil A mit diesen Regeln, Teil B mit dem Verweis auf das Projekt
3. `docs/PROJECT.md`: Zweck, Zielgruppe, Fachsprache und Festlegungen des Projekts
4. `docs/DESIGN.md`: Tokens, Muster, Maße und Beispiele zur Gestaltung

### Schreiben

Gilt für jeden Text, den Menschen lesen: UI-Texte in beiden Sprachen, Nutzungsbeschreibungen der Berechtigungen, Fehlermeldungen, Hinweise, Texte, die die App mit lokaler KI in eigener Stimme schreibt, Doku, Code-Kommentare und Commit-Nachrichten. Verbotene Wörter und Zeichen stehen in Dokumenten, die eine Regel erklären, nur in Code-Formatierung.

- **S-01** Kein Mittelpunkt (`·`, U+00B7) und kein verwandter Punkt (`•`, `⋅`) als Trenner. Stattdessen eine eigene Zeile, Abstand im Layout, ein Komma oder ein Satz.
- **S-02** Keine Gedankenstriche zwischen Satzteilen (`—`, ` – `, ` - `, `--`). Der Halbgeviertstrich steht nur für Bereiche wie `2023–2026` oder `10–20 %`.
- **S-03** Keine Emojis, keine Deko-Pfeile (`→`, `->`, `=>`), keine Glyphen statt Symbolen (`▲`, `‹`, `✓`, `★`) und keine Ausrufezeichen. Symbole kommen aus SF Symbols über `Image(systemName:)`. Die Zeichen der Mac-Tasten sind erlaubt (`⌘ ⌥ ⌃ ⇧ ⇥ ⇤ ⇪ ⏎ ↩ ⌤ ⌫ ⌦ ⎋ ⇞ ⇟ ↖ ↘`, `🌐` vor einer Taste wie `🌐E`), Pfeiltasten nach einer Modifikatortaste (`⌘←`), als Paar (`↑/↓`, `↑ oder ↓`, `← and →`) und mit dem Wort Taste oder key (`↓-Taste`).
- **S-04** Keine Floskeln und Schmuckwörter, weder deutsch (`nahtlos`, `mühelos`, `revolutionär`, `innovativ`, `leistungsstark`, `smart`, `intelligent` als Schmuck, `Entdecke`, `Tauche ein`, `auf einen Blick`, `Magie`, `Reise`, `Lass uns`, `Willkommen bei`, `Mehr erfahren`, `Los geht’s`) noch englisch (`seamless`, `effortless`, `leverage`, `unlock`, `elevate`, `empower`, `delve`, `robust`, `cutting-edge`, `game-changer`, `revolutionize`, `supercharge`, `harness`, `streamline`, `in today’s …`, `whether you’re …`, `dive into`, `Let’s`, `Oops`). Stattdessen sagt der Text konkret, was passiert.
- **S-05** Deutsche Texte nutzen genau eine Anrede: die aus `starter.json` (`texts.anrede`), Standard `du` wie bei Apple und VoiceBud, sonst `Sie`. Die andere Form ist ein Fehler. Die Texte des Kits sind in der du-Form geschrieben; wer `sie` wählt, schreibt die deutschen Texte der `*Text.swift`-Dateien und der `App/Resources/InfoPlist.json` um (gemeinsame Pfade, die ein Projekt ändern darf), `make check-texts` listet jede Stelle. Knöpfe und Menübefehle stehen im Infinitiv (`Einstellungen öffnen`, `Freigabe erteilen`), englische im Imperativ (`Open Settings`).
- **S-06** Neutral beschreiben statt werben oder versprechen: keine Superlative und Versprechen (`die beste`, `perfekt`, `garantiert`, `the best`, `perfect`, `ultimate`), keine Wertung ohne Maßstab. Fachliche Neutralitätsregeln eines Projekts kommen als eigenes Sprachpaket in `rules/projekt/pakete/` dazu.
- **S-07** Kurz und konkret: ein Gedanke je Satz, eine Zahl mit Einheit statt eines Adjektivs, der Grund einer Bitte steht dabei (`Das Mikrofon läuft nur, während du aufnimmst`). Jede Zeile muss sich rechtfertigen, jeder Hinweis steht einmal je Ansicht, Fachbegriffe bekommen einen erklärenden Satz in der Fußnote oder eine Ebene tiefer.
- **S-08** Ein fehlender Wert wird mit seinem Grund benannt (`noch kein Lauf`, `nicht verfügbar, Modell fehlt`), nie als 0, nie als Abkürzung (`n. v.`, `N/A`), nie als Strich und nie als leere Zeile.
- **S-09** Kein Blindtext und keine offenen Merkzettel (`TODO`, `FIXME`, `Lorem ipsum`) in Texten und Kommentaren. Offene Punkte stehen in der Statusdatei oder in `docs/PROJECT.md`.
- **S-10** Jeder UI-Text steht in beiden Sprachen als `tr(en: "…", de: "…")` in einer Datei `*Text.swift` (`enum <Bereich>Text`), nie als Literal in einer Ansicht (`Text("…")`, `Button("…")`, `.help("…")`, `NSMenuItem(title: "…")`). Einsetzungen und Mehrzahl sind `static func`. Beide Texte tragen dieselben Einsetzungen und dasselbe Auslassungszeichen; im englischen Text steht kein Deutsch, im deutschen kein Englisch. `Text(verbatim:)` mit Literal nur mit Kommentar `// verbatim: Grund`, eine begründete Ausnahme einer Sprachregel mit `// text-ausnahme: Grund`. Nutzungsbeschreibungen der Berechtigungen stehen zweisprachig in `App/Resources/InfoPlist.json`.
- **S-11** Auslassungszeichen `…` statt drei Punkten; ein Menübefehl, der einen Dialog öffnet, endet damit, englisch direkt angehängt (`Settings…`), deutsch mit Leerzeichen wie bei Apple (`Einstellungen …`). Deutsche Anführungszeichen `„…“`, englische `“…”`. Keine Verkürzungen mit Apostroph im Deutschen (`geht’s`, `gibt’s`). Zahlen, Daten, Dauern und Größen nur über `Format` und `ByteText` in der UI-Sprache, Einheit mit schmalem geschütztem Leerzeichen.
- **S-12** Code-Kommentare sind englisch und nennen den Grund selbst, ohne Verweise auf Bauplan, Stränge, Statusberichte, Vorgaben-Nummern oder Personen. Standardmäßig gibt es keinen Kommentar; einer steht nur für einen nicht offensichtlichen Grund. Kein auskommentierter Code, keine Abschnittsbanner außer `// MARK:`.
- **S-13** Die App spricht Englisch und Deutsch (`Localizer`, live umschaltbar). Doku, `CLAUDE.md`, Skills, Agenten und Statusdateien sind deutsch; Bezeichner, Code-Kommentare und Commit-Nachrichten englisch. Schlüssel der Einstellungs- und Regeldateien (`starter.json`, `starter.manifest.json`, `rules/`) und die Schalter der Skripte (`--pruefen`) sind deutsch oder englisch, wie sie sind; Code übernimmt sie unverändert.
- **S-14** Zeitangaben kommen aus Daten und `Format`, nie als fester Text: relative Zeiten (`vor 5 Minuten`) erzeugt `RelativeDateTimeFormatter` oder `Format`, nicht ein Literal. Projekte mit Datenständen schalten das Paket `zeitwoerter` in `starter.json` unter `texts.zusatzpakete` ein.

### Design

Gilt für jede Oberfläche unter `App/Sources`: Fenster, Einstellungsbereiche, Onboarding-Schritte, Insel und Kapsel, Menüleisten-Panel, Menüs, und für Icon und DMG unter `tools/`. Maße, Muster und Beispiele stehen in `docs/DESIGN.md`; Vorbild ist VoiceBud auf macOS 26.

- **D-01** Farben, Abstände, Radien, Schriftgrade und Federn kommen nur aus `App/Sources/Kit/Design` (`Theme`, `Space`, `Radius`, `TypeScale`, `Motion`, `Metrics`, `IslandPalette`). Farben entstehen aus dem SwiftUI-`ColorScheme` über `Theme(scheme)`, nie aus dynamischem `NSColor` oder Systemfarben wie `.secondary`, damit Renders ohne Fenster genau wie das Fenster aussehen. Ein fehlender Wert wird ein neues Token in `Kit/Design` (mit Kontrasttest), keine Zahl in der Ansicht; eine begründete Ausnahme trägt `// design-ausnahme: Grund`.
- **D-02** Abstände kommen aus `Space`: Raster 8, 12, 16, 24, 32 (`Space.xs` bis `Space.xl`), 4 und 2 nur zum Feinausgleich, 20 für den Inhalt eines Einstellungsbereichs (`Space.pane`), 12 und 9 als Einzug von Zeilen in Karten (`Space.rowX`, `Space.rowY`), 9 zwischen Symbol und Titel (`Space.iconGap`). Zeilen in Karten und Listen sind mindestens 44 pt hoch (`Metrics.rowMinHeight`), Zeilen der Seitenleiste 34 pt (`Metrics.sidebarRow`). Ecken sind kontinuierlich (`style: .continuous`) mit Radien aus `Radius`, Linien Haarlinien von 0,5 pt.
- **D-03** Nur die Systemschrift (SF Pro) in den Graden von `TypeScale`, keine eigene Schrift und keine freie Größe. Zahlen, die sich ändern, mit `.monospacedDigit()`. Kein Textstil des Systems (`.headline`, `.body`). Kleinster Grad für Text ist `TypeScale.caption` (11 pt), für Plaketten und Zähler `TypeScale.badge` (10,5 pt); `TypeScale.micro` (9,5 pt) nur in Insel, Kapsel und für das Symbol eines Chips.
- **D-04** Symbole nur aus SF Symbols über `Image(systemName:)`, keine Bild-Assets für Icons, keine Emojis, keine Glyphen als Icons. Das App-Icon entsteht im Code (`make icon`). Icon-Knöpfe tragen ein `.accessibilityLabel` aus einer `*Text.swift`-Datei.
- **D-05** Ein Onboarding-Schritt beginnt mit `OnboardingPage`, ein Einstellungsbereich mit `PaneScaffold`; Gruppen sind `SettingsSection`, Zeilen die Muster aus `Kit/Design/Patterns` (`ToggleRow`, `PickerRow`, `ValueRow`, `ButtonRow`, `ProgressRow`, `ListCard`). Eigene Layouts nur, wo kein Muster passt; ein allgemein nützliches wird als Kandidat für `Kit/Design` gemeldet.
- **D-06** Jede Ansicht ist in fünf Sekunden verständlich: der Titel nennt sie, die Unterzeile sagt mit einem kurzen Satz oder einer Zahl, was hier passiert, und es gibt genau eine Hauptaktion (`.buttonStyle(.primary)`). Hält ein Statusfeld die Aktion, ist `Weiter` nicht primär. Fachliches liegt eine Ebene tiefer.
- **D-07** Ruhig und präzise statt geschmückt: keine Glows, Blobs, Schatten-Stapel, Unschärfe als Schmuck, kein Lila-Verlauf auf allem, keine bunten Kacheln ohne Bedeutung, keine Animation zur Zierde. Glas nur nativ (Seitenleiste und Werkzeugleiste unter macOS 26) oder über `GlassSurface`, das in Renders einen Token-Ersatz zeichnet. Verläufe nur als Token (`Theme.accentGradient`, `Wallpaper`).
- **D-08** Hell und dunkel sind beide gestaltet. Text erreicht mindestens 4,5:1 auf seinem Grund, Ringe und Bedienelemente 3:1; jede neue Farbe bekommt ihren Kontrasttest in `App/Tests/DesignTests.swift`.
- **D-09** Bewegung nur über die Federn aus `Motion`, und nur dort, wo sie einen Zustandswechsel erklärt. Reduce Motion wird beachtet (`Motion.adaptive`, Überblendung statt Bewegung); Endlos-Animationen nur für Arbeitszustände (Spinner, Pegel).
- **D-10** Deutsche Texte sind etwa 30 % länger und passen trotzdem: keine festen Breiten für Text, kein Abschneiden, keine Silbentrennung mitten im Wort, kein harter Umbruch mitten im Satz, weder in UI-Texten noch in Absätzen der Doku. Ausnahme ist eine bewusst ausgewogene zweizeilige Unterzeile wie in VoiceBud: sie steht mit dem Kommentar `// umbruch: Grund` direkt über dem Text. Geprüft wird in den Renders mit `de`.
- **D-11** Jeder Bereich mit Daten hat gestaltete Zustände: leer (`EmptyState` mit Titel, einem Satz und höchstens einer Aktion), beschäftigt (`Spinner`, `ProgressRow`), Fehler (`InlineNotice`: was fehlt und was daraus folgt). Ein optionaler Abschnitt ohne Inhalt entfällt samt Überschrift.
- **D-12** Alles ist mit der Tastatur erreichbar (Fokus sichtbar, `↑` und `↓` in Listen, `Esc`, `⌘W`, `⌘,`), Bedienelemente haben Namen für VoiceOver, Trefferflächen sind mindestens 24 pt groß, Zeilen in Karten und Listen mindestens 44 pt (`Metrics.rowMinHeight`).
- **D-13** Jeder sichtbare Zustand hat eine `RenderScene` (Kennung `<bereich>.<zustand>`). Vor „fertig“ werden alle betroffenen Szenen in en und de, hell und dunkel gerendert (`make shots ONLY=<präfix>`) und jedes PNG angesehen; die angesehenen Bilder stehen in der Statusdatei. Ohne Bilder lautet das Ergebnis der Sichtprüfung „nicht geprüft“.
- **D-14** Fenster entstehen über `WindowHost`, die Aktivierungsrichtlinie regelt `AppForm`: `.regular` mit Modul `window`, sonst `.accessory`, Einstellungen und Onboarding schalten vorübergehend um. Die Insel misst den Bildschirm (Notch, Menüleistenhöhe) und legt nichts fest; Panels der Menüleiste sind 320 bis 360 pt breit.

### Technik

Gilt für jeden Code im Repository: App, Tests, Skripte, Werkzeuge und Konfiguration.

- **T-01** Gebaut wird ohne Xcode und ohne SwiftPM: `make build` ruft über `scripts/build.sh` einmal `swiftc` auf, das SDK wählt `scripts/pick-sdk.sh`. `Package.swift` ist der Zweitweg für Xcode; die Quellen bauen auf beiden Wegen. Verboten sind `#Preview`, `@Entry`, `@Generable`, `@Model` (SwiftData), `.xcassets`, `.icon`, `.xib`, Storyboards, Core-Data-Modelle, mlx-swift, XCTest und Swift Testing. Mindestens macOS 26.0; jede neuere API steht hinter `#available`.
- **T-02** Swift 6 mit `-default-isolation MainActor`. Werte, die Isolationsgrenzen überqueren, sind `nonisolated` und `Sendable`; `@unchecked Sendable` und `nonisolated(unsafe)` nur mit Kommentar, der den Grund nennt. Kein `try!`, kein `as!` und kein `!` zum Entpacken außerhalb von Tests; Fehler werden geworfen und mit einem Text aus `*Text.swift` gezeigt.
- **T-03** Module sind Schalter beim Kompilieren (`-D MODUL_<NAME>`); jedes registriert sich nur über `<Name>Module.register()` in `Kit/Main/Modules.swift`. Modulübergreifender Code steht in `#if MODUL_<NAME>` … `#endif`: genau ein Flag je `#if`, ohne `||`, `&&`, `!` und `#elseif`; braucht Code zwei Module, stehen zwei einfache Blöcke ineinander; ein `#else`-Zweig bleibt beim Entfernen stehen. Jede erlaubte Kombination baut (`make build MODULES=a,b`), `bin/starter remove <modul>` entfernt ein Modul vollständig.
- **T-04** Jede Sache hat einen Weg: Einstellungen nur über `SettingKey` und `Settings.shared`, gespeichert in `~/Library/Application Support/<bundleId>/settings.json`; Daten über `Database` (sqlite3, nummerierte Migrationen); Berechtigungen nur über `Kit/Permissions`; Fenster über `WindowHost` und `AppForm`; Texte über `tr`; Formatierung über `Format`; Protokolle über `Log`. Beiträge von Modulen (Seiten, Bereiche, Schritte, Menüeinträge, Szenen) laufen über `Registry`.
- **T-05** Kein Netz im Normalfall: keine Analyse, keine Telemetrie, keine Update-Prüfung, keine Absturzberichte. Einzige Ausnahme ist ein Modell-Download, den die Person ausdrücklich startet, mit Größe vorher und Abbruch (Module `ai` und `mlx`), und Entwicklerwerkzeuge unter `scripts/` (pip in einer Projekt-venv).
- **T-06** Eine Berechtigung wird erst angefragt, wenn ihre Funktion sie braucht, mit Nutzungsbeschreibung in beiden Sprachen aus `App/Resources/InfoPlist.json`. Inhalte der Person (Texte, Aufnahmen, Dateien) werden nie protokolliert und verlassen den Mac nicht; Modelle liegen nie im Repository.
- **T-07** Keine neue Abhängigkeit (Swift-Paket, pip-Paket, Binärdatei, Werkzeug) ohne Eintrag in `docs/DECISIONS.md` mit Grund. Werkzeuge in `scripts/` sind Python 3.9 nur mit Standardbibliothek (`/usr/bin/python3`) oder zsh mit `set -euo pipefail`; kein Node.
- **T-08** Bauen und Prüfen zeigt nie ein Fenster, fragt nie nach Berechtigungen, meldet keine Anmeldeobjekte an und lässt keinen Prozess laufen: Prüfungen laufen über `--render`, `--selftest` und `STARTER_HEADLESS=1`. `make run` und der Blick in die laufende App sind Sache eines Menschen am Ende.
- **T-09** Logik ohne Oberfläche hat Tests in `App/Tests` (`TestSuite` aus `App/Tests/Harness`), Skripte in `scripts/tests` (unittest). Tests nutzen nie das Netz, nie echte Einstellungen und nie Application Support (`STARTER_DATA_DIR`); Uhren und Bildschirme werden hineingereicht statt abzuwarten. Erwartungswerte kommen aus der Anforderung oder einer Handrechnung, nie aus der Ausgabe des Codes.
- **T-10** Erzeugte Dateien werden nie von Hand geändert (`build/gen/`, `rules/generated/`, Teil A dieser Datei). Geändert wird die Quelle (`starter.json`, `rules/`), danach `make rules` oder `make build`.
- **T-11** Standard ist die Ad-hoc-Signatur; Developer ID, Hardened Runtime und Notarisierung nur über `signing` in `starter.json`. Zugangsdaten (Notarisierung, Schlüssel) stehen nie im Repository, in Protokollen oder in Argumenten, sondern im Schlüsselbund.

### Arbeitsweise

Gilt für jede Session und jeden Subagenten, der im Repository arbeitet.

- **A-01** Neue Vorgaben stehen in `docs/agents/VORGABEN.md` und gehen allem anderen vor. Jede Vorgabe wird innerhalb eines Arbeitstags als Regel eingearbeitet (im Projekt in `rules/projekt/`, im Starter in `rules/gruppen/` und `rules/pakete/`), mit `make rules` verteilt und in `VORGABEN.md` als eingearbeitet markiert. Jede Vorgabe wird an jeden gestarteten Subagenten weitergegeben.
- **A-02** Vor jedem Push ist `make check` grün (Regeln, Texte, Gestaltung, Kit, Build, Tests; der Hook `pre-push` führt es aus, ohne Mac nur `make check-light`), für geänderte Module zusätzlich `make typecheck` oder `make build MODULES=…` der betroffenen Kombinationen. Warnungen gelten als Fehler, `make check` bricht bei jeder ab. Nach dem Prüfen läuft kein Prozess der App mehr.
- **A-03** Kleine Commits auf einem eigenen Branch, nie direkt auf `main` (Ausnahme: die Integration mit Freigabe), nie fremde Branches umschreiben. Nachrichten auf Englisch im Format `type(scope): subject`, die erste Zeile höchstens 100 Zeichen, Zeile 2 leer. Hooks werden nie umgangen (`--no-verify`, `core.hooksPath`).
- **A-04** Jede Person committet unter ihrer eigenen Identität, nie unter der einer anderen. Ein Projekt trägt seine Commit-Identität in `starter.json` (`commit`) ein; bis dahin, und in einer Kopie vor `bin/starter init`, nimmt `commit-msg` keinen Commit an, danach nur Commits unter dieser Identität. Die Identität nennt der Auftraggeber, sie wird nie erfunden. Der Hook `session-start` und `make hooks` setzen sie nur, wenn Git noch keine kennt, und überschreiben nie eine vorhandene. Der Starter selbst trägt keine; dort prüft `commit-msg` nur das Format.
- **A-05** Jeder Strang ändert nur seine eigenen Dateien (`docs/agents/straenge.json`); Bedarf an fremden Dateien steht als Anfrage in der eigenen Statusdatei. Gemeinsame Dateien (`Makefile`, `starter.json`, `CLAUDE.md`, `rules/`, Manifest) ändert nur die Integration. Ausnahme: wer einen Befund behebt, der in `rules/baseline/` steht, verkleinert die Baseline mit `--baseline-aktualisieren` und nennt das in der Statusdatei; lokal ist ein veralteter Eintrag nur ein Hinweis, in CI (`--ci`) ein Fehler.
- **A-06** In einem Projekt bleiben Kit-Pfade aus `starter.manifest.json`, Teil A von `CLAUDE.md`, alle Dateien in `rules/` außer `rules/projekt/` und die leeren Baselines der Prüfungen unverändert. Eigene Regeln und Sprachpakete stehen in `rules/projekt/`; Bedarf am Kit steht in `docs/STARTER_FEEDBACK.md` mit Datei, Grund und Test.
- **A-07** Kein Paket gilt ohne Gegenprüfung als fertig: die Subagenten `pruefer-korrektheit`, `pruefer-laie-ux`, `pruefer-sicherheit`, `pruefer-integration` und `pruefer-design` suchen Fehler, höchstens zwei gleichzeitig, danach versucht `widerleger`, jeden Befund zu widerlegen (Workflow `red-team`).
- **A-08** Beweise statt Behauptungen: Befehle mit Ausgabe, Tests und die angesehenen Renders stehen in der Statusdatei, dazu ein Abschnitt `Bekannte Schwächen`. Was nicht ausgeführt wurde, gilt als nicht geprüft; ein ausgefallener Prüfer ist kein Ergebnis ohne Befund.
- **A-09** Offene Fragen an den Auftraggeber stehen gesammelt in `docs/PROJECT.md`, statt zu raten.
- **A-10** Renders, Build-Ausgaben, DMGs, Modelle, venvs und Testberichte gehören nie ins Repository (`build/` ist ausgenommen). Bilder für die Doku kommen nur über `make readme-shots` aus der Liste `docs/screenshots/list.txt`.

### Sprachpakete

Die Prüfungen (`make check-texts`, `make check-design`, Hook `commit-msg`) und die Schreibregeln für KI-Texte lesen dieselben Pakete aus `rules/pakete/`. Anrede laut `starter.json`: `du`. Zusätzlich eingeschaltet: keine.

| Paket | Gruppe | Prüfung | Sprachen | Stand | Begriffe |
|---|---|---|---|---|---|
| `zeichen` | schreiben | `check_texts` | de, en | an, Pflicht | 8 |
| `floskeln` | schreiben | `check_texts` | de | an, Pflicht | 5 |
| `floskeln-en` | schreiben | `check_texts` | en | an, Pflicht | 2 |
| `neutral` | schreiben | `check_texts` | de | an, Pflicht | 1 |
| `neutral-en` | schreiben | `check_texts` | en | an, Pflicht | 1 |
| `anrede` | schreiben | `check_texts` | de | an, Pflicht | 2 |
| `fehlende-werte` | schreiben | `check_texts` | de, en | an, Pflicht | 3 |
| `platzhalter` | schreiben | `check_texts` | de, en | an, Pflicht | 1 |
| `englisch` | schreiben | `check_texts` | de | an, Pflicht | 2 |
| `deutsch` | schreiben | `check_texts` | en | an, Pflicht | 2 |
| `kommentare` | schreiben | `check_texts` | de, en | an, Pflicht | 1 |
| `zeitwoerter` | schreiben | `check_texts` | de, en | aus, einschaltbar | 1 |
| `layout` | design | `check_texts` | de, en | an, Pflicht | 2 |
| `gestaltung` | design | `check_design` | Swift-Code | an, Pflicht | 8 |
| `swift-technik` | technik | `check_design` | Swift-Code | an, Pflicht | 7 |

### Werkzeuge der Regeln

Wo die Werkzeuge und Bausteine liegen, die die Regeln nennen. `make check-rules` prüft, dass jeder Pfad existiert.

| Werkzeug | Regeln | Pfad |
|---|---|---|
| `make rules` und `make check-rules` | A-01, T-10 | `scripts/rules_sync.py` |
| `make check-texts`: UI-Texte, InfoPlist, Kommentare und Doku gegen die Sprachpakete | S-01, S-02, S-03, S-04, S-05, S-06, S-08, S-09, S-10, S-11, S-12, S-14, D-04, D-10 | `scripts/check_texts.py` |
| `make check-design`: Swift-Code in `App/Sources`, `App/Tests` und `tools` gegen die Pakete `gestaltung` und `swift-technik` | D-01, D-02, D-03, D-04, D-07, D-09, T-01, T-02, T-03, T-04, T-05, T-06 | `scripts/check_design.py` |
| Prüfung der Commit-Nachricht und des Autors, in CI mit `--github` (die Commits des Pushs oder Pull Requests) | S-01, S-02, S-03, S-04, A-03, A-04 | `scripts/check_commit_msg.py` |
| Git-Hooks `commit-msg` und `pre-push` (`make hooks`) | A-02, A-03, A-04 | `scripts/hooks` |
| Session-Hook: Werkzeuge, Git-Hooks und Git-Identität (nie überschrieben) beim Start jeder Session | A-04 | `.claude/hooks/session-start.py` |
| Subagenten für Prüfung und Widerlegung | A-07 | `.claude/agents` |
| Red-Team-Workflow über die Renders | A-07 | `.claude/workflows/red-team.js` |
| `bin/starter` (`init`, `remove`, `strip-examples`, `sync`, `check-kit`, `modules`, `doctor`) | A-06, T-03 | `bin/starter` |
| `make check-kit`: Kit-Dateien unverändert, jedes Modul entfernbar, Prüfungen eingeschaltet | A-06 | `scripts/check_kit.py` |
| `make icon`: App-Symbol aus Akzent und SF Symbol | D-04 | `scripts/icon.sh` |
| Gestaltung der Oberfläche mit Beispielen | D-01, D-02, D-03, D-04, D-05, D-06, D-07, D-08, D-09, D-10, D-11, D-12, D-13, D-14 | `docs/DESIGN.md` |
| Baselines der Prüfungen (dürfen nur schrumpfen, im Projekt leer) | A-06 | `rules/baseline` |
| `make check`, `make build`, `make test`, `make shots`, `make doctor` | A-02, T-01, T-09, D-13 | `Makefile` |
| Tokens `Theme`, `Space`, `Radius`, `TypeScale`, `Motion`, `Metrics`, `IslandPalette` | D-01, D-02, D-03, D-07, D-09 | `App/Sources/Kit/Design` |
| Muster für Onboarding-Schritte und Einstellungsbereiche | D-05, D-06, D-11 | `App/Sources/Kit/Design/Patterns` |
| Kontrasttests der Tokens | D-08 | `App/Tests/DesignTests.swift` |
| `tr(en:de:)`, `Localizer`, `Format` | S-10, S-11, S-13 | `App/Sources/Kit/Core/Lang.swift` |
| `SettingKey` und `Settings` | T-04 | `App/Sources/Kit/Core/Settings.swift` |
| `Database` mit Migrationen | T-04 | `App/Sources/Kit/Core/Database.swift` |
| `Registry` für Beiträge der Module | T-03, T-04 | `App/Sources/Kit/Core/Registry.swift` |
| `Modules.registerAll()`, die einzige Liste der Module | T-03 | `App/Sources/Kit/Main/Modules.swift` |
| `AppForm`, `WindowHost`, `AppActions` | D-14, T-04 | `App/Sources/Kit/Main` |
| Berechtigungen | T-04, T-06 | `App/Sources/Kit/Permissions` |
| `RenderRunner` (`--render`, `make shots`) | D-13, T-08 | `App/Sources/Kit/Render/RenderRunner.swift` |
| `SelfTestRunner` (`--selftest [präfix]`) | T-08 | `App/Sources/Kit/Main/SelfTest.swift` |
| Test-Harness `TestSuite` | T-09 | `App/Tests/Harness` |
| Build mit einem `swiftc`-Aufruf und SDK-Wahl | T-01 | `scripts/build.sh` |
| Erzeugte Konfiguration (`AppConfig`, Info.plist, InfoPlist.strings) | T-10 | `scripts/gen_config.py` |
| Nutzungsbeschreibungen der Berechtigungen in beiden Sprachen | S-10, T-06 | `App/Resources/InfoPlist.json` |
| Einstellungen des Projekts: Name, Akzent, Module, Anrede, Commit-Identität, Signatur | S-05, A-04, T-03, T-11 | `starter.json` |

<!-- regeln:ende -->

## Teil B: Projekt

Zweck, Zielgruppe, Fachsprache, App-Formen und offene Fragen stehen in `docs/PROJECT.md`. Vor dem ersten Schritt lesen:

1. `docs/agents/VORGABEN.md`: neue Vorgaben, gehen allem vor.
2. `docs/PROJECT.md`: das Projekt, seine Festlegungen und offenen Fragen.
3. `CONTRIBUTING.md`: Branch, Commit, Prüfung und Merge.
4. Vor jeder Oberfläche `docs/DESIGN.md`; vor Arbeiten an Aufbau, Modulen und Build `docs/ARCHITEKTUR.md` und `docs/MODULE.md`; vor Signatur und DMG `docs/VERTEILUNG.md`.
5. Vor lokaler KI `docs/KI.md`. <!-- modul:ai -->
6. Im Strangbetrieb die eigene Datei-Zuständigkeit in `docs/agents/straenge.json`. Ein Strang ist ein Arbeitspaket mit eigener Session, eigenem Branch und festen Dateien; die Integration führt die Stränge zusammen und pflegt die gemeinsamen Dateien.

Der Einstieg für einen Agenten in ein neues Projekt (Bootstrap) steht in `README.md` im Abschnitt „Ein neues Projekt starten“.

Die eine Einstellungsdatei ist `starter.json`: Name, Bundle-ID, Akzent, Symbol, Module, Berechtigungen, Sprachen und Anrede der Texte, Commit-Identität und Signatur. `scripts/gen_config.py` erzeugt daraus beim Build `AppConfig`, Info.plist und die Nutzungsbeschreibungen. Welche Pfade dem Starter gehören und welche dem Projekt, steht in `starter.manifest.json`.

Die wichtigsten Befehle: `make doctor` prüft die Werkzeuge, `make build` baut `build/<Name>.app` ohne Xcode, `make test` führt die Swift- und Python-Tests aus, `make shots` rendert jeden Zustand in en und de, hell und dunkel nach `build/shots/`, `make check` ist das Tor vor jedem Push. Die App wird beim Bauen und Prüfen nie normal gestartet (T-08); Prüfungen laufen über `--render`, `--selftest` und `STARTER_HEADLESS=1`.

<!-- projektregeln:anfang -->
### Projektregeln

Erzeugt mit `make rules` aus `rules/projekt/`. Änderungen nur dort, nie in diesem Abschnitt.

Regeln dieses Projekts, zusätzlich zu Teil A. Neue Vorgaben aus `docs/agents/VORGABEN.md`, die nur dieses Projekt betreffen, landen hier.

Keine Projektregeln festgelegt.

Keine Sprachpakete des Projekts.

<!-- projektregeln:ende -->

<!-- nur-im-starter:anfang -->
### Bau des Starters

Dieses Repository ist die Vorlage selbst. Bauakten und Statusberichte der Stränge liegen in `docs/bau/`; `bin/starter init` entfernt sie und diesen Abschnitt in einem neuen Projekt. Änderungen am Starter folgen `CONTRIBUTING.md` und bekommen einen Eintrag in `CHANGELOG.md`.
<!-- nur-im-starter:ende -->
