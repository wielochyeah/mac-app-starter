# Status J (Packaging: Icon, DMG, Notarisierung)

Stand: 2026-10-12, Branch `strang/J` (Worktree `wt/J`). Alles aus STRANDS.md §J ist gebaut, auf diesem Mac ausgeführt und angesehen; die Notarisierung nur als Probelauf (keine Zugangsdaten).

## Was gebaut ist

| Bereich | Dateien |
|---|---|
| Icon | `tools/icon/Icon.swift`, `scripts/icon.sh`, `App/Resources/AppIcon.icns` (eingecheckt, 1,1 MB, für violett + sparkles) |
| DMG | `tools/dmg/Background.swift`, `tools/dmg/DMGText.swift`, `tools/dmg/settings.py`, `tools/dmg/layout.json`, `tools/dmg/requirements.txt`, `scripts/dmg.sh` |
| Signieren, Notarisieren | `scripts/notarize.sh`, `tools/entitlements.plist` |
| Gemeinsam | `tools/packaging/pkg.py` (starter.json lesen, Mach-O finden, minos prüfen, Berechtigungen mischen, Notarisierung planen), `tools/lib/packaging.sh` (Werkzeuge bauen, von innen nach außen signieren) |
| Doku, Tests | `tools/README.md`, `scripts/tests/test_packaging.py` (34 Tests, davon 3, die beide Werkzeuge bauen und ausführen) |

Make-Ziele `icon`, `dmg`, `notarize` gab es schon im Makefile (S0); sie rufen jetzt die Skripte auf.

## Entscheidungen

- **Eine Farbquelle.** Icon- und DMG-Werkzeug werden mit `Kit/Design/Theme.swift` und `Tokens.swift` kompiliert, dazu ein generierter Einzeiler `build/tools/ToolConfig.swift` (`AppConfig.accent`), weil das echte `AppConfig` die ganze App nach sich zieht. Akzentfarben, Schriftgrade und Abstände sind damit dieselben wie in der App.
- **Icon-Aufbau** wie VoiceBud (Raster 1024/824/185, zwei Schlagschatten, Perlfläche mit Glanzlicht, Vignette und Akzentschimmer, Innenkante, Glasrand, Haarlinie), statt Insel und Wellenform das SF Symbol aus `app.symbol`: Verlauf `gradientTop`/`brand`/dunkles Ende, weicher Schatten, Akzentleuchten, Glanz auf der oberen Hälfte, Akzentlicht darunter. Symbolgröße nach dem gemessenen Tintenrahmen (längste Seite 520 von 824), nicht nach `NSImage.size`.
- **Symbolmaske über RGBA-Alpha**: `NSImage` zeichnet nicht in einen DeviceGray-Kontext (leer, geprüft), deshalb RGBA zeichnen und den Alphakanal als Maske nehmen.
- **Kleine Größen** 16/32/64: Körper auf ganzen Pixeln (Einzug `round(px·100/1024)` = 2/3/6 px), Symbolrahmen auf ganze Pixel gerundet und mittig (8/16/33 px), kein Leuchten bei 16, weniger Effekte. Alle anderen Größen werden je Pixelgröße neu gerendert (kein `sips`-Verkleinern). `iconutil` erzeugt dieselbe `.icns` bei gleichem Eingang (Prüfsumme zweimal gleich).
- **Kontrast als Test**: der Selbsttest fand bei Orange 2,95:1 zwischen dunklem Symbolende und Fläche. Das dunkle Ende wird jetzt je Akzent so weit abgedunkelt, bis es 3:1 erreicht (Violett unverändert). Nach dem Review: auch der Symbolkörper (`ink`) erreicht 3:1 auf der dunkelsten Stelle der Fläche, die kleinen Vorlagen haben keinen hellen Glanzpunkt mehr (siehe Review).
- **DMG-Maße aus einer Datei** (`tools/dmg/layout.json`), gelesen von `settings.py` und `Background.swift`; Werte wie VoiceBud (Fenster 640 x 432 inkl. 32 pt Titelleiste, Icons 112 bei (170, 158)/(470, 158), Text 13, alles Chrom aus).
- **Hintergrund**: hell, leichter Akzentton unten, Akzentlicht hinter der Icon-Reihe, oben App-Name und „Version 1.0.0 · macOS 26+“, gepunkteter Pfeil im Akzentverlauf, darunter die Zieh-Zeile (nennt die App wie Finder: Dateiname des Bundles) und, kleiner und ohne Rahmen, der Gatekeeper-Hinweis mit `lock.open.fill`. Standard zweisprachig (`DMG_LANG=both`, Englisch kräftig, Deutsch leiser darunter), `en`/`de` einzeln möglich. Der Block unter den Icons ist zwischen Beschriftung und Unterkante zentriert, damit er auch ohne Hinweisfeld richtig sitzt.
- **Gatekeeper-Hinweis**: „Beim ersten Start blockiert?“, dann „Systemeinstellungen › Datenschutz & Sicherheit › „Dennoch öffnen““, nicht „Rechtsklick › Öffnen“ (seit macOS 15 kein Umweg mehr; die App braucht macOS 26). Er erscheint bei jeder nicht notarisierten DMG, also auch mit Developer ID ohne Notarisierung.
- **Link heißt immer `Applications`** (Finder übersetzt Link-Namen nicht; VoiceBuds „Programme“ verwirrte Englischsprachige). Der deutsche Satz nennt den Ordner deshalb „Applications“.
- **dmgbuild 1.6.5, ds_store 1.3.1, mac_alias 2.2.2** mit SHA-256 und `--require-hashes --only-binary :all:` in `build/tools-venv`, angelegt mit `/usr/bin/python3` (3.9.6). Die neuesten Versionen (1.6.7/1.3.3/2.2.3, wie VoiceBud) verlangen Python 3.10. Die venv wird neu gebaut, wenn sich `requirements.txt` ändert; die Ausgabe nennt die installierten Pakete.
- **Zusammenstellen in `build/dmg/work.noindex`** (Spotlight/Launchpad), am Ende `lsregister -u` und Löschen (`KEEP_WORK=1` behält).
- **Signieren von innen nach außen ohne `--deep`** (VoiceBud-Befund: `--deep` ließ den Helfer in `Resources/` unsigniert): erst alle Mach-O-Dateien (tiefste zuerst), dann verschachtelte Bundles, dann die App, danach `codesign --verify --strict --deep`. Ad hoc ohne Hardened Runtime; Developer ID mit `--options runtime --timestamp` und gemischten Berechtigungen (`build/gen/App.entitlements` von S0 plus `tools/entitlements.plist`, Zusätze gewinnen).
- **minos-Prüfung** (VoiceBud-Technik, als Prüfung statt Ableitung): `LSMinimumSystemVersion` bleibt `app.minimumMacOS`; braucht ein Binary in der App mehr, bricht `make dmg` ab und nennt Datei und Zahl.
- **ULMO** (lzma, kleinste) als Standard, Rückfall UDZO zlib-9; `DMG_FORMAT` überschreibt.
- **Prüfung jeder DMG** in `dmg.sh`: `hdiutil verify`, schreibgeschützt einhängen, App, Link-Ziel, `.background.tiff` (versteckt), `.DS_Store`, `.VolumeIcon.icns`, App-Signatur; sonst Abbruch.
- **Notarisierung**: Zugang über ein notarytool-Schlüsselbundprofil (`NOTARY_PROFILE` oder optional `signing.notaryProfile`; der Schlüssel wird gelesen, wenn er da ist, S0s starter.json habe ich nicht erweitert). `.app`: prüfen, zippen (`ditto --keepParent`), `submit --wait`, heften, `spctl`. `.dmg`: signieren, `submit --wait`, heften, `spctl`. Mit `signing.notarize: true` und echter Identität ruft `make dmg` beides auf (App vor dem Einpacken, dann die DMG). Ad hoc, fremde Zertifikatsarten und fehlendes Profil werden mit konkreter Abhilfe abgelehnt.
- **`ai-worker/package.sh`**: Vertrag für Strang H: wird mit dem Pfad der zusammengestellten `.app` aufgerufen, bevor signiert wird; alles, was es hineinlegt, signiert `sign_app` mit. Fehlt das Skript bei aktivem `mlx`, sagt `make dmg` das.

## Aus VoiceBud übernommen (MIT, Copyright (c) 2026 Anas Riad; für THIRD_PARTY_NOTICES)

- `assets/icon-source/Icon.swift`: Apple-Raster und Ebenenfolge, `rgb`/`gradient`-Helfer, `strokeInside` (Gradientstrich nur innen), Schattenmaßstab `s`, Schlagschatten-Paar, Perlfläche mit Glanzlicht/Vignette/Schimmer, Glasrand, Haarlinie, eigene kleine Vorlagen 16/32/64, Befehle `master`/`small`/`preview`/`smallcheck`/`dock` → `tools/icon/Icon.swift`
- `assets/icon-source/build.sh`: iconset-Zuordnung + `iconutil` → `scripts/icon.sh`
- `packaging/dmg/Background.swift`: gepunkteter Verlaufspfeil (Strich 0,1/8 mit runden Enden), Zieh-Zeile + Hinweiskapsel mit `lock.open.fill`, Licht hinter der Icon-Reihe, Vorschau mit echten Icons, Ausgabe 1x/2x über `ImageRenderer` → `tools/dmg/Background.swift`
- `packaging/dmg/settings.py`: Fenster, Icon-Lagen und -Größe, Chrom aus, UDRW + HFS+, kein `hide_extensions` (mit Begründung) → `tools/dmg/settings.py`
- `packaging/build-dmg.sh`: `tiffutil -cathidpicheck`, dmgbuild, `chflags hidden` auf eingehängtem UDRW-Abbild, Komprimieren, `.noindex`-Ablage, `lsregister -u`, minos aus `otool -l` → `scripts/dmg.sh`, `tools/packaging/pkg.py`

## Außerhalb meines Strangs angefasst

- `scripts/doctor.sh` (S0): eine Zeile, prüft dmgbuild jetzt in `build/tools-venv` statt `build/venv-dmg` (S0 hatte den Ort mir überlassen).
- `scripts/tests/test_packaging.py`: neue Datei im Testordner von S0 (dort sucht `scripts/test.sh` Python-Tests).

Für andere Stränge zum Abgleich:
- **G (`check_texts.py`, `check_design.py`)**: `tools/**` bitte ausnehmen. Die Werkzeuge haben bewusst Zahlen-Literale (Icon-Geometrie) und eigene en/de-Paare in `DMGText` statt `tr()` (kein `Localizer` in einem Build-Werkzeug). THIRD_PARTY_NOTICES: Liste oben. Doku: `signing.notaryProfile` und `NOTARY_PROFILE` in der Signier-Anleitung erwähnen.
- **K (`starter.manifest.json`)**: `tools/**`, `scripts/icon.sh`, `scripts/dmg.sh`, `scripts/notarize.sh`, `scripts/tests/test_packaging.py` sind Kit; `App/Resources/AppIcon.icns` ist Projekt (wird bei `init` mit `make icon` neu erzeugt).
- **H**: `ai-worker/package.sh <app>` wie oben; ein eingebettetes Python braucht unter Hardened Runtime vermutlich `com.apple.security.cs.disable-library-validation` in `tools/entitlements.plist`.

## Bekannte Lücken

- **Notarisierung nie echt gelaufen** (keine Developer ID, keine Zugangsdaten). Geprüft: Befehlsaufbau per `--dry-run`, Ablehnungen (ad hoc, Apple-Development-Zertifikat, kein Profil, Identität nicht im Schlüsselbund) und der Abbruch von `make dmg` bei einer nicht vorhandenen Developer ID.
- **Finder selbst nicht angesehen** (Regel: nichts auf dem Bildschirm öffnen). `build/dmg/preview-dark.png` zeigt den Fall weißer Beschriftungen. Geprüft sind `.DS_Store`-Inhalt (Fensterrahmen `{{240, 160}, {640, 432}}`, Icongröße 112, Text 13, Lagen (170, 158)/(470, 158)), versteckte Dateien, Volume-Icon-Flag, und die Vorschau `build/dmg/preview.png`. Offen für den Lead: echtes Fenster (Titelleistenhöhe macOS 26), und ob Finder im Dunkelmodus die Beschriftungen auf dem hellen Hintergrund weiß zeichnet (dann schlecht lesbar; VoiceBud hat dasselbe Risiko).
- **Wie macOS 26 das `.icns` einrahmt** (Tahoe setzt alte Icons teils in einen grauen Rahmen) ist nicht geprüft: `NSWorkspace.icon(forFile:)` aus einem Kommandozeilenwerkzeug lieferte nur das Dokument-Symbol. Lead: im Dock/Finder ansehen. Ein echtes Liquid-Glass-Icon geht nur mit Xcode.
- `ai-worker/package.sh` gibt es noch nicht; der Weg ist nur mit „fehlt“-Meldung geprüft (`MODULES=window,menubar,ai,mlx make dmg`).
- Ein fehlgeschlagener `make dmg` lässt `build/dmg/work.noindex` zum Nachsehen stehen; der nächste Lauf räumt es weg.
- `build_tool` baut ein Werkzeug neu, wenn eine Quelle neuer ist; geänderte Compiler-Flags oder ein anderes SDK merkt es nicht (`rm -rf build/tools` hilft).
- Finder zeigt die App unter ihrem Dateinamen (`app.name`), nicht unter `displayName`: Info.plist hat kein `LSHasLocalizedDisplayName`. Die DMG-Texte richten sich danach. Soll Finder den übersetzten Namen zeigen, gehört das in S0s `gen_config.py`; dann muss `dmg.sh` `--app-label` je Sprache setzen.

## Prüfung (Befehle und Ergebnisse, 2026-10-12)

```
make icon                         -> "icon: App/Resources/AppIcon.icns (violett, sparkles, 1140 KB)"; Werkzeug-Build ~25 s,
                                     danach 0,5 s; zweiter Lauf: gleiche SHA-1 (994ed3d0…)
build/tools/icon selftest         -> "icon selftest: ok" (vorher: "orange: glyph 2.95:1 on the surface", behoben)
build/tools/icon … --symbol nope.nope / --accent lila -> klare Meldung, Exit 1
iconutil -c iconset AppIcon.icns  -> 10 Dateien icon_16x16 … icon_512x512@2x, 16x16 = 16 px
make dmg                          -> "build/dmg/Starter-1.0.0.dmg (3.1M, ULMO, signed ad hoc, Gatekeeper hint shown, texts both)"
                                     erster Lauf legt build/tools-venv an: "installed: dmgbuild==1.6.5 ds-store==1.3.1 mac-alias==2.2.2"
                                     "minos: Info.plist 26.0, newest binary minimum 26.0"
MODULES=menubar make dmg          -> grün (Menüleisten-App, LSUIElement)
MODULES=window,menubar,ai,mlx make dmg -> grün, "mlx is enabled, but ai-worker/package.sh does not exist: the DMG has no MLX worker"
hdiutil attach -readonly -nobrowse -noautoopen -mountpoint <tmp> build/dmg/Starter-1.0.0.dmg
                                  -> .DS_Store, .VolumeIcon.icns, .background.tiff (alle "hidden"), Applications -> /Applications,
                                     Starter.app (Signature=adhoc, Identifier=com.example.starter); Volume-FinderInfo 0x0400
                                     (eigenes Icon); .DS_Store per ds_store gelesen: WindowBounds {{240, 160}, {640, 432}},
                                     iconSize 112, textSize 13, Iloc Starter.app (170, 158), Applications (470, 158);
                                     hdiutil imageinfo: "UDIF read-only compressed (lzma)"; detach ok
SIGN_IDENTITY="Developer ID Application: Nobody (AB12CD34EF)" NO_BUILD=1 scripts/dmg.sh   (heute DMG_NO_BUILD)
                                  -> "no identity found" + "packaging: signing …/Starter.app failed", Exit 1
DMG_LANG=fr scripts/dmg.sh        -> "DMG_LANG must be en, de or both", Exit 1
make notarize                     -> Ablehnung "signing.identity … is "-" (ad hoc) …", Exit 2 (make)
scripts/notarize.sh --dry-run --identity "Developer ID Application: Example GmbH (AB12CD34EF)" --profile starter-notary <app> <dmg>
                                  -> App: codesign --verify, ditto -c -k --sequesterRsrc --keepParent, notarytool submit --wait,
                                     stapler staple, rm zip, spctl --type execute; DMG: codesign --timestamp, submit --wait,
                                     staple, spctl --type open
scripts/notarize.sh … ohne --profile -> Anleitung "xcrun notarytool store-credentials … --team-id …", Exit 1
scripts/notarize.sh --identity "Developer ID Application: Nobody (…)" --profile x -> "is not in the keychain", Exit 1
make build MODULES=menubar / MODULES=window -> grün
make check                        -> Prüfskripte von G/K übersprungen, Build grün, "67 tests, 0 failures", Python "Ran 40 tests … OK"
STARTER_HEADLESS=1 build/Starter.app/Contents/MacOS/Starter --selftest -> "selftest: 8 checks, 0 failures"
make doctor                       -> "ok dmgbuild (build/tools-venv)"
```

Angesehen (Read): `build/icon/preview.png` (hell/dunkel), `build/icon/smallcheck.png` (64/32/16, verkleinert gegen eigene Vorlage, hell/dunkel), `build/icon/dock.png`, eine Übersicht aller sechs Akzente mit typischen Symbolen (rot music.note, blau waveform, gruen leaf.fill, orange sun.max.fill, graphit gearshape.fill, violett sparkles), `build/dmg/preview.png` (zweisprachig mit Hinweis), Varianten de, en (Hintergrund 1x ohne Icons), zweisprachig ohne Hinweis (notarisiert), orange mit eigenem Namen und macOS 26.2. Korrigiert nach dem Ansehen: Symbol zu klein (470 → 520), Kontaktbogen-Spalten überlappten, Hinweisblock saß ohne Hinweisfeld zu tief, deutsche Zeile kürzer („Beim ersten Start“).

## Review (2026-10-12)

12 Befunde aus dem Review, alle geprüft. 11 behoben, 1 nur zum Teil (Finder im Dunkelmodus braucht den Lead). Commits `d88c11b`, `273a028`, `2b2056e`, `057689a`, `2e26a04` und dieser Bericht.

| # | Befund | Ergebnis |
|---|---|---|
| 1 | Zieh-Zeile nennt einen Namen, den Finder nicht zeigt; deutsches Fenster mit englischer Überschrift (major) | **Echt, behoben.** Die Zieh-Zeile nennt jetzt `--app-label` (Dateiname des Bundles, also das, was Finder zeigt). Die Überschrift nimmt bei `--lang de` `displayName.de`. Geprüft mit `--name "Photo Shelf" --name-de Fotoablage --app-label PhotoShelf --lang de`: Überschrift „Fotoablage“, Beschriftung und Zieh-Zeile „PhotoShelf“. |
| 2 | `SIGN_IDENTITY` aus der Umgebung geht vor `notarize.sh` verloren | **Echt, behoben.** `dmg.sh` liest aus `build/gen/app.env` nur noch `APP_NAME` und `MODULES_ENABLED` (in einer Subshell) und gibt `--identity` und `--profile` an `notarize.sh` weiter. Nachgestellt: nach dem Lesen bleibt `SIGN_IDENTITY` die Developer ID, und `notarize.sh --dry-run` plant mit ihr, auch wenn das Kind `SIGN_IDENTITY=-` sieht. |
| 3 | Deutsche DMG-Texte duzen immer, `texts.anrede` wird ignoriert | **Echt, behoben.** `pkg.py` liest `texts.anrede` (du/sie, sonst Fehler), `dmg.sh` gibt `--anrede` weiter, `DMGText.drag` hat „Ziehen Sie … auf …“. Die Hinweiszeilen sind ohne Anrede formuliert. |
| 4 | `make check` baut und testet die Werkzeuge nie | **Echt, behoben.** `ToolBuildTests` baut `icon` und `dmg-background` über `build_tool` (neu nur bei geänderter Quelle) und führt `icon selftest` und ein Rendern des Hintergrunds aus. Kein Überspringen mehr. Der Test entfernt das `SDKROOT`, das der python3-Wrapper der Command Line Tools setzt (sonst eine Beta-SDK, die der Compiler nicht kann). Erster Lauf nach `rm -rf build/tools`: `make check` ~20 s insgesamt. |
| 5 | `make notarize` heftet eine DMG, die noch „Open Anyway“ zeigt; DMG doppelt signiert | **Echt, behoben.** `dmg.sh` schreibt `build/dmg/.<Name>-<Version>.dmg.hint` (`shown`/`none`); `notarize.sh` lehnt eine DMG mit `shown` ab und verweist auf `signing.notarize: true` + `make dmg`. Die DMG wird nur noch einmal signiert (beim Notarisieren macht es `notarize.sh`). App und DMG werden weiterhin beide eingereicht: so trägt auch die nach /Programme kopierte App ein eigenes Ticket (offline prüfbar). |
| 6 | `NO_BUILD=1` verpackt auch einen Debug-Build | **Echt, behoben.** Neue Variable `DMG_NO_BUILD=1`; `NO_BUILD` (von make für Bilder und Tests exportiert) gilt für `make dmg` nicht mehr. Ein Debug-Build wird an seiner Debug-Map erkannt (`nm -ap` findet OSO-Einträge; Debug 61, Release 0) und abgelehnt. `build.sh` (S0) musste dafür nicht geändert werden. |
| 7 | Deutsche Taste heißt auf macOS 26 „Dennoch öffnen“, nicht „Trotzdem öffnen“ (major) | **Echt, behoben.** Selbst nachgelesen: `SecurityPrivacyExtension.appex/…/Localizable.loctable`, Schlüssel `Open Anyway`, de = „Dennoch öffnen“. `DMGText`, `tools/README.md` und dieser Bericht sind korrigiert. |
| 8 | Obere Symbolhälfte nur 1,7 bis 2,6:1, Selbsttest prüft nur das dunkle Ende | **Echt, behoben.** Neue Farbe `ink`: die Akzentfarbe, abgedunkelt bis 3:1 auf der dunkelsten Stelle der Fläche (Orange um 28 %, die anderen um 10 bis 12 %, Graphit unverändert). Ab 128 px: heller Glanzpunkt oben → `ink` → dunkles Ende. 16/32/64 px: nur `ink` → dunkles Ende, kein Glanz. Der Selbsttest prüft `ink` und dunkles Ende oben, in der Mitte und unten auf der Fläche für alle Akzente und dass die kleinen Vorlagen keinen Glanz haben. Bei 16 px wirken die zwei kleinen Sterne trotzdem heller, weil sie nur 1 bis 2 Pixel decken; das liegt an der Abdeckung, nicht mehr an der Farbe. |
| 9 | Deutsches Fenster zeigt den englischen Namen in der Überschrift | **Echt, behoben** zusammen mit 1 (`Options.title`). |
| 10 | Hinweis sagt nicht, dass die Taste erst nach einem blockierten Start erscheint | **Echt, behoben.** „Blocked on first launch?“ / „Beim ersten Start blockiert?“ vor dem Pfad. |
| 11 | Zweisprachige Hinweiskapsel wiegt schwerer als die Zieh-Zeile | **Echt, behoben.** Keine Kapsel mehr (kein Rahmen, keine Fläche). Eine Frage-Zeile mit Schloss (beide Sprachen, „ · “ getrennt), darunter der Pfad je Sprache, 11 pt in `prose` (≈ 5,5:1), zentriert. Die Zieh-Zeile (13 pt halbfett, `fg`) ist wieder das stärkste Element. Der Block ist rund 360 statt 530 pt breit; schmaler als die Zieh-Zeile geht mit dem langen Einstellungspfad nicht, ohne ihn umzubrechen. |
| 12 | Finder-Beschriftungen im Dunkelmodus ungeprüft, Vorschau immer schwarz | **Zum Teil.** `dmg-background` schreibt jetzt auch `preview-dark.png` mit weißen Beschriftungen, `make dmg` kopiert sie nach `build/dmg/` und nennt sie. Sie zeigt, dass weiße Beschriftungen auf dem hellen Hintergrund kaum lesbar wären. Ob Finder sie weiß zeichnet, kann ich nicht prüfen (Finder darf nicht geöffnet werden). Eine Fläche hinter den Beschriftungen habe ich nicht eingebaut: sie wäre nur nötig, wenn Finder weiß zeichnet, und würde schwarze Beschriftungen im hellen Modus verschlechtern. Lead: DMG im Dunkelmodus einhängen und ansehen. |

### Prüfung nach dem Review

```
make check (nach rm -rf build/tools) -> beide Werkzeuge neu gebaut, "67 tests, 0 failures", Python "Ran 45 tests … OK"
build/tools/icon selftest            -> "icon selftest: ok"
make icon (zweimal)                  -> gleiche SHA-1 5c331b62…; violett etwas satter, Sterne bei 16/32 px kräftig
make dmg                             -> "build/dmg/Starter-1.0.0.dmg (3.2M, ULMO, signed ad hoc, Gatekeeper hint shown, texts both)",
                                        preview.png + preview-dark.png
MODULES=menubar make dmg             -> grün
MODULES=window,menubar,ai,mlx make dmg -> grün, "ai-worker/package.sh does not exist"
NO_BUILD=1 make dmg                  -> baut trotzdem Release (NO_BUILD wird ignoriert)
make build; DMG_NO_BUILD=1 scripts/dmg.sh -> "build/Starter.app is a debug build …", Exit 1
DMG_NO_BUILD=1 scripts/dmg.sh (nach Release-Build) -> "packaging the existing build/Starter.app (release, built …)", grün
hdiutil attach -readonly …           -> Applications -> /Applications, .background.tiff hidden, Starter.app adhoc, codesign --verify --strict --deep ok
scripts/notarize.sh --dry-run (ohne Ziel) -> Ablehnung "shows the "Open Anyway" hint … Set signing.notarize to true …", Exit 1
scripts/notarize.sh --dry-run --identity "Developer ID Application: Example GmbH (AB12CD34EF)" --profile starter-notary build/Starter.app
                                     -> codesign --verify, ditto, notarytool submit --wait, staple, rm, spctl
SIGN_IDENTITY/NOTARY_PROFILE-Nachstellung -> Identität bleibt nach dem Lesen von app.env erhalten und kommt in notarize.sh an
SIGN_IDENTITY="Developer ID Application: Nobody (AB12CD34EF)" DMG_NO_BUILD=1 scripts/dmg.sh -> "no identity found", Exit 1
DMG_LANG=fr scripts/dmg.sh           -> "DMG_LANG must be en, de or both", Exit 1
make build MODULES=menubar / window / Standard -> grün
STARTER_HEADLESS=1 build/Starter.app/Contents/MacOS/Starter --selftest -> "selftest: 8 checks, 0 failures"
```

Angesehen (Read): `build/icon/preview.png`, `build/icon/smallcheck.png` (violett), Kleingrößen und Vorschau für Orange und Grün, `build/dmg/preview.png` (zweisprachig, neuer Hinweisblock), Variante deutsch + „Sie“ + abweichende Namen, Variante englisch ohne Hinweis in Orange mit weißen Beschriftungen (`preview-dark.png`).

Für andere Stränge:
- **G**: in `docs/VERTEILUNG.md` und im README-Abschnitt „Betrieb“ heißt die Taste „Dennoch öffnen“ (macOS 26), nicht „Trotzdem öffnen“; die Taste erscheint erst nach einem blockierten Start. `make notarize` nur für DMGs aus `make dmg` mit `signing.notarize: true` beschreiben.
- **S0/G**: `DMG_NO_BUILD` statt `NO_BUILD` für `make dmg`.
