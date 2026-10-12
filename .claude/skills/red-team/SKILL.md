---
name: red-team
description: Führt die Gegenprüfung eines Pakets aus (bei Oberflächenänderungen zuerst Renders in en und de, hell und dunkel, dann sechs Blickwinkel, danach der Widerleger) und arbeitet die Befunde in die Statusdatei ein. Nutzen nach jedem Paket und vor jedem Merge.
---

# Red-Team

## Verträge und Dateien

| Datei | Rolle |
|---|---|
| `.claude/agents/pruefer-korrektheit.md`, `pruefer-laie-ux.md`, `pruefer-design.md`, `pruefer-sicherheit.md`, `pruefer-integration.md` | die Blickwinkel |
| `.claude/agents/widerleger.md` | versucht jeden Befund zu widerlegen |
| `.claude/workflows/red-team.js` | rendert bei Oberflächenänderungen alle Szenen, führt alle Blickwinkel, das Zusammenführen und den Widerleger aus |
| `scripts/render.sh` (`make shots`) | die Bilder, außerhalb von Git |
| `docs/agents/status/<kennung>.md` | Tabelle „Befunde der Gegenprüfung“ mit Commit oder Begründung |
| `docs/vorlagen/REVIEW.md` | Aufbau einer Review-Runde über mehrere Pakete, Dateien unter `docs/review/` |

## Ablauf

1. Vorher: `make check` grün, alles committet, Statusdatei mit Beweisen.
2. Mit Workflow-Werkzeug: Workflow mit `scriptPath: ".claude/workflows/red-team.js"` und `args: { branch, base, paket, strang, umfang, szenen }` starten. Aufnehmen läuft zuerst: Ändert der Stand etwas unter `App/Sources/` oder `App/Resources/`, rendert ein Subagent in einem eigenen Worktree außerhalb des Repositorys alle Szenen (`make shots`, mit `szenen: ["island.", "settings."]` nur diese Präfixe). Die Blickwinkel Laie und UX und Design öffnen jedes Bild; bei vielen Bildern teilt der Workflow sie auf mehrere Subagenten desselben Blickwinkels auf. `umfang: "voll"` (Standard) führt sechs Blickwinkel aus und meldet alle Schweregrade; `umfang: "sparsam"` führt einen Blickwinkel aus, der nur prüft, was die App bricht, und meldet nur `blockierend` und `wichtig`, bei Oberflächenänderungen zusätzlich die Sichtprüfung.
3. Ohne Workflow-Werkzeug: bei Oberflächenänderungen zuerst `make shots` (Bilder bleiben in `build/shots/`), dann höchstens zwei Subagenten gleichzeitig starten: erst `pruefer-korrektheit` und `pruefer-sicherheit`, dann `pruefer-laie-ux` und `pruefer-design` mit der Liste aller Bilder, dann `pruefer-integration` und `pruefer-korrektheit` mit dem Auftrag „Abgleich mit Paket und Abnahme in `docs/agents/straenge.json`, `docs/agents/VORGABEN.md`, `docs/DECISIONS.md` und `docs/PROJECT.md`“, zuletzt `widerleger` mit allen Befunden.
4. Neue Vorgaben aus `docs/agents/VORGABEN.md` gehören in den Auftrag jedes Subagenten.
5. Das Ergebnis `sichtpruefung` steht in der Statusdatei: `geprüft` mit Zahl der Bilder und der Streichliste, `nicht geprüft` mit Grund oder `ohne Oberflächenänderung`. Ohne Bilder gilt die Oberfläche als nicht geprüft, auch wenn alle Tests grün sind; die Punkte der Streichliste werden umgesetzt oder begründet abgelehnt.
6. Jeder bestätigte Befund wird behoben (Commit) oder in der Statusdatei begründet abgelehnt. Widerlegte Befunde stehen mit Grund in der Statusdatei. Was der Workflow unter `unchecked` meldet (ausgefallener Blickwinkel, Befund ohne Urteil), läuft erneut oder steht als „nicht geprüft“ in der Statusdatei.
7. Nach den Korrekturen erneut `make check`; bei größeren Änderungen eine sparsame zweite Runde.

Kein Subagent startet die App normal; Laufzeit prüfen nur `make test`, `make shots` und `--selftest` mit `STARTER_HEADLESS=1`.

## Kosten

Viele Runden kosten viele Tokens. Ab der zweiten Runde reicht `umfang: "sparsam"`; mit `szenen` bleibt die Sichtprüfung bei den Bereichen, die sich geändert haben. Kleine Befunde werden gesammelt behoben, nicht einzeln geprüft.
