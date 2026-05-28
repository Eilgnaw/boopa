import SwiftUI

/// The animated edge glow rendered inside each overlay window.
struct GlowView: View {
    let style: Theme

    var body: some View {
        Group {
            if style.animationKind == .comet {
                CometBorder(style: style)
            } else {
                EdgeGlow(style: style)
                    .modifier(PulseModifier(style: style))
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Edge bands

/// Four directional gradients fading from the edge toward the center; the middle stays transparent.
private struct EdgeGlow: View {
    let style: Theme

    private var color: Color { Color(boopaHex: style.color) }
    private var depth: CGFloat { CGFloat(style.thickness + style.blur) }
    private var edges: Set<GlowEdge> { style.edgeSet }

    var body: some View {
        ZStack {
            if edges.contains(.top) { band(.top) }
            if edges.contains(.bottom) { band(.bottom) }
            if edges.contains(.left) { band(.left) }
            if edges.contains(.right) { band(.right) }
        }
        .compositingGroup()
        .blur(radius: CGFloat(style.blur) * 0.3)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func band(_ edge: GlowEdge) -> some View {
        let gradient = LinearGradient(
            stops: [
                .init(color: color.opacity(style.intensity), location: 0),
                .init(color: color.opacity(0), location: 1),
            ],
            startPoint: edge.gradientStart,
            endPoint: edge.gradientEnd
        )
        switch edge {
        case .top:
            gradient.frame(height: depth).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .bottom:
            gradient.frame(height: depth).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        case .left:
            gradient.frame(width: depth).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .right:
            gradient.frame(width: depth).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        case .all:
            EmptyView()
        }
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

    private var color: Color { Color(boopaHex: style.color) }
    private var period: Double { max(1.2, 4.0 / max(0.1, style.speed)) }
    private var lineWidth: CGFloat { CGFloat(style.thickness) }
    private let tail: CGFloat = 0.22      // comet length as a fraction of the perimeter
    private let segmentCount = 20

    var body: some View {
        // Drive the comet head along the rounded-rect perimeter at constant arc-length
        // speed (so it turns the rounded corners smoothly, with no gaps).
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
                let path = Path(roundedRect: rect, cornerRadius: radius)
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

private extension GlowEdge {
    var gradientStart: UnitPoint {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        case .all: return .center
        }
    }

    var gradientEnd: UnitPoint {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .trailing
        case .right: return .leading
        case .all: return .center
        }
    }
}

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
