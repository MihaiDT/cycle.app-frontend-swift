import SwiftUI

// MARK: - Pattern Highlights Card
//
// 2 × 2 grid of `PatternStatTile`s — Apple Health Activity /
// Workout summary idiom translated to cycle.app's warm palette.
// Four insight tiles answer four questions a user actually asks
// about a pattern:
//   1. WHEN does it hit hardest?      → Hits hardest (hero)
//   2. HOW LONG does it last?         → Lasts
//   3. WHAT comes with it?            → Appears with
//   4. WHEN can I expect it next?     → Next likely
//
// The hero tile carries the saturated phase-ink fill so the user
// reads it as the primary takeaway. The other three sit on the
// shared `widgetCardStyle` glass surface so the card matches the
// Cycle Stats / Cycle Detail tile vocabulary across the app.

struct PatternHighlightsCard: View {
    let pattern: DetectedPattern
    let metrics: PatternMetrics

    private var palette: BodyPatternsPalette {
        BodyPatternsPalette.forPhase(pattern.phase)
    }

    private var hasData: Bool { !metrics.cycles.isEmpty }
    private var totalCycles: Int { metrics.cycles.count }

    // MARK: - Hits hardest (hero)

    private var hitsHardestValue: String {
        guard hasData, let day = metrics.mostActiveDay else { return "—" }
        return "Day \(day)"
    }
    private var hitsHardestSubtitle: String {
        guard hasData,
              metrics.mostActiveDayCycleCount > 0,
              totalCycles > 0
        else { return "no clear peak yet" }
        return "in \(metrics.mostActiveDayCycleCount) of \(totalCycles) cycles"
    }
    private var trendDirection: PatternStatTile.TrendDirection? {
        guard hasData else { return nil }
        switch metrics.trend {
        case .strengthening: return .up
        case .easing:        return .down
        case .persisting,
             .justAppearing: return nil
        }
    }

    // MARK: - Intensity (peak severity)
    //
    // Reads peak severity but renders as a descriptive label —
    // a numeric "3 of 5" forces the user to do the math, while
    // "Moderate" / "Strong" tells them the answer immediately.
    // Same idiom as Apple Health Sleep Analysis labels (Light /
    // Deep / Awake) over raw minute counts. Subtitle anchors to
    // "at its peak" so the tile semantic is unambiguous.

    private var intensityValue: String {
        guard hasData, metrics.peakSeverity > 0 else { return "—" }
        switch Int(metrics.peakSeverity.rounded()) {
        case 1:    return "Mild"
        case 2:    return "Mild"
        case 3:    return "Moderate"
        case 4:    return "Strong"
        case 5...: return "Intense"
        default:   return "Mild"
        }
    }
    private var intensitySubtitle: String {
        guard hasData, metrics.peakSeverity > 0 else {
            return "needs severity logs"
        }
        return "across recent cycles"
    }

    // MARK: - Appears with

    private var appearsWithValue: String {
        guard let raw = metrics.coOccurringSymptomRaw,
              let symptom = SymptomType(rawValue: raw)
        else { return "—" }
        return symptom.displayName
    }
    private var appearsWithSubtitle: String {
        guard metrics.coOccurringSymptomRaw != nil,
              metrics.coOccurringSymptomCount > 0,
              totalCycles > 0
        else { return "no clear pairing" }
        return "in \(metrics.coOccurringSymptomCount) of \(totalCycles) cycles"
    }

    // MARK: - Next likely

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    private static let dayOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    private var nextLikelyValue: String {
        guard let window = metrics.nextPredictedWindow else { return "—" }
        let cal = Calendar.current
        let startStr = Self.dayMonthFormatter.string(from: window.lowerBound)
        let sameMonth =
            cal.component(.month, from: window.lowerBound)
            == cal.component(.month, from: window.upperBound)
            && cal.component(.year, from: window.lowerBound)
            == cal.component(.year, from: window.upperBound)
        if sameMonth {
            let endStr = Self.dayOnlyFormatter.string(from: window.upperBound)
            return "\(startStr)–\(endStr)"
        }
        let endStr = Self.dayMonthFormatter.string(from: window.upperBound)
        return "\(startStr)–\(endStr)"
    }
    private var nextLikelySubtitle: String {
        metrics.nextPredictedWindow == nil
            ? "needs more cycles"
            : "in your next cycle"
    }

    // MARK: - Layout

    private static let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: PatternHighlightsCard.columns, spacing: 10) {
            PatternStatTile(
                label: "Hits hardest",
                value: hitsHardestValue,
                unit: nil,
                subtitle: hitsHardestSubtitle,
                trendDirection: trendDirection,
                palette: palette
            )

            PatternStatTile(
                label: "Intensity",
                value: intensityValue,
                unit: nil,
                subtitle: intensitySubtitle,
                palette: palette
            )

            PatternStatTile(
                label: "Appears with",
                value: appearsWithValue,
                unit: nil,
                subtitle: appearsWithSubtitle,
                palette: palette
            )

            PatternStatTile(
                label: "Next likely",
                value: nextLikelyValue,
                unit: nil,
                subtitle: nextLikelySubtitle,
                palette: palette
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
