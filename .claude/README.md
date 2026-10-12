# .claude

Einstellungen, Hooks, Skills, Subagenten und Workflows für Agenten. Sie greifen in jedem frischen Klon ohne Handarbeit: Claude Code liest `.claude/settings.json` beim Start, die Hooks brauchen nur das `python3` der Command Line Tools (3.9, ohne Pakete) und Git.

## Rechte (`settings.json`)

| Liste | Inhalt |
|---|---|
| `allow` | die Prüf- und Baubefehle (`make doctor`, `build`, `test`, `check`, `shots`, auch `NO_BUILD=1 make shots`, `readme-shots`, `rules`, `hooks`), lesende Git-Befehle, `bin/starter modules` und `check-kit`, der Selbsttest ohne Fenster, für den Workflow `red-team` ein eigener Worktree (`git worktree add --detach`, Entfernen nur für Ordner `red-team-*`) und `pgrep -fl` |
| `ask` | Push nach `main`, Löschen von Branches, `git restore`, `git clean`, `rm -rf`, App starten (`make run`, `open`), DMG, Signatur und Notarisierung, `bin/starter init`, `remove`, `strip-examples`, `sync` (auch mit `--probelauf`, weil die Muster den Probelauf nicht vom echten Lauf trennen; ob sich Module entfernen lassen, zeigt `make check-kit` ohne Rückfrage), `tccutil`, `defaults`, `launchctl`, Installationen mit `brew` oder `pip` |
| `deny` | `sudo`, Force-Push und andere Umschreibungen der Geschichte, die üblichen Wege an den Git-Hooks vorbei (`--no-verify` mit Abkürzungen, `git commit -n`, `core.hooksPath` in jeder Schreibweise, Hooks löschen oder unausführbar machen), Schlüsselbund auslesen, `tccutil reset All` ohne Bundle-ID, Umgebungsvariablen ausgeben, `.env`-Dateien und Zertifikate lesen |

Die Muster sperren die Form, die etwas einstellt, nicht das Wort: `grep hooksPath` läuft weiter. Muster vergleichen nur Text; Formen wie `git commit -anm x` oder `git -C . config core.hooksPath x` fängt der Hook `guard-git.py` ab, der die Argumente wie Git liest. Lückenlos ist das nicht (ein Skript kann Git anders aufrufen), deshalb wiederholt die CI jede Prüfung. Ein Test in `scripts/tests/test_claude_harness.py` prüft mit einem Nachbau des Abgleichs und mit dem Hook, dass gefährliche Befehle gesperrt sind und alltägliche nicht.

## Hooks

| Hook | Ereignis | Wirkung |
|---|---|---|
| `hooks/guard-git.py` | PreToolUse auf `Bash` | lehnt Git-Befehle ab, die die Hooks umgehen: `--no-verify` und Abkürzungen bei commit, merge, push, rebase, am, cherry-pick, revert, `git commit -n` auch in Gruppen wie `-anm`, jede Änderung von `core.hooksPath` (auch über `-c`, `-C` oder `GIT_CONFIG_*`), auch in `sh -c`; Lesen des Werts bleibt erlaubt |
| `hooks/session-start.py` | SessionStart | `scripts/doctor.sh` als eine Zeile (installiert nie etwas; ohne das `SDKROOT`, das der `python3`-Shim der Command Line Tools setzt), `core.hooksPath` auf `scripts/hooks` (wie `make hooks`), Git-Identität aus `starter.json` (`commit`); leer heißt: beim Auftraggeber erfragen, nie erfinden |
| `hooks/announce-directives.py` | PostToolUse auf schreibende Werkzeuge | stellt jeden offenen Abschnitt aus `docs/agents/VORGABEN.md` jedem schreibenden Agenten genau einmal zu, unter 7 KB; liest auch die Fassung auf `origin` (ohne Abruf aus dem Netz) |

Tests der Hooks: `scripts/tests/test_claude_harness.py` (läuft mit `make test`).

## Skills

| Skill | wofür |
|---|---|
| `neues-feature` | Funktion des Projekts unter `App/Sources/Features/` mit Texten, Speicher, Registrierung, Szenen und Tests |
| `neue-ansicht` | Seite im Hauptfenster (Modul `window`) | <!-- modul:window -->
| `neue-einstellung` | typisierte Einstellung und Bereich im Einstellungsfenster |
| `neuer-onboarding-schritt` | Schritt im Onboarding mit Reihenfolge, Bedingung und Zuständen |
| `neue-berechtigung` | macOS-Berechtigung mit Erklärtext, Entitlements und Onboarding-Schritt |
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
