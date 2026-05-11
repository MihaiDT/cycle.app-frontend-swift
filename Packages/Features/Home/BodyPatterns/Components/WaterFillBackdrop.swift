import SwiftUI

// MARK: - Water Fill Backdrop
//
// Renders the pattern card's interior as a glass of water — a
// color column rising from the bottom of the card to a fraction
// of its height equal to `fillRatio` (filled / total). The water's
// surface ripples with two superimposed sin waves so the level
// looks alive, like a real glass on a slightly unstable counter.
// Above the water sits the existing pale-white card surface; below
// the surface, the phase ink fades from saturated bottom to bright
// surface highlight.

struct WaterFillBackdrop: View {

    /// 0…1 — how high the water rises in the card.
    let fillRatio: CGFloat

    /// Phase ink — body of the water.
    let color: Color

    /// Pale glow tone — warmth above the water (replaces the old
    /// generic radial glow with something tied to the level).
    let glow: Color

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                canvas(size: proxy.size, time: t)
            }
        }
    }

    @ViewBuilder
    private func canvas(size: CGSize, time: TimeInterval) -> some View {
        ZStack(alignment: .top) {
            // 1. Card base — pale warm surface above the water.
            Color.white.opacity(0.82)

            // 2. Soft warmth halo near the top — same idea as the
            //    previous backdrop's phase glow but smaller, kept
            //    out of the water area.
            glow
                .frame(width: size.width * 1.0, height: size.height * 0.45)
                .blur(radius: 80)
                .offset(y: -size.height * 0.10)
                .allowsHitTesting(false)

            // 3. The water itself — wavy shape from y = waterTopY
            //    down to the bottom of the card. Filled with a
            //    diagonal multi-stop gradient so the water has
            //    real internal depth instead of reading as a
            //    flat tinted block. Top-leading stays pal
            //    (where the meniscus catches the highlight),
            //    bottom-trailing leans into the saturated phase
            //    ink — gives the card a warm-to-deep slope that
            //    reads dimensional, not painted.
            WaterShape(
                fillRatio: fillRatio,
                time: time
            )
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: color.opacity(0.16), location: 0.0),
                        .init(color: color.opacity(0.26), location: 0.30),
                        .init(color: color.opacity(0.40), location: 0.65),
                        .init(color: color.opacity(0.50), location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .allowsHitTesting(false)

            // 4. A bright thin highlight along the surface so the
            //    waterline reads as a meniscus, not just a fill
            //    edge.
            WaterSurfaceHighlight(
                fillRatio: fillRatio,
                time: time
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.55),
                        Color.white.opacity(0.20),
                        Color.white.opacity(0.55)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 1.0
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Shapes

private struct WaterShape: Shape {

    let fillRatio: CGFloat
    let time: TimeInterval

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // SwiftUI sometimes lays the shape out at zero size during
        // a transition; bail before tracing so the renderer doesn't
        // log "clip: empty path".
        guard rect.width > 0, rect.height > 0 else { return path }

        let waterHeight = rect.height * max(0, min(1, fillRatio))
        let waterTopY = rect.height - waterHeight
        let amplitude: CGFloat = 4.0
        let segments = 60

        // Start at bottom-left, go up to wavy top, across, and
        // down to bottom-right.
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: waterTopY))

        for i in 0...segments {
            let progress = Double(i) / Double(segments)
            let x = rect.width * CGFloat(progress)
            let waveA = sin(progress * .pi * 3.0 + time * 1.2)
            let waveB = sin(progress * .pi * 5.5 + time * 1.6 + 1.3)
            let combined = waveA * 0.6 + waveB * 0.4
            let y = waterTopY + amplitude * CGFloat(combined)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct WaterSurfaceHighlight: Shape {

    let fillRatio: CGFloat
    let time: TimeInterval

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0, rect.height > 0 else { return path }

        let waterHeight = rect.height * max(0, min(1, fillRatio))
        let waterTopY = rect.height - waterHeight
        let amplitude: CGFloat = 4.0
        let segments = 60

        path.move(to: CGPoint(x: 0, y: waterTopY))
        for i in 0...segments {
            let progress = Double(i) / Double(segments)
            let x = rect.width * CGFloat(progress)
            let waveA = sin(progress * .pi * 3.0 + time * 1.2)
            let waveB = sin(progress * .pi * 5.5 + time * 1.6 + 1.3)
            let combined = waveA * 0.6 + waveB * 0.4
            let y = waterTopY + amplitude * CGFloat(combined)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

#if DEBUG
#Preview("80% — 4 of 5") {
    WaterFillBackdrop(
        fillRatio: 0.8,
        color: Color(red: 0.79, green: 0.25, blue: 0.38),
        glow: Color(red: 0.79, green: 0.25, blue: 0.38).opacity(0.20)
    )
    .frame(width: 320, height: 380)
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
}

#Preview("50% — 2 of 4") {
    WaterFillBackdrop(
        fillRatio: 0.5,
        color: Color(red: 0.62, green: 0.34, blue: 0.42),
        glow: Color(red: 0.62, green: 0.34, blue: 0.42).opacity(0.20)
    )
    .frame(width: 320, height: 380)
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
}
#endif
