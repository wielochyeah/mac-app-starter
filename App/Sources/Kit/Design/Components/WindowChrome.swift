import SwiftUI

/// Window chrome for renders: rounded window, hairline edge, traffic lights. Offscreen captures
/// have no real titlebar, so window scenes draw this around their content.
enum WindowLights { case all, closeOnly, none }

/// Which window the render imitates (VoiceBud's HubStaticWindow / OnboardingStaticWindow).
enum WindowChrome {
    /// Settings hub and main window: macOS 26 radius 26, all three lights 19 pt in.
    case settings
    /// Onboarding: radius 16, close button only, 9 pt in.
    case onboarding

    var radius: CGFloat { self == .settings ? Radius.windowGlass : Radius.window }
    var trafficInset: CGFloat { self == .settings ? Metrics.trafficInset : Metrics.trafficInsetCompact }
    var lights: WindowLights { self == .settings ? .all : .closeOnly }
}

struct StaticWindow<Content: View>: View {
    let size: CGSize
    var chrome: WindowChrome = .settings
    var lights: WindowLights
    let content: Content
    @Environment(\.colorScheme) private var scheme

    /// `lights` defaults to the chrome's (all for settings, close only for onboarding).
    init(size: CGSize, chrome: WindowChrome = .settings, lights: WindowLights? = nil, @ViewBuilder content: () -> Content) {
        self.size = size
        self.chrome = chrome
        self.lights = lights ?? chrome.lights
        self.content = content()
    }

    var body: some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: chrome.radius, style: .continuous)
        content
            .frame(width: size.width, height: size.height)
            .background(t.windowBg)
            .overlay(alignment: .topLeading) {
                TrafficLights(lights: lights)
                    .padding(.leading, chrome.trafficInset)
                    .padding(.top, chrome.trafficInset)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(t.windowStroke, lineWidth: Metrics.hairline))
            .environment(\.renderStatic, true)
    }
}

struct TrafficLights: View {
    var lights: WindowLights = .all
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let colors: [Color] = switch lights {
        case .all: [t.trafficRed, t.trafficYellow, t.trafficGreen]
        case .closeOnly: [t.trafficRed]
        case .none: []
        }
        HStack(spacing: Metrics.trafficSpacing) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Circle().fill(color)
                    .overlay(Circle().strokeBorder(t.trafficEdge, lineWidth: Metrics.hairline))
                    .frame(width: Metrics.trafficLight, height: Metrics.trafficLight)
            }
        }
    }
}

/// Puts a window render on a neutral "desk" with a soft shadow (README screenshots, every window
/// scene: VoiceBud's OnboardingBoard / hub renders).
struct RenderBoard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let t = Theme(scheme)
        content
            .compositingGroup()
            .shadow(color: t.deskShadow, radius: Metrics.deskShadowRadius, y: Metrics.deskShadowY)
            .padding(Metrics.deskPadding)
            .background(t.desk)
    }
}

/// A component specimen for `design.*` scenes: window background, 24 pt padding, fixed width.
struct Specimen<Content: View>: View {
    var width: CGFloat = 520
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(width: CGFloat = 520, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) { content }
            .padding(Space.l)
            .frame(width: width, alignment: .topLeading)
            .background(Theme(scheme).windowBg)
    }
}
