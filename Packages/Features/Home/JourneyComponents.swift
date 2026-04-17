import SwiftUI

// MARK: - Animated Blob Background

struct JourneyAnimatedBackground: View {
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            DesignColors.journeyBackground

            Circle()
                .fill(DesignColors.journeyBlobWarm.opacity(0.3))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: animate ? -60 : -90, y: animate ? -80 : -40)

            Circle()
                .fill(DesignColors.journeyBlobAmber.opacity(0.25))
                .frame(width: 240, height: 240)
                .blur(radius: 65)
                .offset(x: animate ? 80 : 50, y: animate ? -20 : -60)

            Circle()
                .fill(DesignColors.journeyBlobLavender.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 75)
                .offset(x: animate ? 20 : -30, y: animate ? 120 : 180)

            Circle()
                .fill(DesignColors.journeyBlobHoney.opacity(0.2))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: animate ? 70 : 100, y: animate ? 300 : 250)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Glass Modifiers

/// Glass circle button — iOS 26+ Liquid Glass, fallback to material
struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(in: .circle)
        } else {
            content
                .background(Circle().fill(.ultraThinMaterial))
                .clipShape(Circle())
        }
    }
}

/// Glass effect with iOS 26+ Liquid Glass, fallback to white card + shadows
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(in: .rect(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                        .fill(.white)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }
}

// MARK: - Connector Line

struct ConnectorLine: View {
    let fromLeft: Bool
    let toLeft: Bool
    let isDashed: Bool
    let lineHeight: CGFloat = 65

    var body: some View {
        Canvas { context, size in
            let cardInset: CGFloat = 50
            let startX = fromLeft ? size.width * 0.3 + cardInset : size.width * 0.7 - cardInset
            let endX = toLeft ? size.width * 0.3 + cardInset : size.width * 0.7 - cardInset

            var path = Path()
            path.move(to: CGPoint(x: startX, y: 0))
            path.addCurve(
                to: CGPoint(x: endX, y: size.height),
                control1: CGPoint(x: startX, y: size.height * 0.7),
                control2: CGPoint(x: endX, y: size.height * 0.3)
            )

            let style = isDashed
                ? StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
                : StrokeStyle(lineWidth: 2.5, lineCap: .round)

            let color = isDashed
                ? DesignColors.journeyConnectorDashed.opacity(0.3)
                : DesignColors.journeyConnectorSolid.opacity(0.5)

            context.stroke(path, with: .color(color), style: style)
        }
        .frame(height: lineHeight)
        .overlay(alignment: .top) {
            GeometryReader { geo in
                let cardInset: CGFloat = 50
                let x = fromLeft ? geo.size.width * 0.3 + cardInset : geo.size.width * 0.7 - cardInset

                Circle()
                    .fill(DesignColors.journeyConnectorDot)
                    .frame(width: 10, height: 10)
                    .position(x: x, y: 0)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Aria Journey Nudge

struct AriaJourneyNudge: View {
    let missedMonths: [MissedMonth]
    let onLogTapped: () -> Void

    private var message: String {
        if missedMonths.count == 1 {
            return "Your \(missedMonths[0].name) chapter is still unwritten. Tap to complete your story."
        }
        let months = missedMonths.map(\.name).joined(separator: " & ")
        return "Your \(months) chapters are missing. Log them to keep your journey whole."
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Text("A")
                    .font(.raleway("Bold", size: 13, relativeTo: .caption))
                    .foregroundStyle(.white)
            }

            Button(action: onLogTapped) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(message)
                        .font(.raleway("Regular", size: 16, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text("Log period")
                            .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(DesignColors.accentWarm)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DesignColors.background)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Milestone Badge

struct MilestoneBadge: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
        }
        .foregroundStyle(DesignColors.accentWarm)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Phase Ring

struct PhaseRing: View {
    let breakdown: JourneyCycleSummary.PhaseBreakdown
    let cycleLength: Int
    let progress: CGFloat?
    let isFuture: Bool
    var isCurrentCycle: Bool = false

    private let ringSize: CGFloat = 90
    private let lineWidth: CGFloat = 4
    private let gapDegrees: Double = 3.5

    private var segments: [(days: Int, color: Color)] {
        [
            (breakdown.menstrualDays, CyclePhase.menstrual.orbitColor),
            (breakdown.follicularDays, CyclePhase.follicular.orbitColor),
            (breakdown.ovulatoryDays, CyclePhase.ovulatory.orbitColor),
            (breakdown.lutealDays, CyclePhase.luteal.orbitColor),
        ]
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    DesignColors.structure.opacity(isFuture ? 0.08 : 0.1),
                    style: isFuture
                        ? StrokeStyle(lineWidth: lineWidth - 1, dash: [3, 3])
                        : StrokeStyle(lineWidth: lineWidth - 1)
                )
                .frame(width: ringSize, height: ringSize)

            if !isFuture { phaseArcs }

            if let progress, !isFuture {
                progressDot(progress: progress)
            }
        }
        .frame(width: ringSize + 10, height: ringSize + 10)
    }

    private var phaseArcs: some View {
        let total = segments.reduce(0) { $0 + $1.days }
        guard total > 0 else { return AnyView(EmptyView()) }

        let totalGap = gapDegrees * Double(segments.filter { $0.days > 0 }.count)
        let available = 360.0 - totalGap
        var startAngle = -90.0

        var arcs: [(start: Double, end: Double, color: Color)] = []
        for seg in segments where seg.days > 0 {
            let sweep = available * Double(seg.days) / Double(total)
            arcs.append((startAngle, startAngle + sweep, seg.color))
            startAngle += sweep + gapDegrees
        }

        let maxAngle: Double? = progress.map { -90.0 + Double($0) * 360.0 }

        return AnyView(
            ZStack {
                ForEach(Array(arcs.enumerated()), id: \.offset) { _, arc in
                    let clippedEnd = maxAngle.map { min(arc.end, $0) } ?? arc.end
                    if clippedEnd > arc.start {
                        Circle()
                            .trim(
                                from: CGFloat((arc.start + 90) / 360),
                                to: CGFloat((clippedEnd + 90) / 360)
                            )
                            .stroke(
                                arc.color.opacity(isCurrentCycle ? 0.55 : 0.35),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                            )
                            .frame(width: ringSize, height: ringSize)
                            .rotationEffect(.degrees(-90))
                    }
                }
            }
        )
    }

    private func progressDot(progress: CGFloat) -> some View {
        let angle = -(.pi / 2) + (.pi * 2 * progress)
        let r = ringSize / 2
        let x = cos(angle) * r
        let y = sin(angle) * r

        return Circle()
            .fill(.white)
            .frame(width: 7, height: 7)
            .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
            .offset(x: x, y: y)
    }
}
