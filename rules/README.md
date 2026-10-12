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
| `code.json` | wo ein String-Literal in Swift ein UI-Text ist (Aufrufe, Modifikatoren, Labels, Zuweisungen, Formate, Titel-Closures wie `title: { "…" }`) | `check_texts.py` |
| `schema/*.schema.json` | JSON-Schema für Gruppen und Pakete | Editor, `make rules` |
| `projekt/projekt.json`, `projekt/pakete/*.json` | Regeln `P-NN` und Sprachpakete des Projekts; der Ordner gehört dem Projekt | `make rules` (Abschnitt „Projektregeln“ in Teil B), alle Prüfungen |
| `baseline/texte.json`, `baseline/design.json` | bekannte Befunde, die beim Einführen einer Regel schon da waren; dürfen nur schrumpfen | `check_texts.py`, `check_design.py` |
| `generated/begriffe.json`, `generated/ki-schreibregeln.json` | erzeugt, nie von Hand ändern | alle Prüfungen, KI-Prompts |

## Regeln

Jede Regel hat eine feste Kennung (`S-01`), einen Schlüssel, einen verbindlichen Wortlaut in einem Absatz, die Pakete, die sie prüfen, die Durchsetzung und die Angabe, ob sie in die Schreibregeln für KI-Texte gehört (`ki`). Kennungen werden nie neu vergeben: eine Regel, die nicht mehr gilt, bekommt das Feld `aufgehoben` mit Grund und verschwindet damit aus Teil A. Beispiele verbotener Wörter und Zeichen stehen im Wortlaut nur in Code-Formatierung, damit `CLAUDE.md` die Sprachprüfung besteht.

## Sprachpakete

Ein Paket bündelt Begriffe. Das Paket nennt seine Prüfung (`pruefer`: `check_texts` als Standard oder `check_design`), die Sprachen der Texte, für die es gilt (`sprachen`: `de`, `en`), ob es standardmäßig aktiv ist und ob ein Projekt es ausgeschaltet lassen darf. Jeder Begriff hat:

- `art`: `regex` (Alternativen mit `|` verbunden), `woerter` (zusätzlich als ganze Wörter eingerahmt) oder `verfahren` (Prüfverfahren, beschrieben in `umsetzung`, heute `markdown-absatz`)
- `muster` im Format von Python `re` und `flags` (`i`, `m`, `s`, `x`); ein Apostroph steht immer als `['’]`, auch geschrieben als `\'` oder `\x27`, sonst rutscht die typografische Form durch, `make rules` prüft das
- `bereiche`: `ui` (beide Literale jedes `tr(en:de:)` und `App/Resources/InfoPlist.json`), `kommentar` (Swift und Python, englisch, Code in Backticks ausgeblendet), `doku` (jede Markdown-Datei außer den Ausnahmen in `index.json`, deutsch), `commit` (Commit-Nachrichten, englisch), `ki` (KI-Texte der App), `swift` (Swift-Code ohne Kommentare und Literale in `App/Sources`, `App/Tests` und `tools`)
- `regeln`: die Regeln, die der Begriff prüft; die Meldung nennt genau diese
- `beiAnrede` (optional): der Begriff gilt nur, wenn `starter.json` `texts.anrede` diesen Wert hat; so verbietet das Paket `anrede` mit `du` die Sie-Form und umgekehrt
- `ausgenommenePfade` (optional, auch am Paket): Globs, für die der Begriff nicht gilt, etwa `App/Sources/Kit/Design/**` für die Gestaltung
- `hinweis`: der Ersatz, den die Meldung nennt
- `beispiele`: Texte, die gemeldet werden müssen, und Texte, die erlaubt bleiben; `make rules` führt jedes Beispiel als Test aus

`erlaubt` im Paket nennt Phrasen, in denen ein Treffer erlaubt ist, jeweils mit Grund und bei Bedarf auf Pfade begrenzt. Ein Zeichen, das zwei Begriffe treffen, wird einmal gemeldet.

Die Zeichen der Mac-Tasten `⌘ ⌥ ⌃ ⇧ ⇥ ⇤ ⇪ ⏎ ↩ ⌤ ⌫ ⌦ ⎋ ⇞ ⇟ ↖ ↘` sind in keinem Muster. Pfeiltasten (`← ↑ → ↓`) bleiben erlaubt direkt nach einer Modifikatortaste (`⌘←`), neben einer anderen Taste (`↑↓`), als Paar mit `/`, `,`, `oder`, `und`, `bis`, `or`, `and` (`↑ / ↓`, `← oder →`), mit `Taste` oder `key` dahinter (`↓-Taste`) und als ganzer Text einer Tastenkappe. `🌐` gilt als Globus-Taste, wenn eine Taste (`🌐E`), `Taste`, `key` oder die Textdarstellung U+FE0E folgt; sonst ist es ein Emoji.

## Einstellungen in starter.json

| Schlüssel | Wirkung |
|---|---|
| `texts.anrede` | `du` (Standard) oder `sie`: wählt den Begriff im Paket `anrede`. Die Texte des Kits sind in der du-Form; mit `sie` meldet `make check-texts` jede du-Form in den `*Text.swift`-Dateien und in `App/Resources/InfoPlist.json` (mit den Standardmodulen des Starters rund 130 Stellen, `bin/starter init --anrede sie` sagt es im Bericht). Diese Dateien sind gemeinsame Pfade, die das Projekt umschreibt; die Baseline nimmt sie nicht auf. |
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
scripts/check_texts.py --ci                          # in CI: ein behobener Befund in der Baseline ist ein Fehler
```

`make rules` prüft den Aufbau jeder Datei gegen `schema/`, kompiliert jedes Muster und testet jedes Beispiel. `scripts/tests/` prüft, dass die Prüfungen jedes Beispiel genauso erkennen.

## Ausnahmen im Code

| Kommentar | Wirkung |
|---|---|
| `// text-ausnahme: Grund` | nimmt einen Aufruf (`tr`, `Text`, …) oder einen Kommentar von den Sprachregeln aus, in derselben Zeile oder bis zu drei Zeilen darüber; ein Kommentar gilt für genau eine Stelle. In Python `# text-ausnahme: Grund` |
| `// umbruch: Grund` | erlaubt den bewussten Umbruch `\n` in einem `tr` darüber (ausgewogene zweizeilige Unterzeile, D-10); alle anderen Sprachregeln gelten weiter |
| `// verbatim: Grund` | erlaubt `Text(verbatim: "…")` mit Literal |
| `// design-ausnahme: Grund` | nimmt eine Zeile von `gestaltung` aus, in derselben Zeile oder direkt darüber |
| `// technik-ausnahme: Grund` | nimmt eine Zeile von `swift-technik` aus, in derselben Zeile oder direkt darüber |

Eine Ausnahme ohne Grund oder ohne Befund ist selbst ein Befund.

## Baseline

Die Baselines enthalten je Datei einen Fingerabdruck (Begriff und Treffer, ohne Zeile und Umgebung) pro Befund: ein Text, der um einen bekannten Befund herum geändert wird, bleibt bekannt, ein zweiter gleicher Befund in derselben Datei ist neu. Sie dürfen nur schrumpfen; `--baseline-aktualisieren` weigert sich, Einträge hinzuzufügen. Ein behobener Befund, der noch in der Baseline steht, ist lokal ein Hinweis und mit `--ci` ein Fehler. Wer einen Befund behebt, verkleinert die Baseline im selben Branch und nennt das in der Statusdatei (A-05); was liegen bleibt, verkleinert die Integration nach dem Zusammenführen. Ein Projekt hält beide Baselines leer.

## Neue Vorgabe einarbeiten

Dieser Ablauf gilt beim Bau des Starters. In einem Projekt landen neue Vorgaben in `projekt/` (siehe `projekt/README.md`).

1. Die Vorgabe in `docs/agents/VORGABEN.md` lesen und die betroffenen Regeln bestimmen.
2. Wortlaut in `gruppen/*.json` ändern oder eine Regel mit der nächsten freien Kennung anlegen; im Feld `vorgabe` die Kennung der Vorgabe eintragen.
3. Lässt sich die Regel an Wörtern, Zeichen oder Code erkennen, einen Begriff in einem Paket ergänzen, mit Beispielen für Treffer und erlaubte Texte.
4. `make rules` ausführen, danach `make check`.
5. In `docs/agents/VORGABEN.md` die Vorgabe als eingearbeitet markieren, mit Regelkennung und Commit.
6. Innerhalb eines Arbeitstags erledigen, damit keine angehängte Liste entsteht, die sich mit der Zeit widerspricht.
