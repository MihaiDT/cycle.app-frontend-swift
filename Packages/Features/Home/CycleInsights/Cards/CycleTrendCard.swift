import SwiftUI
import UIKit

// MARK: - Cycle Trend Card
//
// Replaces the older "Your Cycle Average" card. Reframes the answer from
// a single number to a visible pattern — recent logged cycles as bars,
// running average in the subtitle. The latest cycle is the accent bar
// so the eye lands there first, and the segmented control (6M / 1Y /
// All) scopes the window.

public struct CycleTrendCard: View {
    public struct Point: Equatable, Identifiable {
        public let id: Date
        public let startDate: Date
        public let days: Int

        public init(id: Date, startDate: Date, days: Int) {
            self.id = id
            self.startDate = startDate
            self.days = days
        }
    }

    public enum Window: String, CaseIterable, Sendable {
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"

        var maxEntries: Int? {
            switch self {
            case .sixMonths: 6
            case .oneYear:   12
            case .all:       nil
            }
        }
    }

    public let points: [Point]
    public let averageDays: Int

    @State private var window: Window = .sixMonths

    public init(points: [Point], averageDays: Int) {
        self.points = points
        self.averageDays = averageDays
        Self.applySegmentedAppearance()
    }

    /// Force the native segmented control's title color to the app's
    /// Cocoa Dark (`DesignColors.text`). SwiftUI's `Picker(.segmented)`
    /// doesn't expose a foreground modifier — it's a UIKit-backed view,
    /// so we route through `UISegmentedControl.appearance()`. Applied on
    /// init (idempotent) so later screens that re-enter the card pick up
    /// any theme change without extra wiring.
    private static func applySegmentedAppearance() {
        let cocoa = UIColor(DesignColors.text)
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: cocoa]
        UISegmentedControl.appearance().setTitleTextAttributes(attrs, for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes(attrs, for: .selected)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            if visiblePoints.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `rasterize: false` — the native segmented Picker is UIKit-backed
        // and can't be flattened into a Metal bitmap by `.drawingGroup`.
        .widgetCardStyle(cornerRadius: 28, rasterize: false)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header
    //
    // Mirrors the hero-title treatment used by CycleHistoryCard so the
    // stats screen reads as a single editorial spread.

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("CYCLE\nTREND")
                    .font(AppTypography.cardTitlePrimary)
                    .tracking(AppTypography.cardTitlePrimaryTracking)
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(AppTypography.cardLabel)
                    .tracking(AppTypography.cardLabelTracking)
                    .foregroundStyle(DesignColors.textSecondary)
            }
            Spacer(minLength: 8)
            windowPicker
        }
    }

    private var subtitle: String {
        let count = visiblePoints.count
        guard count > 0 else { return "Not enough cycles yet" }
        let noun = count == 1 ? "cycle" : "cycles"
        return "Last \(count) \(noun) · Avg \(averageDays) days"
    }

    private var windowPicker: some View {
        // Neutral tint to match the "See all" pill on CycleHistoryCard —
        // the stats screen keeps chrome muted so numbers stay the story.
        Picker("Range", selection: $window) {
            ForEach(Window.allCases, id: \.self) { w in
                Text(w.rawValue).tag(w)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .tint(DesignColors.text.opacity(0.85))
    }

    // MARK: - Chart

    /// Max width per bar column. Prevents a 1- or 2-cycle history from
    /// ballooning into chunky blocks, while bar width otherwise shrinks
    /// to fit the card's actual width (1Y = 12 bars, All can be more).
    private static let maxBarWidth: CGFloat = 44

    /// Resolve how wide and how spaced bars should be for `count`
    /// columns inside `available` pt. Both bar and label columns share
    /// the same values so numbers sit under their bars at any count.
    private static func layout(for count: Int, available: CGFloat) -> (barWidth: CGFloat, spacing: CGFloat) {
        guard count > 0 else { return (maxBarWidth, 10) }
        let spacing: CGFloat = count > 8 ? 4 : 10
        let totalSpacing = spacing * CGFloat(max(count - 1, 0))
        let raw = (available - totalSpacing) / CGFloat(count)
        let barWidth = max(8, min(maxBarWidth, raw))
        return (barWidth, spacing)
    }

    private var chart: some View {
        let visible = visiblePoints
        let range = chartRange(for: visible)
        let lastIndex = visible.count - 1
        return GeometryReader { geo in
            let (barWidth, spacing) = Self.layout(for: visible.count, available: geo.size.width)
            VStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, point in
                        bar(
                            for: point,
                            isCurrent: index == lastIndex,
                            range: range,
                            width: barWidth
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)

                monthLabels(for: visible, barWidth: barWidth, spacing: spacing)
            }
        }
        .frame(height: 180)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chartAccessibilityLabel(for: visible))
    }

    private func bar(
        for point: Point,
        isCurrent: Bool,
        range: (lower: Int, upper: Int),
        width: CGFloat
    ) -> some View {
        let span = max(CGFloat(range.upper - range.lower), 1)
        let normalized = (CGFloat(point.days - range.lower) / span) * 110 + 24
        return VStack(spacing: 6) {
            Text("\(point.days)")
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .foregroundStyle(isCurrent ? DesignColors.accentWarmText : DesignColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCurrent ? DesignColors.accentWarm : DesignColors.accentWarm.opacity(0.14))
                .frame(height: normalized)
        }
        .frame(width: width)
    }

    private func monthLabels(for points: [Point], barWidth: CGFloat, spacing: CGFloat) -> some View {
        // Disambiguate consecutive cycles that start in the same calendar
        // month (short cycles can fit two starts inside one month) by
        // promoting the label to "MMM d".
        let labels = disambiguatedLabels(for: points)
        let lastIndex = points.count - 1
        return HStack(spacing: spacing) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(
                        .raleway(
                            index == lastIndex ? "SemiBold" : "Medium",
                            size: 11,
                            relativeTo: .caption2
                        )
                    )
                    .foregroundStyle(
                        index == lastIndex ? DesignColors.text : DesignColors.textSecondary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: barWidth)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func disambiguatedLabels(for points: [Point]) -> [String] {
        let months = points.map { monthLabel(for: $0.startDate) }
        return points.enumerated().map { index, point in
            let thisMonth = months[index]
            let conflict =
                (index > 0 && months[index - 1] == thisMonth)
                || (index < months.count - 1 && months[index + 1] == thisMonth)
            if conflict {
                return monthDayLabel(for: point.startDate)
            }
            return thisMonth
        }
    }

    private func monthDayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Log a few cycles to see your rhythm here.")
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 30)
    }

    // MARK: - Helpers

    private var visiblePoints: [Point] {
        let sorted = points.sorted { $0.startDate < $1.startDate }
        if let cap = window.maxEntries {
            return Array(sorted.suffix(cap))
        }
        return sorted
    }

    /// Clamp the chart's numeric range to a roomy band around the data
    /// so the bars never render at 0 height when all cycles are close
    /// to each other. Floor/ceiling widen in whole days so the y-scale
    /// reads stable cycle-to-cycle.
    private func chartRange(for visible: [Point]) -> (lower: Int, upper: Int) {
        let lengths = visible.map(\.days) + [averageDays]
        guard let minValue = lengths.min(), let maxValue = lengths.max() else {
            return (lower: averageDays - 2, upper: averageDays + 2)
        }
        let lower = max(0, minValue - 2)
        let upper = max(lower + 1, maxValue + 2)
        return (lower, upper)
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func chartAccessibilityLabel(for points: [Point]) -> String {
        guard !points.isEmpty else { return "No cycle data yet" }
        let readings = points.enumerated().map { index, point in
            let suffix = index == points.count - 1 ? ", current cycle" : ""
            return "\(monthLabel(for: point.startDate)) \(point.days) days\(suffix)"
        }
        return readings.joined(separator: ", ")
    }
}

// MARK: - Skeleton

struct CycleTrendSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(skeletonFill).frame(width: 140, height: 24)
                    RoundedRectangle(cornerRadius: 4).fill(skeletonFill).frame(width: 120, height: 24)
                    RoundedRectangle(cornerRadius: 3).fill(skeletonFill).frame(width: 180, height: 12)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 12).fill(skeletonFill).frame(width: 120, height: 28)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(skeletonFill)
                        .frame(width: 44, height: CGFloat(60 + (index * 12 % 60)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3).fill(skeletonFill).frame(width: 44, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    private var skeletonFill: Color { DesignColors.text.opacity(0.08) }
}
