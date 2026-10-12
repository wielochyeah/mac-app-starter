# Status E (Einstellungsfenster, Galerie, Über)

Stand: 2026-10-12, Branch `strang/E` (Worktree `wt/E`), auf `main` 68281d5. Die Stubs von S0 in `Kit/Settings` und `Kit/Gallery` sind ersetzt; `SettingsKit.register()` und `GalleryKit.register()` heißen weiter so.

## Was gebaut ist

**Einstellungsfenster** (VoiceBud `HubController`/`HubRootView`/`HubSidebar`/`HubStaticWindow`, Notizen vb-onboarding-hub §3.1–3.2)

- `SettingsController`: öffnet das Fenster über `WindowHost` (900 x 620, min 760 x 500, leere Unified-Toolbar für das 52-pt-Band, Frame-Autosave mit Freigabe beim Schließen, Views werden beim Schließen freigegeben, accessory ↔ regular über `AppForm`). Dazu: gewünschter Bereich wird gewählt, lokaler Tastenmonitor (⌘F immer; ⌘W, ⌘, und ⌘X/C/V/A/Z nur ohne Hauptmenü), Fokus geht beim Schließen an die vorherige App zurück (nur bei Accessory-Apps ohne weitere Kit-Fenster), `malloc_zone_pressure_relief` 0,5 s nach dem Schließen. Headless: wählt nur den Bereich, öffnet kein Fenster.
- `SettingsHub` (`@Observable`): gewählter Bereich, zuletzt gewählter Bereich in `kit.settingsPane`, Deep Links, ↑/↓, ⌘F-Anfrage (`searchRequest`). Reine Regeln: `resolve` (gewünscht → aktuell → General → erster), `step` (an den Enden begrenzt), `groups`, `showsLabel`.
- `SettingsRootView`: `NavigationSplitView` (Seitenleiste 200/224/280, `.balanced`, ohne Sidebar-Knopf), Detail unter das Titelband gezogen. `SettingsSidebar`: 34-pt-Einträge mit Verlaufs-Squircle 22, Titel 13, Zähler (`CountBadge`), Auswahl springt per `matchedGeometryEffect` (`Motion.selection`, Reduce Motion beachtet), Gruppenlabel nur über der Einstellungsgruppe und nur wenn Inhaltsbereiche darüber stehen, Fußzeile, fokussierbar mit ↑/↓. `SettingsStaticWindow`: dasselbe Fenster ohne `NavigationSplitView` für Renders, mit der schwebenden macOS-26-Seitenleiste (Panel 18, Einzug 8, Schatten).
- `SettingsHubExtras`: `counts[paneId]` (Zähler neben Einträgen) und `sidebarFooter` (Standard: grüner Punkt „Alles lokal und offline / Nichts verlässt deinen Mac“, Projekte mit Netzwerk ersetzen oder entfernen ihn). `\.settingsHub` in der Umgebung für Bereiche im Fenster.

**Bereiche des Kits**

- „Allgemein“ (`general`, Einstellungsgruppe, order 0): Sprache der App (System / Deutsch / English, live über `Localizer.choice`, Fußnote erklärt „System“), Erscheinungsbild (System / Hell / Dunkel, appweit über `NSApp.appearance`, Schlüssel `app.appearance`, beim Start per Launch-Hook angewendet), „Neu beginnen“: Einrichtung erneut zeigen (nur wenn `AppActions.onboardingHandler` gesetzt ist) und Einstellungen zurücksetzen mit Bestätigung an Ort und Stelle (statt Alert, damit der Zustand renderbar ist; ein Primärknopf, Esc/↩ wirken). Zurücksetzen entfernt alle Schlüssel außer `onboarding.*`, setzt Sprache auf System und wendet das Erscheinungsbild neu an; danach 2,4 s „Auf Standard zurückgesetzt“.
- „Über“ (`about`, order 1000): App-Icon (aus dem Bundle, sonst Squircle 96 mit `app.symbol`), Name, „Version x (Build)“, Copyright; „Wenn etwas nicht klappt“: Versionsangaben kopieren („Starter 1.0.0 (1), macOS 26.0.1, arm64“, Chip zeigt 1,4 s „Kopiert“), Datenordner mit Pfad (Home als `~`) und „Im Finder zeigen“; „Links“ aus `starter.json app.links`; „Rechtliches“: `THIRD_PARTY_NOTICES.md` in einem Sheet, wenn gebündelt (eigener kleiner Markdown-Leser: Titel, Überschriften, Absätze, Aufzählung, Linie; Lizenztext bleibt wörtlich).
- „Galerie“ (`gallery`, Inhaltsgruppe, order 900, nur Debug oder `kit.showGallery: true` in settings.json): alle `Registry.gallery`-Einträge nach Bereich gruppiert (feste Reihenfolge: design, patterns, settings, onboarding, permissions, …, Module, dann Rest alphabetisch), Bereichsmenü, Anzahl, Suche (Titel, Id, Bereichsname; ⌘F fokussiert), Vorschau-Erscheinungsbild je Bühne (Fenster / Hell / Dunkel). Einträge mit fester Größe werden einmal je Sprache gemessen und auf die Bühne verkleinert (nie vergrößert), flexible füllen die Breite. Zähler 49 in der Seitenleiste.

**Szenen** (je en/de × hell/dunkel): `settings.window` (ganzes Fenster, Allgemein), `settings.window-about`, `settings.general`, `settings.general-reset` (Bestätigung offen), `settings.about`, `settings.about-full` (Links, Hinweise, „Kopiert“), `settings.notices` (Sheet), `settings.gallery` (ganzes Fenster), `gallery.dark-stage`, `gallery.light-stage`, `gallery.no-results`. Galerie-Einträge: `settings.sidebar`, `settings.local-footer`.

**Selbsttest** `settings.panes`: General und About vorhanden, keine doppelten Ids, Deep Link auf About löst auf.

## Dateien

| Datei | Inhalt |
|---|---|
| `App/Sources/Kit/Settings/SettingsKit.swift` | `SettingsKit.register()` (Handler, Kit-Bereiche, Launch-Hook, Selbsttest), `SettingsScenes` (Szenen, Galerie-Einträge, `paneSize`, `window(pane:)`) |
| `App/Sources/Kit/Settings/SettingsHub.swift` | `SettingsHub`, `SettingKey.settingsPane`, `SettingsHubExtras`, `LocalOnlyFooter` |
| `App/Sources/Kit/Settings/SettingsController.swift` | `SettingsController`, `SettingsKeys` |
| `App/Sources/Kit/Settings/SettingsRootView.swift` | `SettingsRootView`, `SettingsStaticWindow`, `SettingsDetail`, `SettingsSidebar`, `\.settingsHub` |
| `App/Sources/Kit/Settings/GeneralPane.swift` | `GeneralPane`, `AppAppearance`, `SettingKey.appAppearance`, `SettingsReset` |
| `App/Sources/Kit/Settings/AboutPane.swift` | `AboutPane`, `AboutInfo`, `NoticesSheet`, `NoticesText` |
| `App/Sources/Kit/Settings/SettingsText.swift` | `SettingsText`, `SettingsSampleText` (nur Renders) |
| `App/Sources/Kit/Settings/SettingsTokens.swift` | Zusatzmaße als Extensions von `Metrics`/`Space` (Seitenleiste, Panel, About-Icon, Unterleiste, Galerie) |
| `App/Sources/Kit/Gallery/GalleryKit.swift` | `GalleryKit.register()`, `isVisible`, Szenen |
| `App/Sources/Kit/Gallery/GalleryModel.swift` | `GalleryModel` (Bereiche, Gruppen, Filter, Sichtbarkeit), `GalleryScheme`, `GalleryFit` (Messen, Skalieren), `GalleryFitLayout`, `SettingKey.showGallery` |
| `App/Sources/Kit/Gallery/GalleryPane.swift` | `GalleryPane`, `GalleryEntryView` |
| `App/Sources/Kit/Gallery/GalleryText.swift` | `GalleryText` (inkl. Bereichsnamen) |
| `App/Tests/SettingsHubTests.swift` | 12 Tests |
| `App/Tests/GalleryTests.swift` | 6 Tests |

## Entscheidungen

- **Fenster über `WindowHost`, nicht eigenes NSWindow**: S0 erledigt Autosave-Fix, Freigabe und AppForm schon; der Controller hängt sich per `NSWindow.willCloseNotification` für Tastenmonitor, Fokus-Rückgabe und Speicherfreigabe an.
- **Tastenmonitor nur wo nötig**: `MainMenu` ist immer installiert (auch bei Accessory-Apps, sobald sie regular werden), also routet der Monitor ⌘W/⌘,/Bearbeiten nur, wenn es kein Hauptmenü gibt. ⌘F immer, weil kein Menüpunkt in einem Bereich sucht.
- **Bestätigung an Ort und Stelle statt Alert**: renderbar, kein modaler Dialog, Esc bricht ab.
- **Zurücksetzen behält `onboarding.*`**: sonst stünde nach dem Zurücksetzen die Einrichtung wieder an. Fensterrahmen liegen in UserDefaults und bleiben.
- **Galerie: alle Einträge in einer Spalte** statt Liste + Bühne: so steht alles auf einen Blick da (Auftrag „alle Einträge nach Bereich“). Breite Einträge (Fenster-Beispiele 792 pt) werden verkleinert. Gemessen wird einmal je Eintrag und Sprache in einem eigenen `NSHostingController` (statisch, in der Zeichen-Skalierung) plus 8 pt Spielraum (siehe Hinweis an S0).
- **Galerie nur Debug oder `kit.showGallery`**: der Schalter hat bewusst keine UI (Endnutzer brauchen ihn nicht); Entwickler setzen ihn in settings.json.
- **Links aus `starter.json`**: `app.links` ist optional; `gen_config.py` prüft Titel en/de und `https://`/`mailto:` und erzeugt `AppConfig.links`. Ohne Links fehlt der Abschnitt.
- **Sprachsegment wie VoiceBud**: „System“ zuerst, Sprachen in ihrem eigenen Namen.
- **Erscheinungsbild ohne Abschnittstitel**: „Darstellung“ über „Erscheinungsbild“ war doppelt (englisch zweimal „Appearance“).

## Aus VoiceBud übernommen (für THIRD_PARTY_NOTICES, MIT, Copyright (c) 2026 Anas Riad)

- `HubController` (ui/Hub.swift): Tastenmonitor ⌘W/⌘F/Bearbeiten, `handBackActivation` (yieldActivation + activate), `malloc_zone_pressure_relief` nach dem Schließen → `SettingsController`, `SettingsKeys`
- `HubRootView` (NavigationSplitView, Spaltenbreiten, `.balanced`, ohne Sidebar-Knopf) → `SettingsRootView`
- `HubSidebar` (34-pt-Einträge, Squircle + Titel + Zähler, Auswahl mit `matchedGeometryEffect`, Gruppenlabel, ↑/↓ mit `focusable`/`onKeyPress`, Fußzeile „Alles lokal und offline“) → `SettingsSidebar`, `LocalOnlyFooter`
- `HubStaticWindow` (schwebende Seitenleiste in Renders) → `SettingsStaticWindow`
- `HubDetail` → `SettingsDetail`; Sprachzeile aus `HubGeneralPane` → `GeneralPane`
- Kopieren mit 1,4 s „Kopiert“ aus `HubHistoryRow` → Versionsangaben in `AboutPane`

## Außerhalb meines Strangs angefasst

- `scripts/gen_config.py` (S0, additiv): optionales `app.links` prüfen und als `AppConfig.links: [(en, de, url)]` ausgeben.
- `scripts/tests/test_gen_config.py` (S0, additiv): Test `test_links`.
- `scripts/build.sh` (S0, additiv): kopiert `THIRD_PARTY_NOTICES.md` nach `Contents/Resources`, wenn die Datei existiert (MIT verlangt den Hinweis in der verteilten App; „Über“ zeigt ihn).

Sonst nichts außerhalb von `Kit/Settings`, `Kit/Gallery`, `App/Tests/SettingsHubTests.swift`, `App/Tests/GalleryTests.swift`, `docs/bau/status/E.md`.

## Hinweise an andere Stränge

- **S0 (RenderRunner)**: Szenen mit `size: .zero` können Text abschneiden. Bekommt ein `HStack` mit zwei schrumpfbaren Texten genau seine gemessene Idealbreite, kürzt SwiftUI einen davon. Beobachtet am Inhalt von `design.accents` (ohne `Specimen`) auf Deutsch: „Wei…“ statt „Weiter“. `design.accents` selbst ist nicht betroffen (fester `Specimen` 680). Die Galerie gibt deshalb 8 pt Spielraum. Möglicher Fix im RenderRunner: gemessene Breite um 1–2 pt aufrunden oder mit `.fixedSize()` messen und zeichnen.
- **Strang D**: „Einrichtung erneut zeigen“ ruft `AppActions.openOnboarding()`; die Zeile erscheint nur, wenn `onboardingHandler` gesetzt ist.
- **Alle Module**: Einstellungsbereiche zwischen order 1 und 999 in `.settings` landen zwischen Allgemein und Über. Zähler: `SettingsHubExtras.counts["<paneId>"] = { n }`. Galerie-Bereichsnamen für alle geplanten Module stehen in `GalleryText.area`; unbekannte Bereiche zeigen ihre Id mit großem Anfangsbuchstaben.
- **Strang G (`check_texts.py`)**: `Text(verbatim: entry.id)` in `GalleryPane.swift` mit `// verbatim:`-Kommentar (Code-Id). Absichtlich gleiche Wörter in beiden Sprachen: `SettingsText.followMac` („System“), `SettingsText.links` („Links“). `SettingsSampleText.notices` enthält den englischen MIT-Lizenztext in beiden Sprachen (Lizenzen werden nicht übersetzt).
- **Strang G (`check_design.py`)**: `SettingsTokens.swift` deklariert Maße (`static let … = 10`), benutzt aber keine Literale in `.padding`/`spacing`/`cornerRadius`. In den Views stehen nur `spacing: 0`.
- **Strang J**: Das About-Icon nimmt `AppInfo.icon()` (AppIcon.icns im Bundle), sonst das Squircle.

## Kandidaten für Kit/Design

- `SettingsSidebar`-Maße (`Metrics.sidebarTop`, `sidebarPanelInset`, `Space.sidebarX` …) und das statische Panel, falls Strang A für das Hauptfenster dieselbe schwebende Seitenleiste rendert.
- Eine Unterleiste unter dem Kopfband (`Metrics.subBar` 38 pt mit Haarlinie, VoiceBud-Statistikzeile) als Muster.
- `SearchField` mit Fokus-Bindung: ⌘F setzt hier `.focused` auf das ganze Feld; ob das im Fenster wirklich den Textcursor setzt, ist nicht geprüft (siehe Lücken).
- Ein destruktiver Knopfstil (rot); die Bestätigung nutzt jetzt `.primary`.

## Bekannte Lücken

- Das echte Fenster wurde nach Regel §2.17 nie geöffnet: `NavigationSplitView`-Seitenleiste mit Systemglas, Toolbar-Band, Tastenmonitor, ↑/↓-Fokus, ⌘F-Fokus im Suchfeld, Sheet, Fokus-Rückgabe und Speicherfreigabe sind gebaut, aber nur über die reinen Regeln und Renders geprüft. Prüft der Lead.
- `THIRD_PARTY_NOTICES.md` gibt es noch nicht (Strang G); bis dahin zeigt „Über“ keinen Rechtliches-Abschnitt, die Szene `settings.notices` nutzt den Beispieltext. `Package.swift` bündelt die Datei nicht.
- Die Galerie misst feste Einträge einmal je Sprache; ändert ein Eintrag seine Größe mit dem Erscheinungsbild, stimmt die Skalierung nur ungefähr.
- Es gibt kein ⌘1…⌘9 für Bereiche (VoiceBud hat das auch nicht).
- Barrierefreiheit: Auswahl-Trait, Überschriften, kombinierte Fußzeile gesetzt; nicht mit VoiceOver geprüft.

## Prüfung (2026-10-12)

```
make build                                    -> grün (window,menubar,island,background,hotkeys,ai,examples), 0 Warnungen
make build MODULES=window                     -> grün; --selftest: 9 checks, 0 failures
make build MODULES=menubar                    -> grün; --selftest: 9 checks, 0 failures
make build MODULES=menubar,island             -> grün; --selftest: 9 checks, 0 failures
make build MODULES=window,…,ai,mlx,examples   -> grün; --selftest: 9 checks, 0 failures
make build CONFIG=release                     -> grün (Galerie ausgeblendet); --selftest: 9 checks, 0 failures
make test                                     -> "85 tests, 0 failures" + Python "Ran 12 tests … OK"
MODULES=menubar make test                     -> "85 tests, 0 failures"
make shots                                    -> 232 PNGs + index.html (davon 11 Szenen settings.*/gallery.* × 4)
make check                                    -> grün (Prüfskripte von G/K noch nicht da, übersprungen)
```

Selbsttests liefen mit `STARTER_HEADLESS=1` und eigenem `STARTER_DATA_DIR`; danach lief kein Prozess dieses Strangs mehr.

Angesehen (Read): `settings.window` en-light und de-dark (gegen VoiceBud `hub-allgemein.png`: schwebende Seitenleiste, Kopfband 52, Spalte links bündig), `settings.window-about` en-light und en-dark, `settings.general` en-light, `settings.general-reset` de-dark, `settings.about-full` de-light und en-dark, `settings.notices` en-light und de-dark, `settings.gallery` en-light, de-dark und de-light, `gallery.dark-stage` de-light, `gallery.light-stage` en-dark und de-light, `gallery.no-results` en-light.
Nach dem Ansehen behoben: doppelte Beschriftungen („Einrichtung/Einrichtung“, „Appearance/Appearance“), Datenordner in Renders zeigte den Build-Pfad, `mailto:` im Untertitel, doppelter Titel im Hinweis-Sheet, Aufzählungspunkte zu tief, Bereichsüberschrift der Galerie zu schwach gegenüber Eintragstiteln, „Wei…“ in der Galerie (Spielraum beim Messen), Seitenleisten-Beispiel zu hoch, About-Szene schnitt den letzten Abschnitt ab.
