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
| `Kit/Onboarding/OnboardingFlow.swift` | `OnboardingFlow` (Schritte, Index, Richtung mit verzögertem Commit, Speichern, `finish`), `OnboardingAdvance`, `OnboardingResumePoint` + `SettingKey.onboardingResume`, `startIndex(…)` rein |
| `Kit/Onboarding/OnboardingRootView.swift` | `OnboardingFrame` + Seitenwechsel (26 pt + `Motion.page`, Überblendung bei Bewegung reduzieren) + `OnboardingFooter` |
| `Kit/Onboarding/OnboardingSteps.swift` | `WelcomeStep` + `WelcomeArt` + `AppIconImage`, `LanguageStep`, `FeaturesStep` + `FeatureRow`, `PermissionStep` (+ `slot(for:status:…)`), `DoneStep` + `DoneIcon` |
| `Kit/Onboarding/OnboardingKit.swift` | `OnboardingKit.register()`, `advanceRules`, `StepID`, `Order`, `kitSteps`, `kitRules`; `OnboardingWindow` (`show`, `makeFlow`, `restart`) |
| `Kit/Onboarding/OnboardingFeatures.swift` | `OnboardingFeature`, `OnboardingFeatures.items` (Register für Module/Projekt, höchstens 3 sichtbar) |
| `Kit/Onboarding/OnboardingScenes.swift` | 13 Szenen `onboarding.*`, 3 Galerie-Einträge, Beispiel-Funktionen |
| `Kit/Onboarding/OnboardingTokens.swift` | Maße/Farben nur der eigenen Schritte (Kandidaten für Kit/Design, siehe unten) |
| `Kit/Onboarding/OnboardingText.swift` | Texte des Fensters und der Kit-Schritte, `OnboardingSampleText` (nur Szenen) |
| `App/Tests/PermissionsTests.swift` | 18 Tests |
| `App/Tests/OnboardingTests.swift` | 15 Tests |

Entfernt: die S0-Stubs `Kit/Permissions/Permission.swift` und `Kit/Onboarding/OnboardingKit.swift` (ersetzt; `PermissionsKit.register()` / `OnboardingKit.register()` heißen weiter so).

## Schritte und Verhalten

| Reihenfolge | id | Inhalt | Weiter |
|---|---|---|---|
| 0 | `welcome` | Bild 672 x 200: ruhiger Grund, Akzent-Glühen, Haarlinien-Ringe, App-Symbol (`AppIcon.icns`, sonst Akzent-Squircle mit `app.symbol`); App-Name 28, ein Satz 15; unten „N Schritte …“ (echte Zahl) | primär |
| 10 | `language` | Globus, Kopf, Hinweis in der anderen Sprache, Karte: App English/Deutsch (live), Schalter „Wie der Mac“ mit der Sprache des Macs; nur wenn `texts.languages` zwei Sprachen hat | primär |
| 20 | `features` | bis 3 Zeilen aus `OnboardingFeatures`; fehlt, solange niemand etwas einträgt | primär |
| 300 + i | `permission.<id>` | je Eintrag in `starter.json permissions` (prüfbar, ohne Doppelte): Squircle, Warum, 30-pt-Feld, 64-pt-Hinweis | erst primär, wenn erteilt (vorher hält das Feld den einen Primärknopf) |
| 1000 | `done` | App-Symbol mit Haken, Zusammenfassung (Sprache, Freigaben bis 3 einzeln, sonst „x von y erteilt“, wo die Einstellungen sind: ⌘, als Tastenkappen bei Fenster-Apps, sonst Menüleiste), Fußnote | „Fertig“, bzw. „Fertig und neu starten“, wenn eine Freigabe auf den Neustart wartet |

- Erster Start: `AppDelegate` (S0) öffnet das Onboarding, solange `onboarding.done` false ist. `AppActions.openOnboarding()` öffnet es jederzeit (Strang E: „Einrichtung erneut zeigen“), dann ab dem ersten Schritt.
- **Fortsetzen (VoiceBud-Fehler behoben):** jeder Schrittwechsel speichert `onboarding.resume` (`{id, order}`), `OnboardingWindow.restart()` speichert vor dem Neustart noch einmal. Ein neuer Prozess öffnet das Onboarding (nicht fertig) genau dort; fehlt der Schritt inzwischen, beim nächsten mit größerer Ordnung. Das gilt auch für macOS' eigenes „Beenden & erneut öffnen“ bei Bildschirmaufnahme. Schließen über den roten Knopf ohne „Fertig“ heißt: beim nächsten Start geht es am selben Schritt weiter.
- „Fertig“: `onboarding.done = true`, Schritt vergessen, Fenster zu; wartet eine Freigabe auf den Neustart, startet die App neu; beim allerersten Durchlauf einer Fenster-App danach `AppActions.openMainWindow()`. Doppelklick auf „Fertig“ wirkt nur einmal.
- Feldzustände: fehlt → „Freigabe erteilen“ (Return); angefragt → Spinner „Wartet auf deine Antwort“ (Dialog) bzw. „Wartet auf deinen Schalter“ + „Systemeinstellungen öffnen“ (Schalter-Arten); abgelehnt → Punkt + „Systemeinstellungen öffnen“; erteilt → Haken; Neustart → Punkt + „<App> neu starten“ (primär). Hinweiszeilen nennen den echten Listennamen der Systemeinstellungen, bei Schalter-Arten mit „[Im Finder zeigen](app://reveal)“.
- Abfrage: `.task { await monitor.watch([kind]) }` auf dem sichtbaren Schritt, einmal pro Sekunde, endet mit dem Schritt (Test: `watchers` geht auf 0, danach keine Abfrage mehr). Kein Timer.

## APIs für andere Stränge und Projekte

```swift
// Berechtigungen (Regel: nur über Kit/Permissions)
PermissionMonitor.shared.status(.microphone)            // PermissionStatus, beobachtbar
await PermissionMonitor.shared.refresh([.microphone])   // jetzt bei macOS nachsehen
PermissionMonitor.shared.request(.accessibility)        // macOS fragt; Status sofort .requested
PermissionMonitor.shared.openSettings(.inputMonitoring)
.task { await PermissionMonitor.shared.watch([.camera]) } // 1 s, nur solange die View lebt
PermissionsKit.reasons[.microphone] = { tr(en: "…", de: "…") }   // eigener Warum-Satz im Onboarding
PermissionKind(id: "automation:com.apple.mail")         // Automation braucht ein Ziel
AppRelaunch.relaunch(prepare: { … })                    // false in Tests/Renders/Headless

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
- **Automation braucht ein Ziel**: `"automation:com.apple.mail"`. Einfaches `"automation"` akzeptiert `gen_config.py` weiter (S0-Verhalten), der Selbsttest `permissions.config` meldet es aber, und das Onboarding zeigt dafür keinen Schritt.
- **Bildschirmaufnahme live erkennen**: ein laufender Prozess behält die Antwort vom Start (VoiceBud). Nach einer Anfrage liest `PermissionProbe` den Status in einem Kindprozess (`<App> --permission-probe screenRecording`, headless, max. 5 s), nur solange der Schritt sichtbar und angefragt ist; nur aus einem `.app`-Bundle.
- **`restartNeeded`** = zur Startzeit nicht erlaubt, jetzt erlaubt (VoiceBuds Regel), nur für Eingabeüberwachung und Bildschirmaufnahme. Die Startwerte nimmt ein Launch-Hook (`sampleLaunchStatus`), billig und ohne Anfrage. Ohne Stichprobe (Tests) nie ein falscher Neustart-Hinweis.
- **Eine Frage nicht überschreiben**: ein abgefragtes `missing` nach eigener Anfrage zeigt `requested` (VoiceBud Gotcha 13).
- **Mitteilungen** nur im `.app`-Bundle (UNUserNotificationCenter wirft sonst); Selbsttest und Tests rufen es nie auf.
- **Completion-Handler sind `@Sendable`**: macOS ruft sie auf eigenen Queues; eine MainActor-Closure dort würde unter Swift 6 abstürzen.
- **Kein `--background`-Flag**: `SMAppService.mainApp` kann keine Argumente übergeben. Das Anmeldeobjekt wird erst in einem Onboarding-Schritt (900) eingeschaltet, also ist das Onboarding dann meist fertig; ist es das nicht, ist das Zeigen beim Anmelden gewollt (wie VoiceBud).
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

- `App/Sources/Kit/Main/CommandLine.swift` (S0, additiv): Flag `--permission-probe <id>` in `LaunchFlags` (Werkzeug-Flag, `isTool`), in `Launch.run` direkt nach der Fehlerprüfung `exit(PermissionProbe.answer(id))`, Doku-Zeile im Kopfkommentar.
- `scripts/gen_config.py` (S0, additiv): `permission_base`/`permission_ok`, damit `"automation:<bundle id>"` gültig ist (Usage-Text und Entitlement über den Grundnamen); Fehlermeldung nennt das Format. `scripts/tests/test_gen_config.py`: Test `test_automation_with_target`.
- Stubs `Kit/Permissions/Permission.swift` und `Kit/Onboarding/OnboardingKit.swift` gelöscht (S0 hatte sie Strang D zugewiesen).

## Kandidaten für Kit/Design

- `OnboardingTokens.swift`: `Metrics.welcomeIcon/…Ring…/doneIcon/doneBadge…/featureIcon/onboardingCard (460)`, `Theme.welcomeGlow/welcomeGround/welcomeRing/welcomeIconShadow`. `onboardingCard` (VoiceBuds „narrow + 60“) nutzt S0b schon als `Metrics.onboardingNarrow + 60` in einem Beispiel: als Token in Kit gehört es eigentlich zu `PatternTokens`.
- `AppIconImage` (App-Symbol oder Akzent-Squircle in Icon-Proportion) ist allgemein nützlich (Über-Seite von Strang E, Menüleisten-Panel von B).
- `FeatureRow` (Squircle 32, fett + 12-pt-Text) als Muster für Tipps/Funktionslisten.

## Hinweise für Strang G (Prüfskripte)

- `OnboardingText.languageCrossHint` steht absichtlich in der jeweils anderen Sprache (wie `PatternsSampleText.languageCrossHint`).
- `KeyCaps(["⌘", ","])` in `DoneStep`: Tastenzeichen, kein UI-Text.
- `Lang.nativeName` („English“/„Deutsch“) in der Sprachauswahl ist absichtlich nicht übersetzt.
- Keine Farb-, Größen-, Abstands- oder Feder-Literale in `Kit/Onboarding` und `Kit/Permissions` außer `spacing: 0` und dem Icon-Verhältnis `824 / 1024` in `AppIconImage`.

## Bekannte Lücken

- Nie interaktiv geprüft (Regel §2.17): echte Systemdialoge, `watch` gegen echte Schalter, Neustart über `AppRelaunch`, „Beenden & erneut öffnen“ bei Bildschirmaufnahme, Fortsetzen nach dem Neustart im echten Fenster. Getestet sind Regeln, Fluss und Persistenz mit Fake-Backend und Settings-Datei. Das prüft der Lead.
- Ad-hoc-signierte Builds verlieren TCC-Freigaben bei jedem Neubau (neue Signatur); das Onboarding zeigt dann wieder „fehlt“, öffnet sich aber nach „Fertig“ nicht von selbst neu. VoiceBud öffnet die Einrichtung erneut, wenn eine Freigabe verloren ging; das ist hier nicht gebaut (Kandidat für Welle 2, z. B. Launch-Hook mit `refresh` + Hinweis).
- Kein Schritt für Lokales Netzwerk und für `"automation"` ohne Ziel (siehe Entscheidungen).
- Automation: ist die Ziel-App nicht geöffnet, kann macOS nicht fragen; der Hinweis sagt das, die App startet das Ziel nicht selbst.
- Der Probe-Kindprozess startet pro Sekunde einmal, solange der Bildschirmaufnahme-Schritt sichtbar und angefragt ist.
- Welcome zeigt das Akzent-Squircle, bis Strang J `App/Resources/AppIcon.icns` liefert; danach automatisch das echte Symbol.
- Kein Schritt „Darstellung“/„Kurzbefehl“/„Lokale KI“/„Anmeldung“: liefern C, F, H, B. Kein Querverweis Welcome → Insel (Welle 2).
- ⌘W im Onboarding einer reinen Menüleisten-App (kein Hauptmenü) ist nicht eigens geroutet; der rote Knopf schließt.

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
