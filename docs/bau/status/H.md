# Status H (Lokale KI: Module `ai` und `mlx`, `ai-worker/`)

Stand: 2026-10-12, Branch `strang/H`. `mlx` bleibt in `starter.json` aus.

## Was gebaut ist

| Bereich | Dateien |
|---|---|
| Modul `ai` | `App/Sources/Modules/AI/`: `AIModule.swift` (Registrierung, Selbsttests), `LocalAI.swift` (Fassade, `LocalModelProvider`, `AIAvailability`/`AIUnavailableReason`, `AIError`, `ProviderChoice`, `AIUsage`, `AIPaneSection`, Settings-Schlüssel `ai.provider`, `ai.usage`), `AppleOnDeviceProvider.swift` (FoundationModels), `AIViews.swift` (Bereich „Modelle“, Schritt „Lokale KI“, `ModelRowItem`/`ModelRowView`, `AITrial`), `AIScenes.swift` (Szenen, Galerie, Beispielzustände), `AIText.swift`, `AIWait.swift` |
| Modul `mlx` | `App/Sources/Modules/MLX/`: `MLXModule.swift` (Registrierung, Szenen, Selbsttests `mlx.catalog`, `mlx.download`, `mlx.live`), `MLXWorkerClient.swift`, `MLXProvider.swift` (Schlüssel `mlx.model`), `ModelDownloads.swift`, `ModelCatalog.swift` (+ `HubCache`), `WorkerProtocol.swift` (Ereignisse, Anfragen, `RestartPolicy`, `WorkerBudget`, `LineBuffer`), `MLXPaths.swift`, `MLXViews.swift`, `MLXText.swift` |
| Python | `ai-worker/worker.py`, `download.py`, `models.json`, `requirements.txt`, `requirements.lock`, `setup.sh`, `fake_worker.py`, `tests/test_worker.py`, `tests/test_download.py`, `tests/fake_download.py` |
| Tests | `App/Tests/AITests.swift` (16), `App/Tests/MLXTests.swift` (25, nur mit `mlx`), `App/Tests/SelfTestFilterTests.swift` (2); Python 22 Tests |

### API (für Features und Welle 2)

```swift
LocalAI.shared.respond(prompt:instructions:maxTokens:temperature:) async throws -> String
LocalAI.shared.stream(prompt:instructions:…) -> AsyncThrowingStream<String, Error>   // jedes Element = ganzer Text bisher
LocalAI.shared.structured(prompt:schema: DynamicGenerationSchema, dependencies:instructions:) async throws -> GeneratedContent  // nur Apple
LocalAI.shared.availability / .active / .providers / .choice ("auto"|"apple"|"mlx") / .refresh() / .usage
LocalAI.shared.register(_ provider: any LocalModelProvider)      // weitere Anbieter
LocalAI.shared.sections.append(AIPaneSection(id:order:pane:onboarding:))   // Abschnitte im Bereich/Schritt
AIError (unavailable(reason), cancelled, timeout, contextTooLong, guardrail, unsupportedLanguage, busy, unsupported,
         restarting(s), workerCrashed, failed) -> AIText.error(_:) für kurze Nutzertexte
Abbrechen: die aufrufende Task abbrechen.
```

`LocalAI` hängt an jede Anweisung die Antwortsprache der Oberfläche an (`AIText.replyLanguage`). Gespeichert werden nur Anzahl, Fehler, letzte Dauer und Anbieter (`ai.usage`), nie Text.

### Worker-Protokoll (`ai-worker/worker.py`, Kopf der Datei)

JSON-Zeilen. Anfragen `ping | load | generate | cancel | unload | shutdown`, Ereignisse `ready | pong | started | token | done | error | exit`. Jede Anfrage mit `id` bekommt genau ein `done` oder `error`. Prioritätswarteschlange (0 interaktiv vor 1 Hintergrund), `cancel` und `ping` sofort im Lesethread, stdout geschützt (fd-Trick), Leerlauf-Ende nach 300 s (`exit`-Ereignis, Code 0), MLX-Cache-Grenze 64 MiB und `clear_cache` nach jeder Anfrage, Systemprompt-Präfix-Cache (LRU 4, Markertrick), Schleifenschutz, Chat-Template ohne Thinking, `HF_HUB_OFFLINE=1`.

### Client-Regeln (`MLXWorkerClient`)

Start erst bei der ersten Anfrage; Zeitlimit zählt ab `started` (Warteschlange und Laden bis 90 s extra); Zeitüberschreitung beendet den Worker als eigener Abbruch (kein Absturz); Absturz: offene Anfragen scheitern, eine Wiederholung auf frischem Worker, danach Wartezeit 0/5/30/300 s; Abbruch der Task schickt `cancel`, spätestens nach 5 s endet die Anfrage; stderr in `~/Library/Caches/<bundleId>/mlx-worker.log`; `shutdown` beim Beenden (2 s, dann kill).

### Modelle (`ai-worker/models.json`, beide Apache-2.0, Revision gepinnt)

| id | Rolle | Repo | Größe | RAM (gemessen bzw. VoiceBud) |
|---|---|---|---|---|
| `small` (Standard) | Schnell | `mlx-community/Qwen3-1.7B-4bit` @ `3b1b1768…` | 984 MB | 1,1 GB Spitze |
| `quality` | Genau | `mlx-community/Qwen3.5-4B-MLX-4bit` @ `32f3e8ec…` | 3,06 GB | ca. 3,7 GB (VoiceBud) |

Modelle liegen app-privat in `<Application Support>/<bundleId>/Models/huggingface/hub` (gehen mit den App-Daten, löschbar im Bereich), nicht im geteilten `~/.cache/huggingface`. Download nur nach Klick auf „Herunterladen“, einer nach dem anderen, Fortsetzen nach Abbruch.

## Entscheidungen

- **Erweiterung statt `#if MODUL_MLX` im AI-Modul**: MLX meldet sich über `LocalAI.register` und `LocalAI.sections` an. Das AI-Modul enthält keinen einzigen `#if`-Block; `mlx` entfernen braucht nichts im AI-Ordner.
- **Bereich und Schritt aus Momentaufnahmen** (`AIPaneModel`, `MLXSectionModel`): Renders zeigen feste Zustände, nie die Verfügbarkeit des Render-Macs.
- **`structured` nur mit Apple**: `DynamicGenerationSchema` gehört zu FoundationModels; MLX wirft `.unsupported`.
- **Automatisch**: erster verfügbarer Anbieter nach Priorität (Apple 0, MLX 10); ist keiner verfügbar, wird das am leichtesten behebbare Problem gezeigt (Modell fehlt / Apple Intelligence aus vor „nicht unterstützt“).
- **Fortschritt** misst `download.py` am Blob-Ordner genau dieses Repos (fertige und `.incomplete`-Dateien), nicht am ganzen Hub-Cache wie VoiceBud; dadurch stimmt die Anzeige auch beim Fortsetzen. `HF_HUB_DISABLE_XET=1` wie VoiceBud.
- **Kleines Standardmodell Qwen3 1.7B statt Qwen3.5 0.8B**: ≤ 1 GB verlangt; laut VoiceBud-Eval ist 1.7B bei Deutsch etwa gleichauf mit Qwen3.5 2B, 0.8B ist schwächer. Ohne Vision-Teil kleiner pro Qualität.
- **Pins**: `mlx==0.32.3`, `mlx-metal==0.32.3`, `mlx-lm==0.32.0`, `huggingface-hub==1.33.0` (gleich wie VoiceBuds funktionierende venv), dazu `requirements.lock` mit allen 34 Paketen (`setup.sh --lock`).
- **`--selftest <präfix>`**: langsame Prüfungen mit echtem Modell sind `onDemand` und laufen nur benannt (`--selftest ai`, `--selftest mlx`).

## Aus VoiceBud übernommen (MIT, Copyright (c) 2026 Anas Riad)

- `llm_worker.py` → `ai-worker/worker.py`: Protokoll-Idee (`started`, Fehlerzeilen), fd-Trick für stdout, Lesethread + `PriorityQueue`, Watchdog mit `os._exit`, `mx.set_cache_limit`/`clear_cache`, Präfix-Cache mit Marker, `_looping`, Chat-Template mit `enable_thinking=False`-Rückfall, Offline-Umgebung.
- `onboarding.py` (Downloads) → `download.py`: Kindprozess mit `snapshot_download`, Gesamtgröße aus `HfApi().model_info(files_metadata=True)`, Polling alle 0,5 s, `HF_HUB_DISABLE_XET`, Phasen; `cleanup.hf_snapshot` → `snapshot_path` / `HubCache.snapshot`.
- `cleanup.Cleaner` → `MLXWorkerClient`: Frist ab `started` mit Warteschlangen-Zuschlag, eigene Kills markieren, eine Wiederholung nach Absturz, Rohrschließen/Ernten nach Leerlauf-Ende, Budgets wachsen mit der Eingabe.
- `tests/fake_llm_worker.py` → `fake_worker.py` (jetzt echter `worker.Worker` mit Attrappen-Backend und Fehler-Flags).
- `ui/Onboarding.swift` `OnboardingModels`/`OnboardingModelRow` → Fußnotenzustände und Zeilenaufbau (über S0bs `ProgressRow`).

## Außerhalb meines Strangs angefasst

- `App/Sources/Kit/Core/Registry.swift`: `SelfTestCheck` bekommt `onDemand: Bool = false` und einen expliziten Init (bestehende Aufrufe unverändert).
- `App/Sources/Kit/Main/SelfTest.swift`: `run(only:)`; ohne Präfix laufen On-Demand-Prüfungen nicht, ein unbekannter Präfix ist ein Fehler.
- `App/Sources/Kit/Main/CommandLine.swift`: `--selftest [präfix]` (`LaunchFlags.selftestOnly`).
- `App/Tests/SelfTestFilterTests.swift` (neu, Tests dazu).
- `scripts/test.sh`: Fehler behoben, der Python-Pfad der venv war nach `cd ai-worker` relativ falsch (`make test` brach mit Code 127 ab, sobald `ai-worker/.venv` existiert).

## Kandidaten für Kit

- `ModelRowView` (`ProgressRow` plus Zustand „noch nicht gestartet“ mit Chip „Herunterladen“): `ProgressRow.Phase` könnte `.notStarted(total:, action)` bekommen.
- `AIWait` (Async-Arbeit aus synchronem Code durch Drehen des Run-Loops) für Selbsttests und Tests anderer Module.
- Ein einzeiliges Eingabefeld im Kit-Look (`AITrialSection.field`, wie `SearchField` ohne Lupe).

## Bekannte Lücken

- **Kein `ai-worker/package.sh`**: Ein DMG mit MLX bräuchte ein eingebettetes Python (python-build-standalone 3.12 wie VoiceBud) samt `site-packages`; nicht gebaut. `MLXPaths` sucht schon `Contents/Resources/ai-worker` und `Contents/Resources/python/bin/python3`. Bis dahin läuft MLX nur in Entwickler-Builds mit `ai-worker/setup.sh`. Strang J/Integration.
- **macOS-Mindestversion**: MLX 0.32 braucht 26.2; das App-Minimum bleibt 26.0. `MLXProvider` meldet auf 26.0/26.1 „macOS zu alt“, statt `LSMinimumSystemVersion` hochzusetzen (VoiceBud leitet es aus den Binaries ab, sobald Python gebündelt wird).
- **Kein `touch`/`keep`/`prefill`** im Protokoll (VoiceBud hat sie für Diktat); keine Einstellung „Modelle im RAM halten“. Kein Lookahead-Decoding, kein Readahead.
- **Download-Anzeige**: Zählt den Blob-Ordner; hat ein Repo Blobs anderer Revisionen, wird auf die Gesamtgröße gekappt. xet ist abgeschaltet; ob spätere `huggingface_hub`-Versionen das noch erlauben, ist offen (gepinnt auf 1.33.0).
- **Lizenz/Speicher**: Lizenz steht im Katalog, wird aber nirgends angezeigt. 8-GB-Macs nicht getestet.
- Interaktiv nicht ausprobiert (Regel §2.17): Eingabefeld, Senden/Stopp, Bestätigungsdialog „Modelle löschen“, Live-Abfrage alle 2 s im offenen Bereich. Der Lead prüft das.
- Die MLX-Tests laufen nur, wenn `mlx` gebaut wird (`MODULES=…,mlx make test`); `make test` mit Standardmodulen überspringt sie. CI sollte eine Kombination mit `mlx` testen.

## Prüfung (2026-10-12)

```
make build                                   -> grün (Standardmodule)
make build MODULES=window | menubar | window,ai | menubar,ai,mlx | alle inkl. mlx  -> grün, je --selftest 0 failures
MODULES=<alle inkl. mlx> CONFIG=release make build -> grün
STARTER_HEADLESS=1 Starter --selftest        -> "9 checks, 0 failures" (Standard), "10 checks" mit mlx
STARTER_HEADLESS=1 Starter --selftest ai     -> 0 failures; Apple antwortet auf Deutsch:
    respond 2,00 s „Die Menüleiste auf dem Mac ist ein Symbol, das …“
    stream 0,49 s „Von eins bis fünf, mit Kommas: eins, zwei, drei, vier, fünf.“
    structured 0,65 s „Notizen-Buddy / Eine einfache Mac-App zur Erstellung und Organisation von Notizen.“
ai-worker/setup.sh                           -> venv mit Python 3.12.15, mlx 0.32.3, mlx-lm 0.32.0, Metal True (38 s, 435 MB)
ai-worker/.venv/bin/python ai-worker/download.py --model small --hf-home …
                                             -> 100 Fortschrittszeilen, done; 984 013 244 Bytes in ca. 15 min (ca. 1 MB/s hier)
worker.py direkt (Qwen3 1.7B)                -> Laden 2,04 s, 224 Token/s, Spitze 1,1 GB
STARTER_DATA_DIR=… Starter --selftest mlx    -> 0 failures; über den Swift-Client:
    kalt 1,61 s (Laden 1,35 s, 25 Token, 235,6 Token/s, 24 Stücke, Spitze 1110 MB)
    „Die Menüleiste auf dem Mac ist für die Ausführung von Menüs und Anwendungen notwendig.“
    warm über MLXProvider.stream 0,05 s; Abbruch nach erstem Stück 0,06 s („cancelled busy=true“); 1 Start, 0 Abstürze;
    danach kein worker.py-Prozess mehr
STARTER_AI_WORKER=… STARTER_DATA_DIR=<leer> Starter --selftest mlx   (Download über ModelDownloads → download.py)
                                             -> mlx.download 0 … 90 % in 10-%-Schritten, done in 515 s, 984 013 244 Bytes;
                                                danach mlx.live wie oben (kalt 1,58 s, Laden 1,32 s, 232 Token/s);
                                                "3 checks, 0 failures", kein Python-Prozess bleibt
make test                                    -> 85 Swift-Tests, 0 failures; Python 11 (scripts) + 22 (ai-worker) OK
MODULES=<alle inkl. mlx> make test           -> 110 Swift-Tests, 0 failures (MLXTests 3x hintereinander grün)
/usr/bin/python3 -m unittest (ai-worker, Python 3.9 ohne MLX) -> 22 Tests OK
make shots ONLY=ai.                          -> 9 Szenen x en/de x hell/dunkel
```

Angesehen (Read): `ai.pane` de-hell, `ai.pane-unavailable` en-dunkel, `ai.onboarding-unavailable` de-hell (gegen VoiceBud `onboarding-06-modelle-light.png`: gleiche Kartenbreite, Zeilen, Fußnote), `ai.onboarding` en-hell, `ai.download-rows` de-dunkel, `ai.pane-mlx` de-hell und de-dunkel, `ai.pane-mlx-setup` de-dunkel und en-hell, `ai.onboarding-mlx` en-dunkel. Danach behoben: doppelter Einrichtungshinweis, „Aktiv“-Plakette an einem nicht verfügbaren Anbieter, „Laden“ → „Herunterladen“, Bereichshöhe = Fensterhöhe.
