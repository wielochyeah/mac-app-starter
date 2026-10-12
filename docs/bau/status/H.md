# Status H (Lokale KI: Module `ai` und `mlx`, `ai-worker/`)

Stand: 2026-10-12, Branch `strang/H`. `mlx` bleibt in `starter.json` aus.

## Was gebaut ist

| Bereich | Dateien |
|---|---|
| Modul `ai` | `App/Sources/Modules/AI/`: `AIModule.swift` (Registrierung, Selbsttests), `LocalAI.swift` (Fassade, `LocalModelProvider`, `AIAvailability`/`AIUnavailableReason`, `AIError`, `ProviderChoice`, `AIUsage`, `AIPaneSection`, Settings-Schlüssel `ai.provider`, `ai.usage`), `AppleOnDeviceProvider.swift` (FoundationModels), `AIViews.swift` (Bereich „Modelle“, Schritt „Lokale KI“, `ModelRowItem`/`ModelRowView`, `AITrial`), `AIScenes.swift` (Szenen, Galerie, Beispielzustände), `AIText.swift`, `AIWait.swift` |
| Modul `mlx` | `App/Sources/Modules/MLX/`: `MLXModule.swift` (Registrierung, Szenen, Selbsttests `mlx.catalog`, `mlx.live`, `download.mlx`), `MLXWorkerClient.swift`, `MLXProvider.swift` (Schlüssel `mlx.model`), `ModelDownloads.swift`, `ModelCatalog.swift` (+ `HubCache`), `WorkerProtocol.swift` (Ereignisse, Anfragen, `RestartPolicy`, `WorkerBudget`, `LineBuffer`), `MLXPaths.swift`, `MLXViews.swift`, `MLXText.swift` |
| Python | `ai-worker/worker.py`, `download.py`, `models.json`, `requirements.txt`, `requirements.lock`, `setup.sh`, `fake_worker.py`, `tests/test_worker.py`, `tests/test_download.py`, `tests/fake_download.py` |
| Tests | `App/Tests/AITests.swift` (21), `App/Tests/MLXTests.swift` (31, nur mit `mlx`), `App/Tests/SelfTestFilterTests.swift` (2); Python 23 Tests |

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
- **`--selftest <präfix>`**: langsame Prüfungen mit echtem Modell sind `onDemand` und laufen nur benannt (`--selftest ai`, `--selftest mlx`). Der Download (`download.mlx`, einzige Prüfung mit Netz) liegt absichtlich außerhalb des Präfixes `mlx` und läuft nur mit `--selftest download.mlx`.
- **Verfügbarkeit wird vor jeder Anfrage neu gelesen** (`LocalAI.prepare`/`structured` rufen `refresh()`); `refresh()` benachrichtigt Beobachter nur bei einer Änderung.
- **Entwickler- und Nutzertexte**: `AIBuild.canSetUpMLX` (Debug-Build und kein Render) entscheidet, ob „ai-worker/setup.sh“ genannt wird. Release-Builds und alle Renders zeigen „Diese Version der App enthält MLX nicht“. Release-Builds suchen Worker und Python nur im eigenen Bundle (`MLXPaths`).

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

- **Kein `ai-worker/package.sh`: `mlx` ist bis dahin nur für Entwickler.** Ein DMG mit MLX bräuchte ein eingebettetes Python (python-build-standalone 3.12 wie VoiceBud) samt `site-packages`; nicht gebaut. `MLXPaths` sucht in Release-Builds nur `Contents/Resources/ai-worker` und `Contents/Resources/python/bin/python3`. Ein Release-Build mit `mlx` zeigt MLX deshalb als „Nicht enthalten“ ohne Download-Knöpfe. Wer `mlx` ausliefern will, muss erst das Bündeln bauen (Strang J/Integration).
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
make test                                    -> 85 Swift-Tests (vor dem Review), 0 failures; Python 11 (scripts) + 22 (ai-worker) OK
MODULES=<alle inkl. mlx> make test           -> 110 Swift-Tests, 0 failures (MLXTests 3x hintereinander grün)
/usr/bin/python3 -m unittest (ai-worker, Python 3.9 ohne MLX) -> 22 Tests OK
make shots ONLY=ai.                          -> 9 Szenen x en/de x hell/dunkel
```

Angesehen (Read): `ai.pane` de-hell, `ai.pane-unavailable` en-dunkel, `ai.onboarding-unavailable` de-hell (gegen VoiceBud `onboarding-06-modelle-light.png`: gleiche Kartenbreite, Zeilen, Fußnote), `ai.onboarding` en-hell, `ai.download-rows` de-dunkel, `ai.pane-mlx` de-hell und de-dunkel, `ai.pane-mlx-setup` de-dunkel und en-hell, `ai.onboarding-mlx` en-dunkel. Danach behoben: doppelter Einrichtungshinweis, „Aktiv“-Plakette an einem nicht verfügbaren Anbieter, „Laden“ → „Herunterladen“, Bereichshöhe = Fensterhöhe.

## Review (2026-10-12)

Befunde aus `review/H-correctness` und `review/H-design`. Alle waren echt; behoben bis auf die unten genannten.

| # | Befund | Ergebnis |
|---|---|---|
| 1 | Verfügbarkeit nur beim Start bzw. im offenen Bereich gelesen | Behoben (`00d93eb`): `prepare()` und `structured()` rufen `refresh()`; Tests „a request re-reads availability…“, „automatic falls back as soon as…“ |
| 2 | `MLXProvider.stream` klebt nach der Absturz-Wiederholung zwei Antworten zusammen | Behoben (`4127330`): `generate(onRestart:)`, der Stream setzt den Text zurück und liefert „“; `fake_worker.py --crash-after N --marker P`; Test „a crash mid-answer…“ (schlägt ohne die Korrektur mit dem Klebetext fehl) |
| 3, 13, 17 | Download-Knöpfe ohne eingerichtetes MLX, Entwickleranweisung als App-Text | Behoben (`6835f43`): ohne Einrichtung keine Chips, kein „Erneut versuchen“, keine Zeile im Schritt; Problem „setup“ ist kein Fehlschlag; Nutzertext „Diese Version der App enthält MLX nicht“, setup.sh nur im Debug-Build; Doku: `mlx` ist bis `package.sh` nur für Entwickler |
| 4 | Ausprobieren: Zeit nach Stopp, alter Lauf überschreibt neuen | Behoben (`d21c0f7`): Lauf-Nummer, abgebrochene Tasks schreiben nichts; Test dazu |
| 5 | Löschen während des Downloads hinterlässt „Pausiert“ | Behoben (`7ad0889`): gelöschte Downloads werden ignoriert, Ordner nach Prozessende erneut entfernt; Test dazu |
| 6 | Mehrteiliges Modell gilt nach der ersten Datei als fertig | Behoben (`ba3f9ab`): `model.safetensors.index.json` → jede Datei aus `weight_map` muss da sein (Swift und `download.py`); Tests in beiden |
| 7 | `refresh()` benachrichtigt alle 2 s ohne Änderung | Behoben (`00d93eb`): `revision` nur bei Änderung; Test mit `withObservationTracking` |
| 8, 19 | „unten“ im Schritt; „laden“ für Herunterladen | Behoben (`6835f43`): eigener Schritttext „Starte oben den Download…“; überall herunterladen/heruntergeladen |
| 9, 20 | Reservierte leere Fußnotenzeile unter MLX | Behoben (`6835f43`): `footnoteLines` weg; Abstände jetzt gleich (gemessen in `ai.pane-mlx` de-dunkel) |
| 10 | `--selftest mlx` startet still 1 GB Download | Behoben (`d8dff0d`): Prüfung heißt `download.mlx` |
| 11, 24 | Ungenutzte Texte, falsche Beschriftung bei „macOS zu alt“ | Behoben (`6835f43`, `d21c0f7`): `status`, `queued`, `stepLater` entfernt; `softwareUpdate` für `.systemTooOld` (Knopf und Link); `tryPlaceholder` ist der echte Platzhalter, das Feld startet mit der Beispielfrage statt sie heimlich zu senden; `MLXSectionModel.installed` wird benutzt |
| 12 (Pfade) | Release-Build sucht Python in Elternordnern und per Umgebung | Behoben (`1f15dde`): nur im Debug-Build |
| 12, 28 (Texte) | Pfeile und Plan-Verweis in Kommentaren | Behoben (`6835f43`, `7ad0889`); `check_texts.py --streng` (G1) auf AI, MLX, ai-worker: keine Befunde. Der „--“-Fehlalarm (Ordner `models--org--name`) ist durch `<org>--<name>` im Kommentar umgangen; als Regel-Fehlalarm an Strang G zu melden |
| 14 | „später einschalten“ bei Zuständen ohne Schalter | Behoben (`6835f43`): eigener Folgesatz je Grund (bereitet vor: „Du kannst schon weitergehen…“, nicht unterstützt: keiner); Test „hints promise only what exists“ |
| 15 | MLX empfohlen, obwohl nicht im Build | Behoben: „Textfunktionen sind auf diesem Mac nicht verfügbar.“; Hinweis auf einen anderen Anbieter nur, wenn einer helfen kann (`AIPaneModel.hasAlternative`) |
| 16 | „Modell später wechseln“ ohne Auswahl | Behoben: `stepReady(canSwitch:)`, sonst „Den Stand siehst du jederzeit in den Einstellungen unter Modelle.“ |
| 18 | Warnung für Zustände ohne Handlung; drei Namen für „nicht bereit“ | Behoben: `.info` für vorbereiten/nicht unterstützt (`needsAction`); Titel „macOS bereitet das Modell vor“, Status „Wird vorbereitet“ |
| 21 | Textspalten von Anbieter- und Modellzeilen 4 pt versetzt; Fußnote unter der Downloadkarte | Nicht behoben: `Row` (Kit, Symbol 24 pt fest) und `ProgressRow` (Kit S0b, `Metrics.progressIcon` 28 pt) liegen außerhalb des Strangs. Kit-Kandidat: eine gemeinsame Symbolgröße oder ein `iconSize`-Parameter für `Row`. Die Fußnote nennt ihr Thema jetzt selbst (z. B. „Schalte Apple Intelligence…“, „Starte oben den Download…“) |
| 22 | Beispielzeilen und Nutzung widersprechen dem echten UI | Behoben: Beispielzeilen wie die echten (`scope`, „Qwen3.5 4B, 4-Bit“ über `AIText.modelName`); Nutzung im MLX-Render = Antwort im Ausprobieren; voller Anbietername an beiden Stellen; MLX-Szenen berechnen den aktiven Anbieter über `ProviderChoice` |
| 23 | Holprige Formulierungen | Behoben: „wurde unerwartet beendet“, „im Betrieb“, „Gespeichert werden nur…“, „kleines Fenster“, Komma-Satz im Englischen, konkreter Hinweis bei `.unknown` |
| 25 | Totes Ausprobieren und Nutzung voller Nullen | Behoben: Ausprobieren nur, wenn ein Anbieter antworten kann (oder eine Antwort läuft/da ist), Nutzung nur bei Verfügbarkeit oder gezählten Anfragen |
| 26 | Fehlende Szenen | Behoben: `ai.pane-trying`, `ai.pane-error`, `ai.pane-ineligible`, `ai.onboarding-not-ready`, `ai.onboarding-ineligible`, `ai.pane-mlx-offline`, `ai.pane-mlx-too-old`, `ai.onboarding-mlx-missing`, `ai.onboarding-mlx-setup`. Nicht als Szene: die Löschbestätigung (`confirmationDialog` des Systems zeichnet offscreen nicht) |
| 27 | „Modelle löschen“ während eines Downloads | Behoben (`7ad0889`): Knopf deaktiviert, solange ein Download läuft oder wartet |

Zusätzlich: `--selftest ai` war wackelig („Zähle bis fünf“ kam manchmal in einem Stück); jetzt „bis zwanzig in Worten“ (`test(ai)`-Commit).

### Prüfung nach dem Review

```
make build (Standard) und MODULES=window | menubar | window,ai | menubar,ai,mlx | alle inkl. mlx -> grün;
    --selftest: 9 / 8 / 8 / 9 / 10 / 10 checks, 0 failures
MODULES=<alle inkl. mlx> CONFIG=release make build -> grün; --selftest 10 checks, 0 failures
make test                                    -> 90 Swift-Tests, 0 failures; Python 11 + 23 OK
MODULES=<alle inkl. mlx> make test           -> 121 Swift-Tests, 0 failures (3x hintereinander)
/usr/bin/python3 -m unittest (ai-worker)     -> 23 OK; ai-worker/.venv Python 3.12 -> 23 OK
make check                                   -> grün (5x); Skripte von G/K fehlen in diesem Worktree noch (übersprungen)
check_texts.py --streng / check_design.py (G1-Stand, review/H-correctness/combo) auf AI, MLX, ai-worker -> keine Befunde
STARTER_HEADLESS=1 Starter --selftest ai     -> 0 failures (4x): respond 1,4 s, stream 6–8 Stücke ~1 s, structured 0,6–0,8 s
STARTER_DATA_DIR=$SCRATCH/mlx-data Starter --selftest mlx
                                             -> 2 checks, 0 failures: kalt 1,59 s (Laden 1,32 s, 183 Token/s, Spitze 1107 MB),
                                                warm 0,05 s, Abbruch 0,05 s, 1 Start, 0 Abstürze; kein Download gestartet
Starter --selftest download.mlx (Modell vorhanden) -> "already on disk", kein Netz
danach: kein worker.py / download.py / Fake-Prozess übrig
ONLY=ai. scripts/render.sh (Standard und mit mlx) -> 18 Szenen x en/de x hell/dunkel
```

Angesehen (Read): `ai.pane-mlx-setup` de-hell, `ai.pane-mlx` de-dunkel, `ai.onboarding-mlx-missing` de-hell, `ai.onboarding-not-ready` en-dunkel und de-hell (danach Text mit eigenem Subjekt), `ai.pane-not-ready` en-dunkel, `ai.pane-trying` en-hell, `ai.pane-error` de-dunkel, `ai.pane-mlx-too-old` en-hell, `ai.onboarding-mlx-setup` de-dunkel, `ai.download-rows` en-hell, `ai.onboarding` de-hell, `ai.pane-mlx-offline` en-dunkel.

Beobachtet, nicht aus diesem Strang: `ObservingTests/track calls onChange on every change` (Kit, S0) scheitert, wenn vier Testläufe parallel laufen (Zeitabhängigkeit); einzeln grün.
