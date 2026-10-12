# Hinweise zu Fremdcode

Diese Datei nennt Code und Vorlagen, die der Starter von anderen übernommen hat, mit ihren Lizenzen. Sie gehört zum Kit und reist in jedes Projekt mit; die App zeigt sie im Bereich „Über“, wenn sie im Bundle liegt. Wer weiteren Fremdcode übernimmt, ergänzt hier einen Abschnitt mit Quelle, Umfang und vollständigem Lizenztext.

## VoiceBud

Quelle: VoiceBud, eine Diktier-App für macOS von Anas Riad. Lizenz: MIT.

Übernommen und für den Starter verallgemeinert (ohne Diktat, Texterkennung und andere Besonderheiten von VoiceBud):

- Gestaltung: Farbwerte und Rollen des Hubs und des Onboardings (`Theme`), Karten, Zeilen, Gruppentitel, Fußnoten, Schalter, Segmente, Chips, Tastenkappen, Squircle-Symbole, Kopfband eines Bereichs, Knopfstile, Fortschritt, Spinner, Statusmarken, statische Fensterrahmen für Renders, Federwerte (`Motion`), Insel-Palette und Maße der Insel (`App/Sources/Kit/Design/`).
- Muster für Onboarding und Einstellungen: zentrierte Seite, Kopf, Fußnote, Status-Slot und Hinweisbereich der Berechtigungsschritte, Fußleiste, Kachelauswahl, Text mit Links, Hinweisfeld, Download-Zeile mit Fortschritt, Gerüst eines Einstellungsbereichs, Wertkapsel, Suchfeld, Zähler, Listen mit Hover (`App/Sources/Kit/Design/Patterns/`).
- Laufzeit: Sprachwechsel ohne Neustart über ein beobachtbares Objekt (`Localizer`, `tr`), Speichern der Einstellungen mit Erhalt unbekannter Schlüssel (`Settings`), Fenster ohne Bildschirm für Renders (`HeadlessWindows`), Aktivierungsrichtlinie zwischen Accessory und Regular (`AppForm`).
- Werkzeuge: Bauweise mit einem `swiftc`-Aufruf, Bau in einen temporären Ordner und Verschieben an den Zielort (`scripts/build.sh`).
- Was die Module übernehmen (Insel und Kapsel, Onboarding-Fenster, Einstellungsfenster, Kurzbefehle und ihre Regeln, Menüleistensymbol, Anmeldeobjekt, lokale KI mit MLX-Worker, programmatisches App-Symbol, gestaltetes DMG), steht im Statusbericht des jeweiligen Bereichs und wird bei der Zusammenführung hier ergänzt.

Lizenztext:

```
MIT License

Copyright (c) 2026 Anas Riad

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## SF Symbols und Systemschrift

Die App nutzt SF Symbols und die Systemschrift von macOS über die öffentlichen Schnittstellen von AppKit und SwiftUI; beide liefert macOS, der Starter enthält keine Kopie. Sie stehen unter den Lizenzbedingungen von Apple für die Entwicklerwerkzeuge und das SDK und dürfen in Apps für Apple-Plattformen als Bedienelemente erscheinen.

Apple untersagt SF Symbols und ihnen zum Verwechseln ähnliche Zeichen in App-Symbolen, Logos und anderen markenbezogenen Verwendungen. Das Symbol, das `make icon` aus `app.symbol` in `starter.json` erzeugt, ist deshalb nur für die Entwicklung gedacht: Vor einer Weitergabe außerhalb des eigenen Macs bekommt das Projekt ein eigenes Motiv für App-Symbol und DMG (`docs/VERTEILUNG.md`, Abschnitt „Vor der ersten Weitergabe“). Symbole mit Info-Markierung in der App SF Symbols stehen für Apple-Produkte und dürfen nur für diese stehen.

## Python-Pakete für Werkzeuge

Die Werkzeuge in `scripts/` nutzen nur die Standardbibliothek von Python. Optional richten Skripte eigene Umgebungen unter `build/` oder `ai-worker/.venv` ein (dmgbuild für das DMG, mlx-lm für das Modul `mlx`); diese Pakete liegen nicht im Repository und bringen ihre Lizenzen in der jeweiligen Umgebung mit. Ein Projekt, das sie mit der App ausliefert, nennt sie hier.
