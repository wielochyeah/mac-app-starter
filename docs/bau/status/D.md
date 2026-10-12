# Status D (Onboarding + Berechtigungen, Kit)

Stand: 2026-10-12, Branch `strang/D` (von `main` 68281d5). Gebaut ist alles, was STRANDS.md Strang D zuweist: `Kit/Permissions` (Arten, Status, Prüfen, Anfragen, Systemeinstellungs-Links, Abfrage nur solange sichtbar, Neustart-Helfer) und `Kit/Onboarding` (Fenster, Fluss mit Fortsetzen nach Neustart, Kit-Schritte, Szenen). Alle Seiten bestehen aus den S0b-Mustern.

## Dateien

| Datei | Inhalt |
|---|---|
| `Kit/Permissions/PermissionKind.swift` | `PermissionKind` (alle 14 Namen aus `starter.json` + `automation(bundleId:)`), `id` / `init?(id:)`, `prompt` (Dialog, Schalter, erste Nutzung), `needsRestart`, `canCheck`, Symbol + Tönung, `settingsURL()` |
| `Kit/Permissions/PermissionStatus.swift` | `PermissionStatus` (`missing requested denied granted restartNeeded`), `PermissionRules.effective(…)` und die Abbildung jeder System-Antwort (AVFoundation, AX, IOHID, UserNotifications, AppleEvents, Contacts, EventKit, Photos, CoreLocation, CoreBluetooth, Speech) |
| `Kit/Permissions/SystemPermissions.swift` | `PermissionBackend`-Protokoll, `SystemPermissions` (prüft und fragt bei macOS), `PermissionProbe` (`--permission-probe <id>`: frischer Prozess liest Bildschirmaufnahme) |
| `Kit/Permissions/PermissionMonitor.swift` | `@Observable PermissionMonitor` (`shared`, `status`, `refresh`, `watch`, `request`, `openSettings`, `revealApp`, `sampleLaunchStatus`, `preview(_:)`), `SilentPermissions`, Umgebung `\.permissionMonitor` |
| `Kit/Permissions/AppRelaunch.swift` | Neustart: `sh`-Schleife wartet auf das Ende der PID, dann `open` des Bundles; `arguments(pid:appPath:)` rein und getestet |
| `Kit/Permissions/PermissionText.swift` | Titel, Name in den Systemeinstellungen, Warum-Satz, Hinweiszeilen je Zustand, kurze Statuswörter, beide Sprachen, `du` |
| `Kit/Permissions/PermissionsKit.swift` | `register()` (Start-Stichprobe, 4 Selbsttests), `configured`, `reasons` (Projekttext je Art), `appName(bundleId)` |
| `Kit/Onboarding/OnboardingFlow.swift` | `OnboardingFlow` (Schritte, Index, Richtung mit verzögertem Commit, `go(toStep:)`, Speichern, `prepareRestart`, `leave`, `finish`), `OnboardingAdvance`, `OnboardingResumePoint`, `SettingKey.onboardingResume/.onboardingReopen/.onboardingAllowed`, `startIndex(…)` rein |
| `Kit/Onboarding/OnboardingRootView.swift` | `OnboardingFrame` + Seitenwechsel (26 pt + `Motion.page`, Überblendung bei Bewegung reduzieren) + `OnboardingFooter`; Umgebung `\.onboardingGoTo` |
| `Kit/Onboarding/OnboardingSteps.swift` | `WelcomeStep` + `WelcomeArt` + `AppIconImage`, `LanguageStep`, `FeaturesStep` + `FeatureRow`, `PermissionStep` (+ `slot(for:status:…)`), `DoneStep` + `DoneIcon` |
| `Kit/Onboarding/OnboardingKit.swift` | `OnboardingKit.register()`, `advanceRules`, `StepID`, `Order`, `kitSteps`, `kitRules`, `opensAtLaunch`, `lostPermission`/`reopenIfPermissionLost` (Launch-Hook), `macLanguageOffered`; `OnboardingWindow` (`show`, `makeFlow`, `restart`) |
| `Kit/Onboarding/OnboardingFeatures.swift` | `OnboardingFeature`, `OnboardingFeatures.items` (Register für Module/Projekt, höchstens 3 sichtbar) |
| `Kit/Onboarding/OnboardingScenes.swift` | 14 Szenen `onboarding.*`, 3 Galerie-Einträge, Beispiel-Funktionen |
| `Kit/Onboarding/OnboardingTokens.swift` | Maße/Farben nur der eigenen Schritte (Kandidaten für Kit/Design, siehe unten) |
| `Kit/Onboarding/OnboardingText.swift` | Texte des Fensters und der Kit-Schritte, `OnboardingSampleText` (nur Szenen) |
| `App/Tests/PermissionsTests.swift` | 20 Tests |
| `App/Tests/OnboardingTests.swift` | 26 Tests |

Entfernt: die S0-Stubs `Kit/Permissions/Permission.swift` und `Kit/Onboarding/OnboardingKit.swift` (ersetzt; `PermissionsKit.register()` / `OnboardingKit.register()` heißen weiter so).

## Schritte und Verhalten

| Reihenfolge | id | Inhalt | Weiter |
|---|---|---|---|
| 0 | `welcome` | Bild 672 x 200: ruhiger Grund, Akzent-Glühen, Haarlinien-Ringe, App-Symbol (`AppIcon.icns`, sonst Akzent-Squircle mit `app.symbol`); App-Name 28, darunter `app.tagline` aus `starter.json` (fehlt sie, nur der Name); unten „Die Einrichtung hat N kurze Schritte.“ (echte Zahl) | primär |
| 10 | `language` | Globus, Kopf, Hinweis in der anderen Sprache, Karte: App English/Deutsch (live), Schalter „Wie der Mac“ mit der Sprache des Macs; nur wenn `texts.languages` zwei Sprachen hat | primär |
| 20 | `features` | bis 3 Zeilen aus `OnboardingFeatures`; fehlt, solange niemand etwas einträgt | primär |
| 300 + i | `permission.<id>` | je Eintrag in `starter.json permissions` (prüfbar, ohne Doppelte): Squircle, Warum, 30-pt-Feld, 64-pt-Hinweis | erst primär, wenn erteilt (vorher hält das Feld den einen Primärknopf) |
| 1000 | `done` | App-Symbol mit Haken; „Alles bereit“ nur, wenn jede Freigabe erteilt ist, sonst „Fast fertig“ mit Folge und Rückweg; Zusammenfassung (Sprache, Freigaben bis 3 einzeln, sonst „x von y erteilt“; nicht erteilte Zeilen führen per Klick zurück zu ihrem Schritt; wo die Einstellungen sind: eine Tastenkappe „⌘,“ bei Fenster-Apps, sonst Menüleiste), einzeilige Fußnote | „Fertig“, bzw. „Fertig und neu starten“, wenn eine Freigabe auf den Neustart wartet |

- Start: `AppDelegate` (S0) fragt `OnboardingKit.opensAtLaunch`: offen, solange `onboarding.done` false ist oder `onboarding.reopen` gesetzt ist; nie bei `Launch.isBackground` (`--background` oder Start als Anmeldeobjekt). `AppActions.openOnboarding()` öffnet es jederzeit (Strang E: „Einrichtung erneut zeigen“), dann ab dem ersten Schritt.
- **Fortsetzen (VoiceBud-Fehler behoben, auch beim erneuten Durchlauf):** jeder Schrittwechsel speichert `onboarding.resume` (`{id, order}`). Vor allem, was neu starten kann („<App> neu starten“, Anfrage oder Systemeinstellungen bei Eingabeüberwachung/Bildschirmaufnahme, wo macOS „Beenden & erneut öffnen“ anbietet), setzt `prepareRestart()` zusätzlich `onboarding.reopen`. Der neue Prozess öffnet die Einrichtung genau dort, auch wenn sie aus den Einstellungen erneut gezeigt wurde; der Merker gilt einmal. Fehlt der Schritt inzwischen, geht es beim nächsten mit größerer Ordnung weiter. Schließen über den roten Knopf: Merker weg; ein erneuter Durchlauf vergisst seinen Schritt, ein erster Durchlauf geht beim nächsten Start dort weiter.
- **Verlorene Freigabe:** „Fertig“ merkt sich die erteilten Freigaben (`onboarding.allowed`). Ein Launch-Hook prüft sie nach dem Abschluss; fehlt eine wieder (Ad-hoc-Neubau, widerrufen), öffnet sich die Einrichtung an diesem Schritt (wie VoiceBud). Wer dort „Fertig“ drückt, ohne sie zu erteilen, wird nicht mehr gefragt. Nicht headless, nicht im Hintergrund, nicht mit `--demo`.
- „Fertig“: `onboarding.done = true`, Schritt und Merker vergessen, Freigaben merken, Fenster zu; wartet eine Freigabe auf den Neustart, startet die App neu; beim allerersten Durchlauf einer Fenster-App danach `AppActions.openMainWindow()`. Doppelklick auf „Fertig“ wirkt nur einmal.
- Feldzustände: fehlt → „Freigabe erteilen“ (Return); angefragt → Spinner „Wartet auf deine Antwort“ (Dialog) bzw. „Wartet auf deinen Schalter“ + „Systemeinstellungen öffnen“ (Schalter-Arten); bleibt ein Dialog 5 s unbeantwortet, kommt „Systemeinstellungen öffnen“ dazu; endet ein Dialog ohne Entscheidung (Automation-Ziel nicht geöffnet, Hinweis weggewischt), steht wieder „Freigabe erteilen“ da, ebenso, wenn der Schritt erneut erscheint; abgelehnt → Punkt + „Systemeinstellungen öffnen“; erteilt → Haken; Neustart → Punkt + „<App> neu starten“ (primär). Hinweiszeilen nennen den echten Listennamen der Systemeinstellungen, bei Schalter-Arten mit „[Im Finder zeigen](app://reveal)“, bei abgelehnter Automation den Ziel-Eintrag unter der App.
- Abfrage: `.task { await monitor.watch([kind]) }` auf dem sichtbaren Schritt, einmal pro Sekunde, endet mit dem Schritt (Test: `watchers` geht auf 0, danach keine Abfrage mehr). Kein Timer.

## APIs für andere Stränge und Projekte

```swift
// Berechtigungen (Regel: nur über Kit/Permissions)
PermissionMonitor.shared.status(.microphone)            // PermissionStatus, beobachtbar
await PermissionMonitor.shared.refresh([.microphone])   // jetzt bei macOS nachsehen
PermissionMonitor.shared.request(.accessibility)        // macOS fragt; Status sofort .requested (headless: nie)
PermissionMonitor.shared.openSettings(.inputMonitoring)
.task { await PermissionMonitor.shared.watch([.camera]) } // 1 s, nur solange die View lebt
PermissionsKit.reasons[.microphone] = { tr(en: "…", de: "…") }   // eigener Warum-Satz im Onboarding
PermissionKind(id: "automation:com.apple.mail")         // Automation braucht ein Ziel
AppRelaunch.relaunch(prepare: { … })                    // false in Tests/Renders/Headless

// Start
Launch.isBackground              // --background oder Anmeldeobjekt: kein Fenster (Strang A/B)

// Onboarding
OnboardingFeatures.items.append(OnboardingFeature(id:, order:, symbol:, tint:, title: { … }, detail: { … }))
OnboardingKit.advanceRules["<step id>"] = { monitor in OnboardingAdvance(isPrimary: false, title: MyText.skip) }
OnboardingKit.Order.permissions  // 300; Module liegen dazwischen (400 KI, 500 Insel, 600 Kurzbefehl, 900 Anmeldung)
PermissionStep(kind:)            // ein Modul kann eine eigene Berechtigungsseite zeigen
```

Ein Modul-Schritt bekommt weiter nur `OnboardingContext` (S0); `canContinue = false` sperrt „Weiter“. Wer „Weiter“ leise schalten oder umbenennen will (z. B. Strang F „Überspringen“), setzt `OnboardingKit.advanceRules[id]`.

## Entscheidungen

- **Alle 14 Berechtigungen aus `gen_config.py` sind echt umgesetzt** (prüfen + anfragen), nicht nur die 7 aus STRANDS.md: `starter.json` lässt alle zu, sonst hätte eine gültige Konfiguration einen Schritt ohne Funktion. Die Frameworks (AVFoundation, Contacts, EventKit, Photos, CoreLocation, CoreBluetooth, Speech, UserNotifications) werden über `import` gelinkt. Gemessen mit einem Probe-Programm (`phys_footprint` nach 1,5 s, je zweimal): 7,0 MB ohne, 6,9–7,3 MB nur gelinkt, 7,6 MB mit allen Statusabfragen. Kein Grund für `dlopen`-Umwege.
- **Lokales Netzwerk** hat keine Abfrage-API: kein Onboarding-Schritt (macOS fragt bei der ersten Nutzung), `canCheck == false`.
- **Automation braucht ein Ziel**: `"automation:com.apple.mail"`. Einfaches `"automation"` lehnt `gen_config.py` ab (mit Formathinweis), damit Build und Selbsttest dieselbe Regel haben. Der Schritt heißt nach dem Ziel („Mail steuern“).
- **Kit-Texte versprechen nichts, was das Kit nicht halten kann**: die Warum-Sätze sagen nur, wofür die Freigabe ist (kein „bleibt auf deinem Mac“, „nichts wird hochgeladen“, „läuft nur, während …“). Ein Projekt, das so etwas zusagen kann, schreibt es in `PermissionsKit.reasons[kind]`. Die Willkommenszeile kommt aus `app.tagline` in `starter.json`.
- **Bildschirmaufnahme live erkennen**: ein laufender Prozess behält die Antwort vom Start (VoiceBud). Nach einer Anfrage liest `PermissionProbe` den Status in einem Kindprozess (`<App> --permission-probe screenRecording`, headless, max. 5 s), nur solange der Schritt sichtbar und angefragt ist; nur aus einem `.app`-Bundle.
- **`restartNeeded`** = zur Startzeit nicht erlaubt, jetzt erlaubt (VoiceBuds Regel), nur für Eingabeüberwachung und Bildschirmaufnahme. Die Startwerte nimmt ein Launch-Hook (`sampleLaunchStatus`), billig und ohne Anfrage. Ohne Stichprobe (Tests) nie ein falscher Neustart-Hinweis.
- **Eine Frage nicht überschreiben**: ein abgefragtes `missing` nach eigener Anfrage zeigt `requested` (VoiceBud Gotcha 13).
- **Mitteilungen** nur im `.app`-Bundle (UNUserNotificationCenter wirft sonst); Selbsttest und Tests rufen es nie auf.
- **Completion-Handler sind `@Sendable`**: macOS ruft sie auf eigenen Queues; eine MainActor-Closure dort würde unter Swift 6 abstürzen.
- **Hintergrundstart**: `SMAppService.mainApp` kann keine Argumente übergeben, deshalb liest `Launch.noteLaunchEvent` das Start-Apple-Event (`keyAELaunchedAsLogInItem`); dazu `--background` für Hand- und Skriptstarts. Beides setzt `Launch.isBackground`: `AppDelegate` öffnet dann weder Onboarding noch Hauptfenster. Ob macOS das Event bei `SMAppService.mainApp` wirklich so setzt, ist ungeprüft (Lead).
- **Fenster über `WindowHost.show(style: .onboarding)`** (S0): 720 x 560, transparente Titelleiste, nur Schließen, Aktivierungsrichtlinie über `AppForm`, Views beim Schließen frei. Pro Öffnen ein neuer `OnboardingFlow`.
- **Fußleiste über Regeln statt Preferences**: `OnboardingKit.advanceRules` (Closure je Schritt-id, bekommt den Monitor). Eine PreferenceKey-Lösung hätte in Offscreen-Renders erst nach einem zweiten Durchlauf gegriffen.
- **Renders nutzen den echten `OnboardingRootView`** auf einem Fluss ohne Settings (`settings: nil`, schreibt nichts) mit `PermissionMonitor.preview(…)`.

## Aus VoiceBud übernommen (für THIRD_PARTY_NOTICES, MIT, Copyright (c) 2026 Anas Riad)

- `OnboardingModel`: Schrittliste mit Filter, `advanceIsPrimary`/`advanceTitle`, `go(to:)` mit verzögertem Commit bei Richtungswechsel → `OnboardingFlow`
- `OnboardingController` (Fenster, Abbau beim Schließen) → über `WindowHost` + `OnboardingWindow`
- `OnboardingRootView`-Übergang (26 pt, Feder 0.42/0.86, Reduce Motion) → `OnboardingRootView`
- `OnboardingPermissionStep` (Feldzustände, Hinweiszeilen, Finder-Link) → `PermissionStep` + `PermissionText`
- `OnboardingBridge.apply`-Regel „requested nicht durch missing überschreiben“, `restart = initial != granted && now == granted` → `PermissionRules.effective`
- `onboarding.py` Prüfen/Anfragen (AX, IOHIDCheckAccess/RequestAccess, AVCaptureDevice) und 1-s-Abfrage nur während der Schritt sichtbar ist → `SystemPermissions` + `PermissionMonitor.watch`
- Neustart per `sh`-Schleife auf die PID, dann `open` → `AppRelaunch`
- `--screen-access` (frischer Prozess liest Bildschirmaufnahme) → `PermissionProbe`
- Systemeinstellungs-Links `Privacy_*` → `PermissionKind.settingsURL`
- `OnboardingLanguage` (Hinweis in der anderen Sprache, Sprachen in eigenem Namen) → `LanguageStep`
- `OnboardingFinish` (App-Symbol 72 mit Haken-Abzeichen, Karte mit Zeilen) → `DoneStep`/`DoneIcon`
- `OnboardingAppIcon.load` (vom zeigenden Schritt geladen und freigegeben) → `AppIconImage`

## Außerhalb meines Strangs angefasst

- `App/Sources/Kit/Main/CommandLine.swift` (S0, additiv): Flag `--permission-probe <id>` in `LaunchFlags` (Werkzeug-Flag, `isTool`), in `Launch.run` direkt nach der Fehlerprüfung `exit(PermissionProbe.answer(id))`; Flag `--background`, `Launch.isBackground`, `Launch.noteLaunchEvent(_:)`, `Launch.isLoginItemLaunch(_:)`; Doku-Zeilen im Kopfkommentar.
- `App/Sources/Kit/Main/AppDelegate.swift` (S0, klein): liest zuerst das Start-Event (`Launch.noteLaunchEvent`), öffnet bei `Launch.isBackground` kein Fenster, und fragt `OnboardingKit.opensAtLaunch` statt nur `onboardingDone`.
- `scripts/gen_config.py` (S0, additiv): `permission_base`/`permission_ok`, damit `"automation:<bundle id>"` gültig ist (Usage-Text und Entitlement über den Grundnamen) und einfaches `"automation"` abgelehnt wird; `app.tagline {en, de}` (geprüft, optional) → `AppConfig.tagline`. `scripts/tests/test_gen_config.py`: Tests `test_automation_with_target`, `test_tagline`; `test_entitlements_follow_permissions` nutzt jetzt `automation:com.apple.mail`.
- `starter.json` (S0, additiv): `app.tagline` des Starters. Strang K: `bin/starter init` muss die Zeile für das neue Projekt erfragen oder leeren, sonst zeigt das Projekt den Satz des Starters.
- Stubs `Kit/Permissions/Permission.swift` und `Kit/Onboarding/OnboardingKit.swift` gelöscht (S0 hatte sie Strang D zugewiesen).

## Kandidaten für Kit/Design

- `OnboardingTokens.swift` enthält Größen- und Farbliterale außerhalb von Kit/Design (BAUPLAN §2.8): `Metrics.welcomeIcon 104`, `welcomeIconShadowRadius 16`, `welcomeIconShadowY 8`, `welcomeArtTop 40`, `welcomeRingFirst 76`, `welcomeRingGap 34`, `welcomeRingCount 4`, `doneIcon 72`, `doneBadge 21`, `doneBadgeCut 3`, `doneBadgeInset 4`, `doneBadgeGlyph 10.5`, `featureIcon 32`, `onboardingCard = onboardingNarrow + 60`; `Theme.welcomeGlow` (Deckkraft 0.55/0.42, 0.16/0.12), `welcomeGround` (0.6/0.7), `welcomeRing` (0.28/0.22), `welcomeIconShadow` (hell: Akzent 0.28). Bei der Integration gehören sie nach `Kit/Design/Patterns/PatternTokens.swift`; `onboardingCard` ersetzt dort auch S0bs `Metrics.onboardingNarrow + 60` im Beispiel, damit die Breite nur einmal existiert.
- `AppIconImage` (App-Symbol oder Akzent-Squircle in Icon-Proportion) ist allgemein nützlich (Über-Seite von Strang E, Menüleisten-Panel von B).
- `FeatureRow` (Squircle 32, fett + 12-pt-Text) als Muster für Tipps/Funktionslisten.

## Hinweise für Strang G (Prüfskripte)

- `OnboardingText.languageCrossHint` steht absichtlich in der jeweils anderen Sprache (wie `PatternsSampleText.languageCrossHint`).
- `KeyCaps(["⌘,"])` in `DoneStep`: Tastenzeichen, kein UI-Text.
- `Lang.nativeName` („English“/„Deutsch“) in der Sprachauswahl ist absichtlich nicht übersetzt.
- Die Views in `Kit/Onboarding` und `Kit/Permissions` nutzen nur Tokens, außer `spacing: 0` und dem Icon-Verhältnis `824 / 1024` in `AppIconImage`. Literale stehen aber in `Kit/Onboarding/OnboardingTokens.swift` (Liste oben); `check_design.py` wird sie dort melden, bis sie nach Kit/Design wandern.
- `OnboardingText.welcomeLede` und `AppInfo.displayName` reichen Konfigurationswerte durch `tr(en:de:)` (keine Literale).

## Bekannte Lücken

- Nie interaktiv geprüft (Regel §2.17): echte Systemdialoge, `watch` gegen echte Schalter, Neustart über `AppRelaunch`, „Beenden & erneut öffnen“ bei Bildschirmaufnahme, Fortsetzen nach dem Neustart im echten Fenster. Getestet sind Regeln, Fluss und Persistenz mit Fake-Backend und Settings-Datei. Das prüft der Lead.
- Nie interaktiv geprüft (neu): `keyAELaunchedAsLogInItem` bei `SMAppService.mainApp`, ob `onDisappear` des Onboarding-Fensters beim Beenden der App ausbleibt (sonst würde `leave()` den Reopen-Merker bei macOS' „Beenden & erneut öffnen“ löschen; beim eigenen Neustart schützt `isRelaunching`), das Wiederöffnen bei verlorener Freigabe nach einem Ad-hoc-Neubau.
- Kein Schritt für Lokales Netzwerk (siehe Entscheidungen).
- Automation: ist die Ziel-App nicht geöffnet, kann macOS nicht fragen; der Hinweis sagt das, „Freigabe erteilen“ steht danach wieder da, die App startet das Ziel nicht selbst.
- „Gleiche Sprache wie der Mac“ wird in den Renders immer als angeboten gezeigt (`previewFollowsMac`); den Fall „Sprache des Macs fehlt“ decken nur Tests ab.
- Der Probe-Kindprozess startet pro Sekunde einmal, solange der Bildschirmaufnahme-Schritt sichtbar und angefragt ist.
- Welcome zeigt das Akzent-Squircle, bis Strang J `App/Resources/AppIcon.icns` liefert; danach automatisch das echte Symbol.
- Kein Schritt „Darstellung“/„Kurzbefehl“/„Lokale KI“/„Anmeldung“: liefern C, F, H, B. Kein Querverweis Welcome → Insel (Welle 2).
- ⌘W im Onboarding einer reinen Menüleisten-App (kein Hauptmenü) ist nicht eigens geroutet; der rote Knopf schließt.
- Kein Selbsttest, der meldet, dass ein Projekt noch die Kit-Warum-Sätze oder die Tagline des Starters zeigt (Strang K/G: `init` bzw. Textprüfung).
- `ObservingTests/track calls onChange on every change` (S0) schlug in zwei von etwa zwölf Läufen fehl (50-ms-Wartezeit unter Last); kein Code von D beteiligt.

## Prüfung (2026-10-12)

```
make build                                   -> build/Starter.app (debug, window,menubar,island,background,hotkeys,ai,examples), 0 Warnungen
MODULES=menubar make build                   -> grün; --selftest 14 checks, 0 failures
MODULES=window make build                    -> grün; --selftest 14 checks, 0 failures
MODULES=menubar,island make build            -> grün; --selftest 14 checks, 0 failures
MODULES=window,menubar,island,background,hotkeys,ai,mlx,examples make build -> grün; --selftest 14 checks, 0 failures
CONFIG=release make build                    -> grün
STARTER_HEADLESS=1 …/Starter --selftest      -> "selftest: 14 checks, 0 failures" (neu: permissions.config/.symbols/.links/.texts,
                                                onboarding.steps/.window); kein Prozess bleibt, kein Ordner in Application Support
…/Starter --permission-probe screenRecording -> "granted" (aus dem Terminal gestartet), exit 0; microphone -> exit 2
make test                                    -> "100 tests, 0 failures" (33 neu) + Python "Ran 12 tests … OK"
MODULES=menubar make test                    -> "100 tests, 0 failures"
make shots ONLY=onboarding.                  -> 52 PNGs (13 Szenen × en/de × hell/dunkel)
make shots                                   -> 240 PNGs + index.html
make check                                   -> grün (Prüfskripte von G/K noch nicht da, übersprungen)
```

Angesehen (Read, jede Szene als 2 × 2-Bild en/de × hell/dunkel): `welcome`, `language`, `features`, `done`, `done-restart`, `permission-missing`, `-requested`, `-denied`, `-granted`, `-restart`, `-microphone-waiting`, `-accessibility-waiting`, `-notifications`; dazu `done` de-hell mit `MODULES=menubar` (Einstellungs-Tipp „Klick auf das Symbol in der Menüleiste“). Verglichen mit VoiceBud `onboarding-01-willkommen-light`, `-05b-eingabe-neustart-light`, `-12-fertig-light`. Nach dem Ansehen behoben: Einstellungs-Tipp „⌘,“ als Text mit Komma → Tastenkappen; Neustart-Fußnote nannte „Fertig“, obwohl der Knopf „Fertig und neu starten“ heißt; „Erteilt“-Hinweis auf DE fast 560 pt breit → zweizeilig; Haken im Abzeichen zu dünn → `heavy`.

## Review (2026-10-12)

20 Befunde, davon zwei doppelt gemeldet (1 = 10, 2 = 16, 3 = 13). Alle echt, alle behoben; nichts übersprungen. Teilweise: 4 (Tokens bleiben bis zur Integration in Kit/Onboarding), 11 (kein Selbsttest-Hinweis), 13 (kein Hinweis „noch die Tagline des Starters“), 6 (Anmelde-Event ungeprüft).

| # | Befund | Urteil | Was geändert ist (Commit) |
|---|---|---|---|
| 1, 10 | Fortsetzen nach Neustart nur beim ersten Durchlauf; Hinweis „geht genau hier weiter“ stimmt beim erneuten Durchlauf nicht | echt: `AppDelegate` und `startIndex` sahen nur `onboarding.done` | Merker `onboarding.reopen`, gesetzt von `prepareRestart()` vor „<App> neu starten“ und vor Anfrage/Systemeinstellungen bei Neustart-Arten; `opensAtLaunch` und `startIndex` beachten ihn, einmalig; Schließen per Hand löscht ihn und beim erneuten Durchlauf auch den Schritt. Hinweistext stimmt jetzt (f084d48) |
| 2, 16 | Dialog-Freigaben hängen ohne Entscheidung im Spinner | echt: `asked` wurde nie geleert | Nach Rückkehr der Dialog-Anfrage wird sie vergessen (Stand „fehlt“ → „Freigabe erteilen“), ebenso beim erneuten Zeigen des Schritts; nach 5 s ohne Antwort „Systemeinstellungen öffnen“; Standort/Bluetooth antworten später und bleiben angefragt (6717710) |
| 3, 13 | Willkommen ohne Zweck der App, nur per Kit-Datei änderbar, Datenschutz-Versprechen | echt | `app.tagline {en, de}` in `starter.json` → `AppConfig.tagline` → Willkommenszeile; ohne Tagline nur der Name, kein Versprechen (94d5c67, bd627b7) |
| 4 | Literale außerhalb Kit/Design, D.md behauptete das Gegenteil, Kartenbreite doppelt | echt | D.md listet die Literale; `onboardingCard = onboardingNarrow + 60`; Umzug nach `PatternTokens` bei der Integration (Strang-Regel: Kit/Design nur für Fehlerbehebungen) (c253add) |
| 5 | `request` fragt auch headless/in Tests | echt (über `.shared` erreichbar) | `SystemPermissions.request` verweigert bei `RenderMode.isHeadless`/`isStatic` und loggt; im Monitor nicht, damit Tests mit Fake-Backend weiter laufen (6717710) |
| 6 | `--background`/Anmeldestart fehlt | echt | `--background`, `Launch.isLoginItemLaunch` über das Start-Apple-Event, `Launch.isBackground`; `AppDelegate` öffnet dann kein Fenster (f084d48) |
| 7 | `askPhrase` als rohe Tupel außerhalb `tr()` | echt | `askLine(kind)` mit einem vollen `tr(en:de:)`-Satz je Art (bd627b7) |
| 8 | Einfaches `"automation"` baut, Selbsttest rot | echt | `gen_config.py` lehnt es mit Formathinweis ab, Test ergänzt (94d5c67) |
| 9 | Verlorene Freigabe öffnet die Einrichtung nicht | echt | `onboarding.allowed` bei „Fertig“, Launch-Hook `reopenIfPermissionLost` öffnet am verlorenen Schritt (b638f7e) |
| 11 | Kit-Texte versprechen Datenschutz/Verhalten | echt | Zweite Zeilen mit Versprechen gestrichen (Mikrofon, Kamera, Bildschirm, Kontakte, Fotos, Standort, Automation); Mitteilungen sachlich; Kopfkommentar nennt die Regel (bd627b7) |
| 12 | „Alles bereit“ trotz fehlender Freigaben | echt | „Fast fertig“ + Folge + Rückweg; nicht erteilte Zeilen (und die Sammelzeile) springen per `\.onboardingGoTo` zum Schritt; Neustart-Fußnote „damit die neuen Freigaben wirken“ (bd627b7) |
| 14 | Zwei Automation-Ziele nicht unterscheidbar | echt | Titel „Mail steuern“ / „Control Mail“; Listenname bleibt „Automation“ (bd627b7) |
| 15 | Automation-Hinweis nennt falschen Schalter | echt | „Schalte … unter „Automation“ bei „<App>“ den Eintrag „Mail“ ein.“ (bd627b7) |
| 17 | Graues Schattenfeld ums Symbol (hell) | echt | Heller Modus: Akzent-Schatten 0.28, dunkel unverändert (c253add) |
| 18 | Komma-Tastenkappe als Punkt, dünner Globus | echt | Eine Kappe „⌘,“; `globe.europe.africa.fill` in Zeile und Sprach-Schritt (c253add) |
| 19 | „Dein Mac nutzt Englisch“ auf fremdsprachigen Macs falsch | echt | `macLanguageOffered` (erste Sprache des Macs en/de); sonst „Englisch, weil die Sprache deines Macs fehlt“, Fertig-Zeile ohne „wie der Mac“ (bd627b7) |
| 20 | Viermal „später ändern“, holpriges Deutsch, Fußnote ohne Subjekt | echt | Willkommen: „Die Einrichtung hat N kurze Schritte.“; Sprach-Fußnote mit Subjekt, zweizeilig; Zeilentext = Untertitel; Fertig-Untertitel konkret, Fußnote einzeilig; Beispieltexte schlicht (bd627b7) |

### Prüfung nach dem Review

```
make build (Standardmodule), MODULES=menubar / window / menubar,island / alle inkl. mlx
                                             -> grün, 0 Warnungen; je --selftest "14 checks, 0 failures"
CONFIG=release make build                    -> grün, 0 Warnungen
make test                                    -> "113 tests, 0 failures" + Python "Ran 13 tests … OK"
MODULES=menubar make test                    -> "113 tests, 0 failures" + Python OK
make shots                                   -> 244 PNGs + index.html (onboarding: 14 Szenen × 4 = 56)
make check                                   -> grün (rules_sync/check_texts/check_design/check_kit noch nicht da, übersprungen)
```

Angesehen (Read, 2 × 2 en/de × hell/dunkel): `welcome`, `language`, `features`, `done`, `done-restart`, `permission-restart`, `permission-microphone-waiting`, `permission-automation-denied` (neu), dazu Ausschnitte des Willkommens-Symbols (hell) und der Fertig-Zeilen (de). Dabei behoben: Fertig-Fußnote wurde abgeschnitten, als der Untertitel zweizeilig wurde → einzeilig; englische Sprach-Fußnote brach vor „> General“ → feste Zeilenumbrüche. Kein App-Prozess und kein Ordner in Application Support blieb zurück.
