# Verteilung

Wie aus dem Quellcode eine App wird, die jemand auf einem anderen Mac installiert: App-Bundle, Signatur, DMG, Notarisierung, Gatekeeper, Berechtigungen und Anmeldeobjekt. Die Schritte einer Fassung stehen im Skill `release-dmg`.

## 1. Das App-Bundle

`make build` (Debug) und `make build CONFIG=release` (optimiert) erzeugen `build/<Name>.app`:

```
<Name>.app/Contents/
  Info.plist                     aus starter.json (scripts/gen_config.py), dazu im Binary eingebettet
  MacOS/<Name>                   ein swiftc-Aufruf über Kit, Features und die eingeschalteten Module
  Resources/AppIcon.icns         aus make icon
  Resources/<lang>.lproj/InfoPlist.strings   Erklärtexte der Berechtigungen in en und de
  PkgInfo
```

- `LSUIElement` ist `true`, wenn das Modul `window` fehlt: die App hat dann kein Dock-Symbol und lebt in der Menüleiste.
- `LSMinimumSystemVersion` ist `app.minimumMacOS` (Standard 26.0); das Binary trägt dieselbe Mindestversion.
- Nur Apple Silicon (arm64). Rosetta wird nicht unterstützt.
- Der Build entsteht in einem temporären Ordner und ersetzt das alte Bundle erst am Ende, damit eine laufende Kopie nicht beschädigt wird.

## 2. Signatur

| Weg | Einstellung in `starter.json` | Folge |
|---|---|---|
| ad hoc (Standard) | `signing.identity: "-"` | kostet nichts; Gatekeeper blockiert den ersten Start auf fremden Macs; Berechtigungen gelten nur für genau diesen Build |
| Developer ID | `signing.identity: "Developer ID Application: <Name> (<Team-ID>)"`, `signing.teamId` | Hardened Runtime mit Entitlements aus `build/gen/App.entitlements`; mit Notarisierung startet die App ohne Warnung |

**Ad hoc und Berechtigungen.** macOS verknüpft erteilte Berechtigungen (Mikrofon, Bedienungshilfen, Eingabeüberwachung, Bildschirmaufnahme) mit der Signatur des Builds. Ein ad hoc signierter neuer Build ist für macOS eine andere App: erteilte Berechtigungen gelten nicht mehr, die App fragt erneut oder zeigt sie als fehlend. Das betrifft die Entwicklung (jedes `make build`) und jede neue Fassung beim Empfänger. Abhilfe ist eine Developer ID; zum Testen setzt `tccutil reset All <bundleId>` den Stand nur dieser App zurück.

**Developer ID.** Das Zertifikat liegt im Schlüsselbund des Build-Macs, nie im Repository. Unter der Hardened Runtime braucht jede Berechtigung ihr Entitlement; `scripts/gen_config.py` schreibt sie aus `permissions`. Ausnahmen der Hardened Runtime (etwa nicht signierter ausführbarer Speicher) brauchen einen Eintrag in `docs/DECISIONS.md`.

## 3. DMG

`make dmg` baut die Release-Fassung und daraus `build/dmg/<Name>-<version>.dmg`:

- Fenster 640 x 432 pt (400 pt Hintergrund und 32 pt Titelleiste von macOS 26), App-Symbol links und die Verknüpfung „Applications“ rechts, je 112 pt groß, dazwischen ein gepunkteter Pfeil.
- Hintergrund aus `tools/dmg/Background.swift` im Stil der App (Akzent aus `starter.json`), als TIFF mit 1x und 2x; bei ad hoc signierten Builds mit einem Hinweis auf „Dennoch öffnen“.
- Layout über dmgbuild (Python-Paket in `build/tools-venv`, legt `make dmg` beim ersten Lauf an), ohne Finder-Skripte und ohne Automatisierungsrecht. `hide_extensions` bleibt aus: es setzt Finder-Informationen an der App, und eine signierte App mit solchen Informationen besteht die strenge Signaturprüfung nicht mehr („beschädigt“ statt „Dennoch öffnen“).
- Der Hintergrund ist mit `chflags hidden` verborgen, das Abbild komprimiert (ULMO, ersatzweise UDZO), das Volume trägt das App-Symbol.
- Prüfen ohne Finder: `hdiutil attach -nobrowse -readonly -mountpoint <ordner> <dmg>`, Inhalt ansehen, `codesign --verify --deep --strict <ordner>/<Name>.app`, `hdiutil detach <ordner>`.

DMGs gehören nie ins Repository (`.gitignore`); die CI legt das DMG eines Tags als Artefakt ab.

## 4. Notarisierung

Nur mit Developer ID und nur auf ausdrücklichen Wunsch. `make notarize` (`scripts/notarize.sh`) signiert mit Hardened Runtime, reicht das DMG mit `xcrun notarytool submit --wait` ein und heftet das Ergebnis mit `xcrun stapler staple` an. Zugangsdaten kommen aus einem Schlüsselbund-Profil (`xcrun notarytool store-credentials <profil>`), nie aus Dateien, Argumenten oder Umgebungsvariablen im Repository. Ohne Profil bricht das Skript mit einer klaren Meldung ab, statt still unsigniert zu verteilen.

Nach der Notarisierung: `spctl -a -vv <app>` meldet „Notarized Developer ID“, `xcrun stapler validate <dmg>` besteht.

## 5. Gatekeeper beim Empfänger

| Build | erster Start |
|---|---|
| notarisiert | startet nach der üblichen Rückfrage für Apps aus dem Internet |
| ad hoc signiert | macOS blockiert den Start. In den Systemeinstellungen unter „Datenschutz & Sicherheit“ erscheint die App mit „Dennoch öffnen“; danach startet sie. Den früheren Weg über Rechtsklick und „Öffnen“ gibt es auf aktuellem macOS nicht mehr |

Verwaltete Macs (MDM) können nicht notarisierte Apps ganz sperren. Wer an solche Macs verteilt, braucht eine Developer ID.

## 6. Berechtigungen beim Empfänger

- Gefragt wird im Onboarding oder beim ersten Gebrauch der Funktion, nie beim Start ohne Zusammenhang.
- Bedienungshilfen, Eingabeüberwachung und Bildschirmaufnahme schaltet die Nutzerin in den Systemeinstellungen ein; die App öffnet den passenden Bereich und erkennt die Änderung selbst. Manche wirken erst nach einem Neustart der App; das Onboarding speichert vorher seinen Stand.
- Nach einer neuen ad hoc signierten Fassung sind diese Berechtigungen erneut zu erteilen (Abschnitt 2).

## 7. Anmeldeobjekt (Modul `background`)

`SMAppService.mainApp` registriert die App als Anmeldeobjekt. Das geht nur aus einem installierten Ort (`/Applications` oder `~/Applications`, im Finder „Programme“), nicht aus `build/`; die App zeigt den Schalter sonst nicht und sagt, warum. Beim Bauen und Testen wird nie ein Anmeldeobjekt registriert. Die Nutzerin sieht und entfernt es in den Systemeinstellungen unter „Allgemein“, „Anmeldeobjekte“.

## 8. Vor der ersten Weitergabe

- Eigenes App-Symbol: `make icon` setzt ein SF Symbol aus `app.symbol` auf eine Fläche im Akzent. Die Bedingungen für SF Symbols verbieten sie (und ähnlich aussehende Bilder) in App-Symbolen, Logos und jeder anderen Verwendung als Marke (Human Interface Guidelines, „SF Symbols“). Das erzeugte Symbol ist deshalb nur für die Entwicklung; `make icon` und `make dmg` sagen das bei jedem Lauf. Vor der ersten Weitergabe bekommt die App ein eigenes Motiv: eine eigene Zeichnung in `tools/icon/Icon.swift` (gemeinsamer Pfad, das Projekt darf ihn ändern) oder eine fertige `AppIcon.icns` mit Rechten des Projekts. Der DMG-Hintergrund zeigt das App-Symbol aus `App/Resources/AppIcon.icns` und ändert sich damit.
- `app.bundleId` endgültig wählen: sie bestimmt den Ort der Daten (`~/Library/Application Support/<bundleId>/`), die Einstellungen und die Berechtigungen. Ein späterer Wechsel beginnt bei null.
- `app.version` und `app.build` setzen, `CHANGELOG.md` ergänzen, `THIRD_PARTY_NOTICES.md` um mitgelieferten Fremdcode ergänzen.
- Auf einem zweiten Mac oder Benutzer installieren und das Onboarding einmal ganz durchgehen (`docs/vorlagen/ABNAHME.md`, AK-60).

## 9. Updates

Der Starter enthält keine automatische Update-Prüfung (kein Netz ohne Auftrag der Nutzerin). Eine neue Fassung ist ein neues DMG mit höherer `app.build`; Einstellungen und Daten unter `~/Library/Application Support/<bundleId>/` bleiben erhalten. Ein Projekt, das Updates aus dem Netz will, entscheidet das in `docs/DECISIONS.md` und nennt die Adresse im Datenschutzteil von `docs/PROJECT.md`.
