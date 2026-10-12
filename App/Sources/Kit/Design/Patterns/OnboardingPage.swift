import SwiftUI

// The onboarding page skeleton (VoiceBud ui/Onboarding.swift: OnboardingCentered, OnboardingPage,
// OnboardingHeader, OnboardingFootnote, the permission step's fixed hint area, OnboardingHero).
// Rhythm: gaps 8 / 12 / 16 / 24 only (Space.xs…l); title 22 bold, body 13, secondary 12 prose.
// Nothing on a page may move when its state changes: changing parts live in fixed slots
// (OnboardingStatusSlot 30 pt, OnboardingHint 560 x 64, OnboardingFootnote(lines:)).

/// Places its one child centred between the titlebar and the footer, lifted by 12 pt, but never
/// closer than 24 pt to the top. Every step uses it (through `OnboardingPage`), so top and bottom
/// gaps balance whatever the step's height.
nonisolated struct OnboardingCentered: Layout {
    var minTop: CGFloat = Metrics.onboardingMinTop
    var lift: CGFloat = Metrics.onboardingLift

    /// The child's top inside an area of `available` height (pure; PatternsTests).
    static func top(content: CGFloat, available: CGFloat, minTop: CGFloat = Metrics.onboardingMinTop,
                    lift: CGFloat = Metrics.onboardingLift) -> CGFloat {
        max(minTop, ((available - content) / 2 - lift).rounded())
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // takes the whole proposed area; without a proposal, just enough for the child at its top
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) }
        let width = proposal.width ?? sizes.map(\.width).max() ?? 0
        let height = proposal.height ?? (sizes.map(\.height).max() ?? 0) + minTop
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            let top = Self.top(content: size.height, available: bounds.height, minTop: minTop, lift: lift)
            view.place(at: CGPoint(x: bounds.midX, y: bounds.minY + top), anchor: .top,
                       proposal: ProposedViewSize(width: bounds.width, height: size.height))
        }
    }
}

/// One onboarding step body: a centred column below the 32 pt titlebar. Put a hero, an
/// `OnboardingHeader`, then the step's card / slot / tiles inside; space blocks with
/// `.padding(.bottom, Space.xs | .s | .m | .l)`.
///
///     OnboardingPage {
///         OnboardingHero(symbol: "globe", tint: .sky).padding(.bottom, Space.m)
///         OnboardingHeader(title: …, subtitle: …).padding(.bottom, Space.l)
///         Card { … }.frame(width: Metrics.onboardingColumn)
///     }
struct OnboardingPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        OnboardingCentered {
            VStack(spacing: 0) { content }
        }
        .padding(.top, Metrics.titlebar)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The whole 720 x 560 onboarding surface: the page area (clipped, where pages slide) above the
/// 68 pt footer, on `windowBg`. The window's titlebar is transparent, so the frame owns the full
/// height (`.ignoresSafeArea()`, VoiceBud OnboardingRootView). Strand D's root view puts its
/// transitions inside `page`; renders wrap it in `StaticWindow(chrome: .onboarding)`.
struct OnboardingFrame<Page: View, Footer: View>: View {
    let page: Page
    let footer: Footer
    @Environment(\.colorScheme) private var scheme

    init(@ViewBuilder page: () -> Page, @ViewBuilder footer: () -> Footer) {
        self.page = page()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack { page }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            footer
        }
        .frame(width: Metrics.onboardingWindow.width, height: Metrics.onboardingWindow.height)
        .background(Theme(scheme).windowBg)
        .ignoresSafeArea()
    }
}

/// Title (22 bold `fg`) and one calm sentence (13 `prose`, line spacing 3), centred, at most the
/// 560 pt column wide, 8 pt between. Use "\n" in the subtitle to break where it reads best.
struct OnboardingHeader: View {
    let title: String
    var subtitle: String?
    /// The welcome step: 28 pt intro title and a 15 pt lede (VoiceBud's only exceptions).
    var large = false
    @Environment(\.colorScheme) private var scheme

    init(title: String, subtitle: String? = nil, large: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.large = large
    }

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: Space.xs) {
            Text(title)
                .font(large ? TypeScale.intro : TypeScale.title)
                .foregroundStyle(t.fg)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(large ? TypeScale.lede : TypeScale.body)
                    .foregroundStyle(t.prose)
                    .multilineTextAlignment(.center)
                    .lineSpacing(TypeScale.proseLineSpacing)
                    .frame(maxWidth: Metrics.onboardingColumn)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One centred 12 pt `prose` line under the header (VoiceBud's "Prefer English? …" on the language
/// step), with `app://` links.
struct OnboardingNote: View {
    let text: String
    var perform: (String) -> Void
    @Environment(\.colorScheme) private var scheme

    init(_ text: String, perform: @escaping (String) -> Void = { _ in }) {
        self.text = text
        self.perform = perform
    }

    var body: some View {
        OnboardingRichText(text, perform: perform)
            .font(TypeScale.secondary)
            .foregroundStyle(Theme(scheme).prose)
            .multilineTextAlignment(.center)
            .lineSpacing(TypeScale.noteLineSpacing)
            .frame(maxWidth: Metrics.onboardingColumn)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 12 pt `prose` note under a card. `lines` reserves room (16 pt per line), so the page never
/// shifts when the text changes; `app://` links work like in `OnboardingRichText`.
struct OnboardingFootnote: View {
    let text: String
    var lines: Int
    var perform: (String) -> Void
    @Environment(\.colorScheme) private var scheme

    init(_ text: String, lines: Int = 1, perform: @escaping (String) -> Void = { _ in }) {
        self.text = text
        self.lines = lines
        self.perform = perform
    }

    var body: some View {
        OnboardingRichText(text, perform: perform)
            .font(TypeScale.secondary)
            .foregroundStyle(Theme(scheme).prose)
            .lineSpacing(TypeScale.noteLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: CGFloat(max(lines, 0)) * Metrics.footnoteLine, alignment: .topLeading)
            .padding(.horizontal, 6)
            .padding(.top, Space.xs)
    }
}

/// The fixed 560 x 64 hint area under a status slot: one or more centred 12 pt `prose` lines
/// (with `app://` links), 8 pt apart. Changing `lines` cross-fades in place; nothing below moves.
/// Pass the slot's `key` so hint and slot change together.
struct OnboardingHint: View {
    let lines: [String]
    var key: String
    var perform: (String) -> Void
    @Environment(\.colorScheme) private var scheme

    init(_ lines: [String], key: String? = nil, perform: @escaping (String) -> Void = { _ in }) {
        self.lines = lines
        self.key = key ?? lines.joined(separator: "\n")
        self.perform = perform
    }

    init(_ line: String, key: String? = nil, perform: @escaping (String) -> Void = { _ in }) {
        self.init([line], key: key, perform: perform)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: Space.xs) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    OnboardingRichText(line, perform: perform)
                }
            }
            .font(TypeScale.secondary)
            .foregroundStyle(Theme(scheme).prose)
            .multilineTextAlignment(.center)
            .lineSpacing(TypeScale.noteLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .id(key)
            .transition(.opacity)
        }
        .frame(width: Metrics.onboardingHint.width, height: Metrics.onboardingHint.height, alignment: .top)
        .animation(Motion.page, value: key)
    }
}

/// The picture at the top of a step: either the 64 pt gradient squircle with a soft shadow
/// (permission and settings-like steps), or a custom art slot (welcome: wallpaper, app icon,
/// a live preview) clipped to `Radius.hero` with a hairline `tileEdge`.
struct OnboardingHero<Art: View>: View {
    private let art: Art?
    private let symbol: String
    private let tint: TintName
    private let size: CGSize
    private let framed: Bool
    @Environment(\.colorScheme) private var scheme

    /// Custom art, by default 672 x 200 with a rounded hairline frame (`framed: false` draws it bare,
    /// e.g. a 72 pt app icon).
    init(size: CGSize = Metrics.heroArt, framed: Bool = true, @ViewBuilder art: () -> Art) {
        self.art = art()
        self.symbol = ""
        self.tint = .accent
        self.size = size
        self.framed = framed
    }

    var body: some View {
        let t = Theme(scheme)
        if let art {
            let shape = RoundedRectangle(cornerRadius: framed ? Radius.hero : 0, style: .continuous)
            art
                .frame(width: size.width, height: size.height)
                .clipShape(shape)
                .overlay { if framed { shape.strokeBorder(t.tileEdge, lineWidth: Metrics.hairline) } }
                .accessibilityHidden(true)
        } else {
            SquircleIcon(symbol: symbol, tint: tint, size: Metrics.squircleLarge)
                .shadow(color: t.heroShadow, radius: 6, y: 3)
        }
    }
}

extension OnboardingHero where Art == EmptyView {
    /// The 64 pt squircle hero.
    init(symbol: String, tint: TintName = .accent) {
        self.art = nil
        self.symbol = symbol
        self.tint = tint
        self.size = CGSize(width: Metrics.squircleLarge, height: Metrics.squircleLarge)
        self.framed = false
    }
}
