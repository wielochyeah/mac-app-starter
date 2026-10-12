# rules/

Die einzige Quelle aller Regeln für Agenten. Was hier steht, gilt; `CLAUDE.md` Teil A, die Wortlisten der Prüfungen und die Schreibregeln für KI-Texte entstehen daraus oder lesen es direkt.

## Aufbau

| Datei | Inhalt | Wer liest sie |
|---|---|---|
| `index.json` | Präambel, Rangfolge, Gruppen und Pakete, Werkzeuge der Regeln mit Pfad, Bereiche, Prüfumfang mit begründeten Ausnahmen | `make rules`, alle Prüfungen |
| `gruppen/schreiben.json` | S-01 bis S-14: Zeichen, Floskeln, Anrede, neutrale Sprache, fehlende Werte, zwei Sprachen, Typografie, Kommentare | `make rules` (Teil A), KI-Prompts |
| `gruppen/design.json` | D-01 bis D-14: Tokens, Raster, Typografie, Symbole, Muster, eine Hauptaktion, keine Deko, hell und dunkel, Bewegung, deutsche Längen, Zustände, Barrierefreiheit, Renders, App-Formen | `make rules` (Teil A) |
| `gruppen/technik.json` | T-01 bis T-11: Build ohne Xcode, Swift 6, Module, Kit-Wege, kein Netz, Privatsphäre, Abhängigkeiten, nie auf dem Bildschirm, Tests, erzeugte Dateien, Signatur | `make rules` (Teil A) |
| `gruppen/arbeitsweise.json` | A-01 bis A-10: Vorgaben, Prüfen, Commits, Identität, eigene Dateien, Kit-Pfade, Gegenprüfung, Beweise, Fragen, sauberes Repository | `make rules` (Teil A) |
| `pakete/*.json` | Begriffe mit Muster, Ersatzhinweis, Bereichen, Sprachen und Beispielen | `check_texts.py`, `check_design.py`, Hook `commit-msg`, KI-Texte |
| `code.json` | wo ein String-Literal in Swift ein UI-Text ist (Aufrufe, Modifikatoren, Labels, Zuweisungen) | `check_texts.py` |
| `schema/*.schema.json` | JSON-Schema für Gruppen und Pakete | Editor, `make rules` |
| `projekt/projekt.json`, `projekt/pakete/*.json` | Regeln `P-NN` und Sprachpakete des Projekts; der Ordner gehört dem Projekt | `make rules` (Abschnitt „Projektregeln“ in Teil B), alle Prüfungen |
| `baseline/texte.json`, `baseline/design.json` | bekannte Befunde, die beim Einführen einer Regel schon da waren; dürfen nur schrumpfen | `check_texts.py`, `check_design.py` |
| `generated/begriffe.json`, `generated/ki-schreibregeln.json` | erzeugt, nie von Hand ändern | alle Prüfungen, KI-Prompts |

## Regeln

Jede Regel hat eine feste Kennung (`S-01`), einen Schlüssel, einen verbindlichen Wortlaut in einem Absatz, die Pakete, die sie prüfen, die Durchsetzung und die Angabe, ob sie in die Schreibregeln für KI-Texte gehört (`ki`). Kennungen werden nie neu vergeben: eine Regel, die nicht mehr gilt, bekommt das Feld `aufgehoben` mit Grund und verschwindet damit aus Teil A. Beispiele verbotener Wörter und Zeichen stehen im Wortlaut nur in Code-Formatierung, damit `CLAUDE.md` die Sprachprüfung besteht.

## Sprachpakete

Ein Paket bündelt Begriffe. Das Paket nennt seine Prüfung (`pruefer`: `check_texts` als Standard oder `check_design`), die Sprachen der Texte, für die es gilt (`sprachen`: `de`, `en`), ob es standardmäßig aktiv ist und ob ein Projekt es ausgeschaltet lassen darf. Jeder Begriff hat:

- `art`: `regex` (Alternativen mit `|` verbunden), `woerter` (zusätzlich als ganze Wörter eingerahmt) oder `verfahren` (Prüfverfahren, beschrieben in `umsetzung`, heute `markdown-absatz`)
- `muster` im Format von Python `re` und `flags` (`i`, `m`, `s`, `x`); ein Apostroph steht immer als `['’]`, sonst rutscht die typografische Form durch, `make rules` prüft das
- `bereiche`: `ui` (beide Literale jedes `tr(en:de:)` und `App/Resources/InfoPlist.json`), `kommentar` (Swift und Python, englisch), `doku` (Markdown, deutsch), `commit` (Commit-Nachrichten, englisch), `ki` (KI-Texte der App), `swift` (Swift-Code ohne Kommentare und Literale)
- `beiAnrede` (optional): der Begriff gilt nur, wenn `starter.json` `texts.anrede` diesen Wert hat; so verbietet das Paket `anrede` mit `du` die Sie-Form und umgekehrt
- `ausgenommenePfade` (optional, auch am Paket): Globs, für die der Begriff nicht gilt, etwa `App/Sources/Kit/Design/**` für die Gestaltung
- `hinweis`: der Ersatz, den die Meldung nennt
- `beispiele`: Texte, die gemeldet werden müssen, und Texte, die erlaubt bleiben; `make rules` führt jedes Beispiel als Test aus

`erlaubt` im Paket nennt Phrasen, in denen ein Treffer erlaubt ist, jeweils mit Grund und bei Bedarf auf Pfade begrenzt. Ein Zeichen, das zwei Begriffe treffen, wird einmal gemeldet.

Die Tastenkürzel-Zeichen `⌘ ⌥ ⌃ ⇧ ⇥ ⇪ ⏎ ⌫` sind in keinem Muster; eine Pfeiltaste direkt nach einer Modifikatortaste (`⌘←`) und ein Tastenpaar (`↑/↓`) bleiben erlaubt.

## Einstellungen in starter.json

| Schlüssel | Wirkung |
|---|---|
| `texts.anrede` | `du` (Standard) oder `sie`: wählt den Begriff im Paket `anrede` |
| `texts.zusatzpakete` | Pakete, die standardmäßig aus sind und eingeschaltet werden, etwa `["zeitwoerter"]` |
| `texts.personen` | Namen, die in Code-Kommentaren nicht stehen sollen; sie ergänzen das Paket `kommentare` |

Nach jeder Änderung `make rules` ausführen, sonst meldet `make check` eine Abweichung.

## Befehle

```bash
make rules            # prüfen und CLAUDE.md Teil A, generated/begriffe.json, generated/ki-schreibregeln.json schreiben
make check-rules      # nur prüfen, Fehler bei Abweichung (Teil von make check)
make check-texts      # Sprachprüfung: UI-Texte, InfoPlist, Kommentare, Doku
make check-design     # Swift-Code: Tokens statt freier Werte, Technik-Regeln
scripts/check_texts.py App/Sources/Modules/Island   # nur einen Ordner prüfen
scripts/check_texts.py --streng                      # Baseline nicht anwenden
scripts/check_texts.py --baseline-aktualisieren      # nach einer Korrektur: Baseline verkleinern
```

`make rules` prüft den Aufbau jeder Datei gegen `schema/`, kompiliert jedes Muster und testet jedes Beispiel. `scripts/tests/` prüft, dass die Prüfungen jedes Beispiel genauso erkennen.

## Ausnahmen im Code

| Kommentar | Wirkung |
|---|---|
| `// text-ausnahme: Grund` | nimmt einen Aufruf (`tr`, `Text`, …) von den Sprachregeln aus, in derselben Zeile oder bis zu drei Zeilen darüber |
| `// verbatim: Grund` | erlaubt `Text(verbatim: "…")` mit Literal |
| `// design-ausnahme: Grund` | nimmt eine Zeile von `gestaltung` aus, in derselben Zeile oder direkt darüber |
| `// technik-ausnahme: Grund` | nimmt eine Zeile von `swift-technik` aus |

Eine Ausnahme ohne Grund oder ohne Befund ist selbst ein Befund.

## Baseline

Die Baselines enthalten Fingerabdrücke (Begriff, Treffer, Umgebung), keine Zählungen: ein neuer Befund desselben Begriffs in derselben Datei schlägt trotzdem fehl. Sie dürfen nur schrumpfen; `--baseline-aktualisieren` weigert sich, Einträge hinzuzufügen, und ein behobener Befund, der noch in der Baseline steht, macht die Prüfung rot, bis sie verkleinert ist. Ein Projekt hält beide Baselines leer.

## Neue Vorgabe einarbeiten

Dieser Ablauf gilt beim Bau des Starters. In einem Projekt landen neue Vorgaben in `projekt/` (siehe `projekt/README.md`).

1. Die Vorgabe in `docs/agents/VORGABEN.md` lesen und die betroffenen Regeln bestimmen.
2. Wortlaut in `gruppen/*.json` ändern oder eine Regel mit der nächsten freien Kennung anlegen; im Feld `vorgabe` die Kennung der Vorgabe eintragen.
3. Lässt sich die Regel an Wörtern, Zeichen oder Code erkennen, einen Begriff in einem Paket ergänzen, mit Beispielen für Treffer und erlaubte Texte.
4. `make rules` ausführen, danach `make check`.
5. In `docs/agents/VORGABEN.md` die Vorgabe als eingearbeitet markieren, mit Regelkennung und Commit.
6. Innerhalb eines Arbeitstags erledigen, damit keine angehängte Liste entsteht, die sich mit der Zeit widerspricht.
