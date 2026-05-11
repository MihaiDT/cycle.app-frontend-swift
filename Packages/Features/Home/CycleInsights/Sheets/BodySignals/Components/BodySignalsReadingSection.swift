import SwiftUI

// MARK: - Body Signals Reading Section
//
// Editorial paragraph that explains what the chart above shows
// and what the metric means in everyday terms. Sits beneath the
// `BodySignalsChartCard` on each focused screen
// (Wrist temperature / HRV / Resting heart rate) so the user
// who tapped a tile gets context, not just numbers.
//
// Surface treatment matches the rest of the BodySignals detail:
//   • `widgetCardStyle(cornerRadius: 28)` – same surface as the
//     chart card above, just full-width text.
//   • Editorial section header "Reading" rendered above (no
//     eyebrow, same weight as Cycle Stats section titles).
//   • One Text node, sentence-line-broken via the formatter so
//     each thought owns its own breath.
//
// Copy is deterministic per `(kind, sampleCount)` via
// `BodySignalsReadingEngine`. Cross-cycles the variant rotates
// naturally; within a session the same screen always shows the
// same paragraph.

struct BodySignalsReadingSection: View {
    let kind: BodySignalMetric.Kind
    let metric: BodySignalMetric?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reading")
                .font(.raleway("SemiBold", size: 20, relativeTo: .title3))
                .foregroundStyle(DesignColors.text)

            Text(formatted)
                .font(.raleway("Medium", size: 15, relativeTo: .body))
                .tracking(-0.1)
                .foregroundStyle(DesignColors.text.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetCardStyle(cornerRadius: 28)
        }
    }

    /// One sentence per line – same cadence as
    /// `PatternReadingSection` and the editorial lede on pattern
    /// cards.
    private var formatted: String {
        BodySignalsReadingEngine.reading(for: kind, metric: metric)
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "? ", with: "?\n")
            .replacingOccurrences(of: "! ", with: "!\n")
    }
}
