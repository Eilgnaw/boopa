import SwiftUI

/// A horizontal traffic-light beacon that looks like it's being pulled *out of the
/// notch* (or the top-center of the screen when there's no notch): the bar slides
/// down from behind the notch floor, with everything still "inside" the notch
/// masked away, so it reads as emerging from a slot. Rendered in its own overlay
/// window, fully independent of the edge glow.
struct TrafficLightView: View {
    let spec: TrafficSpec
    let notch: NotchGeometry?

    @State private var pulled = false

    private var pad: CGFloat { housingW * 0.06 }
    private var lamp: CGFloat { (housingW - pad * 4) / 3 }

    // The bar is taller than the lamps alone, split into three vertical bands:
    //  • `tuck`     — black above the notch floor that slips up into the notch so
    //                 the join is black-on-black with no gap at the corners.
    //  • `topRoom`  — black below the notch floor so a lit lamp's glow clears the
    //                 physical notch instead of being eaten by it.
    //  • lamp row, then `bottomRoom` for the glow on the underside.
    private var tuck: CGFloat { cornerRadius > 0 ? cornerRadius + 12 : 0 }
    private var topRoom: CGFloat { lamp * 0.5 }
    private var bottomRoom: CGFloat { lamp * 0.3 }
    private var housingH: CGFloat { tuck + topRoom + lamp + bottomRoom }

    /// Bar width: exactly the notch width so it reads as the notch extending
    /// downward, unless an explicit `--size` overrides it. Falls back to a
    /// sensible width on screens with no notch.
    private var notchWidth: CGFloat? { notch.map { $0.rightX - $0.leftX } }
    private var housingW: CGFloat {
        if spec.size > 0 { return CGFloat(spec.size) }
        // Just inside the notch width, so the sides sit a hair in from the walls
        // instead of overhanging the rounded corners.
        if let w = notchWidth { return w - 0.5 }
        return 200
    }

    /// The notch's bottom-corner radius (matches GlowView's). The bar is tucked up
    /// by this much so its flat top meets the notch where it's still full-width
    /// black, hiding the desktop slivers the rounded corners would otherwise leave.
    private var cornerRadius: CGFloat {
        guard let notch else { return 0 }
        return min(8, (notch.rightX - notch.leftX) / 2, notch.height / 2)
    }

    var body: some View {
        GeometryReader { geo in
            // Pull out from the notch center when present, else the top-center.
            let centerX = notch.map { ($0.leftX + $0.rightX) / 2 } ?? geo.size.width / 2
            // The slot the bar emerges from: the notch floor (or the very top edge).
            let slotY = notch?.height ?? 0
            // Tuck the flat top up into the notch so the extra black covers the
            // rounded-corner slivers and joins the notch seamlessly.
            let topY = slotY - tuck
            let restCenterY = topY + housingH / 2
            // The reveal grows a clip downward from `topY`; the content nudges down a
            // little so the lamps slide. Keeping the nudge ≤ housingH guarantees the
            // black always fills the revealed strip (so the notch never flashes desktop).
            let reveal = pulled ? housingH : 0
            let slide = min(40, housingH)

            housing
                .frame(width: housingW, height: housingH)
                .position(x: centerX, y: restCenterY)
                .offset(y: pulled ? 0 : -slide)
                // Anchor the top of the clip at the notch (`topY`) and grow it down, so
                // the black is rooted at the notch and extends downward — the area just
                // below the notch is black from the first frame, never bare desktop.
                .mask(
                    Rectangle()
                        .frame(width: geo.size.width, height: reveal)
                        .position(x: geo.size.width / 2, y: topY + reveal / 2)
                )
                .onAppear {
                    // No spring (no overshoot/bounce) — a steady eased wipe that reads
                    // as the bar being slowly drawn down out of the notch.
                    withAnimation(.easeInOut(duration: 0.75)) {
                        pulled = true
                    }
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var housing: some View {
        // Flat top (flush with the notch), rounded bottom — a seamless extension
        // of the notch that the bar slides out of. Lamps sit low (extra black on
        // top) so their glow stays clear of the physical notch.
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: housingW * 0.14,
            bottomTrailingRadius: housingW * 0.14,
            topTrailingRadius: 0,
            style: .continuous
        )
        return HStack(spacing: pad) {
            ForEach(TrafficColor.allCases, id: \.self) { lampView($0) }
        }
        .padding(.horizontal, pad)
        .padding(.top, tuck + topRoom)
        .padding(.bottom, bottomRoom)
        // Solid black to match the notch bezel so the two merge into one shape.
        .background(shape.fill(Color.black))
    }

    @ViewBuilder
    private func lampView(_ color: TrafficColor) -> some View {
        let isLit = spec.litColors.contains(color)
        let tint = Color(boopaHex: color.hex)
        Circle()
            .fill(isLit ? tint : tint.opacity(0.16))
            .overlay(
                // A bright top highlight gives each lamp a glassy, domed look.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(isLit ? 0.55 : 0.12), .clear],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: lamp * 0.6
                        )
                    )
            )
            .overlay(Circle().strokeBorder(Color.black.opacity(0.45), lineWidth: 1))
            .frame(width: lamp, height: lamp)
            // Lit lamps cast a colored halo so the active signal pops.
            .shadow(color: isLit ? tint.opacity(0.9) : .clear, radius: isLit ? lamp * 0.45 : 0)
            .modifier(LampBreathe(active: isLit))
    }
}

/// A gentle breathing pulse applied only to lit lamps, so an active signal feels alive.
private struct LampBreathe: ViewModifier {
    let active: Bool
    @State private var bright = false

    func body(content: Content) -> some View {
        content
            .opacity(active ? (bright ? 1.0 : 0.78) : 1.0)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}
