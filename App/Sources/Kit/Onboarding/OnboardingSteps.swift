import SwiftUI

// The kit's own onboarding steps: Welcome (0), Language (10), Features (20), one step per
// permission (300 +), Done (1000). Modules add theirs in between through Registry.onboardingSteps.
// Every page is built from Kit/Design/Patterns (OnboardingPage, OnboardingHeader, …), the layout
// and copy rules of VoiceBud's setup (notes vb-onboarding-hub §2.7).

// MARK: - Welcome

/// The app icon on an accent glow with hairline rings, then the app's name and what it is for.
struct WelcomeStep: View {
    let stepCount: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            OnboardingHero { WelcomeArt() }
                .padding(.top, Metrics.welcomeArtTop)
            Spacer(minLength: 0)
            OnboardingHeader(title: AppInfo.displayName, subtitle: OnboardingText.welcomeLede, large: true)
            Spacer(minLength: 0)
            Text(OnboardingText.welcomeNote(steps: stepCount))
                .font(TypeScale.secondary)
                .foregroundStyle(t.prose)
                .padding(.bottom, Space.m)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The welcome hero (672 x 200): a calm ground, the accent glowing out from the centre, hairline
/// rings and the app icon. Static: nothing animates, so nothing runs while the step is open.
struct WelcomeArt: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        ZStack {
            t.welcomeGround
            RadialGradient(stops: t.welcomeGlow, center: .center, startRadius: 0, endRadius: Metrics.heroArt.width / 2)
            ForEach(0..<Metrics.welcomeRingCount, id: \.self) { ring in
                let diameter = 2 * (Metrics.welcomeRingFirst + CGFloat(ring) * Metrics.welcomeRingGap)
                Circle()
                    .strokeBorder(t.welcomeRing, lineWidth: Metrics.hairline)
                    .frame(width: diameter, height: diameter)
                    .opacity(1 - Double(ring) / Double(Metrics.welcomeRingCount))
            }
            AppIconImage(size: Metrics.welcomeIcon)
                .shadow(color: t.welcomeIconShadow, radius: Metrics.welcomeIconShadowRadius, y: Metrics.welcomeIconShadowY)
        }
        .frame(width: Metrics.heroArt.width, height: Metrics.heroArt.height)
    }
}

/// The app icon (`AppIcon.icns` from the bundle), or the accent squircle with `app.symbol` while
/// no icon exists yet. Loaded by the view that shows it and released with it (VoiceBud).
struct AppIconImage: View {
    let size: CGFloat
    @State private var icon = AppInfo.icon()

    var body: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            // an icon file draws its body at 824 of 1024 px; match that so both sit the same
            SquircleIcon(symbol: AppInfo.symbol, tint: .accent, size: (size * 824 / 1024).rounded())
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Language

/// App language: English or German, or the Mac's, switching live (VoiceBud's second step).
struct LanguageStep: View {
    /// Renders: fixed "same as the Mac" state instead of the real setting.
    var previewFollowsMac: Bool?
    private let localizer = Localizer.shared

    var body: some View {
        let language = Binding(get: { localizer.lang }, set: { localizer.choice = $0 })
        let follows = Binding(get: { previewFollowsMac ?? (localizer.choice == nil) },
                              set: { localizer.choice = $0 ? nil : localizer.lang })
        let system = previewFollowsMac == nil ? localizer.system : localizer.lang
        OnboardingPage {
            OnboardingHero(symbol: "globe", tint: .sky).padding(.bottom, Space.m)
            OnboardingHeader(title: OnboardingText.languageTitle, subtitle: OnboardingText.languageSubtitle)
                .padding(.bottom, Space.xs)
            OnboardingNote(OnboardingText.languageCrossHint).padding(.bottom, Space.l)
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(tone: .onboarding) {
                    // each language in its own name, so it can be found in either language
                    PickerRow(OnboardingText.languageApp, subtitle: OnboardingText.languageAppDetail,
                              options: Lang.allCases.map { ($0, $0.nativeName) }, selection: language)
                    ToggleRow(OnboardingText.followMac, subtitle: OnboardingText.followMacDetail(OnboardingText.languageName(system)),
                              isOn: follows)
                }
                OnboardingFootnote(OnboardingText.languageFootnote, lines: 2)
            }
            .frame(width: Metrics.onboardingCard)
        }
    }
}

// MARK: - Features

/// Up to three things the app does (`OnboardingFeatures`), as rows in one card.
struct FeaturesStep: View {
    let features: [OnboardingFeature]

    var body: some View {
        OnboardingPage {
            OnboardingHero(symbol: AppInfo.symbol, tint: .accent).padding(.bottom, Space.m)
            OnboardingHeader(title: OnboardingText.featuresTitle).padding(.bottom, Space.l)
            SettingsSection(tone: .onboarding) {
                ForEach(features) { FeatureRow(feature: $0) }
            }
            .frame(width: Metrics.onboardingColumn)
        }
    }
}

struct FeatureRow: View {
    let feature: OnboardingFeature
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        HStack(alignment: .center, spacing: Space.s) {
            SquircleIcon(symbol: feature.symbol, tint: feature.tint, size: Metrics.featureIcon)
            VStack(alignment: .leading, spacing: Space.hair) {
                Text(feature.title()).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
                Text(feature.detail())
                    .font(TypeScale.secondary)
                    .foregroundStyle(t.prose)
                    .lineSpacing(TypeScale.noteLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Space.s)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Permission

/// One permission (VoiceBud's permission page): squircle, why, a 30 pt slot that changes in
/// place and the 64 pt hint under it. Polls the status once a second while visible.
struct PermissionStep: View {
    let kind: PermissionKind
    /// "Restart <App>" in the slot (persists the step first, then relaunches).
    var restart: () -> Void = {}
    @Environment(\.permissionMonitor) private var monitor
    @Environment(\.renderStatic) private var renderStatic

    var body: some View {
        let status = monitor.status(kind)
        let slot = Self.slot(for: kind, status: status, monitor: monitor, restart: restart)
        OnboardingPage {
            OnboardingHero(symbol: kind.symbol, tint: kind.tint).padding(.bottom, Space.m)
            OnboardingHeader(title: PermissionText.title(kind), subtitle: PermissionsKit.why(kind))
                .padding(.bottom, Space.l)
            OnboardingStatusSlot(slot).padding(.bottom, Space.s)
            OnboardingHint(PermissionText.hint(kind, status), key: slot.key) { action in
                if action == "reveal" { monitor.revealApp() }
            }
        }
        .task(id: kind) {
            guard !renderStatic else { return }
            await monitor.watch([kind])
        }
    }

    /// What the slot shows for a status (VoiceBud OnboardingPermissionStep.slot).
    static func slot(for kind: PermissionKind, status: PermissionStatus, monitor: PermissionMonitor,
                     restart: @escaping () -> Void) -> OnboardingSlotState {
        let openSettings = OnboardingSlotState.SlotButton.openSettings { monitor.openSettings(kind) }
        switch status {
        case .missing:
            return .action { monitor.request(kind) }
        case .requested:
            // a dialog is on screen: nothing to click here; a switch: the way to it
            return .waiting(PermissionText.waiting(kind), button: kind.prompt == .settingsSwitch ? openSettings : nil)
        case .denied:
            return .denied(button: openSettings)
        case .granted:
            return .granted()
        case .restartNeeded:
            return .restartNeeded(restart: restart)
        }
    }
}

// MARK: - Done

/// What is set up (language, permissions), where Settings are, and "Done".
struct DoneStep: View {
    let permissions: [PermissionKind]
    var previewFollowsMac: Bool?
    @Environment(\.permissionMonitor) private var monitor
    @Environment(\.renderStatic) private var renderStatic
    private let localizer = Localizer.shared

    /// More than this many permissions collapse into one "x of y allowed" row.
    static let permissionRowLimit = 3

    var body: some View {
        let restartPending = permissions.contains { monitor.status($0) == .restartNeeded }
        OnboardingPage {
            DoneIcon().padding(.bottom, Space.m)
            OnboardingHeader(title: OnboardingText.doneTitle, subtitle: OnboardingText.doneSubtitle)
                .padding(.bottom, Space.l)
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(tone: .onboarding) {
                    ValueRow(OnboardingText.doneLanguage, symbol: "globe", tint: .sky, value: languageValue)
                    if permissions.count <= Self.permissionRowLimit {
                        ForEach(permissions, id: \.self) { kind in
                            let status = monitor.status(kind)
                            Row(PermissionText.title(kind), symbol: kind.symbol, tint: kind.tint, tone: .onboarding) {
                                StatusMark(Self.mark(status), PermissionText.short(status))
                            }
                        }
                    } else {
                        let allowed = permissions.filter { monitor.status($0).isAllowed }.count
                        Row(OnboardingText.donePermissionsTitle, symbol: "lock.fill", tint: .blue, tone: .onboarding) {
                            StatusMark(allowed == permissions.count ? .ok : .warn,
                                       OnboardingText.donePermissions(granted: allowed, of: permissions.count))
                        }
                    }
                    if AppInfo.isEnabled("window") {
                        Row(OnboardingText.doneSettings, subtitle: OnboardingText.doneSettingsWindow, symbol: "gearshape.fill",
                            tint: .graphite, tone: .onboarding) {
                            KeyCaps(["⌘", ","])
                        }
                    } else {
                        Row(OnboardingText.doneSettings, subtitle: OnboardingText.doneSettingsMenuBar, symbol: "gearshape.fill",
                            tint: .graphite, tone: .onboarding)
                    }
                }
                OnboardingFootnote(restartPending ? OnboardingText.doneRestartNote : OnboardingText.doneFootnote, lines: 2)
            }
            .frame(width: Metrics.onboardingCard)
        }
        .task {
            guard !renderStatic else { return }
            await monitor.refresh(permissions)
        }
    }

    private var languageValue: String {
        let follows = previewFollowsMac ?? (localizer.choice == nil)
        return OnboardingText.doneLanguageValue(OnboardingText.languageName(localizer.lang), followsMac: follows)
    }

    static func mark(_ status: PermissionStatus) -> StatusMark.Kind {
        switch status {
        case .granted: .ok
        case .restartNeeded, .denied: .warn
        case .missing, .requested: .idle
        }
    }
}

/// The app icon with an accent check badge cut out of the window background (VoiceBud finish).
struct DoneIcon: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        AppIconImage(size: Metrics.doneIcon)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(t.accent)
                    .overlay {
                        Image(systemName: "checkmark")
                            .symbolFont(Metrics.doneBadgeGlyph, weight: .heavy)
                            .foregroundStyle(t.onAccent)
                    }
                    .frame(width: Metrics.doneBadge, height: Metrics.doneBadge)
                    .background(Circle().fill(t.windowBg).padding(-Metrics.doneBadgeCut))
                    .offset(x: -Metrics.doneBadgeInset, y: -Metrics.doneBadgeInset)
            }
            .accessibilityHidden(true)
    }
}
