import SwiftUI

// MARK: - Resting Heart Rate Section
//
// Apple Health–style metric card with the rolling RHR line. Header
// hero leads with the latest reading and the delta vs the rolling
// baseline.

struct RestingHRSection: View {
    let metric: BodySignalMetric?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BodySignalsReadingSection(kind: .restingHR, metric: metric)

            BodySignalsChartCard(
                title: "Resting heart rate",
                iconName: BodySignalMetric.Kind.restingHR.outlineSymbol,
                value: valueText,
                delta: deltaText,
                footnote: "Resting HR typically creeps up in the days before your period and through the luteal phase. Useful as a soft heads-up.",
                infoCopy: "Resting heart rate is the number of times your heart beats per minute (bpm) when your body is at rest – captured by your Apple Watch during calm moments. Higher than usual can hint at stress, illness, or an oncoming period; lower means you're well-rested. The dashed line on the chart is your personal baseline, the rolling average across this window. cycle.app reads this directly from Apple Health and never sends it anywhere."
            ) {
                chartContent
            }
        }
    }

    // MARK: - Chart content

    @ViewBuilder
    private var chartContent: some View {
        if let metric, metric.hasData {
            RestingHRChart(metric: metric)
        } else {
            BodySignalsEmptyChart(
                message: "No resting heart rate data yet. Wear your watch during the day."
            )
        }
    }

    // MARK: - Header value & delta

    private var valueText: String? {
        guard let m = metric, m.hasData, let latest = m.latest?.value else { return nil }
        return String(format: "%.0f bpm", latest)
    }

    private var deltaText: String? {
        guard let m = metric, m.hasData,
              let delta = m.latestDelta else { return nil }
        if abs(delta) < 0.5 { return "On your baseline" }
        let direction = delta < 0 ? "below" : "above"
        return String(format: "%.0f bpm %@ your baseline", abs(delta), direction)
    }
}
