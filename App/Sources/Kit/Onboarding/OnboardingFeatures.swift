/// One card on the onboarding's "What <App> does" step.
struct OnboardingFeature: Identifiable {
    let id: String
    let order: Int
    let symbol: String
    var tint: TintName = .accent
    let title: () -> String
    let detail: () -> String
}

/// Features shown on the onboarding's features step (order 20). Modules and project features add
/// theirs in `register()`; the step shows the first three by order and is skipped when empty.
///
///     OnboardingFeatures.items.append(OnboardingFeature(id: "notes.search", order: 10, symbol: "magnifyingglass",
///         title: { NotesText.searchTitle }, detail: { NotesText.searchDetail }))
enum OnboardingFeatures {
    static var items: [OnboardingFeature] = []
    /// At most this many are shown (a fourth would push the footer off the page).
    static let limit = 3

    static var shown: [OnboardingFeature] { pick(items) }

    static func pick(_ items: [OnboardingFeature]) -> [OnboardingFeature] {
        Array(items.sorted { ($0.order, $0.id) < ($1.order, $1.id) }.prefix(limit))
    }
}
