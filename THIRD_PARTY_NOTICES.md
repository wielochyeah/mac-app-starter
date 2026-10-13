# Hinweise zu Fremdcode

Diese Datei nennt Code und Vorlagen, die der Starter von anderen übernommen hat, mit Quelle, Umfang und Lizenz. Sie gehört zum Kit und reist in jedes Projekt mit; sie ist für Entwickler. Die App zeigt nicht diese Datei, sondern die kurze Fassung für ihre Nutzerinnen aus `App/Resources/Notices/<lang>.md` (Einstellungen, Bereich „Über“, Zeile „Hinweise zu Drittanbietern“); `make build` legt sie ins Bundle, und ein Test prüft, dass jeder Lizenztext dieser Datei dort wörtlich steht. Wer weiteren Fremdcode übernimmt, ergänzt hier einen Abschnitt mit Quelle, Umfang und vollständigem Lizenztext und denselben Lizenztext in beiden Dateien unter `App/Resources/Notices/`.

## VoiceBud

Quelle: VoiceBud, eine Diktier-App für macOS von Anas Riad. Lizenz: MIT.

Übernommen und für den Starter verallgemeinert (ohne Diktat, Texterkennung und andere Besonderheiten von VoiceBud):

- Gestaltung: Farbwerte und Rollen des Hubs und der Einrichtung (`Theme`), Karten, Zeilen, Gruppentitel, Fußnoten, Schalter, Segmente, Chips, Tastenkappen, Squircle-Symbole, Kopfband eines Bereichs, Tastenstile, Fortschritt, Spinner, Statusmarken, statische Fensterrahmen für Renders, Federwerte (`Motion`), Insel-Palette und Maße der Insel (`App/Sources/Kit/Design/`).
- Muster für Einrichtung und Einstellungen: zentrierte Seite, Kopf, Fußnote, Status-Slot und Hinweisbereich der Berechtigungsschritte, Fußleiste, Kachelauswahl, Text mit Links, Hinweisfeld, Download-Zeile mit Fortschritt, Gerüst eines Einstellungsbereichs, Wertkapsel, Suchfeld, Zähler, Listen mit Hover (`App/Sources/Kit/Design/Patterns/`).
- Laufzeit: Sprachwechsel ohne Neustart über ein beobachtbares Objekt (`Localizer`, `tr`), Speichern der Einstellungen mit Erhalt unbekannter Schlüssel (`Settings`), Fenster ohne Bildschirm für Renders (`HeadlessWindows`), Aktivierungsrichtlinie zwischen Accessory und Regular (`AppForm`).
- Werkzeuge: Bauweise mit einem `swiftc`-Aufruf, Bau in einen temporären Ordner und Verschieben an den Zielort (`scripts/build.sh`).
- Einrichtung und Berechtigungen (`App/Sources/Kit/Onboarding/`, `App/Sources/Kit/Permissions/`): Schrittfolge mit Filter und verzögertem Richtungswechsel (`OnboardingFlow`), Seitenübergang, Berechtigungsschritt mit Statusfeld, Hinweiszeilen und Finder-Link, die Regel, dass „angefragt“ nicht von „fehlt“ überschrieben wird, Prüfen und Anfragen der Berechtigungen mit Abfrage nur bei sichtbarem Schritt, Neustart der App, Abfrage der Bildschirmaufnahme in einem frischen Prozess, Links in die Systemeinstellungen, Sprachschritt mit Hinweis in der anderen Sprache, Abschluss mit App-Symbol und Haken.
- Einstellungsfenster (`App/Sources/Kit/Settings/`): Fenstersteuerung mit Tastenweg ⌘W, ⌘F und Bearbeiten, Rückgabe des Fokus an die vorherige App, Freigabe des Speichers nach dem Schließen, `NavigationSplitView` mit Spaltenbreiten, Seitenleiste mit 34-pt-Einträgen, Auswahl mit Feder, ↑/↓ und Fußzeile „Alles lokal und offline“, statische Fensterdarstellung für Renders, „Kopiert“ mit 1,4 s Haltezeit.
- Fenster-Modul (`App/Sources/Modules/Window/`): statisches Fenster mit schwebender Seitenleiste für Renders, Fußzeile der Seitenleiste, Auswahlring der Kacheln.
- Menüleiste und Hintergrund (`App/Sources/Modules/MenuBar/`, `App/Sources/Modules/Background/`): gezeichnetes Template-Symbol mit Punkt, `alignmentRect`, Erscheinungsbild per KVO und Timer nur bei Bedarf, Menütitel bei jedem Öffnen neu, Speicherfreigabe nach dem Schließen, Verhalten des Anmeldeobjekts (nur die installierte App, Änderung nur bei Unterschied).
- Insel und Kapsel (`App/Sources/Modules/Island/`): Messung von Notch und Menüleiste, Panel- und Fensterrezept, Formen von Notch und Kapsel samt Morph, Federn und Übergänge, Ablauf von Erscheinen, Ausblenden und Zeigerabfrage, Selbstheilung bei Bildschirmwechseln, Textkörper der Ergebniskarte mit Vorschau und Aufklappen, Abzeichen, Ring, Zeitanzeige, Taste „Kopieren“, Pegelanzeige, Bühne und Kacheln des Bereichs „Insel“, Demo-Ablauf.
- Tastaturkurzbefehle (`App/Sources/Modules/Hotkeys/`): `HotkeyCenter` mit Carbon-Registrierung, Regeln für Tastenkombinationen mit ihren Begründungen und dem Vorschlag, Tabelle der Kombinationen, die macOS und gängige Apps belegen, Tastaturbelegung, Aufnahme-Zeile, große Tastenkappen in der Einrichtung, die Testfälle der Regeln.
- Lokale KI (`App/Sources/Modules/AI/`, `App/Sources/Modules/MLX/`, `ai-worker/`): Protokoll und Aufbau des MLX-Workers (geschützte Standardausgabe, Warteschlange mit Priorität, Wächter, Speichergrenzen, Präfix-Cache), Download in einem Kindprozess mit Gesamtgröße und Fortschritt, Fristen und Neustarts des Clients, Test-Worker, Aufbau der Modellzeilen in der Einrichtung.
- App-Symbol und DMG (`tools/icon/`, `tools/dmg/`, `scripts/icon.sh`, `scripts/dmg.sh`, `tools/packaging/`): Raster und Ebenen des Symbols mit eigenen kleinen Vorlagen, Hintergrund des DMG-Fensters mit gepunktetem Pfeil, Zieh-Zeile und Hinweis, Fenster- und Icon-Lagen für dmgbuild, Ablauf von Verbergen, Komprimieren und Prüfen der Mindestversion.

Nicht übernommen: Diktat und Texterkennung, Live-Text der Insel, Erkennung fremder Notch-Apps, IPC und andere Teile, die nur VoiceBud braucht.

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
