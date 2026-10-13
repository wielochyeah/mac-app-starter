import AppKit
import ApplicationServices
import AVFoundation
import Contacts
import CoreBluetooth
import CoreGraphics
import CoreLocation
import CoreServices
import EventKit
import IOKit.hid
import Photos
import Speech
import UserNotifications

/// Reads and requests permissions. `SystemPermissions` talks to macOS; tests and renders inject
/// their own backend so nothing ever asks the system.
protocol PermissionBackend: AnyObject {
    /// The system's current answer. `fresh`: the app asked in this run, so read it from a new
    /// process where this one would keep its launch answer (Screen Recording).
    func check(_ kind: PermissionKind, fresh: Bool) async -> PermissionStatus
    /// Shows macOS's own question (dialog kinds) or its "open System Settings" alert (switch kinds).
    func request(_ kind: PermissionKind) async
}

/// The real backend. Checks never show anything; only `request` makes macOS ask.
/// Completion handlers are `@Sendable`: macOS calls them on its own queues (a main-actor closure
/// there would trap under Swift 6).
final class SystemPermissions: PermissionBackend {
    // kept alive while macOS asks (and for the status of location)
    private var locationManager: CLLocationManager?
    private var bluetooth: CBCentralManager?
    private var eventStore: EKEventStore?
    private var contactStore: CNContactStore?

    func check(_ kind: PermissionKind, fresh: Bool) async -> PermissionStatus {
        switch kind {
        case .microphone: return PermissionRules.av(AVCaptureDevice.authorizationStatus(for: .audio))
        case .camera: return PermissionRules.av(AVCaptureDevice.authorizationStatus(for: .video))
        case .accessibility, .inputMonitoring:
            return Self.checkNow(kind) ?? .missing
        case .screenRecording:
            // a running process keeps the answer it got at launch; a child process sees the switch
            if fresh, let probed = await PermissionProbe.ask(kind) { return probed }
            return Self.checkNow(kind) ?? .missing
        case .notifications:
            // UNUserNotificationCenter needs a real app bundle (it throws in a bare binary)
            guard AppInfo.isAppBundle else { return .missing }
            return await withCheckedContinuation { (done: CheckedContinuation<PermissionStatus, Never>) in
                UNUserNotificationCenter.current().getNotificationSettings { @Sendable settings in
                    done.resume(returning: PermissionRules.notifications(settings.authorizationStatus))
                }
            }
        case .automation(let bundleId):
            return PermissionRules.automation(await Self.automation(bundleId, ask: false))
        case .speechRecognition: return PermissionRules.speech(SFSpeechRecognizer.authorizationStatus())
        case .contacts: return PermissionRules.contacts(CNContactStore.authorizationStatus(for: .contacts))
        case .calendars: return PermissionRules.events(EKEventStore.authorizationStatus(for: .event))
        case .reminders: return PermissionRules.events(EKEventStore.authorizationStatus(for: .reminder))
        case .photos: return PermissionRules.photos(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .location:
            let manager = locationManager ?? CLLocationManager()
            locationManager = manager
            return PermissionRules.location(manager.authorizationStatus)
        case .bluetooth: return PermissionRules.bluetooth(CBManager.authorization)
        case .localNetwork: return .missing
        }
    }

    func request(_ kind: PermissionKind) async {
        // never a real macOS prompt from tests, renders, the self-test or STARTER_HEADLESS runs
        guard !RenderMode.isHeadless, !RenderMode.isStatic else {
            return Log.warn("permission request skipped in a headless run: \(public: kind.id)", "permissions")
        }
        switch kind {
        case .microphone: _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .camera: _ = await AVCaptureDevice.requestAccess(for: .video)
        case .accessibility:
            // the key's value (kAXTrustedCheckOptionPrompt is a C global, not concurrency-safe)
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .inputMonitoring: _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        case .screenRecording: _ = CGRequestScreenCaptureAccess()
        case .notifications:
            guard AppInfo.isAppBundle else { return Log.warn("notifications need the .app bundle", "permissions") }
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { @Sendable _, _ in
                    done.resume()
                }
            }
        case .automation(let bundleId): _ = await Self.automation(bundleId, ask: true)
        case .speechRecognition:
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                SFSpeechRecognizer.requestAuthorization { @Sendable _ in done.resume() }
            }
        case .contacts:
            let store = contactStore ?? CNContactStore()
            contactStore = store
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                store.requestAccess(for: .contacts) { @Sendable _, _ in done.resume() }
            }
        case .calendars, .reminders:
            let store = eventStore ?? EKEventStore()
            eventStore = store
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                if kind == .calendars {
                    store.requestFullAccessToEvents { @Sendable _, _ in done.resume() }
                } else {
                    store.requestFullAccessToReminders { @Sendable _, _ in done.resume() }
                }
            }
        case .photos:
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { @Sendable _ in done.resume() }
            }
        case .location:
            let manager = locationManager ?? CLLocationManager()
            locationManager = manager
            manager.requestWhenInUseAuthorization()   // answered later; the monitor polls
        case .bluetooth:
            // creating a central manager makes macOS ask; the monitor polls CBManager.authorization
            if bluetooth == nil { bluetooth = CBCentralManager(delegate: nil, queue: nil) }
        case .localNetwork:
            break   // macOS asks on the first local network access, there is no request API
        }
    }

    /// Synchronous checks that work without any framework object (also used by the probe and the
    /// launch sample). nil for kinds that need more.
    nonisolated static func checkNow(_ kind: PermissionKind) -> PermissionStatus? {
        switch kind {
        case .accessibility: PermissionRules.trusted(AXIsProcessTrusted())
        case .inputMonitoring: PermissionRules.hid(IOHIDCheckAccess(kIOHIDRequestTypeListenEvent))
        case .screenRecording: PermissionRules.trusted(CGPreflightScreenCaptureAccess())
        default: nil
        }
    }

    /// AEDeterminePermissionToAutomateTarget off the main thread (with `ask` it waits for the
    /// person's answer).
    nonisolated static func automation(_ bundleId: String, ask: Bool) async -> OSStatus {
        await Task.detached {
            var target = AEAddressDesc()
            let bytes = Array(bundleId.utf8)
            let made = bytes.withUnsafeBufferPointer { buffer in
                AECreateDesc(DescType(typeApplicationBundleID), buffer.baseAddress, buffer.count, &target)
            }
            guard made == 0 else { return OSStatus(made) }
            defer { AEDisposeDesc(&target) }
            return AEDeterminePermissionToAutomateTarget(&target, AEEventClass(typeWildCard), AEEventID(typeWildCard), ask)
        }.value
    }
}

/// `--permission-probe <id>`: a fresh process prints the status it sees at launch. A long-running
/// process keeps the Screen Recording answer it got when it started (VoiceBud `--screen-access`).
enum PermissionProbe {
    nonisolated static let flag = "--permission-probe"

    /// Child side: prints the status word, exit 0; unknown or uncheckable kind: exit 2.
    nonisolated static func answer(_ id: String) -> Int32 {
        guard let kind = PermissionKind(id: id), let status = SystemPermissions.checkNow(kind) else {
            FileHandle.standardError.write(Data("\(flag): \(id) cannot be probed\n".utf8))
            return 2
        }
        print(status.rawValue)
        return 0
    }

    /// Parent side: runs this app's binary with the probe flag (headless, 5 s at most).
    static func ask(_ kind: PermissionKind) async -> PermissionStatus? {
        guard AppInfo.isAppBundle, let executable = Bundle.main.executableURL else { return nil }
        let id = kind.id
        return await Task.detached { () -> PermissionStatus? in
            let process = Process()
            process.executableURL = executable
            process.arguments = [flag, id]
            var environment = ProcessInfo.processInfo.environment
            environment["STARTER_HEADLESS"] = "1"
            process.environment = environment
            let out = Pipe()
            process.standardOutput = out
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return nil }
            let deadline = Date().addingTimeInterval(5)
            while process.isRunning && Date() < deadline { usleep(20_000) }
            if process.isRunning {
                process.terminate()
                return nil
            }
            let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            return PermissionStatus(rawValue: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }.value
    }
}
