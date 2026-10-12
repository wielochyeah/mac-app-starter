import Foundation

/// Plays every island state on the real island: `--demo` (or `--demo island`) loops it for the
/// lead's manual check; the settings pane's "Show Preview" plays it once. Never run by tests or
/// renders (it puts a window on screen).
enum IslandDemo {
    private static var task: Task<Void, Never>?

    /// True when `--demo` names no area or names "island".
    static func wanted(_ arguments: [String] = CommandLine.arguments) -> Bool {
        guard let i = arguments.firstIndex(of: "--demo") else { return false }
        let areas = arguments[(i + 1)...].prefix { !$0.hasPrefix("-") }
        return areas.isEmpty || areas.contains("island")
    }

    static func play(loop: Bool) {
        task?.cancel()
        task = Task { @MainActor in
            repeat {
                await runOnce()
            } while loop && !Task.isCancelled
            if !Task.isCancelled { Island.shared.dismiss() }
        }
    }

    static func stop() {
        task?.cancel()
        task = nil
        Island.shared.dismiss()
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private static func runOnce() async {
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
        // a level meter fed at 30 Hz, like a microphone
        island.present(.levels([], symbol: "mic.fill"))
        let start = Date()
        while Date().timeIntervalSince(start) < 3, !Task.isCancelled {
            let t = Date().timeIntervalSince(start)
            let bands = (0..<7).map { i in Float(max(0, IslandMeterMath.speech(t) * (1 - Double(i) * 0.1))) }
            island.update(.levels(bands, symbol: "mic.fill"))
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
        // takes longer: seconds from 5 s, the card with Cancel from 10 s
        island.present(.progress(title: IslandSampleText.preparing,
                                 cancel: IslandAction(id: "cancel", title: CommonText.cancel) { Island.shared.dismiss() }))
        await pause(12.5)
        guard !Task.isCancelled else { return }
        island.dismiss()
        await pause(1.2)
    }
}
