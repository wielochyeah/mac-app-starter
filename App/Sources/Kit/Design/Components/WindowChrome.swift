import SwiftUI

/// Window chrome for renders: rounded window (macOS 26 radius), hairline edge, traffic lights.
/// Offscreen captures have no real titlebar, so window scenes draw this around their content.
enum WindowLights { case all, closeOnly, none }

struct StaticWindow<Content: View>: View {
    let size: CGSize
    var lights: WindowLights = .all
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(size: CGSize, lights: WindowLights = .all, @ViewBuilder content: () -> Content) {
        self.size = size
        self.lights = lights
        self.content = content()
    }

    var body: some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: Radius.windowGlass, style: .continuous)
        content
            .frame(width: size.width, height: size.height)
            .background(t.windowBg)
            .overlay(alignment: .topLeading) {
                TrafficLights(lights: lights)
                    .padding(.leading, Metrics.trafficInset)
                    .padding(.top, Metrics.trafficInset)
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

/// Puts a window render on a neutral "desk" with a soft shadow (README screenshots).
struct RenderBoard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let t = Theme(scheme)
        content
            .compositingGroup()
            .shadow(color: t.deskShadow, radius: 24, y: 14)
            .padding(36)
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
