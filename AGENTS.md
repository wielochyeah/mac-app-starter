# AGENTS.md

Alle verbindlichen Regeln für Agenten stehen in `CLAUDE.md`. Teil A entsteht aus `rules/`, Teil B verweist auf `docs/PROJECT.md`. Neue Vorgaben stehen in `docs/agents/VORGABEN.md` und gehen allem vor.

Das Wichtigste für jeden Agenten, der hier ohne Claude Code arbeitet:

- Native macOS-App in Swift 6 (SwiftUI und AppKit), mindestens macOS 26, gebaut ohne Xcode: `make build` ruft einmal `swiftc` auf. Kein `#Preview`, kein `@Entry`, kein SwiftData, kein XCTest (T-01).
- Die App wird beim Bauen und Prüfen nie normal gestartet, fragt nie nach Berechtigungen und lässt keinen Prozess laufen. Ansehen über `make shots` (Renders nach `build/shots/`), prüfen über `--selftest` mit `STARTER_HEADLESS=1` (T-08).
- Jeder UI-Text steht zweisprachig als `tr(en:de:)` in einer `*Text.swift`-Datei, Farben, Abstände und Schrift kommen aus `App/Sources/Kit/Design` (S-10, D-01).
- Vor jedem Push ist `make check` grün; Commit-Nachrichten lauten `type(scope): subject` auf Englisch, mit der Identität aus `starter.json` (A-02, A-03, A-04).
