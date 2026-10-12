import AppKit

/// Restarts the app (Input Monitoring and Screen Recording only take effect in a new process).
/// A small shell loop waits until this process is really gone, then opens the bundle again:
/// a fixed pause let the new copy start while the old one was still shutting down (VoiceBud).
enum AppRelaunch {
    /// False for bare binaries, renders, tests and headless runs: nothing to reopen there.
    static var isAvailable: Bool { AppInfo.isAppBundle && !RenderMode.isHeadless && !RenderMode.isStatic }

    /// The helper's argv (pure; PermissionsTests). PID and path are positional parameters of
    /// `sh -c`, never spliced into the script, so no quoting can break it.
    nonisolated static func arguments(pid: Int32, appPath: String) -> [String] {
        ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; exec /usr/bin/open \"$2\"",
         "relaunch", String(pid), appPath]
    }

    /// Runs `prepare` (persist whatever must survive, e.g. the onboarding step), starts the helper
    /// and quits. Returns false (and does nothing) when a relaunch is not possible.
    @discardableResult
    static func relaunch(prepare: () -> Void = {}) -> Bool {
        guard isAvailable else {
            Log.warn("relaunch skipped: not an installed app bundle or headless", "permissions")
            return false
        }
        prepare()
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = arguments(pid: ProcessInfo.processInfo.processIdentifier, appPath: Bundle.main.bundlePath)
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice
        do {
            try helper.run()
        } catch {
            Log.error("relaunch helper failed: \(error)", "permissions")
            return false
        }
        NSApp.terminate(nil)
        return true
    }
}
