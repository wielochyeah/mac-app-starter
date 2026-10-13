---
name: release-dmg
description: Bereitet eine Fassung der App zur Weitergabe vor (Version, Release-Build, DMG mit gestaltetem Fenster, Signatur ad hoc oder mit Developer ID, Notarisierung nur auf ausdrücklichen Wunsch, Prüfung des DMG). Nutzen, wenn jemand außerhalb des Entwickler-Macs die App installieren soll.
---

# Release als DMG

Einzelheiten zu Signatur, Gatekeeper und Berechtigungen stehen in `docs/VERTEILUNG.md`.

## Verträge und Dateien

| Datei | Rolle |
|---|---|
| `starter.json` | `app.version`, `app.build`, `signing.identity` (`-` für ad hoc), `signing.teamId`, `signing.notarize`, `signing.notaryProfile` (Name des Schlüsselbund-Profils; `NOTARY_PROFILE` geht vor) |
| `scripts/dmg.sh` (`make dmg`) | Release-Build, Hintergrund aus `tools/dmg/Background.swift`, dmgbuild in `build/tools-venv`, Ergebnis `build/dmg/<Name>-<version>.dmg` |
| `scripts/notarize.sh` (`make notarize`) | `notarytool submit --wait` und `stapler staple` für App oder DMG; `make dmg` ruft es mit `signing.notarize: true` selbst auf, von Hand nur zum Wiederholen (lehnt ein DMG mit Hinweis im Fenster ab) |
| `tools/entitlements.plist`, `build/gen/App.entitlements` | Entitlements für die Hardened Runtime |
| `App/Resources/AppIcon.icns` | App-Symbol, neu mit `make icon` |
| `CHANGELOG.md` | Abschnitt der Fassung |

## Schritte

1. `app.version` (sichtbar, `1.2.0`) und `app.build` (fortlaufende Zahl, immer höher als zuvor) in `starter.json` setzen; `CHANGELOG.md` bekommt den Abschnitt der Fassung.
2. `make check` grün, Renders der Fassung angesehen.
3. `make dmg`. Beim ersten Lauf richtet das Skript dmgbuild in `build/tools-venv` ein (Netz für pip, nur im Werkzeugordner) und sagt, was es installiert.
4. Prüfen ohne Finder-Fenster: `hdiutil attach -nobrowse -readonly -mountpoint <ordner> build/dmg/<Name>-<version>.dmg`, Inhalt ansehen (App, Verknüpfung „Applications“, verborgener Hintergrund), `codesign --verify --deep --strict <ordner>/<Name>.app`, danach `hdiutil detach <ordner>`.
5. Ad hoc signiert (Standard): Empfänger starten die App einmal, macOS blockiert sie; danach in den Systemeinstellungen unter „Datenschutz & Sicherheit“ auf „Dennoch öffnen“ klicken. Das DMG-Fenster sagt das; den früheren Weg über Rechtsklick und „Öffnen“ gibt es auf aktuellem macOS nicht mehr.
6. Mit Developer ID: Signatur und Notarisierung nur auf ausdrücklichen Wunsch des Auftraggebers und nur mit Zugangsdaten aus dem Schlüsselbund (`notarytool store-credentials <profil>`), nie aus Dateien oder Argumenten im Repository. `signing.identity`, `signing.notaryProfile` und `signing.notarize: true` setzen, dann `make dmg` (Schritt 3): es notarisiert App und DMG selbst. Danach `spctl -a -vv <app>` und `xcrun stapler validate <dmg>`.
7. Tag `v<version>` setzen und mit dem DMG weitergeben; das DMG selbst kommt nie ins Repository.

## Prüfen

- Installieren auf einem zweiten Mac oder einem zweiten Benutzer: DMG öffnen, App auf den Ordner „Applications“ ziehen (das ist `/Applications`, im Finder „Programme“), starten, Einrichtung und Berechtigungen durchgehen (`docs/vorlagen/ABNAHME.md`, AK-60).
- Ein ad hoc signierter neuer Build verliert erlaubte Berechtigungen; das ist erwartet und steht in `docs/VERTEILUNG.md`.
