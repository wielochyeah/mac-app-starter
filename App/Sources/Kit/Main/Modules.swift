// The ONLY place that lists modules. One plain `#if MODUL_<NAME>` block per module, one flag each
// (never combined with || or &&): `bin/starter remove <module>` strips these blocks.

enum Modules {
    private static var registered = false

    /// Calls every module's `register()` once (kit first, then modules in starter.json order), then the project's
    /// `Features.register()` (App/Sources/Features/Features.swift).
    static func registerAll() {
        guard !registered else { return }
        registered = true
        KitModule.register()
        #if MODUL_WINDOW
        WindowModule.register()
        #endif
        #if MODUL_MENUBAR
        MenuBarModule.register()
        #endif
        #if MODUL_ISLAND
        IslandModule.register()
        #endif
        #if MODUL_BACKGROUND
        BackgroundModule.register()
        #endif
        #if MODUL_HOTKEYS
        HotkeysModule.register()
        #endif
        #if MODUL_AI
        AIModule.register()
        #endif
        #if MODUL_MLX
        MLXModule.register()
        #endif
        #if MODUL_EXAMPLES
        ExamplesModule.register()
        #endif
        Features.register()
    }

    /// The modules compiled into this binary (from the `-D MODUL_*` flags).
    static var compiled: Set<String> {
        var out: Set<String> = []
        #if MODUL_WINDOW
        out.insert("window")
        #endif
        #if MODUL_MENUBAR
        out.insert("menubar")
        #endif
        #if MODUL_ISLAND
        out.insert("island")
        #endif
        #if MODUL_BACKGROUND
        out.insert("background")
        #endif
        #if MODUL_HOTKEYS
        out.insert("hotkeys")
        #endif
        #if MODUL_AI
        out.insert("ai")
        #endif
        #if MODUL_MLX
        out.insert("mlx")
        #endif
        #if MODUL_EXAMPLES
        out.insert("examples")
        #endif
        return out
    }
}

/// The kit areas (never removed). Each area owns its `register()`.
enum KitModule {
    static func register() {
        DesignKit.register()
        PermissionsKit.register()
        OnboardingKit.register()
        SettingsKit.register()
        GalleryKit.register()
        SelfTestRunner.registerKitChecks()
    }
}
