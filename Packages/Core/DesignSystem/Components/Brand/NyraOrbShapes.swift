import SwiftUI

// MARK: - Nyra Orb Shapes
//
// Private Shape primitives powering the orb's face and silhouette.
// Kept alongside the orb (same folder) but in a dedicated file so
// NyraOrb.swift can stay focused on state/layers/animation.


// MARK: - Face shapes

internal struct EyeArc: Shape {
    enum Direction { case up, down }
    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let end = CGPoint(x: rect.maxX, y: rect.midY)
        let apex: CGPoint = direction == .up
            ? CGPoint(x: rect.midX, y: rect.minY)
            : CGPoint(x: rect.midX, y: rect.maxY)
        p.move(to: start)
        p.addQuadCurve(to: end, control: apex)
        return p
    }
}

/// Siri-style wobbling blob — a near-circle with 8 control points,
/// each offset radially by a phase-driven sine. Two phases running
/// at different rates (`phase` and `phase2`) break symmetry so the
/// silhouette never repeats exactly. Animating both phases via
/// `AnimatablePair` lets SwiftUI interpolate the shape on the render
/// thread instead of per-frame in Swift.
internal struct BlobShape: Shape {
    var phase: CGFloat
    var phase2: CGFloat
    /// How far each control point can bulge — 0 is a perfect circle.
    var bulge: CGFloat = 0.055

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, phase2) }
        set {
            phase = newValue.first
            phase2 = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2

        let segments = 8
        var points: [CGPoint] = []
        for i in 0..<segments {
            let theta = Double(i) / Double(segments) * 2.0 * .pi
            let wobble1 = sin(theta * 3 + Double(phase) * 2 * .pi)
            let wobble2 = cos(theta * 2 + Double(phase2) * 2 * .pi)
            let radial = 1.0 + CGFloat(wobble1 + wobble2 * 0.6) * bulge * 0.5
            let rr = r * radial
            points.append(CGPoint(
                x: cx + cos(theta) * rr,
                y: cy + sin(theta) * rr
            ))
        }

        // Smooth catmull-rom-ish curve through the 8 points using
        // quadratic beziers with midpoints as anchors — produces a
        // continuous, blob-like outline without hard corners.
        let first = points[0]
        let midFirst = CGPoint(
            x: (first.x + points[1].x) / 2,
            y: (first.y + points[1].y) / 2
        )
        p.move(to: midFirst)
        for i in 0..<segments {
            let current = points[(i + 1) % segments]
            let next = points[(i + 2) % segments]
            let mid = CGPoint(
                x: (current.x + next.x) / 2,
                y: (current.y + next.y) / 2
            )
            p.addQuadCurve(to: mid, control: current)
        }
        p.closeSubpath()
        return p
    }
}

/// 4-point twinkle (✧) — a star with concave sides. Used as the eye
/// catchlight on Sora-style companion faces: 4 cardinal points with
/// curved waists between them. The `waist` parameter controls how
/// deeply the sides bow in (0 = diamond/rhombus, higher = sharper star).
internal struct Twinkle: Shape {
    var waist: CGFloat = 0.28

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let w = rect.width / 2
        let h = rect.height / 2

        // 4 cardinal points (N, E, S, W) with quadratic bezier curves
        // bowing inward between them — gives the classic twinkle look.
        let top    = CGPoint(x: cx, y: cy - h)
        let right  = CGPoint(x: cx + w, y: cy)
        let bottom = CGPoint(x: cx, y: cy + h)
        let left   = CGPoint(x: cx - w, y: cy)

        // Control points near center — the smaller the offset, the
        // sharper the star. `waist` maps 0 → diamond, 1 → cross.
        let cw = w * waist
        let ch = h * waist

        p.move(to: top)
        p.addQuadCurve(to: right, control: CGPoint(x: cx + cw, y: cy - ch))
        p.addQuadCurve(to: bottom, control: CGPoint(x: cx + cw, y: cy + ch))
        p.addQuadCurve(to: left, control: CGPoint(x: cx - cw, y: cy + ch))
        p.addQuadCurve(to: top, control: CGPoint(x: cx - cw, y: cy - ch))
        p.closeSubpath()
        return p
    }
}

/// Smile curve — a soft upward arc. `amount` scales the bow depth,
/// with 0 producing a flat line and 1 producing a near half-circle.
internal struct SmileArc: Shape {
    let amount: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let clamped = max(0, min(1, amount))
        let start = CGPoint(x: rect.minX, y: rect.minY)
        let end = CGPoint(x: rect.maxX, y: rect.minY)
        let apex = CGPoint(x: rect.midX, y: rect.minY + rect.height * clamped)
        p.move(to: start)
        p.addQuadCurve(to: end, control: apex)
        return p
    }
}

// MARK: - Internal shadow helper

internal struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Preview

#Preview("Nyra · States") {
    ScrollView {
        VStack(spacing: 32) {
            ForEach(NyraOrb.Mood.allCases, id: \.self) { mood in
                VStack(spacing: 10) {
                    NyraOrb(size: 200, mood: mood)
                    Text(mood.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 18) {
                ForEach([24, 40, 72, 120, 200], id: \.self) { sz in
                    VStack {
                        NyraOrb(size: CGFloat(sz))
                        Text("\(sz)px").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(40)
    }
    .background(Color(hex: 0xFDFCF7))
}
