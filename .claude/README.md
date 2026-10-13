# .claude

Einstellungen, Hooks, Skills, Subagenten und Workflows für Agenten. Sie greifen in jedem frischen Klon ohne Handarbeit: Claude Code liest `.claude/settings.json` beim Start, die Hooks brauchen nur das `python3` der Command Line Tools (3.9, ohne Pakete) und Git.

## Rechte (`settings.json`)

| Liste | Inhalt |
|---|---|
| `allow` | genau die Prüf- und Baubefehle (`make doctor`, `build`, `test`, `check`, `check-rules`, `check-texts`, `check-design`, `check-kit`, `shots`, `readme-shots`, `rules`, `hooks`, `icon`, `clean`), Modul- und Szenenwahl nur über `MODULES=`, `CONFIG=release` und `ONLY=`, die Prüfskripte und `scripts/test_python.py` ohne weitere Argumente, lesende Git-Befehle (`git status`, `git diff`, `git log`, `git show` mit Refs, `git fetch` und `git fetch origin` ohne Optionen), `bin/starter modules`, `check-kit` und `--help`, der Selbsttest `build/<Name>.app/Contents/MacOS/<Name> --selftest`, für den Workflow `red-team` ein eigener Worktree (Anlegen und Entfernen nur für Ordner `red-team-*`) und `pgrep -fl` |
| `ask` | Push nach `main`, Löschen von Branches, `git restore`, `git clean`, `rm -rf`, App starten (`make run`, `open`), DMG, Signatur und Notarisierung, `bin/starter init`, `remove`, `strip-examples`, `sync` (auch mit `--probelauf`, weil die Muster den Probelauf nicht vom echten Lauf trennen; ob sich Module entfernen lassen, zeigt `make check-kit` ohne Rückfrage), `tccutil`, `defaults`, `launchctl`, Installationen mit `brew` oder `pip` |
| `deny` | `sudo`, Force-Push und andere Umschreibungen der Geschichte, die üblichen Wege an den Git-Hooks vorbei (`--no-verify` mit Abkürzungen, `git commit -n`, `core.hooksPath` in jeder Schreibweise, Hooks löschen oder unausführbar machen), Git-Optionen, die Programme starten oder fremde Dateien lesen (`--upload-pack`, `--receive-pack`, `--no-index`, `--ext-diff`, `git -c alias…`, `git difftool`), Schlüsselbund auslesen, `tccutil reset All` ohne Bundle-ID, Umgebungsvariablen ausgeben, `.env`-Dateien und Zertifikate lesen |

Die Muster sperren die Form, die etwas einstellt, nicht das Wort: `grep hooksPath` läuft weiter. Muster vergleichen nur Text, und ein `*` trifft alles bis zum Ende; deshalb steht ein `*` in `allow` nur an Stellen für Werte und Refs, die der Hook `guard-git.py` nachprüft. Er liest die Argumente wie Git und make und lehnt ab: Wege an den Hooks vorbei (`git commit -anm x`, `git -C . config core.hooksPath x`), Git-Optionen und Variablen, die ein anderes Programm starten (`git -c` mit anderen Schlüsseln als Anzeige-Einstellungen, `GIT_SSH_COMMAND`, `GIT_CONFIG_*`, `PAGER`, `MAKEFLAGS` …), `make` mit mehr als einem Ziel, mit Optionen oder mit Variablen außer `MODULES`, `CONFIG`, `ONLY`, `SHOTS_LANG`, `SHOTS_APPEARANCE`, `NO_BUILD`, `STRICT`, `CHECK_FLAGS` in ihrer erlaubten Form, und einen Selbsttest unter `build/` aus einem anderen Pfad als `build/<Name>.app/Contents/MacOS/<Name>` (auch mit `..`). Lückenlos ist das nicht (ein Skript kann Git oder make anders aufrufen), deshalb wiederholt die CI jede Prüfung. Ein Test in `scripts/tests/test_claude_harness.py` prüft mit einem Nachbau des Abgleichs und mit dem Hook, dass gefährliche Befehle gesperrt sind, alltägliche nicht, und welche `allow`-Regeln einen `*` tragen dürfen.

## Hooks

| Hook | Ereignis | Wirkung |
|---|---|---|
| `hooks/guard-git.py` | PreToolUse auf `Bash` | lehnt Befehle ab, die die Hooks umgehen (`--no-verify` und Abkürzungen bei commit, merge, push, rebase, am, cherry-pick, revert, `git commit -n` auch in Gruppen wie `-anm`, jede Änderung von `core.hooksPath`) oder aus einem erlaubten Befehl einen anderen machen (Git-Optionen und Variablen, die Programme starten, `make` mit mehreren Zielen, Optionen oder fremden Variablen, Selbsttest aus einem anderen Pfad); auch in `sh -c`; Lesen von Werten bleibt erlaubt |
| `hooks/session-start.py` | SessionStart | `scripts/doctor.sh` als eine Zeile (installiert nie etwas; ohne das `SDKROOT`, das der `python3`-Shim der Command Line Tools setzt), `core.hooksPath` auf `scripts/hooks` (wie `make hooks`), Git-Identität (`scripts/git_setup.py`): in einem Projekt aus `starter.json` (`commit`), nur wenn Git noch keine kennt, eine abweichende wird gemeldet, nie überschrieben; leer heißt: beim Auftraggeber erfragen, nie erfinden; im Starter selbst keine, in einer Kopie vor `bin/starter init` nichts außer dem Hinweis auf `init` |
| `hooks/announce-directives.py` | PostToolUse auf schreibende Werkzeuge | stellt jeden offenen Abschnitt aus `docs/agents/VORGABEN.md` jedem schreibenden Agenten genau einmal zu, unter 7 KB; liest auch die Fassung auf `origin` (ohne Abruf aus dem Netz) |

Tests der Hooks: `scripts/tests/test_claude_harness.py` (läuft mit `make test`).

## Skills

| Skill | wofür |
|---|---|
| `neues-feature` | Funktion des Projekts unter `App/Sources/Features/` mit Texten, Speicher, Registrierung, Szenen und Tests |
| `neue-ansicht` | Seite im Hauptfenster (Modul `window`) | <!-- modul:window -->
| `neue-einstellung` | typisierte Einstellung und Bereich im Einstellungsfenster |
| `neuer-onboarding-schritt` | Schritt in der Einrichtung mit Reihenfolge, Bedingung und Zuständen |
| `neue-berechtigung` | macOS-Berechtigung mit Nutzungsbeschreibung, Entitlements und Einrichtungsschritt |
| `insel-zustand` | Rückmeldung in der Insel an der Notch oder der Kapsel (Modul `island`) | <!-- modul:island -->
| `menueleisten-app` | Statusmenü, Symbolzustände, App ohne Dock-Symbol (Modul `menubar`) | <!-- modul:menubar -->
| `hintergrund-job` | geplante Aufgabe und Start beim Anmelden (Modul `background`) | <!-- modul:background -->
| `kurzbefehl` | globaler Kurzbefehl mit Regeln gegen Belegtes (Modul `hotkeys`) | <!-- modul:hotkeys -->
| `ki-funktion` | lokale KI mit Apple Foundation Models, optional MLX (Modul `ai`) | <!-- modul:ai -->
| `screenshots` | alle Szenen in en und de, hell und dunkel, ohne Fenster |
| `red-team` | Gegenprüfung eines Pakets |
| `starter-rueckfluss` | Bedarf an Kit-Pfaden als Pull Request in den Starter |
| `release-dmg` | Fassung bauen, DMG prüfen, Signatur und Notarisierung |

## Subagenten und Workflow

`agents/pruefer-korrektheit.md`, `pruefer-laie-ux.md`, `pruefer-design.md`, `pruefer-sicherheit.md`, `pruefer-integration.md` und `widerleger.md` prüfen nur lesend und starten die App nie normal. `workflows/red-team.js` rendert bei Oberflächenänderungen alle Szenen, führt sechs Blickwinkel (höchstens zwei gleichzeitig), das Zusammenführen und den Widerleger aus (Skill `red-team`). Ein ausgefallener Blickwinkel und eine unvollständige Sichtprüfung erscheinen als „nicht geprüft“, nie als „ohne Befund“. Der Test in `scripts/tests/test_claude_harness.py` führt den Workflow mit Stellvertretern über `osascript -l JavaScript` aus (nur auf dem Mac).
