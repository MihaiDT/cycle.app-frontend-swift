import SwiftUI

// MARK: - HRV by Phase Section
//
// Apple Health–style metric card with the by-phase bar chart. Header
// hero pairs the latest reading with a delta against the current
// phase's average so the headline reads "26 ms / −17 vs menstrual
// avg" rather than the bare value.

struct HRVPhaseSection: View {
    let metric: BodySignalMetric?
    let phase: CyclePhase?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BodySignalsReadingSection(kind: .hrv, metric: metric)

            BodySignalsChartCard(
                title: "Heart rate variability",
                iconName: BodySignalMetric.Kind.hrv.outlineSymbol,
                value: valueText,
                delta: deltaText,
                footnote: "HRV shifts with your cycle – higher in follicular, usually lower in luteal. Bigger bar = calmer nervous system for that phase.",
                infoCopy: "HRV is the time variation between your heartbeats, measured in milliseconds (ms) by your Apple Watch. Higher numbers usually mean a calmer, more recovered nervous system; lower can signal stress or under-recovery. The chart shows your average HRV for each cycle phase, with a dashed line marking your overall average across the four phases. cycle.app reads this directly from Apple Health and never sends it anywhere."
            ) {
                chartContent
            }
        }
    }

    // MARK: - Chart content

    @ViewBuilder
    private var chartContent: some View {
        if let metric, metric.hasData, !metric.byPhase.isEmpty {
            HRVPhaseChart(metric: metric)
        } else {
            BodySignalsEmptyChart(
                message: "Need a few cycles of overnight HRV readings to show a phase breakdown."
            )
        }
    }

    // MARK: - Header value & delta

    private var valueText: String? {
        guard let m = metric, m.hasData, let latest = m.latest?.value else { return nil }
        return String(format: "%.0f ms", latest)
    }

    private var deltaText: String? {
        guard let m = metric, m.hasData,
              let latest = m.latest?.value,
              let phase,
              let phaseAvg = m.byPhase[phase] else { return nil }
        let delta = latest - phaseAvg
        let direction = delta >= 0 ? "above" : "below"
        return String(format: "%.0f ms %@ %@ average", abs(delta), direction, phase.displayName.lowercased())
    }
}
