import SwiftUI

// MARK: - HRV Cycle Constellation
//
// Replaces the bare 4-bar chart with a cycle-shaped read: one orb
// per menstrual phase, positioned vertically by the user's average
// HRV in that phase, connected by a soft cubic-spline that traces
// the rhythm across a full cycle. Reads as "your HRV journey" rather
// than "four numbers in a row".
//
// Why this layout: the bar chart was tonally correct but semantically
// flat — equal-width bars give no felt difference between phases
// beyond the height. Plotting the same values along a curve turns
// the chart into a small narrative the eye walks through:
// follicular climbs, ovulatory peaks, luteal descends, menstrual
// quiets. Phase identity is preserved through orb tint, so a reader
// who already speaks the cycle.app palette doesn't need a legend.

struct HRVPhaseChart: View {
    let metric: BodySignalMetric

    /// Phase order mirrors how the cycle is told elsewhere in the
    /// app — menstrual → follicular → ovulatory → luteal. Missing
    /// phases keep their slot so the row reads as a full cycle even
    /// when some phases haven't been sampled yet.
    private static let phases: [CyclePhase] = [.menstrual, .follicular, .ovulatory, .luteal]

    private static let chartHeight: CGFloat = 184
    private static let chartAreaHeight: CGFloat = 140
    private static let orbSize: CGFloat = 46
    private static let chartPadding: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            chartArea
                .padding(.vertical, 6)
                .background(phaseLanes)
            separator
            labelsRow
                .padding(.top, 8)
        }
        .frame(height: Self.chartHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Chart canvas (lanes + separator)
    //
    // Four vertical phase lanes at very low opacity (~5%) running the
    // full chart height, clipped into a softly rounded rect. Anchors
    // each phase label to the orb directly above it — without this,
    // the labels read as a separate text row floating below the
    // chart. A hairline separator under the orb area hands the eye
    // off from "data" to "labels" without a hard break.

    private var phaseLanes: some View {
        HStack(spacing: 0) {
            ForEach(Self.phases, id: \.self) { phase in
                phase.orbitColor.opacity(0.05)
                    .frame(maxWidth: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var separator: some View {
        Rectangle()
            .fill(DesignColors.text.opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 4)
    }

    // MARK: - Chart area

    private var chartArea: some View {
        GeometryReader { geo in
            let positions = orbPositions(in: geo.size)
            let entries = self.entries

            ZStack {
                averageLine(in: geo.size)
                connector(through: positions, withData: entries.map { $0.value > 0 })
                orbs(at: positions, entries: entries)
            }
        }
        .frame(height: Self.chartAreaHeight)
    }

    // MARK: - Average reference line
    //
    // Soft dashed guide at the personal mean of the logged phase
    // averages. Tells the reader "today this phase sits above/below
    // your typical HRV" without making any clinical claim — the
    // baseline is the user's own data, not a population range. We
    // skip the line when there's only one value logged: with no
    // variation to anchor against, the line would just retrace the
    // single orb and read as visual noise.

    @ViewBuilder
    private func averageLine(in size: CGSize) -> some View {
        let dataValues = entries.map(\.value).filter { $0 > 0 }
        if dataValues.count >= 2 {
            let avg = dataValues.reduce(0, +) / Double(dataValues.count)
            let y = mapValueToY(avg, in: size, values: dataValues)

            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            .stroke(
                DesignColors.text.opacity(0.28),
                style: StrokeStyle(lineWidth: 0.8, dash: [3, 4])
            )

            // Sit the label in the dead-zone between orb 3
            // (Ovulatory) and orb 4 (Luteal) — `size.width * 3/4` is
            // the slot boundary in our 4-orb grid, guaranteed to
            // miss every orb since orbs anchor at slot midpoints.
            // The white background clears both the dashed avg line
            // and the connector spline behind the label.
            Text("avg")
                .font(.raleway("Medium", size: 9, relativeTo: .caption2))
                .tracking(0.4)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white)
                .position(x: size.width * 3 / 4, y: y)
        }
    }

    // MARK: - Connector
    //
    // Smooth cubic spline through the orb centers. We split each
    // segment into a horizontal-tangent curve (control points slid
    // halfway across the gap on each side) so the line eases in and
    // out of every orb instead of breaking into kinks at sharp
    // value changes. Stroke uses a horizontal gradient through the
    // phase palette at low opacity — same hue family as the orbs,
    // quiet enough that the orbs stay the protagonists.

    @ViewBuilder
    private func connector(through positions: [CGPoint], withData hasData: [Bool]) -> some View {
        if positions.count >= 2 {
            Path { path in
                let pts = positions
                path.move(to: pts[0])
                for i in 1..<pts.count {
                    let prev = pts[i - 1]
                    let curr = pts[i]
                    let mx = (prev.x + curr.x) / 2
                    path.addCurve(
                        to: curr,
                        control1: CGPoint(x: mx, y: prev.y),
                        control2: CGPoint(x: mx, y: curr.y)
                    )
                }
            }
            .stroke(
                connectorGradient,
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )
            .opacity(hasData.contains(true) ? 1 : 0)
        }
    }

    private var connectorGradient: LinearGradient {
        LinearGradient(
            colors: Self.phases.map { $0.orbitColor.opacity(0.42) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Orbs

    private func orbs(
        at positions: [CGPoint],
        entries: [(phase: CyclePhase, value: Double)]
    ) -> some View {
        ForEach(Array(zip(positions, entries).enumerated()), id: \.offset) { _, pair in
            let (point, entry) = pair
            orb(for: entry)
                .position(point)
        }
    }

    @ViewBuilder
    private func orb(for entry: (phase: CyclePhase, value: Double)) -> some View {
        let hasValue = entry.value > 0
        ZStack {
            // Opaque white backing — masks the connector spline from
            // showing *through* the orb. The phase tint sits on top
            // of this white disc, so the orb reads as a clean pastel
            // chip and the line appears to anchor at the orb edge
            // rather than crossing the disc like a thread.
            Circle()
                .fill(Color.white)
            Circle()
                .fill(entry.phase.orbitColor.opacity(hasValue ? 0.25 : 0.08))
            Circle()
                .stroke(
                    entry.phase.orbitColor.opacity(hasValue ? 0.55 : 0.20),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: hasValue ? [] : [3, 3]
                    )
                )

            if hasValue {
                Text("\(Int(entry.value.rounded()))")
                    .font(.raleway("SemiBold", size: 14, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } else {
                Text("–")
                    .font(.raleway("Medium", size: 13, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
            }
        }
        .frame(width: Self.orbSize, height: Self.orbSize)
    }

    // MARK: - Labels

    private var labelsRow: some View {
        HStack(spacing: 0) {
            ForEach(Self.phases, id: \.self) { phase in
                Text(phase.displayName)
                    .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    // MARK: - Geometry

    private var entries: [(phase: CyclePhase, value: Double)] {
        Self.phases.map { phase in (phase, metric.byPhase[phase] ?? 0) }
    }

    /// Maps the 4 entries onto chart-area coordinates. X is equal
    /// spacing across the width; Y delegates to `mapValueToY` so the
    /// orb positions and the average line share the exact same
    /// vertical scale. Phases without data anchor to the bottom row
    /// so the empty orbs read as "below the rhythm" instead of
    /// crashing the spline mid-air.
    private func orbPositions(in size: CGSize) -> [CGPoint] {
        let entries = self.entries
        let values = entries.map(\.value).filter { $0 > 0 }
        let xStep = size.width / CGFloat(entries.count)
        let yBottom = size.height - Self.orbSize / 2 - Self.chartPadding

        return entries.enumerated().map { i, entry in
            let x = xStep * (CGFloat(i) + 0.5)
            let y = entry.value > 0
                ? mapValueToY(entry.value, in: size, values: values)
                : yBottom
            return CGPoint(x: x, y: y)
        }
    }

    /// Single source of truth for value-to-Y mapping inside the
    /// chart area. Used by both the orb positions and the average
    /// reference line so they always sit on the same scale.
    private func mapValueToY(_ value: Double, in size: CGSize, values: [Double]) -> CGFloat {
        let yTop = Self.orbSize / 2 + Self.chartPadding
        let yBottom = size.height - Self.orbSize / 2 - Self.chartPadding

        guard let minVal = values.min(), let maxVal = values.max() else {
            return yBottom
        }
        guard values.count >= 2, maxVal > minVal else {
            // Single value (or all identical) — center vertically so
            // the lone orb doesn't pin to the top edge.
            return (yTop + yBottom) / 2
        }

        let range = maxVal - minVal
        let yRange = yBottom - yTop
        let normalized = (value - minVal) / range
        return yBottom - CGFloat(normalized) * yRange
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let parts = entries.map { entry in
            entry.value > 0
                ? "\(entry.phase.displayName) \(Int(entry.value.rounded())) milliseconds"
                : "\(entry.phase.displayName) no data"
        }
        return "HRV by phase: " + parts.joined(separator: ", ")
    }
}
