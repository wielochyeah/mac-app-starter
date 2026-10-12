---
name: neuer-onboarding-schritt
description: Fügt dem Onboarding einen Schritt hinzu (OnboardingStep mit Reihenfolge und Bedingung, OnboardingPage mit Kopf, Status-Slot und Hinweis, Fußleiste über den Kontext, beide Sprachen, Render-Szenen je Zustand). Nutzen, wenn beim ersten Start etwas erklärt, gewählt oder erlaubt werden muss.
---

# Neuer Onboarding-Schritt

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Schritt | `App/Sources/Kit/Core/Registry.swift` | `OnboardingStep(id:order:isIncluded:content:)`, `OnboardingContext` mit `canContinue`, `next()`, `back()`, `index`, `count` |
| Fenster und Ablauf | `App/Sources/Kit/Onboarding/` | Fenster 720 x 560, Übergänge, Fortschritt, Speichern des Schritts, Kit-Schritte |
| Muster | `App/Sources/Kit/Design/Patterns/OnboardingPage.swift`, `OnboardingStatusSlot.swift`, `TilePicker.swift`, `RichText.swift` | `OnboardingPage`, `OnboardingHero`, `OnboardingHeader`, `OnboardingStatusSlot`, `OnboardingHint`, `OnboardingFootnote`, `OnboardingNote`, `TilePicker(tone: .onboarding)` |
| Berechtigungen | `App/Sources/Kit/Permissions/` | Schritte für Berechtigungen baut das Kit aus `permissions` in `starter.json` (Skill `neue-berechtigung`) |

## Reihenfolge

| order | Schritt |
|---|---|
| 0 | Begrüßung mit App-Symbol und Zweck (Kit) |
| 10 | Sprache (Kit) |
| 20 | Funktionen (Kit, bis zu drei Karten aus `OnboardingFeatures`) |
| 300 bis 399 | Berechtigungen (Kit, je Eintrag in `permissions`) |
| 400 | Lokale KI (Modul `ai`) |
| 500 | Darstellung Insel oder Kapsel (Modul `island`) |
| 600 | Kurzbefehl (Modul `hotkeys`) |
| 900 | Beim Anmelden starten (Modul `background`) |
| 1000 | Fertig (Kit) |

Eigene Schritte nutzen freie Werte dazwischen, etwa 30 bis 290 für Erklärungen und Auswahl vor den Berechtigungen.

## Schritte

1. Braucht es den Schritt wirklich? Ein Schritt erklärt eine Sache, verlangt eine Entscheidung oder eine Erlaubnis. Was später in den Einstellungen reicht, gehört nicht ins Onboarding.
2. Seite bauen, nur aus Mustern:

   ```swift
   OnboardingPage {
       OnboardingHero(symbol: "tray.full", tint: .teal).padding(.bottom, Space.m)
       OnboardingHeader(title: SyncText.stepTitle, subtitle: SyncText.stepWhy).padding(.bottom, Space.l)
       SettingsSection(tone: .onboarding) { ToggleRow(SyncText.toggle, isOn: $enabled) }
           .frame(width: Metrics.onboardingColumn)
       OnboardingFootnote(SyncText.stepNote, lines: 2)
   }
   ```

   Abstände zwischen Blöcken nur `Space.xs`, `Space.s`, `Space.m`, `Space.l` als `.padding(.bottom, …)`. Links im Text als `[Titel](app://aktion)` mit `perform`.
3. Weiter erst, wenn es geht: `context.canContinue.wrappedValue = false`, solange etwas fehlt. Hält der Schritt selbst die Hauptaktion (Status-Slot mit `.action`), ist „Weiter“ nicht primär; das Kit-Fenster richtet die Fußleiste danach.
4. Registrieren: `Registry.onboardingSteps.append(OnboardingStep(id: "sync", order: 120, isIncluded: { true }, content: { context in AnyView(SyncStep(context: context)) }))`. `isIncluded` wird beim Öffnen ausgewertet; ein Schritt, der nicht zutrifft, fehlt ganz.
5. Was der Schritt festlegt, speichert er sofort über `SettingKey`; das Onboarding kann jederzeit geschlossen und später mit `AppActions.openOnboarding()` fortgesetzt werden.
6. Texte: Titel kurz, Untertitel sagt, warum, in einem Satz. Keine Begrüßungsfloskeln.
7. Render-Szenen `onboarding.<id>` je Zustand (Ausgangslage, gewählt, Fehler) im Fensterrahmen: `RenderBoard { StaticWindow(size: Metrics.onboardingWindow, chrome: .onboarding) { … } }`.

## Prüfen

- `make check`.
- `make shots ONLY=onboarding.` und jede Szene in allen vier Fassungen mit dem Werkzeug Read ansehen; mit `patterns.sample-step` vergleichen. Deutsch passt ohne Kürzung in die Spalte von 560 pt.
- Gegenprüfung mit dem Skill `red-team`. Der ganze Ablauf auf einem frischen Benutzer bleibt eine Abnahme in der laufenden App (`docs/vorlagen/ABNAHME.md`, AK-01).
