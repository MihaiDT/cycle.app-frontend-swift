import Charts
import SwiftUI

// MARK: - Wrist Temperature Chart
//
// Nightly wrist-temp series + a dashed baseline rule. Area mark is a
// warm-accent gradient so the graph reads as a soft silhouette
// instead of a medical stat trace. Y domain clamps tight to the
// observed range so small per-phase lifts (~0.2°C) stay visible.

struct WristTempChart: View {
    let metric: BodySignalMetric

    var body: some View {
        Chart {
            ForEach(metric.samples) { sample in
                LineMark(
                    x: .value("Day", sample.date),
                    y: .value("Temp", sample.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(DesignColors.accentWarm)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                AreaMark(
                    x: .value("Day", sample.date),
                    y: .value("Temp", sample.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignColors.accentWarm.opacity(0.35),
                            DesignColors.accentWarm.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            if let baseline = metric.baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                    .foregroundStyle(DesignColors.text.opacity(0.35))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Baseline")
                            .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
            }
        }
        .chartYScale(domain: domain)
        .frame(height: 160)
    }

    /// Zoom tight to the observed range with a ¼-width breathing
    /// pad so minor fluctuations read as real shifts on the curve.
    private var domain: ClosedRange<Double> {
        let values = metric.samples.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 35...37 }
        let padding = max(0.2, (hi - lo) * 0.25)
        return (lo - padding)...(hi + padding)
    }
}
