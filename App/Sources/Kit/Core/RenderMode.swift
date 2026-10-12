import SwiftUI

/// How the process runs.
enum RenderMode {
    /// True while `--render` draws scenes offscreen: no glass, no timelines, no AppKit-backed
    /// controls (they do not draw in offscreen captures). Views read `\.renderStatic` instead
    /// where they can; this flag is for code outside a view tree.
    static var isStatic = false

    /// `STARTER_HEADLESS=1`: activation policy `.prohibited`, windows are never ordered front,
    /// no status item. Used by tests, renders and `--selftest`.
    static let isHeadless: Bool = ProcessInfo.processInfo.environment["STARTER_HEADLESS"] == "1"
}

private nonisolated struct RenderStaticKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside a `--render` capture. Swap AppKit-backed views (ScrollView, TextField,
    /// glass, TimelineView) for static stand-ins that look the same.
    var renderStatic: Bool {
        get { self[RenderStaticKey.self] }
        set { self[RenderStaticKey.self] = newValue }
    }
}
