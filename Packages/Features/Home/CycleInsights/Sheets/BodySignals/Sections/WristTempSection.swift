import SwiftUI

// MARK: - Wrist Temperature Section
//
// Apple Health–style metric card: icon + caps title row, big value
// or "No Data", small delta caption, chart below, footnote at the
// bottom.

struct WristTempSection: View {
    let metric: BodySignalMetric?

    var body: some View {
        BodySignalsChartCard(
            title: "Wrist temperature",
            iconName: BodySignalMetric.Kind.wristTemperature.outlineSymbol,
            value: valueText,
            delta: deltaText,
            footnote: "Sampled by your watch while you sleep. The baseline is your rolling average across this window."
        ) {
            chartContent
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
        let dir = delta >= 0 ? "+" : "−"
        return String(format: "%@%.2f from baseline", dir, abs(delta))
    }
}
