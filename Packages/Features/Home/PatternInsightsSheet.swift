import SwiftUI

// MARK: - Pattern Insights Sheet

struct PatternInsightsSheet: View {
    let summaries: [JourneyCycleSummary]
    let insight: JourneyInsight?
    @Environment(\.dismiss) private var dismiss

    private var completed: [JourneyCycleSummary] {
        summaries.filter { !$0.isCurrentCycle }
    }

    private var cycleLengths: [Int] { completed.map(\.cycleLength) }
    private var avgLength: Double { cycleLengths.isEmpty ? 0 : Double(cycleLengths.reduce(0, +)) / Double(cycleLengths.count) }
    private var shortestCycle: Int { cycleLengths.min() ?? 0 }
    private var longestCycle: Int { cycleLengths.max() ?? 0 }
    private var avgBleeding: Double {
        let vals = completed.map(\.bleedingDays)
        return vals.isEmpty ? 0 : Double(vals.reduce(0, +)) / Double(vals.count)
    }

    private let warmBrown = DesignColors.warmBrown

    private static let chartMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Capsule()
                    .fill(DesignColors.structure.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                VStack(spacing: 6) {
                    Text("Your Pattern")
                        .font(.raleway("Bold", size: 28, relativeTo: .title))
                        .foregroundStyle(warmBrown)

                    Text("Based on \(completed.count) completed cycles")
                        .font(.raleway("Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                }

                cycleLengthChart
                statsGrid

                if let insight {
                    regularityCard(insight: insight)
                }

                phasesCard

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, AppLayout.horizontalPadding)
        }
        .background(DesignColors.journeyBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Cycle Length Chart

    private var cycleLengthChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cycle Length")
                .font(.raleway("SemiBold", size: 16, relativeTo: .headline))
                .foregroundStyle(warmBrown)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(completed.enumerated()), id: \.element.id) { _, summary in
                    VStack(spacing: 6) {
                        let maxH: CGFloat = 100
                        let normalized = CGFloat(summary.cycleLength - 20) / 20.0
                        let barH = max(20, min(maxH, normalized * maxH))

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [warmBrown.opacity(0.6), warmBrown.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: barH)

                        Text("\(summary.cycleLength)")
                            .font(.raleway("Bold", size: 13, relativeTo: .caption))
                            .foregroundStyle(warmBrown)

                        Text(Self.chartMonthFormatter.string(from: summary.startDate))
                            .font(.raleway("Regular", size: 10, relativeTo: .caption2))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140)

            HStack(spacing: 4) {
                Rectangle()
                    .fill(DesignColors.accentWarm.opacity(0.5))
                    .frame(width: 16, height: 2)
                Text("avg \(String(format: "%.0f", avgLength)) days")
                    .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
        .padding(AppLayout.spacingL)
        .modifier(GlassCardModifier())
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(value: String(format: "%.0f", avgLength), unit: "days", label: "Average cycle", icon: "arrow.left.arrow.right")
            statCard(value: String(format: "%.0f", avgBleeding), unit: "days", label: "Average period", icon: "drop.fill")
        }
    }

    private func statCard(value: String, unit: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignColors.accentWarm)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.raleway("Bold", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(warmBrown)
                Text(unit)
                    .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Text(label)
                .font(.raleway("Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppLayout.spacingL)
        .modifier(GlassCardModifier())
    }

    // MARK: - Regularity Card

    private func regularityCard(insight: JourneyInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignColors.accentWarm)
                Text("Regularity")
                    .font(.raleway("SemiBold", size: 16, relativeTo: .headline))
                    .foregroundStyle(warmBrown)
            }

            VStack(spacing: 8) {
                GeometryReader { geo in
                    let width = geo.size.width

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignColors.structure.opacity(0.12))
                            .frame(height: 6)

                        let startPct = CGFloat(shortestCycle - 20) / 20.0
                        let endPct = CGFloat(longestCycle - 20) / 20.0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [DesignColors.accentWarm, warmBrown.opacity(0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, (endPct - startPct) * width), height: 6)
                            .offset(x: startPct * width)

                        let avgPct = CGFloat(avgLength - 20) / 20.0
                        Circle()
                            .fill(.white)
                            .frame(width: 10, height: 10)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: avgPct * width - 5)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(shortestCycle)d shortest")
                        .font(.raleway("Regular", size: 11, relativeTo: .caption2))
                        .foregroundStyle(DesignColors.textSecondary)
                    Spacer()
                    Text("\(longestCycle)d longest")
                        .font(.raleway("Regular", size: 11, relativeTo: .caption2))
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }

            HStack(spacing: 4) {
                let trendIcon = switch insight.trendDirection {
                case .shortening: "arrow.down.right"
                case .stable: "arrow.right"
                case .lengthening: "arrow.up.right"
                }
                Image(systemName: trendIcon)
                    .font(.system(size: 11, weight: .medium))
                Text("Your cycles are \(insight.trendDirection.rawValue)")
                    .font(.raleway("Medium", size: 13, relativeTo: .caption))
            }
            .foregroundStyle(DesignColors.textSecondary)
        }
        .padding(AppLayout.spacingL)
        .modifier(GlassCardModifier())
    }

    // MARK: - Phases Card

    private var phasesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Phases")
                .font(.raleway("SemiBold", size: 16, relativeTo: .headline))
                .foregroundStyle(warmBrown)

            let totalDays = Int(avgLength.rounded())
            let avgBd = CycleJourneyEngine.phaseBreakdown(
                cycleLength: totalDays,
                bleedingDays: Int(avgBleeding.rounded())
            )

            let phases: [(name: String, days: Int, color: Color)] = [
                ("Menstrual", avgBd.menstrualDays, CyclePhase.menstrual.orbitColor),
                ("Follicular", avgBd.follicularDays, CyclePhase.follicular.orbitColor),
                ("Ovulatory", avgBd.ovulatoryDays, CyclePhase.ovulatory.orbitColor),
                ("Luteal", avgBd.lutealDays, CyclePhase.luteal.orbitColor),
            ]

            ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                HStack(spacing: 10) {
                    Circle()
                        .fill(phase.color)
                        .frame(width: 10, height: 10)

                    Text(phase.name)
                        .font(.raleway("Medium", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)

                    Spacer()

                    Text("~\(phase.days) days")
                        .font(.raleway("Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)

                    let pct = CGFloat(phase.days) / CGFloat(max(1, totalDays))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(phase.color.opacity(0.6))
                        .frame(width: 50 * pct, height: 4)
                }
            }
        }
        .padding(AppLayout.spacingL)
        .modifier(GlassCardModifier())
    }
}
