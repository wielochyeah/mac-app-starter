# Review

Vorlage für eine Review-Runde über mehrere Stränge oder Pakete. Kleine Runden nach einem Paket stehen nur in der Statusdatei des Strangs (Tabelle „Befunde der Gegenprüfung“); diese Vorlage ist für größere Runden, etwa am Checkpoint vor einem Merge nach `main`. Der Ablauf steht im Skill `red-team`, das Werkzeug ist `.claude/workflows/red-team.js`.

Die Dateien einer Runde liegen in einem Projekt unter `docs/review/`: `_stand.md` mit dem Stand je Strang, eine Datei `<strang>.md` je Strang mit seinen Befunden und `gesamt.md` für Befunde über alle Stränge.

## _stand.md

Letzter geprüfter Commit je Branch. Die nächste Runde prüft nur Commits danach und die offenen Befunde auf Erledigung.

| Strang | Branch | zuletzt geprüft | Runde | Umfang |
|---|---|---|---|---|
| `<Kennung>` | `claude/<projekt>-<kennung>` | `<Hash>` | 1 | `voll` oder `sparsam` |

## Vorgehen je Runde

1. `git fetch origin`; neue Commits je Branch seit dem Eintrag in `_stand.md`.
2. Je Strang die Blickwinkel Korrektheit, Anforderungen, Laie und UX, Design, Sicherheit und Integration (Subagenten `pruefer-*`), höchstens zwei gleichzeitig. Ab der zweiten Runde reicht meist `umfang: "sparsam"`.
3. Jeder Befund geht an den `widerleger`; nur bestätigte Befunde kommen in `<strang>.md`, widerlegte mit Grund in den Abschnitt „Widerlegt“.
4. Was ein Blickwinkel nicht prüfen konnte, steht als „nicht geprüft“ in der Datei, nie als „ohne Befund“.
5. Zum Schluss prüft `pruefer-integration` mit dem Auftrag Vollständigkeit über alle Stränge: jede Zeile aus `docs/agents/PLAN.md`, `docs/agents/straenge.json` und der Abnahmeliste der Ausbaustufe (nach `docs/vorlagen/ABNAHME.md`) gegen das, was gebaut und geprüft ist. Lücken gehen an den `widerleger` und dann nach `gesamt.md`.
6. `_stand.md` bekommt die neuen Commits.

## <strang>.md

```
# Review Strang <Kennung>

Geprüft: <Hash> gegen <Basis>, Runde <n>

## Offen

### <Kennung>-<Runde>-<Nr> (<blockierend | wichtig | klein>): <Titel>

- Datei: <Pfad>:<Zeile> oder Bild <build/shots/...png>
- Blickwinkel: <Korrektheit | Anforderungen | Laie | Design | Sicherheit | Integration>
- Problem: <ein bis drei Sätze mit Beleg>
- Vorschlag: <konkret>

## Erledigt

| Befund | Commit | geprüft in Runde |
|---|---|---|

## Abgelehnt

| Befund | Begründung des Strangs | trägt die Begründung |
|---|---|---|

## Widerlegt

| Befund | Grund |
|---|---|
```

Kennungen wie `I-2-03` (Strang I, Runde 2, dritter Befund) werden nie neu vergeben. Ein Strang arbeitet seine offenen Befunde mit Commit oder begründeter Ablehnung in seiner Statusdatei ab; die nächste Runde prüft, ob das trägt.
