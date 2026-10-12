# Features

Hier landen die Funktionen des Projekts (eine Datei oder ein Ordner pro Feature). Sie hängen sich wie die Module über `Registry` in die App ein (Seiten, Einstellungsbereiche, Onboarding-Schritte, Menüeinträge, Render-Szenen) und nutzen Kit-Bausteine und Design-Tokens, Module nur in eigenen Blöcken `#if MODUL_<NAME>` … `#endif`.

Angemeldet wird jedes Feature mit einer Zeile in `Features.register()` (`Features.swift` in diesem Ordner); `Modules.registerAll()` ruft das nach dem Kit und allen Modulen auf. Tests eines Features liegen in `App/Tests/Features/`.
