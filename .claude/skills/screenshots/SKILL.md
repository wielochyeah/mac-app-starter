---
name: screenshots
description: Rendert jede Szene der App ohne Fenster auf dem Bildschirm in Englisch und Deutsch, hell und dunkel (make shots), und zeigt, wie die Bilder angesehen werden und wie Bilder für das README entstehen. Nutzen nach jeder sichtbaren Änderung, bevor eine Ansicht als fertig gilt.
---

# Screenshots

## Verträge und Dateien

| Datei | Rolle |
|---|---|
| `scripts/render.sh` | gestartet mit `make shots`; baut die App und ruft sie mit `--render` unter `STARTER_HEADLESS=1` auf |
| `App/Sources/Kit/Render/RenderRunner.swift` | rendert jede `RenderScene` aus `Registry.renderScenes` über `NSHostingView.cacheDisplay` mit Faktor 2 |
| `App/Sources/Kit/Core/Registry.swift` | `RenderScene(id:size:content:)`, Kennung `<bereich>.<name>`, `size: .zero` für die passende Größe |
| `App/Sources/Kit/Core/RenderMode.swift` | `RenderMode.isStatic` beim Rendern: Glas wird zu einer Fläche in Token-Farbe, Bewegung steht still, Scrollen ist aus |
| `docs/screenshots/list.txt` | ausgewählte Bilder für das README, je Zeile `<sprache>-<erscheinung>/<szene>.png`, `tools/icon.png` oder `tools/dmg.png` |
| `scripts/readme-shots.sh` | gestartet mit `make readme-shots`; kopiert und verkleinert die Auswahl nach `docs/screenshots/` |

## Aufruf

```bash
make shots                                  # alles: build/shots/<sprache>-<erscheinung>/<szene>.png und build/shots/index.html
make shots ONLY=onboarding.                 # nur Szenen, deren Kennung so beginnt
make shots ONLY=settings. SHOTS_LANG=de     # nur Deutsch
make shots ONLY=design. SHOTS_APPEARANCE=dark   # nur dunkel
NO_BUILD=1 make shots ONLY=onboarding.      # vorhandenen Build nutzen
make readme-shots                           # Bilder aus docs/screenshots/list.txt nach docs/screenshots/, höchstens 1200 px breit
```

Es öffnet sich kein Fenster, es bleibt kein Prozess zurück, es wird keine Berechtigung angefragt. Daten liegen dabei unter `build/render-data`, nie unter `~/Library`.

`build/shots/index.html` zeigt alle Bilder als Übersicht, zuerst die Szenen des Projekts, danach die Muster des Starters; zum Prüfen zählen die einzelnen PNGs.

Muster und eigene Konfiguration: Die Szenen des Kits und der Module (`onboarding.*`, `settings.*`, `menubar.*`, `island.*` …) zeigen Beispieldaten, etwa drei Beispiel-Berechtigungen und Beispielkarten in der Einrichtung. Wie das Projekt selbst aussieht, zeigen die Szenen mit der Endung `.project`: `onboarding.project` (jeder Schritt der echten Einrichtung mit den Berechtigungen aus `starter.json`, den eigenen Funktionskarten und den Schritten der Module) und `menubar.project` (das Statusmenü mit den eigenen Abschnitten und Menüeinträgen). Urteile über das Projekt stützen sich auf diese Szenen und die Szenen der eigenen Funktionen.

## Ansehen

Jede betroffene Szene in allen vier Fassungen (`en-light`, `en-dark`, `de-light`, `de-dark`) mit dem Werkzeug Read öffnen. Code lesen ersetzt kein Bild; ohne Bilder gilt die Ansicht als nicht geprüft.

- Fünf Sekunden: Was ist das, was ist die Antwort, was ist die eine Hauptaktion?
- Deutsch passt ohne Kürzung und ohne umgebrochene Tasten.
- Hell und dunkel sind beide gestaltet, Kontrast reicht, Akzent nur auf Bedienelementen und Auswahl.
- Raster und Kanten: gleiche Abstände, gemeinsame linke Kante, Haarlinien zwischen Zeilen.
- Nichts doppelt, kein Kasten im Kasten, keine Deko ohne Aufgabe.

Befunde gehören in die Statusdatei (Abschnitt „Beweise“: welche Szenen angesehen wurden). Bilder aus `build/` kommen nie ins Repository; nur die Auswahl in `docs/screenshots/` über `make readme-shots` (`scripts/readme-shots.sh`): je Zeile von `list.txt` eine Szene `<sprache>-<erscheinung>/<szene>.png` aus `build/shots`, dazu `tools/icon.png` und `tools/dmg.png`, die die Werkzeuge in `tools/` zeichnen. Breitere Bilder verkleinert `sips` auf 1200 px (`README_MAX_WIDTH`), damit das Repository klein bleibt; jedes gewählte Bild vorher mit Read ansehen.

## Grenzen

Glas, echte Fensterrahmen, die Insel an der echten Notch, Systemdialoge und Menüs von AppKit erscheinen in Renders nur als Stellvertreter. Was davon abhängt, wird zusätzlich in der laufenden App geprüft (`make run`), auf einem Mac mit und einem ohne Notch.
