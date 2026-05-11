import SwiftUI

// MARK: - Segmented Half-Arc Gauge
//
// The signature visualisation for `PatternWidgetCard`. Reads as a
// row of N segments curved into a half-arc — one segment per cycle
// in the lookback window. Filled segments (in phase ink) are the
// cycles where the signal returned. The empty ones are the cycles
// where it didn't.
//
// Why a Canvas:
//   - Single render pass, no SwiftUI ZStack overhead per segment.
//   - Stable across cell reuse on the UICollectionView host (the
//     pattern these cards may eventually live on if Today scrolls
//     them in a list).
//   - We can tweak gap-degrees / line-width as the design evolves
//     without rebuilding a Shape per knob.
//
// Geometry contract:
//   - Aspect ratio fixed at 2 : 1 via `.aspectRatio(2, contentMode:
//     .fit)`. Caller frames the size; the canvas honours width and
//     half of that as the visible half-arc height.
//   - Stroke ends are `.round`, so each segment reads as a pill
//     rather than a hard slice.
//   - Total arc spans 180°; gaps are subtracted before dividing the
//     remainder evenly across `total` segments.

struct SegmentedHalfArcGauge: View {
    /// Total cycles in the lookback window — one segment per cycle.
    let total: Int

    /// Number of cycles where the signal returned. Filled in the
    /// phase ink; the rest stay in the muted phase track.
    let filled: Int

    /// Phase ink for filled segments (e.g. `DesignColors.calendarPeriodGlyph`).
    let fillColor: Color

    /// Soft phase wash for the empty segments — the same hue at low
    /// opacity. Caller passes a pre-tinted colour so this view stays
    /// agnostic of the phase palette.
    let trackColor: Color

    /// Stroke thickness in points. 14 reads well at the standard
    /// widget width (≈ 240pt); shrink to 10 for compact contexts.
    var lineWidth: CGFloat = 14

    /// Visual gap between adjacent segments, in degrees. 5° works for
    /// 4–6 segments at the standard size. Smaller values run the
    /// segments together; larger values eat into the arc length and
    /// leave the segments feeling stubby.
    var gapDegrees: Double = 5

    var body: some View {
        Canvas { ctx, size in
            // Zero-segment guard. Empty arcs render as a pure track —
            // the empty-state widget passes total=0 to draw a quiet
            // dashed silhouette via a separate path; here we just
            // bail so we don't divide-by-zero.
            guard total > 0 else { return }

            // Radius needs to clear the stroke on BOTH the horizontal
            // ends and the vertical apex. Earlier we sized only by
            // width — at a 2:1 aspect the apex stroke ran past the
            // top edge and got clipped by Canvas, leaving a flat
            // crown on every segment. Min of the two ensures we
            // always have at least `lineWidth + 2` of clearance.
            let halfStroke = lineWidth / 2
            let center = CGPoint(x: size.width / 2, y: size.height - halfStroke)
            let usableHalfWidth = (size.width - lineWidth) / 2
            let usableHeight = size.height - lineWidth - 2
            let radius = min(usableHalfWidth, usableHeight)
            let totalArc = 180.0
            let segmentSize = (totalArc - gapDegrees * Double(total - 1)) / Double(total)

            for index in 0..<total {
                let startDeg = 180.0 + Double(index) * (segmentSize + gapDegrees)
                let endDeg = startDeg + segmentSize

                var path = Path()
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startDeg),
                    endAngle: .degrees(endDeg),
                    // SwiftUI's Path is in Y-down screen space —
                    // `clockwise: false` here draws the visual top
                    // half (180° → 270° → 360°). Flipping this
                    // would render upside-down.
                    clockwise: false
                )

                let stroke = StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
                let color = index < filled ? fillColor : trackColor
                ctx.stroke(path, with: .color(color), style: stroke)
            }
        }
        .aspectRatio(2, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - Empty silhouette

/// Thin dashed half-arc rendered when there are no patterns yet.
/// Same silhouette as `SegmentedHalfArcGauge` so the empty card and
/// the data card share a visual rhythm.
struct EmptyHalfArcGauge: View {
    var lineWidth: CGFloat = 14

    var body: some View {
        Canvas { ctx, size in
            // Same radius-clamping logic as the active gauge — see
            // `SegmentedHalfArcGauge` for the rationale. The empty
            // silhouette must inherit the identical geometry so the
            // empty-state widget reads as the data widget's "before".
            let halfStroke = lineWidth / 2
            let center = CGPoint(x: size.width / 2, y: size.height - halfStroke)
            let usableHalfWidth = (size.width - lineWidth) / 2
            let usableHeight = size.height - lineWidth - 2
            let radius = min(usableHalfWidth, usableHeight)

            var path = Path()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(360),
                clockwise: false
            )

            ctx.stroke(
                path,
                with: .color(.black.opacity(0.10)),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    dash: [4, 8]
                )
            )
        }
        .aspectRatio(2, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Active 4 of 5") {
    SegmentedHalfArcGauge(
        total: 5,
        filled: 4,
        fillColor: .pink,
        trackColor: .pink.opacity(0.18)
    )
    .frame(width: 240, height: 130)
    .padding()
    .background(Color(red: 0.97, green: 0.90, blue: 0.82))
}

#Preview("Emerging 2 of 4") {
    SegmentedHalfArcGauge(
        total: 4,
        filled: 2,
        fillColor: .green,
        trackColor: .green.opacity(0.20)
    )
    .frame(width: 240, height: 130)
    .padding()
    .background(Color(red: 0.97, green: 0.90, blue: 0.82))
}

#Preview("Empty silhouette") {
    EmptyHalfArcGauge()
        .frame(width: 240, height: 130)
        .padding()
        .background(Color(red: 0.97, green: 0.90, blue: 0.82))
}
#endif
