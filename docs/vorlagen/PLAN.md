# Plan

Vorlage für den Arbeitsplan eines Projekts. `bin/starter init` legt sie als `docs/agents/PLAN.md` an. Der Plan beschreibt, was gebaut wird und in welcher Reihenfolge; wer welche Dateien ändert, steht maschinenlesbar in `docs/agents/straenge.json`.

## Ziel

`<ein Absatz: was die erste Ausbaustufe leistet und woran der Auftraggeber sie erkennt>`

## App-Formen und Module

| Modul | bleibt | Grund |
|---|---|---|
| `window` | `<ja oder nein>` | `<Hauptfenster nötig?>` |
| `menubar` | `<ja oder nein>` | `<Statusmenü nötig?>` |
| `island` | `<ja oder nein>` | `<Rückmeldung an der Notch nötig?>` |
| `background` | `<ja oder nein>` | `<geplante Aufgaben, Start beim Anmelden?>` |
| `hotkeys` | `<ja oder nein>` | `<globale Kurzbefehle?>` |
| `ai` | `<ja oder nein>` | `<lokale KI?>` |
| `mlx` | `<ja oder nein>` | `<eigene Modelle über MLX?>` |
| `examples` | nein, sobald das erste Feature steht | `bin/starter strip-examples` |

Mindestens `window` oder `menubar` bleibt, sonst sind die Einstellungen nicht erreichbar.

## Stufen

| Stufe | Inhalt | fertig, wenn |
|---|---|---|
| 1 | `<Ansichten, Einstellungen, Einrichtungsschritte, Hintergrundaufgaben>` | `<Abnahme in Sätzen>` |

## Stränge

Ein Strang ist ein Arbeitspaket mit eigener Session, eigenem Branch und festen Dateien; die Integration führt die Stränge zusammen und pflegt die gemeinsamen Dateien. Ohne Parallelbetrieb gibt es nur die Integration.

| Strang | Ziel | Pakete | Dateien |
|---|---|---|---|
| `<Kennung>` | `<ein Satz>` | `<Paket: Inhalt>` | `<Globs, gleich dem Feld dateien in straenge.json>` |

## Verträge

Schnittstellen zwischen Strängen mit Datei, Besitzer und Signatur. Die Integration legt jede Vertragsdatei vor dem Start der Stränge als Stub mit der endgültigen Signatur an (in Swift: Typ und `register()` mit leerem Körper, so baut jede Kombination).

| Vertrag | Datei | Besitzer | Nutzer | Inhalt |
|---|---|---|---|---|

## Checkpoints

| Checkpoint | wann | was |
|---|---|---|
| C1 | `<Ende der Stufe>` | Merge, `make check`, `make shots` angesehen (en, de, hell, dunkel), Gegenprüfung mit dem Skill `red-team` |
