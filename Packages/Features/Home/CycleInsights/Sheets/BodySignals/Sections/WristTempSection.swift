import SwiftUI

// MARK: - Wrist Temperature Section
//
// Apple Health–style metric card: icon + caps title row, big value
// or "No Data", small delta caption, chart below, footnote at the
// bottom.

struct WristTempSection: View {
    let metric: BodySignalMetric?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Reading first: when the chart has no data yet
            // ("No Data" + "Wear your Apple Watch overnight…"),
            // the empty chart card reads as noise. Putting the
            // reading above the card means the user gets context
            // first regardless of data state. Once data arrives
            // the order still works — read the explanation, then
            // the numbers.
            BodySignalsReadingSection(kind: .wristTemperature, metric: metric)

            BodySignalsChartCard(
                title: "Wrist temperature",
                iconName: BodySignalMetric.Kind.wristTemperature.outlineSymbol,
                value: valueText,
                delta: deltaText,
                footnote: "Sampled by your watch while you sleep. The baseline is your rolling average across this window.",
                infoCopy: "Wrist temperature is the overnight skin temperature reading from your Apple Watch, captured while you sleep. cycle.app shows differences from your personal baseline – small shifts of 0.1–0.5° can hint at ovulation, illness, or hormonal changes around your cycle. The baseline is your rolling average across this window, not a clinical reference. cycle.app reads this directly from Apple Health and never sends it anywhere."
            ) {
                chartContent
            }
        }
    }

    // MARK: - Chart content

    @ViewBuilder
    private var chartContent: some View {
        if let metric, metric.hasData {
            WristTempChart(metric: metric)
        } else {
            BodySignalsEmptyChart(message: emptyMessage)
        }
    }

    private var emptyMessage: String {
        guard let metric else {
            return "No wrist temperature samples in this window yet."
        }
        return metric.awaitingFirstSample
            ? "Wear your Apple Watch overnight to start collecting wrist temperature."
            : "No wrist temperature samples in this window yet."
    }

    // MARK: - Header value & delta

    private var valueText: String? {
        guard let m = metric, m.hasData, let latest = m.latest?.value else { return nil }
        return String(format: "%.2f%@", latest, m.unit)
    }

    private var deltaText: String? {
        guard let m = metric, m.hasData,
              let delta = m.latestDelta else { return nil }
        if abs(delta) < 0.005 { return "On your baseline" }
        let direction = delta < 0 ? "below" : "above"
        return String(format: "%.2f%@ %@ your baseline", abs(delta), m.unit, direction)
    }
}
