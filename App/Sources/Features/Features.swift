// The project's own features. `Modules.registerAll()` calls `Features.register()` once, after the kit and every
// module, so a feature can use whatever module is compiled in (inside `#if MODUL_<NAME>` blocks).
// Add one line per feature, e.g. `NotesFeature.register()`; each feature appends to `Registry` like a module does.

enum Features {
    static func register() {
    }
}
