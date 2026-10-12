---
name: menueleisten-app
description: Baut Inhalte für das Statusmenü der App (Abschnitt im Panel, Menüeinträge, Zustand des Symbols idle, busy, attention) und macht aus dem Projekt eine reine Menüleisten-App ohne Dock-Symbol. Nutzen, wenn die App in der Menüleiste leben oder dort etwas zeigen soll. Gehört zum Modul menubar.
---

# Menüleisten-App

Gehört zum Modul `menubar`; `bin/starter remove menubar` entfernt diesen Skill mit dem Modul. Code außerhalb von `App/Sources/Modules/MenuBar/`, der das Statusmenü nutzt, steht in `#if MODUL_MENUBAR` … `#endif`.

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Symbol und Zustand | `App/Sources/Modules/MenuBar/` | `MenuBarStatus.shared.state` mit `idle`, `busy` (dezente Bewegung, ruht bei reduzierter Bewegung), `attention` (Punkt); Symbol aus `app.symbol` in `starter.json` |
| Panel | `MenuBarPanel.sections` | Abschnitte mit Kennung, Reihenfolge und View zwischen Kopf (App-Symbol, Name, Statuszeile) und Fußzeile (Einstellungen, Beenden) |
| Menü | `App/Sources/Kit/Core/Registry.swift` | `MenuItemContribution(id:order:title:symbol:shortcut:action:)`; Rechtsklick oder ⌥-Klick öffnet das Menü aus `Registry.menuItems` |
| Form der App | `starter.json` (`modules`), `App/Sources/Kit/Main/AppForm.swift` | ohne `window` läuft die App als Accessory ohne Dock-Symbol (`LSUIElement`); Einstellungen und Onboarding schalten vorübergehend auf `.regular` |

## Schritte

1. Reine Menüleisten-App: `bin/starter remove window`, danach `make build`. Hauptfenster-Aktionen (`AppActions.openMainWindow()`) öffnen dann die Einstellungen.
2. Abschnitt im Panel: eine View aus Kit-Bausteinen (`Card`, `Row`, `StatusMark`, `Segmented`), so schmal wie das Panel (320 bis 360 pt), höchstens eine Hauptaktion je Abschnitt. Eintragen im `register()` des Features in `MenuBarPanel.sections`.
3. Menüeintrag: `Registry.menuItems.append(MenuItemContribution(id: "export.run", order: 100, title: { ExportText.run }, symbol: "square.and.arrow.up", shortcut: "⇧⌘E", action: { Export.run() }))`. Titel als Verb im Infinitiv (`Exportieren`), Auslassungspunkte `…` nur, wenn danach eine Eingabe folgt.
4. Zustand des Symbols: während einer Arbeit `MenuBarStatus.shared.state = .busy`, danach zurück auf `.idle`; `.attention` nur, solange die Nutzerin etwas tun muss, und mit einem Hinweis im Panel, der sagt, was.
5. Render-Szenen: `<feature>.menubar` für den Abschnitt im Panel, je weiterem Zustand `<feature>.menubar-<zustand>`.

## Prüfen

- `make check`, `make build MODULES=menubar` und `make build MODULES=menubar,window`.
- `make shots ONLY=<feature>.` und `make shots ONLY=menubar.`, alle vier Fassungen jeder Szene mit dem Werkzeug Read ansehen; das Symbol in den Zuständen zeigt `menubar.icon-states`.
- Klickverhalten, Panel an der echten Menüleiste und der Wechsel zwischen Accessory und Regular sind nur in der laufenden App prüfbar.
