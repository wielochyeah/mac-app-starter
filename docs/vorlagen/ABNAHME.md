# Abnahmeliste

Vorlage für die Abnahme einer Ausbaustufe. Die Liste entsteht aus dem Ziel in `docs/agents/PLAN.md` und den Festlegungen in `docs/PROJECT.md`; die Integration prüft mit ihr vor dem Merge nach `main` Ansicht für Ansicht. Neue Punkte werden hinten angehängt, Kennungen nie neu vergeben.

Stand: `<TT.MM.JJJJ>`, geprüft auf Commit `<Hash>`

## Gebrauch

- **Priorität:** `MUSS` (vor der Abnahme erfüllt, sonst ausblenden oder ausdrücklich als offen nennen), `SOLL` (angestrebt; Offenes steht unter „Bekannte Schwächen“ der Statusdatei), `KANN` (nur bei Zeit).
- **Prüfung:** `[Gates]` für `make check`; `[Test]` für einen Test mit Namen (`make test ONLY=<Name>`); `[Render]` für eine Szene aus `make shots`, angesehen in en und de, hell und dunkel; `[Klick]` für einen Weg in der laufenden App (`make run`), auf einem Mac mit und einem ohne Notch, wo die Insel betroffen ist; `[Installiert]` für einen Weg mit der App aus dem DMG unter `/Programme` (Berechtigungen, Anmeldeobjekt).
- **Ergebnis:** `ok`, `offen` oder `nicht gebaut`, bei Bedarf mit Commit oder Test. Alles außer `ok` bei `MUSS` geht an den zuständigen Strang.

## 1. Erster Start

| Kennung | Priorität | Kriterium | Prüfung | Strang | Ergebnis |
|---|---|---|---|---|---|
| AK-01 | MUSS | Das Onboarding öffnet beim ersten Start, jeder Schritt passt in beiden Sprachen ohne Abschneiden | `[Render] onboarding.*`, `[Klick]` nach `tccutil reset All <bundleId>` | | |
| AK-02 | MUSS | Jede Berechtigung aus `starter.json` lässt sich erteilen, ablehnen und nach einem Neustart erkennen | `[Installiert]` | | |

## 2. Hauptansichten

| Kennung | Priorität | Kriterium | Prüfung | Strang | Ergebnis |
|---|---|---|---|---|---|
| AK-10 | MUSS | `<Ansicht: in fünf Sekunden klar, was sie zeigt, eine Hauptaktion>` | `<[Render] window.<id>>` | | |

## 3. Menüleiste, Insel, Hintergrund

| Kennung | Priorität | Kriterium | Prüfung | Strang | Ergebnis |
|---|---|---|---|---|---|
| AK-20 | SOLL | `<Zustand der Insel oder des Statusmenüs in einem Satz>` | `<[Render] island.<zustand>>`, `[Klick]` | | |

## 4. Einstellungen

| Kennung | Priorität | Kriterium | Prüfung | Strang | Ergebnis |
|---|---|---|---|---|---|
| AK-30 | MUSS | Jede Einstellung wirkt sofort und übersteht einen Neustart | `[Test]`, `[Klick]` | | |
| AK-31 | MUSS | Sprache wechselt live zwischen Englisch und Deutsch, ohne Neustart | `[Klick]` | | |

## 5. Gestaltung und Sprache

| Kennung | Priorität | Kriterium | Prüfung | Strang | Ergebnis |
|---|---|---|---|---|---|
| AK-50 | MUSS | Jede Szene in en und de, hell und dunkel angesehen, keine abgeschnittenen Texte | `[Render]` | | |
| AK-51 | MUSS | Texte ohne verbotene Wörter und Zeichen, beide Sprachen vollständig | `[Gates]` | | |
| AK-52 | MUSS | Reduzierte Bewegung schaltet Federn auf Überblendung | `[Klick]` mit eingeschalteter Einstellung | | |

## 6. Verteilung

| Kennung | Priorität | Kriterium | Prüfung | Strang | Ergebnis |
|---|---|---|---|---|---|
| AK-60 | MUSS | `make dmg` erzeugt ein DMG mit gestaltetem Fenster, die App startet nach „Trotzdem öffnen“ auf einem zweiten Mac oder Benutzer | `[Installiert]` | | |
| AK-61 | SOLL | Mit Developer ID: `codesign --verify --deep --strict`, `spctl -a -vv` und `xcrun stapler validate` bestehen | `[Installiert]` | | |

## 7. Offene Punkte aus der Abnahme

| Kennung | was fehlt | Folge | zuständig | bis |
|---|---|---|---|---|
