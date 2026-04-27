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

    public init(
        items: [Item],
        selectedID: ID?,
        onSelect: @escaping (ID) -> Void,
        yLabelFormatter: @escaping (Double) -> String = { String(Int($0.rounded())) },
        yTickCount: Int = 5,
        chartHeight: CGFloat = 200,
        dimmedOpacity: Double = 0.32
    ) {
        self.items = items
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.yLabelFormatter = yLabelFormatter
        self.yTickCount = yTickCount
        self.chartHeight = chartHeight
        self.dimmedOpacity = dimmedOpacity
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
    private var range: (lower: Double, upper: Double) {
        let values = items.map(\.value)
        guard let minV = values.min(), let maxV = values.max() else {
            return (0, 1)
        }
        if minV == maxV {
            return (max(0, minV - 1), maxV + 1)
        }
        let span = maxV - minV
        let pad = max(span * 0.18, 1)
        return (max(0, minV - pad), maxV + pad)
    }

    private var yTicks: [Double] {
        let (lo, hi) = range
        let count = max(yTickCount, 2)
        let step = (hi - lo) / Double(count - 1)
        return (0..<count).map { lo + Double($0) * step }
    }

    // MARK: - Y-axis gutter

    private var yAxis: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(yTicks.enumerated().reversed()), id: \.offset) { index, tick in
                Text(yLabelFormatter(tick))
                    .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                    .lineLimit(1)
                    .fixedSize()
                if index > 0 {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: chartHeight, alignment: .top)
        .accessibilityHidden(true)
    }

    // MARK: - Bars

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(items) { item in
                barColumn(for: item)
            }
        }
        .frame(height: chartHeight, alignment: .bottom)
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
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: selectedID)
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
