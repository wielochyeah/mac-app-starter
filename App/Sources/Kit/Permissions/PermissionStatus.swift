import AVFoundation
import Contacts
import CoreBluetooth
import CoreLocation
import EventKit
import IOKit.hid
import Photos
import Speech
import UserNotifications

/// What the app knows about one permission.
/// - `missing`: not decided yet (or, for switch permissions, not switched on).
/// - `requested`: the app asked in this run and macOS has not answered yet.
/// - `denied`: refused or restricted; only System Settings can change it.
/// - `granted`: allowed and in effect.
/// - `restartNeeded`: allowed, but takes effect only after the app restarts.
nonisolated enum PermissionStatus: String, CaseIterable, Sendable {
    case missing, requested, denied, granted, restartNeeded

    /// Allowed, whether or not it already works in this process.
    var isAllowed: Bool { self == .granted || self == .restartNeeded }
}

/// The pure rules between what the system reports and what the app shows (PermissionsTests).
nonisolated enum PermissionRules {
    /// The status to show for one kind.
    /// - polled: the system's answer (nil: not checked yet)
    /// - asked: the app requested it in this run (a polled `missing` then means "macOS has not
    ///   decided yet": VoiceBud gotcha 13, never overwrite a fresh request with `missing`)
    /// - atLaunch: the status this process started with; a restart kind granted later needs one
    static func effective(kind: PermissionKind, polled: PermissionStatus?, asked: Bool,
                          atLaunch: PermissionStatus?) -> PermissionStatus {
        switch polled ?? .missing {
        case .granted, .restartNeeded:
            if kind.needsRestart, let atLaunch, !atLaunch.isAllowed { return .restartNeeded }
            return .granted
        case .denied:
            return .denied
        case .missing, .requested:
            return asked ? .requested : .missing
        }
    }

    // MARK: System values to status

    static func av(_ s: AVAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .missing
        @unknown default: .missing
        }
    }

    static func trusted(_ yes: Bool) -> PermissionStatus { yes ? .granted : .missing }

    /// IOHIDCheckAccess (Input Monitoring).
    static func hid(_ s: IOHIDAccessType) -> PermissionStatus {
        switch s {
        case kIOHIDAccessTypeGranted: .granted
        case kIOHIDAccessTypeDenied: .denied
        default: .missing
        }
    }

    static func notifications(_ s: UNAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        case .notDetermined: .missing
        @unknown default: .missing
        }
    }

    /// AEDeterminePermissionToAutomateTarget. "Not running" reads as missing: macOS can only ask
    /// while the target app is open.
    static func automation(_ status: OSStatus) -> PermissionStatus {
        switch status {
        case 0: .granted           // noErr
        case -1743: .denied        // errAEEventNotPermitted
        default: .missing          // -1744 errAEEventWouldRequireUserConsent, -600 procNotFound
        }
    }

    static func contacts(_ s: CNAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorized, .limited: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .missing
        @unknown default: .missing
        }
    }

    /// Calendars and reminders. Write-only access is not enough for a "full access" request.
    static func events(_ s: EKAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .fullAccess: .granted
        case .denied, .restricted, .writeOnly: .denied
        case .notDetermined: .missing
        @unknown default: .missing
        }
    }

    static func photos(_ s: PHAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorized, .limited: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .missing
        @unknown default: .missing
        }
    }

    static func location(_ s: CLAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorizedAlways, .authorizedWhenInUse: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .missing
        @unknown default: .missing
        }
    }

    static func bluetooth(_ s: CBManagerAuthorization) -> PermissionStatus {
        switch s {
        case .allowedAlways: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .missing
        @unknown default: .missing
        }
    }

    static func speech(_ s: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .missing
        @unknown default: .missing
        }
    }
}
