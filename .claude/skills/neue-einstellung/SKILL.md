---
name: neue-einstellung
description: Legt eine Einstellung mit typisiertem Schlüssel an und zeigt sie in einem Bereich des Einstellungsfensters (SettingKey, PaneScaffold, SettingsSection, Zeilenmuster, beide Sprachen, Render-Szene, Test). Nutzen, wenn die App etwas Einstellbares bekommt oder einen eigenen Einstellungsbereich braucht.
---

# Neue Einstellung

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Schlüssel | `App/Sources/Kit/Core/Settings.swift` | `SettingKey<Value>(_ name:, default:)`, `Settings.shared[.key]`, `reset(_:)`, `hasValue(_:)` |
| Bereich | `App/Sources/Kit/Core/Registry.swift` | `SettingsPane(id:group:order:title:symbol:tint:content:)`, Gruppen `.content` (oben) und `.settings` (unten) |
| Muster | `App/Sources/Kit/Design/Patterns/PaneScaffold.swift`, `SettingsRows.swift`, `InlineNotice.swift`, `TilePicker.swift`, `ProgressRow.swift`, `ListCard.swift` | `PaneScaffold`, `SettingsSection`, `ToggleRow`, `PickerRow`, `ValueRow`, `ButtonRow`, `ConfirmRow`, `LinkRow`, `NavigationRow`, `InlineNotice`, `TilePicker`, `ListCard` |
| Deep Link | `App/Sources/Kit/Main/AppActions.swift` | `AppActions.openSettings(pane: "<id>")` |
| Zurücksetzen | `App/Sources/Kit/Settings/GeneralPane.swift` | `SettingsReset.keep(_:)` für Zustände, `SettingsReset.didReset` für Werte im Speicher |

Einstellungen liegen als JSON in `~/Library/Application Support/<bundleId>/settings.json`, atomar geschrieben, unbekannte Schlüssel bleiben erhalten, kaputte Werte fallen auf den Standard zurück.

## Schritte

1. Schlüssel neben dem Code, dem er gehört:

   ```swift
   extension SettingKey {
       static var notesSort: SettingKey<String> { .init("notes.sort", default: "date") }
   }
   ```

   Name mit Präfix des Besitzers (`notes.`, `island.`), nie ein Name, den ein anderes Modul nutzt. Eigene Werttypen sind `nonisolated struct …: Codable, Sendable` (Swift 6 mit MainActor als Standard).
2. Nur Einstellungen, die wirklich wirken. Jede Einstellung greift sofort; wer sie liest, beobachtet `Settings.shared` (in SwiftUI automatisch, außerhalb über `Observing.track`). Einstellung oder Zustand? „Einstellungen zurücksetzen“ (Bereich „Allgemein“) entfernt jeden Schlüssel. Hält er keinen gewählten Wert, sondern einen Zustand (wo die Person war, was schon geschehen ist), meldet `register()` ihn mit `SettingsReset.keep("notes.lastOpened")` an (ein Präfix wie `"notes.state."` geht auch, E-23). Wer Werte im Speicher hält, liest sie in `SettingsReset.didReset.append { … }` neu.
3. Bereich bauen:

   ```swift
   let sort = Binding(get: { Settings.shared[.notesSort] }, set: { Settings.shared[.notesSort] = $0 })
   PaneScaffold(title: NotesText.pane, symbol: "note.text", tint: .yellow, subtitle: NotesText.paneIntro) {
       SettingsSection(NotesText.order, footnote: NotesText.orderNote) {
           PickerRow(NotesText.sort, options: [("date", NotesText.byDate), ("title", NotesText.byTitle)],
                     selection: sort)
       }
   }
   ```

   Gruppen sind `SettingsSection`, Zeilen die Muster; Haarlinien setzt `SettingsSection` selbst. Eine Aktion, die sich nicht rückgängig machen lässt (zurücksetzen, löschen), fragt an Ort und Stelle: die Zeile mit dem Knopf weicht mit `Motion.expand` einer `ConfirmRow(titel, text:, button:, cancel:, confirm:)`, wie in „Allgemein“ bei „Einstellungen zurücksetzen“. Ein Suchfeld steht im Kopfband (`PaneScaffold(…) { SearchField(text: $query) } content: { … }`), Listen mit eigenem Scrollen nutzen `layout: .fill`.
4. Registrieren: `Registry.settingsPanes.append(SettingsPane(id: "notes", group: .settings, order: 100, title: { NotesText.pane }, symbol: "note.text", tint: .yellow, content: { AnyView(NotesPane()) }))`. Funktionen des Projekts nehmen `order` 100 bis 199 in Zehnerschritten; „Allgemein“ hat 0, „Über“ 1000, die Module ihre eigenen Bereiche (Tabelle „Reihenfolge in der Registry“ in `docs/MODULE.md`). Zwei Bereiche teilen sich nie einen Wert.
5. Texte in `<Name>Text.swift`, beide Sprachen; Fußnoten erklären Folgen in einem Satz.
6. Render-Szene `<feature>.pane` mit Beispielwerten; bei Zuständen (Berechtigung fehlt, nichts eingerichtet) je eine Szene.
7. Test: Standardwert, Schreiben und Lesen über `Settings(fileURL:)` in einem `tempDir()`, kaputter Wert fällt auf den Standard.

## Prüfen

- `make check`.
- `make shots ONLY=<feature>.` und `make shots ONLY=settings.`, alle Szenen in allen vier Fassungen mit dem Werkzeug Read ansehen; mit `patterns.sample-pane` vergleichen.
- Gegenprüfung mit dem Skill `red-team`.
