import SwiftUI

/// How the process runs.
enum RenderMode {
    /// True while `--render` draws scenes offscreen: no glass, no timelines, no AppKit-backed
    /// controls (they do not draw in offscreen captures). Views read `\.renderStatic` instead
    /// where they can; this flag is for code outside a view tree.
    static var isStatic = false

    /// Activation policy `.prohibited`, windows are never ordered front, no status item, and no
    /// file of the person's is opened (notes stay in memory). Set by `STARTER_HEADLESS=1` (tests)
    /// and for every tool run (`--render`, `--selftest`, `--permission-probe`) whatever the
    /// environment says, in `Launch.run`.
    private(set) static var isHeadless: Bool = headless(environment: ProcessInfo.processInfo.environment, tool: false)

    /// Whether a process runs headless (pure, tested).
    nonisolated static func headless(environment: [String: String], tool: Bool) -> Bool {
        tool || environment["STARTER_HEADLESS"] == "1"
    }

    /// Makes this process headless before anything opens a window or a file (tool runs).
    static func enterHeadless() { isHeadless = true }
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
