# Vorgaben

Neue Wünsche und Entscheidungen des Auftraggebers während der Arbeit. Sie gelten sofort, gehen `CLAUDE.md` und allen anderen Dokumenten vor und werden an jeden gestarteten Subagenten weitergegeben. Der Hook `announce-directives` stellt schreibenden Sessions jeden neuen Abschnitt einmal zu.

## Wie eine Vorgabe eingetragen wird

Jede Vorgabe bekommt einen eigenen Abschnitt mit fortlaufender Kennung, Datum und kurzem Titel. Darunter steht der Wunsch möglichst im Wortlaut, danach was konkret zu tun ist und für wen. Die Zeile „Stand“ bleibt beim Eintragen auf „offen“.

```
## V1 (TT.MM.JJJJ): <kurzer Titel>

<Wortlaut oder Zusammenfassung des Wunsches>

- <was konkret zu tun ist>
- Zuständig: <Strang oder alle>

Stand: offen
```

## Wie eine Vorgabe eingearbeitet wird

Eine Vorgabe ist kein dauerhafter Anhang. Innerhalb eines Arbeitstags wird sie als Regel übernommen, damit keine Liste entsteht, die sich mit der Zeit widerspricht. Der Ort ist `rules/projekt/`:

1. Die Regel in `rules/projekt/projekt.json` mit der nächsten freien Kennung `P-NN` anlegen oder ändern, im Feld `vorgabe` die Kennung eintragen. Lässt sich die Regel an Wörtern oder Zeichen erkennen, einen Begriff mit Beispielen in einem Paket unter `rules/projekt/pakete/` ergänzen (Ablauf in `rules/README.md`).
2. `make rules` ausführen, danach `make check`. Die Regel steht dann im Abschnitt „Projektregeln“ von `CLAUDE.md`.
3. Die Zeile „Stand“ ändern auf `eingearbeitet in <Regelkennungen>, Commit <Hash>`.
4. Betrifft die Vorgabe eine Regel aus Teil A, die in jedem Projekt anders gelten sollte, steht sie zusätzlich in `docs/STARTER_FEEDBACK.md`; Teil A selbst bleibt im Projekt unverändert.

Eingearbeitete Vorgaben bleiben als Verlauf stehen. Maßgeblich ist danach der Wortlaut in `rules/` und `CLAUDE.md`.

## Vorgaben

Noch keine.
