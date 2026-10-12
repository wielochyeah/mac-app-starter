---
name: ki-funktion
description: Baut eine Funktion mit lokaler KI (LocalAI.respond, stream, structured mit DynamicGenerationSchema, Verfügbarkeit mit ehrlichem Aus-Zustand, Abbruch, keine Protokollierung von Inhalten). Nutzen, wenn ein Sprachmodell auf dem Mac Text zusammenfassen, umschreiben, einordnen oder Daten aus Text ziehen soll. Gehört zum Modul ai.
---

# KI-Funktion

Gehört zum Modul `ai`; `bin/starter remove ai` entfernt diesen Skill mit dem Modul. Code außerhalb von `App/Sources/Modules/AI/`, der KI nutzt, steht in `#if MODUL_AI` … `#endif`. Hintergrund und Datenschutzversprechen stehen in `docs/KI.md`.

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Fassade | `App/Sources/Modules/AI/` | `LocalAI.availability`, `respond(prompt:instructions:) async throws -> String`, `stream(prompt:instructions:) -> AsyncThrowingStream<String, Error>`, `structured(prompt:schema:)`, Abbruch über die `Task` |
| Anbieter | `LocalModelProvider` | `AppleOnDeviceProvider` (Apple Foundation Models, Standard, ohne Download); `MLXProvider` mit Modul `mlx` | <!-- modul:mlx -->
| Einstellungen | Bereich „Modelle“, Einstellung für den Anbieter | Verfügbarkeit mit Hinweis, wie sie sich herstellen lässt, Testfeld mit gestreamter Antwort |
| Downloads | `ModelDownloads`, `ai-worker/models.json` | Modelle mit Größe, Fortschritt, Pause und erneutem Versuch; nur auf Auslösen der Nutzerin | <!-- modul:mlx -->

## Schritte

1. Ohne KI muss die App weiter funktionieren: die Funktion zeigt ohne Verfügbarkeit einen klaren Aus-Zustand mit Grund (Apple Intelligence aus, Gerät nicht geeignet, Modell nicht geladen) und, wo möglich, den Weg zur Lösung.
2. Anweisungen (`instructions`) kurz und fest im Code, in der Sprache der Oberfläche (`Localizer.shared.lang`); der Text der Nutzerin geht nur als `prompt` hinein. Anweisungen im Text der Nutzerin ändern die Regeln nicht.
3. Strukturierte Ergebnisse über `DynamicGenerationSchema`, nie über `@Generable` (das Makro fehlt ohne Xcode). Antworten gegen das Schema prüfen; was nicht passt, wird verworfen und nicht gezeigt.
4. Lange Antworten streamen und abbrechbar machen; Abbruch beendet die Erzeugung, nicht nur die Anzeige.
5. Weder Prompt noch Antwort landen in `Log`, in Dateien oder in Fehlermeldungen. Gespeichert wird nur, was die Funktion ausdrücklich als Ergebnis speichert.
6. Texte, die die App in eigener Stimme zeigt, folgen den Schreibregeln; umgeschriebener Text der Nutzerin bleibt ihr Text.
7. Tests: Logik um das Modell herum mit einem eingespeisten Anbieter (`LocalModelProvider`-Testdouble), nie mit dem echten Modell im Test. Ein Selbsttest `--selftest ai` darf das echte Modell ohne Fenster fragen.
8. Render-Szenen für die Zustände der Funktion: verfügbar, nicht verfügbar mit Grund, Antwort läuft, Fehler.
9. Eigenes Modell über MLX: Modul `mlx` in `starter.json` einschalten, Modell in `ai-worker/models.json` eintragen (Name, Hugging-Face-Adresse, Größe), `ai-worker/setup.sh` richtet die Umgebung ein. <!-- modul:mlx -->

## Prüfen

- `make check`, `make build MODULES=window,ai` und `make build MODULES=window` (ohne KI muss alles bauen).
- `STARTER_HEADLESS=1 build/<Name>.app/Contents/MacOS/<Name> --selftest ai` fragt das Apple-Modell ohne Fenster.
- `make shots ONLY=ai.` und die eigenen Szenen in allen vier Fassungen ansehen.
- Gegenprüfung mit dem Skill `red-team`, Blickwinkel Sicherheit (Netz, Protokoll, Downloads).
