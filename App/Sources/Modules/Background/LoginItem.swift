import Foundation
import Observation
import ServiceManagement

/// "Open at login" through `SMAppService.mainApp` (macOS 13+, no helper app, no LaunchAgent).
///
/// Only the installed app can be a login item: macOS registers the bundle at its path, so a build
/// in the project's `build/` folder, a copy on the disk image or a translocated copy would leave a
/// stale entry (VoiceBud: "only the DMG build is a real app process"). `isAvailable` says whether
/// this copy qualifies; `unavailableReason` explains why not, for the person.
enum LoginItem {
    enum Status: Equatable {
        case enabled
        case disabled
        /// Registered, but the person still has to allow it in System Settings, Login Items.
        case requiresApproval
        /// This copy of the app cannot be a login item (`unavailableReason`).
        case unavailable
    }

    enum Unavailable: Equatable {
        /// A bare binary (tests, `swift run`), not an `.app`.
        case notBundle
        /// Running from a mounted disk image (`/Volumes/…`).
        case diskImage
        /// Gatekeeper moved the quarantined app to a random read-only place.
        case translocated
        /// Anywhere else than /Applications or ~/Applications (e.g. the project's build folder).
        case notInstalled
    }

    /// Where this copy runs decides (pure, tested). Nil = available.
    static func availability(bundlePath: String, isBundle: Bool, home: String) -> Unavailable? {
        guard isBundle else { return .notBundle }
        let path = (bundlePath as NSString).standardizingPath
        if path.contains("/AppTranslocation/") { return .translocated }
        if path.hasPrefix("/Volumes/") { return .diskImage }
        let homeApps = (home as NSString).appendingPathComponent("Applications") + "/"
        if path.hasPrefix("/Applications/") || path.hasPrefix(homeApps) { return nil }
        return .notInstalled
    }

    static var unavailableReason: Unavailable? {
        let bundle = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        return availability(bundlePath: bundle, isBundle: AppInfo.isAppBundle, home: NSHomeDirectory())
    }

    static var isAvailable: Bool { unavailableReason == nil }

    /// macOS's status mapped to ours (pure, tested). `notFound` means macOS has no record of this
    /// copy yet, which reads as "not registered".
    static func map(_ status: SMAppService.Status) -> Status {
        switch status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .disabled
        @unknown default: .disabled
        }
    }

    static var status: Status {
        guard isAvailable else { return .unavailable }
        return map(SMAppService.mainApp.status)
    }

    /// Whether `on` asks for a change against the current status (only then macOS is called, so
    /// switching works both ways, VoiceBud review 05.10.: "off" was ignored).
    static func needsChange(to on: Bool, from status: Status) -> Bool {
        switch status {
        case .unavailable: false
        case .enabled, .requiresApproval: !on
        case .disabled: on
        }
    }

    /// Registers or unregisters this app as a login item. Never call it from tests or renders.
    static func setEnabled(_ on: Bool) throws {
        guard needsChange(to: on, from: status) else { return }
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    /// Opens System Settings at General, Login Items.
    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// The login item for SwiftUI: status, why it is unavailable, the last error. Re-read on
/// `refresh()` (pane appears, after a change); renders pass fixed values.
@Observable final class LoginItemModel {
    static let shared = LoginItemModel()

    private(set) var status: LoginItem.Status = .unavailable
    private(set) var unavailable: LoginItem.Unavailable?
    private(set) var error: String?
    @ObservationIgnored private let isLive: Bool

    /// Live: reads `SMAppService`.
    init() {
        isLive = true
        refresh()
    }

    /// Fixed values for renders and tests; `set` changes only the shown status.
    init(status: LoginItem.Status, unavailable: LoginItem.Unavailable? = nil) {
        isLive = false
        self.status = status
        self.unavailable = unavailable
    }

    var isOn: Bool { status == .enabled || status == .requiresApproval }

    func refresh() {
        guard isLive else { return }
        unavailable = LoginItem.unavailableReason
        status = LoginItem.status
    }

    func set(_ on: Bool) {
        guard isLive else {
            if status != .unavailable { status = on ? .enabled : .disabled }
            return
        }
        do {
            try LoginItem.setEnabled(on)
            error = nil
        } catch {
            self.error = BackgroundText.loginItemFailed(JobBook.message(error))
            Log.error("login item: \(error)", "background")
        }
        refresh()
    }
}

extension SettingKey {
    /// Set once the login-item onboarding step was shown; later runs start at what macOS reports.
    static var backgroundLoginAsked: SettingKey<Bool> { .init("background.loginItemAsked", default: false) }
}

/// The onboarding step's switch (pure, tested): on by default in a first setup (VoiceBud), later
/// what macOS reports, so the person's own choice is not overruled.
enum LoginItemStepRule {
    static func initial(status: LoginItem.Status, asked: Bool) -> Bool {
        asked ? (status == .enabled || status == .requiresApproval) : true
    }
}
