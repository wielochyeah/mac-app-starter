---
name: kurzbefehl
description: Legt einen globalen Kurzbefehl an, den die Nutzerin ändern kann (HotkeyCenter.shared.register mit Standard und Aktion, Regeln gegen belegte und tippende Kombinationen, Eintrag im Bereich Kurzbefehle, optional im Onboarding). Nutzen, wenn eine Funktion aus jeder App heraus per Tastatur erreichbar sein soll. Gehört zum Modul hotkeys.
---

# Kurzbefehl

Gehört zum Modul `hotkeys`; `bin/starter remove hotkeys` entfernt diesen Skill mit dem Modul. Code außerhalb von `App/Sources/Modules/Hotkeys/`, der Kurzbefehle anmeldet, steht in `#if MODUL_HOTKEYS` … `#endif`.

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Anmelden | `App/Sources/Modules/Hotkeys/HotkeyCenter.swift` | `HotkeyCenter.shared.register(id:title:subtitle:default:order:showInOnboarding:onRelease:action:)`, nur `id`, `title`, `default` und `action` sind Pflicht; Änderungen der Nutzerin liegen in den Einstellungen und greifen ohne Neustart |
| Kombination | `KeyCombo` | `KeyCombo(keyCode:modifiers:)` mit virtuellem Tastencode (`kVK_*` aus Carbon, gleich auf jeder Belegung) und `KeyModifiers` (`.command`, `.shift`, `.option`, `.control`), Anzeige mit ⌃⌥⇧⌘ und dem Tastennamen der aktuellen Tastaturbelegung |
| Regeln | `ShortcutRules` | lehnt Kurzbefehle des Systems, Standardbefehle von Apps (⌘W, ⌘Q, ⌃A …), Kombinationen, die auf der Belegung ein Zeichen tippen (⌥L ergibt @ auf deutscher Tastatur), und Doppelungen innerhalb der App ab; jede Ablehnung nennt den Grund und schlägt eine freie Variante vor |
| Oberfläche | Bereich „Kurzbefehle“, `ShortcutRecorder`, Onboarding-Schritt „Kurzbefehl“ (order 600) | Aufnehmen, Prüfen, Standard wiederherstellen |

Technisch läuft das über Carbon `RegisterEventHotKey`; das braucht keine Berechtigung für Eingabeüberwachung.

## Schritte

1. Braucht die Funktion wirklich einen globalen Kurzbefehl? Befehle, die nur im Fenster der App gelten, sind Menüeinträge mit Tastenkürzel (`MenuItemContribution.shortcut`).
2. Standard wählen, der die Regeln besteht: mindestens zwei Umschalttasten, darunter ⌃ oder ⌘, keine Belegung des Systems. Vorher im Test gegen `ShortcutRules` prüfen.
3. Anmelden im `register()` des Features:

   ```swift
   #if MODUL_HOTKEYS
   HotkeyCenter.shared.register(id: "capture.start", title: { CaptureText.hotkeyTitle },
                                default: KeyCombo(keyCode: UInt16(kVK_Space), modifiers: [.control, .option])) {
       Capture.start()
   }
   #endif
   ```

   Kennung mit Präfix des Features; Titel als Tätigkeit.
4. Die Aktion kehrt schnell zurück und stößt die Arbeit nur an; sie öffnet kein Fenster, ohne die App zu aktivieren.
5. Ein Kurzbefehl, der in Renders oder Tests gebraucht wird, wird nur dort angemeldet, nie im Produktionscode für die Vorschau.
6. Render-Szenen: `hotkeys.pane` zeigt alle Kurzbefehle; ist der neue Befehl der wichtigste der App, `showInOnboarding: true` und `hotkeys.onboarding` ansehen.

## Prüfen

- `make check`, `make test ONLY=Hotkey` (Regelwerk), `make build MODULES=window,hotkeys` und `make build MODULES=window`.
- `make shots ONLY=hotkeys.` und alle vier Fassungen mit dem Werkzeug Read ansehen.
- Ob der Kurzbefehl aus anderen Apps auslöst, ist nur in der laufenden App prüfbar.
