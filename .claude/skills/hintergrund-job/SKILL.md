---
name: hintergrund-job
description: Legt eine geplante Aufgabe an, die die App im Hintergrund regelmäßig ausführt (BackgroundJobs.shared.register mit Intervall, Toleranz und Ergebnis, Schalter je Aufgabe, Jetzt ausführen, Start beim Anmelden). Nutzen, wenn etwas ohne Zutun der Nutzerin wiederholt laufen soll. Gehört zum Modul background.
---

# Hintergrund-Aufgabe

Gehört zum Modul `background`; `bin/starter remove background` entfernt diesen Skill mit dem Modul. Code außerhalb von `App/Sources/Modules/Background/`, der Aufgaben anmeldet, steht in `#if MODUL_BACKGROUND` … `#endif`.

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Aufgaben | `App/Sources/Modules/Background/BackgroundJobs.swift` | `BackgroundJobs.shared.register(id:title:interval:tolerance:qos:exact:run:)` mit `run: @Sendable () async throws -> JobOutcome` (`.done(note:)`, `.nothingToDo`, `.failed(_:)`), `runNow(_:)`, letzter Lauf, Ergebnis und Dauer werden gespeichert, Schalter je Aufgabe |
| Anmeldeobjekt | `LoginItem` | `SMAppService.mainApp`; nur verfügbar, wenn die App aus einem installierten Ort läuft, nicht aus `build/` |
| Einstellungen | Bereich „Hintergrund“ | Anmeldeobjekt, Liste der Aufgaben mit letztem Lauf, Ergebnis, Schalter und „Jetzt ausführen“ |
| Onboarding | Schritt „Mit dem Mac starten“ (order 900) | nur, wenn `LoginItem.isAvailable` |

## Schritte

1. Passt eine geplante Aufgabe? Sie läuft im Abstand von Minuten oder Stunden, darf sich um die Toleranz verschieben und darf ausfallen, wenn der Mac schläft. Was sofort auf ein Ereignis reagieren muss, gehört nicht hierher.
2. Anmelden im `register()` des Features:

   ```swift
   #if MODUL_BACKGROUND
   BackgroundJobs.shared.register(id: "cleanup.cache", title: { CleanupText.jobTitle }, interval: 6 * 3600,
                                  tolerance: 1800, qos: .utility) {
       let removed = try await CacheCleaner.run()                  // nonisolated: läuft nicht auf dem Hauptthread
       guard removed > 0 else { return .nothingToDo }
       return .done(note: await CleanupText.removed(removed))      // Texte gehören dem MainActor
   }
   #endif
   ```

   Die Arbeit läuft außerhalb des MainActors: der Typ, der sie erledigt, ist `nonisolated` (sonst legt `-default-isolation MainActor` sie doch auf den Hauptthread), Texte holt `await` vom MainActor. Sie ist abbrechbar (`Task.checkCancellation()`) und schreibt Ergebnisse atomar. Kein Netz, außer die Nutzerin hat es für genau diese Aufgabe eingeschaltet.
3. Ergebnis ehrlich melden: `.done(note:)` mit kurzem Detail, `.nothingToDo`, wenn es nichts zu tun gab, `.failed(_:)` (oder ein geworfener Fehler) mit Grund in Alltagssprache. Nutzerinhalte stehen nie im Protokoll.
4. Kennung mit Präfix des Features, Titel als Tätigkeit (`Cache aufräumen`).
5. Tests: die Logik der Aufgabe für sich, mit eingespeister Uhr und temporärem Ordner; nie auf den echten Planer warten.
6. Render-Szenen: der Bereich `background.pane` zeigt die Aufgaben mit Beispieldaten; neue Zustände bekommen eine eigene Szene.

## Prüfen

- `make check`, `make build MODULES=menubar,background` und mit allen Modulen.
- `make shots ONLY=background.` und alle vier Fassungen mit dem Werkzeug Read ansehen.
- Beim Bauen nie ein Anmeldeobjekt registrieren. Ob die Aufgabe nach dem Anmelden startet, prüft die installierte App aus dem DMG (`docs/VERTEILUNG.md`).
