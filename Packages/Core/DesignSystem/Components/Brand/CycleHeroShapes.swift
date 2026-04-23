import SwiftUI
import UIKit

// MARK: - Cycle Hero — Shapes & Effects
//
// Animated shapes and modifiers used by the hero chrome — split out
// so CycleHeroView.swift can focus on layout + state. Visibility left
// at fileprivate on helpers and private on internal types since they
// are consumed only by CycleHeroView.swift in the same module.


// MARK: - Animated Wave Slash Shape

/// Rectangle with an animated sine-wave bottom edge. The wave drifts
/// horizontally over time via `wavePhase`, with `slashHeight` controlling
/// the wave amplitude. When `blobMorph` > 0, extra noise frequencies kick
/// in and the amplitude boosts — the gentle wave transforms into an organic
/// chaotic blob, then morphs back when the sync completes.
// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(0, phase - 0.15)),
                        .init(color: .white.opacity(0.4), location: max(0, phase)),
                        .init(color: .clear, location: min(1, phase + 0.15)),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(content)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

// MARK: - Wave Shape

struct WaveSlashShape: Shape {
    var slashHeight: CGFloat
    var wavePhase: CGFloat
    /// 0 = gentle wave, 1 = chaotic blob morph
    var blobMorph: CGFloat = 0

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(slashHeight, wavePhase), blobMorph) }
        set {
            slashHeight = newValue.first.first
            wavePhase = newValue.first.second
            blobMorph = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let baseY = rect.height - slashHeight

        path.move(to: .zero)
        path.addLine(to: CGPoint(x: w, y: 0))

        // Breathing pulse during blob morph — slow swell
        let breathe = 1.0 + sin(wavePhase * 0.5) * 0.15 * blobMorph

        // Wave bottom edge — sampled every 2pt for smoothness
        let steps = max(Int(w / 2), 1)
        for i in stride(from: steps, through: 0, by: -1) {
            let x = w * CGFloat(i) / CGFloat(steps)
            let normalizedX = x / w

            // Base waves (always active) — gentle, low frequency
            let wave1 = sin(normalizedX * .pi * 2.0 + wavePhase) * 0.6
            let wave2 = sin(normalizedX * .pi * 3.5 + wavePhase * 0.7) * 0.4

            // Blob: smooth low-frequency undulations, large amplitude
            let blob1 = sin(normalizedX * .pi * 1.2 + wavePhase * 1.4) * 0.7 * blobMorph
            let blob2 = cos(normalizedX * .pi * 2.3 - wavePhase * 0.9) * 0.5 * blobMorph

            let combined = (wave1 + wave2 + blob1 + blob2) * breathe
            let y = baseY + slashHeight * combined
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Double Clamping

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

// MARK: - Chat bubble shape
//
// iMessage-style speech bubble with a tail curving out of the
// bottom-left corner toward the speaker (Nyra on the hero). The body
// is inset by `tailSize` on the left so the tail has room to curve
// without clipping the content.

struct ChatBubble: Shape {
    let radius: CGFloat
    let tailSize: CGFloat

    init(radius: CGFloat = 20, tailSize: CGFloat = 12) {
        self.radius = radius
        self.tailSize = tailSize
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Reserve a little breathing room at the bottom so the tail
        // can droop naturally below the body instead of sitting flat
        // on the rect's edge. Content padding in the caller should
        // match this so nothing collides with the tail.
        let tailDrop: CGFloat = tailSize * 0.45
        let leftInset = tailSize * 0.7

        let body = CGRect(
            x: leftInset,
            y: 0,
            width: rect.width - leftInset,
            height: rect.height - tailDrop
        )
        let r = min(min(body.width / 2, body.height / 2), radius)

        // Top-left of body
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        // Top edge → TR corner
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        p.addArc(
            center: CGPoint(x: body.maxX - r, y: body.minY + r),
            radius: r,
            startAngle: .degrees(-90), endAngle: .degrees(0),
            clockwise: false
        )
        // Right edge → BR corner
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        p.addArc(
            center: CGPoint(x: body.maxX - r, y: body.maxY - r),
            radius: r,
            startAngle: .degrees(0), endAngle: .degrees(90),
            clockwise: false
        )
        // Bottom edge → start of tail (short of the BL arc)
        p.addLine(to: CGPoint(x: body.minX + r * 0.9, y: body.maxY))

        // Tail — two mirrored curves.
        //
        // Out-curve: convex, from the bottom edge down-left to the tip,
        // with a control point pulled BELOW body.maxY so the belly
        // bulges naturally instead of running flat along the edge.
        let tipX: CGFloat = rect.minX + 2
        let tipY = body.maxY + tailDrop
        p.addQuadCurve(
            to: CGPoint(x: tipX, y: tipY),
            control: CGPoint(x: body.minX * 0.35, y: body.maxY + tailDrop * 1.15)
        )
        // In-curve: concave, from the tip curling back up into the
        // body's left edge. Control point pulled INSIDE the bubble
        // (above-right of the endpoint) so the curl is soft, not sharp.
        let reentryY = body.maxY - r * 0.65
        p.addQuadCurve(
            to: CGPoint(x: body.minX, y: reentryY),
            control: CGPoint(x: body.minX * 0.95, y: body.maxY - r * 0.05)
        )

        // Left edge → TL corner
        p.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        p.addArc(
            center: CGPoint(x: body.minX + r, y: body.minY + r),
            radius: r,
            startAngle: .degrees(180), endAngle: .degrees(-90),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }
}

#Preview("Menstrual Day 2") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CycleHeroView(
            cycle: CycleContext(
                cycleDay: 2,
                cycleLength: 28,
                bleedingDays: 5,
                cycleStartDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                currentPhase: .menstrual,
                nextPeriodIn: nil,
                fertileWindowActive: false,
                periodDays: [],
                predictedDays: []
            ),
            selectedDate: .constant(nil),
            onEditPeriod: {},
            onCalendarTapped: {}
        )
        .padding(.horizontal, 16)
    }
}

#Preview("Collapsed") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        VStack {
            CycleHeroView(
                cycle: CycleContext(
                    cycleDay: 14,
                    cycleLength: 28,
                    bleedingDays: 5,
                    cycleStartDate: Calendar.current.date(byAdding: .day, value: -13, to: Date())!,
                    currentPhase: .ovulatory,
                    nextPeriodIn: 15,
                    fertileWindowActive: true,
                    periodDays: [],
                    predictedDays: []
                ),
                selectedDate: .constant(nil),
                onEditPeriod: {},
                onCalendarTapped: {},
                collapseProgress: 1.0
            )
            .padding(.horizontal, 16)
            Spacer()
        }
    }
}
