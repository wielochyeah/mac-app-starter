import AppKit
import Observation
import SwiftUI

/// The app's one view of its permissions. Observable: a view that reads `status(_:)` redraws when
/// it changes. Polls macOS only while someone watches (`watch(_:)` inside a view's `.task`), once
/// a second, and stops the moment that view goes away (VoiceBud: watching only while a
/// permission step is visible).
///
///     .task { await PermissionMonitor.shared.watch([.microphone]) }
///     switch monitor.status(.microphone) { … }
///     Button(…) { monitor.request(.microphone) }
@Observable final class PermissionMonitor {
    static let shared = PermissionMonitor(backend: SystemPermissions())

    /// Seconds between two polls while watched.
    nonisolated static let pollInterval: Double = 1

    @ObservationIgnored private let backend: PermissionBackend
    /// The system's last answers.
    private(set) var polled: [PermissionKind: PermissionStatus] = [:]
    /// Kinds requested in this run (a polled `missing` then shows as `requested`).
    private(set) var asked: Set<PermissionKind> = []
    /// What this process saw at launch, for kinds that need a restart (`sampleLaunchStatus`).
    @ObservationIgnored private(set) var atLaunch: [PermissionKind: PermissionStatus] = [:]
    /// Renders and previews: fixed answers that win over everything else.
    @ObservationIgnored private var pinned: [PermissionKind: PermissionStatus] = [:]
    /// How many `watch` loops run right now (tests, and the guarantee that idle means no polling).
    private(set) var watchers = 0

    init(backend: PermissionBackend) {
        self.backend = backend
    }

    /// A monitor that never asks the system and always answers with these states (render scenes).
    static func preview(_ states: [PermissionKind: PermissionStatus]) -> PermissionMonitor {
        let monitor = PermissionMonitor(backend: SilentPermissions())
        monitor.pinned = states
        return monitor
    }

    // MARK: Reading

    /// The status to show (pure rule: `PermissionRules.effective`).
    func status(_ kind: PermissionKind) -> PermissionStatus {
        if let pinned = pinned[kind] { return pinned }
        return PermissionRules.effective(kind: kind, polled: polled[kind], asked: asked.contains(kind),
                                         atLaunch: atLaunch[kind])
    }

    /// Asks macOS now and records the answers.
    func refresh(_ kinds: [PermissionKind]) async {
        for kind in kinds where pinned[kind] == nil && kind.canCheck {
            let answer = await backend.check(kind, fresh: asked.contains(kind))
            record(kind, answer)
        }
    }

    /// Records one system answer (only writes on change, so observers redraw only then).
    func record(_ kind: PermissionKind, _ answer: PermissionStatus) {
        if polled[kind] != answer { polled[kind] = answer }
    }

    /// Polls `kinds` once a second until the calling task is cancelled (a view's `.task` ends
    /// when the view disappears).
    func watch(_ kinds: [PermissionKind]) async {
        watchers += 1
        defer { watchers -= 1 }
        while !Task.isCancelled {
            await refresh(kinds)
            try? await Task.sleep(for: .seconds(Self.pollInterval))
        }
    }

    // MARK: Acting

    /// Makes macOS ask (or show its "open System Settings" alert). The status turns `requested`
    /// right away and follows the system's answer from then on.
    func request(_ kind: PermissionKind) {
        guard pinned[kind] == nil else { return }
        asked.insert(kind)
        Task {
            await backend.request(kind)
            await refresh([kind])
        }
    }

    /// Marks a kind as requested without asking (tests).
    func markAsked(_ kind: PermissionKind) { asked.insert(kind) }

    /// Opens the kind's pane in System Settings → Privacy & Security.
    func openSettings(_ kind: PermissionKind) {
        guard pinned[kind] == nil, !RenderMode.isHeadless, let url = kind.settingsURL() else { return }
        NSWorkspace.shared.open(url)
    }

    /// Shows the app in the Finder, so it can be dragged into a privacy list where it is missing.
    func revealApp() {
        guard !RenderMode.isHeadless else { return }
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    /// Remembers what this process starts with for kinds that need a restart (a launch hook): a
    /// later `granted` then reads `restartNeeded` until the app restarts.
    func sampleLaunchStatus(_ kinds: [PermissionKind]) {
        for kind in kinds where kind.needsRestart && atLaunch[kind] == nil {
            if let now = SystemPermissions.checkNow(kind) { setLaunchStatus(kind, now) }
        }
    }

    /// Tests and previews.
    func setLaunchStatus(_ kind: PermissionKind, _ status: PermissionStatus) { atLaunch[kind] = status }
}

/// Answers `missing` and never asks (previews, tests).
final class SilentPermissions: PermissionBackend {
    func check(_ kind: PermissionKind, fresh: Bool) async -> PermissionStatus { .missing }
    func request(_ kind: PermissionKind) async {}
}

private nonisolated struct PermissionMonitorKey: EnvironmentKey {
    static let defaultValue: PermissionMonitor? = nil
}

extension EnvironmentValues {
    /// The monitor views read (default `PermissionMonitor.shared`; renders inject a preview).
    var permissionMonitor: PermissionMonitor {
        get { self[PermissionMonitorKey.self] ?? .shared }
        set { self[PermissionMonitorKey.self] = newValue }
    }
}
