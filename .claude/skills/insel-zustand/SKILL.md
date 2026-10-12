---
name: insel-zustand
description: Zeigt eine Rückmeldung der App in der Insel an der Notch oder in der Kapsel unter der Menüleiste (IslandContent, present, update, dismiss, Fortschritt mit Abbruch, Ergebniskarte, Hinweis, Render-Szenen für Insel und Kapsel). Nutzen, wenn eine Funktion kurz und sichtbar melden soll, was gerade passiert. Gehört zum Modul island.
---

# Zustand in der Insel

Gehört zum Modul `island`; `bin/starter remove island` entfernt diesen Skill mit dem Modul. Code außerhalb von `App/Sources/Modules/Island/`, der die Insel nutzt, steht in `#if MODUL_ISLAND` … `#endif`.

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Insel | `App/Sources/Modules/Island/` | `Island.shared.present(_:)`, `update(_:)`, `dismiss()`, `isPresenting` |
| Inhalt | `IslandContent` | `.activity(symbol:title:detail:tint:)`, `.progress(title:fraction:…)` mit Sekundenzähler ab 5 s und Abbruchhinweis ab 10 s, `.levels([Float])` als Pegel, `.done(title:detail:body:actions:)` als Karte mit Aufklappen und Kopieren, `.notice(text:kind:)` mit `info`, `warning`, `error`, verschwindet nach 2,5 s |
| Darstellung | Einstellung `island.style` | `auto` (Insel mit Notch, Kapsel ohne), `island`, `capsule`; mehrere Bildschirme, Selbstheilung nach Bildschirmwechsel |
| Tokens | `App/Sources/Kit/Design/Island.swift` | `IslandPalette`, `IslandAccent`, `Radius.Island`, `Metrics.Island`, `Motion.Island` |

## Schritte

1. Passt die Insel? Sie meldet kurz, was die App gerade tut oder getan hat. Lange Texte, Formulare und Entscheidungen gehören in ein Fenster.
2. Den passenden Inhalt wählen: Tätigkeit ohne bekanntes Ende `.activity`, messbarer Fortschritt `.progress`, Ergebnis mit Text zum Kopieren `.done`, kurzer Hinweis `.notice`.
3. Anzeigen und fortschreiben:

   ```swift
   #if MODUL_ISLAND
   Island.shared.present(.progress(title: ExportText.running, fraction: 0))
   Island.shared.update(.progress(title: ExportText.running, fraction: 0.6))
   Island.shared.present(.done(title: ExportText.done, detail: ExportText.files(3), body: nil, actions: []))
   #endif
   ```

   Ein abgebrochener oder fehlgeschlagener Ablauf endet mit `.notice(text:kind: .error)` oder `dismiss()`, nie mit einer stehenbleibenden Insel.
4. Titel höchstens drei Wörter, Detail eine kurze Zeile; beide Sprachen passen in die Breite der Insel (Deutsch zuerst prüfen).
5. Töne sind standardmäßig aus; die Insel respektiert reduzierte Bewegung selbst.
6. Render-Szenen für jeden neuen Zustand in beiden Formen: `island.<feature>-<zustand>` und `capsule.<feature>-<zustand>` auf der Menüleisten-Kulisse des Moduls.

## Prüfen

- `make check`, `make build MODULES=window,island` und `make build MODULES=window` (ohne Insel muss der Code weiter bauen).
- `make shots ONLY=island.` und `make shots ONLY=capsule.`, alle vier Fassungen jeder Szene mit dem Werkzeug Read ansehen.
- Die echte Insel an einer Notch und die Kapsel auf einem Bildschirm ohne Notch sind nur in der laufenden App prüfbar (`--demo island` durchläuft alle Zustände); das bleibt eine Abnahme der Integration und steht bis dahin unter „Bekannte Schwächen“.
