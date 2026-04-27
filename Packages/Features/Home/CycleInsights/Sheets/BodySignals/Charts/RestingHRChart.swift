import Charts
import SwiftUI

// MARK: - Resting Heart Rate Chart
//
// Smooth area chart of daily resting HR with cycle phase bands
// painted into the background. Shares its visual vocabulary with
// the HRV phase chart (lane tints, soft palette, dashed personal
// baseline) so a reader who's already learned the HRV constellation
// reads this without a second mental model.
//
// Why this layout: the previous chart colored every line segment +
// point by phase, which read as a jagged mosaic and competed with
// the actual data trend. Pulling the phase identity into background
// bands lets a single quiet line carry the rhythm, while the bands
// answer "which phase was I in when this happened?" passively.

struct RestingHRChart: View {
    let metric: BodySignalMetric

    private static let chartHeight: CGFloat = 180
    private static let lineTint: Color = DesignColors.roseTaupe

    var body: some View {
        let domain = yDomain
        let bands = phaseBands

        Chart {
            // 1. Phase bands — full-height vertical washes painted in
            //    the background. Drawn first so every other mark sits
            //    on top.
            ForEach(bands) { band in
                RectangleMark(
                    xStart: .value("Phase start", band.start),
                    xEnd: .value("Phase end", band.end),
                    yStart: .value("Min", domain.lowerBound),
                    yEnd: .value("Max", domain.upperBound)
                )
                .foregroundStyle(band.phase.orbitColor.opacity(0.07))
            }

            // 2. Area fill — single warm tint, gradient downward to
            //    near-transparent so the line + bands stay readable
            //    near the baseline.
            ForEach(metric.samples) { sample in
                AreaMark(
                    x: .value("Day", sample.date),
                    y: .value("RHR", sample.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Self.lineTint.opacity(0.32),
                            Self.lineTint.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // 3. Line — single tint, monotone interpolation. No
            //    per-point coloring; phase identity already lives in
            //    the bands behind.
            ForEach(metric.samples) { sample in
                LineMark(
                    x: .value("Day", sample.date),
                    y: .value("RHR", sample.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Self.lineTint.opacity(0.9))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            // 4. Personal baseline — dashed, with a small "normal"
            //    label tucked at the right end so the reader knows
            //    what the line means.
            if let baseline = metric.baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                    .foregroundStyle(DesignColors.text.opacity(0.32))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text("normal")
                            .font(.raleway("Medium", size: 9, relativeTo: .caption2))
                            .tracking(0.4)
                            .foregroundStyle(DesignColors.textSecondary.opacity(0.75))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Capsule())
                    }
            }
        }
        .chartYScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(.clear)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: false)
                    .font(.raleway("Medium", size: 9, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.65))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                    .foregroundStyle(DesignColors.text.opacity(0.05))
                AxisValueLabel()
                    .font(.raleway("Medium", size: 9, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.65))
            }
        }
        // Wrap the plot area with explicit clipping so the phase
        // bands cannot bleed past the data Y-domain into the axis
        // label gutter beneath. Without this the bands' bottom edge
        // visually leaks behind "1 Feb / 1 Mar / 1 Apr".
        .chartPlotStyle { plot in
            plot.clipShape(Rectangle())
        }
        .frame(height: Self.chartHeight)
    }

    // MARK: - Helpers

    private var yDomain: ClosedRange<Double> {
        let values = metric.samples.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 55...75 }
        let padding = max(2, (hi - lo) * 0.2)
        return (lo - padding)...(hi + padding)
    }

    /// Collapses the day-stamped samples into contiguous phase
    /// segments. Each segment becomes a single `RectangleMark`,
    /// keeping the band count small even on long histories. Samples
    /// with no phase association break the run so the band fades
    /// out instead of guessing.
    private var phaseBands: [PhaseBand] {
        var bands: [PhaseBand] = []
        var current: (phase: CyclePhase, start: Date, end: Date)?

        for sample in metric.samples.sorted(by: { $0.date < $1.date }) {
            guard let phase = sample.phase else {
                if let c = current {
                    bands.append(PhaseBand(phase: c.phase, start: c.start, end: c.end))
                    current = nil
                }
                continue
            }

            if let c = current, c.phase == phase {
                current = (phase, c.start, sample.date)
            } else {
                if let c = current {
                    bands.append(PhaseBand(phase: c.phase, start: c.start, end: c.end))
                }
                current = (phase, sample.date, sample.date)
            }
        }

        if let c = current {
            bands.append(PhaseBand(phase: c.phase, start: c.start, end: c.end))
        }
        return bands
    }

    private struct PhaseBand: Identifiable {
        let id = UUID()
        let phase: CyclePhase
        let start: Date
        let end: Date
    }
}
