#if TESTING
import AppKit
import AVFoundation
import Contacts
import CoreBluetooth
import CoreLocation
import EventKit
import IOKit.hid
import Photos
import Speech
import UserNotifications

/// Records what the monitor asks; answers from a table. Never touches macOS.
final class FakePermissions: PermissionBackend {
    var answers: [PermissionKind: PermissionStatus] = [:]
    var checks: [(PermissionKind, Bool)] = []
    var requests: [PermissionKind] = []

    func check(_ kind: PermissionKind, fresh: Bool) async -> PermissionStatus {
        checks.append((kind, fresh))
        return answers[kind] ?? .missing
    }

    func request(_ kind: PermissionKind) async { requests.append(kind) }
}

/// Runs main-actor async work to completion by spinning the main run loop (the harness is sync).
func spin(_ seconds: Double = 0.05, until done: () -> Bool = { false }) {
    let end = Date().addingTimeInterval(seconds)
    while Date() < end && !done() { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
}

final class PermissionsTests: TestSuite {
    static var all: [PermissionKind] { PermissionKind.simple + [.automation(bundleId: "com.apple.mail")] }

    override class func register() {
        test("ids round-trip, automation needs a target") {
            for kind in all { expectEqual(PermissionKind(id: kind.id), kind, kind.id) }
            expectEqual(PermissionKind(id: "automation:com.apple.Mail"), .automation(bundleId: "com.apple.Mail"))
            for bad in ["automation", "automation:", "automation:mail", "automation:com..mail", "Microphone", "bogus", ""] {
                expect(PermissionKind(id: bad) == nil, "\(bad) should not parse")
            }
            expectEqual(PermissionsKit.invalidConfigEntries(["notifications", "automation", "mic", "automation:com.apple.mail"]),
                        ["automation", "mic"])
            expectEqual(PermissionKind.simple.count, 14, "every starter.json name except automation")
        }

        test("every config name the build accepts is a kind") {
            // scripts/gen_config.py PERMISSION_KEYS lists the names starter.json may use
            let script = (try? String(contentsOf: repoRoot.appendingPathComponent("scripts/gen_config.py"), encoding: .utf8)) ?? ""
            guard let start = script.range(of: "PERMISSION_KEYS = {"), let end = script.range(of: "}", range: start.upperBound..<script.endIndex)
            else { return fail("PERMISSION_KEYS not found") }
            let names = script[start.upperBound..<end.lowerBound].split(separator: "\n").compactMap { line -> String? in
                guard let q1 = line.firstIndex(of: "\""), let q2 = line[line.index(after: q1)...].firstIndex(of: "\"") else { return nil }
                return String(line[line.index(after: q1)..<q2])
            }
            expectEqual(Set(names), Set(PermissionKind.simple.map(\.id) + ["automation"]))
        }

        test("restart, prompt and check facts") {
            expectEqual(all.filter(\.needsRestart), [.inputMonitoring, .screenRecording])
            expectEqual(all.filter { $0.prompt == .settingsSwitch }, [.accessibility, .inputMonitoring, .screenRecording])
            expectEqual(all.filter { !$0.canCheck }, [.localNetwork])
        }

        test("System Settings links point at the right pane") {
            expectEqual(PermissionKind.microphone.settingsURL()?.absoluteString,
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
            expectEqual(PermissionKind.inputMonitoring.settingsURL()?.absoluteString,
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
            expectEqual(PermissionKind.screenRecording.settingsURL()?.absoluteString,
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            expectEqual(PermissionKind.notifications.settingsURL(bundleId: "com.example.x")?.absoluteString,
                        "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.example.x")
            for kind in all { expect(kind.settingsURL() != nil, "\(kind.id) has no link") }
        }

        test("every kind has an SF Symbol") {
            for kind in all {
                expect(NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil) != nil, "\(kind.id): \(kind.symbol)")
            }
        }

        test("effective status: requested survives a polled missing") {
            let mic = PermissionKind.microphone
            expectEqual(PermissionRules.effective(kind: mic, polled: nil, asked: false, atLaunch: nil), .missing)
            expectEqual(PermissionRules.effective(kind: mic, polled: .missing, asked: false, atLaunch: nil), .missing)
            expectEqual(PermissionRules.effective(kind: mic, polled: nil, asked: true, atLaunch: nil), .requested)
            expectEqual(PermissionRules.effective(kind: mic, polled: .missing, asked: true, atLaunch: nil), .requested)
            expectEqual(PermissionRules.effective(kind: mic, polled: .denied, asked: true, atLaunch: nil), .denied)
            expectEqual(PermissionRules.effective(kind: mic, polled: .granted, asked: true, atLaunch: .missing), .granted,
                        "the microphone needs no restart")
        }

        test("effective status: restart kinds granted after launch need a restart") {
            for kind in [PermissionKind.inputMonitoring, .screenRecording] {
                expectEqual(PermissionRules.effective(kind: kind, polled: .granted, asked: true, atLaunch: .missing), .restartNeeded)
                expectEqual(PermissionRules.effective(kind: kind, polled: .granted, asked: false, atLaunch: .denied), .restartNeeded)
                expectEqual(PermissionRules.effective(kind: kind, polled: .granted, asked: false, atLaunch: .granted), .granted)
                expectEqual(PermissionRules.effective(kind: kind, polled: .granted, asked: false, atLaunch: nil), .granted,
                            "launch not sampled: no false restart prompt")
            }
        }

        test("system values map to statuses") {
            expectEqual(PermissionRules.av(.authorized), .granted)
            expectEqual(PermissionRules.av(.denied), .denied)
            expectEqual(PermissionRules.av(.restricted), .denied)
            expectEqual(PermissionRules.av(.notDetermined), .missing)
            expectEqual(PermissionRules.trusted(true), .granted)
            expectEqual(PermissionRules.trusted(false), .missing)
            expectEqual(PermissionRules.hid(kIOHIDAccessTypeGranted), .granted)
            expectEqual(PermissionRules.hid(kIOHIDAccessTypeDenied), .denied)
            expectEqual(PermissionRules.hid(kIOHIDAccessTypeUnknown), .missing)
            expectEqual(PermissionRules.notifications(.authorized), .granted)
            expectEqual(PermissionRules.notifications(.provisional), .granted)
            expectEqual(PermissionRules.notifications(.denied), .denied)
            expectEqual(PermissionRules.notifications(.notDetermined), .missing)
            expectEqual(PermissionRules.automation(0), .granted)
            expectEqual(PermissionRules.automation(-1743), .denied)
            expectEqual(PermissionRules.automation(-1744), .missing)
            expectEqual(PermissionRules.automation(-600), .missing)
            expectEqual(PermissionRules.contacts(.authorized), .granted)
            expectEqual(PermissionRules.contacts(.denied), .denied)
            expectEqual(PermissionRules.events(.fullAccess), .granted)
            expectEqual(PermissionRules.events(.writeOnly), .denied, "write-only is not the full access we asked for")
            expectEqual(PermissionRules.events(.notDetermined), .missing)
            expectEqual(PermissionRules.photos(.limited), .granted)
            expectEqual(PermissionRules.photos(.restricted), .denied)
            expectEqual(PermissionRules.location(.authorizedAlways), .granted)
            expectEqual(PermissionRules.location(.denied), .denied)
            expectEqual(PermissionRules.location(.notDetermined), .missing)
            expectEqual(PermissionRules.bluetooth(.allowedAlways), .granted)
            expectEqual(PermissionRules.bluetooth(.restricted), .denied)
            expectEqual(PermissionRules.speech(.authorized), .granted)
            expectEqual(PermissionRules.speech(.notDetermined), .missing)
        }

        test("monitor: request marks requested at once, a switch kind keeps waiting, then follows the system") {
            let fake = FakePermissions()
            let monitor = PermissionMonitor(backend: fake)
            expectEqual(monitor.status(.screenRecording), .missing)
            monitor.request(.screenRecording)
            expectEqual(monitor.status(.screenRecording), .requested)
            spin(1) { fake.requests == [.screenRecording] && !fake.checks.isEmpty }
            spin(0.05)
            expectEqual(fake.requests, [.screenRecording])
            expectEqual(fake.checks.last?.1, true, "a requested kind is checked fresh")
            expectEqual(monitor.status(.screenRecording), .requested, "the switch in System Settings is not on yet")
            fake.answers[.screenRecording] = .granted
            var done = false
            Task { await monitor.refresh([.screenRecording]); done = true }
            spin(1) { done }
            expectEqual(monitor.status(.screenRecording), .granted)
        }

        test("monitor: a dialog that ends without a decision offers Allow Access again") {
            // AEDeterminePermissionToAutomateTarget returns -600 at once when the target is not
            // running; a dismissed prompt also returns undecided
            let fake = FakePermissions()
            let monitor = PermissionMonitor(backend: fake)
            let mail = PermissionKind.automation(bundleId: "com.apple.mail")
            monitor.request(mail)
            expectEqual(monitor.status(mail), .requested, "while macOS asks")
            spin(1) { !monitor.asked.contains(mail) }
            expectEqual(monitor.status(mail), .missing)
            let slot = PermissionStep.slot(for: mail, status: monitor.status(mail), monitor: monitor, restart: {})
            expectEqual(slot.kind, .action)
            monitor.request(mail)
            spin(1) { fake.requests.count == 2 }
            expectEqual(fake.requests, [mail, mail], "asking again reaches macOS again")
            // answered: the refresh before forgetting the request has it, no flash of "missing"
            fake.answers[.camera] = .granted
            monitor.request(.camera)
            spin(1) { !monitor.asked.contains(.camera) }
            expectEqual(monitor.status(.camera), .granted)
        }

        test("monitor: location answers later, so its request stays open until the step is shown again") {
            let monitor = PermissionMonitor(backend: FakePermissions())
            monitor.request(.location)
            spin(0.1)
            expectEqual(monitor.status(.location), .requested)
            monitor.forgetRequest(.location)
            expectEqual(monitor.status(.location), .missing)
            monitor.markAsked(.accessibility)
            monitor.forgetRequest(.accessibility)
            expectEqual(monitor.status(.accessibility), .requested, "a switch kind keeps waiting for the switch")
        }

        test("monitor: polls only while watched, stops when the task ends") {
            let fake = FakePermissions()
            let monitor = PermissionMonitor(backend: fake)
            expectEqual(monitor.watchers, 0)
            let task = Task { await monitor.watch([.microphone, .localNetwork]) }
            spin(0.3) { !fake.checks.isEmpty }
            expectEqual(monitor.watchers, 1)
            expectEqual(fake.checks.map(\.0), [.microphone], "Local Network is never checked")
            task.cancel()
            spin(1) { monitor.watchers == 0 }
            expectEqual(monitor.watchers, 0)
            let count = fake.checks.count
            spin(0.2)
            expectEqual(fake.checks.count, count, "no polling after the watcher left")
        }

        test("monitor: restart kinds read restartNeeded until the app restarts") {
            let monitor = PermissionMonitor(backend: FakePermissions())
            monitor.setLaunchStatus(.inputMonitoring, .missing)
            monitor.record(.inputMonitoring, .granted)
            expectEqual(monitor.status(.inputMonitoring), .restartNeeded)
            let fresh = PermissionMonitor(backend: FakePermissions())
            fresh.setLaunchStatus(.inputMonitoring, .granted)
            fresh.record(.inputMonitoring, .granted)
            expectEqual(fresh.status(.inputMonitoring), .granted)
        }

        test("preview monitor answers fixed states and never asks") {
            let monitor = PermissionMonitor.preview([.microphone: .denied])
            monitor.request(.microphone)
            expectEqual(monitor.status(.microphone), .denied)
            expectEqual(monitor.status(.camera), .missing)
            expect(monitor.asked.isEmpty)
        }

        test("texts: every kind and state has words in both languages, du, no exclamation marks") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            for lang in Lang.allCases {
                Localizer.shared.forced = lang
                for kind in all {
                    var texts = [PermissionText.title(kind), PermissionText.settingsName(kind), PermissionsKit.why(kind)]
                    for status in PermissionStatus.allCases {
                        texts += PermissionText.hint(kind, status)
                        texts.append(PermissionText.short(status))
                    }
                    for text in texts {
                        expect(!text.isEmpty, "\(kind.id) \(lang): empty")
                        expect(!text.contains("!"), "\(kind.id) \(lang): \(text)")
                        if lang == .de { expect(!text.contains(" Sie ") && !text.contains("Ihre"), "\(kind.id): \(text)") }
                    }
                }
            }
        }

        test("hint lines fit the 64 pt hint area (at most three lines)") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            for lang in Lang.allCases {
                Localizer.shared.forced = lang
                for kind in all {
                    for status in PermissionStatus.allCases {
                        let lines = PermissionText.hint(kind, status).reduce(0) { $0 + $1.split(separator: "\n").count }
                        expect(lines <= 3, "\(kind.id) \(status) \(lang): \(lines) lines")
                    }
                }
            }
        }

        test("project reasons replace the kit sentence") {
            let saved = PermissionsKit.reasons
            defer { PermissionsKit.reasons = saved }
            PermissionsKit.reasons[.microphone] = { "Custom" }
            expectEqual(PermissionsKit.why(.microphone), "Custom")
            expect(PermissionsKit.why(.camera) != "Custom")
        }

        test("relaunch helper: pid and path are arguments, never part of the script") {
            let args = AppRelaunch.arguments(pid: 4242, appPath: "/Applications/My \"App\".app")
            expectEqual(args.count, 5)
            expectEqual(args[0], "-c")
            expect(args[1].contains("kill -0 \"$1\"") && args[1].contains("open \"$2\""))
            expect(!args[1].contains("4242") && !args[1].contains("Applications"))
            expectEqual(Array(args[3...]), ["4242", "/Applications/My \"App\".app"])
            expect(!AppRelaunch.isAvailable, "tests never relaunch")
            expect(!AppRelaunch.relaunch(), "relaunch must refuse in tests")
        }

        test("probe refuses kinds it cannot check in a fresh process") {
            expectEqual(PermissionProbe.answer("microphone"), 2)
            expectEqual(PermissionProbe.answer("bogus"), 2)
        }

        test("launch flag --permission-probe is a tool flag") {
            let flags = LaunchFlags.parse(["app", "--permission-probe", "screenRecording"])
            expectEqual(flags.permissionProbe, "screenRecording")
            expect(flags.isTool && flags.errors.isEmpty)
            expect(!LaunchFlags.parse(["app", "--permission-probe"]).errors.isEmpty)
        }
    }
}
#endif
