# Status K (Starter-Werkzeuge)

Stand: 2026-10-12 (nach dem Review), Branch `strang/K` (von `main` 68281d5). Gebaut: Manifest, Lock-Datei, `bin/starter` mit `init`, `remove`, `strip-examples`, `sync`, `check-kit`, `modules`, `doctor`, die Bibliothek `scripts/starter/`, `scripts/check_kit.py`, Tests und die Vorlagen-Probe `make probe`. Vorlage war app-starter (`scripts/starter-*.ts`, `check-kit.ts`, `lib/project-state.ts`, `starter.manifest.json`), übertragen auf Swift, Python 3.9 ohne Fremdpakete und deutsche Ausgaben.

## Dateien

| Datei | Inhalt |
|---|---|
| `starter.manifest.json` | Pfadklassen `kit`, `shared`, `project`, `starterOnly` mit `order` (erste Liste gewinnt), Modul-Einträge (Ordner, Pfade, `needs`, `permissions`, `nextSteps`), Regel `atLeastOne` (window/menubar), Markierungs-Konvention, Soll-Liste `checks` für check-kit Teil 2 |
| `starter.lock.json` | Stand des Repositorys: `version`, `state`, `source`, `commit`, `project` (null = der Starter selbst), `createdOn`, `lastSyncedOn`, `removedModules`, `checksums` |
| `bin/starter` | Einstieg (`#!/usr/bin/env python3`), ruft `scripts/starter/cli.py` |
| `scripts/check_kit.py` | Schritt von `make check`, gleich `bin/starter check-kit` |
| `scripts/starter/common.py` | Fehler, Git, Dateiliste (`git ls-files --cached --others --exclude-standard`), sichere Pfade, Prüfsummen (LF-normalisiert), `cut_blocks`, `build_env` |
| `scripts/starter/globs.py` | Glob-Abgleich wie app-starter (`**`, `*`, `?`, `./` verankert, Muster ohne `/` trifft den Dateinamen) |
| `scripts/starter/manifest.py` | Schema-Prüfung von Hand, `classify`, Module, Lock lesen/schreiben |
| `scripts/starter/config.py` | `starter.json` im kompakten Layout (schreibt S0s Datei byteweise gleich zurück), Prüfung über `scripts/gen_config.py`, Schlüssel-Merge für sync |
| `scripts/starter/markers.py` | `#if MODUL_<NAME>`-Blöcke entfernen, Kommentar-Markierungen, leer gewordene Swift-Dateien, Suche nach übrig gebliebenen Swift-Typen |
| `scripts/starter/project.py` | `init` |
| `scripts/starter/remove.py` | `remove`, `strip-examples`, Entfern-Simulation |
| `scripts/starter/sync.py` | `sync` |
| `scripts/starter/kitcheck.py` | `check-kit` |
| `scripts/starter/cli.py` | Argumente, deutsche Hilfe und Fehlermeldungen, `modules`, `doctor` |
| `scripts/starter/tests/test_*.py` | 115 Tests (Marker, Manifest, Globs, Config, init, remove, sync, check-kit, Zustand, CLI als Prozess) |
| `scripts/starter/tests/probe_starter.py` | Vorlagen-Probe (`make probe`, nicht Teil von `make test`), auch: ein erstes Feature hält check-kit grün |

## Befehle

```
bin/starter init [--name N --bundle-id ID --accent A --symbol S --module-aus m,… --non-interactive --probelauf --ohne-build --ohne-netz]
bin/starter remove <modul> [--probelauf] [--ohne-build]
bin/starter strip-examples [--probelauf] [--ohne-build]
bin/starter sync --ziel <tag> [--quelle <url|pfad>] [--basis <tag|commit>] [--probelauf]     # Exit 2 = Konflikte offen
bin/starter check-kit | modules | doctor
make probe
```

- **init**: lehnt ab, wenn `origin` auf `wielochyeah/mac-app-starter` zeigt, und tut nichts, wenn die Lock-Datei schon ein Projekt nennt (außer ein früherer Lauf hinterließ `pendingBuild`, dann baut es noch einmal). Prüft Name, Bundle-ID, Akzent und Symbol selbst mit deutschen Meldungen. Fragt ohne `--non-interactive` Name, Bundle-ID, Akzent, Symbol und je Modul „behalten?“ (Standard: wie in `starter.json`, also `n` für mlx), prüft jede Antwort sofort samt Modulregeln (ein Modul, dessen Abhängigkeit geht, geht ohne Frage mit; die letzte App-Form lässt sich nicht abwählen), zeigt eine Zusammenfassung und fragt „Fortfahren?“. Schreibt in `starter.json` Name, Bundle-ID, `displayName` en/de, Akzent, Symbol, Version 0.1.0, Build 1, `© <Jahr>`, leert `commit` und setzt `signing` auf ad hoc. Löscht `starterOnly.paths` (`docs/bau/**`), schneidet `<!-- nur-im-starter:anfang/ende -->` in allen Textdateien heraus, legt `docs/DECISIONS.md` als `docs/STARTER_DECISIONS.md` ab und ersetzt `docs/DECISIONS.md`, `docs/agents/{PLAN.md,straenge.json,VORGABEN.md}` durch `docs/vorlagen/*` (fehlt eine Vorlage, bleibt die Datei und der Bericht sagt es). Lock mit Starter-Commit (lokaler Tag `v<version>`, sonst `git ls-remote` mit 15 s, `--ohne-netz` schaltet das ab). Entfernt die gewählten Module in Abhängigkeitsreihenfolge (mlx vor ai), dann `make icon` (wenn `scripts/icon.sh` da ist) und `make build`. Alle Modul-Entfernungen werden vor dem ersten Schreiben simuliert. Alle Texte werden geschnitten, bevor etwas verschoben wird: `docs/STARTER_DECISIONS.md` bekommt den geschnittenen Text, eine ersetzte Datei ihre Vorlage. Ist `make build` rot, kommt der ganze Bericht samt nächsten Schritten, dann der Fehler (Exit 1), und die Lock-Datei vermerkt `pendingBuild`.
- **remove**: prüft bekanntes Modul, noch vorhanden (sonst „schon entfernt, nichts zu tun“), kein vorhandenes Modul braucht es (`remove ai` bei vorhandenem mlx: „Zuerst bin/starter remove mlx“, auch wenn mlx in `starter.json` aus ist), window/menubar-Regel (zählt nur eingeschaltete). Dann Plan: Dateien der Modulpfade, `#if MODUL_<NAME>`-Blöcke in allen Swift-Dateien (auch Tests), Kommentar-Markierungen in allen Textdateien, Swift-Dateien ohne Code danach. Findet die Simulation einen Typ des Moduls außerhalb eines `#if` (Datei:Zeile), schreibt es nichts (Exit 1). Sonst: löschen, schreiben, Baseline-Einträge gelöschter Dateien aus `rules/baseline/*.json` streichen, Schlüssel aus `starter.json` streichen (nicht auf false setzen), `removedModules` und (im Projekt) nur die Prüfsummen der Kit-Dateien nachführen, die remove selbst geändert hat und die bis dahin unverändert waren, `make build`. Ist der Build rot: ganzer Bericht, Wiederherstellung mit `git restore --source=HEAD --staged --worktree -- <dateien>`, Exit 1, `pendingBuild` in der Lock-Datei; ein zweiter Aufruf baut dann noch einmal statt „schon entfernt“ zu melden. Hatte der Baum schon nicht committete Änderungen, sagt der Bericht es. `--probelauf` läuft auch im Starter selbst.
- **sync**: Port von app-starter (private Refs `refs/starter/basis|ziel`, `transfer.fsckObjects`, Basis aus `lock.commit` oder Tag `v<version>`, `--basis` als Ausweg, unsichere Pfade im Baum brechen ab, Passwörter und Tokens in der Adresse sowie Werte mit führendem `-` abgelehnt, SSH (`git@github.com:…`, `ssh://git@…`) erlaubt und Standard, wenn `origin` des Projekts SSH nutzt; Git fragt nie nach einem Passwort; ein fehlender Tag nennt `git ls-remote --tags`). Kit nimmt das Ziel, gemeinsame Dateien `git merge-file -L Projekt -L Basis -L Starter`, Projekt- und Starter-only-Pfade bleiben, Binärdateien und CRLF wie im Original. Beide Starter-Stände werden vorher so umgeformt wie das Projekt (entfernte Module: Pfade übersprungen, `#if`-Blöcke und Markierungen weg, leere Swift-Dateien weg; nur-im-Starter-Abschnitte geschnitten). `starter.json` wird nach Schlüsseln zusammengeführt, nie als Text. Ausführbares (Hooks, CI, `scripts/**`, `bin/**`, `tools/**`, Makefile, Package.swift, `*.sh`) steht laut im Bericht. Die Lock-Datei bekommt neue Prüfsummen nur für Kit-Dateien, die jetzt den Zielstand tragen; eine vorher geänderte oder neu angelegte Kit-Datei, die sync nicht anfasst, meldet check-kit weiter. Kein Commit.
- **check-kit** und **doctor** bestimmen den Zustand wie app-starter: `project` (Lock nennt ein Projekt), `starter` (`origin` oder in CI `GITHUB_REPOSITORY` ist der Starter), `needs-init` (anderes Repository, init fehlt: check-kit und doctor scheitern mit „zuerst bin/starter init“), `unknown` (kein origin: geprüft wie der Starter, mit Hinweis).
- **check-kit**: Projekt: Kit-Prüfsummen gegen Lock (geändert, gelöscht, neu angelegt; Meldung nennt `App/Sources/Features/`, `App/Tests/Features/`, `scripts/projekt/` und den Skill `starter-rueckfluss`), keine Starter-Reste. Starter: Lock leer und Version gleich `starter.json`, jede Datei von einer Liste getroffen, Module = `MODULE_DIRS`/`MODULE_DEPENDS` aus `gen_config.py` und = `starter.json`, Modulpfade disjunkt und nie Projektdateien, jedes `#if` mit Modul-Flag ist eines, das remove auflösen kann, jedes Modul lässt sich ohne übrige Swift-Typen und ohne Anleitungen (`*.md`), die noch seine Pfade oder Skills nennen, entfernen (app-starter E-70). Überall: Makefile-Ziele `check` (mit check-rules, check-texts, check-design, check-kit, build, test) und die Skripte darin, Hooks `commit-msg` → `scripts/check_commit_msg.py` (auch als `"$ROOT/scripts/…"` in Anführungszeichen; Kommentar- und echo/print-Zeilen zählen nicht), `pre-push` → `make check`, CI führt `make check` aus; gemeldet werden `|| true`, `; true`, `--no-verify`, Make-Zeilen mit führendem `-`, `continue-on-error: true`, `if: false`. Fehlende Prüfskripte sind im Projekt ein Fehler (die Makefile-Ziele überspringen sie sonst still), im Starter ein Hinweis.

## Entscheidungen

- **Englische Schlüssel im Manifest und in der Lock-Datei** (`kit`, `shared`, `project`, `starterOnly`, `modules`, `checksums`), passend zu `starter.json`; Beschreibungen und alle Ausgaben deutsch.
- **remove lässt das Manifest unverändert.** Das Manifest ist eine Kit-Datei; bleibt sie byteweise gleich, kann sync sie einfach übernehmen. Die Entfernung steht in `starter.lock.json` (`removedModules`) und darin, dass `starter.json` den Schlüssel nicht mehr hat (ein Modul auf `false` ist nur ausgeschaltet). Abweichung vom Wortlaut „updates manifest“ in STRANDS.md.
- **Modul-Tests**: Testdateien eines Moduls stehen ganz in `#if MODUL_<NAME>` (nötig, damit `make test MODULES=…` baut) oder unter `App/Tests/Modules/<Ordner>/`. remove löscht jede Swift-Datei, in der nach dem Entfernen nur Kommentare, Importe und Direktiven bleiben. Keine Namensmuster wie `App/Tests/Window*.swift`: sie hätten Kit-Tests wie `WindowHostTests.swift` mitgenommen.
- **Eigene Tests eines Projekts** gehören nach `App/Tests/Features/` (Projektpfad); jede andere neue Datei unter `App/Tests/` ist eine neue Kit-Datei und lässt check-kit scheitern.
- **Gemeinsam statt Kit**: alle `*Text.swift` in `Kit/` und `Modules/` (Projekte dürfen Texte anpassen, sync führt zusammen), `starter.json` (Schlüssel-Merge), Makefile, Package.swift, `.github/**`, `.claude/{settings.json,README.md,skills,agents,workflows}`, `rules/generated/**`, `rules/baseline/**` (ein Projekt verkleinert die Baseline, wenn es gemeinsame Texte ändert), `tools/icon/Icon.swift` und `tools/dmg/Background.swift` (eigenes Motiv laut `docs/VERTEILUNG.md`), `App/Resources/InfoPlist.json`, `ai-worker/models.json`, `ai-worker/requirements*.txt`, README, CLAUDE.md, AGENTS.md, CONTRIBUTING.md, CHANGELOG.md, `docs/UEBERGABE.md`. Projekt: `App/Sources/Features/**`, `App/Tests/Features/**`, `App/Resources/**` (Icon), `scripts/projekt/**`, `rules/projekt/**`, `docs/{PROJECT,DECISIONS,STARTER_FEEDBACK}.md`, `docs/agents/**`, `docs/screenshots/**`, Lock.
- **Schutz vor übrig gebliebenen Typen** ohne Compiler: Namen, die gelöschte Swift-Dateien auf Spalte 0 deklarieren (Typen, Funktionen, globale `let/var`, nicht private), werden in den übrigen Swift-Dateien außerhalb von Kommentaren und Strings gesucht. Kein Treffer sind: Zugriff auf ein Mitglied (`Metrics.Island`), eine eigene Deklaration (`enum Island {` in einer Extension), ein Name, den eine übrige Datei auf Spalte 0 deklariert (Ersatz im `#else`), und in einer Datei ein Name, den dieselbe Datei als verschachtelten Typ deklariert (ihr eigener Gültigkeitsbereich). Danach baut remove mit `make build`, das ist die eigentliche Probe. Mitglieder in Extensions (`.islandStyle`) findet nur der Build.
- **`#if`-Regeln**: `#if MODUL_X` entfernt den Block und behält `#else`; `#if !MODUL_X` behält den Block; verschachtelte Modul-Blöcke gehen; `MODUL_X` zusammen mit `&&`/`||` oder `#elseif` an einem Modul-Block lehnt remove mit Datei:Zeile ab (check-kit meldet es schon im Starter).
- **SDKROOT**: `/usr/bin/python3` ist ein xcrun-Shim und exportiert `SDKROOT=<xcrun-Standard-SDK>` (hier die 27.0-Beta) in den Prozess. `make build` aus `bin/starter` übernahm das, `pick-sdk.sh` hielt es für eine Nutzerwahl, der Build scheiterte. `build_env()` lässt ein SDKROOT weg, das gleich dem xcrun-Standard ist (pick-sdk probiert diesen ohnehin zuerst), und auch `MODULES`/`CONFIG`/`ONLY` eines äußeren make. **Gilt für jedes Python-Werkzeug, das baut** (Strang G Hooks, Strang H, Strang J, falls in Python).
- **Ohne Git keine Dateiliste**: alle Befehle brechen außerhalb eines Git-Repositorys mit Anleitung ab, statt still „keine Dateien“ zu prüfen.
- **init setzt die App-Version auf 0.1.0** und das Copyright auf das laufende Jahr; die Version des Starters steht nur noch unter `starter.version` und im Lock.
- **Probe**: jede Kopie baut ohne `build/`: clangs Modul-Cache speichert seinen Pfad und lässt sich nicht in einen anderen Ordner kopieren. Zwei Kopien bauen gleichzeitig (`STARTER_PROBE_JOBS`), ein Lauf dauert rund 4 Minuten.

## Vorgaben für andere Stränge und die Integration

- **Swift**: Code eines Moduls außerhalb seines Ordners nur in `#if MODUL_<NAME>` … `#endif` (ein Flag je `#if`, kein `#elseif` daran). Modul-Tests ganz in `#if MODUL_<NAME>` oder unter `App/Tests/Modules/<Ordner>/`.
- **Anleitungen** (`*.md`, auch `.claude/skills`, `.claude/agents`, README, CLAUDE.md, `docs/*`): Zeilen, die Pfade eines Moduls (`App/Sources/Modules/<Ordner>/`, `ai-worker/`, `docs/KI.md`, `App/Tests/Modules/<Ordner>/`) oder seinen Skill in Backticks nennen, tragen `<!-- modul:<name> -->` am Ende oder stehen zwischen `<!-- modul:<name>:anfang -->` und `<!-- modul:<name>:ende -->`. check-kit meldet jede fehlende Markierung als „remove <name>: datei:zeile nennt …“. Ausgenommen: CHANGELOG, THIRD_PARTY_NOTICES, DECISIONS, STARTER_DECISIONS, `docs/bau/**`.
- **Shell, Python, YAML, Makefile, requirements, `docs/screenshots/list.txt`, Skripte ohne Endung mit `#!`-Zeile (Git-Hooks, `bin/starter`)**: `# modul:<name>` am Zeilenende bzw. `# modul:<name>:anfang/ende`.
- **Skill-Namen** im Manifest: window `neue-ansicht`, menubar `menueleisten-app`, island `insel-zustand`, background `hintergrund-job`, hotkeys `kurzbefehl`, ai `ki-funktion` (Ordner `.claude/skills/<name>/`); sie gehen mit dem Modul.
- **G1**: `scripts/hooks/commit-msg` muss `scripts/check_commit_msg.py` aufrufen, `scripts/hooks/pre-push` `make check`; leere `commit.name/email` in `starter.json` müssen jeden Commit ablehnen (die Probe prüft das, sobald der Hook da ist).
- **G2**: `.github/workflows/ci.yml` muss `make check` in einem `run:` haben; Vorlagen `docs/vorlagen/{DECISIONS.md,PLAN.md,straenge.json,VORGABEN.md}`; README-Abschnitt „Stand“ zwischen `<!-- nur-im-starter:anfang -->`/`ende` (jede Textdatei außer JSON darf solche Abschnitte haben, in ihrer Kommentarsyntax: `# nur-im-starter:anfang` in YAML, Shell, Python, Makefile, `// nur-im-starter:anfang` in Swift; init schneidet sie überall). Template-Probe-Job: `make probe` oder dieselben Schritte; in einem Projekt überspringt sich `make probe`.
- **Neue Wurzeldateien** (z. B. `LICENSE`) brauchen einen Eintrag im Manifest, sonst meldet check-kit im Starter „Dateien ohne Klasse“.
- **Vorschlag an S0** (nicht umgesetzt): `gen_config.py` könnte Module ablehnen, deren Ordner fehlt (heute baut `MODULES=island` nach `remove island` still ohne Insel und meldet sie trotzdem in `AppConfig.enabledModules`).

## Aus VoiceBud übernommen

Nichts. Übernommen ist Mechanik aus app-starter (eigenes Repository des Nutzers): Manifest-Klassen und Reihenfolge, Glob-Semantik, `isSafeRepoPath`, `cutBlocks`, Marker-Syntax je Dateityp, Lock-Felder, init-Ablauf (verschieben vor ersetzen, Identität leeren), remove-Ablauf, sync-Algorithmus mit Entscheidungstabelle, `EXECUTABLE`-Liste, Exit 2 bei Konflikten, check-kit Teil 2 mit den Abschwächungs-Mustern, `containsCommand`, `runValues`.

## Außerhalb meines Strangs angefasst

- `Makefile` (S0): Ziel `probe` und Zeile in `help`, `probe` in `.PHONY`. Rein ergänzend.
- `scripts/test.sh` (S0): führt nach `scripts/tests` auch `scripts/starter/tests` aus (`-t scripts`), volle Ausgabe nur bei Fehlern. Rein ergänzend.
- `starter.lock.json` neu an der Wurzel (keinem Strang zugeordnet, gehört zur Manifest-Mechanik).

## Bekannte Lücken

- Der Schutz vor übrig gebliebenen Typen ist textbasiert: Mitglieder in Extensions, Operatoren, Typen, die eingerückt auf oberster Ebene stehen, und Nutzungen in einer Datei, die einen gleichnamigen verschachtelten Typ deklariert, findet erst `make build`. Der ist dann rot, nachdem remove geschrieben hat; der Bericht nennt den Befehl `git restore --source=HEAD --staged --worktree -- <dateien>` und die Lock-Datei `pendingBuild`. Eine unqualifizierte Nutzung eines verschachtelten Typs in einer anderen Datei als seiner Deklaration (`Island` in einer zweiten `extension Radius`) meldet der Schutz fälschlich. Die Probe und check-kit im Starter fangen die Fälle im Starter-Code vorher ab.
- `#if` in mehrzeiligen String-Literalen (`"""`) würde als Direktive gelesen.
- sync gegen GitHub ist nicht ausprobiert (es gibt noch keinen Tag `v1.0.0`; geprüft mit lokalen Repositorys als `--quelle`, auch mit Basis aus `lock.commit` per SHA-Fetch). Ohne veröffentlichten Tag schreibt init `commit: null`, und sync braucht den Tag `v<version>` oder `--basis`.
- `check-kit` prüft im Starter die Anleitungen anderer Stränge; bei der Integration wird es dort Funde geben, bis die Modul-Markierungen gesetzt sind (gewollt, siehe oben).
- Die Probe-Assertion „Commit scheitert ohne Identität“ wird übersprungen, solange `scripts/hooks/commit-msg` fehlt (Strang G1).
- `make icon` in init ist ungetestet, weil `scripts/icon.sh` (Strang J) auf diesem Branch fehlt; init überspringt es dann.
- Interaktives init nur über ein Pseudo-Terminal ausprobiert (Antworten per Skript), nicht von Hand.

## Prüfung (Befehle und Ergebnisse, 2026-10-12)

```
python3 -m unittest discover -s scripts/starter/tests -t scripts -p 'test_*.py'
                                  -> Ran 91 tests … OK (System-Python 3.9.6)
make test                         -> "67 tests, 0 failures" (Swift) + "Ran 11 tests … OK" + "Ran 91 tests … OK"
make check                        -> grün; check-kit: "alle Dateien klassifiziert (Kit 97, gemeinsam 13, Projekt 2,
                                     nur im Starter 3)", "8 von 8 Modulen lassen sich ohne Reste entfernen",
                                     Hinweis auf noch fehlende Dateien von G1/G2
make build / MODULES=menubar / MODULES=window -> grün
STARTER_PROBE_JOBS=2 make probe   -> letzter Lauf auf dem Stand mit allen Commits: "OK (skipped=1)", 171 s:
   init grün (36 s, mit make build, Name mit Leerzeichen „Probe App“)
   remove window 0 (35 s), danach remove menubar 1 („Mindestens eines der Module window, menubar muss bleiben“)
   remove menubar 0, island 0, background 0, hotkeys 0, mlx 0, examples 0 (je make build grün, check-kit Teil 1 grün)
   remove ai 1 („Modul ai wird noch von mlx gebraucht“), danach remove mlx 0 und remove ai 0
   übersprungen: Commit ohne Identität (Hook fehlt noch)
   Ein Lauf davor unter Volllast (Last 15, andere Stränge bauten) endete für island und background mit
   „compile command failed due to signal 15“ nach 860 s: von außen beendete Compiler, kein Fehler der Werkzeuge;
   der Lauf danach war grün.
bin/starter remove island         -> im Starter-Repository abgelehnt („ist der Starter selbst“), --probelauf zeigt den Plan
bin/starter init (Pseudo-Terminal, Antworten per Skript) -> fragt Name, Bundle-ID, Akzent, Symbol, 8 Module, Fortfahren
Kopie des Starters mit Tags v1.0.0/v1.0.1 (lokal), Projekt mit init + remove island, dann
  bin/starter sync --ziel 1.0.1 --quelle <kopie> [--probelauf]
                                  -> Modules.swift, CommonText.swift, Makefile übernommen, Makefile als ausführbar
                                     gemeldet, Insel blieb entfernt, check-kit danach "96 Kit-Dateien unverändert seit
                                     Starter 1.0.1"
```

Kein App-Start, keine Berechtigungen, kein Anmeldeobjekt; die Probe baut nur, ihre Temp-Ordner werden gelöscht, es bleibt kein Prozess.

## Review (2026-10-12)

Fünfzehn Befunde aus zwei Prüfungen (Korrektheit, Doku); zwei davon doppelt. Je Befund: echt oder nicht, was geschah.

| # | Befund | Urteil | Ergebnis |
|---|---|---|---|
| 1, 8 | `remove island` scheitert an `Metrics.Island`, `Radius.Island`, `enum Island {` (Blocker) | echt | behoben (8784b8d): Mitgliedszugriff und eigene Deklarationen zählen nicht als Nutzung; ein verschachtelter Typ gilt in seiner Datei als eigener Gültigkeitsbereich. Test mit `extension Radius { enum Island {} }`, `Metrics.Island.x` und echter Nutzung `Island.shared` |
| 2, 7 | check-kit hält G1s Hook `exec python3 "$ROOT/scripts/check_commit_msg.py"` für abgeschaltet (Blocker) | echt | behoben (c269ca9): Skriptpfade dürfen in Anführungszeichen und hinter einem Ordner stehen; Kommentar- und echo/print-Zeilen zählen nicht. Test mit G1s Hook-Text, auch als Projekt |
| 3 | remove und sync schreiben alle Kit-Prüfsummen neu, frühere Änderungen verschwinden (major) | echt | behoben (c0ad7bc): remove führt nur die Prüfsummen der Dateien nach, die es selbst geändert hat und die bis dahin unverändert waren; sync nur die der Kit-Dateien, die jetzt den Zielstand tragen. Tests für beide |
| 4 | init überschreibt eine leere Vorlage mit dem Starter-Text, `STARTER_DECISIONS.md` behält den Block (minor) | echt | behoben (2d449b3): erst schneiden, dann verschieben und ersetzen; ersetzte Dateien werden nicht zurückgeschrieben. Test |
| 5 | Markierungen in Skripten ohne Endung (Hooks, `bin/starter`) werden ignoriert (minor) | echt | behoben (57c2863): Erkennung über die `#!`-Zeile |
| 6 | nur-im-starter-Abschnitte nur als HTML-Kommentar (minor) | echt | behoben (57c2863): Marker in der Kommentarsyntax der Datei (`#`, `//`, `<!-- -->`); Naht ohne doppelte Leerzeilen. G2 hat die Starter-Jobs in `ci.yml` inzwischen über `.github/ci_plan.py` abgeschaltet; die Marker sind der zweite Weg |
| 9 | Kein `Features.register()`, ein Feature braucht eine Kit-Änderung (major) | echt | auf `strang/G2` behoben (21fd11a: `Modules.registerAll()` ruft `Features.register()`, Stub `App/Sources/Features/Features.swift`). K ergänzt einen Test und einen Probe-Schritt (7a5e0eb): Feature plus Tests in Projektpfaden halten check-kit grün |
| 10 | Kit-Pfade, die die Doku dem Projekt zum Ändern gibt (major) | echt | behoben (9829aea): `rules/baseline/**`, `tools/icon/Icon.swift`, `tools/dmg/Background.swift` sind gemeinsam; remove streicht Baseline-Einträge gelöschter Dateien; die Manifest-Beschreibung (überlebt init) nennt die Projektorte. Tests liegen unter `App/Tests/Features/` (G2s Skill sagt das inzwischen) |
| 11 | Interaktives init prüft Modulregeln erst nach der Bestätigung (major) | echt | behoben (f289ac1): Regeln je Antwort, mlx geht mit ai ohne Frage, die letzte App-Form lässt sich nicht abwählen, Standard wie in `starter.json`, Zusammenfassung vor „Fortfahren?“. Per Pseudo-Terminal auf dem Integrationsstand geprüft |
| 12 | Roter Build nach init/remove: Bericht weg, zweiter Lauf meldet Erfolg, `git checkout .` empfohlen (major) | echt | behoben (413bec4, 717b89a): ganzer Bericht vor dem Fehler, Exit 1, `pendingBuild` in der Lock-Datei, ein zweiter Lauf baut noch einmal, Wiederherstellung mit `git restore --source=HEAD --staged --worktree -- <dateien>` (in `.claude/settings.json` unter „ask“, nicht verboten), Hinweis auf vorher nicht committete Änderungen. Nicht abgelehnt bei schmutzigem Baum: CI entfernt mehrere Module ohne Commit dazwischen |
| 13 | Eine frische Kopie gilt als „der Starter selbst“ (major) | echt | behoben (edaa0c6): Zustand aus Lock, `origin` und in CI `GITHUB_REPOSITORY` (project, starter, needs-init, unknown wie app-starter). needs-init lässt check-kit und doctor scheitern; ohne origin wird wie der Starter geprüft, mit Hinweis |
| 14 | Englische Meldungen, irreführende Namensregel, fehlende Hinweise, Wortlaut (minor) | echt | behoben (2ce29dd, Teile in 413bec4): init prüft Flags selbst auf Deutsch, Namensregel nennt Umlaute in `app.displayName`, Bundle-ID-Hinweis nur im Bericht, fehlender Tag nennt `git ls-remote --tags`, Einzahl, Probelauf im Konjunktiv, echte Bundle-ID in den nächsten Schritten, Hilfe zu remove umformuliert |
| 15 | sync lehnt `ssh://git@…` ab, Standardquelle nur HTTPS (minor) | echt | behoben (a2dbca2): nur Passwörter und Tokens abgelehnt; Standardquelle per SSH, wenn `origin` SSH nutzt; Git fragt nie nach einem Passwort (`GIT_TERMINAL_PROMPT=0`, auch bei init) |

### Für die Integration (nicht in diesem Strang)

- `CLAUDE.md:151` nennt `docs/KI.md` und `tools/README.md:33` nennt `ai-worker/` ohne Modul-Markierung; check-kit im Starter meldet beides (`remove ai`, `remove mlx`) und `test_this_repository_passes` ist rot, bis dort `<!-- modul:ai -->` bzw. `<!-- modul:mlx -->` steht (CLAUDE.md Teil A kommt aus `rules/`, die Markierung gehört dann in die Quelle).
- `AppIconImage` ist doppelt deklariert (Strang A `Modules/Window/Pages/HomePage.swift`, Strang D `Kit/Onboarding/OnboardingSteps.swift`); der zusammengeführte Stand baut erst, wenn einer umbenannt ist.
- G2: `docs/UEBERGABE.md` sollte für private Starter `--quelle git@github.com:wielochyeah/mac-app-starter.git` nennen.

### Prüfung nach dem Review

```
python3 -m unittest discover -s scripts/starter/tests -t scripts -p 'test_*.py'   -> Ran 115 tests … OK
make check (strang/K)            -> grün; check-kit: Starter selbst, alle Dateien klassifiziert, 8 von 8 Modulen
                                    entfernbar, Hinweis auf noch fehlende Dateien von G1/G2
make build, MODULES=menubar, MODULES=window (strang/K) -> grün
STARTER_PROBE_JOBS=2 make probe (strang/K)  -> OK (skipped=1: Hook fehlt auf diesem Branch), 148 s
Integrationsklon (main + A, B, C, D, E, F, G1, G2, H, J + K; Platzhalter-Korrekturen nur im Klon: Markierungen in
CLAUDE.md:151 und tools/README.md:33, AppIconImage in HomePage umbenannt; origin auf den Starter gesetzt):
  bin/starter check-kit         -> grün, "8 von 8 Modulen lassen sich ohne Reste entfernen", Hooks erfüllt
                                    (ohne die Platzhalter: nur die zwei Anleitungs-Befunde oben)
  STARTER_PROBE_JOBS=2 make probe -> "Ran 6 tests … OK" (203 s), ohne Überspringen: init grün (40 s), Commit ohne
                                    Identität scheitert an G1s Hook, remove window/menubar/island/background/hotkeys/
                                    mlx/examples je grün mit make build und check-kit, ai erst nach mlx, menubar nach
                                    window abgelehnt, erstes Feature hält check-kit grün
  Kopie mit origin git@github.com:beispiel/notizen.git: doctor und check-kit Exit 1 „noch nicht eingerichtet“;
    interaktives init per Pseudo-Terminal: menubar nach window=n neu gefragt, mlx mit ai entfernt, Zusammenfassung,
    danach check-kit "231 Kit-Dateien unverändert", remove hotkeys --probelauf im Konjunktiv
```
