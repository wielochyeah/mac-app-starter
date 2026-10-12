import AppKit
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
        /// Registered, but the person still has to allow it in System Settings, General, Login
        /// Items & Extensions.
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

    /// Opens System Settings at General, Login Items & Extensions.
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
    init(status: LoginItem.Status, unavailable: LoginItem.Unavailable? = nil, error: String? = nil) {
        isLive = false
        self.status = status
        self.unavailable = unavailable
        self.error = error
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
    /// Set once a login-item choice from the onboarding step was applied; later runs start at what
    /// macOS reports.
    static var backgroundLoginAsked: SettingKey<Bool> { .init("background.loginItemAsked", default: false) }
    /// The choice on the onboarding step during a first setup, not applied yet. Stored only while
    /// onboarding runs; `LoginWish` applies it once onboarding is done and removes it.
    static var backgroundLoginWish: SettingKey<Bool> { .init("background.loginItemWish", default: false) }
}

/// The onboarding step's switch (pure, tested): a choice not applied yet wins; else on by default
/// in a first setup (VoiceBud), later what macOS reports, so the person's own choice is not overruled.
enum LoginItemStepRule {
    static func initial(status: LoginItem.Status, asked: Bool, pending: Bool? = nil) -> Bool {
        if let pending { return pending }
        return asked ? (status == .enabled || status == .requiresApproval) : true
    }
}

/// The first-setup choice of the onboarding step, applied only when onboarding is done (VoiceBud
/// sends the login choice in `finish`, never earlier): at launch for a wish left from an earlier
/// run, and from `Registry.onboardingFinishedHooks`. Going back, closing the setup window or
/// quitting halfway registers nothing; the wish waits for the next setup.
enum LoginWish {
    /// A pending wish is applied once onboarding is done (pure, tested).
    static func isDue(onboardingDone: Bool, pending: Bool?) -> Bool { onboardingDone && pending != nil }

    static func pending(_ settings: Settings) -> Bool? {
        settings.hasValue(.backgroundLoginWish) ? settings[.backgroundLoginWish] : nil
    }

    /// Applies a pending wish when onboarding is done: changes the login item only when it differs
    /// from what macOS reports, remembers that the person was asked, forgets the wish.
    @discardableResult
    static func applyIfDue(settings: Settings = .shared, login: LoginItemModel = .shared) -> Bool {
        let wanted = pending(settings)
        guard let wanted, isDue(onboardingDone: settings[.onboardingDone], pending: wanted) else { return false }
        settings.reset(.backgroundLoginWish)
        settings[.backgroundLoginAsked] = true
        login.refresh()
        if LoginItem.needsChange(to: wanted, from: login.status) { login.set(wanted) }
        return true
    }
}
