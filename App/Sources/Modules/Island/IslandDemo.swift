import Foundation
import Observation

/// Whether the settings' short preview is playing (the pane's button turns into Stop).
@Observable
final class IslandDemoState {
    var previewing = false
}

/// Plays island states on the real island: `--demo` (or `--demo island`) loops every state for
/// the lead's manual check; the settings pane's "Show Preview" plays a short sequence once
/// (about 8 s). Never run by tests or renders (it puts a window on screen).
enum IslandDemo {
    static let state = IslandDemoState()
    private static var task: Task<Void, Never>?

    /// True when `--demo` names no area or names "island".
    static func wanted(_ arguments: [String] = CommandLine.arguments) -> Bool {
        guard let i = arguments.firstIndex(of: "--demo") else { return false }
        let areas = arguments[(i + 1)...].prefix { !$0.hasPrefix("-") }
        return areas.isEmpty || areas.contains("island")
    }

    /// Every state, once or in a loop (`--demo`).
    static func play(loop: Bool) {
        run(previewing: false) {
            repeat {
                await runAll()
            } while loop && !Task.isCancelled
        }
    }

    /// The settings' short preview: activity, progress, a done card with an action, a notice.
    static func preview() {
        run(previewing: true) { await runShort() }
    }

    static func stop() {
        task?.cancel()
        task = nil
        state.previewing = false
        Island.shared.dismiss()
    }

    private static func run(previewing: Bool, _ body: @escaping @MainActor () async -> Void) {
        task?.cancel()
        state.previewing = previewing
        task = Task { @MainActor in
            await body()
            guard !Task.isCancelled else { return }
            Island.shared.dismiss()
            state.previewing = false
            task = nil
        }
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private static func runShort() async {
        let island = Island.shared
        island.present(.activity(symbol: "timer", title: IslandSampleText.focus, detail: "24:13"))
        await pause(1.2)
        for step in 0...10 {
            guard !Task.isCancelled else { return }
            island.update(.progress(title: IslandSampleText.exporting, fraction: Double(step) / 10, symbol: "square.and.arrow.up"))
            await pause(0.15)
        }
        guard !Task.isCancelled else { return }
        island.update(.done(title: IslandSampleText.saved, detail: IslandSampleText.savedDetail, body: IslandSampleText.savedBody,
                            actions: [IslandAction(id: "reveal", title: IslandSampleText.showInFinder, symbol: "folder") {}]))
        await pause(2.6)
        guard !Task.isCancelled else { return }
        island.present(.notice(text: IslandSampleText.noticeSuccess, kind: .success))
        await pause(2.6)
    }

    private static func runAll() async {
        let island = Island.shared
        island.present(.activity(symbol: "timer", title: IslandSampleText.focus, detail: "24:13"))
        await pause(2.2)
        guard !Task.isCancelled else { return }
        island.update(.progress(title: IslandSampleText.preparing))
        await pause(1.6)
        for step in 0...10 {
            guard !Task.isCancelled else { return }
            island.update(.progress(title: IslandSampleText.exporting, fraction: Double(step) / 10, symbol: "square.and.arrow.up"))
            await pause(0.18)
        }
        island.update(.done(title: IslandSampleText.saved, detail: IslandSampleText.savedDetail, body: IslandSampleText.savedLong,
                            actions: [IslandAction(id: "reveal", title: IslandSampleText.showInFinder, symbol: "folder") {}]))
        await pause(4.5)
        guard !Task.isCancelled else { return }
        // a plain level meter, then one fed at 30 Hz like a microphone (with the recording dot)
        island.present(.levels([], symbol: "waveform"))
        await pause(2)
        guard !Task.isCancelled else { return }
        island.present(.levels([], symbol: "mic.fill", recording: true))
        let start = Date()
        while Date().timeIntervalSince(start) < 3, !Task.isCancelled {
            let t = Date().timeIntervalSince(start)
            let bands = (0..<7).map { i in Float(max(0, IslandMeterMath.speech(t) * (1 - Double(i) * 0.1))) }
            island.update(.levels(bands, symbol: "mic.fill", recording: true))
            await pause(1.0 / 30)
        }
        island.update(.done(title: IslandSampleText.saved, body: IslandSampleText.savedBody))
        await pause(3.8)
        for (text, kind) in [(IslandSampleText.noticeInfo, IslandNoticeKind.info), (IslandSampleText.noticeSuccess, .success),
                             (IslandSampleText.noticeWarning, .warning), (IslandSampleText.noticeError, .error)] {
            guard !Task.isCancelled else { return }
            island.present(.notice(text: text, kind: kind))
            await pause(3)
        }
        guard !Task.isCancelled else { return }
        // takes longer: seconds from 5 s, the card with Cancel from 10 s (Cancel closes it)
        island.present(.progress(title: IslandSampleText.preparing, cancel: IslandAction(id: "cancel", title: CommonText.cancel) {}))
        await pause(12.5)
        guard !Task.isCancelled else { return }
        island.dismiss()
        await pause(1.2)
    }
}
