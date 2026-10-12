// STUB (S0): texts of the stub onboarding. Strand D owns this file and replaces it.

enum OnboardingText {
    static var windowTitle: String { tr(en: "Set Up \(AppInfo.displayName)", de: "\(AppInfo.displayName) einrichten") }
    static var welcomeTitle: String { tr(en: "Welcome to \(AppInfo.displayName)", de: "Willkommen bei \(AppInfo.displayName)") }
    static var welcomeLede: String {
        tr(en: "A few short steps, then the app is ready.", de: "Ein paar kurze Schritte, dann ist die App bereit.")
    }
    static var start: String { tr(en: "Start", de: "Los geht’s") }
}
