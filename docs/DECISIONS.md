# Entscheidungen

Jede Entscheidung mit Datum, Wortlaut, Grund und Folgen. Neue Einträge kommen ans Ende; eine überholte Entscheidung bleibt stehen und bekommt einen Verweis auf die neue. In einem neuen Projekt legt `bin/starter init` diese Einträge als `docs/STARTER_DECISIONS.md` ab, das `bin/starter sync` nachzieht, und beginnt `docs/DECISIONS.md` mit der leeren Vorlage aus `docs/vorlagen/DECISIONS.md`; das Projekt zählt seine eigenen Einträge als PE-01, PE-02 und so weiter (P-NN sind die Regeln des Projekts in `rules/projekt/`).

Die Kennungen beginnen mit E (Entscheidung), weil D bereits die Designregeln in `CLAUDE.md` Teil A kennzeichnet.

## Grundsatz

### E-01 (12.10.2026): Template-Repository mit Manifest, Schwester von app-starter

- **Entscheidung:** `mac-app-starter` ist ein GitHub-Template-Repository für native Mac-Apps. Es übernimmt von `app-starter` (Web) die Mechanik: `starter.manifest.json` trennt Kit-, gemeinsame und Projekt-Pfade, `starter.lock.json` hält den Stand, `bin/starter` richtet ein, entfernt Module und zieht neuere Fassungen nach; dazu die Regelquelle `rules/`, die Prüfer-Subagenten und die Dokumente. Gestaltung, Onboarding, Einstellungen, Insel und Verteilung kommen aus VoiceBud.
- **Grund:** Agenten arbeiten zuverlässig, wenn fertiger, getesteter Code und feste Regeln im Repository liegen; Manifest, Lock und Sync fangen die Drift zwischen Starter und Projekten ab.
- **Folgen:** Projekte ändern keine Kit-Pfade, sondern melden Bedarf in `docs/STARTER_FEEDBACK.md` (Skill `starter-rueckfluss`).

### E-02 (12.10.2026): App-Formen als entfernbare Module

- **Entscheidung:** Fenster-App (`window`), Menüleisten-App (`menubar`), Insel an der Notch (`island`) und Hintergrund (`background`) sind Module, dazu `hotkeys`, `ai`, `mlx` und `examples`. Ein Projekt wählt eine oder mehrere Formen und entfernt den Rest mit `bin/starter remove <modul>`. Mindestens `window` oder `menubar` bleibt.
- **Grund:** Der Starter soll für jede Art von Mac-App taugen, nicht nur für Apps an der Notch. Ohne Fenster und ohne Menüleiste wären die Einstellungen nicht erreichbar.
- **Folgen:** Kit (Core, Design, Texte, Onboarding, Einstellungen, Berechtigungen, Galerie, Render, Main) bleibt immer. Die Aktivierungsrichtlinie ist `.regular` mit `window`, sonst `.accessory` mit `LSUIElement`; Einstellungen und Onboarding schalten eine Accessory-App vorübergehend auf `.regular`, bis das letzte dieser Fenster zu ist.

## Technik

### E-03 (12.10.2026): Bauen ohne Xcode und ohne SwiftPM

- **Entscheidung:** Der Standardweg baut mit einem einzigen `swiftc`-Aufruf aus `scripts/build.sh`; `scripts/pick-sdk.sh` wählt das neueste SDK, das der Compiler lesen kann. `Package.swift` liegt als zweiter Weg für Xcode oder ein intaktes SwiftPM bei; die Quellen bauen auf beiden Wegen.
- **Grund:** Auf Macs mit Command Line Tools ohne Xcode stürzt SwiftPM bei gemischten Installationen ab, und ein Beta-SDK lässt sich mit dem Release-Compiler nicht bauen. Ein fest eingetragener SDK-Pfad bräche beim nächsten Update der Werkzeuge.
- **Folgen:** `make doctor` erkennt die gemischte Installation und nennt die Reparatur, installiert aber nichts. Ressourcen entstehen ohne Asset-Katalog (`AppIcon.icns`, `.lproj` aus `InfoPlist.json`).

### E-04 (12.10.2026): Verbotene Bausteine

- **Entscheidung:** Kein `#Preview`, `@Entry`, `@Generable`, SwiftData `@Model`, `.xcassets`, `.icon`, `.xib`, Storyboard, Core-Data-Modell, mlx-swift, XCTest, Swift Testing. Erlaubt sind `@Observable`, `@MainActor`, SwiftUI, AppKit, FoundationModels mit `DynamicGenerationSchema`, ServiceManagement, Carbon für Kurzbefehle und sqlite3.
- **Grund:** Diese Bausteine brauchen Makro-Plugins oder Werkzeuge, die nur Xcode mitbringt (`actool`, `ibtool`, `momc`, `metal`); mit den Command Line Tools allein bauen sie nicht.
- **Folgen:** `EnvironmentKey` werden von Hand geschrieben, Tests laufen über ein eigenes Harness (`App/Tests/Harness/`), Speicher über einen kleinen sqlite3-Wrapper.

### E-05 (12.10.2026): Swift 6 mit MainActor als Standard

- **Entscheidung:** Sprachmodus Swift 6 mit `-default-isolation MainActor`.
- **Grund:** Oberflächencode läuft ohnehin auf dem Main Actor; der Standard spart Annotationen und macht Datenrennen zu Compilerfehlern. Mit Swift 6.3 und dem macOS-26.5-SDK geprüft.
- **Folgen:** Typen, die in `nonisolated` oder `Sendable`-Kontexte gehen (eigene Werte eines `SettingKey`, Konfiguration), sind `nonisolated struct …: Codable, Sendable`.

### E-06 (12.10.2026): macOS 26 als Mindestversion, nur Apple Silicon

- **Entscheidung:** `app.minimumMacOS` ist `26.0`, Architektur arm64.
- **Grund:** Liquid Glass und Foundation Models stehen ab macOS 26 ohne Verfügbarkeitsweichen bereit; MLX läuft nur auf Apple Silicon.
- **Folgen:** Schnittstellen nach 26.0 brauchen weiter `#available`. Intel-Macs werden nicht unterstützt.

### E-07 (12.10.2026): Module als Compiler-Flags

- **Entscheidung:** `scripts/build.sh` übersetzt die Module aus `starter.json` in `-D MODUL_<NAME>` und kompiliert `App/Sources/Modules/<Name>/` nur für eingeschaltete Module. Querbezüge stehen in je einem `#if MODUL_<NAME>` … `#endif` mit genau einem Flag, ohne `||`, `&&`, `!` und `#elseif`; braucht Code zwei Module, stehen zwei einfache Blöcke ineinander. `App/Sources/Kit/Main/Modules.swift` ist die einzige Liste der Module.
- **Grund:** `bin/starter remove` kann einfache Blöcke sicher entfernen, auch ineinander stehende, weil jeder nur ein Flag nennt; kombinierte Bedingungen ließen sich nicht ohne Compiler auflösen. Ein Build je Kombination beweist, dass jede Auswahl baut.
- **Folgen:** `make build MODULES=a,b` baut jede Kombination; die CI baut eine Matrix und entfernt jedes Modul in einer frischen Kopie.

### E-08 (12.10.2026): Texte in Englisch und Deutsch, Wechsel ohne Neustart

- **Entscheidung:** Jeder sichtbare Text steht in einer `*Text.swift`-Datei als `tr(en: "…", de: "…")`; Views enthalten keine Textliterale. `Localizer.shared` folgt den Sprachen des Macs, bis die Nutzerin eine wählt; `STARTER_LANG` erzwingt eine Sprache für Renders und Tests. Die deutsche Anrede (`du` oder `Sie`) steht in `starter.json` (`texts.anrede`), Standard `du` wie bei Apple und VoiceBud.
- **Grund:** Beide Sprachen sind durch die Signatur Pflicht und können nicht auseinanderlaufen; ein beobachtbares Objekt lässt SwiftUI bei einem Wechsel neu zeichnen, ohne Bundles oder Neustart. String-Kataloge bräuchten `xcstringstool` aus Xcode.
- **Folgen:** Mehrzahl und Platzhalter sind `static func`. Erklärtexte der Berechtigungen kommen aus `App/Resources/InfoPlist.json` und werden beim Bauen in `.lproj`-Dateien geschrieben.

### E-09 (12.10.2026): Nur Design-Tokens, Farben aus dem Farbschema

- **Entscheidung:** Farben, Abstände, Radien, Schriftgrößen und Bewegung liegen in `App/Sources/Kit/Design/`; Views nutzen `Theme`, `Space`, `Radius`, `TypeScale`, `Motion`. Farben entstehen aus dem `ColorScheme` von SwiftUI (`Theme(scheme)`), nicht aus dynamischen `NSColor`.
- **Grund:** Einheitliches Aussehen über alle Module und Projekte; Renders ohne Fenster sehen genauso aus wie das echte Fenster. `make check-design` findet Abweichungen.
- **Folgen:** Ausnahmen tragen `// design-ausnahme: <grund>`. Sechs Akzente (`violett`, `rot`, `blau`, `gruen`, `orange`, `graphit`) mit getesteten Kontrasten.

### E-10 (12.10.2026): Glas vom System, Stellvertreter in Renders

- **Entscheidung:** Glas kommt vom System, wo es eines gibt (Seitenleiste, Werkzeugleiste), sonst aus `GlassSurface`. Beim Rendern (`RenderMode.isStatic`) zeichnet `GlassSurface` eine Fläche in Token-Farbe.
- **Grund:** Offscreen-Renders zeigen kein Glas, und getöntes Glas leert die ganze Aufnahme.
- **Folgen:** Renders zeigen Glas als ruhige Fläche; die echte Wirkung prüft eine Person in der laufenden App.

### E-11 (12.10.2026): Einstellungen als JSON mit typisierten Schlüsseln

- **Entscheidung:** Einstellungen liegen in `~/Library/Application Support/<bundleId>/settings.json`, atomar geschrieben, unbekannte Schlüssel bleiben erhalten, kaputte Werte fallen auf den Standard zurück. Schlüssel sind `SettingKey<Value>` neben dem Code, dem sie gehören.
- **Grund:** Lesbar, testbar, ohne UserDefaults-Domänen, die an Bundle-ID und Signatur hängen; Module bringen ihre Schlüssel mit und nehmen sie beim Entfernen mit.
- **Folgen:** Eine unlesbare Datei wird beim nächsten Speichern als `settings.json.broken` beiseitegelegt.

### E-12 (12.10.2026): Speicher mit sqlite3 und nummerierten Migrationen

- **Entscheidung:** `App/Sources/Kit/Core/Database.swift` ist ein kleiner Wrapper um sqlite3 mit Migrationen über `PRAGMA user_version`, WAL und typisierten Zeilen. Kein ORM.
- **Grund:** SwiftData braucht Xcode-Makros; ein ORM wäre eine Abhängigkeit ohne Gewinn für kleine Datenmengen.
- **Folgen:** Migrationen sind additiv und nummeriert; eine falsche Migration korrigiert eine neue.

### E-13 (12.10.2026): Lokale KI mit Apple Foundation Models, MLX optional

- **Entscheidung:** Das Modul `ai` nutzt standardmäßig Apple Foundation Models. Das Modul `mlx` (aus) bringt einen Python-Worker mit MLX, einen Modellkatalog und Downloads mit Fortschritt.
- **Grund:** Foundation Models braucht keinen Download und spricht Deutsch; mlx-swift lässt sich ohne Xcode nicht bauen, der Python-Worker mit dem Protokoll aus VoiceBud schon.
- **Folgen:** Ohne Apple Intelligence zeigt die App einen ehrlichen Aus-Zustand. Einzelheiten in `docs/KI.md`.

### E-14 (12.10.2026): Kein Netz ohne Auftrag

- **Entscheidung:** Die App ruft das Netz nur für einen Modell-Download auf, den die Nutzerin auslöst. Keine Analyse, keine Absturzberichte, keine Update-Prüfung. Werkzeuge in `scripts/` dürfen für eigene Umgebungen (dmgbuild, mlx) Pakete laden.
- **Grund:** Datenschutz ist ein Versprechen der Apps, die aus dem Starter entstehen; was nicht eingebaut ist, kann nichts verraten.
- **Folgen:** Ein Projekt, das Netz braucht, entscheidet das in seinem `docs/DECISIONS.md` und nennt die Adressen in `docs/PROJECT.md`.

### E-15 (12.10.2026): Ad hoc signiert, Developer ID als Schalter

- **Entscheidung:** Standard ist die Ad-hoc-Signatur; mit `signing.identity` in `starter.json` signiert `make dmg` mit Developer ID und Hardened Runtime, mit `signing.notarize: true` und einem Profil aus dem Schlüsselbund (`signing.notaryProfile`) notarisiert es App und DMG.
- **Grund:** Ohne Apple-Mitgliedschaft muss der Starter bauen und laufen; mit Mitgliedschaft genügt ein Wert.
- **Folgen:** Ad hoc signierte Builds verlieren Berechtigungen bei jedem neuen Build und brauchen beim Empfänger „Dennoch öffnen“ (`docs/VERTEILUNG.md`).

### E-16 (12.10.2026): Werkzeuge in Python 3.9 und zsh, kein Node

- **Entscheidung:** Werkzeuge, Prüfskripte und Hooks sind Python mit Standardbibliothek, lauffähig mit `/usr/bin/python3` der Command Line Tools (3.9); Shell-Skripte sind zsh mit `set -euo pipefail`.
- **Grund:** Beides ist auf jedem Mac mit den Command Line Tools vorhanden; eine Mac-App soll für ihre Werkzeuge kein Node brauchen.
- **Folgen:** Der Workflow `.claude/workflows/red-team.js` ist JavaScript, weil der Workflow-Runner von Claude Code es verlangt; sein Test läuft über JavaScriptCore (`osascript -l JavaScript`) ohne Node.

### E-17 (12.10.2026): Prüfen ohne Fenster

- **Entscheidung:** Beim Bauen und Prüfen startet niemand die App normal, fragt keine Berechtigung an, registriert kein Anmeldeobjekt und lässt keinen Prozess laufen. Laufzeitverhalten prüfen `make test`, `make shots` (`--render`) und `--selftest`, jeweils mit `STARTER_HEADLESS=1` (Aktivierungsrichtlinie `.prohibited`, kein Fenster vorne).
- **Grund:** Agenten und CI arbeiten auf Macs, auf denen Fenster und Systemdialoge stören oder nicht bedient werden können; Berechtigungen gehören der Person am Mac.
- **Folgen:** Was nur interaktiv prüfbar ist (Fensterverhalten, Insel an der echten Notch, Berechtigungsdialoge), steht in der Abnahme als eigener Punkt und wird von einer Person mit `make run` oder der installierten App geprüft.

## Arbeitsweise

### E-18 (12.10.2026): Dokumente auf Deutsch, Code und Commits auf Englisch

- **Entscheidung:** README, `docs/`, `CLAUDE.md`, Skills und Subagenten sind Deutsch; Bezeichner und Code-Kommentare Englisch; Commits `type(scope): subject` auf Englisch.
- **Grund:** Wie bei `app-starter`: Menschen lesen die Dokumente beim Einrichten, Werkzeuge und Code folgen der Sprache der Plattform.
- **Folgen:** Die Textprüfung prüft Dokumente mit den deutschen Sprachpaketen.

### E-19 (12.10.2026): Jede Oberfläche wird angesehen

- **Entscheidung:** Jede Szene wird in Englisch und Deutsch, hell und dunkel gerendert und mit dem Werkzeug Read angesehen, bevor eine Ansicht als fertig gilt. Ohne Bilder lautet eine Prüfung „nicht geprüft“, nie „ohne Befund“.
- **Grund:** Code zeigt weder abgeschnittene deutsche Texte noch graue Kästen auf Grau; nur Bilder zeigen das.
- **Folgen:** Jede sichtbare Änderung bringt Render-Szenen mit; der Workflow `red-team` rendert vor der Prüfung.

## Nach der Zusammenführung von Welle 1

### E-20 (12.10.2026): Eigene Funktionen melden sich in `Features.register()` an

- **Entscheidung:** `Modules.registerAll()` (Kit-Pfad) ruft als letzte Zeile `Features.register()` aus `App/Sources/Features/Features.swift` auf. Das ist ein Projektpfad: jede eigene Funktion bekommt dort eine Zeile wie `NotesFeature.register()` und trägt sich wie ein Modul in `Registry` ein. Tests eigener Funktionen liegen unter `App/Tests/Features/`.
- **Grund:** `Modules.swift` gehört dem Kit und bleibt im Projekt unverändert (A-06), `bin/starter sync` überschreibt es. Ohne einen Haken im Projektpfad hätte ein Projekt keinen Ort, an dem sich seine Funktionen anmelden.
- **Folgen:** Funktionen laufen nach Kit und Modulen an und dürfen jedes eingebaute Modul in `#if MODUL_<NAME>` nutzen. Das Beispielmodul `examples` ist ein Modul, keine Funktion: `bin/starter strip-examples` entfernt es, `Features.swift` bleibt leer.

### E-21 (12.10.2026): Die Komponenten-Galerie ist ein Bereich der Einstellungen

- **Entscheidung:** Die Galerie aller `Registry.gallery`-Einträge ist der Bereich „Galerie“ (Inhaltsgruppe) im Einstellungsfenster, kein eigenes Fenster. Sie erscheint in Debug-Builds und in Release-Builds nur mit `kit.showGallery: true` in `settings.json`; dafür gibt es bewusst keinen Schalter in der Oberfläche.
- **Grund:** Ein zweites Fenster mit derselben Ansicht wäre nur ein zweiter Einstieg mit eigener Fensterlogik. Im Einstellungsfenster gelten Seitenleiste, Suche, ⌘F und Fensterverwaltung schon.
- **Folgen:** `AppActions.openSettings(pane: "gallery")` öffnet sie. Endnutzer sehen sie nicht; „Einstellungen zurücksetzen“ behält `kit.showGallery`.

### E-22 (12.10.2026): Ausgewogene Zweizeiler nur als Unterzeile unter einem Titel

- **Entscheidung:** Ein fester Umbruch in einem UI-Text (`\n` mitten im Satz) ist erlaubt, wenn er eine Unterzeile direkt unter dem Titel eines Onboarding-Schritts oder Einstellungsbereichs in zwei etwa gleich lange Zeilen teilt, wie bei VoiceBud. Er steht an einer Satzgrenze (nach einem Komma oder vor einer Ergänzung), in jeder Sprache an ihrer eigenen Stelle, und `// umbruch: Grund` steht direkt über dem `tr`. Überall sonst (Knöpfe, Zeilen, Fußnoten, Fließtext, Menüs, Mitteilungen) bleibt jeder Umbruch mitten im Satz ein Befund (D-10).
- **Grund:** Unter einem zentrierten Titel in einer festen Spalte bricht ein langer Satz sonst mit einem einzelnen Wort in der zweiten Zeile um; das wirkt unfertig. Außerhalb solcher Unterzeilen hängt die Zeilenlänge von Fensterbreite und Sprache ab, ein fester Umbruch wäre dort falsch.
- **Folgen:** Jeder Zweizeiler wird in den Renders mit `de` und `en` angesehen; passt eine Zeile nicht mehr in die Spalte, fällt der Umbruch weg. Die Prüfung lässt den Umbruch nur unter dem Kommentar `// umbruch:` durch, alle anderen Regeln gelten für den Text weiter.

### E-23 (12.10.2026): „Einstellungen zurücksetzen“ behält Zustände

- **Entscheidung:** Zurücksetzen entfernt jede Einstellung, die die Person gewählt hat, und behält Zustände, die festhalten, wo sie war oder was schon geschehen ist: `onboarding.*`, `kit.showGallery`, die Nutzung der lokalen KI (`ai.usage`), ob nach dem Anmeldeobjekt schon gefragt wurde (`background.loginItemAsked`) und die gewählte Seite und Seitenleiste des Hauptfensters (`window.*`). Module melden solche Schlüssel mit `SettingsReset.keep(_:)` in `register()` an.
- **Grund:** Ein Zurücksetzen soll Vorlieben auf Anfang stellen, nicht die Einrichtung erneut starten, Fragen wiederholen oder das Fenster an eine andere Stelle springen lassen.
- **Folgen:** Wer einen neuen Schlüssel einführt, entscheidet beim Anlegen, ob er Einstellung oder Zustand ist (Skill `neue-einstellung`); Module, die Werte im Speicher halten, lesen sie in `SettingsReset.didReset` neu.
