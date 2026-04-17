import SwiftUI

// MARK: - Ring Arc (server data → ring segment)

/// A contiguous arc segment on the ring, derived from actual server data.
/// Consecutive days with the same phase are grouped for efficient drawing.
struct RingArc: Equatable, Sendable {
    let startDay: Int   // 1-based
    let endDay: Int     // 1-based, inclusive
    let phase: CyclePhase
    let isPredicted: Bool
    let isLate: Bool

    init(startDay: Int, endDay: Int, phase: CyclePhase, isPredicted: Bool, isLate: Bool = false) {
        self.startDay = startDay
        self.endDay = endDay
        self.phase = phase
        self.isPredicted = isPredicted
        self.isLate = isLate
    }
}

// MARK: - Celestial Orbit Canvas

/// Draws the cycle orbit ring: phase-colored arcs, glass effects, and orb marker.
struct CelestialOrbitCanvas: View {
    let displayDay: Int
    let cycleLength: Int
    let arcs: [RingArc]
    let phase: CyclePhase
    let isDragging: Bool
    let reduceMotion: Bool
    var collapseProgress: CGFloat = 0

    @State private var fillAngle: Double = -.pi / 2
    @State private var orbAngle: Double = -.pi / 2

    private var wrappedDay: Int {
        guard cycleLength > 0 else { return 1 }
        return ((displayDay - 1) % cycleLength) + 1
    }

    /// Angle for the fill track and phase arcs — reaches full circle on last day.
    private var targetFillAngle: Double {
        let cl = Double(max(cycleLength, 1))
        let fraction = Double(wrappedDay) / cl
        return fraction * 2 * .pi - .pi / 2
    }

    /// Angle for the orb marker — capped slightly before the start to avoid overlap.
    private var targetOrbAngle: Double {
        let cl = Double(max(cycleLength, 1))
        let fraction = min(Double(wrappedDay) / cl, 1.0 - 0.5 / cl)
        return fraction * 2 * .pi - .pi / 2
    }

    private var fillTaskKey: Int { displayDay &* 31 &+ cycleLength }

    var body: some View {
        let currentFill = fillAngle
        let currentOrb = orbAngle
        let collapse = collapseProgress

        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 20

            if collapse > 0.05 {
                ctx.opacity = Double(min(1, collapse * 3))
                drawBaseTrack(ctx: &ctx, c: center, r: r)
                ctx.opacity = 1
            }
            drawFilledTrack(ctx: &ctx, c: center, r: r, fill: currentFill)
            drawPhaseArcs(ctx: &ctx, c: center, r: r, fill: currentFill)
            drawOrb(ctx: &ctx, c: center, r: r, angle: currentOrb)
        }
        .task(id: fillTaskKey) {
            let targetFill = targetFillAngle
            let targetOrb = targetOrbAngle
            let startFill = fillAngle
            let startOrb = orbAngle
            let duration: Double = isDragging ? 0.15 : reduceMotion ? 0.0 : 0.5
            guard duration > 0, max(abs(targetFill - startFill), abs(targetOrb - startOrb)) > 0.001 else {
                fillAngle = targetFill
                orbAngle = targetOrb
                return
            }
            let began = Date.now
            while !Task.isCancelled {
                let t = min(1.0, Date.now.timeIntervalSince(began) / duration)
                let ease = 1 - pow(1 - t, 3)
                fillAngle = startFill + (targetFill - startFill) * ease
                orbAngle = startOrb + (targetOrb - startOrb) * ease
                if t >= 1.0 { break }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { break }
            }
        }
    }

    // MARK: - Drawing

    private let arcW: CGFloat = 14
    private let startAngle = -Double.pi / 2

    private func drawBaseTrack(ctx: inout GraphicsContext, c: CGPoint, r: Double) {
        var path = Path()
        path.addArc(center: c, radius: r, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        ctx.stroke(
            path,
            with: .color(DesignColors.structure.opacity(0.18)),
            style: StrokeStyle(lineWidth: arcW, lineCap: .round)
        )
    }

    private func drawFilledTrack(ctx: inout GraphicsContext, c: CGPoint, r: Double, fill: Double) {
        guard fill > startAngle + 0.01 else { return }
        // Glass body
        var glass = Path()
        glass.addArc(center: c, radius: r, startAngle: .radians(startAngle), endAngle: .radians(fill), clockwise: false)
        ctx.stroke(
            glass,
            with: .color(DesignColors.structure.opacity(0.10)),
            style: StrokeStyle(lineWidth: arcW, lineCap: .round)
        )
        // Inner rim
        var inner = Path()
        inner.addArc(
            center: c,
            radius: r - Double(arcW / 2) + 0.8,
            startAngle: .radians(startAngle),
            endAngle: .radians(fill),
            clockwise: false
        )
        ctx.stroke(inner, with: .color(Color.white.opacity(0.14)), lineWidth: 0.5)
        // Outer rim
        var outer = Path()
        outer.addArc(
            center: c,
            radius: r + Double(arcW / 2) - 0.8,
            startAngle: .radians(startAngle),
            endAngle: .radians(fill),
            clockwise: false
        )
        ctx.stroke(outer, with: .color(Color.black.opacity(0.04)), lineWidth: 0.5)
    }

    /// Draws ring arcs from pre-computed server data segments.
    /// Each `RingArc` maps to real dates looked up via server calendar data.
    /// NO formula-based phase ranges — colors match exactly what the server says.
    private func drawPhaseArcs(ctx: inout GraphicsContext, c: CGPoint, r: Double, fill: Double) {
        let cl = max(cycleLength, 1)
        let fullCircle = fill >= startAngle + 2 * .pi - 0.05

        for arc in arcs {
            let pStart = Double(arc.startDay - 1) / Double(cl) * 2 * .pi + startAngle
            let pEnd = Double(arc.endDay) / Double(cl) * 2 * .pi + startAngle
            guard fill > pStart else { continue }
            let cEnd = min(pEnd, fill)

            let baseOpacity = arc.isLate ? 0.25 : arc.isPredicted ? 0.35 : 0.55
            let arcColor: Color = arc.isLate
                ? Color(red: 0.55, green: 0.52, blue: 0.50)
                : arc.phase.orbitColor

            // Phase color arc
            var body = Path()
            body.addArc(center: c, radius: r, startAngle: .radians(pStart), endAngle: .radians(cEnd), clockwise: false)

            ctx.stroke(
                body,
                with: .color(arcColor.opacity(baseOpacity)),
                style: StrokeStyle(lineWidth: arcW, lineCap: .butt)
            )

            // Inner highlight
            var hi = Path()
            hi.addArc(
                center: c,
                radius: r - Double(arcW / 2) + 1,
                startAngle: .radians(pStart),
                endAngle: .radians(cEnd),
                clockwise: false
            )
            ctx.stroke(hi, with: .color(Color.white.opacity(arc.isPredicted ? 0.15 : 0.25)), lineWidth: 1.0)

            // Specular
            var sp = Path()
            sp.addArc(
                center: c,
                radius: r - Double(arcW * 0.15),
                startAngle: .radians(pStart),
                endAngle: .radians(cEnd),
                clockwise: false
            )
            ctx.stroke(
                sp,
                with: .color(Color.white.opacity(arc.isPredicted ? 0.06 : 0.12)),
                style: StrokeStyle(lineWidth: arcW * 0.35, lineCap: .butt)
            )

            // Outer depth
            var od = Path()
            od.addArc(
                center: c,
                radius: r + Double(arcW / 2) - 1,
                startAngle: .radians(pStart),
                endAngle: .radians(cEnd),
                clockwise: false
            )
            ctx.stroke(od, with: .color(arcColor.opacity(arc.isPredicted || arc.isLate ? 0.08 : 0.15)), lineWidth: 0.8)
        }

        // Start fade
        if !fullCircle {
            let fadeAngle = Double.pi * 0.1
            let clampedFade = min(fadeAngle, fill - startAngle)
            guard clampedFade > 0.01 else { return }
            for i in 0..<24 {
                let t = Double(i) / 24
                let tN = Double(i + 1) / 24
                let alpha = pow(1 - t, 3) * 0.9
                var seg = Path()
                seg.addArc(
                    center: c,
                    radius: r,
                    startAngle: .radians(startAngle + t * clampedFade),
                    endAngle: .radians(startAngle + tN * clampedFade),
                    clockwise: false
                )
                ctx.stroke(
                    seg,
                    with: .color(Color(uiColor: .systemBackground).opacity(alpha)),
                    style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                )
            }
        }
    }

    private func drawOrb(ctx: inout GraphicsContext, c: CGPoint, r: Double, angle: Double) {
        let pos = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)

        // Bloom
        let bs: Double = 38
        ctx.fill(
            Path(ellipseIn: CGRect(x: pos.x - bs / 2, y: pos.y - bs / 2, width: bs, height: bs)),
            with: .radialGradient(
                Gradient(colors: [phase.glowColor.opacity(0.25), phase.glowColor.opacity(0.06), .clear]),
                center: pos,
                startRadius: 0,
                endRadius: bs / 2
            )
        )

        // Cross rays
        for i in 0..<4 {
            let a = Double(i) * .pi / 4
            let d = 7.0
            var ray = Path()
            ray.move(to: CGPoint(x: pos.x - cos(a) * d, y: pos.y - sin(a) * d))
            ray.addLine(to: CGPoint(x: pos.x + cos(a) * d, y: pos.y + sin(a) * d))
            ctx.stroke(ray, with: .color(.white.opacity(i % 2 == 0 ? 0.5 : 0.25)), lineWidth: 1.2)
        }

        // Gemstone
        let gs: Double = 12
        var gem = ctx
        gem.addFilter(.shadow(color: phase.glowColor.opacity(0.6), radius: 6))
        let gemRect = CGRect(x: -gs / 2, y: -gs / 2, width: gs, height: gs)
        let gemPath = Path(roundedRect: gemRect, cornerRadius: 3)
        gem.translateBy(x: pos.x, y: pos.y)
        gem.rotate(by: .radians(.pi / 4))
        gem.fill(
            gemPath,
            with: .linearGradient(
                Gradient(colors: [.white, phase.orbitColor.opacity(0.7)]),
                startPoint: CGPoint(x: -gs * 0.3, y: -gs * 0.5),
                endPoint: CGPoint(x: gs * 0.3, y: gs * 0.5)
            )
        )
        gem.stroke(gemPath, with: .color(.white.opacity(0.7)), lineWidth: 0.8)
    }
}
