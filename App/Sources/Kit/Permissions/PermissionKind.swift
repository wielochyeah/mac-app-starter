import Foundation

/// A macOS privacy permission (TCC) the app can ask for. The ids match the names in
/// `starter.json` `"permissions"` (scripts/gen_config.py); Automation names its target app:
/// `"automation:com.apple.mail"`.
///
/// Every check, request and System Settings link goes through Kit/Permissions
/// (`PermissionMonitor`), never through the frameworks directly in feature code.
nonisolated enum PermissionKind: Hashable, Sendable {
    case microphone, camera, accessibility, inputMonitoring, screenRecording, notifications
    /// Apple Events to one other app, by bundle id (e.g. "com.apple.mail").
    case automation(bundleId: String)
    case speechRecognition, contacts, calendars, reminders, photos, location, bluetooth, localNetwork

    /// Every kind without a target, in the order the starter documents them.
    static let simple: [PermissionKind] = [
        .microphone, .camera, .accessibility, .inputMonitoring, .screenRecording, .notifications,
        .speechRecognition, .contacts, .calendars, .reminders, .photos, .location, .bluetooth, .localNetwork,
    ]

    /// The config name: "microphone", "inputMonitoring", "automation:com.apple.mail".
    var id: String {
        switch self {
        case .microphone: "microphone"
        case .camera: "camera"
        case .accessibility: "accessibility"
        case .inputMonitoring: "inputMonitoring"
        case .screenRecording: "screenRecording"
        case .notifications: "notifications"
        case .automation(let bundleId): "automation:\(bundleId)"
        case .speechRecognition: "speechRecognition"
        case .contacts: "contacts"
        case .calendars: "calendars"
        case .reminders: "reminders"
        case .photos: "photos"
        case .location: "location"
        case .bluetooth: "bluetooth"
        case .localNetwork: "localNetwork"
        }
    }

    /// Parses a config name. Plain "automation" has no target and is rejected (nil): macOS asks per
    /// target app, so there is nothing to check or request without one.
    init?(id: String) {
        if id.hasPrefix("automation:") {
            let target = String(id.dropFirst("automation:".count)).trimmingCharacters(in: .whitespaces)
            guard Self.isBundleId(target) else { return nil }
            self = .automation(bundleId: target)
            return
        }
        guard let kind = Self.simple.first(where: { $0.id == id }) else { return nil }
        self = kind
    }

    static func isBundleId(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count >= 2 && parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }

    /// How macOS asks. `.dialog`: a system alert with Allow / Don't Allow. `.settingsSwitch`: the
    /// person flips a switch in System Settings (Accessibility, Input Monitoring, Screen Recording).
    enum Prompt: Sendable { case dialog, settingsSwitch, firstUse }

    var prompt: Prompt {
        switch self {
        case .accessibility, .inputMonitoring, .screenRecording: .settingsSwitch
        case .localNetwork: .firstUse
        default: .dialog
        }
    }

    /// Takes effect only after the app restarts once it is granted (IOHID listen access and
    /// Screen Recording; notes vb-onboarding-hub §2.3, gotcha 11).
    var needsRestart: Bool { self == .inputMonitoring || self == .screenRecording }

    /// The request returns only once macOS has an answer, or once it gave up without asking (the
    /// target app of Automation is not running, a dismissed notification prompt). Location and
    /// Bluetooth return at once and answer later; switch kinds wait for the person in Settings.
    var requestWaitsForAnswer: Bool { prompt == .dialog && self != .location && self != .bluetooth }

    /// False where macOS offers no way to read the status (Local Network is asked on first use).
    var canCheck: Bool { self != .localNetwork }

    /// SF Symbol and squircle tint of the permission's onboarding hero and rows.
    var symbol: String {
        switch self {
        case .microphone: "mic.fill"
        case .camera: "camera.fill"
        case .accessibility: "accessibility"
        case .inputMonitoring: "keyboard.fill"
        case .screenRecording: "rectangle.dashed.badge.record"
        case .notifications: "bell.badge.fill"
        case .automation: "gearshape.2.fill"
        case .speechRecognition: "waveform"
        case .contacts: "person.crop.circle.fill"
        case .calendars: "calendar"
        case .reminders: "checklist"
        case .photos: "photo.fill"
        case .location: "location.fill"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .localNetwork: "network"
        }
    }

    var tint: TintName {
        switch self {
        case .microphone: .orange
        case .camera: .green
        case .accessibility: .blue
        case .inputMonitoring: .graphite
        case .screenRecording: .indigo
        case .notifications: .red
        case .automation: .graphite
        case .speechRecognition: .violet
        case .contacts: .sky
        case .calendars: .red
        case .reminders: .yellow
        case .photos: .teal
        case .location: .blue
        case .bluetooth: .indigo
        case .localNetwork: .sky
        }
    }

    /// The pane in System Settings → Privacy & Security (Notifications: the app's own entry).
    func settingsURL(bundleId: String = AppConfig.bundleId) -> URL? {
        let privacy = "x-apple.systempreferences:com.apple.preference.security?Privacy_"
        let anchor: String
        switch self {
        case .notifications:
            return URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleId)")
        case .microphone: anchor = "Microphone"
        case .camera: anchor = "Camera"
        case .accessibility: anchor = "Accessibility"
        case .inputMonitoring: anchor = "ListenEvent"
        case .screenRecording: anchor = "ScreenCapture"
        case .automation: anchor = "Automation"
        case .speechRecognition: anchor = "SpeechRecognition"
        case .contacts: anchor = "Contacts"
        case .calendars: anchor = "Calendars"
        case .reminders: anchor = "Reminders"
        case .photos: anchor = "Photos"
        case .location: anchor = "LocationServices"
        case .bluetooth: anchor = "Bluetooth"
        case .localNetwork: anchor = "LocalNetwork"
        }
        return URL(string: privacy + anchor)
    }
}
