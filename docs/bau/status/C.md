# Status C (Modul Insel)

Stand: 2026-10-12, Branch `strang/C` (von `main` 68281d5). Gebaut ist das Modul `island` in `App/Sources/Modules/Island/` mit Tests in `App/Tests/IslandTests.swift`. Grundlage: VoiceBud `ui/Island.swift`, `ui/IslandWindow.swift`, `ui/IslandRender.swift`, `ui/Hub.swift` (Bühne, Kacheln), Notizen `vb-island-notch.md`.

## Was gebaut ist

| Datei | Inhalt |
|---|---|
| `IslandController.swift` | `Island` (öffentliche API `Island.shared.present(_:)`, `update(_:)`, `dismiss()`, `isPresenting`, `notchBusy`), Lebenszyklus: Erscheinen (transparent einordnen, nach 16 ms wachsen, 0,1 s einblenden, nach 60 ms Glyphen tauschen statt eintreten), Morphen in eine neue Aufnahme auf demselben Bildschirm, Ausblenden (20 ms, Einklappen, Ausblenden ab 0,12/0,22 s, Ausordnen 0,26 s später), Auto-Ausblenden (Hinweis 2,5 s, Fertig-Karte nach Einstellung, ab 60 s bleibt sie), "Dauert länger" (Sekunden ab 5 s, Karte ab 10 s), Zeiger auf der Karte (30 Hz nur solange nötig, geparkter Zeiger, Menüleisten-Streifen, 0,6 s Nachlauf, Restzeit eingefroren, mindestens 0,8 s), Selbstheilung (Fensterserver-Prüfung `kCGWindowIsOnscreen`, Neubau höchstens alle 5 s, Prüfung nach 60 ms und 0,35 s, Heiltimer 0,25 s nur bei laufendem Inhalt), Bildschirmwechsel, Vollbild-Unterdrückung, Reduce Motion, Töne und Haptik. Alles über `Island.Dependencies` (Uhr, Fenster, Bildschirme, Zeiger, Einstellungen) austauschbar |
| `IslandContent.swift` | `IslandContent` (`.activity(symbol:title:detail:tint:)`, `.progress(title:fraction:symbol:tint:cancel:)`, `.levels([Float], symbol:tint:)`, `.done(title:detail:body:actions:tint:)`, `.notice(text:kind:)`), `IslandAction`, `IslandNoticeKind` (info, success, warning, error), `IslandTint`, `IslandBadgeKind` |
| `IslandGeometry.swift` | `IslandScreen` (Bildschirmbeschreibung, aus `NSScreen` oder von Hand), `IslandScreenGeometry` (Notch aus `safeAreaInsets.top` + `auxiliaryTopLeft/RightArea`, Mitte aus der linken Fläche, Menüleistenhöhe mit Rückfall, Panel-Ursprung pixelgenau, Insel oder Kapsel je Stil, Kapsel-Oberkante mit Ausweichen), `IslandLayout` (Breiten: Ohren nach Inhalt, Karten 400/470, Hinweise so schmal wie möglich; Absätze, Vorschauzeile, Timer) |
| `IslandModel.swift` | `IslandModel` (@Observable Darstellungsmodell, `bands` und `cardFrame` unbeobachtet), `IslandSurfaceGeometry` + `islandSurface(_:widthGrowing:heightGrowing:reduce:)` (getrennte Federn für Breite und Höhe über zwei Animatable-Modifier), Übergänge `islandEnter`, `islandSwap`, `islandGlyph`, `islandHandOver` |
| `IslandShapes.swift` | `NotchShape` (konkave Ohren, animierbare Radien), `NotchSurfaceShape/Mask`, `CapsuleBackdrop` (Schatten mit negativer Ausdehnung), `CapsuleSurfaceShape/Mask`, `IslandCheckGlyph` |
| `IslandView.swift` | `IslandView` (Wurzel im Panel), `NotchIslandView` (Ohrenreihe + Körper), `CapsuleView` (wächst aus dem 36 × 8-Samen); Standbild- und Reduce-Motion-Pfad ohne Morphen |
| `IslandBodies.swift` | Titelzeile (Titel + gedimmtes Detail, Abstand statt Mittelpunkt), Vorschau, aufgeklappter Volltext (12 Zeilen + halbe, Rollen, Ausblendkanten), Kopieren + Aktionen, Hinweistext, "Dauert länger" mit Abbrechen |
| `IslandGlyphs.swift` | Abzeichen, Aufnahmepunkt, Ring (Spinner oder Anteil), Timer, Sekundenzähler, Prozent, Pegelanzeige `IslandMeter` (4 Balken, Attack/Release-Glättung, ruhige synthetische Bewegung ohne Daten), `IslandButton`, `IslandCopyButton`, `IslandHaptic`, `IslandSound` |
| `IslandPanel.swift` | `IslandPanel` (randlos, nicht aktivierend, klickdurchlässig, Ebene Statusleiste + 8, alle Spaces, `constrainFrameRect` überschrieben, `canHide = false`, `sharingType = .readOnly`), `IslandHostingView` (`acceptsFirstMouse`), `IslandSurfaceHost`-Protokoll + `IslandPanelHost`, `isFullscreen`, `IslandTask`, `IslandScheduling` + `MainScheduler` |
| `IslandSettings.swift` | `IslandStyle` (auto, island, capsule), Einstellungsschlüssel, `IslandPrefs` |
| `IslandPreviews.swift` | `IslandBackdrop` (Hintergrundbild, Menüleiste, Hardware-Notch), `IslandStage`, `IslandMiniStage`, `IslandStyleTile`, `IslandStyleStage` (Live-Bühne: Insel und Kapsel morphen mit den echten Federn) |
| `IslandPane.swift` | Einstellungsbereich "Insel und Kapsel" |
| `IslandOnboarding.swift` | Onboarding-Schritt "Darstellung" (Reihenfolge 500) |
| `IslandScenes.swift` | Render-Szenen und Galerie-Einträge |
| `IslandDemo.swift` | `--demo` / `--demo island` (Schleife) und "Vorschau zeigen" (einmal) |
| `IslandText.swift` | `IslandText`, `IslandSampleText` |
| `IslandLook.swift` | Modul-Tokens (Maße der Glyphen, Ohren, Pille, Karten, Zeiten der Choreografie) |
| `IslandModule.swift` | `IslandModule.register()`: Bereich, Schritt, Start-/Ende-Hooks, Demo-Treiber, Szenen, Galerie, Selbsttests |

### Registriert

- Einstellungsbereich `island` (Gruppe settings, Reihenfolge 200, Symbol `rectangle.topthird.inset.filled`, Tönung black): Live-Bühne, Kacheln Automatisch / Insel an der Notch / Kapsel (echte Views verkleinert), Bestätigung anzeigen (1,5 s / 3,0 s / 5,0 s / Bleibt), Beim Überfahren ausklappen, Töne, Trackpad-Rückmeldung, Im Vollbild ausblenden, Vorschau zeigen.
- Onboarding-Schritt `island.appearance` (500): Titel, Live-Bühne, zwei Kacheln (Insel speichert `auto`, Kapsel `capsule`; ein in den Einstellungen gewähltes `island` bleibt), Fußnote.
- Einstellungsschlüssel: `island.style` ("auto"), `island.confirmSeconds` (3), `island.hoverExpand` (true), `island.sounds` (false), `island.haptics` (true), `island.hideInFullscreen` (false).
- Start-Hook `Island.shared.start()` (Beobachter für Bildschirme und Reduce Motion, Panel vorab bauen, nicht headless), Ende-Hook (Demo stoppen, Insel abbauen), Demo-Treiber (nur wenn `--demo` keinen anderen Bereich nennt).
- Selbsttests `island.geometry` (jeder echte Bildschirm: Menüleiste > 0, Panel bündig oben) und `island.headless` (echter Controller mit echtem Panel, headless: Inhalt im Modell, Panel nie sichtbar, `stop()` räumt ab).
- Render-Szenen (30): `island.<zustand>` und `capsule.<zustand>` für `activity`, `progress`, `progress-fraction`, `progress-counting`, `progress-slow`, `levels`, `done`, `done-hover`, `done-copied`, `notice-info`, `notice-success`, `notice-warning`, `notice-error`; dazu `capsule.no-notch`, `island.pane`, `island.onboarding`, `island.tiles`.
- Galerie (Bereich `island`): `island.states`, `island.stage`, `island.glyphs`.

## Entscheidungen

- **Allgemeines Inhaltsmodell statt VoiceBuds Phasen.** Linkes Ohr: Abzeichen (Symbol und Tönung des Inhalts, Haken, Hinweiszeichen) plus Titel; rechtes Ohr: Detail, Zähler/Prozent/Ring oder Pegel. Die Ohren sind so breit wie ihr Inhalt (mindestens 50 pt je Seite, immer symmetrisch zur Notch, höchstens 470 pt gesamt), gemessen mit den AppKit-Zwillingen der Schriftgrade (`IslandLook.titleFont` usw.) statt nach dem ersten Frame. Ein langer Titel wird gekürzt.
- **Stil `auto` vs. `island`:** beide zeigen die Insel an der Notch. `auto` weicht unter die Notch aus (Kapsel bei Notchhöhe + 8), solange `Island.shared.notchBusy` true liefert; standardmäßig ist niemand gesetzt. VoiceBuds Alcove-Erkennung (Bildschirmfoto fremder Fenster, CoreAudio-Heuristik) ist bewusst nicht portiert. Auf Bildschirmen ohne Notch zeigt jeder Stil die Kapsel (nie eine gemalte Notch).
- **Fertig-Karte ohne rechte Ohr-Angabe:** Titel und gedimmtes Detail stehen in der Karte (VoiceBud-Meta-Zeile), das rechte Ohr bleibt leer. Aufklappen nur, wenn es Text oder Aktionen gibt. Aktionen schließen die Karte (`dismisses: true`) und sehen aus wie Kopieren.
- **Klicks:** Die Wurzel nimmt nur Klicks an, wenn `model.acceptsClicks` (Zeiger auf aufgeklappter Karte oder auf der "Dauert länger"-Karte mit Abbrechen); das Panel bleibt sonst klickdurchlässig. Zeigerabfrage gibt es nur für Fertig-Karten mit Inhalt (und eingeschaltetem Aufklappen) und für Fortschritt mit Abbrechen ab 10 s.
- **Pegel ohne Neuzeichnen:** `update(.levels(…))` mit gleichem Symbol und gleicher Tönung schreibt nur `model.bands` (unbeobachtet); der `Canvas` liest sie jedes Frame. Beliebig viele Bänder werden auf 4 Balken gefaltet; leere Bänder = ruhige synthetische Bewegung (Vorschauen).
- **"Wächst gerade ein" zählt als sichtbar:** Ein `update` in den 16 ms vor dem ersten Frame bleibt in derselben Aufnahme (kein zweites Einordnen).
- **Renders:** In `--render` laufen keine Übergänge (`RenderMode.isStatic` → `.identity`; ein ruhender Blur-Modifier würde Text offscreen rastern), alle Zeitachsen stehen bei 0,75 s, der Kapsel-Schatten ist dort ein `shadow` gleicher Reichweite (Offscreen-Aufnahmen zeichnen keine Blur-Filter; live bleibt VoiceBuds geblurrte Kopie). Die Szenen-Hintergründe folgen hell/dunkel (Pfirsich bzw. Violett aus `Wallpaper`).
- **Testbarkeit:** Der Controller hängt nur an `Island.Dependencies`; die Tests nutzen eine manuelle Uhr, ein Fake-Panel und Bildschirme von Hand (14"-MacBook mit Notch + externer Bildschirm ohne).
- Swift 6 / MainActor: `NotchShape`, `IslandCheckGlyph`, `IslandCappedHeightLayout`, Umgebungsschlüssel sind `nonisolated`; die Animatable-Werte der Breiten-/Höhen-Modifier ebenso.

## Aus VoiceBud übernommen (für THIRD_PARTY_NOTICES, MIT, Copyright (c) 2026 Anas Riad)

- `IslandScreenGeometry` (Notch-Messung, Menüleiste, Panel-Ursprung) → `IslandScreen` + `IslandScreenGeometry`
- `IslandPanel`, `IslandHostingView` (Fensterrezept wörtlich)
- `NotchShape`, `IslandSurfaceGeometry`, `IslandSurfaceWidthFX/HeightFX`, `islandSurface(…)`, `NotchSurfaceShape/Mask`, `CapsuleBackdrop`, `CapsuleSurfaceShape/Mask`, `IslandCheckGlyph`
- `IslandMotion` (Federwerte liegen schon in `Motion.Island`), Übergänge `islandEnter`, `islandSwap`, `islandGlyph`, `islandHandOver`, `IslandContentKey`
- `IslandController`: `beginTake`/`dismiss`-Choreografie, `scheduleHide`, Zeigerabfrage (`startHoverTracking`, `pollPointer`, `cardScreenRect`, `pointerEntered/Left`), `ensureVisibleWhileRecording`/`reallyOnScreen`/`verifyOnScreen`/`rebuildPanel`, `screensChanged`, `isFullscreen`, Töne, Langsam-Zeiten (`IslandSlow`)
- `NotchIslandView`, `CapsuleView` (Morph- und Standbildpfad), `IslandView` (Reduce-Motion-Überblendung über `FadeID`), `IslandSurfaceHitArea`, `islandReportsCardFrame`
- `IslandDoneText`, `IslandCappedHeightLayout`, `IslandFullText`, `IslandPreviewText`, `IslandErrorBody`, `IslandSlowBody` (allgemein: Abbrechen-Knopf statt Tastenkürzel-Hinweis), `IslandCopy.paragraphs/preview/timer`
- `IslandMicBadge`/`IslandErrorBadge`/`IslandCheckBadge` → `IslandBadge`, `IslandRecDot`, `IslandRingSpinner` → `IslandRing`, `IslandTimerText`, `IslandSlowSeconds`, `IslandCopyButton`, `IslandPressStyle`, `IslandHaptic`
- `WaveformView` ("fein") + `IslandWaveEngine` + `IslandWaveMath` → `IslandMeter`, `IslandMeterEngine`, `IslandMeterMath`
- `IslandBackdrop`, `IslandRenderer`-Szenenidee → `IslandBackdrop`, `IslandScenes`
- `HubIslandStage`, `HubStageCapsule`, `HubIslandTile`, `HubIslandPane` → `IslandStyleStage`, `IslandStyleTile`, `IslandPane`; Onboarding-Schritt nach `onboarding-08-darstellung`
- `DemoDriver`-Idee → `IslandDemo`

Nicht übernommen: Alcove-Erkennung, Live-Text (Schwanzlayout, Cursor, Schimmer), Texterkennung/Formeln, Kontextabschnitt, IPC, `OutputMute`.

## Außerhalb meines Strangs angefasst

Nichts. Nur `App/Sources/Modules/Island/**`, `App/Tests/IslandTests.swift` und diese Datei. Der Stub `IslandModule.swift` ist ersetzt (Name und `register()` bleiben).

Kandidaten für Kit (nicht verschoben): `IslandLook`-Maße der Glyphen und Choreografie-Zeiten (→ `Kit/Design/Island.swift`), `IslandBackdrop`/`IslandStage` (das Onboarding-Hero von Strang D kann in Welle 2 `IslandStyleStage` oder `IslandStage` direkt nutzen, solange `MODUL_ISLAND` an ist).

## Hinweise für andere Stränge

- **G (Prüfskripte):** `IslandLook` hat vier NSFont-Zwillinge mit Zahlen (`NSFont.systemFont(ofSize: 12, …)`), markiert mit `// design-ausnahme:`. `IslandText.counter` hat in beiden Sprachen denselben Text (Zahl + "s"). Zwei `Text(verbatim:)` mit `// verbatim:`-Kommentar (Timer "m:ss", unsichtbarer Zeilenhöhen-Bezug). `spacing: 0` und `.frame(width: 1, height: 1)` kommen vor.
- **D (Onboarding):** Schritt `island.appearance` nutzt `OnboardingPage`, `OnboardingHeader`, `SettingsSection(tone: .onboarding)`, `TilePicker`, `OnboardingFootnote`; er setzt `canContinue` nicht (Weiter immer möglich).
- **E (Einstellungen):** Bereich `island` nutzt `PaneScaffold` (Layout `.column`); die Bühne oben ist ein eigenes Kind in der Spalte.
- **I (Beispiele, Welle 2):** Aufruf über `Island.shared.present/update/dismiss`; `Island.shared.notchBusy` für eigene Notch-Inhalte.

## Bekannte Lücken

- Echtes Verhalten auf dem Bildschirm (Federn, Einblenden, Zeiger auf der Karte, Kopieren, Spaces-Selbstheilung, mehrere Bildschirme, Vollbild-Erkennung, Töne, Haptik) ist nur über die Zustandsmaschine mit Fakes getestet, nicht live angesehen (Regel §2.17). Für den Lead: `build/Starter.app/Contents/MacOS/Starter --demo island` spielt alle Zustände in Schleife; "Vorschau zeigen" im Bereich einmal.
- Reduce Motion ist gebaut (Überblendung je Zustand), aber nicht live geprüft.
- VoiceOver: Glyphen sind ausgeblendet, Texte lesbar; keine Ansage beim Erscheinen (`NSAccessibility` announcement) – Kandidat für später.
- Die Live-Bühne im Bereich und im Onboarding animiert die Pegelanzeige dauerhaft (60 Hz), solange sie sichtbar ist (wie VoiceBud).
- Der Selbsttest `island.geometry` prüft die echten Bildschirme der Maschine; ohne Bildschirm (manche CI-Runner) ist er leer und besteht.
- `Package.swift`-Weg nicht gebaut (SwiftPM stürzt auf diesem Mac ab, siehe S0).

## Prüfung (Befehle und Ergebnisse, 2026-10-12)

```
make build                                      -> grün (window,menubar,island,background,hotkeys,ai,examples)
make build MODULES=menubar,island               -> grün; --selftest "10 checks, 0 failures"
make build MODULES=window,island                -> grün; --selftest "10 checks, 0 failures"
make build MODULES=window,menubar               -> grün (ohne Insel); --selftest "8 checks, 0 failures"
make build MODULES=window,menubar,island,background,hotkeys,ai,mlx,examples -> grün; --selftest "10 checks, 0 failures"
make build CONFIG=release                       -> grün
make test                                       -> "105 tests, 0 failures" (38 neue Insel-Tests) + Python "Ran 11 tests … OK"
MODULES=menubar,island make test                -> "105 tests, 0 failures"
MODULES=window,menubar make test                -> "67 tests, 0 failures" (Insel-Tests sind mit #if MODUL_ISLAND ausgenommen)
make shots                                      -> "render: 308 PNG(s) … + index.html" (30 Insel-Szenen × en/de × hell/dunkel)
make check                                      -> grün (Prüfskripte von G/K noch nicht da, übersprungen)
pgrep (Starter aus wt/C)                        -> kein Prozess übrig; kein Ordner in ~/Library/Application Support
```

Tests (`App/Tests/IslandTests.swift`): Geometrie (Notch gemessen, Notch außermittig, ohne Notch, sich versteckende Menüleiste, unbrauchbare Werte, Panel-Ursprung pixelgenau bei 2x und 1x, Bildschirm unter dem Zeiger inkl. Oberkante, Insel/Kapsel je Stil inkl. Ausweichen, Zeiger auf der Karte mit Menüleisten-Streifen), Breiten (eingeklappt, Ohren, Deckel, Fortschritt, Karten, Hinweise), Absätze, Timer, Prozent en/de, Pegel-Mathematik (Stille, Falten, Glättung zeitkorrigiert), Einstellungen, Inhaltsmodell, Registrierung, `--demo`-Filter, Render-Pixelprüfung, und die Zustandsmaschine: Erscheinen (16 ms / 60 ms), Hinweis 2,5 s mit Ausordnen, Fertig-Karte 1,5 s und "Bleibt", Ändern an Ort und Stelle und reine Pegel-Updates, Morphen vs. neue Aufnahme auf anderem Bildschirm, Update vor dem ersten Frame, Erscheinen während des Ausblendens, Form einmal je Aufnahme, langsamer Fortschritt 5 s / 10 s, Abbrechen erst ab 10 s, Zeiger (geparkt, Aufklappen, Restzeit, Nachlauf, Einklappen, Ausblenden nach Restzeit), Menüleisten-Streifen, keine Abfrage ohne Text oder bei ausgeschaltetem Aufklappen, Bildschirmwechsel, Selbstheilung, headless mit virtuellem Zeiger.

Angesehen (Read, über Kontaktbögen): alle `island.*`-Zustände en-dark und de-light, alle `capsule.*`-Zustände de-light und en-dark, `done-hover`/`done-copied` in allen vier Varianten, `capsule.no-notch`, `island.pane` de-light und en-dark (gegen VoiceBud `hub-insel.png`), `island.onboarding` en-dark und de-light (gegen `onboarding-08-darstellung-light.png`), `island.tiles` de-dark und en-light. Behoben nach dem Ansehen: Kopieren-Knopf war wegen unsichtbarer Breiten-Platzhalter seitlich versetzt; Kachel-Vorschauen hatten dunkle Ränder (Bühne jetzt so breit wie die Kachel); Insel in Kacheln zu groß; Kapsel-Schatten fehlte in Renders; deutscher Beispieltitel "Exportiert" mehrdeutig ("Export läuft"); Beispieltext verlängert, damit die Ausblendkante beim Aufklappen sichtbar ist.
