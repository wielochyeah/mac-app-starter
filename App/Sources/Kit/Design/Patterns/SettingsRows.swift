import AppKit
import SwiftUI

// Ready-made rows for a SettingsSection card. All of them are `Row` (title 13 `fg`, subtitle 11.5
// `fg2` or 12 `prose` on setup steps, min height 44, padding 12 / 9) with one kind of trailing
// control, so every pane in every module looks the same. The subtitle tone comes from the
// enclosing `SettingsSection(tone:)`.

/// A setting that is on or off.
struct ToggleRow: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: TintName
    @Binding var isOn: Bool
    @Environment(\.textTone) private var tone

    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        _isOn = isOn
    }

    var body: some View {
        Row(title, subtitle: subtitle, symbol: symbol, tint: tint, tone: tone) {
            SwitchToggle(isOn: $isOn).accessibilityLabel(title)
        }
    }
}

/// How a `PickerRow` shows its options: a segmented control (2–3 short options) or a pop-up menu
/// button (more options, or longer names).
enum PickerRowStyle { case segmented, menu }

/// One choice out of a few.
struct PickerRow<Value: Hashable>: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: TintName
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var style: PickerRowStyle
    @Environment(\.textTone) private var tone

    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent,
         options: [(value: Value, title: String)], selection: Binding<Value>, style: PickerRowStyle = .segmented) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.options = options
        _selection = selection
        self.style = style
    }

    var body: some View {
        Row(title, subtitle: subtitle, symbol: symbol, tint: tint, tone: tone) {
            switch style {
            case .segmented: Segmented(options, selection: $selection).accessibilityLabel(title)
            case .menu: MenuPicker(options, selection: $selection).accessibilityLabel(title)
            }
        }
    }
}

/// A pop-up button in the kit's look (white pill with hairline, chevrons), drawn in SwiftUI so
/// renders show it; the menu itself is the system's.
struct MenuPicker<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    @Environment(\.colorScheme) private var scheme
    @Environment(\.renderStatic) private var renderStatic

    init(_ options: [(value: Value, title: String)], selection: Binding<Value>) {
        self.options = options
        _selection = selection
    }

    private var current: String { options.first { $0.value == selection }?.title ?? "" }

    var body: some View {
        if renderStatic {
            label
        } else {
            Menu {
                ForEach(options, id: \.value) { option in
                    Button {
                        selection = option.value
                    } label: {
                        if option.value == selection { Label(option.title, systemImage: "checkmark") } else { Text(option.title) }
                    }
                }
            } label: {
                label
            }
            .menuStyle(.button)
            .buttonStyle(PlainStyle())
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var label: some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: Radius.segment, style: .continuous)
        return HStack(spacing: 6) {
            Text(current).font(TypeScale.secondaryMedium).foregroundStyle(t.fg).lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .symbolFont(9, weight: .semibold)
                .foregroundStyle(t.fg2)
        }
        .padding(.leading, 10)
        .padding(.trailing, Space.xs)
        .frame(height: Metrics.menuPickerHeight)
        .background(shape.fill(t.buttonSecondary))
        .overlay(shape.strokeBorder(t.buttonSecondaryEdge, lineWidth: Metrics.hairline))
        .shadow(color: t.buttonShadow, radius: 0.5, y: 0.5)
        .contentShape(shape)
        .fixedSize()
    }
}

/// A value to read, not to change here ("3.0 s", "1.2 GB", "Version 1.0"). `capsule: true`
/// puts it in a value capsule (VoiceBud HubValueCapsule), e.g. above a slider.
struct ValueRow: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: TintName
    let value: String
    var capsule: Bool
    @Environment(\.textTone) private var tone
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, value: String,
         capsule: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.value = value
        self.capsule = capsule
    }

    var body: some View {
        Row(title, subtitle: subtitle, symbol: symbol, tint: tint, tone: tone) {
            if capsule {
                ValueCapsule(value)
            } else {
                Text(value)
                    .font(TypeScale.body.monospacedDigit())
                    .foregroundStyle(Theme(scheme).fg2)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A short value in a capsule: 12.5 medium, monospaced digits, height 23, `capsuleBg` + hairline.
struct ValueCapsule: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    init(_ text: String) { self.text = text }

    var body: some View {
        let t = Theme(scheme)
        Text(text)
            .font(TypeScale.value)
            .foregroundStyle(t.fg)
            .contentTransition(.numericText())
            .padding(.horizontal, 9)
            .frame(height: Metrics.valueCapsuleHeight)
            .background(Capsule().fill(t.capsuleBg))
            .overlay(Capsule().strokeBorder(t.capsuleStroke, lineWidth: Metrics.hairline))
    }
}

/// How a `ButtonRow` draws its button: a chip (VoiceBud's "Remove", "Add App…"; the default), or a
/// full secondary / primary button for the one action that matters on the pane.
enum ButtonRowStyle { case chip, secondary, primary }

/// Asks in place before a destructive action, instead of the row that started it: what happens,
/// the action as red text on a quiet button, Cancel as the prominent button that Esc presses.
/// Return never confirms. Swap it in with `Motion.expand`:
///
///     if confirming {
///         ConfirmRow(SettingsText.resetConfirmTitle, text: SettingsText.resetConfirmText,
///                    button: SettingsText.resetConfirmButton, cancel: { confirming = false }, confirm: reset)
///     } else {
///         ButtonRow(SettingsText.reset, button: SettingsText.resetButton) { confirming = true }
///     }
struct ConfirmRow: View {
    let title: String
    let text: String
    let button: String
    let cancel: () -> Void
    let confirm: () -> Void
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, text: String, button: String, cancel: @escaping () -> Void, confirm: @escaping () -> Void) {
        self.title = title
        self.text = text
        self.button = button
        self.cancel = cancel
        self.confirm = confirm
    }

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolFont(Metrics.noticeIcon, weight: .semibold)
                    .foregroundStyle(t.warn)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.hair) {
                    Text(title).font(TypeScale.bodySemibold).foregroundStyle(t.fg)
                    Text(text)
                        .font(TypeScale.subtitle)
                        .foregroundStyle(t.fg2)
                        .lineSpacing(TypeScale.footnoteLineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: Space.xs) {
                Spacer(minLength: 0)
                // the label carries its own colour: the button style sets the default text colour
                Button(action: confirm) { Text(button).foregroundStyle(t.destructive) }
                    .buttonStyle(.secondary)
                Button(CommonText.cancel, action: cancel)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Space.s)
        .transition(.opacity)
    }
}

/// A row with one action ("Show in Finder", "Reset…", "Add App…").
struct ButtonRow: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: TintName
    let button: String
    var buttonSymbol: String?
    var style: ButtonRowStyle
    let action: () -> Void
    @Environment(\.textTone) private var tone

    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, button: String,
         buttonSymbol: String? = nil, style: ButtonRowStyle = .chip, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.button = button
        self.buttonSymbol = buttonSymbol
        self.style = style
        self.action = action
    }

    var body: some View {
        Row(title, subtitle: subtitle, symbol: symbol, tint: tint, tone: tone) {
            switch style {
            case .chip: Chip(button, symbol: buttonSymbol, action: action)
            case .secondary: Button(button, action: action).buttonStyle(.secondary)
            case .primary: Button(button, action: action).buttonStyle(.primary)
            }
        }
    }
}

/// A row that opens something outside the pane (a web page, System Settings, a file): the whole
/// row is the button, with an `arrow.up.right` mark and a hover highlight.
struct LinkRow: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: TintName
    let action: () -> Void
    @Environment(\.textTone) private var tone
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent,
         action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.action = action
    }

    /// Opens `url` with the system (System Settings deep links, web pages).
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, url: URL) {
        self.init(title, subtitle: subtitle, symbol: symbol, tint: tint) { NSWorkspace.shared.open(url) }
    }

    var body: some View {
        let t = Theme(scheme)
        HoverButton(action: action) {
            Row(title, subtitle: subtitle, symbol: symbol, tint: tint, tone: tone) {
                Image(systemName: "arrow.up.right")
                    .symbolFont(11, weight: .semibold)
                    .foregroundStyle(t.fg3)
            }
        }
        .accessibilityAddTraits(.isLink)
        .accessibilityHint(PatternsText.opensOutside)
    }
}

/// A row that leads deeper (a sub-page, another pane): optional value and a chevron, whole row
/// clickable with a hover highlight.
struct NavigationRow: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: TintName
    var value: String?
    let action: () -> Void
    @Environment(\.textTone) private var tone
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, tint: TintName = .accent, value: String? = nil,
         action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.value = value
        self.action = action
    }

    var body: some View {
        let t = Theme(scheme)
        HoverButton(action: action) {
            Row(title, subtitle: subtitle, symbol: symbol, tint: tint, tone: tone) {
                HStack(spacing: Space.xs) {
                    if let value { Text(value).font(TypeScale.body).foregroundStyle(t.fg2).lineLimit(1) }
                    Image(systemName: "chevron.right")
                        .symbolFont(11, weight: .semibold)
                        .foregroundStyle(t.fg3)
                }
            }
        }
    }
}

/// A whole-row button: no chrome, `rowHover` behind it while the pointer is over it.
struct HoverButton<Label: View>: View {
    let action: () -> Void
    let label: Label
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .background(hovering ? Theme(scheme).rowHover : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainStyle())
        .onHover { inside in withAnimation(Motion.fade) { hovering = inside } }
    }
}
