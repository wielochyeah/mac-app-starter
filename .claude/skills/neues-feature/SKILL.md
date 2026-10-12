---
name: neues-feature
description: Baut eine Funktion des Projekts unter App/Sources/Features nach den Mustern des Kits (Modell, Speicher, Texte in beiden Sprachen, Ansichten aus Kit-Bausteinen, Registrierung, Render-Szenen, Tests). Nutzen, wenn ein fachlicher Bereich mit eigenen Daten, Ansichten oder Einstellungen dazukommt.
---

# Neues Feature

## Verträge und Dateien

| Vertrag | Datei | Rolle im Feature |
|---|---|---|
| Registry | `App/Sources/Kit/Core/Registry.swift` | `AppPage`, `SettingsPane`, `OnboardingStep`, `MenuItemContribution`, `RenderScene`, `GalleryEntry`, `SelfTestCheck`, `launchHooks`, `terminateHooks`, `onboardingFinishedHooks` |
| Texte | `App/Sources/Kit/Core/Lang.swift` | `tr(en:de:)`, `Localizer.shared`, `Format` für Zahlen, Dauer und Datum |
| Einstellungen | `App/Sources/Kit/Core/Settings.swift` | `SettingKey`, `Settings.shared[.schluessel]` |
| Speicher | `App/Sources/Kit/Core/Database.swift`, `Paths.swift` | `Database(url:migrations:)`, `Paths.database(_:)` |
| Design | `App/Sources/Kit/Design/` | Tokens (`Theme`, `Space`, `Radius`, `TypeScale`, `Motion`), Komponenten, Muster unter `Patterns/` |
| Aktionen | `App/Sources/Kit/Main/AppActions.swift` | `openSettings(pane:)`, `openMainWindow()`, `openOnboarding()` |
| Tests | `App/Tests/Harness/Harness.swift` | `TestSuite`, `expect`, `expectEqual`, `tempDir()` |

## Dateien eines Features

Ein Ordner `App/Sources/Features/<Name>/`, Namen auf Englisch in UpperCamelCase:

- `<Name>Feature.swift`: `enum <Name>Feature { static func register() { … } }` hängt Seiten, Einstellungsbereiche, Onboarding-Schritte, Menüeinträge, Galerie-Einträge und Render-Szenen an `Registry` an. Angemeldet wird es mit einer Zeile `<Name>Feature.register()` in `Features.register()` (`App/Sources/Features/Features.swift`); `Modules.registerAll()` ruft `Features.register()` einmal nach dem Kit und allen Modulen auf.
- `<Name>Text.swift`: `enum <Name>Text` mit jedem sichtbaren Text als `static var x: String { tr(en: "…", de: "…") }`, Mehrzahl und Platzhalter als `static func`. Keine Texte in Views.
- `<Name>Store.swift`: Zugriff auf Daten. Tabellen über `Database` mit nummerierten Migrationen (`Database.Migration(1, "CREATE TABLE …")`), Zeilen als `RowDecodable`. Kleine Vorlieben über `SettingKey`, Name mit Präfix des Features (`notes.sort`).
- `<Name>Model.swift`: `@Observable final class`, reine Logik ohne Datei- und Netzzugriff dort, wo sie testbar sein soll.
- `<Name>View.swift` und weitere Views: nur Tokens und Bausteine des Kits.
- `App/Tests/Features/<Name>Tests.swift`: Tests für jede Logik, in `#if TESTING`.

Features nutzen nur das Kit. Braucht ein Feature ein Modul (Insel, Statusmenü, Hintergrund, Kurzbefehle, KI), steht jeder Bezug in einem eigenen `#if MODUL_<NAME>` … `#endif`, ein Flag je Block, nie verschachtelt, nie mit `||` oder `&&`. So baut das Projekt auch nach `bin/starter remove <modul>`.

Solange das Modul `examples` enthalten ist, zeigt `App/Sources/Modules/Examples/` dasselbe Muster an einem vollständigen Beispiel. <!-- modul:examples -->

## Schritte

1. `docs/DESIGN.md` und `docs/ARCHITEKTUR.md` lesen; Ziel, Ansichten und Daten in `docs/PROJECT.md` (Abschnitte 3 und 4) eintragen.
2. Texte zuerst: `<Name>Text.swift` mit beiden Sprachen, Anrede wie `texts.anrede` in `starter.json`, kurz und konkret, ohne Floskeln und Ausrufezeichen. Deutsch ist etwa 30 % länger; Layouts müssen das tragen.
3. Daten und Logik mit Tests: Erwartungswerte aus der Anforderung oder einer Handrechnung, eingespeiste Uhr statt `Date()` in Logik, die Zeit braucht.
4. Ansichten und Bezüge zu Modulen mit dem passenden Skill:
   - Einstellungsbereich: `neue-einstellung`
   - Onboarding-Schritt: `neuer-onboarding-schritt`
   - Berechtigung: `neue-berechtigung`
   - Seite im Hauptfenster: `neue-ansicht` <!-- modul:window -->
   - Abschnitt im Statusmenü: `menueleisten-app` <!-- modul:menubar -->
   - Rückmeldung in der Insel: `insel-zustand` <!-- modul:island -->
   - geplante Aufgabe: `hintergrund-job` <!-- modul:background -->
   - globaler Kurzbefehl: `kurzbefehl` <!-- modul:hotkeys -->
   - lokale KI: `ki-funktion` <!-- modul:ai -->
5. In `register()` für jeden sichtbaren Zustand eine `RenderScene` mit Kennung `<feature>.<zustand>` und Beispieldaten anlegen, die echt wirken, aber erfunden sind. Neue allgemeine Bausteine zusätzlich als `GalleryEntry`.
6. Was beim Start laufen muss, in `Registry.launchHooks`; was beim Beenden aufräumen muss, in `Registry.terminateHooks`; was nach „Fertig“ in der Einrichtung geschehen soll, in `Registry.onboardingFinishedHooks` (`{ firstTime in … }`). Nichts startet Fenster oder fragt Berechtigungen an, wenn `RenderMode.isHeadless` gilt.
7. Prüfbare Annahmen zur Laufzeit (Datei lesbar, Migration aktuell) als `SelfTestCheck` eintragen.
8. Sobald das erste eigene Feature steht: `bin/starter strip-examples`. <!-- modul:examples -->

## Prüfen

- `make check` (Regeln, Texte, Design, Kit, Build, Tests).
- `make build MODULES=<kombination>` für jede Kombination, die das Projekt nutzt, und `STARTER_HEADLESS=1 build/<Name>.app/Contents/MacOS/<Name> --selftest`.
- `make shots ONLY=<feature>.` und jedes Bild in `build/shots/{en,de}-{light,dark}/` mit dem Werkzeug Read ansehen (Skill `screenshots`).
- Gegenprüfung mit dem Skill `red-team`.

## In einem Projekt

`App/Sources/Features/**`, `App/Tests/Features/**` und `docs/PROJECT.md` gehören dem Projekt, `App/Sources/Kit/**` dem Starter (`starter.manifest.json`). Fehlt im Kit ein Baustein, steht der Bedarf in `docs/STARTER_FEEDBACK.md` (Skill `starter-rueckfluss`); bis dahin entsteht er im Feature-Ordner.
