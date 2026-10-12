# Design

Muster, Maße und Beispiele für jede Oberfläche. Die verbindliche Kurzform steht in `CLAUDE.md` Teil A (Design- und Schreibregeln aus `rules/`). Bei Widerspruch gilt `CLAUDE.md`; Festlegungen eines Projekts stehen in `docs/PROJECT.md`.

Vorbild sind VoiceBud und die Apps von macOS 26 (Musik, Systemeinstellungen, Kontrollzentrum): ruhig, präzise, großzügig ohne leer zu wirken, klare Hierarchie, Systemschrift, SF Symbols, Haarlinien, durchgehende Eckenradien, Federn statt linearer Bewegung, hell und dunkel gleich sorgfältig gestaltet.

## 1. Grundsätze

1. **In fünf Sekunden klar.** Der Titel ist der Name der Ansicht, die Zeile darunter beantwortet die Frage der Nutzerin. Genau eine Hauptaktion je Ansicht.
2. **Nur Tokens und Muster.** Farben, Abstände, Radien, Schriftgrößen und Bewegung kommen aus `App/Sources/Kit/Design/`, Layouts aus den Mustern unter `Kit/Design/Patterns/`. `make check-design` findet Zahlen und Farben außerhalb des Kits.
3. **Einmal sagen.** Jeder Hinweis steht einmal; Titel und Untertitel sagen Verschiedenes. Kein Kasten im Kasten, keine Deko ohne Aufgabe.
4. **Ehrlich zeigen.** Was fehlt oder aus ist (keine Berechtigung, kein Modell, nichts eingerichtet), bleibt sichtbar und sagt in einem Satz, warum und was hilft.
5. **Beide Sprachen, beide Erscheinungsbilder.** Deutsch ist etwa 30 % länger; jede Ansicht passt in beiden Sprachen ohne Kürzung. Hell und dunkel sind beide entworfen, nicht abgeleitet.
6. **Mac-typisch.** Tastatur zuerst (Fokus, ⌘-Kürzel, Pfeiltasten in Listen), Kontextmenüs, Fenster merken ihre Größe, nichts fragt, was macOS selbst weiß.

## 2. Farben (`Theme`)

`Theme(scheme, accent: AppConfig.accent)` liefert jede Farbe für das aktuelle `ColorScheme`. Farben entstehen aus dem Schema von SwiftUI, nicht aus dynamischen `NSColor`, damit Renders genau wie das Fenster aussehen. In einer View: `@Environment(\.colorScheme) var scheme` und `let theme = Theme(scheme)`.

| Rolle | Tokens |
|---|---|
| Flächen | `windowBg`, `sidebarBg`, `sidebarPanel`, `card`, `field`, `chip`, `chipActive`, `segmentTrack`, `segmentSelected`, `capsuleBg` |
| Linien | `separator` (Haarlinie 0,5 pt), `cardStroke`, `windowStroke`, `sidebarPanelStroke`, `capsuleStroke`, `tileEdge`, `squircleEdge` |
| Text | `fg` (Haupttext), `fg2` (Nebentext), `fg3` (leise), `prose` (Fließtext im Onboarding), `sideGroup` (Gruppentitel der Seitenleiste) |
| Akzent | `accent` (Bedienelemente), `accentText` (Text im Akzent, 4,5:1), `ring` (Fokus, Auswahl), `onAccent` (Schrift auf Akzent), `accentSoft`, `accentGradient` |
| Zustand | `ok`, `warn`, `idle`, `okText`, `warnText`, `okSoft`, `warnSoft`, `strike` |
| Bedienelemente | `switchOff`, `trackOff`, `knob`, `knobShadow`, `buttonSecondary`, `buttonSecondaryEdge`, `buttonPrimaryEdge`, `buttonShadow`, `rowHover`, `sideSel`, `detent` |
| Renders | `glassStandIn`, `glassStroke`, `desk`, `deskShadow`, `panelShadow`, `wallpaper`, `menuBarTint`, `menuBarText`, `traffic*` |

### Akzente

Ein Projekt wählt genau einen Akzent in `starter.json` (`app.accent`). Alle Kontraste sind per Test geprüft: Text 4,5:1 auf Fenster und Karte, Ring 3:1, Füllung gegen den Aus-Zustand eines Schalters.

| Akzent | Marke | Füllung hell / dunkel | Text hell / dunkel |
|---|---|---|---|
| `violett` | #8F6CF2 | #8F6CF2 / #8F6CF2 | #6243CC / #B89EFA |
| `rot` | #FA2D48 | #FA2D48 / #FF3B55 | #B80D29 / #FF8592 |
| `blau` | #0A84FF | #0A84FF / #0A84FF | #005BBF / #5EAEFF |
| `gruen` | #249B43 | #249B43 / #249B43 | #176A2E / #4CD472 |
| `orange` | #F5900A | #C96A00 / #F5900A | #934900 / #FFB340 |
| `graphit` | #6E6E73 | #6E6E73 / #8E8E93 | #56565C / #C7C7CC |

Der Akzent färbt Bedienelemente, Auswahl, Fokus und das App-Symbol, nie große Flächen oder Fließtext. Farbige Squircle-Symbole in den Einstellungen nutzen `TintName` (`accent`, `violet`, `blue`, `sky`, `indigo`, `teal`, `green`, `yellow`, `orange`, `red`, `graphite`, `black`) wie die Systemeinstellungen.

## 3. Maße

| Token | Werte |
|---|---|
| `Space` | `hair` 2, `xxs` 4, `xs` 8, `iconGap` 9, `s` 12, `m` 16, `l` 24, `xl` 32, `xxl` 48, `pane` 20, `rowX` 12, `rowY` 9 |
| `Radius` | `keyCap` und `segment` 6, `chip` 7, `button`, `field`, `segmentTrack` 8, `row` 10, `tile` 11, `card` 13, `hero` 14, `ring` 15, `window` 16, `panel` 18, `windowGlass` 26, `squircle(size)` |
| `TypeScale` | `display` 34 fett, `intro` 28 fett, `title` 22 fett, `headline` 17 halbfett, `paneTitle` 15,5 fett, `lede` 15, `reading` 13,5, `body` 13 (auch Medium, Semibold), `preview` 12,5, `groupLabel` 12,5 halbfett, `secondary` 12, `subtitle` 11,5, `caption` 11, `badge` 10,5 halbfett, `micro` 9,5 fett |
| `Metrics` | Zeilenhöhe 44, Schalter 36 x 21, Onboarding 720 x 560, Einstellungen 900 x 620, Seitenleiste 224, Spalte im Onboarding 560 |

Raster 8, 12, 16, 24, 32. Abstände zwischen Blöcken nur aus `Space`, nie als Zahl. Radien sind durchgehend (`style: .continuous`). Linien sind Haarlinien (0,5 pt), Rahmen um jede Zeile gibt es nicht: Zeilen in einer Karte trennt `SettingsSection` mit Haarlinien.

Schrift ist immer die Systemschrift (SF Pro), Zahlen in Tabellen und Zählern mit `.monospacedDigit()`. Symbole in freier Größe über `Image.symbolFont(_:weight:)`.

## 4. Komponenten

Unter `Kit/Design/Components/`, in der Galerie und als Szenen `design.*`:

| Komponente | Zweck |
|---|---|
| `.buttonStyle(.primary)`, `.primary(minWidth:)`, `.secondary`, `.primary(_ isPrimary:)` | Knöpfe; genau ein primärer je Ansicht; `SwitchingButtonStyle` wechselt an Ort und Stelle |
| `PressStyle`, `PlainStyle` | Druckzustand für eigene Flächen |
| `Card { }` | Karte mit Rand und Fläche aus Tokens |
| `Row(title, subtitle:, symbol:, tint:, dot:) { trailing }` | Zeile mit Symbol, Titel, Untertitel und Bedienelement rechts |
| `GroupLabel`, `Separator`, `Footnote`, `SectionHeader` | Gruppentitel, Haarlinie, Fußnote, Kopf eines Abschnitts |
| `SwitchToggle`, `Segmented`, `Chip`, `Badge`, `KeyCaps` | Schalter, Segmente, Chip, Marke, Tastenkappen (⌘ ⌥ ⌃ ⇧) |
| `SquircleIcon(symbol:, tint:, size:)` | farbiges Symbol wie in den Systemeinstellungen |
| `SegmentedProgress`, `Spinner`, `StatusMark` | Schritte, laufend, Zustand mit Text |
| `EmptyState` | Symbol, Titel, ein Satz, höchstens eine Aktion |
| `GlassSurface(cornerRadius:) { }` | eigenes Glas; in Renders eine Fläche in Token-Farbe |
| `StaticWindow`, `TrafficLights`, `RenderBoard`, `Specimen` | Fensterrahmen und Schreibtisch nur für Renders |

## 5. Muster

Unter `Kit/Design/Patterns/`, als Szenen `patterns.*`. Ein Onboarding-Schritt beginnt mit `OnboardingPage`, ein Einstellungsbereich mit `PaneScaffold`; eigene Layouts nur, wenn kein Muster passt, und dann als Kandidat für das Kit gemeldet.

### Onboarding-Schritt

```swift
OnboardingPage {
    OnboardingHero(symbol: "mic.fill", tint: .orange).padding(.bottom, Space.m)
    OnboardingHeader(title: MicText.title, subtitle: MicText.why).padding(.bottom, Space.l)
    OnboardingStatusSlot(slot).padding(.bottom, Space.s)
    OnboardingHint(hintLines, key: slot.key) { action in if action == "reveal" { reveal() } }
}
```

- Inhalt mittig zwischen Titelleiste und Fußleiste, 12 pt angehoben, nie näher als 24 pt an der Oberkante (`OnboardingCentered`).
- Kopf 22 pt fett, Untertitel 13 pt in `prose`; der erste Schritt mit `large: true` (28 und 15 pt).
- Status-Slot 30 pt hoch für jeden Zustand einer Berechtigung (`action`, `waiting`, `denied`, `granted`, `restartNeeded`); Hinweisbereich fest 560 x 64 pt, wechselt mit Überblendung.
- Karten in Schritten: `SettingsSection(tone: .onboarding)` in `Metrics.onboardingColumn` (560 pt) oder schmal in `Metrics.onboardingCard` (460 pt: Sprache, Fertig, Beim Anmelden starten), darunter `OnboardingFootnote`.
- Fußleiste mit Zurück, Fortschritt in Segmenten und Weiter; hält der Slot die Hauptaktion, ist Weiter nicht primär.
- Links im Text als `[Titel](app://aktion)`; der Rest bleibt wörtlich, kein Markdown.

### Einstellungsbereich

```swift
PaneScaffold(title: AlertsText.pane, symbol: "bell.badge.fill", tint: .red, subtitle: AlertsText.intro) {
    SettingsSection(AlertsText.behavior, footnote: AlertsText.note) {
        ToggleRow(AlertsText.sounds, subtitle: AlertsText.soundsDetail, isOn: $sounds)
        PickerRow(AlertsText.style, options: [(.banner, AlertsText.banner), (.list, AlertsText.list)], selection: $style)
    }
    InlineNotice(AlertsText.offline, kind: .warning)
}
```

- Kopfband 52 pt mit Squircle-Symbol und Titel, Spalte bis 640 pt links bündig, Gruppen 20 pt auseinander.
- Zeilen: `ToggleRow`, `PickerRow` (Segmente oder Menü), `ValueRow` (mit `ValueCapsule`), `ButtonRow`, `LinkRow`, `NavigationRow`; Hover über `HoverButton`.
- Hinweise: `InlineNotice` mit `info`, `success`, `warning`, `error` und höchstens einer Aktion.
- Downloads und lange Arbeiten: `ProgressRow` mit Rolle, Name, Phase (wartet, läuft, pausiert, fertig) und Bytes über `ByteText` („1,4 von 3,0 GB“).
- Listen mit Suche: `ListCard` mit `ListSearch.matches` (Groß- und Kleinschreibung und Akzente egal), leer mit Titel und einem Satz; Zähler in der Seitenleiste mit `CountBadge`.
- Auswahl mit Vorschau: `TilePicker(tone: .settings)` als erste Zeile einer Gruppe.

## 6. App-Formen

| Form | Gestalt |
|---|---|
| Hauptfenster (`window`) | `NavigationSplitView` mit Seitenleiste aus Systemglas und Gruppen (`PageSection`), Werkzeugleiste mit Suche, Seiten mit großem Titel; Bausteine wie in Musik: Kopf mit Bild (`HeroHeader`), Reihen von Kacheln (`Shelf`), Raster (`TileGrid`), Listen mit Index und Nebeninfo (`ItemList`), erzeugte Bilder aus Text und Symbol (`Artwork`), leere Seite (`EmptyPage`) |
| Einstellungen (Kit) | eigenes Fenster 900 x 620 wie die Systemeinstellungen: Seitenleiste mit farbigen Squircle-Symbolen, oben Inhalte, darunter Einstellungen; Bereich nach dem Muster oben; die Pfeiltasten wechseln den Bereich |
| Onboarding (Kit) | Fenster 720 x 560 mit durchsichtiger Titelleiste und nur dem Schließen-Knopf, Seiten gleiten 26 pt mit Feder, unter reduzierter Bewegung Überblendung |
| Statusmenü (`menubar`) | Symbol als Vorlage, Zustände `idle`, `busy`, `attention`; Panel wie ein Modul im Kontrollzentrum: abgerundet, Glas, 320 bis 360 pt, Kopf mit App-Symbol und Statuszeile, Abschnitte, Fußzeile mit Einstellungen und Beenden |
| Insel (`island`) | wächst aus der Notch mit konkaven Ohren, schwarz (`IslandPalette`), Breite und Höhe mit getrennten Federn (`Motion.Island`); ohne Notch eine Kapsel unter der Menüleiste; Inhalte kurz: Symbol, höchstens drei Wörter Titel, eine Zeile Detail |

## 7. Bewegung

- Nur Federn aus `Motion`: `page` (Seitenwechsel), `press`, `selection`, `tile`, `toggle`, `expand`, `Motion.Island.*` für die Insel; keine linearen Animationen, keine selbst gewählten Werte.
- Reduzierte Bewegung: `Motion.adaptive(_:reduce:)` ersetzt Gleiten und Federn durch Überblendung (`Motion.reduced`, `Motion.fade`). Endlose Bewegung (Spinner, Statussymbol `busy`) ruht.
- Bewegung zeigt Ursache und Wirkung (was kommt woher), nie Deko: kein Pulsieren, kein Hüpfen, kein gestaffeltes Einblenden von Listen.

## 8. Glas und Tiefe

- Glas nur, wo das System es liefert (Seitenleiste, Werkzeugleiste, Menüs) oder über `GlassSurface` für schwebende Flächen (Statusmenü-Panel). Kein Unschärfe-Leuchten, keine farbigen Lichthöfe, keine Verläufe als Hintergrund von Inhalten.
- Gestaltete Flächen mit Verlauf gibt es an drei Stellen: Insel, Bild im Onboarding (`OnboardingHero`, Glanz im Akzent hinter dem App-Symbol) und App-Symbol. Sonst sind Flächen ruhig.
- Schatten nur aus Tokens (`panelShadow`, `buttonShadow`, `knobShadow`), nie gestapelt.
- In Renders zeichnet `GlassSurface` eine Fläche in `glassStandIn`; die echte Wirkung prüft die Person am Mac.

## 9. Texte

- Jeder sichtbare Text steht in einer `*Text.swift`-Datei als `tr(en: "…", de: "…")`; Views enthalten keine Textliterale. Mehrzahl und Platzhalter sind `static func`.
- Deutsch duzt (oder siezt, je nach `texts.anrede` in `starter.json`), Englisch spricht direkt an. Kurz und konkret: was passiert, was die Nutzerin tun kann.
- Knöpfe sind Verben (`Erlauben`, `Exportieren`, `Weiter`, `Fertig`); `…` nur, wenn danach eine Eingabe oder ein Dialog folgt. Typografische Zeichen: „…“ im Deutschen, “…” im Englischen, `…` als ein Zeichen.
- Keine Ausrufezeichen, keine Emoji, keine Floskeln (`nahtlos`, `mühelos`, `seamless`, `effortless`, `unlock`, `supercharge` und die anderen Wörter der Sprachpakete), keine Versprechen, keine erfundenen Zahlen.
- Tastenkürzel mit den Zeichen von macOS: ⌘ ⌥ ⌃ ⇧ ⇥ ⇪ ⏎ ⌫, in der Reihenfolge ⌃⌥⇧⌘.
- Berechtigungstexte (`App/Resources/InfoPlist.json`) sagen, wofür und was auf dem Mac bleibt.

## 10. Symbole

- Nur SF Symbols, ein Gewicht je Ansicht, Größe über `Image.symbolFont`. Keine eigenen Grafiken als Symbole, keine Emoji als Symbol.
- Symbole mit Info-Markierung in der App SF Symbols stehen für Apple-Produkte und dürfen nur dafür stehen.
- Das App-Symbol aus `make icon` (Fläche im Akzent mit dem SF Symbol aus `app.symbol`) ist nur für die Entwicklung: Apple untersagt SF Symbols in App-Symbolen und Logos. Vor der ersten Weitergabe bekommt die App ein eigenes Motiv (`docs/VERTEILUNG.md`).

## 11. Barrierefreiheit

- Jedes Bedienelement hat ein Label für VoiceOver, Symbole ohne Text eine Beschreibung; Zustände (an, aus, ausgewählt) werden gesprochen.
- Alles ist mit der Tastatur erreichbar; der Fokusring kommt vom System oder aus `ring`.
- Text 4,5:1 in hell und dunkel, Bedienelemente 3:1 gegen ihre Umgebung; Farbe ist nie das einzige Zeichen (Zustand zusätzlich mit Symbol oder Wort).
- Reduzierte Bewegung und erhöhter Kontrast werden respektiert.

## 12. Renders ansehen

Jede sichtbare Änderung bringt Render-Szenen mit (`RenderScene`, Kennung `<bereich>.<name>`), für jeden Zustand eine. Im Kit und in Modulen ist der Bereich das Kit-Gebiet oder Modul (`settings.`, `island.`), in einem Projekt das Feature (`notes.page`, `notes.pane`, `notes.island-saving`), damit `make shots ONLY=<feature>.` alle Szenen eines Features trifft. Vor „fertig“:

1. `make shots ONLY=<bereich>.` rendert in `build/shots/{en,de}-{light,dark}/<szene>.png`.
2. Jede Szene in allen vier Fassungen mit dem Werkzeug Read öffnen. Code lesen ersetzt kein Bild.
3. Prüfen: fünf Sekunden, eine Hauptaktion, Deutsch ohne Kürzung, gemeinsame linke Kante, Raster, hell und dunkel gestaltet, nichts doppelt, kein Kasten im Kasten, Kontrast.
4. Zum Vergleich die Beispiele `patterns.sample-pane`, `patterns.sample-step` und `patterns.sample-permission`.
5. In der Statusdatei stehen die angesehenen Szenen. Ohne Bilder gilt die Oberfläche als nicht geprüft.

Renders zeigen kein echtes Glas, keine echten Fensterrahmen, keine Insel an der echten Notch und keine Systemdialoge; das prüft die Person am Mac mit `make run`.

## 13. Was nicht vorkommt

- Lila Verläufe überall, Glühen, Blasen, Glas auf Glas, Schatten-Stapel.
- Drei gleiche Karten nebeneinander ohne Aufgabe, große leere Heldenflächen, Kennzahlen-Mosaike.
- Pillenförmige Knöpfe für alles, mehrere primäre Knöpfe, Knöpfe ohne klare Wirkung.
- Werbesprache (etwa `Willkommen in der Zukunft`), Emoji, Ausrufezeichen, Platzhaltertexte, erfundene Zahlen.
- Eigene Schriften, eigene Symbolsätze, feste Farben im Code, Systemfarben (`.purple`, `.blue`) als Gestaltung.
