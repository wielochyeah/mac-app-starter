# Neues Projekt aus dem Starter

Der Weg von der Vorlage zu einem Projekt, das lokal baut, von einem Agenten weitergebaut wird und als DMG verteilt werden kann. Einzelheiten stehen in `docs/ARCHITEKTUR.md`, `docs/MODULE.md`, `docs/DESIGN.md` und `docs/VERTEILUNG.md`.

## 1. Repository anlegen

Der Starter liegt als Repository `wielochyeah/mac-app-starter` auf GitHub, unter „Settings“, „General“ als „Template repository“ markiert. Freigegeben ist der Stand mit dem Tag `v<Version>`; was er enthält, steht in `CHANGELOG.md`.

### Mit Zugang

„Use this template“ sieht nur, wer das Repository des Starters lesen darf; der Eigentümer lädt dafür unter „Settings“, „Collaborators“ mit der Rolle „Read“ ein. Denselben Lesezugriff braucht später `bin/starter sync`, weil es die Tags des Starters holt.

1. Im Repository des Starters „Use this template“ wählen, dann „Create a new repository“, Sichtbarkeit „Private“.
2. Auf einem Mac mit Apple Silicon und macOS 26 klonen:

   ```sh
   git clone git@github.com:<owner>/<repo>.git
   cd <repo>
   ```

### Ohne Zugang: Kopie per Archiv

Der Eigentümer erzeugt das Archiv des freigegebenen Stands (`git archive --format=tar.gz -o mac-app-starter-<version>.tar.gz v<version>`). Wer es erhält, legt daraus ein Repository an; die Werkzeuge lesen Dateien mit `git ls-files`, deshalb zuerst `git init` und ein erster Commit:

```sh
mkdir <repo> && tar -xzf mac-app-starter-<version>.tar.gz -C <repo> && cd <repo>
git init && git add -A
git -c user.name="<Name>" -c user.email="<E-Mail>" commit -m "chore: copy mac-app-starter <version>"
```

`bin/starter sync` braucht den Zugang zum Starter; ohne ihn kommen neuere Fassungen wieder als Archiv.

## 2. Einrichten

1. Werkzeuge prüfen: `make doctor`. Nötig sind die Command Line Tools (`xcode-select --install`), Xcode ist es nicht. Das Skript installiert nichts; meldet es eine gemischte Installation der Command Line Tools, nennt es die zwei Befehle zur Reparatur. `make build` funktioniert trotzdem, nur der zweite Weg über `Package.swift` nicht.
2. Projekt anlegen, einmal:

   ```sh
   bin/starter init --name "<Name>" --bundle-id <com.firma.app> --accent <akzent> --symbol <sf.symbol> --anrede du
   ```

   `init` schreibt `starter.json` um, entfernt die Bauunterlagen des Starters, legt Plan, Vorgaben und Strang-Plan als leere Vorlagen an, verschiebt die Entscheidungen des Starters nach `docs/STARTER_DECISIONS.md`, leert die Commit-Identität, die Unterzeile des Starters (`app.tagline`) und die Namensliste `texts.personen`, schreibt `starter.lock.json` und führt `make rules` aus, damit `CLAUDE.md` Teil A und die Wortlisten zur Anrede passen. Ohne `--non-interactive` fragt es nach und bietet die angegebenen Schalter als Vorschlag an; mit `--non-interactive` nimmt es die Angaben nur aus den Schaltern (`--name` ist dann Pflicht). Mit `--module-aus <modul>` fallen Module gleich weg. `--anrede sie` wählt die förmliche Anrede: die Texte des Kits sind in der du-Form geschrieben, `make check-texts` listet danach jede Stelle, die umzuschreiben ist. Eine eigene Unterzeile für den Willkommensschritt steht danach in `starter.json` als `app.tagline` mit `en` und `de`.
3. Commit-Identität des Projekts in `starter.json` eintragen (`commit.name`, `commit.email`; die Person, unter deren Namen das Projekt committet, nie eine erfundene), dann `make hooks`. `make hooks` setzt sie als Git-Identität dieses Repositorys, wenn Git noch keine kennt, und meldet eine abweichende, statt sie zu überschreiben. Bis die Identität in `starter.json` steht, nimmt der Hook `commit-msg` keinen Commit an.
4. Prüfen und ansehen:

   ```sh
   make check            # Regeln, Texte, Design, Kit, Build, Tests
   make shots            # jede Szene in en und de, hell und dunkel, nach build/shots
   make run              # die App einmal selbst starten
   ```

   `build/shots/index.html` zeigt alle Szenen als Übersicht. Beim ersten `make run` öffnet das Onboarding.

## 3. Selbst festlegen

Vor dem ersten eigenen Commit:

| Datei | Was |
|---|---|
| `starter.json` | Name, Bundle-ID, Anzeigename in beiden Sprachen, Akzent, Symbol, Copyright, Module, Berechtigungen, Anrede (`du` oder `sie`), Commit-Identität, Signatur |
| `App/Resources/InfoPlist.json` | Erklärtexte der Berechtigungen, die das Projekt nutzt, konkret für diese App |
| `docs/PROJECT.md` | Zweck, Zielgruppe, App-Formen, Ansichten, Daten, Berechtigungen, KI, Verteilung, offene Fragen |
| `README.md` | Einleitung und „Ein neues Projekt starten“ beschreiben noch den Starter; beides durch Zweck und Einrichtung des Projekts ersetzen, Aufbau, Befehle und Module bleiben |
| `App/Resources/AppIcon.icns` | `make icon` nach einer Änderung von Akzent oder Symbol; vor der ersten Weitergabe ein eigenes Motiv (`docs/VERTEILUNG.md`) |

Nicht benötigte Module entfernen, jedes mit eigenem Commit:

```sh
bin/starter remove island --probelauf
bin/starter remove island
git add -A && git commit -m "chore(setup): remove the island module"
```

`mlx` vor `ai`; mindestens `window` oder `menubar` bleibt. Die Beispiele entfernt `bin/starter strip-examples`, sobald das erste eigene Feature steht.

## 4. Agenten einrichten

Bauen, Testen und Rendern brauchen macOS; ein Linux-Container in der Cloud kann nur die Prüfskripte in Python ausführen. Deshalb:

- **Claude Code auf dem Mac** (Terminal oder Desktop-App) für die Arbeit an der App. Der Hook `session-start` prüft die Werkzeuge, setzt `core.hooksPath` und die Git-Identität aus `starter.json`, wenn Git noch keine kennt; eine vorhandene überschreibt er nie, er meldet nur, wenn sie abweicht.
- **Claude Code in der Cloud** für Dokumente, Regeln und Werkzeuge; die CI auf `macos-26` führt bei jedem Push `make check` aus und baut, rendert und probt alle Module bei Pull Requests, auf `main` und bei Tags. Unter „Network access“ der Umgebung genügt `github.com`.

Den Bootstrap-Prompt aus dem `README.md` mit Name, Zweck, Zielgruppe, App-Formen und Hauptansichten füllen und senden. Neue Wünsche während der Arbeit kommen in `docs/agents/VORGABEN.md`; der Agent arbeitet sie als Regel in `rules/projekt/` ein.

Agenten starten die App beim Bauen nie selbst, fragen keine Berechtigung an und registrieren kein Anmeldeobjekt; sie prüfen mit `make test`, `make shots` und `--selftest`. Den Start der App, das Onboarding auf einem frischen Benutzer und die Berechtigungsdialoge prüft eine Person.

## 5. Branchschutz

`main` nimmt nur Stände an, bei denen die CI grün ist:

```sh
gh api -X PUT repos/<owner>/<repo>/branches/main/protection \
  -f "required_status_checks[strict]=true" \
  -f "required_status_checks[contexts][]=Regeln, Texte, Design, Kit, Commits" \
  -f "required_status_checks[contexts][]=make check (starter.json)" \
  -F "enforce_admins=true" -F "required_pull_request_reviews=null" -F "restrictions=null"
```

Die Namen der Prüfungen sind die Namen der Jobs in `.github/workflows/ci.yml`. `strict=true` ist nötig: nur dann hat der Pull Request genau den Stand geprüft, der auf `main` landet, und der Merge braucht keinen zweiten `make check`.

Minuten auf macOS-Runnern zählen in privaten Repositorys zehnfach, Linux-Minuten einfach. Deshalb entscheidet der Job `Plan` (`.github/ci_plan.py`), welche Mac-Jobs ein Ereignis braucht:

| Ereignis | Jobs | Mac-Minuten, geschätzt |
|---|---|---|
| Push auf einen Arbeits-Branch | `Regeln, Texte, Design, Kit, Commits` (Linux, mit den Python-Tests) | 0 |
| Pull Request, kein Entwurf, jede Aktualisierung | dazu `make check (starter.json)`: `make check` mit Warnungen als Fehler, Selbsttest, Release-Build, Python-Werkzeuge unter `/usr/bin/python3` 3.9 | etwa 10 |
| Pull Request als Entwurf, oder nur Doku geändert (`*.md` außerhalb von `App/`, `docs/`) | nur Linux | 0 |
| Merge über GitHub auf `main` | `Modul-Kombinationen (typecheck)`: jede Kombination aus `.github/ci_plan.py` in einem Job geprüft, ohne zu bauen; `Renders (en, de, hell, dunkel)` | etwa 15 |
| direkter Push auf `main`, wöchentlich montags, `gh workflow run ci.yml --ref <branch>` | dazu `make check (starter.json)` | etwa 25 |
| Tag `v*` | alles davon und `DMG` | etwa 30 |
| im Starter selbst: `main`, Tags, Lauf von Hand | dazu `Template-Probe` und `Modul entfernen (<modul>)` je Modul | etwa 60 mehr |
| Kopie aus „Use this template“ vor `bin/starter init` | nur `Einrichten (bin/starter init)` (Linux), schlägt mit dem Hinweis auf `bin/starter init` fehl | 0 |

Die Schätzung beruht auf etwa dem Dreifachen der Zeiten auf einem Mac mit Apple Silicon (`make check` 2,5 Minuten, `make typecheck` 3 Minuten). Ein Pull Request mit fünf Aktualisierungen kostet so etwa 50 Mac-Minuten, abgerechnet 500; vorher liefen je Aktualisierung bis zu 27 Mac-Jobs. Renders behalten die CI drei Tage: bei Grün nur die Bilder aus `docs/screenshots/list.txt` und die Übersicht, bei Rot alle. Wer weiter sparen muss, kürzt `COMBOS` in `.github/ci_plan.py`, nie die Prüfungen.

Der Plan liest aus den Ordnern unter `App/Sources/Modules/`, welche Module es noch gibt: Kombinationen mit einem entfernten Modul fallen weg. Ein Repository gilt nur als der Starter, wenn es `repository` aus `starter.manifest.json` ist (Groß- und Kleinschreibung zählen nicht); jede andere Kopie ohne `bin/starter init` bekommt keinen Mac-Job.

## 6. Verteilen

`make dmg` baut ein DMG mit gestaltetem Fenster; Signatur, Notarisierung, Gatekeeper und Berechtigungen beim Empfänger stehen in `docs/VERTEILUNG.md`, die Schritte im Skill `release-dmg`.

## 7. Neuere Fassungen des Starters übernehmen

```sh
bin/starter sync --ziel v1.1.0 --probelauf
bin/starter sync --ziel v1.1.0
```

Ohne `--quelle` holt `sync` die Tags von GitHub (`source` in `starter.lock.json`), per SSH, wenn `origin` des Projekts SSH nutzt, sonst per HTTPS. Ist der Starter privat und das Projekt per HTTPS geklont, die Quelle per SSH angeben, damit kein Passwort gefragt wird:

```sh
bin/starter sync --ziel v1.1.0 --quelle git@github.com:wielochyeah/mac-app-starter.git
```

Zugangsdaten in der Adresse (`https://<token>@github.com/…`) lehnt `sync` ab. Ein lokaler Klon des Starters geht als Pfad (`--quelle ../mac-app-starter`).

Der Probelauf zeigt, was sich ändert. Der echte Lauf übernimmt Kit-Pfade, führt gemeinsame Dateien dreifach zusammen und lässt entfernte Module entfernt; er committet nichts und endet mit Code 2, wenn Konflikte bleiben. Danach zuerst `git diff` lesen, vor allem Hooks, CI und Skripte, dann `make rules`, Konflikte lösen, `make check`. Was im Starter allgemein fehlt, kommt nach `docs/STARTER_FEEDBACK.md`; der Skill `starter-rueckfluss` macht daraus einen Pull Request im Starter.

## 8. Nie

- Kit-Pfade aus `starter.manifest.json` oder Teil A von `CLAUDE.md` ändern; eigene Regeln kommen nach `rules/projekt/`.
- Zertifikate, Notarisierungsprofile, Passwörter oder Tokens committen, ausgeben oder als Argument übergeben.
- Mit einer anderen Git-Identität committen als der aus `starter.json`, Hooks mit `--no-verify` umgehen oder auf `main` force-pushen.
- Unter der Bundle-ID oder Signatur eines anderen Projekts verteilen.
- Renders, DMGs, Modelle oder Daten unter echten Namen ins Repository legen; nur die Auswahl in `docs/screenshots/` über `make readme-shots`.
