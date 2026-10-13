import SwiftUI

// Sizes the hotkeys views need on top of Kit/Design (VoiceBud OnboardingBigKeys and the hub's
// shortcut row). Kept in the module, like Kit/Design/Patterns/PatternTokens.swift; candidates for
// Kit/Design if another module needs large key caps.

extension Metrics {
    enum Hotkeys {
        /// One large key cap on the onboarding step (VoiceBud 62 x 56).
        static let bigKey = CGSize(width: 62, height: 56)
        /// Glyph size on a large key cap, and the height of its glyph line.
        static let bigKeyGlyph: CGFloat = 19
        static let bigKeyGlyphLine: CGFloat = 22
        /// Gap between glyph and word on a large key cap.
        static let bigKeyWordGap: CGFloat = 5
        /// The key's visible depth below it, and how far a pressed key sinks.
        static let bigKeyDepth: CGFloat = 2.5
        static let bigKeyDepthPressed: CGFloat = 1
        static let bigKeyPress: CGFloat = 1.5
        /// Ring around the caps being recorded (VoiceBud padding 3, line 1).
        static let recordingRingInset: CGFloat = 3
        static let recordingRingLine: CGFloat = 1
        /// The "Press keys …" placeholder while recording.
        static let recordingPlaceholderHeight: CGFloat = 22
        /// Height the onboarding step's card and footnote count with when the page is centred
        /// (the row with a two-line footnote). A refusal makes the row taller below it, into the
        /// free space under the centred page, so nothing above moves.
        static let stepCardArea: CGFloat = 110
    }
}

extension Space {
    /// Between the chips and caps of a shortcut row (VoiceBud 6).
    static let shortcutRowGap: CGFloat = 6
    /// Inside the "Press keys …" placeholder.
    static let recordingPlaceholderX: CGFloat = 8
}

extension TypeScale {
    /// The word under a modifier glyph on a large key cap ("ctrl", "shift").
    static let keyWord = Font.system(size: 9.5, weight: .medium)   // design-ausnahme: module token for the large key caps (VoiceBud OnboardingBigKeys), Kit candidate
    /// A letter or number on a large key cap (VoiceBud 19 x 0.95).
    static let keyLetter = Font.system(size: 18)   // design-ausnahme: module token for the large key caps (VoiceBud OnboardingBigKeys), Kit candidate
}
