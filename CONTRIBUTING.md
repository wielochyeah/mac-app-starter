# Mitarbeit

Die verbindlichen Regeln stehen in `CLAUDE.md` (Teil A aus `rules/`). Diese Datei beschreibt den Ablauf. Bei Widerspruch gilt `CLAUDE.md`.

## Ablauf

- Arbeit auf einem eigenen Branch, nie direkt auf `main`. In Projekten heißen die Branches `claude/<projekt>-<strang>`.
- Kleine Commits, mindestens stündlich pushen. Fremde Branches werden nie umgeschrieben.
- Commit-Nachrichten auf Englisch im Format `type(scope): subject`, zum Beispiel `feat(island): add a progress state with cancel`. Typen: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`; maßgeblich ist `scripts/check_commit_msg.py`. Der Hook `commit-msg` prüft dazu Zeichen und Floskeln.
- Commit-Autor ist die Identität aus `starter.json` (`commit.name`, `commit.email`). Der Hook `session-start` setzt sie; nach `bin/starter init` ist sie leer, bis das Projekt seine eigene einträgt, und bis dahin nimmt der Hook `commit-msg` keinen Commit an. Ohne Claude Code einmal `make hooks` ausführen und die Identität von Hand setzen: `git config user.name "<commit.name>"` und `git config user.email "<commit.email>"`.
- Zugangsdaten (Developer ID, Notarisierungsprofil, Tokens) werden nie ausgegeben, geloggt oder committet; sie liegen im Schlüsselbund oder in den Geheimnissen der CI.

## Prüfen

| Wann | Befehl |
|---|---|
| vor jedem Push | `make check`: Regeln (`make check-rules`), Texte (`make check-texts`), Design-Tokens (`make check-design`), Kit-Pfade (`make check-kit`), Build und Tests |
| bei Änderungen an Modulen oder Querbezügen | zusätzlich `make build MODULES=<kombination>` für jede berührte Kombination und `STARTER_HEADLESS=1 build/<Name>.app/Contents/MacOS/<Name> --selftest` |
| nach jeder sichtbaren Änderung | `make shots ONLY=<präfix>` und jede Szene in en und de, hell und dunkel mit dem Werkzeug Read ansehen (Skill `screenshots`) |
| vor einer Weitergabe | `make dmg` und die Schritte im Skill `release-dmg` |

Warnungen gelten als Fehler. Ausnahmen in den Prüfskripten stehen mit Grund an der Stelle (`// design-ausnahme: <grund>`, `// verbatim: <grund>`); die Liste bekannter Funde der Textprüfung darf nur schrumpfen.

Beim Bauen und Prüfen startet niemand die App normal, fragt keine Berechtigung an, registriert kein Anmeldeobjekt und lässt keinen Prozess laufen. Laufzeitverhalten zeigen `make test`, `make shots` und `--selftest` mit `STARTER_HEADLESS=1`; `make run` ist der letzte Schritt einer Person am eigenen Mac.

## Dateien und Zuständigkeit

- Im Strangbetrieb ändert jeder Strang nur die Dateien, die ihm in `docs/agents/straenge.json` gehören. Bedarf an fremden Dateien steht als Anfrage in der eigenen Statusdatei `docs/agents/status/<strang>.md`.
- Gemeinsame Dateien ändert nur die Integration. Die vollständige Liste steht im Feld `integration.dateien` von `docs/agents/straenge.json`.
- Die Statusdatei führt Beweise (Befehle mit Ausgabe, Tests, angesehene Renders) und einen Abschnitt „Bekannte Schwächen“. Vorlage: `docs/agents/status/README.md`.

## Kit und Projekt

`starter.manifest.json` trennt Kit-Pfade (gehören dem Starter), gemeinsame Pfade (liefert der Starter, das Projekt darf sie ändern) und Projekt-Pfade. In einem Projekt werden Kit-Pfade und Teil A von `CLAUDE.md` nicht geändert. Wer dort etwas braucht, trägt es in `docs/STARTER_FEEDBACK.md` ein (Datei, Grund, Test); der Skill `starter-rueckfluss` macht daraus einen Pull Request im Starter.

## Regeln ändern

1. Neue Wünsche des Auftraggebers stehen in `docs/agents/VORGABEN.md`.
2. Die Vorgabe wird innerhalb eines Arbeitstags als Regel eingearbeitet: in einem Projekt in `rules/projekt/`, beim Bau des Starters in `rules/gruppen/` und `rules/pakete/` (Ablauf in `rules/README.md`).
3. `make rules` erzeugt Teil A und den Abschnitt „Projektregeln“ von `CLAUDE.md` und die Wortlisten neu.
4. In `VORGABEN.md` wird die Vorgabe mit Regelkennung und Commit als eingearbeitet markiert.

Teil A von `CLAUDE.md` wird nie von Hand geändert.

## Bausteine anlegen

| Aufgabe | Weg |
|---|---|
| neues Feature | Skill `neues-feature`: Ordner unter `App/Sources/Features/`, Texte, Speicher, Registrierung, Szenen, Tests |
| Seite im Hauptfenster | Skill `neue-ansicht` | <!-- modul:window -->
| Einstellung oder Einstellungsbereich | Skill `neue-einstellung` |
| Einrichtungsschritt | Skill `neuer-onboarding-schritt` |
| Berechtigung | Skill `neue-berechtigung` |
| Zustand der Insel | Skill `insel-zustand` | <!-- modul:island -->
| Inhalt im Statusmenü | Skill `menueleisten-app` | <!-- modul:menubar -->
| geplante Aufgabe | Skill `hintergrund-job` | <!-- modul:background -->
| globaler Kurzbefehl | Skill `kurzbefehl` | <!-- modul:hotkeys -->
| Funktion mit lokaler KI | Skill `ki-funktion` | <!-- modul:ai -->
| UI-Text | in `<Bereich>Text.swift` als `tr(en:de:)`, nie als Literal in einer View |
| Farbe, Abstand, Radius, Schriftgröße, Bewegung | Token aus `App/Sources/Kit/Design/`; fehlt eines, steht der Bedarf in `docs/STARTER_FEEDBACK.md` |

## Ein Muster je Problem

Für jedes wiederkehrende Problem gibt es genau einen Weg. Wer einen zweiten findet, meldet ihn als Anfrage, statt ihn zu kopieren.

| Problem | Muster |
|---|---|
| sichtbarer Text | `enum <Bereich>Text` mit `tr(en:de:)`; Mehrzahl und Platzhalter als `static func` |
| Zahl, Dauer, Datum in der UI | `Format.number`, `Format.decimal`, `Format.seconds`, `Format.day`, `Format.time` (folgen der UI-Sprache) |
| Einstellung | `SettingKey` neben dem Besitzer, `Settings.shared[.key]` |
| gespeicherte Daten | `Database` mit nummerierten Migrationen; Pfade nur über `Paths` |
| Beitrag zur Oberfläche | `Registry` im `register()` des Features oder Moduls |
| Fenster öffnen | `AppActions.openSettings(pane:)`, `openOnboarding()`, `openMainWindow(page:)`; eigene Fenster über `WindowHost.show` |
| Bezug auf ein Modul | ein eigener `#if MODUL_<NAME>` … `#endif` mit genau einem Flag, ohne `\|\|`, `&&` und `!`; für zwei Module zwei einfache Blöcke ineinander |
| Beobachten außerhalb von SwiftUI | `Observing.track(_:while:onChange:)` |
| Protokoll | `Log.debug`, `info`, `warn`, `error`; nie Inhalte der Nutzerin |
| Einstellungsbereich | `PaneScaffold` mit `SettingsSection` und den Zeilenmustern |
| Einrichtungsschritt | `OnboardingPage` mit `OnboardingHeader`, `OnboardingStatusSlot`, `OnboardingHint` |
| Namen von Dateien und Typen | Englisch, Typen in UpperCamelCase, eine Hauptsache je Datei, Dateiname gleich Typname |

## Tests

- Swift-Tests liegen in `App/Tests/<Bereich>Tests.swift` (Tests eines Features in `App/Tests/Features/`, das dem Projekt gehört) innerhalb von `#if TESTING`, als Unterklasse von `TestSuite`; der Test-Runner findet sie selbst. XCTest und Swift Testing gibt es ohne Xcode nicht.
- Python-Tests für Werkzeuge liegen in `scripts/tests/` (`unittest`, nur Standardbibliothek).
- Tests rufen nie das Netz auf, fragen keine Berechtigung an und öffnen kein Fenster. Uhr, Bildschirme und Tastaturbelegung werden eingespeist. Erwartungswerte kommen aus der Anforderung oder einer Handrechnung.

## Gegenprüfung

Kein Paket gilt ohne Gegenprüfung als fertig. Die Subagenten `pruefer-korrektheit`, `pruefer-laie-ux`, `pruefer-design`, `pruefer-sicherheit` und `pruefer-integration` suchen Fehler aus ihrem Blickwinkel, danach versucht `widerleger`, jeden Befund zu widerlegen. Befunde werden mit Commit oder begründeter Ablehnung in der Statusdatei abgearbeitet. Der Workflow `.claude/workflows/red-team.js` führt alle Blickwinkel zusammen aus (Skill `red-team`).
