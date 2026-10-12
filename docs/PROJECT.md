# Projekt

Vorlage. Der Agent füllt sie beim Start eines Projekts (Bootstrap-Schritt 3) und hält sie danach aktuell. Angaben in spitzen Klammern ersetzen; Abschnitte, die nicht zutreffen, mit „entfällt“ und Grund füllen, nicht löschen. Die Regeln in `CLAUDE.md` Teil A gelten unverändert; hier stehen nur die Festlegungen des Projekts.

## 1. Projekt

| Feld | Angabe |
|---|---|
| Name | `<Name, gleich app.name in starter.json>` |
| Bundle-ID | `<com.firma.app, gleich app.bundleId>` |
| Zweck | `<ein bis zwei Sätze>` |
| Zielgruppe | `<wer nutzt die App, welches Vorwissen>` |
| UI-Sprachen | Englisch und Deutsch, Anrede im Deutschen `<du oder Sie, gleich texts.anrede>` |
| Mindestversion | macOS `<26.0, gleich app.minimumMacOS>` |
| Akzent und Symbol | `<akzent>`, SF Symbol `<symbol>` |
| Auftraggeber | `<Name>` |

## 2. App-Formen

| Form | Modul | genutzt | Wofür |
|---|---|---|---|
| Fenster-App | `window` | `<ja oder nein>` | `<was das Hauptfenster zeigt>` |
| Menüleisten-App | `menubar` | `<ja oder nein>` | `<was das Statusmenü zeigt, welche Zustände das Symbol hat>` |
| Insel an der Notch | `island` | `<ja oder nein>` | `<welche Zustände die Insel zeigt>` |
| Hintergrund | `background` | `<ja oder nein>` | `<welche Aufgaben, wie oft, Start beim Anmelden>` |

## 3. Ansichten

| Ansicht | Ort | Frage der Nutzerin | Hauptaktion | Render-Szene |
|---|---|---|---|---|
| `<Übersicht>` | Hauptfenster, Seitenleiste „<Gruppe>“ | `<Was ist neu?>` | `<Eintrag anlegen>` | `<feature>.page` |
| `<Bereich>` | Einstellungen | `<Wie stelle ich X ein?>` | | `<feature>.pane` |

Jede Ansicht ist über `Registry` eingetragen (Seite, Einstellungsbereich, Onboarding-Schritt) und hat eine Render-Szene. Szenen eines Features heißen `<feature>.<zustand>` (etwa `notes.page`, `notes.pane`, `notes.empty`), damit `make shots ONLY=<feature>.` alle trifft; die Präfixe `window.`, `settings.`, `island.` und die anderen Modul- und Kit-Präfixe gehören dem Starter.

## 4. Datenobjekte und Speicher

| Objekt | Speicherort | Tabelle oder Schlüssel | Feature-Ordner |
|---|---|---|---|
| `<Notiz>` | `Database` (sqlite) | `<notes>` | `App/Sources/Features/<Notes>/` |
| `<Vorliebe>` | `Settings` (`settings.json`) | `<feature.key>` | |

Daten liegen unter `~/Library/Application Support/<bundleId>/`. Nichts verlässt den Mac ohne ausdrückliche Aktion der Nutzerin.

## 5. Berechtigungen

| Berechtigung | Wofür | Onboarding-Schritt | ohne sie |
|---|---|---|---|
| `<notifications>` | `<Hinweis, wenn eine Aufgabe fertig ist>` | ja | `<Funktion X ist aus, die App sagt warum>` |

Die Liste ist dieselbe wie `permissions` in `starter.json`; die Erklärtexte stehen in `App/Resources/InfoPlist.json` in beiden Sprachen.

## 6. Lokale KI

| Feld | Angabe |
|---|---|
| Funktionen mit KI | `<Zusammenfassen, Umschreiben oder entfällt>` |
| Anbieter | `<Apple Foundation Models, MLX-Modell oder beide>` |
| Modelle und Größe | `<Name, GB, nur bei mlx>` |
| Verhalten ohne KI | `<Funktion aus mit Hinweis, Vorlage statt Text>` |

## 7. Fachsprache

- **Begriffe mit Erklärung**: `<Begriff: ein Satz Erklärung>`
- **Verbotene Begriffe** dieses Projekts: `<Begriff und Ersatz>`. Jeder verbotene Begriff steht als Sprachpaket in `rules/projekt/pakete/` und jede Sprachregel in `rules/projekt/projekt.json`; hier steht nur die Übersicht.
- **Pflichtformulierungen** (wörtlich, mit Ort): `<Wortlaut, wo er steht>`

## 8. Verteilung

| Feld | Angabe |
|---|---|
| Signatur | `<ad hoc oder Developer ID, Team-ID>` |
| Notarisierung | `<ja oder nein, Profil im Schlüsselbund>` |
| Weitergabe | `<DMG per Link, interne Verteilung>` |
| Updates | `<neues DMG, keine automatische Prüfung>` |

Zugangsdaten für Signatur und Notarisierung stehen nie im Repository, nur im Schlüsselbund oder in den Geheimnissen der CI.

## 9. Festlegungen

Entscheidungen des Projekts stehen in `docs/DECISIONS.md` mit Datum, Grund und Folgen, die des Starters in `docs/STARTER_DECISIONS.md`.

## 10. Offene Fragen an den Auftraggeber

| Nr. | Frage | Kontext | Stand |
|---|---|---|---|
| 1 | Unter welcher Bundle-ID und welchem Team wird die App verteilt? | Bundle-ID und Signatur legen fest, wo macOS Einstellungen und Berechtigungen speichert; ein späterer Wechsel setzt beides zurück. | offen, bis `app.bundleId` und `signing` in `starter.json` stehen |
| 2 | `<Frage>` | `<wo sie auftrat, welche Optionen es gibt>` | offen |
