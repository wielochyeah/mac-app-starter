import SwiftUI

/// The filled accent button (VoiceBud OnboardingButtonStyle .primary): 13 pt semibold, radius 8,
/// min height 30, padding 16, hairline edge, disabled 45 %, pressed scale 0.97 on the press spring.
struct PrimaryButtonStyle: ButtonStyle {
    var minWidth: CGFloat = Metrics.buttonMinWidth

    func makeBody(configuration: Configuration) -> some View {
        KitButtonBody(label: configuration.label, primary: true, pressed: configuration.isPressed, minWidth: minWidth)
    }
}

/// The quiet button next to a primary one: white (dark: white 12 %) with a hairline edge.
struct SecondaryButtonStyle: ButtonStyle {
    var minWidth: CGFloat = Metrics.buttonMinWidth

    func makeBody(configuration: Configuration) -> some View {
        KitButtonBody(label: configuration.label, primary: false, pressed: configuration.isPressed, minWidth: minWidth)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(minWidth: CGFloat) -> PrimaryButtonStyle { PrimaryButtonStyle(minWidth: minWidth) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func secondary(minWidth: CGFloat) -> SecondaryButtonStyle { SecondaryButtonStyle(minWidth: minWidth) }
}

/// A button that switches between primary and secondary in place, animating the change on the page
/// spring (VoiceBud's footer "Continue" while a step's own slot holds the primary action).
struct SwitchingButtonStyle: ButtonStyle {
    var primary: Bool
    var minWidth: CGFloat = Metrics.buttonMinWidth

    func makeBody(configuration: Configuration) -> some View {
        KitButtonBody(label: configuration.label, primary: primary, pressed: configuration.isPressed, minWidth: minWidth)
    }
}

extension ButtonStyle where Self == SwitchingButtonStyle {
    static func primary(_ primary: Bool, minWidth: CGFloat = Metrics.buttonMinWidth) -> SwitchingButtonStyle {
        SwitchingButtonStyle(primary: primary, minWidth: minWidth)
    }
}

/// Scales the label a little while pressed; no chrome (chips, tiles, icon buttons).
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Motion.pressScaleSmall : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// No chrome, no press effect: the label is the whole control.
struct PlainStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

private struct KitButtonBody<Label: View>: View {
    let label: Label
    let primary: Bool
    let pressed: Bool
    let minWidth: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
        label
            .font(primary ? TypeScale.bodySemibold : TypeScale.bodyMedium)
            .foregroundStyle(primary ? t.onAccent : t.fg)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Space.m)
            .frame(minWidth: minWidth, minHeight: Metrics.buttonHeight)
            .background(shape.fill(primary ? t.accent : t.buttonSecondary))
            .overlay(shape.strokeBorder(primary ? t.buttonPrimaryEdge : t.buttonSecondaryEdge, lineWidth: Metrics.hairline))
            .shadow(color: primary ? .clear : t.buttonShadow, radius: 0.5, y: 0.5)
            .contentShape(shape)
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(pressed ? Motion.pressScale : 1)
            .animation(Motion.press, value: pressed)
            .animation(Motion.page, value: primary)
    }
}
