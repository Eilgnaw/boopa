import SwiftUI

/// Notch (camera-housing) geometry for one screen, expressed in that overlay's
/// local points with a top-left origin. `nil` for screens without a notch —
/// e.g. most external displays. Computed per screen in `GlowController`.
struct NotchGeometry: Equatable {
    var height: CGFloat   // notch depth from the physical top edge
    var leftX: CGFloat    // x where the notch begins
    var rightX: CGFloat   // x where the notch ends
}

/// The animated edge glow rendered inside each overlay window.
struct GlowView: View {
    let style: Theme
    let notch: NotchGeometry?

    var body: some View {
        Group {
            if style.animationKind == .comet {
                CometBorder(style: style, notch: notch)
            } else {
                EdgeGlow(style: style, notch: notch)
                    .modifier(PulseModifier(style: style))
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Edge bands

/// Directional gradients fading from each edge toward the center; the middle stays
/// transparent. The top edge wraps around the notch when one is present, so the glow
/// hugs the screen's usable contour instead of hiding behind the camera housing.
private struct EdgeGlow: View {
    let style: Theme
    let notch: NotchGeometry?

    private var color: Color { Color(boopaHex: style.color) }
    private var depth: CGFloat { CGFloat(style.thickness + style.blur) }
    private var edges: Set<GlowEdge> { style.edgeSet }

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let d = min(depth, min(w, h) / 2)

            if edges.contains(.bottom) {
                fill(ctx, CGRect(x: 0, y: h - d, width: w, height: d),
                     from: CGPoint(x: 0, y: h), to: CGPoint(x: 0, y: h - d))
            }
            if edges.contains(.left) {
                fill(ctx, CGRect(x: 0, y: 0, width: d, height: h),
                     from: CGPoint(x: 0, y: 0), to: CGPoint(x: d, y: 0))
            }
            if edges.contains(.right) {
                fill(ctx, CGRect(x: w - d, y: 0, width: d, height: h),
                     from: CGPoint(x: w, y: 0), to: CGPoint(x: w - d, y: 0))
            }
            if edges.contains(.top) {
                drawTop(ctx, width: w, depth: d)
            }
        }
        .compositingGroup()
        .blur(radius: CGFloat(style.blur) * 0.3)
        .ignoresSafeArea()
    }

    /// Straight band when there's no notch; otherwise a rounded contour that dips
    /// around the notch, glowing on the screen-content side with every corner rounded.
    private func drawTop(_ ctx: GraphicsContext, width w: CGFloat, depth d: CGFloat) {
        guard let notch, notch.rightX > notch.leftX, notch.height > 0 else {
            fill(ctx, CGRect(x: 0, y: 0, width: w, height: d),
                 from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: d))
            return
        }
        let nL = notch.leftX, nR = notch.rightX, nH = notch.height
        let r = min(8, (nR - nL) / 2, nH / 2)   // corner radius around the notch

        // The usable top contour: across to the notch, down its left wall, across the
        // floor, up the right wall, then on to the far corner — with rounded turns.
        var contour = Path()
        contour.move(to: CGPoint(x: 0, y: 0))
        contour.addLine(to: CGPoint(x: nL - r, y: 0))
        contour.addQuadCurve(to: CGPoint(x: nL, y: r), control: CGPoint(x: nL, y: 0))
        contour.addLine(to: CGPoint(x: nL, y: nH - r))
        contour.addQuadCurve(to: CGPoint(x: nL + r, y: nH), control: CGPoint(x: nL, y: nH))
        contour.addLine(to: CGPoint(x: nR - r, y: nH))
        contour.addQuadCurve(to: CGPoint(x: nR, y: nH - r), control: CGPoint(x: nR, y: nH))
        contour.addLine(to: CGPoint(x: nR, y: r))
        contour.addQuadCurve(to: CGPoint(x: nR + r, y: 0), control: CGPoint(x: nR, y: 0))
        contour.addLine(to: CGPoint(x: w, y: 0))

        // The notch opening (rounded bottom corners), extended above the top edge.
        // Clip it OUT so the centered stroke only paints on the content side.
        var hole = Path()
        hole.move(to: CGPoint(x: nL, y: -d))
        hole.addLine(to: CGPoint(x: nL, y: nH - r))
        hole.addQuadCurve(to: CGPoint(x: nL + r, y: nH), control: CGPoint(x: nL, y: nH))
        hole.addLine(to: CGPoint(x: nR - r, y: nH))
        hole.addQuadCurve(to: CGPoint(x: nR, y: nH - r), control: CGPoint(x: nR, y: nH))
        hole.addLine(to: CGPoint(x: nR, y: -d))
        hole.closeSubpath()

        var c = ctx
        c.clip(to: hole, options: .inverse)

        // Soft inner glow: stack centered strokes from wide+faint to narrow+bright.
        // Half of each stroke is clipped away, leaving a one-sided fade ~`d` deep that
        // follows the rounded contour smoothly through every corner.
        let steps = 28
        let minW = max(2, CGFloat(style.thickness))
        let aLayer = 1 - pow(1 - style.intensity, 1 / Double(steps))
        for i in 0..<steps {
            let f = Double(i) / Double(steps - 1)         // 0 (outer) → 1 (inner)
            let width = minW + (2 * d - minW) * (1 - CGFloat(f))
            c.stroke(contour, with: .color(color.opacity(aLayer)),
                     style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }

    private func fill(_ ctx: GraphicsContext, _ rect: CGRect, from: CGPoint, to: CGPoint) {
        let gradient = Gradient(stops: [
            .init(color: color.opacity(style.intensity), location: 0),
            .init(color: color.opacity(0), location: 1),
        ])
        ctx.fill(Path(rect), with: .linearGradient(gradient, startPoint: from, endPoint: to))
    }
}

// MARK: - Opacity animation (breathe / pulse / blink / solid)

private struct PulseModifier: ViewModifier {
    let style: Theme
    @State private var lit = false

    func body(content: Content) -> some View {
        content
            .opacity(lit ? high : low)
            .onAppear { animate() }
    }

    private var high: Double { 1 }
    private var low: Double {
        switch style.animationKind {
        case .breathe: return 0.35
        case .pulse: return 0.12
        case .blink: return 0.0
        case .solid, .comet: return 1
        }
    }

    private func animate() {
        switch style.animationKind {
        case .solid, .comet:
            lit = true
        case .breathe:
            withAnimation(.easeInOut(duration: style.period).repeatForever(autoreverses: true)) { lit = true }
        case .pulse:
            withAnimation(.easeInOut(duration: max(0.2, style.period * 0.5)).repeatForever(autoreverses: true)) { lit = true }
        case .blink:
            withAnimation(.easeInOut(duration: max(0.06, style.period * 0.15)).repeatForever(autoreverses: true)) { lit = true }
        }
    }
}

// MARK: - Comet (rotating highlight around the border)

private struct CometBorder: View {
    let style: Theme
    let notch: NotchGeometry?

    private var color: Color { Color(boopaHex: style.color) }
    private var period: Double { max(1.2, 4.0 / max(0.1, style.speed)) }
    private var lineWidth: CGFloat { CGFloat(style.thickness) }
    private let tail: CGFloat = 0.22      // comet length as a fraction of the perimeter
    private let segmentCount = 20

    var body: some View {
        // Drive the comet head along the perimeter at constant arc-length speed (so it
        // turns the rounded corners — and the notch — smoothly, with no gaps).
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let head = CGFloat(elapsed.truncatingRemainder(dividingBy: period) / period)
                let radius = min(size.width, size.height) * 0.045
                let inset = lineWidth / 2 + 1
                let rect = CGRect(
                    x: inset, y: inset,
                    width: max(0, size.width - 2 * inset),
                    height: max(0, size.height - 2 * inset)
                )
                let path = borderPath(rect: rect, radius: radius, inset: inset)
                let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

                // A bright head with a fading tail, drawn as overlapping arc segments.
                for i in 0..<segmentCount {
                    let f = CGFloat(i) / CGFloat(segmentCount) // 0 at head → 1 at tail end
                    let to = head - f * tail
                    let from = to - tail / CGFloat(segmentCount) - 0.003
                    let alpha = Double((1 - f) * (1 - f)) * style.intensity
                    strokeArc(ctx, path, from: from, to: to,
                              color: color.opacity(alpha), stroke: stroke)
                }
            }
            .blur(radius: CGFloat(style.blur) * 0.3)
        }
        .ignoresSafeArea()
    }

    /// The closed loop the comet travels: a rounded rect, with a notch carved into
    /// the top edge when one is present so the light wraps around the camera housing.
    private func borderPath(rect: CGRect, radius r: CGFloat, inset: CGFloat) -> Path {
        guard let notch, notch.rightX > notch.leftX, notch.height > 0 else {
            return Path(roundedRect: rect, cornerRadius: r)
        }
        let nL = notch.leftX, nR = notch.rightX
        let nB = inset + notch.height                       // notch floor (y)
        let nr = min(8, (nR - nL) / 2, notch.height / 2)    // small radius at notch corners

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        // top edge → into the notch
        p.addLine(to: CGPoint(x: nL - nr, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: nL, y: rect.minY + nr), control: CGPoint(x: nL, y: rect.minY))
        p.addLine(to: CGPoint(x: nL, y: nB - nr))
        p.addQuadCurve(to: CGPoint(x: nL + nr, y: nB), control: CGPoint(x: nL, y: nB))
        // across the notch floor → back up
        p.addLine(to: CGPoint(x: nR - nr, y: nB))
        p.addQuadCurve(to: CGPoint(x: nR, y: nB - nr), control: CGPoint(x: nR, y: nB))
        p.addLine(to: CGPoint(x: nR, y: rect.minY + nr))
        p.addQuadCurve(to: CGPoint(x: nR + nr, y: rect.minY), control: CGPoint(x: nR, y: rect.minY))
        // remaining top edge → top-right corner → around
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }

    /// Stroke a fraction [from, to] of the closed path, wrapping across the 0/1 seam.
    private func strokeArc(_ ctx: GraphicsContext, _ path: Path,
                           from: CGFloat, to: CGFloat,
                           color: Color, stroke: StrokeStyle) {
        let a = from - floor(from) // normalize into 0..1
        let b = to - floor(to)
        if a <= b {
            ctx.stroke(path.trimmedPath(from: a, to: b), with: .color(color), style: stroke)
        } else {
            ctx.stroke(path.trimmedPath(from: a, to: 1), with: .color(color), style: stroke)
            ctx.stroke(path.trimmedPath(from: 0, to: b), with: .color(color), style: stroke)
        }
    }
}

// MARK: - Helpers

extension Color {
    /// Parse `#RRGGBB`, `#RRGGBBAA`, or a small set of color names. Falls back to red.
    init(boopaHex string: String) {
        let names: [String: Color] = [
            "red": .red, "green": .green, "blue": .blue, "orange": .orange,
            "yellow": .yellow, "purple": .purple, "pink": .pink, "white": .white,
            "cyan": .cyan, "mint": .mint, "teal": .teal, "indigo": .indigo, "gray": .gray,
        ]
        if let named = names[string.lowercased()] { self = named; return }

        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        switch hex.count {
        case 6:
            self = Color(.sRGB,
                         red: Double((value >> 16) & 0xFF) / 255,
                         green: Double((value >> 8) & 0xFF) / 255,
                         blue: Double(value & 0xFF) / 255,
                         opacity: 1)
        case 8:
            self = Color(.sRGB,
                         red: Double((value >> 24) & 0xFF) / 255,
                         green: Double((value >> 16) & 0xFF) / 255,
                         blue: Double((value >> 8) & 0xFF) / 255,
                         opacity: Double(value & 0xFF) / 255)
        default:
            self = .red
        }
    }
}
