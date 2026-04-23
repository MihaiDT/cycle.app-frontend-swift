import SwiftUI

// MARK: - Cycle Trend Card
//
// Replaces the older "Your Cycle Average" card. Reframes the answer from
// a single number to a visible pattern — recent cycles as bars, plus a
// ghost forecast row to the right when the real history is still short.
// The running average is surfaced in the subtitle (not a floating line,
// which was noisy for VoiceOver). The latest logged cycle is the accent
// bar so the eye lands there first.

public struct CycleTrendCard: View {
    public struct Point: Equatable, Identifiable {
        public let id: Date
        public let startDate: Date
        public let days: Int
        public let isPredicted: Bool

        public init(id: Date, startDate: Date, days: Int, isPredicted: Bool = false) {
            self.id = id
            self.startDate = startDate
            self.days = days
            self.isPredicted = isPredicted
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
        let real = realCount
        guard real > 0 else { return "Not enough cycles yet" }
        let noun = real == 1 ? "cycle" : "cycles"
        return "Last \(real) \(noun) · Avg \(averageDays) days"
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
    /// ballooning into chunky blocks that span the card. When bars can't
    /// fill the row, a trailing Spacer packs them to the leading edge.
    private static let maxBarWidth: CGFloat = 44

    private var chart: some View {
        let visible = visiblePoints
        let range = chartRange(for: visible)
        let lastRealIndex = visible.lastIndex(where: { !$0.isPredicted }) ?? (visible.count - 1)
        return VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, point in
                    bar(
                        for: point,
                        isCurrent: index == lastRealIndex && !point.isPredicted,
                        range: range
                    )
                }
                if visible.count < (window.maxEntries ?? visible.count) {
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 150)

            monthLabels(for: visible, lastRealIndex: lastRealIndex)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chartAccessibilityLabel(for: visible))
    }

    private func bar(for point: Point, isCurrent: Bool, range: (lower: Int, upper: Int)) -> some View {
        let span = max(CGFloat(range.upper - range.lower), 1)
        let normalized = (CGFloat(point.days - range.lower) / span) * 110 + 24
        return VStack(spacing: 6) {
            Text("\(point.days)")
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .foregroundStyle(dayLabelColor(for: point, isCurrent: isCurrent))

            barShape(for: point, isCurrent: isCurrent)
                .frame(height: normalized)
        }
        .frame(maxWidth: Self.maxBarWidth)
    }

    @ViewBuilder
    private func barShape(for point: Point, isCurrent: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if point.isPredicted {
            // Dashed outline, no fill — reads as "forecast" vs. the solid
            // real cycles. Same corner radius so the silhouette still
            // rhymes with the logged bars around it.
            shape
                .strokeBorder(
                    DesignColors.accentWarm.opacity(0.45),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        } else if isCurrent {
            shape.fill(DesignColors.accentWarm)
        } else {
            shape.fill(DesignColors.accentWarm.opacity(0.14))
        }
    }

    private func dayLabelColor(for point: Point, isCurrent: Bool) -> Color {
        if point.isPredicted {
            return DesignColors.textSecondary.opacity(0.6)
        }
        if isCurrent {
            return DesignColors.accentWarmText
        }
        return DesignColors.textSecondary
    }

    private func monthLabels(for points: [Point], lastRealIndex: Int) -> some View {
        // Disambiguate consecutive cycles that start in the same calendar
        // month (short cycles can fit two starts inside one month) by
        // promoting the label to "MMM d".
        let labels = disambiguatedLabels(for: points)
        return HStack(spacing: 10) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(
                        .raleway(
                            index == lastRealIndex ? "SemiBold" : "Medium",
                            size: 11,
                            relativeTo: .caption2
                        )
                    )
                    .foregroundStyle(monthLabelColor(
                        isCurrent: index == lastRealIndex,
                        isPredicted: points[index].isPredicted
                    ))
                    .frame(maxWidth: Self.maxBarWidth)
            }
            if points.count < (window.maxEntries ?? points.count) {
                Spacer(minLength: 0)
            }
        }
    }

    private func monthLabelColor(isCurrent: Bool, isPredicted: Bool) -> Color {
        if isPredicted { return DesignColors.textSecondary.opacity(0.5) }
        if isCurrent   { return DesignColors.text }
        return DesignColors.textSecondary
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

    // MARK: - Visible data
    //
    // Takes the real (logged) points, clamps them to the window, and —
    // for the bounded windows (6M / 1Y) — tops up with ghost forecast
    // bars projected forward from the last real start date at `avg` days
    // apart. The "All" window never forecasts; it only shows history.

    private var realPoints: [Point] {
        points.filter { !$0.isPredicted }.sorted { $0.startDate < $1.startDate }
    }

    private var realCount: Int { realPoints.count }

    private var visiblePoints: [Point] {
        let real = realPoints
        guard let cap = window.maxEntries else { return real }

        let recent = Array(real.suffix(cap))
        let missing = cap - recent.count
        guard missing > 0, let anchor = real.last else { return recent }

        let projected = (1...missing).compactMap { step -> Point? in
            guard
                let next = Calendar.current.date(
                    byAdding: .day,
                    value: step * averageDays,
                    to: anchor.startDate
                )
            else { return nil }
            return Point(id: next, startDate: next, days: averageDays, isPredicted: true)
        }
        return recent + projected
    }

    /// Clamp the chart's numeric range to a roomy band around the data.
    /// Predictions use `averageDays` by construction so they don't stretch
    /// the y-axis — the scale reads off the real cycles.
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
        let lastReal = points.lastIndex(where: { !$0.isPredicted }) ?? -1
        let readings = points.enumerated().map { index, point in
            let prefix = point.isPredicted ? "Forecast " : ""
            let suffix = index == lastReal ? ", current cycle" : ""
            return "\(prefix)\(monthLabel(for: point.startDate)) \(point.days) days\(suffix)"
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
                        .frame(height: CGFloat(60 + (index * 12 % 60)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150)

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3).fill(skeletonFill).frame(height: 8)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    private var skeletonFill: Color { DesignColors.text.opacity(0.08) }
}
