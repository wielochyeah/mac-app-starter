---
name: insel-zustand
description: Zeigt eine Rückmeldung der App in der Insel an der Notch oder in der Kapsel unter der Menüleiste (IslandContent, present, update, dismiss, Fortschritt mit Abbruch, Ergebniskarte, Hinweis, Render-Szenen für Insel und Kapsel). Nutzen, wenn eine Funktion kurz und sichtbar melden soll, was gerade passiert. Gehört zum Modul island.
---

# Zustand in der Insel

Gehört zum Modul `island`; `bin/starter remove island` entfernt diesen Skill mit dem Modul. Code außerhalb von `App/Sources/Modules/Island/`, der die Insel nutzt, steht in `#if MODUL_ISLAND` … `#endif`.

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Insel | `App/Sources/Modules/Island/` | `Island.shared.present(_:)`, `update(_:)`, `dismiss()`, `isPresenting`, `notchBusy` |
| Inhalt | `IslandContent` | `.activity(symbol:title:detail:tint:)`, `.progress(title:fraction:…)` mit Sekundenzähler ab 5 s und Abbruchhinweis ab 10 s, `.levels(_:symbol:tint:recording:)` als Pegel (Bänder 0 bis 1; `recording: true` zeigt den roten Aufnahmepunkt, in der Kapsel dazu die Zeit seit `present`; nur für Apps, die wirklich Mikrofon oder Bildschirm aufnehmen), `.done(title:detail:body:actions:tint:)` als Karte mit Aufklappen und Kopieren, `.notice(text:kind:)` mit `info`, `success`, `warning`, `error`, verschwindet nach 2,5 s |
| Darstellung | Einstellung `island.style` | `auto` (Insel mit Notch, Kapsel ohne), `island`, `capsule`; mehrere Bildschirme, Selbstheilung nach Bildschirmwechsel. `Island.shared.notchBusy` (`(() -> Bool)?`, Standard nil) meldet, dass gerade eine andere App die Notch belegt: dann erscheint eine neue Anzeige mit `auto` als Kapsel direkt unter der Notch (entschieden je `present`, nie mittendrin). Ohne `notchBusy` verhält sich `auto` wie `island`, und die Einstellungen bieten nur Automatisch und Kapsel |
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

   Pegel live: einmal `Island.shared.present(.levels([], symbol: "mic.fill", recording: true))`, danach je Messung `Island.shared.update(.levels(bands, symbol: "mic.fill", recording: true))` mit gleichem `symbol`, `tint` und `recording`; nur dann tauscht die Insel allein die Bänder ohne neues Zeichnen. Den Aufnahmepunkt setzt nur dieser Inhalt, nicht `Island` oder das Modell. Belegte Notch: Weiß das Projekt, wann eine andere App die Notch nutzt, setzt es beim Start (im `register()` oder in `Registry.launchHooks`, in `#if MODUL_ISLAND`) `Island.shared.notchBusy = { NotchWatcher.shared.isBusy }`; der Starter selbst erkennt keine anderen Notch-Apps.
4. Titel höchstens drei Wörter, Detail eine kurze Zeile; beide Sprachen passen in die Breite der Insel (Deutsch zuerst prüfen). Eine Ergebniskarte `.done` mit `body` hat ihren Kopieren-Knopf schon (aufgeklappt beim Überfahren); eine eigene Aktion „Kopieren“ käme doppelt. Nur wenn „Beim Überfahren ausklappen“ aus ist (`Settings.shared[.islandHoverExpand] == false`), zeigt die Karte gefaltet allein ihre `actions`; dann gehört „Kopieren“ dazu.
5. Töne sind standardmäßig aus; die Insel respektiert reduzierte Bewegung selbst.
6. Render-Szenen für jeden neuen Zustand in beiden Formen: `<feature>.island-<zustand>` und `<feature>.capsule-<zustand>` auf der Menüleisten-Kulisse des Moduls. Die Kulisse baut `IslandScenes.stage(_:kind:)` aus einem `IslandScenes.Sample` (Inhalt, Bildausschnitt, Zustand des Modells):

   ```swift
   #if MODUL_ISLAND
   let sample = IslandScenes.Sample(id: "", content: { .progress(title: ExportText.running) }) {
       $0.slowSince = Date(timeIntervalSinceNow: -12)   // Sekundenzähler läuft
       $0.slowHint = true                               // Karte „Dauert länger“ mit Abbrechen
   }
   Registry.renderScenes.append(RenderScene(id: "export.island-slow", size: sample.crop) { IslandScenes.stage(sample, kind: .notch) })
   Registry.renderScenes.append(RenderScene(id: "export.capsule-slow", size: sample.crop) { IslandScenes.stage(sample, kind: .capsule) })
   #endif
   ```

   Aufgeklappte Ergebniskarten brauchen den größeren Ausschnitt und `hover`: `IslandScenes.Sample(id: "", crop: IslandLook.hoverCrop, content: { … }) { $0.hover = .expanded }`. Den Inhalt im `content`-Block bauen, nicht vorher: so steht er in der Sprache des jeweiligen Renders.

## Prüfen

- `make check`, `make build MODULES=window,island` und `make build MODULES=window` (ohne Insel muss der Code weiter bauen).
- `make shots ONLY=<feature>.` (eigene Zustände) und `make shots ONLY=island.` (Zustände des Moduls), alle vier Fassungen jeder Szene mit dem Werkzeug Read ansehen.
- Die echte Insel an einer Notch und die Kapsel auf einem Bildschirm ohne Notch sind nur in der laufenden App prüfbar (`--demo island` durchläuft alle Zustände); das bleibt eine Abnahme der Integration und steht bis dahin unter „Bekannte Schwächen“.
