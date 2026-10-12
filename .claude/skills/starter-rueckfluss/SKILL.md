---
name: starter-rueckfluss
description: Macht aus Einträgen in docs/STARTER_FEEDBACK.md eines Projekts einen Pull Request im Starter mac-app-starter, mit Test, Render-Szene und Galerie-Eintrag. Nutzen, wenn ein Projekt eine Änderung an Kit-Pfaden braucht.
---

# Rückfluss in den Starter

Kit-Pfade (`starter.manifest.json`, Gruppe `kit`) ändert ein Projekt nicht. Der Bedarf steht in `docs/STARTER_FEEDBACK.md` mit Datei, Grund und Test; dieser Skill bringt ihn in den Starter.

## Verträge und Dateien

| Datei | Rolle |
|---|---|
| `docs/STARTER_FEEDBACK.md` (Projekt) | Tabelle mit Nr., Datei im Starter, Bedarf, Grund, Test, Stand |
| `starter.manifest.json` | welche Pfade Kit, gemeinsam oder Projekt sind, und der Name des Starter-Repositorys |
| `starter.lock.json` | Version und Commit des Starters im Projekt |
| `rules/` im Starter | Regeln, falls der Bedarf eine Regel ist (Ablauf in `rules/README.md`) |

## Ablauf

1. Offene Einträge lesen. Namen, Fachbegriffe und Daten des Projekts gehören nicht in den Starter; der Eintrag wird allgemein formuliert.
2. Das Starter-Repository aus `starter.manifest.json` holen und dort einen Branch `claude/rueckfluss-<thema>` von `main` anlegen.
3. Änderung im Starter bauen, mit dem Test aus der Spalte „Test“ (Erwartung aus der Anforderung). Sichtbare Bausteine bekommen eine Render-Szene und einen Eintrag in der Galerie; neue Tokens einen Kontrasttest.
4. Im Starter `make check`, `make shots` mit angesehenen Bildern (en und de, hell und dunkel) und die Build-Matrix der berührten Module, dann Pull Request mit Verweis auf den Eintrag, ohne Namen oder Inhalte des Projekts.
5. Im Projekt den Stand des Eintrags auf `PR <nummer> im Starter` setzen. Nach dem Release holt `bin/starter sync --ziel <tag>` die Änderung zurück; dann Stand auf `übernommen in <tag>`.
