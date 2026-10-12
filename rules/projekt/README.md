# rules/projekt/

Regeln und Sprachpakete des Projekts. Dieser Ordner gehört dem Projekt; alle anderen Dateien in `rules/` gehören dem Starter und werden in einem Projekt nicht geändert (A-06).

| Datei | Inhalt |
|---|---|
| `projekt.json` | Gruppe `projekt` mit Regeln `P-01`, `P-02` und so weiter, Aufbau wie `rules/gruppen/*.json` |
| `pakete/*.json` | Sprachpakete des Projekts, Aufbau wie `rules/pakete/*.json`; `gruppe` ist `projekt` oder eine Gruppe aus Teil A |

`make rules` lädt beides ohne weiteren Eintrag, schreibt die Regeln in den Abschnitt „Projektregeln“ von `CLAUDE.md` Teil B und nimmt die aktiven Begriffe in `rules/generated/begriffe.json` auf. Damit gelten sie in `make check-texts`, `make check-design`, im Hook `commit-msg` und für KI-Texte genauso wie die Pakete des Starters.

## Neue Projektregel

1. Regel mit der nächsten freien Kennung in `projekt.json` anlegen, im Feld `vorgabe` die Kennung aus `docs/agents/VORGABEN.md` eintragen.
2. Lässt sich die Regel an Wörtern, Zeichen oder Code erkennen, ein Paket in `pakete/` anlegen oder ergänzen, mit Beispielen für Treffer und erlaubte Texte. Ein Paket, das eine Regel prüft, steht in deren Feld `pakete`.
3. `make rules`, danach `make check`.

Eine Regel, die für jedes Projekt gelten sollte, gehört zusätzlich als Vorschlag in `docs/STARTER_FEEDBACK.md`.
