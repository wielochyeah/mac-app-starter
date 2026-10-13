---
name: neue-berechtigung
description: Nimmt eine macOS-Berechtigung (Mikrofon, Bedienungshilfen, Bildschirmaufnahme, Mitteilungen und andere) vollständig auf (starter.json, Nutzungsbeschreibungen in beiden Sprachen, Entitlements, Einrichtungsschritt, alle Zustände, Test auf der installierten App). Nutzen, wenn eine Funktion Zugriff braucht, den macOS schützt.
---

# Neue Berechtigung

## Verträge und Dateien

| Vertrag | Datei | Rolle |
|---|---|---|
| Liste | `starter.json` (`permissions`) | welche Berechtigungen die App nutzt; `scripts/gen_config.py` kennt die gültigen Namen |
| Nutzungsbeschreibungen | `App/Resources/InfoPlist.json` | Text, den macOS im Dialog zeigt, je Schlüssel `en` und `de`; der Build schreibt sie nach `Info.plist` und `<lang>.lproj/InfoPlist.strings` |
| Entitlements | `build/gen/App.entitlements` (erzeugt) | nötig unter der Hardened Runtime mit Developer ID |
| Prüfen, anfragen, Systemeinstellungen | `App/Sources/Kit/Permissions/` | `PermissionKind`, Status `missing`, `requested`, `denied`, `granted`, `restartNeeded`, Anfrage, Link in die Systemeinstellungen, Abfrage im Sekundentakt nur, solange jemand hinsieht |
| Schritt | `App/Sources/Kit/Onboarding/` | ein Einrichtungsschritt je Eintrag in `permissions` (order 300 und folgende) |
| Muster | `App/Sources/Kit/Design/Patterns/OnboardingStatusSlot.swift` | `OnboardingSlotState` und `OnboardingStatusSlot` für jeden Zustand |

Gültige Namen: `notifications`, `accessibility`, `inputMonitoring`, `screenRecording`, `microphone`, `camera`, `automation:<bundleId>` (je gesteuerte App, etwa `automation:com.apple.mail`), `speechRecognition`, `contacts`, `calendars`, `reminders`, `photos`, `location`, `bluetooth`, `localNetwork`.

## Schritte

1. Braucht die Funktion die Berechtigung wirklich, und zu welchem Zeitpunkt? Gefragt wird in der Einrichtung oder in dem Moment, in dem die Nutzerin die Funktion zum ersten Mal auslöst, nie beim Start ohne Zusammenhang.
2. Namen in `permissions` in `starter.json` eintragen; `make build` erzeugt Info.plist-Schlüssel und Entitlements.
3. Nutzungsbeschreibung schreiben (`App/Resources/InfoPlist.json`), in beiden Sprachen: sie sagt, wofür die App den Zugriff nutzt („Die App nutzt das Mikrofon, um aufzunehmen, was du sagst.“). Eine Zusage (bleibt auf dem Mac, nichts wird hochgeladen) nur, wenn das Projekt sie einhält und ein Test sie belegt. Die Texte des Starters sind Platzhalter; nach `bin/starter init` meldet `make check-texts` jeden, der für eine Berechtigung aus `starter.json` noch unverändert ist.
4. Zugriff nur über `App/Sources/Kit/Permissions/`; nie selbst `AVCaptureDevice.requestAccess`, `AXIsProcessTrustedWithOptions` und Ähnliches aus einem Feature aufrufen.
5. Ohne Berechtigung bleibt die Funktion sichtbar, sagt in einem Satz, warum sie aus ist, und bietet den Weg in die Systemeinstellungen (`InlineNotice` mit Aktion).
6. Bedienungshilfen, Eingabeüberwachung und Bildschirmaufnahme wirken bei manchen Apps erst nach einem Neustart: Zustand `restartNeeded`; die Einrichtung speichert ihren Stand vor dem Neustart.
7. Render-Szenen: die Kit-Szenen `onboarding.permission-*` zeigen jeden Zustand; eigene Hinweise der Funktion bekommen eine eigene Szene.

## Prüfen

- `make check` und `make shots ONLY=onboarding.`, Bilder ansehen.
- Nie während des Bauens eine Berechtigung anfragen oder `tccutil` ausführen.
- Echte Dialoge und der Weg in die Systemeinstellungen sind nur mit der installierten App prüfbar. Der Agent startet die App dafür nie und führt `tccutil` nicht aus; er führt diesen Punkt im Statusbericht unter „Bekannte Schwächen“ als „nur interaktiv prüfbar“ und beschreibt die Schritte für die Person am Mac.
- Nur die Person am Mac: `make dmg`, die App aus dem DMG nach `/Applications` (Finder: „Programme“) kopieren, starten, Dialog bestätigen und ablehnen. Zurücksetzen nur für diese App: `tccutil reset All <bundleId>`. Ad hoc signierte Builds verlieren Berechtigungen bei jedem neuen Build (`docs/VERTEILUNG.md`).
- Gegenprüfung mit dem Skill `red-team`, Blickwinkel Sicherheit.
