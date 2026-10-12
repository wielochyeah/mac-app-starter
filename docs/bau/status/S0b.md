# Status S0b (gemeinsame UI-Muster)

Stand: 2026-10-12, Branch `main`. Gebaut ist `App/Sources/Kit/Design/Patterns/`: fertige Bausteine für das Onboarding-Fenster (Strang D), den Einstellungs-Hub (Strang E) und die Onboarding-Schritte und Einstellungsbereiche jedes Moduls. Wer diese Muster nutzt, sieht automatisch aus wie VoiceBud (Maße aus `vb-onboarding-hub.md` §2.7, §3–§4, Technik aus VoiceBud `ui/Onboarding.swift` und `ui/Hub.swift`).

**Regel für alle Stränge:** Ein Onboarding-Schritt beginnt mit `OnboardingPage`, ein Einstellungsbereich mit `PaneScaffold`; Gruppen sind `SettingsSection`, Zeilen sind die `…Row`-Muster unten. Eigene Layouts nur, wenn kein Muster passt (dann im Statusbericht als Kandidat melden).

## Dateien

| Datei | Inhalt |
|---|---|
| `Patterns/PatternTokens.swift` | Zusatz-Tokens als Extensions von `Metrics`, `Space`, `Radius`, `TypeScale`, `Theme` (Slot 30, Hinweis 560 x 64, Anheben 12, Mindestabstand 24, Hero 672 x 200, Kachelhöhen 56/86, Fortschrittsbalken 4 / Einzug 40, Suchfeld 236 x 28, Hinweisfeld-Radius 12 …) |
| `Patterns/PatternsText.swift` | `PatternsText` (eingebaute Wörter: Freigabe erteilen, Erteilt, Abgelehnt, Wirkt nach Neustart, Bereit, Pausiert, „x von y“, Keine Treffer …) und `PatternsSampleText` (Texte der Beispielszenen) |
| `Patterns/OnboardingPage.swift` | `OnboardingCentered`, `OnboardingPage`, `OnboardingFrame`, `OnboardingHeader`, `OnboardingNote`, `OnboardingFootnote`, `OnboardingHint`, `OnboardingHero` |
| `Patterns/OnboardingStatusSlot.swift` | `OnboardingSlotState`, `OnboardingStatusSlot` |
| `Patterns/OnboardingFooter.swift` | `OnboardingFooter` |
| `Patterns/TilePicker.swift` | `TileOption`, `TilePicker` (= `OnboardingTilePicker`) |
| `Patterns/RichText.swift` | `OnboardingRichText`, `RichTextLinks` |
| `Patterns/PaneScaffold.swift` | `PaneScaffold`, `PaneIntro`, `PaneScroll`, `SettingsColumn`, `SettingsSection`, `\.textTone` |
| `Patterns/SettingsRows.swift` | `ToggleRow`, `PickerRow` (+ `PickerRowStyle`), `MenuPicker`, `ValueRow`, `ValueCapsule`, `ButtonRow` (+ `ButtonRowStyle`), `LinkRow`, `NavigationRow`, `HoverButton` |
| `Patterns/InlineNotice.swift` | `InlineNotice` |
| `Patterns/ProgressRow.swift` | `ProgressRow`, `ProgressBar`, `ByteText` |
| `Patterns/ListCard.swift` | `ListCard`, `ListSearch`, `SearchField`, `CountBadge` |
| `Patterns/PatternsCatalog.swift` | `PatternsKit.register()` (Galerie + Szenen), Beispiele |
| `App/Tests/PatternsTests.swift` | 12 Tests |

## API (genaue Signaturen)

```swift
// MARK: Onboarding
nonisolated struct OnboardingCentered: Layout {          // Kind mittig zwischen Titelleiste und Fußleiste,
    var minTop: CGFloat = Metrics.onboardingMinTop       // 12 pt angehoben, nie näher als 24 pt an oben
    var lift: CGFloat = Metrics.onboardingLift
    static func top(content: CGFloat, available: CGFloat, minTop: CGFloat = 24, lift: CGFloat = 12) -> CGFloat
}
struct OnboardingPage<Content: View>   { init(@ViewBuilder content: () -> Content) }   // VStack(spacing: 0) + 32 pt Titelleiste
struct OnboardingFrame<Page: View, Footer: View> { init(@ViewBuilder page: () -> Page, @ViewBuilder footer: () -> Footer) } // 720 x 560
struct OnboardingHeader  { init(title: String, subtitle: String? = nil, large: Bool = false) }   // 22 bold + 13 prose; large = 28 + 15
struct OnboardingNote    { init(_ text: String, perform: @escaping (String) -> Void = { _ in }) }  // eine Zeile 12 prose, zentriert
struct OnboardingFootnote { init(_ text: String, lines: Int = 1, perform: @escaping (String) -> Void = { _ in }) } // reserviert lines*16
struct OnboardingHint {                                   // fester Bereich 560 x 64, Zeilen zentriert, wechselt per Überblendung
    init(_ lines: [String], key: String? = nil, perform: @escaping (String) -> Void = { _ in })
    init(_ line: String, key: String? = nil, perform: @escaping (String) -> Void = { _ in })
}
struct OnboardingHero<Art: View> {
    init(size: CGSize = Metrics.heroArt, framed: Bool = true, @ViewBuilder art: () -> Art)   // eigenes Bild, 672 x 200, Radius 14
}
extension OnboardingHero where Art == EmptyView { init(symbol: String, tint: TintName = .accent) }  // 64-pt-Squircle mit Schatten

struct OnboardingSlotState {
    enum Kind: String { case action, waiting, denied, granted, restartNeeded }
    struct SlotButton { let title: String; let action: () -> Void }
    let kind: Kind; let text: String; let button: SlotButton?; let helpLink: SlotButton?
    var key: String                                       // wechselt mit jedem sichtbaren Zustand
    static func action(_ title: String = PatternsText.allowAccess, perform: @escaping () -> Void) -> Self
    static func waiting(_ text: String = PatternsText.waitingForAnswer, button: SlotButton? = nil) -> Self
    static func denied(_ text: String = PatternsText.denied, button: SlotButton? = nil, helpLink: SlotButton? = nil) -> Self
    static func granted(_ text: String = PatternsText.granted) -> Self
    static func restartNeeded(_ text: String = PatternsText.afterRestart, buttonTitle: String = PatternsText.restartApp,
                              restart: @escaping () -> Void) -> Self
}
extension OnboardingSlotState.SlotButton { static func openSettings(_ open: @escaping () -> Void) -> Self } // "Systemeinstellungen öffnen"
struct OnboardingStatusSlot { init(_ state: OnboardingSlotState) }   // 30 pt hoch; Primärknopf trägt .defaultAction

struct OnboardingFooter {
    init(count: Int, index: Int, advanceTitle: String = CommonText.continue, advanceIsPrimary: Bool = true,
         canAdvance: Bool = true, back: (() -> Void)?, advance: @escaping () -> Void)   // back nil = kein Zurück
}

struct TileOption<Value: Hashable> { init(_ value: Value, title: String, detail: String? = nil, badge: String? = nil) }
struct TilePicker<Value: Hashable, Preview: View> {
    init(_ options: [TileOption<Value>], selection: Binding<Value>, previewHeight: CGFloat = Metrics.tilePreview,
         tone: TextTone = .onboarding, @ViewBuilder preview: @escaping (Value) -> Preview)
    static func step(from current: Value, by offset: Int, in values: [Value]) -> Value   // ←/→, an den Enden begrenzt
}
typealias OnboardingTilePicker<Value: Hashable, Preview: View> = TilePicker<Value, Preview>

struct OnboardingRichText { init(_ text: String, perform: @escaping (String) -> Void = { _ in }) }
enum RichTextLinks {
    static let scheme = "app"
    enum Part: Equatable { case text(String); case link(title: String, action: String); var isLink: Bool }
    static func parse(_ text: String) -> [Part]
    static func action(of url: URL) -> String?
    static func attributed(_ parts: [Part]) -> AttributedString
}

// MARK: Einstellungen
struct PaneScaffold<Content: View, Trailing: View> {
    enum Layout { case column, fill }
    init(title: String, symbol: String? = nil, tint: TintName = .accent, subtitle: String? = nil, layout: Layout = .column,
         @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content)
}
extension PaneScaffold where Trailing == EmptyView {
    init(title: String, symbol: String? = nil, tint: TintName = .accent, subtitle: String? = nil, layout: Layout = .column,
         @ViewBuilder content: () -> Content)
}
struct PaneIntro { init(_ text: String) }                                  // 12.5 fg2 unter dem Kopfband
struct PaneScroll<Content: View> { init(@ViewBuilder content: () -> Content) }   // ScrollView; statisch in Renders
struct SettingsColumn<Content: View> { init(@ViewBuilder content: () -> Content) } // max 640, links, Kinder 20 pt auseinander
struct SettingsSection<Content: View> {
    init(_ title: String? = nil, footnote: String? = nil, footnoteLines: Int = 0, tone: TextTone = .settings,
         @ViewBuilder content: () -> Content)                               // Haarlinien zwischen Zeilen automatisch
}
extension EnvironmentValues { var textTone: TextTone }                      // SettingsSection setzt ihn, Zeilen lesen ihn
extension View { func tone(_ tone: TextTone) -> some View }

struct ToggleRow { init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, isOn: Binding<Bool>) }
enum PickerRowStyle { case segmented, menu }
struct PickerRow<Value: Hashable> {
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent,
         options: [(value: Value, title: String)], selection: Binding<Value>, style: PickerRowStyle = .segmented)
}
struct MenuPicker<Value: Hashable> { init(_ options: [(value: Value, title: String)], selection: Binding<Value>) }
struct ValueRow { init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, value: String, capsule: Bool = false) }
struct ValueCapsule { init(_ text: String) }
enum ButtonRowStyle { case chip, secondary, primary }
struct ButtonRow {
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, button: String,
         buttonSymbol: String? = nil, style: ButtonRowStyle = .chip, action: @escaping () -> Void)
}
struct LinkRow {
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, action: @escaping () -> Void)
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, url: URL)   // NSWorkspace.open
}
struct NavigationRow {
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, value: String? = nil,
         action: @escaping () -> Void)
}
struct HoverButton<Label: View> { init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) }   // ganze Zeile, rowHover

struct InlineNotice {
    enum Kind { case info, success, warning, error }
    init(_ text: String, title: String? = nil, kind: Kind = .info, actionTitle: String? = nil, action: (() -> Void)? = nil,
         perform: @escaping (String) -> Void = { _ in })                    // text darf app://-Links enthalten
}

struct ProgressRow {
    enum Phase: Equatable {
        case waiting(total: Int64); case running(done: Int64, total: Int64)
        case paused(done: Int64, total: Int64); case done(total: Int64)
        var fraction: Double? { get }
    }
    init(role: String, name: String, symbol: String, tint: TintName = .accent, phase: Phase, retry: (() -> Void)? = nil)
}
struct ProgressBar { init(fraction: Double, tint: Color? = nil) }           // 4 pt, Füllung min. 4 pt
enum ByteText {
    enum Unit { case kb, mb, gb }
    static func unit(for bytes: Int64) -> Unit
    static func size(_ bytes: Int64) -> String                 // "0,9 GB", "820 MB" (dezimal wie Finder, geschütztes Leerzeichen)
    static func progress(done: Int64, total: Int64) -> String  // "1,4 von 3,0 GB"
    static func value(_ bytes: Int64, in unit: Unit) -> String
    static func name(_ unit: Unit) -> String
}

struct ListCard<Item: Identifiable, RowContent: View> {
    init(_ title: String, items: [Item], query: Binding<String>? = nil, searchPrompt: String = CommonText.search,
         matches: ((Item, String) -> Bool)? = nil, emptyTitle: String, emptyMessage: String? = nil,
         previewHovered: Item.ID? = nil, @ViewBuilder row: @escaping (_ item: Item, _ hovered: Bool) -> RowContent)
}
enum ListSearch {
    static func matches(_ fields: String..., query: String) -> Bool
    static func matches(_ fields: [String], query: String) -> Bool    // jedes Wort, Groß/Klein und Akzente egal
}
struct SearchField { init(text: Binding<String>, prompt: String = CommonText.search, size: CGSize = Metrics.searchField) }
struct CountBadge { enum Style { case plain, pill }; init(_ count: Int?, style: Style = .plain) }

// Erweiterungen in Components (siehe "Außerhalb meines Strangs")
StatusMark(_ kind:, _ text:, large: Bool = false)          // large: Haken 15, Text 13, ohne festen 16-pt-Platz
struct SwitchingButtonStyle: ButtonStyle { var primary: Bool; var minWidth: CGFloat }
.buttonStyle(.primary(_ primary: Bool, minWidth: CGFloat = Metrics.buttonMinWidth))   // wechselt an Ort und Stelle, animiert
```

## So benutzt du die Muster

**Onboarding-Schritt** (Strang D liefert Fenster, Fluss und Übergänge; Module liefern nur den Seiteninhalt):

```swift
OnboardingPage {
    OnboardingHero(symbol: "mic.fill", tint: .orange).padding(.bottom, Space.m)
    OnboardingHeader(title: MyText.title, subtitle: MyText.why).padding(.bottom, Space.l)
    OnboardingStatusSlot(slot).padding(.bottom, Space.s)
    OnboardingHint(hintLines, key: slot.key) { action in if action == "reveal" { reveal() } }
}
```
- Abstände zwischen Blöcken nur `Space.xs/s/m/l` (8/12/16/24) als `.padding(.bottom, …)`.
- Karten auf Schritten: `SettingsSection(tone: .onboarding) { … }` mit `.frame(width: Metrics.onboardingColumn)` (560) oder `Metrics.onboardingNarrow + 60` (460, Sprache); darunter `OnboardingFootnote(_, lines:)`.
- Ein Primärknopf je Ansicht: hält der Slot die Aktion (`.action`, `.restartNeeded`), bekommt `OnboardingFooter` `advanceIsPrimary: false`.
- Strang D: Root-View = `OnboardingFrame { ZStack { step.id(…).transition(…) } } footer: { OnboardingFooter(…) }`; Renders zusätzlich in `RenderBoard { StaticWindow(size: Metrics.onboardingWindow, chrome: .onboarding) { … } }`.
- Links im Text: `[Im Finder zeigen](app://reveal)`; Aktion klein, nur a-z, 0-9, `-`. Alles andere bleibt wörtlicher Text (kein Markdown).

**Einstellungsbereich** (Strang E liefert Fenster und Seitenleiste; jeder Bereich ist):

```swift
PaneScaffold(title: MyText.pane, symbol: "bell.badge.fill", tint: .red, subtitle: MyText.intro) {
    SettingsSection(MyText.behavior, footnote: MyText.note) {
        ToggleRow(MyText.sounds, subtitle: MyText.soundsDetail, isOn: $sounds)
        PickerRow(MyText.style, options: [(.a, MyText.a), (.b, MyText.b)], selection: $style)
        if advanced { ValueRow(MyText.duration, value: Format.seconds(d), capsule: true) }
    }
    InlineNotice(MyText.offline, kind: .warning)
}
```
- Ein Suchfeld oben rechts: `PaneScaffold(…) { SearchField(text: $q) } content: { … }`; eigene Liste mit eigenem Scrollen: `layout: .fill`.
- Kacheln in Einstellungen: `TilePicker(…, tone: .settings)` als erste „Zeile“ einer `SettingsSection`.
- Download-Zeilen (Strang H): `ProgressRow(role:name:symbol:tint:phase:retry:)` in einer `SettingsSection`, Byte-Zahlen über `ByteText`.
- Listen (Hintergrund-Jobs, Apps, Begriffe): `ListCard` mit `ListSearch.matches` als `matches`.
- Seitenleisten-Zähler (Strang E): `CountBadge(n)`.

## Szenen und Galerie

Jedes Muster hat einen `GalleryEntry` (Bereich `patterns`) und eine Szene `patterns.<name>`: `onboarding-page`, `onboarding-header`, `onboarding-hero`, `onboarding-footnote`, `onboarding-hint`, `onboarding-status-slot`, `onboarding-tile-picker`, `onboarding-rich-text`, `onboarding-footer`, `pane-scaffold`, `settings-section`, `toggle-row`, `picker-row`, `value-row`, `button-row`, `link-row`, `navigation-row`, `inline-notice`, `progress-row`, `list-card`, `count-badge`, `search-field`, und die zusammengesetzten Beispiele nur aus Mustern: `sample-pane` (ganzer Bereich „Allgemein“), `sample-step` (Sprach-Schritt wie VoiceBud `setup-language.png`), `sample-permission` (Bedienungshilfen, wartet auf den Schalter).

`design.sample-settings` und `design.sample-onboarding` sind entfernt (samt ihrer nicht mehr genutzten `DesignText`-Texte); die neuen Beispiele ersetzen sie. `DesignKit.register()` ruft `PatternsKit.register()` auf.

## Entscheidungen

- **Ein `TilePicker` für beide Orte**, `tone:` wählt Onboarding- (12 prose, Einzug 12) oder Hub-Maße (12,5 fg2, 12/13/11). `OnboardingTilePicker` ist ein Typalias. Auswahl als `Binding` statt VoiceBuds Wert + Closure. Tastatur: fokussierbar, ←/→.
- **`SettingsSection` setzt Haarlinien selbst** (`Group(subviews:)`, macOS 15+), auch um bedingte Zeilen. Gruppenabstand 20 kommt aus `SettingsColumn` (Stapelabstand), nicht aus `GroupLabel(top:)`.
- **Ton über die Umgebung** (`\.textTone`): eine `SettingsSection(tone: .onboarding)` stellt alle Zeilen darin auf 12 pt `prose`.
- **Rich Text ohne Markdown**: eigener Parser statt `LocalizedStringKey`, nur `[Titel](app://aktion)` wird Link; der Rest bleibt wörtlich (VoiceBud musste dafür zwischen `Text(verbatim:)` und Markdown umschalten).
- **`MenuPicker`** ist ein SwiftUI-Knopf im Kit-Look mit System-`Menu` (in Renders nur der Knopf), weil AppKit-Popups offscreen nicht zeichnen.
- **Byte-Größen dezimal** (1 GB = 10⁹ Byte, wie Finder), Zahlen über `Format.decimal` in der UI-Sprache, Einheit mit geschütztem Leerzeichen.
- **`OnboardingCentered` ist `nonisolated`** (Layout-Methoden sind nicht MainActor); die beiden Werte `Metrics.onboardingLift/MinTop` sind deshalb `nonisolated static let`.
- **Tokens der Muster** liegen als Extensions in `Patterns/PatternTokens.swift`, nicht in `Tokens.swift`/`Theme.swift`, damit die Grunddateien klein bleiben. Sie sind trotzdem unter `Kit/Design/` und für alle Stränge nutzbar.

## Aus VoiceBud übernommen (für THIRD_PARTY_NOTICES, MIT, Copyright (c) 2026 Anas Riad)

`OnboardingCentered`, `OnboardingPage`, `OnboardingHeader`, `OnboardingFootnote(lines:)`, `OnboardingRichText` (Idee: Link-Schema über `OpenURLAction`), `OnboardingFooter`, `OnboardingTilePicker`/`HubTilePicker` (ein Ring mit `matchedGeometryEffect`), Slot- und Hinweisbereich aus `OnboardingPermissionStep` (Zustände, 30 pt, 560 x 64, stateKey-Übergang), `OnboardingStatus(large:)`, `OnboardingSpeedHint` → `InlineNotice`, `OnboardingModelRow`/`OnboardingProgressBar` → `ProgressRow`/`ProgressBar`, `HubPaneHeader` + `HubScroll` + `HubSettingsColumn` → `PaneScaffold`/`PaneScroll`/`SettingsColumn`, `HubValueCapsule` → `ValueCapsule`, Suchfeld, Zähler, Hover-Zeilen und leere Zustände aus `HubHistoryPane`/`HubSidebar` → `SearchField`, `CountBadge`, `ListCard`.

## Außerhalb meines Strangs angefasst (S0-Dateien, nur additiv)

- `Kit/Design/Components/Controls.swift`: `StatusMark` bekommt `large: Bool = false` (VoiceBud `OnboardingStatus(large:)`); die feste 16-pt-Markenbreite gilt nur noch ohne `large`. Bestehende Aufrufe unverändert.
- `Kit/Design/Components/Buttons.swift`: neu `SwitchingButtonStyle` und `.primary(_ primary: Bool, minWidth:)` (Fußleisten-„Weiter“ wechselt primär/sekundär animiert an Ort und Stelle).
- `Kit/Design/DesignCatalog.swift`: `design.sample-settings`/`design.sample-onboarding` entfernt, Aufruf `PatternsKit.register()`.
- `Kit/Texts/DesignText.swift`: die nur von den entfernten Beispielen genutzten Texte gelöscht (u. a. `setupHint`; die Ausnahme dafür in S0.md für `check_texts.py` entfällt, dafür steht jetzt `PatternsSampleText.languageCrossHint` absichtlich in der anderen Sprache).

## Hinweise für Strang G (Prüfskripte)

- `check_texts.py`: `PatternsSampleText.languageCrossHint` ist absichtlich vertauscht (VoiceBud-Muster). Marken-/Modellnamen in Beispielen (`"Qwen 3, 4B"`, `"GB"`/`"MB"`/`"KB"` in `ByteText.name`) sind keine Übersetzungsfälle.
- `check_design.py`: `Kit/Design/` ist ausgenommen; die Beispielszenen in `PatternsCatalog.swift` nutzen einzelne feste Maße für Vorschau-Grafiken.

## Bekannte Lücken

- Kein Schieberegler-Muster (VoiceBud `HubDetentSlider`); `ValueRow(capsule: true)` zeigt nur den Wert. Kandidat für später, falls ein Modul ihn braucht.
- Kein Muster für große Tastenkappen (VoiceBud `OnboardingBigKeys`) und keine Seitenleiste: Seitenleiste ist Strang E.
- Hover, Fokus auf `TilePicker` und der echte `Menu`-Popup von `MenuPicker` sind nur gebaut, nicht interaktiv ausprobiert (Regel §2.17: App nie normal gestartet). Renders zeigen Hover über `ListCard(previewHovered:)`.
- Barrierefreiheit: Labels/Traits gesetzt (Schalter, Auswahl, Kacheln, Links, Hinweisart), nicht mit VoiceOver geprüft.

## Prüfung (2026-10-12)

```
make build                                   -> grün (window,menubar,island,background,hotkeys,ai,examples), 0 Warnungen
make build MODULES=menubar                   -> grün
make build MODULES=window                    -> grün
make build MODULES=window,menubar,island,background,hotkeys,ai,mlx,examples -> grün
make build CONFIG=release                    -> grün
STARTER_HEADLESS=1 …/Starter --selftest      -> "selftest: 8 checks, 0 failures", exit 0, kein Prozess bleibt
make test                                    -> "67 tests, 0 failures" (12 neue in PatternsTests) + Python "Ran 11 tests … OK"
MODULES=menubar make test                    -> "67 tests, 0 failures"
make shots ONLY=patterns.                    -> 100 PNGs (25 Szenen × en/de × hell/dunkel)
make shots                                   -> 188 PNGs + index.html
make check                                   -> grün (fehlende Prüfskripte von G/K übersprungen)
```

PatternsTests: Rechnung von `OnboardingCentered` (Mitte, Anheben, Mindestabstand, Runden) und Platzierung im echten Render (Pixelzeile), Link-Parser (gültige, kaputte und fremde Links, Klammern davor, URL-Rundweg, AttributedString), `ByteText` en/de, `ProgressRow.Phase.fraction`, `ListSearch`, `TilePicker.step`, eindeutige Slot-Keys, jede Szene + Galerie vorhanden und alte Beispiele weg, jede `patterns.*`-Szene rendert in beiden Erscheinungen mit deckenden Rändern.

Angesehen (Read) und mit VoiceBud verglichen: `patterns.sample-step` en-light gegen `docs/screenshots/setup-language.png` (Squircle, Titel, Untertitel, Hinweis in der anderen Sprache, Karte 460 breit, Fußnote, Fußleiste: gleiche Anordnung und Abstände), `patterns.sample-pane` en-light und de-dark gegen `hub-allgemein.png` (Kopfband 52 mit Squircle, Spalte links bündig, Gruppentitel, Karten, Segmente, Schalter), `patterns.onboarding-tile-picker` de-dark gegen `hub-insel.png` (ein Ring, Titel fett bei Auswahl), `patterns.sample-permission` de-light, `patterns.onboarding-status-slot` de-dark und en-light, `patterns.list-card` en-dark, `patterns.onboarding-page` de-dark, `patterns.pane-scaffold` en-light, `patterns.onboarding-footer` de-light, `patterns.inline-notice` de-dark, `patterns.progress-row` en-light, `patterns.onboarding-rich-text` de-light. Behoben nach dem Ansehen: zu großer Abstand zwischen Punkt und Text im Slot (feste 16-pt-Breite nur noch ohne `large`), Suchfeld in leerer Liste ausgeblendet, Beispielbereich auf Inhaltshöhe gekürzt.
