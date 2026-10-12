# tools/: Werkzeuge für Icon, DMG und Notarisierung

Kleine Programme, die beim Bauen auf diesem Mac laufen. Sie landen nie in der App. Aufgerufen werden sie über `make`, nicht direkt.

| Befehl | Was passiert | Ergebnis |
|---|---|---|
| `make icon` | `scripts/icon.sh` baut `tools/icon/Icon.swift` und rendert das Icon aus `app.accent` und `app.symbol` (starter.json) | `App/Resources/AppIcon.icns` (wird eingecheckt), Vorschauen in `build/icon/` |
| `make dmg` | `scripts/dmg.sh`: Release-Build, Signatur, Fensterhintergrund, dmgbuild, Komprimierung, Prüfung | `build/dmg/<Name>-<Version>.dmg`, Fenstervorschau `build/dmg/preview.png` |
| `make notarize` | `scripts/notarize.sh`: einreichen und heften (nur mit Developer ID). Für eine fertige DMG reicht `signing.notarize: true` und `make dmg`; eine DMG mit „Dennoch öffnen“-Hinweis im Fenster lehnt `make notarize` ab | notarisierte `.app` oder `.dmg`; `--dry-run` zeigt nur die Befehle |

## Icon

- Apple-Raster: 1024er Fläche, Körper 824, kontinuierlicher Radius 185, zwei Schlagschatten, helle Perlfläche mit einem Hauch Akzent, SF Symbol mit Akzentverlauf, Leuchten, Glanzkante, Haarlinie (Technik aus VoiceBud).
- Farben kommen aus `Kit/Design/Theme.swift` (`AccentPalette`): das Werkzeug wird mit `Theme.swift` und `Tokens.swift` zusammen kompiliert. Keine kopierten Hex-Werte.
- 16, 32 und 64 px sind eigene Vorlagen: Körper und Symbol auf ganzen Pixeln, Symbol größer, kein Leuchten. Ein verkleinertes 1024er-Bild verschmiert dort.
- Symbolfarben: `ink` ist die Akzentfarbe, so weit abgedunkelt, dass sie auch auf der dunkelsten Stelle der Fläche 3:1 erreicht (bei Orange deutlich, sonst um etwa 10 %). Ab 128 px läuft das Symbol von einem hellen Glanzpunkt oben über `ink` zum dunklen Ende; die kleinen Vorlagen (16/32/64) zeichnen es nur in `ink` und dunklem Ende, ohne Glanz, sonst verblassen kleine Teile wie die Sterne von `sparkles`.
- `build/tools/icon selftest` prüft Pixelraster, Lage des Symbols und für alle Akzente, dass `ink` und dunkles Ende oben, in der Mitte und unten auf der Fläche mindestens 3:1 haben und die kleinen Vorlagen keinen Glanz tragen. `make icon` führt ihn jedes Mal aus, `make test` baut beide Werkzeuge und führt ihn ebenfalls aus.
- Ausprobieren ohne die Datei im Repo zu ändern: `ICON_OUT=build/test.icns ICON_ACCENT=rot ICON_SYMBOL=music.note make icon`, dann `build/icon/preview.png` ansehen.
- Ein Icon Composer `.icon` (Liquid Glass) geht nur mit Xcode (`actool`). Ohne Xcode bleibt es bei `.icns`.

## DMG

- Fenster 640 x 400 pt Hintergrund (+ 32 pt Titelleiste ab macOS 26), Icons 112 pt bei (170, 158) und (470, 158). Die eine Quelle dafür ist `tools/dmg/layout.json`; `settings.py` (dmgbuild) und `Background.swift` lesen sie.
- Der Link heißt in jeder Sprache `Applications`: Finder übersetzt den Namen eines Links nicht. Der deutsche Hinweis sagt deshalb „Zieh … auf „Applications““.
- Die Zieh-Zeile nennt die App so, wie Finder sie unter dem Icon zeigt: mit dem Dateinamen des Bundles (`app.name`). Die Überschrift zeigt `displayName` (bei rein deutschem Fenster `displayName.de`).
- Texte: `DMG_LANG=en|de|both`, Standard `both`, wenn das Projekt beide Sprachen hat. Englisch oben, Deutsch leiser darunter. Die deutsche Anrede folgt `texts.anrede` („Zieh …“ oder „Ziehen Sie …“).
- Der Gatekeeper-Hinweis („Beim ersten Start blockiert? Systemeinstellungen › Datenschutz & Sicherheit › „Dennoch öffnen““, englisch „Open Anyway“) erscheint, solange die DMG nicht notarisiert ist. Er steht klein und ohne Rahmen unter der Zieh-Zeile. Die Taste gibt es erst, nachdem macOS einen Start blockiert hat, deshalb die Frage vorweg. Rechtsklick › Öffnen hilft seit macOS 15 nicht mehr, deshalb steht es nicht da.
- `build/dmg/preview.png` zeigt das Fenster mit schwarzen Beschriftungen wie in Finder, `preview-dark.png` mit weißen (falls Finder sie im Dunkelmodus weiß zeichnet; auf dem hellen Hintergrund wären sie dann kaum lesbar).
- `DMG_NO_BUILD=1 make dmg` verpackt die vorhandene `build/<Name>.app` ohne neuen Build, aber nur einen Release-Build (ein Debug-Build hat eine Debug-Map und wird abgelehnt). `NO_BUILD` (für Bilder und Tests) gilt für `make dmg` nicht.
- dmgbuild läuft in `build/tools-venv` (System-Python 3.9). Die Versionen stehen mit Hash in `tools/dmg/requirements.txt`; sie werden einmal von PyPI geladen. dmgbuild 1.6.6+ braucht Python 3.10, deshalb 1.6.5.
- Kein `hide_extensions`: das setzt Finder-Infos an der App und bricht die strenge Signaturprüfung („beschädigt“ statt „Dennoch öffnen“).
- Die App wird in `build/dmg/work.noindex` zusammengestellt (Spotlight und Launchpad zeigen sie dort nicht als zweite App) und danach gelöscht; `KEEP_WORK=1` behält sie.
- Ist das Modul `mlx` an, ruft `make dmg` `ai-worker/package.sh <Pfad zur .app>` auf, sobald es das Skript gibt, und sagt es in der Ausgabe.

## Signieren und Notarisieren

- Standard ist ad hoc (`signing.identity: "-"`). Jeder neue Build verliert dann erteilte Freigaben (Mikrofon, Bedienungshilfen …), und Empfänger müssen einmal „Dennoch öffnen“ klicken.
- Mit Developer ID: `signing.identity` auf den Namen des Zertifikats setzen (`security find-identity -v -p codesigning`). `make dmg` signiert dann von innen nach außen mit Hardened Runtime und Zeitstempel. Die Berechtigungen kommen aus `build/gen/App.entitlements` (aus `permissions`) plus `tools/entitlements.plist` (eigene Zusätze, gewinnen bei gleichem Schlüssel).
- Notarisieren: einmal `xcrun notarytool store-credentials <profil> --apple-id <id> --team-id <team>`, dann `NOTARY_PROFILE=<profil>` setzen (oder `signing.notaryProfile` in starter.json) und `signing.notarize: true`. `make dmg` notarisiert und heftet dann App und DMG (die App einzeln, damit auch die Kopie in /Programme ihr Ticket trägt) und lässt den Hinweis im Fenster weg. `SIGN_IDENTITY` und `NOTARY_PROFILE` in der Umgebung gehen vor starter.json.
- `LSMinimumSystemVersion` wird gegen die `minos` aller Binaries in der App geprüft. Braucht eine Bibliothek ein neueres macOS, bricht `make dmg` mit der Zahl ab, die in `app.minimumMacOS` gehört.

## Dateien

| Datei | Inhalt |
|---|---|
| `icon/Icon.swift` | Icon-Werkzeug: `master`, `small`, `iconset`, `preview`, `smallcheck`, `dock`, `selftest` |
| `dmg/Background.swift`, `dmg/DMGText.swift` | Fensterhintergrund 1x/2x und Vorschau mit Icons |
| `dmg/settings.py`, `dmg/layout.json`, `dmg/requirements.txt` | dmgbuild-Einstellungen, Fenstermaße, gepinnte Pakete |
| `packaging/pkg.py` | liest starter.json für die Skripte, findet Mach-O-Dateien, prüft minos, mischt Berechtigungen, plant die Notarisierung |
| `lib/packaging.sh` | gemeinsame zsh-Funktionen: Werkzeuge bauen, von innen nach außen signieren |
| `entitlements.plist` | zusätzliche Hardened-Runtime-Berechtigungen (leer) |

Tests: `scripts/tests/test_packaging.py` (läuft in `make test`).
