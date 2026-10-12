import SwiftUI

/// The onboarding footer (VoiceBud OnboardingFooter): Back on the left (hidden on the first step),
/// the segmented step progress centred, Continue on the right; 68 pt high, 24 pt side padding.
/// One primary button per screen: while the step's own slot holds the primary action (a missing
/// permission), pass `advanceIsPrimary: false` and Continue turns secondary and gives up Return.
struct OnboardingFooter: View {
    let count: Int
    let index: Int
    var advanceTitle: String
    var advanceIsPrimary: Bool
    var canAdvance: Bool
    /// nil hides Back (first step).
    var back: (() -> Void)?
    let advance: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(count: Int, index: Int, advanceTitle: String = CommonText.continue, advanceIsPrimary: Bool = true,
         canAdvance: Bool = true, back: (() -> Void)?, advance: @escaping () -> Void) {
        self.count = count
        self.index = index
        self.advanceTitle = advanceTitle
        self.advanceIsPrimary = advanceIsPrimary
        self.canAdvance = canAdvance
        self.back = back
        self.advance = advance
    }

    var body: some View {
        ZStack {
            if count > 1 { SegmentedProgress(count: count, current: index) }
            HStack(spacing: 0) {
                if let back {
                    Button(CommonText.back, action: back)
                        .buttonStyle(.secondary)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                // Return goes to the one primary button: here, or the step's own slot
                Button(advanceTitle, action: advance)
                    .buttonStyle(.primary(advanceIsPrimary, minWidth: Metrics.buttonWideMinWidth))
                    .keyboardShortcut(advanceIsPrimary ? .defaultAction : nil)
                    .disabled(!canAdvance)
            }
        }
        .padding(.horizontal, Space.l)
        .frame(height: Metrics.onboardingFooter)
        .animation(Motion.adaptive(Motion.page, reduce: reduceMotion), value: back == nil)
    }
}
