import SwiftUI

// MARK: - Cycle Trend Card
//
// Replaces the older "Your Cycle Average" card. Same data source
// (`stats.cycleLength.history`) but reframes the answer from a single
// number to a visible pattern — six most recent cycles as bars, with
// the user's running average shown as a dashed guide line. The latest
// cycle is the accent bar so the eye lands there first, and the
// segmented control (6M / 1Y / All) scopes the window without opening
// a second screen.

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
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            chart
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CYCLE TREND")
                    .font(AppTypography.cardEyebrow)
                    .tracking(AppTypography.cardEyebrowTracking)
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.75))

                Text(headerSubtitle)
                    .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)
            }
            Spacer(minLength: 8)
            windowPicker
        }
    }

    private var headerSubtitle: String {
        let count = visiblePoints.count
        guard count > 0 else { return "Not enough cycles yet" }
        return "Length per cycle · last \(count)"
    }

    private var windowPicker: some View {
        HStack(spacing: 2) {
            ForEach(Window.allCases, id: \.self) { w in
                Button {
                    window = w
                } label: {
                    Text(w.rawValue)
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                        .foregroundStyle(w == window ? DesignColors.text : DesignColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(w == window ? DesignColors.background : Color.clear)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(w.rawValue) range")
                .accessibilityAddTraits(w == window ? [.isSelected, .isButton] : [.isButton])
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignColors.text.opacity(0.05))
        }
    }

    // MARK: - Chart

    private var chart: some View {
        let visible = visiblePoints
        let range = chartRange(for: visible)
        return VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, point in
                        bar(for: point, isCurrent: index == visible.count - 1, range: range)
                    }
                }

                if !visible.isEmpty, range.upper > range.lower {
                    averageOverlay(range: range)
                }
            }
            .frame(height: 150)

            monthLabels(for: visible)
        }
    }

    private func bar(for point: Point, isCurrent: Bool, range: (lower: Int, upper: Int)) -> some View {
        let span = max(CGFloat(range.upper - range.lower), 1)
        let normalized = (CGFloat(point.days - range.lower) / span) * 110 + 24
        return VStack(spacing: 6) {
            Text("\(point.days)")
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .foregroundStyle(
                    isCurrent
                        ? DesignColors.accentWarmText
                        : DesignColors.textSecondary
                )

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCurrent ? DesignColors.accentWarm : DesignColors.accentWarm.opacity(0.14))
                .frame(height: normalized)
                .accessibilityLabel(
                    "\(monthLabel(for: point.startDate)), \(point.days) days\(isCurrent ? ", current cycle" : "")"
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func averageOverlay(range: (lower: Int, upper: Int)) -> some View {
        let span = max(CGFloat(range.upper - range.lower), 1)
        let offset = (CGFloat(averageDays - range.lower) / span) * 110 + 24
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                DashedLine()
                    .stroke(
                        DesignColors.text.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                    .frame(height: 1)

                Text("avg \(averageDays)d")
                    .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background {
                        Capsule().fill(DesignColors.background)
                    }
                    .offset(x: 0, y: -10)
            }
            .frame(width: geo.size.width, alignment: .leading)
            .offset(y: -offset)
        }
        .frame(height: 1)
        .accessibilityLabel("Average \(averageDays) days")
    }

    private func monthLabels(for points: [Point]) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                Text(monthLabel(for: point.startDate))
                    .font(
                        .raleway(
                            index == points.count - 1 ? "SemiBold" : "Medium",
                            size: 11,
                            relativeTo: .caption2
                        )
                    )
                    .foregroundStyle(
                        index == points.count - 1
                            ? DesignColors.text
                            : DesignColors.textSecondary
                    )
                    .frame(maxWidth: .infinity)
            }
        }
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
    /// plus the average line so the bars never render at 0 height when
    /// all cycles are close to each other. The floor/ceiling widen in
    /// whole days so y-axis scale reads stable cycle-to-cycle.
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
}

// MARK: - Dashed line shape

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Skeleton

struct CycleTrendSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(skeletonFill).frame(width: 90, height: 10)
                    RoundedRectangle(cornerRadius: 3).fill(skeletonFill).frame(width: 140, height: 10)
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
