# Status E (Einstellungsfenster, Galerie, Über)

Stand: 2026-10-12 (nach Review), Branch `strang/E` (Worktree `wt/E`), auf `main` 68281d5. Die Stubs von S0 in `Kit/Settings` und `Kit/Gallery` sind ersetzt; `SettingsKit.register()` und `GalleryKit.register()` heißen weiter so.

## Was gebaut ist

**Einstellungsfenster** (VoiceBud `HubController`/`HubRootView`/`HubSidebar`/`HubStaticWindow`, Notizen vb-onboarding-hub §3.1–3.2)

- `SettingsController`: öffnet das Fenster über `WindowHost` (900 x 620, min 760 x 500, leere Unified-Toolbar für das 52-pt-Band, Frame-Autosave mit Freigabe beim Schließen, Views werden beim Schließen freigegeben, accessory ↔ regular über `AppForm`). Dazu: gewünschter Bereich wird gewählt, lokaler Tastenmonitor (⌘F immer; ⌘W, ⌘, und ⌘X/C/V/A/Z nur ohne Hauptmenü), Fokus geht beim Schließen an die vorherige App zurück (nur bei Accessory-Apps ohne weitere Kit-Fenster), `malloc_zone_pressure_relief` 0,5 s nach dem Schließen. Headless: wählt nur den Bereich, öffnet kein Fenster.
- `SettingsHub` (`@Observable`): gewählter Bereich, zuletzt gewählter Bereich in `kit.settingsPane`, Deep Links, ↑/↓, ⌘F-Anfrage (`searchRequest`). Reine Regeln: `resolve` (gewünscht → aktuell → General → erster), `step` (an den Enden begrenzt), `groups`, `showsLabel`.
- `SettingsRootView`: `NavigationSplitView` (Seitenleiste 200/224/280, `.balanced`, ohne Sidebar-Knopf), Detail unter das Titelband gezogen. `SettingsSidebar`: 34-pt-Einträge mit Verlaufs-Squircle 22, Titel 13, Zähler (`CountBadge`), Auswahl springt per `matchedGeometryEffect` (`Motion.selection`, Reduce Motion beachtet), Gruppenlabel nur über der Einstellungsgruppe und nur wenn Inhaltsbereiche darüber stehen, Fußzeile, fokussierbar mit ↑/↓. Die Liste scrollt (ohne Balken), wenn mehr Bereiche da sind als das Fenster hoch ist; die Fußzeile bleibt unten stehen, der gewählte Eintrag wird bei ↑/↓ ins Bild gescrollt. `SettingsStaticWindow`: dasselbe Fenster ohne `NavigationSplitView` für Renders, mit der schwebenden macOS-26-Seitenleiste (Panel 18, Einzug 8, Schatten).
- `SettingsHubExtras`: `counts[paneId]` (Zähler neben Einträgen) und `sidebarFooter` (Standard: keine Fußzeile; `LocalOnlyFooter` mit grünem Punkt „Alles lokal und offline / Nichts verlässt deinen Mac“ schalten nur Projekte ohne jede Netzwerknutzung ein). `\.settingsHub` in der Umgebung für Bereiche im Fenster.

**Bereiche des Kits**

- „Allgemein“ (`general`, Einstellungsgruppe, order 0): Sprache der App (System / Deutsch / English, live über `Localizer.choice`, Fußnote erklärt „System“), Erscheinungsbild (System / Hell / Dunkel, appweit über `NSApp.appearance`, Schlüssel `app.appearance`, beim Start per Launch-Hook angewendet), „Neu beginnen“: Einrichtung erneut zeigen (nur wenn `AppActions.onboardingHandler` gesetzt ist) und Einstellungen zurücksetzen mit Bestätigung an Ort und Stelle (statt Alert, damit der Zustand renderbar ist). Zurücksetzen entfernt alle Schlüssel außer `onboarding.*`, `kit.showGallery` und dem, was Module mit `SettingsReset.keep(_:)` als Zustand anmelden, setzt Sprache auf System, wendet das Erscheinungsbild neu an und ruft `SettingsReset.didReset` auf (Module lesen dort zwischengespeicherte Werte neu); danach `Motion.doneHold` (2,4 s) „Auf Standard zurückgesetzt“. In der Bestätigung ist „Abbrechen“ der hervorgehobene Knopf (Esc), „Zurücksetzen“ roter Text auf einem ruhigen Knopf ohne Tastenkürzel.
- „Über“ (`about`, order 1000): App-Icon (aus dem Bundle, sonst Squircle 96 mit `app.symbol`), Name, „Version x (Build)“, Copyright; „Wenn etwas nicht klappt“: Versionsangaben kopieren („Starter 1.0.0 (1), macOS 26.0.1, arm64“, Chip zeigt 1,4 s „Kopiert“), Datenordner mit Pfad (Home als `~`) und „Im Finder zeigen“; „Links“ aus `starter.json app.links`; „Rechtliches“: Hinweise zu Drittanbietern in einem Sheet (600 x 520, ↩ und Esc schließen), Quelle `Contents/Resources/Notices/<lang>.md` aus `App/Resources/Notices/` in der Sprache der Oberfläche, sonst Englisch. Eigener kleiner Markdown-Leser: Titel, Überschriften, Absätze, Aufzählung, Linie, Code-Zäune als wörtlicher Block in Monospace (Lizenztexte, 80 Spalten passen), Inline-Code in Monospace, `<!-- … -->` wird übersprungen.
- „Galerie“ (`gallery`, Inhaltsgruppe, order 900, nur Debug oder `kit.showGallery: true` in settings.json): alle `Registry.gallery`-Einträge nach Bereich gruppiert (feste Reihenfolge: design, patterns, settings, onboarding, permissions, …, Module, dann Rest alphabetisch), Bereichsmenü, Anzahl, Suche (Titel, Id, Bereichsname; ⌘F fokussiert), Vorschau-Erscheinungsbild je Bühne (Fenster / Hell / Dunkel). Einträge mit fester Größe werden einmal je Sprache gemessen und auf die Bühne verkleinert (nie vergrößert), flexible füllen die Breite. Zähler 49 in der Seitenleiste.

**Szenen** (je en/de × hell/dunkel): `settings.window` (ganzes Fenster, Allgemein), `settings.window-about`, `settings.general`, `settings.general-reset` (Bestätigung offen), `settings.about`, `settings.about-full` (Links, Hinweise, „Kopiert“), `settings.notices` (Sheet mit der gebündelten Datei), `settings.window-many` (10 Bereiche bei Mindestgröße 760 x 500, scrollende Liste, Fußzeile), `settings.gallery` (ganzes Fenster), `gallery.dark-stage`, `gallery.light-stage`, `gallery.no-results`. Galerie-Einträge: `settings.sidebar`, `settings.local-footer`.

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
| `App/Resources/Notices/en.md`, `de.md` | Hinweise zu Drittanbietern für Nutzerinnen und Nutzer (VoiceBud, MIT-Text wörtlich) |
| `App/Sources/Kit/Settings/SettingsText.swift` | `SettingsText`, `SettingsSampleText` (nur Renders) |
| `App/Sources/Kit/Design/SettingsTokens.swift` | `Metrics.Sidebar` (schwebende Seitenleiste), Maße für About, Unterleiste, Galerie, Sheet; `Space`-Werte der Seitenleiste; `TypeScale.code`/`codeInline`; `Motion.copiedHold`/`doneHold`; `DestructiveHex`, `Theme.destructive` |
| `App/Sources/Kit/Gallery/GalleryKit.swift` | `GalleryKit.register()`, `isVisible`, Szenen |
| `App/Sources/Kit/Gallery/GalleryModel.swift` | `GalleryModel` (Bereiche, Gruppen, Filter, Sichtbarkeit), `GalleryScheme`, `GalleryFit` (Messen, Skalieren), `GalleryFitLayout`, `SettingKey.showGallery` |
| `App/Sources/Kit/Gallery/GalleryPane.swift` | `GalleryPane`, `GalleryEntryView` |
| `App/Sources/Kit/Gallery/GalleryText.swift` | `GalleryText` (inkl. Bereichsnamen) |
| `App/Tests/SettingsHubTests.swift` | 16 Tests |
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
- **Erscheinungsbild mit eigenem Abschnitt**: Abschnitt „Erscheinungsbild“, Zeile „Hell oder dunkel“ (vorher ohne Titel, las sich als Teil von „Sprache“).
- **Galerie als Bereich, kein eigenes Fenster**: BAUPLAN §3 nennt „pane + window“, STRANDS §E nur den Bereich. Die Galerie lebt im Einstellungsfenster (`AppActions.openSettings(pane: "gallery")`), ein zweites Fenster mit derselben Ansicht brächte nur einen zweiten Einstieg. Für DECISIONS bei der Zusammenführung.
- **Zwei Hinweisdateien**: `THIRD_PARTY_NOTICES.md` (Wurzel, Strang G) ist die Liste für Entwickler (Deutsch, Quellen, Umfang, Werkzeuge). Die App zeigt `App/Resources/Notices/<lang>.md`, geschrieben für Menschen, die die App benutzen. Ein Test stellt sicher, dass jeder Lizenztext (```-Block) der Wurzeldatei wörtlich in beiden App-Dateien steht.
- **Englische Schreibweise**: Abschnittstitel, Sheet-Titel und Knöpfe in Title Case, Zeilentitel und Untertitel in Satzschreibung ohne Schlusspunkt; US-Englisch („Licenses“).

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
- `scripts/build.sh` (S0, additiv): kopiert `App/Resources/Notices/*.md` nach `Contents/Resources/Notices/` (MIT verlangt den Hinweis in der verteilten App; „Über“ zeigt ihn). Die Wurzeldatei `THIRD_PARTY_NOTICES.md` wird nicht mehr gebündelt.
- `App/Resources/Notices/en.md`, `de.md` (neu, unter S0s `App/Resources`).
- `App/Sources/Kit/Design/SettingsTokens.swift` (neu in S0s `Kit/Design`, aus `Kit/Settings` verschoben, BAUPLAN §2.8). An bestehenden Kit/Design-Dateien nichts geändert.

Sonst nichts außerhalb von `Kit/Settings`, `Kit/Gallery`, `App/Tests/SettingsHubTests.swift`, `App/Tests/GalleryTests.swift`, `docs/bau/status/E.md`.

## Hinweise an andere Stränge

- **S0 (RenderRunner)**: Szenen mit `size: .zero` können Text abschneiden. Bekommt ein `HStack` mit zwei schrumpfbaren Texten genau seine gemessene Idealbreite, kürzt SwiftUI einen davon. Beobachtet am Inhalt von `design.accents` (ohne `Specimen`) auf Deutsch: „Wei…“ statt „Weiter“. `design.accents` selbst ist nicht betroffen (fester `Specimen` 680). Die Galerie gibt deshalb 8 pt Spielraum. Möglicher Fix im RenderRunner: gemessene Breite um 1–2 pt aufrunden oder mit `.fixedSize()` messen und zeichnen.
- **Strang D**: „Einrichtung erneut zeigen“ ruft `AppActions.openOnboarding()`; die Zeile erscheint nur, wenn `onboardingHandler` gesetzt ist.
- **Strang G (`THIRD_PARTY_NOTICES.md`)**: Der Satz „die App zeigt sie im Bereich „Über“, wenn sie im Bundle liegt“ stimmt nicht mehr. Vorschlag: „Die App zeigt eine Fassung für Nutzerinnen und Nutzer aus `App/Resources/Notices/<lang>.md`; jeder Lizenztext von hier steht dort wörtlich (Test).“ Wer Fremdcode ergänzt, ergänzt beide App-Dateien mit.
- **Reset-Vertrag (Stränge F, H, B, A)**: `SettingsReset.keep("<prefix>")` für Zustand, `SettingsReset.didReset.append { … }` für zwischengespeicherte Werte, beides in `register()`. Konkret: F `HotkeyCenter` liest `choices` nach dem Zurücksetzen neu und registriert die Carbon-Hotkeys neu; H `SettingsReset.keep("ai.usage")`; B `SettingsReset.keep("background.loginItemAsked")`; A entscheidet, ob `window.page`/`window.sidebarHidden` Zustand sind (dann `keep`).
- **Strang A (`Metrics.Sidebar`)**: `Metrics.Window.sidebarMin/Max/Inset/Top` doppeln `Metrics.Sidebar` (Kit/Design). Bei der Zusammenführung auf `Metrics.Sidebar` umstellen; Achtung, A nutzt `sidebarTop` 48, der Hub 44 (VoiceBud); einen Wert wählen.
- **Alle Module**: Einstellungsbereiche zwischen order 1 und 999 in `.settings` landen zwischen Allgemein und Über. Zähler: `SettingsHubExtras.counts["<paneId>"] = { n }`. Galerie-Bereichsnamen für alle geplanten Module stehen in `GalleryText.area`; unbekannte Bereiche zeigen ihre Id mit großem Anfangsbuchstaben.
- **Strang G (`check_texts.py`)**: `Text(verbatim: entry.id)` in `GalleryPane.swift` mit `// verbatim:`-Kommentar (Code-Id). Absichtlich gleiche Wörter in beiden Sprachen: `SettingsText.followMac` („System“), `SettingsText.links` („Links“). `SettingsSampleText.notices` enthält den englischen MIT-Lizenztext in beiden Sprachen (Lizenzen werden nicht übersetzt).
- **Strang G (`check_design.py`, `check_texts.py`)**: Mit G1s Entwurf gegen eine Kopie dieses Strangs geprüft: keine Befunde in `Kit/Settings`, `Kit/Gallery`, `Kit/Design/SettingsTokens.swift`. Pfeile in Kommentaren und der Bindestrich als Minus waren vorher Befunde und sind umformuliert. Die Maße liegen jetzt in Kit/Design.
- **Strang J**: Das About-Icon nimmt `AppInfo.icon()` (AppIcon.icns im Bundle), sonst das Squircle.

## Kandidaten für Kit/Design

- `Metrics.Sidebar` liegt schon in Kit/Design; das statische Panel (`sidebarPanel`, Schatten) könnte ein gemeinsamer View für Hub und Hauptfenster werden.
- Eine Unterleiste unter dem Kopfband (`Metrics.subBar` 38 pt mit Haarlinie, VoiceBud-Statistikzeile) als Muster.
- `SearchField` mit Fokus-Bindung: ⌘F setzt hier `.focused` auf das ganze Feld; ob das im Fenster wirklich den Textcursor setzt, ist nicht geprüft (siehe Lücken).
- Ein echter destruktiver Knopfstil in `Buttons.swift` (`KitButtonBody` ist privat). Bis dahin roter Text (`Theme.destructive`, Kontrast ≥ 4,5:1 getestet) auf `.secondary`.

## Bekannte Lücken

- Das echte Fenster wurde nach Regel §2.17 nie geöffnet: `NavigationSplitView`-Seitenleiste mit Systemglas, Toolbar-Band, Tastenmonitor, ↑/↓-Fokus und Mitscrollen, ⌘F-Fokus im Suchfeld, Sheet (Esc über `onExitCommand`), Fokus-Rückgabe und Speicherfreigabe sind gebaut, aber nur über die reinen Regeln und Renders geprüft. Prüft der Lead.
- Der SwiftPM-Weg (`Package.swift`) bündelt keine Ressourcen; dort fehlt der Abschnitt „Rechtliches“. Der Standardweg `make build` bündelt sie.
- Wave-1-Module nutzen `SettingsReset.keep`/`didReset` noch nicht (siehe Hinweise); bis zur Zusammenführung greifen Kurzbefehle nach einem Zurücksetzen erst beim nächsten Start.
- Die Galerie misst feste Einträge einmal je Sprache; ändert ein Eintrag seine Größe mit dem Erscheinungsbild, stimmt die Skalierung nur ungefähr.
- Es gibt kein ⌘1…⌘9 für Bereiche (VoiceBud hat das auch nicht).
- Barrierefreiheit: Auswahl-Trait, Überschriften, kombinierte Fußzeile gesetzt; nicht mit VoiceOver geprüft.
- S0: `ObservingTests/track calls onChange on every change` schlug in einem von vier Läufen mit `MODULES=menubar` fehl (1 != 2, 50 ms Runloop unter Last); drei Wiederholungen grün. Nicht von diesem Strang.

## Prüfung vor dem Review (2026-10-12)

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

## Review (2026-10-12)

16 Befunde aus zwei Reviews (Korrektheit, Gestaltung), einige doppelt. Alle Änderungen in `fdc5691 fix(settings): address strand E review findings`.

| # | Befund | Urteil | Ergebnis |
|---|---|---|---|
| 1 | Hinweis-Sheet zeigt die deutsche Entwicklerdatei mit rohem Markdown (Code-Zäune, Backticks), kein Esc, Titel weicht ab (major) | echt | behoben: eigene Dateien `App/Resources/Notices/{en,de}.md` für Nutzerinnen und Nutzer, build.sh bündelt nur diese; `NoticesText` kennt Code-Zäune (wörtlicher Monospace-Block), Inline-Code, HTML-Kommentare; Esc schließt (`onExitCommand`); Datei-Titel = Sheet-Titel; Tests für Zaun, Kommentare, Spans und Gleichlauf mit der Wurzeldatei (mit G2s Datei geprüft: grün, mit veränderter Lizenz: rot) |
| 2 | Zurücksetzen löscht Modulzustand, Module können weder ausnehmen noch reagieren (major) | echt | behoben: `SettingsReset.keep(_:)`, `SettingsReset.didReset`, `kit.showGallery` bleibt; Vertrag unter „Hinweise an andere Stränge“ für F, H, B, A. Das Umsetzen in den Modulen bleibt deren Sache (Zusammenführung) |
| 3 | Maße als Literale außerhalb Kit/Design, doppelt mit Strang A | echt | behoben: Datei nach `Kit/Design/SettingsTokens.swift`, Seitenleiste als `Metrics.Sidebar`, Haltezeiten als `Motion.copiedHold`/`doneHold`, Speicherfreigabe als benannte Konstante. Doppelung mit A wird bei der Zusammenführung aufgelöst (A ist ein anderer Branch) |
| 4, 10 | Destruktives „Zurücksetzen“ ist Standardknopf (↩) und sieht aus wie „Weiter“ | echt | behoben: „Zurücksetzen“ roter Text auf `.secondary` ohne Tastenkürzel, „Abbrechen“ hervorgehoben mit Esc; Kontrast-Test für `Theme.destructive` |
| 5 | Galerie-Fenster fehlt (BAUPLAN §3) | Planwiderspruch | übersprungen mit Begründung: STRANDS §E verlangt nur den Bereich; Entscheidung unter „Entscheidungen“ festgehalten, für DECISIONS bei der Zusammenführung |
| 6 | Fußzeile „Alles lokal und offline“ als Standard für jede App | echt | behoben: Standard aus, `LocalOnlyFooter` als dokumentiertes Opt-in |
| 7, 12 | Uneinheitliche Groß-/Kleinschreibung, „Licences“, holprige Sätze, Satzzeichen | echt | behoben: Title Case für Abschnitte, Sheet-Titel und Knöpfe, Satzschreibung ohne Punkt für Zeilen und Untertitel; „Troubleshooting“, „Reset settings“, „Third-party notices“ (Zeile), „Licenses“; „You won't need to go through setup again.“ / „Die Einrichtung musst du nicht wiederholen.“ |
| 8 | Hinweis-Sheet: rohes Markdown, Szene versteckt es mit Beispieltext (major, Doppel zu 1) | echt | behoben wie 1; `settings.notices` rendert die gebündelte Datei der Render-Sprache, der Beispieltext ist nur noch Rückfall ohne Bundle (Tests) und als solcher beschriftet |
| 9 | Seitenleiste ohne ScrollView, läuft bei vielen Bereichen in die Ampeln | echt | behoben: Liste in `ScrollView` (Balken aus, Mitscrollen bei ↑/↓), Fußzeile fest unten; neue Szene `settings.window-many` (10 Bereiche bei 760 x 500) |
| 11 | Sprach-Fußnote: Relativsatz hängt an „Systemeinstellungen“ | echt | behoben: „Bei „System“ nutzt die App aus der Liste unter Sprache & Region in den Systemeinstellungen die erste Sprache, die sie beherrscht.“ / EN entsprechend (ohne Pfeil, G1s Textprüfung verbietet Deko-Pfeile) |
| 13 | Erscheinungsbild-Karte ohne Titel liest sich als Teil von „Sprache“ | echt | behoben: Abschnitt „Erscheinungsbild“ / „Appearance“, Zeile „Hell oder dunkel“ / „Light or dark“ |
| 14 | Seitenleisten-Beispiel in der Galerie mit leerem 44-pt-Streifen | echt | behoben: `SettingsSidebar(top:)`, das Beispiel nutzt `Metrics.Sidebar.topAlone` (12) und zeigt die Opt-in-Fußzeile |
| 15 | Vorschau-Schalter „Fenster“ unklar | echt | behoben: „Auto“ / „Automatisch“ |
| 16 | Kopieren-Chip mit Symbol, Finder-Chip ohne; Haltezeiten als Literale | echt | behoben: Finder-Chip mit `folder`; Zeiten in `Motion` (siehe 3) |

**Prüfung nach dem Review**

```
make build                                    -> grün, 0 Warnungen
make build MODULES=window                     -> grün, 0 Warnungen; --selftest: 9 checks, 0 failures
make build MODULES=menubar                    -> grün, 0 Warnungen; --selftest: 9 checks, 0 failures
make build MODULES=menubar,island             -> grün, 0 Warnungen; --selftest: 9 checks, 0 failures
make build MODULES=window,…,ai,mlx,examples   -> grün, 0 Warnungen; --selftest: 9 checks, 0 failures
make build CONFIG=release                     -> grün, 0 Warnungen; --selftest: 9 checks, 0 failures
make test                                     -> "89 tests, 0 failures" + Python "Ran 12 tests … OK"
MODULES=menubar make test                     -> "89 tests, 0 failures" (3 von 4 Läufen; einmal S0-ObservingTests, siehe Lücken)
make shots                                    -> 236 PNGs + index.html
make check                                    -> grün (Prüfskripte von G/K auf diesem Branch noch nicht da)
G1 check_design.py / check_texts.py (Kopie)   -> keine Befunde in Kit/Settings, Kit/Gallery, SettingsTokens.swift
```

Angesehen (Read): `settings.notices` en-light und de-dark (echte Datei, MIT-Text in 80 Spalten, keine Backticks), `settings.window-many` de-light (Liste scrollt, Fußzeile unten, Panel-Einzug intakt), `settings.window` en-light, `settings.general-reset` en-dark und de-light (roter Text, „Abbrechen“ hervorgehoben), `settings.general` de-light (Fußnote, Abschnitt „Erscheinungsbild“), `settings.about-full` en-light (Schreibweise, Finder-Symbol), `settings.window-about` de-dark (Rechtliches mit gebündelter Datei), `gallery.light-stage` en-light und de-dark (kein Streifen oben, „Auto“/„Automatisch“).
