import SwiftUI

// MARK: - Cycle Details Check-Ins Card
//
// Premium per-cycle check-in summary. Three rolling rows (Energy,
// Mood, Sleep) with their averages headlined and the daily dot
// timeline beneath each — same vocabulary as the Cycle History
// dot rows, but scaled up and given numeric anchors so the screen
// reads as a proper detail surface instead of a compact glance.

struct CycleDetailsCheckInsCard: View {
    let timeline: CycleHistoryTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            VStack(spacing: 18) {
                metricRow(metric: .energy)
                divider
                metricRow(metric: .mood)
                divider
                metricRow(metric: .sleep)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignColors.textSecondary)
                Text("DAILY CHECK-INS")
                    .font(AppTypography.cardEyebrow)
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)
            }
            Spacer(minLength: 8)
            Text("\(loggedDayCount) of \(timeline.length) days")
                .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
        }
    }

    private var loggedDayCount: Int {
        timeline.reports.values.filter { $0.energy + $0.mood + $0.sleep > 0 }.count
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
            .frame(height: 1)
    }

    // MARK: - Metric

    private enum Metric {
        case energy, mood, sleep

        var label: String {
            switch self {
            case .energy: return "Energy"
            case .mood:   return "Mood"
            case .sleep:  return "Sleep"
            }
        }

        // Same palette decisions as the Cycle History dot rows so a
        // user who learned the colors there reads them the same way
        // here — honey gold / dusty rose / cocoa dark.
        var tint: Color {
            switch self {
            case .energy: return DesignColors.accentHoneyText
            case .mood:   return DesignColors.accentSecondary
            case .sleep:  return DesignColors.text
            }
        }

        func value(in report: JourneyReportInput) -> Int {
            switch self {
            case .energy: return report.energy
            case .mood:   return report.mood
            case .sleep:  return report.sleep
            }
        }
    }

    @ViewBuilder
    private func metricRow(metric: Metric) -> some View {
        let values = timeline.reports.values
            .map { metric.value(in: $0) }
            .filter { $0 > 0 }
        let avg: Double? = values.isEmpty
            ? nil
            : Double(values.reduce(0, +)) / Double(values.count)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(metric.tint)
                    .frame(width: 8, height: 8)
                Text(metric.label)
                    .font(.raleway("SemiBold", size: 14, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.text)
                Spacer(minLength: 8)
                if let avg {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", avg))
                            .font(.raleway("Bold", size: 18, relativeTo: .title3))
                            .tracking(-0.3)
                            .foregroundStyle(DesignColors.text)
                            .contentTransition(.numericText(value: avg))
                        Text("/ 5")
                            .font(.raleway("Medium", size: 11, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                } else {
                    Text("No data")
                        .font(.raleway("Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }

            dotTimeline(metric: metric)
        }
    }

    // MARK: - Dot timeline

    @ViewBuilder
    private func dotTimeline(metric: Metric) -> some View {
        // Larger, more legible than the Cycle History glance: 7pt
        // dots, 16pt row height, the same alpha-by-value modulation
        // (0.4 → 1.0) so a 5/5 day reads brighter than a 1/5 day
        // without changing color.
        Canvas { ctx, size in
            let length = max(timeline.length, 1)
            let dayWidth = size.width / CGFloat(length)
            let midY = size.height / 2
            let filledColor = metric.tint
            let emptyStrokeColor = DesignColors.text.opacity(0.18)

            for day in 1...length {
                let x = dayWidth * (CGFloat(day) - 0.5)
                if let report = timeline.reports[day], metric.value(in: report) > 0 {
                    let clamped = max(1, min(5, metric.value(in: report)))
                    let alpha = 0.40 + 0.60 * (Double(clamped - 1) / 4.0)
                    let rect = CGRect(x: x - 3.5, y: midY - 3.5, width: 7, height: 7)
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .color(filledColor.opacity(alpha))
                    )
                } else {
                    let rect = CGRect(x: x - 2.5, y: midY - 2.5, width: 5, height: 5)
                    ctx.stroke(
                        Path(ellipseIn: rect),
                        with: .color(emptyStrokeColor),
                        lineWidth: 0.7
                    )
                }
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}
