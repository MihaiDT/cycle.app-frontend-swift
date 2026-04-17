import SwiftUI

// MARK: - CyclePhase Color Extensions

extension CyclePhase {
    var orbitColor: Color {
        switch self {
        case .menstrual: Color(red: 0.79, green: 0.25, blue: 0.38)
        case .follicular: Color(red: 0.36, green: 0.72, blue: 0.65)
        case .ovulatory: Color(red: 0.91, green: 0.66, blue: 0.22)
        case .luteal: Color(red: 0.55, green: 0.49, blue: 0.78)
        case .late: Color(red: 0.65, green: 0.62, blue: 0.60)
        }
    }

    var glowColor: Color {
        switch self {
        case .menstrual: Color(red: 0.66, green: 0.19, blue: 0.31)
        case .follicular: Color(red: 0.24, green: 0.60, blue: 0.53)
        case .ovulatory: Color(red: 0.80, green: 0.55, blue: 0.13)
        case .luteal: Color(red: 0.43, green: 0.38, blue: 0.69)
        case .late: Color(red: 0.55, green: 0.52, blue: 0.50)
        }
    }

    var gradientColors: [Color] {
        [orbitColor, glowColor]
    }
}

// MARK: - Celestial Mini Bar

public struct CelestialMiniBar: View {
    public let cycleDay: Int
    public let cycleLength: Int
    public let phase: String
    public let nextPeriodIn: Int?
    public let fertileWindowActive: Bool

    public init(
        cycleDay: Int,
        cycleLength: Int,
        phase: String,
        nextPeriodIn: Int?,
        fertileWindowActive: Bool
    ) {
        self.cycleDay = cycleDay
        self.cycleLength = cycleLength
        self.phase = phase
        self.nextPeriodIn = nextPeriodIn
        self.fertileWindowActive = fertileWindowActive
    }

    private var currentPhase: CyclePhase { CyclePhase(rawValue: phase) ?? .follicular }
    private var fillFraction: Double { Double(cycleDay) / Double(max(cycleLength, 1)) }
    private var orbAngle: Double { fillFraction * 2 * .pi - .pi / 2 }

    public var body: some View {
        HStack(spacing: 14) {
            miniOrbit
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(currentPhase.orbitColor).frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text("Day \(cycleDay)")
                        .font(.raleway("Bold", size: 15, relativeTo: .callout))
                        .foregroundColor(DesignColors.text)
                    Text("·").foregroundColor(DesignColors.textSecondary)
                        .accessibilityHidden(true)
                    Text(currentPhase.displayName)
                        .font(.raleway("Medium", size: 15, relativeTo: .callout))
                        .foregroundColor(currentPhase.orbitColor)
                }
                if let n = nextPeriodIn, n > 0 {
                    Text("\(n)d until period")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.textSecondary)
                } else if fertileWindowActive {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text("Fertile window").font(.raleway("Regular", size: 12, relativeTo: .caption))
                    }
                    .foregroundColor(CyclePhase.ovulatory.glowColor)
                } else {
                    Text(currentPhase.insight)
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            LinearGradient(
                                colors: [currentPhase.orbitColor.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }

    private var miniOrbit: some View {
        ZStack {
            Circle().stroke(DesignColors.textSecondary.opacity(0.12), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: fillFraction)
                .stroke(
                    currentPhase.orbitColor.opacity(0.6),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(currentPhase.orbitColor)
                .frame(width: 5, height: 5)
                .shadow(color: currentPhase.glowColor.opacity(0.7), radius: 3)
                .offset(x: cos(orbAngle) * 17, y: sin(orbAngle) * 17)
            Text("\(cycleDay)")
                .font(.raleway("Bold", size: 13, relativeTo: .caption))
                .foregroundStyle(
                    LinearGradient(
                        colors: [currentPhase.orbitColor.opacity(0.85), currentPhase.glowColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

private func previewCycle(_ day: Int, _ phase: CyclePhase, _ nextPeriod: Int?, _ fertile: Bool) -> CycleContext {
    CycleContext(
        cycleDay: day,
        cycleLength: 28,
        bleedingDays: 5,
        cycleStartDate: Calendar.current.date(byAdding: .day, value: -(day - 1), to: Date())!,
        currentPhase: phase,
        nextPeriodIn: nextPeriod,
        fertileWindowActive: fertile,
        periodDays: [],
        predictedDays: []
    )
}

#Preview("Follicular - Day 8") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(cycle: previewCycle(8, .follicular, 21, false), exploringDay: .constant(nil))
    }
}

#Preview("Ovulatory - Day 14") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(cycle: previewCycle(14, .ovulatory, 14, true), exploringDay: .constant(nil))
    }
}

#Preview("Menstrual - Day 2") {
    ZStack {
        DesignColors.background.ignoresSafeArea()
        CelestialCycleView(cycle: previewCycle(2, .menstrual, nil, false), exploringDay: .constant(nil))
    }
}
