import SwiftUI

/// The welcome art of the setup while the island module is built (VoiceBud's welcome hero): the
/// top of a screen with menu bar and notch, and the real island growing out of the notch, working,
/// turning into its result card and folding back. Renders and Reduce Motion show the card still.
/// A feature picks the take the island plays by setting `working` and `result` in its `register()`.
enum IslandWelcome {
    /// What the island shows while it works: the app's symbol with a spinner.
    static var working: () -> IslandContent = { IslandStyleTile.content }
    /// The card it turns into.
    static var result: () -> IslandContent = {
        .done(title: IslandText.welcomeTitle, detail: AppInfo.displayName, body: IslandText.welcomeBody)
    }

    static func register() {
        Registry.welcomeArt = { AnyView(IslandWelcomeArt()) }
    }
}

struct IslandWelcomeArt: View {
    @State private var driver = IslandWelcomeDriver(still: RenderMode.isStatic)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            IslandBackdrop(notch: driver.model.notch)
            IslandWelcomeMenuBar()
            IslandView(model: driver.model)
        }
        .frame(width: Metrics.heroArt.width, height: Metrics.heroArt.height)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IslandText.welcomeArtLabel)
        // runs only while the step is on screen; cancelled when it goes away
        .task(id: reduceMotion) {
            guard !RenderMode.isStatic else { return }
            if reduceMotion {
                driver.showStill()
            } else {
                await driver.loop()
            }
        }
    }
}

/// The menu bar on both sides of the island: the app's name on the left, Wi-Fi and the clock on
/// the right, as on a MacBook. The middle stays free for the whole result card.
private struct IslandWelcomeMenuBar: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: 0) {
            Text(AppInfo.displayName)
                .font(TypeScale.bodySemibold)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: Metrics.Island.doneWidth)
            HStack(spacing: Space.m) {
                Image(systemName: "wifi")
                Text(Format.time(IslandWelcomeDriver.clock)).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(TypeScale.bodyMedium)
        .foregroundStyle(t.menuBarText)
        .padding(.horizontal, Space.m)
        .frame(height: Metrics.Island.renderMenuBar)
        .accessibilityHidden(true)
    }
}

/// Plays the take in a loop on its own island model (never on `Island.shared`).
@Observable final class IslandWelcomeDriver {
    let model: IslandModel

    /// 9:41 today, the clock of every Mac in a picture.
    static var clock: Date { Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date()) ?? Date() }

    init(still: Bool) {
        model = IslandPreviewModel.make(still ? IslandWelcome.result() : nil, kind: .notch, canvas: Metrics.heroArt, still: still)
    }

    /// Reduce Motion: the result card, without growing or folding.
    func showStill() {
        withAnimation(Motion.Island.crossFade) {
            model.reduceMotion = true
            model.contentSwap = true
            model.content = IslandWelcome.result()
            model.presented = true
        }
    }

    /// Closed notch, the island grows with the working content, turns into the card, holds it,
    /// folds back into the notch; again until the task is cancelled.
    func loop() async {
        quietly {
            model.reduceMotion = false
            model.presented = false
            model.contentSwap = false
        }
        while !Task.isCancelled {
            guard await pause(IslandWelcomeTiming.closed) else { return }
            quietly {
                model.contentSwap = false
                model.content = IslandWelcome.working()
            }
            // the island's own springs grow it, as in the app
            model.presented = true
            guard await pause(IslandTiming.swapAfter) else { return }
            quietly { model.contentSwap = true }
            guard await pause(IslandWelcomeTiming.working) else { return }
            model.content = IslandWelcome.result()
            guard await pause(IslandWelcomeTiming.result) else { return }
            quietly { model.contentSwap = false }
            guard await pause(IslandTiming.collapseDelay) else { return }
            model.presented = false
        }
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    private func quietly(_ body: () -> Void) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet, body)
    }
}

/// The beats of the welcome take, in seconds.
enum IslandWelcomeTiming {
    static let closed: Double = 1.2
    static let working: Double = 1.8
    static let result: Double = 3.4
}
