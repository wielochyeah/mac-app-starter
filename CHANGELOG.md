# Änderungen

Jede Fassung des Starters hat einen Tag `v<Version>` und einen Abschnitt hier, mit dem, was sie enthält, und den Hinweisen für Projekte, die sie mit `bin/starter sync --ziel v<Version>` übernehmen. Die Version steht in `starter.json` (`starter.version`) und in `starter.lock.json`.

Ein Projekt führt darunter seine eigenen Fassungen (`app.version` in `starter.json`) mit denselben Abschnitten.

## Unveröffentlicht

### Inhalt

- MIT-Lizenz in `LICENSE`; der Starter nennt sich in `THIRD_PARTY_NOTICES.md` und in den Hinweisen der App unter „Über“.

### Hinweise für Projekte

- `LICENSE` gehört dem Projekt, `sync` ändert sie nicht. Lizenz und Copyright-Zeile trägt das Projekt selbst ein; den Abschnitt „mac-app-starter“ in `App/Resources/Notices/` übernimmt es von Hand, weil diese Dateien dem Projekt gehören.

## 1.0.0 (13.10.2026)

Die erste Fassung. Aus ihr entsteht jede neue Mac-App mit `bin/starter init`. Die Korrekturen der Prüfrunde vor der Veröffentlichung (Werkzeuge und CI, App-Code, Texte) sind eingearbeitet.

### Inhalt

- Native Mac-App mit einem `swiftc`-Aufruf aus `scripts/build.sh` (Command Line Tools oder Xcode), SDK-Wahl über `scripts/pick-sdk.sh`, Swift 6 mit MainActor als Standard, macOS 26 als Mindestversion; `Package.swift` als zweiter Weg für Xcode und `swift build`, mit Modulen und Mindestversion aus `starter.json`.
- Kit: Sprache Englisch und Deutsch mit Wechsel ohne Neustart, Einstellungen als JSON (`Settings.inMemory()` für Szenen), SQLite mit nummerierten Migrationen (sicher, wenn zwei Prozesse gleichzeitig öffnen), Registry für Seiten, Einstellungsbereiche, Einrichtungsschritte, Menüeinträge, Galerie, Render-Szenen, Selbsttests und Hooks mit einem `order`-Bereich je Modul, Design-Tokens mit sechs Akzenten und Kontrasttests (Nebentext mindestens 4,5:1), Bausteine und Muster im Stil von VoiceBud (darunter `ConfirmRow` für Rückfragen an Ort und Stelle). Das Protokoll schreibt eingesetzte Werte privat, Inhalte auf keiner Stufe.
- Einrichtung mit Begrüßung, Sprache, Funktionen, einem Schritt je Berechtigung mit allen Zuständen bis zum Neustart und Abschluss; Einstellungsfenster wie die Systemeinstellungen mit „Allgemein“, „Über“ und der Galerie aller Bausteine, jeder Bereich mit einer Einleitungszeile.
- App-Formen als Module: Fenster-App im Stil von Musik (`AppActions.openMainWindow(page:)`), Menüleisten-App mit Statusmenü, Insel an der Notch und Kapsel ohne Notch (mit Modul `island` wächst die echte Insel auch im Begrüßungsschritt aus einer gezeichneten Notch), Hintergrund mit geplanten Aufgaben und Anmeldeobjekt; dazu globale Tastaturkurzbefehle mit Regeln, lokale KI über Apple Foundation Models und eigene Modelle über MLX (aus; Pakete nur mit Hashes, Modelle ohne Time-Machine-Sicherung, ein hängender Worker wird nach dem Abbruch beendet).
- Beispiel „Notizen“ (Modul `examples`): eigene Datenbank mit Volltextsuche, gelöschte Notizen ohne Reste in Datei und WAL, Seiten im Hauptfenster, Abschnitt im Statusmenü, Karten in der Insel, Tastaturkurzbefehl ⌃⌥N sichert die Zwischenablage als Notiz (Kopien aus Passwortmanagern nicht), Zusammenfassung und Titelvorschlag mit lokaler KI, Hintergrund-Aufgabe „Papierkorb leeren“ und Einstellungsbereich, jeder Bezug auf ein Modul in eigenen `#if`-Blöcken. `bin/starter strip-examples` entfernt es ohne Rest.
- Renders jeder Szene in en und de, hell und dunkel ohne Fenster (`make shots`; `onboarding.project` und `menubar.project` zeigen das eigene Projekt), README-Bilder mit `make readme-shots` (höchstens 1200 Pixel breit, dazu App-Symbol und DMG-Fenster), Selbsttest (`--selftest`), Test-Harness ohne XCTest (`make test`). Jeder Werkzeuglauf läuft ohne Fenster und ohne echte Daten, auch ohne `STARTER_HEADLESS=1`.
- Weitergabe: programmatisches App-Symbol (`make icon`), DMG mit gestaltetem Fenster in beiden Sprachen (`make dmg`), Signatur ad hoc oder mit Developer ID (eingebetteter Code mit eigenen Entitlements über `tools/entitlements-map.json`, keine Bundle-ID `com.example.*`), Notarisierung mit einem Profil im Schlüsselbund.
- Regeln für Agenten aus `rules/` mit Prüfungen für Texte (feste Begriffe der Oberfläche, Anführungszeichen, Einheiten, Nutzungsbeschreibungen ohne Zusagen, DMG-Texte, Hinweise zu Fremdcode), Design, Kit und Commits, Subagenten für die Gegenprüfung, Skills für jede Art von Beitrag, Hooks für Claude Code (Allow-Regeln exakt, `guard-git` lehnt Befehle ab, die andere Programme starten). Git-Hooks in POSIX-`sh`: ohne Mac führt `pre-push` `make check-light` aus. `make check` und die CI behandeln Warnungen als Fehler, `make typecheck` prüft jede Modul-Kombination. Die CI plant je Ereignis (`.github/ci_plan.py`): Arbeits-Branch nur Linux, Pull Request ein Mac-Job, `main` und Tags dazu Typecheck, Renders und Template-Probe; Actions sind auf Commits festgelegt. Starter-Werkzeuge `bin/starter init`, `remove`, `strip-examples`, `sync`, `check-kit`, `modules`, `doctor`.

### Migrationen

- Keine. Die Datenbank eines Projekts beginnt leer; Module bringen ihre Tabellen mit eigenen Migrationen mit.

### Hinweise für Projekte

- Der Starter trägt keine Commit-Identität. Ein Projekt trägt seine in `starter.json` (`commit`) ein; bis dahin nimmt der Hook `commit-msg` keinen Commit an. `make hooks` und der Hook `session-start` setzen sie als Git-Identität nur, wenn Git noch keine kennt.
- Starter oder Kopie entscheidet `repository` in `starter.manifest.json` gegen origin oder `GITHUB_REPOSITORY`, ohne Groß und Klein. Eine Kopie vor `bin/starter init` baut in der CI nicht und meldet „Einrichten (bin/starter init)“.
- `bin/starter init` fragt die Anrede (`--anrede du|sie`), lehnt ein unbekanntes SF Symbol ab, entfernt die Unterzeile des Starters (`app.tagline`), `texts.personen`, Rundgang und Bilder des Starters und führt danach `make rules` aus. Mit `--anrede sie` stehen die du-Texte des Kits als bekannte Befunde in `rules/baseline/texte.json`: `python3 scripts/check_texts.py --streng` zeigt sie, `--baseline-aktualisieren` verkleinert die Liste.
- `make check-texts` meldet in einem Projekt jede Nutzungsbeschreibung in `App/Resources/InfoPlist.json`, die für eine Berechtigung aus `starter.json` noch der Text des Starters ist.
- Eigene Einstellungsbereiche nehmen `order` 100 bis 199 (Tabelle in `docs/MODULE.md`); zwei Bereiche mit demselben Wert meldet der Selbsttest `kit.registry`.
- Finder zeigt den Namen der App in der Sprache des Macs (`LSHasLocalizedDisplayName`, `app.displayName`), solange das Bundle seinen Dateinamen behält.
- Notarisiert wird über `make dmg` mit `signing.notarize: true` und einem Profil im Schlüsselbund (`signing.notaryProfile` oder `NOTARY_PROFILE`); `make notarize` reicht nur erneut ein.
- Das Modul `mlx` kommt noch nicht in ein DMG (`docs/KI.md`); weitergegebene Apps nutzen Apple Foundation Models.
- Das App-Symbol aus `make icon` nutzt ein SF Symbol und ist nur für die Entwicklung gedacht; vor der ersten Weitergabe ein eigenes Motiv einsetzen (`docs/VERTEILUNG.md`).
- Eigene README-Bilder kommen über `docs/screenshots/list.txt`, `make shots` und `make readme-shots`; `bin/starter remove` nimmt Zeilen und Bilder eines Moduls mit und nennt Stellen, die sie noch zeigen.
- Mit Modul `island` zeigt der Begrüßungsschritt eine neutrale Karte der Insel; was sie dort meldet, setzt ein Feature über `IslandWelcome.working` und `IslandWelcome.result`.
