# Änderungen

Jede Fassung des Starters hat einen Tag `v<Version>` und einen Abschnitt hier, mit dem, was sie enthält, und den Hinweisen für Projekte, die sie mit `bin/starter sync --ziel v<Version>` übernehmen. Die Version steht in `starter.json` (`starter.version`) und in `starter.lock.json`.

Ein Projekt führt darunter seine eigenen Fassungen (`app.version` in `starter.json`) mit denselben Abschnitten.

## Unveröffentlicht

### Inhalt

- Native Mac-App ohne Xcode: ein `swiftc`-Aufruf aus `scripts/build.sh`, SDK-Wahl über `scripts/pick-sdk.sh`, Swift 6 mit MainActor als Standard, macOS 26 als Mindestversion; `Package.swift` als zweiter Weg.
- Kit: Sprache Englisch und Deutsch mit Wechsel ohne Neustart, Einstellungen als JSON, SQLite mit nummerierten Migrationen, Registry für Seiten, Einstellungsbereiche, Onboarding-Schritte, Menüeinträge, Galerie und Render-Szenen, Design-Tokens mit sechs Akzenten und Kontrasttests, Bausteine und Muster im Stil von VoiceBud.
- App-Formen als Module: Fenster-App, Menüleisten-App, Insel an der Notch, Hintergrund mit Anmeldeobjekt; dazu Kurzbefehle, lokale KI (Apple Foundation Models), MLX-Worker (aus) und Beispiele.
- Renders jeder Szene in en und de, hell und dunkel ohne Fenster (`make shots`), Selbsttest ohne Fenster (`--selftest`), Test-Harness ohne XCTest (`make test`).
- Regeln für Agenten aus `rules/` mit Prüfungen für Texte, Design und Commits, Subagenten für die Gegenprüfung, Skills, Hooks für Claude Code, CI mit Build-Matrix, Renders, DMG und Template-Probe; Starter-Werkzeuge `bin/starter init`, `remove`, `strip-examples`, `sync`, `check-kit`.

### Migrationen

- Keine. Die Datenbank eines Projekts beginnt leer; Module bringen ihre Tabellen mit eigenen Migrationen mit.

### Hinweise für Projekte

- `bin/starter init` leert die Commit-Identität in `starter.json`. Bis das Projekt seine eigene einträgt, nimmt der Hook `commit-msg` keinen Commit an.
- Das App-Symbol aus `make icon` nutzt ein SF Symbol und ist nur für die Entwicklung gedacht; vor der ersten Weitergabe ein eigenes Motiv einsetzen (`docs/VERTEILUNG.md`).
