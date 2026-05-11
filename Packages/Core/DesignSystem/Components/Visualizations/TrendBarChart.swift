import SwiftUI

// MARK: - Trend Bar Chart
//
// Reusable bar chart for trend timelines (cycle history, body
// signal series, future analytics surfaces). Renders capsule bars
// with a y-axis label gutter on the left and an x-axis label row
// underneath. Tapping a column fires `onSelect(id)`; the selected
// bar pops at full tint while the rest dim, so the eye lands on
// the user's pick first — same hierarchy language Apple Health
// uses for its weekly bars.
//
// The component is intentionally "dumb": parents own the selected
// ID and decide each bar's tint (so an in-range terracotta bar
// stays terracotta even when selected — the chart never overrides
// the surface's tonal vocabulary).

public struct TrendBarChart<ID: Hashable>: View {
    public struct Item: Identifiable, Equatable {
        public let id: ID
        public let value: Double
        public let xLabel: String
        public let tint: Color

        public init(id: ID, value: Double, xLabel: String, tint: Color) {
            self.id = id
            self.value = value
            self.xLabel = xLabel
            self.tint = tint
        }
    }

    public let items: [Item]
    public let selectedID: ID?
    public let onSelect: (ID) -> Void
    public let yLabelFormatter: (Double) -> String
    public let yTickCount: Int
    public let chartHeight: CGFloat
    public let dimmedOpacity: Double
    /// When set, draws a soft horizontal band across the chart between
    /// these y-axis values. Used by the cycle trend chart to mark the
    /// 21–35 day "typical" range — bars inside read as in-band, bars
    /// outside punch through. Pass `nil` (default) to skip the band.
    public let normalBand: ClosedRange<Double>?
    /// Caps label rendered at the trailing edge of the band (default
    /// "TYPICAL"). The band stays unlabeled if this is set to an empty
    /// string.
    public let normalBandLabel: String

    public init(
        items: [Item],
        selectedID: ID?,
        onSelect: @escaping (ID) -> Void,
        yLabelFormatter: @escaping (Double) -> String = { String(Int($0.rounded())) },
        yTickCount: Int = 5,
        chartHeight: CGFloat = 200,
        dimmedOpacity: Double = 0.32,
        normalBand: ClosedRange<Double>? = nil,
        normalBandLabel: String = "TYPICAL"
    ) {
        self.items = items
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.yLabelFormatter = yLabelFormatter
        self.yTickCount = yTickCount
        self.chartHeight = chartHeight
        self.dimmedOpacity = dimmedOpacity
        self.normalBand = normalBand
        self.normalBandLabel = normalBandLabel
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            yAxis
            VStack(spacing: 10) {
                bars
                xLabels
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Range / ticks

    /// Padded range so bars never bottom out at the floor and a row
    /// of near-identical values still reads as bars rather than
    /// stripes pinned to the top.
    ///
    /// **With `normalBand`:** the chart's lower edge is pinned to the
    /// band's lower bound (or below, if a cycle dips beneath it).
    /// Otherwise the bars would float at e.g. y=20 while the band
    /// started at y=21 — the user reads two parallel baselines and
    /// can't tell which one is "the floor". Aligning them makes a
    /// 35-day bar visibly fill the typical band from edge to edge.
    /// Top side keeps a small breathing pad so the tallest bar isn't
    /// kissing the chart ceiling.
    private var range: (lower: Double, upper: Double) {
        let values = items.map(\.value)
        let bandLow = normalBand?.lowerBound
        let bandHigh = normalBand?.upperBound

        guard let minV = values.min(), let maxV = values.max() else {
            if let lo = bandLow, let hi = bandHigh, lo < hi {
                let pad = max((hi - lo) * 0.1, 1)
                return (max(0, lo), hi + pad)
            }
            return (0, 1)
        }

        let lowSeed = min(minV, bandLow ?? minV)
        let highSeed = max(maxV, bandHigh ?? maxV)

        if lowSeed == highSeed {
            return (max(0, lowSeed - 1), highSeed + 1)
        }
        let span = highSeed - lowSeed
        if bandLow != nil {
            // Zero bottom pad: bars and band share a baseline.
            let topPad = max(span * 0.1, 1)
            return (max(0, lowSeed), highSeed + topPad)
        }
        // No band — symmetric pad, the original behavior.
        let pad = max(span * 0.18, 1)
        return (max(0, lowSeed - pad), highSeed + pad)
    }

    private var yTicks: [Double] {
        let (lo, hi) = range
        let count = max(yTickCount, 2)
        let step = (hi - lo) / Double(count - 1)
        return (0..<count).map { lo + Double($0) * step }
    }

    // MARK: - Y-axis gutter

    private var yAxis: some View {
        // Tight ranges (e.g. a single bar at 28d, a chart where every
        // bar landed on the same day) generate ticks that round to
        // identical labels — "29d, 28d, 28d, 27d". We hide the
        // duplicates instead of dropping them so the spacers between
        // tick rows stay even and the gridline rhythm doesn't shift
        // when the data widens.
        let entries = yAxisEntries
        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(entries.enumerated().reversed()), id: \.offset) { index, entry in
                Text(entry.label)
                    .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                    .lineLimit(1)
                    .fixedSize()
                    .opacity(entry.isVisible ? 1 : 0)
                if index > 0 {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: chartHeight, alignment: .top)
        .accessibilityHidden(true)
    }

    private var yAxisEntries: [(label: String, isVisible: Bool)] {
        var seen: Set<String> = []
        var result: [(label: String, isVisible: Bool)] = []
        for tick in yTicks {
            let label = yLabelFormatter(tick)
            if seen.contains(label) {
                result.append((label, false))
            } else {
                seen.insert(label)
                result.append((label, true))
            }
        }
        return result
    }

    // MARK: - Bars

    private var bars: some View {
        ZStack(alignment: .bottom) {
            if let band = normalBand {
                normalBandLayer(for: band)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(items) { item in
                    barColumn(for: item)
                }
            }
        }
        .frame(height: chartHeight, alignment: .bottom)
    }

    // MARK: - Normal range band
    //
    // Apple-Health-style horizontal band that names the "typical"
    // y-axis window without dominating the chart. Soft fill plus
    // hairline borders on both edges so the eye can land on the
    // band's footprint instantly; the trailing-side caps label
    // ("TYPICAL") tells the user what they're looking at without
    // stealing real estate from the bars.

    @ViewBuilder
    private func normalBandLayer(for band: ClosedRange<Double>) -> some View {
        let (lo, hi) = range
        let span = max(hi - lo, 0.0001)
        let usable = max(chartHeight - 6, 1)
        let bottomY = max(0, min(1, (band.lowerBound - lo) / span)) * usable
        let topY = max(0, min(1, (band.upperBound - lo) / span)) * usable
        let bandHeight = max(0, topY - bottomY)

        if bandHeight > 1 {
            Rectangle()
                .fill(DesignColors.accentWarm.opacity(0.07))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DesignColors.accentWarm.opacity(0.22))
                        .frame(height: 0.6)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignColors.accentWarm.opacity(0.22))
                        .frame(height: 0.6)
                }
                .overlay(alignment: .topTrailing) {
                    if !normalBandLabel.isEmpty {
                        Text(normalBandLabel)
                            .font(.raleway("SemiBold", size: 9, relativeTo: .caption2))
                            .tracking(1.0)
                            .foregroundStyle(DesignColors.accentWarmText.opacity(0.55))
                            .padding(.trailing, 6)
                            .padding(.top, 4)
                    }
                }
                .frame(height: bandHeight)
                .padding(.bottom, bottomY)
                .accessibilityHidden(true)
        }
    }

    private func barColumn(for item: Item) -> some View {
        let (lo, hi) = range
        let span = max(hi - lo, 0.0001)
        let normalized = max(0, min(1, (item.value - lo) / span))
        // Reserve a sliver at the top so even the tallest bar keeps
        // a hair of breathing room from the chart ceiling.
        let usable = max(chartHeight - 6, 1)
        let height = max(10, normalized * usable)
        let isSelected = item.id == selectedID

        return Button {
            onSelect(item.id)
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Capsule(style: .continuous)
                    .fill(item.tint.opacity(isSelected ? 1.0 : dimmedOpacity))
                    .frame(maxWidth: 32)
                    .frame(height: height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // No `.animation(value: selectedID)` here — that's a scoped
        // animation that overrides any ambient transaction, including
        // the `disablesAnimations` transaction the host card uses to
        // seed selection silently when its cell is recycled mid-scroll.
        // The host now wraps user-driven taps in `withAnimation` so the
        // spring still fires on intentional selection, just not on
        // viewport re-entry.
        .accessibilityLabel("\(item.xLabel), \(yLabelFormatter(item.value))")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    // MARK: - X-axis labels

    private var xLabels: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(items) { item in
                let isSelected = item.id == selectedID
                Text(item.xLabel)
                    .font(.raleway(isSelected ? "SemiBold" : "Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(isSelected ? DesignColors.text : DesignColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}
