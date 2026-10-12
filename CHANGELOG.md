# Änderungen

Jede Fassung des Starters hat einen Tag `v<Version>` und einen Abschnitt hier, mit dem, was sie enthält, und den Hinweisen für Projekte, die sie mit `bin/starter sync --ziel v<Version>` übernehmen. Die Version steht in `starter.json` (`starter.version`) und in `starter.lock.json`.

Ein Projekt führt darunter seine eigenen Fassungen (`app.version` in `starter.json`) mit denselben Abschnitten.

## 1.0.0 (12.10.2026)

Die erste Fassung. Aus ihr entsteht jede neue Mac-App mit `bin/starter init`.

### Inhalt

- Native Mac-App ohne Xcode: ein `swiftc`-Aufruf aus `scripts/build.sh`, SDK-Wahl über `scripts/pick-sdk.sh`, Swift 6 mit MainActor als Standard, macOS 26 als Mindestversion; `Package.swift` als zweiter Weg.
- Kit: Sprache Englisch und Deutsch mit Wechsel ohne Neustart, Einstellungen als JSON, SQLite mit nummerierten Migrationen, Registry für Seiten, Einstellungsbereiche, Onboarding-Schritte, Menüeinträge, Galerie, Render-Szenen, Selbsttests und Hooks, Design-Tokens mit sechs Akzenten und Kontrasttests, Bausteine und Muster im Stil von VoiceBud (darunter `ConfirmRow` für Rückfragen an Ort und Stelle).
- Onboarding mit Begrüßung, Sprache, Funktionen, einem Schritt je Berechtigung mit allen Zuständen bis zum Neustart und Abschluss; Einstellungsfenster wie die Systemeinstellungen mit „Allgemein“, „Über“ und der Galerie aller Bausteine.
- App-Formen als Module: Fenster-App im Stil von Musik (`AppActions.openMainWindow(page:)`), Menüleisten-App mit Panel, Insel an der Notch und Kapsel ohne Notch (mit Modul `island` wächst die echte Insel auch im Begrüßungsschritt aus einer gezeichneten Notch), Hintergrund mit geplanten Aufgaben und Anmeldeobjekt; dazu globale Kurzbefehle mit Regeln, lokale KI über Apple Foundation Models und eigene Modelle über MLX (aus).
- Beispiel „Notizen“ (Modul `examples`): eigene Datenbank mit Volltextsuche, Seiten im Hauptfenster, Abschnitt im Menüleisten-Panel, Karten in der Insel, Kurzbefehl ⌃⌥N, Zusammenfassung und Titelvorschlag mit lokaler KI, Hintergrund-Aufgabe „Papierkorb leeren“ und Einstellungsbereich, jeder Bezug auf ein Modul in eigenen `#if`-Blöcken. `bin/starter strip-examples` entfernt es ohne Rest.
- Renders jeder Szene in en und de, hell und dunkel ohne Fenster (`make shots`), README-Bilder mit `make readme-shots` (höchstens 1200 Pixel breit, dazu App-Symbol und DMG-Fenster), Selbsttest ohne Fenster (`--selftest`), Test-Harness ohne XCTest (`make test`).
- Weitergabe: programmatisches App-Symbol (`make icon`), DMG mit gestaltetem Fenster in beiden Sprachen (`make dmg`), Signatur ad hoc oder mit Developer ID, Notarisierung mit einem Profil im Schlüsselbund.
- Regeln für Agenten aus `rules/` mit Prüfungen für Texte, Design, Kit und Commits, Subagenten für die Gegenprüfung, Skills für jede Art von Beitrag, Hooks für Claude Code, CI mit Build-Matrix (auch jeder Teil des Beispiels mit nur seinem Modul), Renders, DMG und Template-Probe; Starter-Werkzeuge `bin/starter init`, `remove`, `strip-examples`, `sync`, `check-kit`, `modules`, `doctor`.

### Migrationen

- Keine. Die Datenbank eines Projekts beginnt leer; Module bringen ihre Tabellen mit eigenen Migrationen mit.

### Hinweise für Projekte

- `bin/starter init` leert die Commit-Identität in `starter.json`. Bis das Projekt seine eigene einträgt, nimmt der Hook `commit-msg` keinen Commit an.
- `bin/starter init` fragt die Anrede (`--anrede du|sie`), entfernt die Unterzeile des Starters (`app.tagline`) und `texts.personen` und führt danach `make rules` aus.
- Finder zeigt den Namen der App in der Sprache des Macs (`LSHasLocalizedDisplayName`, `app.displayName`), solange das Bundle seinen Dateinamen behält.
- Notarisiert wird über `make dmg` mit `signing.notarize: true` und einem Profil im Schlüsselbund (`signing.notaryProfile` oder `NOTARY_PROFILE`); `make notarize` reicht nur erneut ein.
- Das Modul `mlx` kommt noch nicht in ein DMG (`docs/KI.md`); weitergegebene Apps nutzen Apple Foundation Models.
- Das App-Symbol aus `make icon` nutzt ein SF Symbol und ist nur für die Entwicklung gedacht; vor der ersten Weitergabe ein eigenes Motiv einsetzen (`docs/VERTEILUNG.md`).
- Der Rundgang im README und die Bilder in `docs/screenshots/` zeigen den Starter mit dem Beispiel „Notizen“. Ein Projekt trägt eigene Szenen in `docs/screenshots/list.txt` ein und ruft `make shots` und `make readme-shots` auf; nach `bin/starter strip-examples` fehlen die Szenen `examples.*`, die die Liste des Starters nennt.
- Mit Modul `island` zeigt der Begrüßungsschritt eine neutrale Karte der Insel; was sie dort meldet, setzt ein Feature über `IslandWelcome.working` und `IslandWelcome.result`.
