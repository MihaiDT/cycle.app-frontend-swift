import SwiftUI

// MARK: - Cycle Trend Detail Block
//
// Renders the metrics for a single cycle picked on the bar chart
// above. Sits inside the same `CycleTrendCard` surface beneath the
// chart and re-keys whenever the user taps a different bar — the
// big number animates via the numeric content transition; the
// editorial summary sentence swaps fresh values via the same
// numericText pipeline so letters and digits share one transition.
//
// The block is intentionally minimal so the chart's selected bar
// keeps the visual spotlight; the summary sentence is the
// explainer caption, not a competing surface.
//
// Replaced the previous "vs Average / Range" metric grid (May 2026)
// with a single editorial sentence per the wellness voice rule:
// less data, more meaning. The grid was clinically scannable but
// read as another tile of stats; the sentence reframes the same
// facts as a soft observation ("31 days. One over your average,
// well within typical.").

struct CycleTrendDetailBlock: View, Equatable {
    let cycleLength: Int
    let startDate: Date
    let averageDays: Int
    let isInTypicalRange: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            summarySentence
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
                    .contentTransition(.numericText(value: Double(cycleLength)))
                Text("days")
                    .font(.raleway("Medium", size: 18, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .contentTransition(.numericText())
            }

            // Cross-fade through `.numericText()` so the date string
            // ("Cycle started Mar 24") swaps with the same Apple-Health
            // feel as the headline number — letters and digits share
            // one visual language across the block.
            Text(subtitle)
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .contentTransition(.numericText())
        }
    }

    private var subtitle: String {
        "Cycle started \(formattedStartDate)"
    }

    // MARK: - Summary sentence

    /// One editorial sentence that synthesises the variation delta
    /// and range typicality. Replaces the older two-cell grid
    /// ("vs Average · Range"). Swaps cleanly between bar selections
    /// via `.numericText()` so digits inside the sentence carry the
    /// same Apple-Health-style transition as the headline number.
    private var summarySentence: some View {
        Text(summaryCopy)
            .font(AppTypography.linkLabel)
            .tracking(-0.1)
            .foregroundStyle(DesignColors.textSecondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentTransition(.numericText())
    }

    // MARK: - Derived copy

    private var variationDelta: Int { cycleLength - averageDays }

    /// Editorial sentence built from delta + range. Branches:
    ///   • on average + typical → "Right on your average of N, well within typical."
    ///   • small delta + typical → "M day(s) under/over your average of N, still in typical range."
    ///   • outside range → "M day(s) under/over your average. Outside your typical range — worth a note."
    private var summaryCopy: String {
        let absDelta = abs(variationDelta)
        let unit = absDelta == 1 ? "day" : "days"

        if variationDelta == 0 {
            return isInTypicalRange
                ? "Right on your average of \(averageDays). Well within typical."
                : "Right on your average of \(averageDays). Outside your typical range — worth a note."
        }

        let direction = variationDelta > 0 ? "over" : "under"
        let deltaPhrase = "\(absDelta) \(unit) \(direction) your average of \(averageDays)"

        if isInTypicalRange {
            return "\(deltaPhrase). Still in typical range."
        }
        return "\(deltaPhrase). Outside your typical range — worth a note."
    }

    private var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: startDate)
    }
}
