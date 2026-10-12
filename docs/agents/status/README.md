# Statusdateien

Jeder Strang führt genau eine Statusdatei nach dem Muster `statusdatei` aus `docs/agents/straenge.json`, also `docs/agents/status/<kennung>.md` (Kleinbuchstabe, zum Beispiel `a.md`), die Integration `integration.md`. Die Datei gehört dem Strang; andere lesen sie, ändern sie aber nicht. Sie ist kurz, aktuell und belegt jede Aussage.

## Vorlage

```
# Strang <Kennung>: <Name>

Branch: <nach branchMuster aus docs/agents/straenge.json, in einem Projekt claude/<projekt>-<kennung>>
Stand: <Datum>, <Commit>

## Erledigt

- <Paket oder Baustein>: <Pfade>, <Tests>

## Beweise

- `<Befehl>`: <Ergebnis, bei Fehlern die entscheidende Zeile>
- Renders: <welche Szenen angesehen wurden, en und de, hell und dunkel>

## Anfragen an andere

| an | Datei | was | warum | Stand |
|---|---|---|---|---|

## Befunde der Gegenprüfung

| Befund | Blickwinkel | erledigt mit | oder abgelehnt, weil |
|---|---|---|---|

## Bekannte Schwächen

- <was noch nicht gut ist, mit Grund>
```

## Regeln

- Beweise statt Behauptungen: Was nicht ausgeführt wurde, gilt als nicht geprüft. Eine Oberfläche, deren Renders niemand mit dem Werkzeug Read geöffnet hat, gilt als nicht geprüft.
- Anfragen an fremde Dateien stehen hier, nie als Änderung in der fremden Datei.
- Der Abschnitt „Bekannte Schwächen“ fehlt nie; er ist leer nur, wenn wirklich nichts offen ist.
- Was nur in der laufenden App prüfbar ist (Fensterverhalten, Berechtigungsdialoge, Insel an der echten Notch, Anmeldeobjekt), steht als „nur interaktiv prüfbar“ unter „Bekannte Schwächen“, bis jemand es mit `make run` oder der installierten App geprüft hat.

## Format von `docs/agents/straenge.json`

Die Datei ist die maßgebliche Fassung des Strang-Plans. In einem Projekt legt `bin/starter init` sie aus `docs/vorlagen/straenge.json` an.

| Feld | Inhalt |
|---|---|
| `version`, `stand` | Formatversion und Datum der letzten Änderung (JJJJ-MM-TT) |
| `branchMuster`, `statusdatei` | Muster mit `<kennung>` für Branch und Statusdatei eines Strangs |
| `regeln` | Sätze, die für jeden Strang gelten |
| `wellen`, `checkpoints` | welche Stränge gleichzeitig laufen und wann zusammengeführt wird |
| `vertraege` | je Schnittstelle `id`, `datei`, `besitzer`, `nutzer`, `inhalt` |
| `einstellungen` | je Einstellungsschlüssel (`SettingKey`) `name`, `besitzer`, `standard`; ein Schlüssel hat genau einen Besitzer |
| `renderSzenen` | je Präfix der Szenen-Kennungen (`window.`, `island.` …) der Besitzer |
| `gemeinsameAbnahme` | Bedingungen, die jeder Strang erfüllt |
| `integration` | `id`, `name`, `branch`, `ziel` und `dateien`: die gemeinsamen Dateien, die nur die Integration ändert |
| `straenge` | je Strang `id`, `name`, `welle`, `ziel`, `pakete`, `dateien` (Globs), `liefert`, `abhaengigkeiten`, `abnahme`, `branch` |

Jede Datei des Repositorys gehört genau einem Feld `dateien`. Wer ein Feld `dateien` ändert, prüft das für alle Dateien.
