import SwiftUI

// MARK: - Cycle Trend Detail Block
//
// Renders the metrics for a single cycle picked on the bar chart
// above. Sits inside the same `CycleTrendCard` surface beneath the
// chart and re-keys whenever the user taps a different bar — the
// big number animates via the numeric content transition, the
// secondary metric row swaps in fresh values without re-laying
// the row.
//
// Three secondary metrics:
//   • Variation — signed delta vs. running average
//   • Range    — sits inside the typical 21–35d window or not
//   • Position — index within the visible window (e.g. "4 of 6")
//
// The block is intentionally minimal so the chart's selected bar
// keeps the visual spotlight; the detail row is the explainer
// caption, not a competing surface.

struct CycleTrendDetailBlock: View, Equatable {
    let cycleLength: Int
    let startDate: Date
    let averageDays: Int
    let positionIndex: Int
    let positionTotal: Int
    let isInTypicalRange: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading
            metrics
        }
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(cycleLength)")
                    .font(.raleway("Bold", size: 44, relativeTo: .largeTitle))
                    .tracking(-1.2)
                    .foregroundStyle(DesignColors.text)
                    .contentTransition(.numericText())
                Text("days")
                    .font(.raleway("Medium", size: 18, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Text(subtitle)
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .contentTransition(.opacity)
        }
    }

    private var subtitle: String {
        "Cycle started \(formattedStartDate)"
    }

    // MARK: - Metric row

    private var metrics: some View {
        HStack(alignment: .top, spacing: 0) {
            metricCell(label: "vs Average", value: variationValue, accent: variationAccent)
            divider
            metricCell(label: "Range", value: rangeValue, accent: rangeAccent)
            divider
            metricCell(label: "Position", value: positionValue, accent: DesignColors.text)
        }
        .padding(.top, 4)
    }

    private func metricCell(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.raleway("Bold", size: 20, relativeTo: .title3))
                .tracking(-0.4)
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(label)
                .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.text.opacity(0.08))
            .frame(width: 1, height: 32)
            .padding(.horizontal, 4)
    }

    // MARK: - Derived values

    private var variationDelta: Int { cycleLength - averageDays }

    private var variationValue: String {
        if variationDelta == 0 { return "On avg" }
        return variationDelta > 0 ? "+\(variationDelta)d" : "\(variationDelta)d"
    }

    private var variationAccent: Color {
        if variationDelta == 0 { return DesignColors.text }
        return abs(variationDelta) <= 2
            ? DesignColors.text
            : DesignColors.accentHoneyText
    }

    private var rangeValue: String {
        isInTypicalRange ? "Typical" : "Outside"
    }

    private var rangeAccent: Color {
        isInTypicalRange ? DesignColors.accentWarmText : DesignColors.accentHoneyText
    }

    private var positionValue: String {
        "\(positionIndex)/\(positionTotal)"
    }

    private var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: startDate)
    }
}
