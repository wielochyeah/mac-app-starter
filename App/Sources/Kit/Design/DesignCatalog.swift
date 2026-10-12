import SwiftUI

/// Registers every design component as a gallery entry and a `design.<name>` render scene, then the
/// patterns (`patterns.<name>`).
enum DesignKit {
    static func register() {
        for item in catalog {
            Registry.gallery.append(GalleryEntry(id: "design.\(item.id)", area: "design", title: item.title, content: item.view))
            Registry.renderScenes.append(RenderScene(id: "design.\(item.id)", size: item.size) {
                AnyView(item.specimen ? AnyView(Specimen(width: item.width) { item.view() }) : item.view())
            })
        }
        // Composed building blocks (Kit/Design/Patterns) and the composed samples
        // (patterns.sample-pane / patterns.sample-step replace the former design.sample-* scenes).
        PatternsKit.register()
    }

    private struct Item {
        let id: String
        let title: () -> String
        var size: CGSize = .zero
        /// false: the view brings its own background and size.
        var specimen = true
        var width: CGFloat = 520
        let view: () -> AnyView
    }

    private static var catalog: [Item] {
        [
            Item(id: "tokens", title: { DesignText.tokens }) { AnyView(TokenSwatches()) },
            Item(id: "type", title: { DesignText.type }) { AnyView(TypeSamples()) },
            Item(id: "accents", title: { DesignText.accents }, width: 680) { AnyView(AccentSamples()) },
            Item(id: "buttons", title: { DesignText.buttons }) { AnyView(ButtonSamples()) },
            Item(id: "card", title: { DesignText.card }) { AnyView(CardSample()) },
            Item(id: "row", title: { DesignText.row }) { AnyView(RowSamples()) },
            Item(id: "group-label", title: { DesignText.groupLabel }) { AnyView(GroupLabelSample()) },
            Item(id: "separator", title: { DesignText.separator }) { AnyView(SeparatorSample()) },
            Item(id: "footnote", title: { DesignText.footnote }) { AnyView(FootnoteSample()) },
            Item(id: "switch", title: { DesignText.switchToggle }) { AnyView(SwitchSamples()) },
            Item(id: "segmented", title: { DesignText.segmented }) { AnyView(SegmentedSamples()) },
            Item(id: "chip", title: { DesignText.chip }) { AnyView(ChipSamples()) },
            Item(id: "badge", title: { DesignText.badge }) { AnyView(BadgeSamples()) },
            Item(id: "squircle", title: { DesignText.squircle }) { AnyView(SquircleSamples()) },
            Item(id: "keycaps", title: { DesignText.keyCaps }) { AnyView(KeyCapSamples()) },
            Item(id: "progress", title: { DesignText.progress }) { AnyView(ProgressSamples()) },
            Item(id: "spinner", title: { DesignText.spinner }) { AnyView(SpinnerSamples()) },
            Item(id: "status", title: { DesignText.statusMark }) { AnyView(StatusSamples()) },
            Item(id: "empty-state", title: { DesignText.emptyState }) { AnyView(EmptyStateSample()) },
            Item(id: "section-header", title: { DesignText.sectionHeader }) { AnyView(SectionHeaderSample()) },
            Item(id: "glass", title: { DesignText.glass }) { AnyView(GlassSample()) },
            Item(id: "island", title: { DesignText.island }) { AnyView(IslandSample()) },
        ]
    }
}

// MARK: - Specimens (sample state is fixed so renders are deterministic)

// Token and type-scale labels below are code identifiers ("fg2", "paneTitle 15.5"), shown
// verbatim in monospace on purpose: they name the API, they are not UI copy (S0.md, exception
// for scripts/check_texts.py). Everything a person reads goes through DesignText.

private struct TokenSwatches: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let tokens: [(String, Color)] = [
            ("windowBg", t.windowBg), ("card", t.card), ("fg", t.fg), ("fg2", t.fg2), ("fg3", t.fg3),
            ("prose", t.prose), ("accent", t.accent), ("accentText", t.accentText), ("ring", t.ring),
            ("switchOff", t.switchOff), ("trackOff", t.trackOff), ("field", t.field), ("chip", t.chip),
            ("ok", t.ok), ("warn", t.warn), ("strike", t.strike),
        ]
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s), count: 4), alignment: .leading, spacing: Space.s) {
            ForEach(tokens, id: \.0) { name, color in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .fill(color)
                        .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).strokeBorder(t.cardStroke, lineWidth: Metrics.hairline))
                        .frame(height: 40)
                    Text(verbatim: name).font(TypeScale.caption.monospaced()).foregroundStyle(t.fg2)
                }
            }
        }
    }
}

private struct TypeSamples: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let rows: [(String, Font)] = [
            ("display 34", TypeScale.display), ("intro 28", TypeScale.intro), ("title 22", TypeScale.title),
            ("headline 17", TypeScale.headline), ("paneTitle 15.5", TypeScale.paneTitle), ("lede 15", TypeScale.lede),
            ("body 13", TypeScale.body), ("groupLabel 12.5", TypeScale.groupLabel), ("secondary 12", TypeScale.secondary),
            ("subtitle 11.5", TypeScale.subtitle), ("caption 11", TypeScale.caption), ("badge 10.5", TypeScale.badge),
        ]
        VStack(alignment: .leading, spacing: Space.xs) {
            ForEach(rows, id: \.0) { name, font in
                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                    Text(verbatim: name).font(TypeScale.caption.monospaced()).foregroundStyle(t.fg3).frame(width: 110, alignment: .leading)
                    Text(DesignText.typeSample).font(font).foregroundStyle(t.fg).lineLimit(1)
                }
            }
        }
    }
}

private struct AccentSamples: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ForEach(AccentName.allCases, id: \.self) { accent in
                let t = Theme(scheme, accent: accent)
                HStack(spacing: Space.s) {
                    Text(DesignText.accentName(accent)).font(TypeScale.caption).foregroundStyle(t.fg2).frame(width: 60, alignment: .leading)
                    Capsule().fill(t.accent).frame(width: 36, height: 21)
                    Text(CommonText.continue).font(TypeScale.bodySemibold).foregroundStyle(t.onAccent)
                        .padding(.horizontal, Space.m).frame(height: Metrics.buttonHeight)
                        .background(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).fill(t.accent))
                    Text(DesignText.recommended).font(TypeScale.badge).foregroundStyle(t.accentText)
                        .padding(.horizontal, 6).frame(height: Metrics.badgeHeight).background(Capsule().fill(t.accentSoft))
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(t.ring, lineWidth: 2.5).frame(width: 40, height: 24)
                    Text(DesignText.typeSample).font(TypeScale.body).foregroundStyle(t.accentText).lineLimit(1).fixedSize()
                }
            }
        }
    }
}

private struct ButtonSamples: View {
    var body: some View {
        HStack(spacing: Space.s) {
            Button(CommonText.back) {}.buttonStyle(.secondary)
            Button(CommonText.continue) {}.buttonStyle(.primary(minWidth: Metrics.buttonWideMinWidth))
            Button(CommonText.continue) {}.buttonStyle(.primary).disabled(true)
        }
    }
}

private struct CardSample: View {
    @State private var on = true

    var body: some View {
        Card {
            Row(DesignText.openAtLogin, subtitle: DesignText.openAtLoginDetail) { SwitchToggle(isOn: $on) }
            Separator()
            Row(DesignText.sounds) { SwitchToggle(isOn: .constant(false)) }
        }
    }
}

private struct RowSamples: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        Card {
            Row(DesignText.general, symbol: "gearshape.fill", tint: .graphite) { KeyCaps(["⌘", ","]) }
            Separator()
            Row(DesignText.openAtLogin, subtitle: DesignText.openAtLoginDetail) { Chip(CommonText.change) {} }
            Separator()
            Row(DesignText.ready, dot: t.ok) { Badge(DesignText.new) }
            Separator()
            Row(DesignText.failed, subtitle: DesignText.notAllowed, subtitleColor: t.strike) { Chip(CommonText.retry, symbol: "arrow.clockwise") {} }
        }
    }
}

private struct GroupLabelSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupLabel(DesignText.language)
            Card { Row(DesignText.interface) }
            GroupLabel(DesignText.behavior, top: Space.pane)
            Card { Row(DesignText.sounds) }
        }
    }
}

private struct SeparatorSample: View {
    var body: some View {
        Card {
            Row(DesignText.interface)
            Separator()
            Row(DesignText.sounds)
            Separator(inset: Space.rowX)
            Row(DesignText.openAtLogin)
        }
    }
}

private struct FootnoteSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Card { Row(DesignText.interface) }
            Footnote(DesignText.footnoteSample)
        }
    }
}

private struct SwitchSamples: View {
    var body: some View {
        HStack(spacing: Space.l) {
            SwitchToggle(isOn: .constant(true))
            SwitchToggle(isOn: .constant(false))
            SwitchToggle(isOn: .constant(true)).disabled(true)
        }
    }
}

private struct SegmentedSamples: View {
    @State private var lang = "system"
    @State private var pick = 1

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Segmented([("system", CommonText.systemLanguage), ("de", Lang.de.nativeName), ("en", Lang.en.nativeName)], selection: $lang)
            Segmented([(1, CommonText.on), (2, CommonText.off)], selection: $pick)
        }
    }
}

private struct ChipSamples: View {
    var body: some View {
        HStack(spacing: Space.xs) {
            Chip(CommonText.copy, symbol: "doc.on.doc") {}
            Chip(CommonText.copied, symbol: "checkmark", active: true) {}
            Chip(CommonText.reset) {}
            Chip(CommonText.change) {}
        }
    }
}

private struct BadgeSamples: View {
    var body: some View {
        HStack(spacing: Space.xs) {
            Badge(DesignText.recommended)
            Badge(DesignText.ready, tone: .ok)
            Badge(DesignText.waiting, tone: .warn)
            Badge(DesignText.new, tone: .neutral)
        }
    }
}

private struct SquircleSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                ForEach(TintName.allCases, id: \.self) { tint in
                    SquircleIcon(symbol: Self.symbol(tint), tint: tint)
                }
            }
            HStack(spacing: Space.m) {
                SquircleIcon(symbol: AppInfo.symbol, tint: .accent, size: Metrics.squircleLarge)
                SquircleIcon(symbol: "mic.fill", tint: .orange, size: Metrics.squircleLarge)
                SquircleIcon(symbol: "globe", tint: .sky, size: Metrics.squircleLarge)
            }
        }
    }

    static func symbol(_ tint: TintName) -> String {
        switch tint {
        case .accent: AppInfo.symbol
        case .violet: "clock.fill"
        case .blue: "text.viewfinder"
        case .sky: "globe"
        case .indigo: "doc.text.viewfinder"
        case .teal: "rectangle.2.swap"
        case .green: "text.badge.plus"
        case .yellow: "book.closed.fill"
        case .orange: "mic.fill"
        case .red: "waveform"
        case .graphite: "gearshape.fill"
        case .black: "macbook"
        }
    }
}

private struct KeyCapSamples: View {
    var body: some View {
        HStack(spacing: Space.l) {
            KeyCaps(["⌃", "⇧"])
            KeyCaps(["⌘", ","])
            KeyCaps(["⌥", "⌘", "K"])
            KeyCaps(["fn"])
        }
    }
}

private struct ProgressSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SegmentedProgress(count: 6, current: 0)
            SegmentedProgress(count: 6, current: 2)
            SegmentedProgress(count: 6, current: 5)
        }
    }
}

private struct SpinnerSamples: View {
    var body: some View {
        HStack(spacing: Space.l) {
            Spinner(size: 12)
            Spinner()
            Spinner(size: 28)
        }
    }
}

private struct StatusSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            StatusMark(.ok, DesignText.allowed)
            StatusMark(.warn, DesignText.notAllowed)
            StatusMark(.idle, DesignText.waiting)
            StatusMark(.busy, DesignText.checking)
            StatusMark(.error, DesignText.failed)
        }
    }
}

private struct EmptyStateSample: View {
    var body: some View {
        EmptyState(symbol: "note.text", title: DesignText.emptyTitle, message: DesignText.emptyMessage,
                   actionTitle: DesignText.newNote) {}
            .frame(height: 240)
    }
}

private struct SectionHeaderSample: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(DesignText.general, symbol: "gearshape.fill", tint: .graphite)
            SectionHeader(DesignText.language, symbol: "globe", tint: .sky) { Chip(CommonText.reset) {} }
        }
        .background(Theme(scheme).windowBg)
    }
}

private struct GlassSample: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        ZStack {
            LinearGradient(colors: t.accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            GlassSurface(cornerRadius: Radius.panel) {
                HStack(spacing: Space.s) {
                    SquircleIcon(symbol: AppInfo.symbol)
                    Text(DesignText.glassSample).font(TypeScale.bodyMedium).foregroundStyle(t.fg)
                }
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// The island tokens on the wallpaper stage: notch with a compact island, a capsule pill and a
/// done card (all token values; the real island lives in the island module).
private struct IslandSample: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let accent = IslandAccent.of()
        let notch = Metrics.Island.renderNotch
        ZStack(alignment: .top) {
            Rectangle().fill(t.wallpaper)
            t.menuBarTint.frame(height: Metrics.Island.renderMenuBar)
            UnevenRoundedRectangle(bottomLeadingRadius: Radius.Island.bottomCompact, bottomTrailingRadius: Radius.Island.bottomCompact,
                                   style: .continuous)
                .fill(IslandPalette.surface)
                .frame(width: notch.width + 2 * Metrics.Island.compactWing, height: notch.height)
                .overlay {
                    HStack {
                        Circle().fill(IslandPalette.rec).frame(width: Metrics.Island.recDot, height: Metrics.Island.recDot)
                        Spacer()
                        Text(Format.seconds(4.2)).font(TypeScale.secondaryMedium.monospacedDigit()).foregroundStyle(IslandPalette.timer)
                    }
                    .padding(.horizontal, Metrics.Island.bodyPad)
                }
            VStack(alignment: .leading, spacing: Space.xxs) {
                HStack(spacing: Space.xs) {
                    Image(systemName: "checkmark.circle.fill").font(TypeScale.secondarySemibold).foregroundStyle(accent.line)
                    Text(DesignText.islandDone).font(TypeScale.secondarySemibold).foregroundStyle(IslandPalette.text)
                    Spacer()
                    Text(DesignText.islandMeta).font(TypeScale.secondaryMedium).foregroundStyle(IslandPalette.meta)
                }
                Text(DesignText.islandPreview).font(TypeScale.preview).foregroundStyle(IslandPalette.body)
                    .lineSpacing(TypeScale.previewLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                Text(DesignText.islandHint).font(TypeScale.subtitle).foregroundStyle(IslandPalette.warning)
            }
            .padding(.horizontal, Metrics.Island.bodyPad)
            .padding(.vertical, Space.s)
            .frame(width: Metrics.Island.doneWidth - 2 * Space.xxl)
            .background(RoundedRectangle(cornerRadius: Radius.Island.capsuleCard, style: .continuous).fill(IslandPalette.surface)
                .shadow(color: IslandPalette.shadow, radius: Space.s, y: Space.xs))
            .padding(.top, notch.height + Space.l)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
