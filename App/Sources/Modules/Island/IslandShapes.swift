import SwiftUI

/// The hardware notch extended in black: flat top flush with the screen edge, concave "ears"
/// (radius `topRadius`) flowing into the menu bar, rounded bottom corners. The rect includes
/// the ears: the black body is `width - 2 * topRadius` wide. Both radii animate.
nonisolated struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let tr = max(0, min(topRadius, rect.width / 4, rect.height / 2))
        let left = rect.minX + tr, right = rect.maxX - tr
        let br = max(0, min(bottomRadius, (right - left) / 2, rect.height - tr))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        if tr > 0 {
            p.addArc(tangent1End: CGPoint(x: right, y: rect.minY), tangent2End: CGPoint(x: right, y: rect.minY + tr), radius: tr)
        }
        p.addLine(to: CGPoint(x: right, y: rect.maxY - br))
        if br > 0 {
            p.addArc(tangent1End: CGPoint(x: right, y: rect.maxY), tangent2End: CGPoint(x: right - br, y: rect.maxY), radius: br)
        }
        p.addLine(to: CGPoint(x: left + br, y: rect.maxY))
        if br > 0 {
            p.addArc(tangent1End: CGPoint(x: left, y: rect.maxY), tangent2End: CGPoint(x: left, y: rect.maxY - br), radius: br)
        }
        p.addLine(to: CGPoint(x: left, y: rect.minY + tr))
        if tr > 0 {
            p.addArc(tangent1End: CGPoint(x: left, y: rect.minY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: tr)
        }
        p.closeSubpath()
        return p
    }
}

/// The notch island's black shape at the animated surface geometry (ears outside the body).
struct NotchSurfaceShape: View {
    @Environment(\.islandSurface) private var g

    var body: some View {
        NotchShape(topRadius: g.top, bottomRadius: g.bottom)
            .fill(IslandPalette.surface)
            .frame(width: max(0, g.width + 2 * g.top), height: max(0, g.height))
    }
}

/// Clips island content to the animated body (without the ears).
struct NotchSurfaceMask: View {
    @Environment(\.islandSurface) private var g

    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: g.bottom, bottomTrailingRadius: g.bottom)
            .frame(width: max(0, g.width), height: max(0, g.height))
    }
}

/// Black capsule or card with a tight shadow under it (CSS 0 8px 24px -10px rgba(0,0,0,.5);
/// the negative spread is the inset of the blurred copy). Offscreen renders do not draw blur
/// filters, so stills use a plain shadow of the same reach instead.
struct CapsuleBackdrop: View {
    var radius: CGFloat
    @Environment(\.renderStatic) private var renderStatic

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(0, radius), style: .continuous)
        if renderStatic {
            shape.fill(IslandPalette.surface)
                .shadow(color: IslandPalette.shadow, radius: IslandLook.stillShadowRadius, y: IslandLook.shadowOffset)
        } else {
            shape.fill(IslandPalette.surface)
                .background(
                    shape.fill(IslandPalette.shadow)
                        .padding(IslandLook.shadowInset)
                        .offset(y: IslandLook.shadowOffset)
                        .blur(radius: IslandLook.shadowBlur))
        }
    }
}

struct CapsuleSurfaceShape: View {
    @Environment(\.islandSurface) private var g

    var body: some View {
        CapsuleBackdrop(radius: g.bottom)
            .frame(width: max(0, g.width), height: max(0, g.height))
    }
}

struct CapsuleSurfaceMask: View {
    @Environment(\.islandSurface) private var g

    var body: some View {
        RoundedRectangle(cornerRadius: max(0, g.bottom), style: .continuous)
            .frame(width: max(0, g.width), height: max(0, g.height))
    }
}

/// The check of the done badge on a 24 grid (VoiceBud IslandCheckGlyph).
nonisolated struct IslandCheckGlyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 5 / 24, y: r.minY + r.height * 12.5 / 24))
        p.addLine(to: CGPoint(x: r.minX + r.width * 9.5 / 24, y: r.minY + r.height * 17 / 24))
        p.addLine(to: CGPoint(x: r.minX + r.width * 19 / 24, y: r.minY + r.height * 7.5 / 24))
        return p
    }
}
