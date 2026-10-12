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
        let offered = previewFollowsMac != nil || OnboardingKit.macLanguageOffered()
        OnboardingPage {
            OnboardingHero(symbol: DoneStep.languageSymbol, tint: .sky).padding(.bottom, Space.m)
            OnboardingHeader(title: OnboardingText.languageTitle, subtitle: OnboardingText.languageSubtitle)
                .padding(.bottom, Space.xs)
            OnboardingNote(OnboardingText.languageCrossHint).padding(.bottom, Space.l)
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(tone: .onboarding) {
                    // each language in its own name, so it can be found in either language
                    PickerRow(OnboardingText.languageApp, subtitle: OnboardingText.languageAppDetail,
                              options: Lang.allCases.map { ($0, $0.nativeName) }, selection: language)
                    ToggleRow(OnboardingText.followMac,
                              subtitle: OnboardingText.followMacDetail(OnboardingText.languageName(system), offered: offered),
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
    /// Runs before anything that can end in a restart: a restart kind's request or its System
    /// Settings pane (macOS offers "Quit & Reopen" there), so the setup comes back at this step.
    var willLeaveForRestart: () -> Void = {}
    @Environment(\.permissionMonitor) private var monitor
    @Environment(\.renderStatic) private var renderStatic
    /// A dialog has been waiting longer than `answerPatience`: offer System Settings as a way out.
    @State private var waitedLong = false

    /// Seconds a dialog may stay unanswered before the slot offers System Settings.
    static let answerPatience: Double = 5

    var body: some View {
        let status = monitor.status(kind)
        let slot = Self.slot(for: kind, status: status, monitor: monitor, waitedLong: waitedLong,
                             willLeaveForRestart: willLeaveForRestart, restart: restart)
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
            // shown again: a dialog asked earlier and never answered offers "Allow Access" again
            monitor.forgetRequest(kind)
            await monitor.watch([kind])
        }
        .task(id: status) {
            waitedLong = false
            guard !renderStatic, status == .requested, kind.prompt == .dialog else { return }
            try? await Task.sleep(for: .seconds(Self.answerPatience))
            if !Task.isCancelled { waitedLong = true }
        }
    }

    /// What the slot shows for a status (VoiceBud OnboardingPermissionStep.slot).
    static func slot(for kind: PermissionKind, status: PermissionStatus, monitor: PermissionMonitor,
                     waitedLong: Bool = false, willLeaveForRestart: @escaping () -> Void = {},
                     restart: @escaping () -> Void) -> OnboardingSlotState {
        let prepare = { if kind.needsRestart { willLeaveForRestart() } }
        let openSettings = OnboardingSlotState.SlotButton.openSettings {
            prepare()
            monitor.openSettings(kind)
        }
        switch status {
        case .missing:
            return .action {
                prepare()
                monitor.request(kind)
            }
        case .requested:
            // a dialog is on screen: nothing to click (unless it stays unanswered); a switch: the way to it
            let button = kind.prompt == .settingsSwitch || waitedLong ? openSettings : nil
            return .waiting(PermissionText.waiting(kind), button: button)
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

/// What is set up (language, permissions), where Settings are, and "Done". While a permission is
/// not allowed the page says so ("Almost Done") and its row leads back to its step.
struct DoneStep: View {
    let permissions: [PermissionKind]
    var previewFollowsMac: Bool?
    @Environment(\.permissionMonitor) private var monitor
    @Environment(\.renderStatic) private var renderStatic
    @Environment(\.onboardingGoTo) private var goTo
    @Environment(\.colorScheme) private var scheme
    private let localizer = Localizer.shared

    /// Filled like the other row glyphs (the outline globe looked thin next to them).
    static let languageSymbol = "globe.europe.africa.fill"

    /// More than this many permissions collapse into one "x of y allowed" row.
    static let permissionRowLimit = 3

    var body: some View {
        let notAllowed = permissions.filter { !monitor.status($0).isAllowed }
        let restartPending = permissions.contains { monitor.status($0) == .restartNeeded }
        let collapsed = permissions.count > Self.permissionRowLimit
        OnboardingPage {
            DoneIcon().padding(.bottom, Space.m)
            OnboardingHeader(title: OnboardingText.doneTitle(complete: notAllowed.isEmpty),
                             subtitle: notAllowed.isEmpty ? OnboardingText.doneSubtitle
                                 : OnboardingText.doneMissing(notAllowed.map(PermissionText.title), collapsed: collapsed))
                .padding(.bottom, Space.l)
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(tone: .onboarding) {
                    ValueRow(OnboardingText.doneLanguage, symbol: Self.languageSymbol, tint: .sky, value: languageValue)
                    if !collapsed {
                        ForEach(permissions, id: \.self) { kind in
                            let status = monitor.status(kind)
                            permissionRow(PermissionText.title(kind), symbol: kind.symbol, tint: kind.tint, mark: Self.mark(status),
                                          text: PermissionText.short(status), back: status.isAllowed ? nil : kind)
                        }
                    } else {
                        let allowed = permissions.count - notAllowed.count
                        permissionRow(OnboardingText.donePermissionsTitle, symbol: "lock.fill", tint: .blue,
                                      mark: notAllowed.isEmpty ? .ok : .warn,
                                      text: OnboardingText.donePermissions(granted: allowed, of: permissions.count),
                                      back: notAllowed.first)
                    }
                    if AppInfo.isEnabled("window") {
                        Row(OnboardingText.doneSettings, subtitle: OnboardingText.doneSettingsWindow, symbol: "gearshape.fill",
                            tint: .graphite, tone: .onboarding) {
                            KeyCaps(["⌘,"])   // one cap: a lone comma cap reads as a speck
                        }
                    } else {
                        Row(OnboardingText.doneSettings, subtitle: OnboardingText.doneSettingsMenuBar, symbol: "gearshape.fill",
                            tint: .graphite, tone: .onboarding)
                    }
                }
                OnboardingFootnote(restartPending ? OnboardingText.doneRestartNote : OnboardingText.doneFootnote, lines: 1)
            }
            .frame(width: Metrics.onboardingCard)
        }
        .task {
            guard !renderStatic else { return }
            await monitor.refresh(permissions)
        }
    }

    /// A permission row; with `back` the whole row leads to that permission's step.
    @ViewBuilder
    private func permissionRow(_ title: String, symbol: String, tint: TintName, mark: StatusMark.Kind, text: String,
                               back kind: PermissionKind?) -> some View {
        if let kind, let goTo {
            HoverButton { goTo(OnboardingKit.StepID.permission(kind)) } label: {
                Row(title, symbol: symbol, tint: tint, tone: .onboarding) {
                    HStack(spacing: Space.xs) {
                        StatusMark(mark, text)
                        Image(systemName: "chevron.right")
                            .font(TypeScale.caption.weight(.semibold))
                            .foregroundStyle(Theme(scheme).fg3)
                    }
                }
            }
        } else {
            Row(title, symbol: symbol, tint: tint, tone: .onboarding) { StatusMark(mark, text) }
        }
    }

    private var languageValue: String {
        let follows = previewFollowsMac ?? (localizer.choice == nil)
        let offered = previewFollowsMac != nil || OnboardingKit.macLanguageOffered()
        return OnboardingText.doneLanguageValue(OnboardingText.languageName(localizer.lang), sameAsMac: follows && offered)
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
