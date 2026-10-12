---
name: neue-berechtigung
description: Nimmt eine macOS-Berechtigung (Mikrofon, Bedienungshilfen, Bildschirmaufnahme, Mitteilungen und andere) sauber auf (starter.json, Erklärtexte in beiden Sprachen, Entitlements, Onboarding-Schritt, Zustände, Test auf der installierten App). Nutzen, wenn eine Funktion Zugriff braucht, den macOS schützt.
---

# Neue Berechtigung

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Liste | `starter.json` (`permissions`) | welche Berechtigungen die App nutzt; `scripts/gen_config.py` kennt die gültigen Namen |
| Erklärtexte | `App/Resources/InfoPlist.json` | Text, den macOS im Dialog zeigt, je Schlüssel `en` und `de`; der Build schreibt sie nach `Info.plist` und `<lang>.lproj/InfoPlist.strings` |
| Entitlements | `build/gen/App.entitlements` (erzeugt) | nötig unter der Hardened Runtime mit Developer ID |
| Prüfen, anfragen, Systemeinstellungen | `App/Sources/Kit/Permissions/` | `PermissionKind`, Status `missing`, `requested`, `denied`, `granted`, `restartNeeded`, Anfrage, Link in die Systemeinstellungen, Abfrage im Sekundentakt nur, solange jemand hinsieht |
| Schritt | `App/Sources/Kit/Onboarding/` | ein Onboarding-Schritt je Eintrag in `permissions` (order 300 und folgende) |
| Muster | `App/Sources/Kit/Design/Patterns/OnboardingStatusSlot.swift` | `OnboardingSlotState` und `OnboardingStatusSlot` für jeden Zustand |

Gültige Namen: `notifications`, `accessibility`, `inputMonitoring`, `screenRecording`, `microphone`, `camera`, `automation`, `speechRecognition`, `contacts`, `calendars`, `reminders`, `photos`, `location`, `bluetooth`, `localNetwork`.

## Schritte

1. Braucht die Funktion die Berechtigung wirklich, und zu welchem Zeitpunkt? Gefragt wird im Onboarding oder in dem Moment, in dem die Nutzerin die Funktion zum ersten Mal auslöst, nie beim Start ohne Zusammenhang.
2. Namen in `permissions` in `starter.json` eintragen; `make build` erzeugt Info.plist-Schlüssel und Entitlements.
3. Erklärtext prüfen oder schreiben (`App/Resources/InfoPlist.json`): sagt konkret, was die App mit dem Zugriff tut und was auf dem Mac bleibt, in beiden Sprachen.
4. Zugriff nur über `App/Sources/Kit/Permissions/`; nie selbst `AVCaptureDevice.requestAccess`, `AXIsProcessTrustedWithOptions` und Ähnliches aus einem Feature aufrufen.
5. Ohne Berechtigung bleibt die Funktion sichtbar, sagt in einem Satz, warum sie aus ist, und bietet den Weg in die Systemeinstellungen (`InlineNotice` mit Aktion).
6. Bedienungshilfen, Eingabeüberwachung und Bildschirmaufnahme wirken bei manchen Apps erst nach einem Neustart: Zustand `restartNeeded`; das Onboarding speichert seinen Stand vor dem Neustart.
7. Render-Szenen: die Kit-Szenen `onboarding.permission-*` zeigen jeden Zustand; eigene Hinweise der Funktion bekommen eine eigene Szene.

## Prüfen

- `make check` und `make shots ONLY=onboarding.`, Bilder ansehen.
- Nie während des Bauens eine Berechtigung anfragen oder `tccutil` ausführen.
- Echte Dialoge und der Weg in die Systemeinstellungen sind nur mit der installierten App prüfbar. Der Agent startet die App dafür nie und führt `tccutil` nicht aus; er führt diesen Punkt im Statusbericht unter „Bekannte Schwächen“ als „nur interaktiv prüfbar“ und beschreibt die Schritte für die Person am Mac.
- Nur die Person am Mac: `make dmg`, die App aus dem DMG nach `/Applications` (Finder: „Programme“) kopieren, starten, Dialog bestätigen und ablehnen. Zurücksetzen nur für diese App: `tccutil reset All <bundleId>`. Ad hoc signierte Builds verlieren Berechtigungen bei jedem neuen Build (`docs/VERTEILUNG.md`).
- Gegenprüfung mit dem Skill `red-team`, Blickwinkel Sicherheit.
