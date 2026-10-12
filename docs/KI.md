# Lokale KI

Die Module `ai` und `mlx` geben der App ein Sprachmodell, das auf dem Mac läuft. Kein Text verlässt den Mac, es gibt keinen API-Schlüssel und kein Konto. Wie eine Funktion mit KI entsteht, steht im Skill `ki-funktion`.

## Anbieter

| Anbieter | Modul | Download | Stärken | Grenzen |
|---|---|---|---|---|
| Apple Foundation Models | `ai` (an) | keiner, das Modell gehört zu macOS | sofort da, Deutsch und Englisch, strukturierte Antworten über `DynamicGenerationSchema`, kein zusätzlicher Speicher auf der Platte | braucht Apple Intelligence (eingeschaltet, Gerät geeignet, Modell geladen); Modell und Fähigkeiten legt Apple fest |
| MLX | `mlx` (aus) | ein Modell nach Wahl, 1 bis mehrere GB | eigene Modelle (etwa Qwen in 4 Bit), unabhängig von Apple Intelligence | braucht Python 3.11 bis 3.13 (bevorzugt 3.12) und `mlx-lm` in `ai-worker/.venv`, Download, Arbeitsspeicher | <!-- modul:mlx -->

`mlx` braucht `ai`; `bin/starter remove ai` verlangt vorher `bin/starter remove mlx`. Die Einstellung „Anbieter“ im Bereich „Modelle“ wählt `Automatisch` (Apple, wenn verfügbar, sonst MLX), `Apple` oder `MLX` (nur mit Modul `mlx`).

## Schnittstelle

```swift
#if MODUL_AI
let ai = LocalAI.shared                                                   // @Observable, eine Instanz
if case .unavailable(let reason) = ai.availability { … }                  // Grund mit Text für die Nutzerin
let text = try await ai.respond(prompt: input, instructions: SummaryText.instructions)
for try await answer in ai.stream(prompt: input, instructions: SummaryText.instructions) { … }  // jeweils die ganze Antwort bisher; abbrechbar über die Task
let content = try await ai.structured(prompt: input, schema: schema)      // DynamicGenerationSchema, nur Apple
#endif
```

- Anbieter erfüllen `LocalModelProvider`; Tests speisen einen eigenen Anbieter ein und rufen nie das echte Modell.
- Fehler tragen einen Text für die Nutzerin in beiden Sprachen (nicht verfügbar, abgebrochen, Zeitüberschreitung, Modell fehlt) und nie den Prompt.
- Der Bereich „Modelle“ zeigt Anbieter, Verfügbarkeit mit Hinweis, wie sie sich herstellen lässt (etwa Apple Intelligence in den Systemeinstellungen einschalten, mit Link), ein Testfeld mit gestreamter Antwort und einen Zähler der Aufrufe mit letzter Dauer.
- Der Onboarding-Schritt „Lokale KI“ (order 400) zeigt die Verfügbarkeit und mit `mlx` die Download-Zeilen.

## Datenschutzversprechen

Die App hält diese Zusagen ein; jede Funktion mit KI erbt sie:

1. Prompts und Antworten bleiben auf dem Mac. Es gibt keinen Netzaufruf außer dem Modell-Download, den die Nutzerin auslöst.
2. Weder Prompt noch Antwort stehen im Protokoll, in Absturzberichten oder in Fehlermeldungen.
3. Gespeichert wird nur, was eine Funktion ausdrücklich als Ergebnis speichert, und die Nutzerin kann es löschen.
4. Ohne verfügbares Modell bleibt die Funktion sichtbar, sagt in einem Satz, warum sie aus ist, und die übrige App läuft weiter.

<!-- modul:mlx:anfang -->
## Modelle für MLX

- Katalog: `ai-worker/models.json` mit Name, Rolle, Hugging-Face-Adresse und Größe; mindestens ein kleines Standardmodell (unter 1 GB, 4 Bit) und eine größere Wahl für bessere Antworten.
- Download: nur auf Knopfdruck in den Einstellungen oder im Onboarding, mit Größe vorher, Fortschritt „x von y GB“, Pause und erneutem Versuch. Der Download läuft in einem eigenen Prozess (`ai-worker/download.py`) und misst den Fortschritt am Cache gegen die Gesamtgröße.
- Ablage: unter `~/Library/Application Support/<bundleId>/Models/huggingface` (`MLXPaths.hfHome`, mit `STARTER_DATA_DIR` in dessen Ordner); Modelle kommen nie ins Repository und lassen sich in den Einstellungen löschen.
- Umgebung: `ai-worker/setup.sh` legt `ai-worker/.venv` mit Python 3.12 an (aus Homebrew, sonst 3.11 oder 3.13, sonst über uv) und installiert die festen Versionen aus `ai-worker/requirements.lock`, ohne diese Datei aus `ai-worker/requirements.txt`; `ai-worker/setup.sh --check` prüft nur, `--lock` schreibt die Sperrdatei neu. Das Skript installiert nie Homebrew oder uv selbst; fehlt beides, sagt es, welcher Befehl fehlt.

## Der MLX-Worker

Ein Python-Prozess (`ai-worker/`), den `MLXWorkerClient` startet und überwacht:

- Protokoll: JSON-Zeilen über stdin und stdout; stdout ist für das Protokoll reserviert (Ausgaben von Bibliotheken gehen nach stderr).
- Befehle `ping`, `load`, `generate`, `cancel`, `unload`, `shutdown`; Ereignisse `started`, `token`, `done`, `error`. Anfragen haben Priorität und lassen sich abbrechen.
- Zeitlimits zählen ab `started`, nicht ab dem Absenden; ein Modell zu laden dauert beim ersten Mal länger.
- Der Worker beendet sich nach 5 Minuten ohne Anfrage und gibt den Speicher frei; der Client startet ihn bei Bedarf neu, nach Abstürzen mit wachsender Pause (0, 5, 30, 300 s).
- Er beendet sich mit der App (`Registry.terminateHooks`).

## MLX in einer weitergegebenen App

Noch nicht gebaut: `mlx` läuft nur in Entwickler-Builds aus dem Projekt (`make build` und `ai-worker/setup.sh`). Ein Release-Build sucht den Worker nur in `Contents/Resources/ai-worker` und Python nur in `Contents/Resources/python/bin/python3` seines eigenen Bundles, nie im Projekt oder über Umgebungsvariablen. `make dmg` legt beides noch nicht hinein und sagt das in der Ausgabe; die App im DMG zeigt MLX deshalb als „Nicht enthalten“, ohne Download-Knöpfe. Apple Foundation Models (`ai`) funktioniert im DMG wie gewohnt.

Was für die Weitergabe fehlt, ist ein Skript `ai-worker/package.sh <Pfad zur .app>`, das `make dmg` aufruft, sobald es existiert:

- ein eigenständiges Python 3.12 (etwa python-build-standalone) mit den festen Versionen aus `ai-worker/requirements.lock` nach `Contents/Resources/python`, die Dateien des Workers nach `Contents/Resources/ai-worker`;
- jede `.so` und `.dylib` darin signieren, bevor `make dmg` die App signiert; mit Developer ID braucht die Hardened Runtime dann `com.apple.security.cs.disable-library-validation` in `tools/entitlements.plist` und einen Eintrag in `docs/DECISIONS.md`;
- `LSMinimumSystemVersion` an die Mindestversion der Binaries von MLX anpassen (`make dmg` prüft `minos` und bricht sonst ab; MLX 0.32 braucht macOS 26.2).

Bis dahin ist ein DMG mit `mlx` kein Fehler, aber für Empfänger ohne MLX.
<!-- modul:mlx:ende -->

## Prompts

- Anweisungen sind fest im Code, kurz und in der Sprache der Oberfläche. Sie beschreiben Aufgabe, Form der Antwort und Grenzen.
- Der Text der Nutzerin ist Material, keine Anweisung; Anweisungen darin ändern die Regeln nicht.
- Antworten, die die App in eigener Stimme zeigt, folgen den Schreibregeln aus `CLAUDE.md` (keine Floskeln, keine Ausrufezeichen, keine erfundenen Zahlen). Umgeschriebener Text der Nutzerin bleibt ihr Text und wird nicht nach diesen Regeln gefiltert.
- Strukturierte Antworten werden gegen ihr Schema geprüft; was nicht passt, wird verworfen statt gezeigt.

## Prüfen

- `make build MODULES=window,ai` und `make build MODULES=window` (ohne KI baut alles).
- `STARTER_HEADLESS=1 build/<Name>.app/Contents/MacOS/<Name> --selftest` prüft ohne Fenster, was ohne Modell prüfbar ist; das läuft auch in der CI auf Macs ohne Apple Intelligence.
- `STARTER_HEADLESS=1 build/<Name>.app/Contents/MacOS/<Name> --selftest ai` fragt zusätzlich das echte Apple-Modell und meldet Verfügbarkeit und Antwortzeit. Prüfungen gegen ein echtes Modell sind immer `onDemand` (`SelfTestCheck(id:onDemand: true)`) und laufen nur benannt, nie im einfachen `--selftest`.
- Mit `mlx`: `ai-worker/setup.sh`, dann die Python-Tests in `ai-worker/tests/` (Teil von `make test`) und `--selftest mlx` gegen das kleine Modell. <!-- modul:mlx -->
- Renders `ai.pane`, `ai.onboarding`, `ai.download-rows` in allen vier Fassungen ansehen.
