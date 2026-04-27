import SwiftUI
import UIKit

// MARK: - Cycle Trend Card
//
// Replaces the older "Your Cycle Average" card. Reframes the answer from
// a single number to a visible pattern — recent logged cycles as bars,
// running average in the subtitle. The latest cycle is the accent bar
// so the eye lands there first, and the segmented control (6M / 1Y /
// All) scopes the window.

public struct CycleTrendCard: View, Equatable {
    // Equatable lets the call site wrap with `.equatable()` so
    // SwiftUI short-circuits body re-evaluations when neither the
    // points nor the average actually changed. This is the dominant
    // mid-scroll cost: each parent body re-eval (TCA observation,
    // host VC re-host, etc.) used to spin a fresh chart layout
    // through GeometryReader + 12+ glossy-bar layers per frame.
    /// `nonisolated` is required because `View` is implicitly
    /// `@MainActor`-isolated under Swift 6 strict concurrency.
    /// SwiftUI's diffing calls `==` off the main actor; the
    /// compared properties are all value types so the comparison
    /// is data-race-safe.
    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.points == rhs.points && lhs.averageDays == rhs.averageDays
    }


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
    /// `nil` until the chart settles on a default — the most recent
    /// visible cycle. Tracked separately so the user can scroll
    /// (window changes) without losing their pick when it stays
    /// visible.
    @State private var selectedCycleID: Date?

    /// Hard cap on visible bars so columns never collapse into
    /// hairlines. The card hosts a fit-style chart (no horizontal
    /// scroll) — anything wider than this and bars start losing
    /// their pill silhouette.
    private static let maxVisibleBars: Int = 12

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

    /// The picker only earns its place once the user has enough cycles
    /// for the windows (6M / 1Y / All) to show different data. With 1–3
    /// cycles all three options render the same chart, so the control
    /// is dead chrome — hide it until N ≥ this threshold.
    private static let pickerVisibleAtCount: Int = 4

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            if visiblePoints.isEmpty {
                emptyState
            } else {
                if hasMixedRangeClassifications {
                    rangeLegend
                }
                chart
                detailDivider
                detailBlock
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `rasterize: false` — the native segmented Picker is UIKit-backed
        // and can't be flattened into a Metal bitmap by `.drawingGroup`.
        .widgetCardStyle(cornerRadius: 28, rasterize: false)
        .accessibilityElement(children: .contain)
        .onAppear(perform: ensureSelectionInitialized)
        .onChange(of: visiblePoints.map(\.id)) { _, _ in
            ensureSelectionInitialized()
        }
    }

    // MARK: - Selection bookkeeping
    //
    // Default to the most recent visible cycle. When the user
    // changes the window (6M → 1Y → All) and their previously
    // selected cycle disappears from view, fall back to the
    // newest visible bar instead of leaving the detail block
    // pinned to a no-longer-visible point.

    private func ensureSelectionInitialized() {
        let visible = visiblePoints
        guard !visible.isEmpty else {
            selectedCycleID = nil
            return
        }
        if let current = selectedCycleID, visible.contains(where: { $0.id == current }) {
            return
        }
        selectedCycleID = visible.last?.id
    }

    // MARK: - Header
    //
    // Mirrors the hero-title treatment used by CycleHistoryCard so the
    // stats screen reads as a single editorial spread.

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(DesignColors.textSecondary)
                    Text("CYCLE TREND")
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                        .tracking(1.4)
                        .foregroundStyle(DesignColors.textSecondary)
                }

                Text(subtitle)
                    .font(.raleway("SemiBold", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                    .contentTransition(.numericText())
                    .transaction { $0.animation = .easeInOut(duration: 0.25) }
            }
            Spacer(minLength: 8)
            if points.count >= Self.pickerVisibleAtCount {
                windowPicker
            }
        }
    }

    private var subtitle: String {
        let count = visiblePoints.count
        guard count > 0 else { return "Not enough cycles yet" }
        let noun = count == 1 ? "cycle" : "cycles"
        return "Last \(count) \(noun) · Avg \(averageDays) days"
    }

    // MARK: - Range Legend
    //
    // Names the two-color vocabulary used by the bars: terracotta for
    // cycles inside the ACOG normal window (21–35 days), honey for
    // cycles outside it. Always renders so the user learns the system
    // before they ever see an outside-range bar.

    private var rangeLegend: some View {
        HStack(spacing: 14) {
            legendSwatch(label: "IN RANGE", color: DesignColors.accentWarm)
            legendSwatch(label: "OUTSIDE", color: DesignColors.accentHoney)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bars in terracotta sit inside the typical cycle range; honey bars sit outside it.")
    }

    private func legendSwatch(label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 14, height: 5)
            Text(label)
                .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
                .tracking(0.9)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
        }
    }

    // MARK: - Bar tinting
    //
    // Uses the same classification as the Normality card so the two
    // surfaces stay in sync — a "needs attention" cycle on the rows
    // wears the same hue here on the chart.

    private func tint(for point: Point) -> Color {
        switch CycleNormality.classifyCycleLength(days: point.days).tone {
        case .normal:         return DesignColors.accentWarm
        case .needsAttention: return DesignColors.accentHoney
        }
    }

    /// Legend earns its place only when at least one bar of each
    /// classification is visible — otherwise it's dead chrome
    /// (e.g. all bars terracotta, "OUTSIDE" swatch promises a contrast
    /// the chart never delivers).
    private var hasMixedRangeClassifications: Bool {
        var hasNormal = false
        var hasOutside = false
        for p in visiblePoints {
            switch CycleNormality.classifyCycleLength(days: p.days).tone {
            case .normal:         hasNormal = true
            case .needsAttention: hasOutside = true
            }
            if hasNormal && hasOutside { return true }
        }
        return false
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
    //
    // Wraps the reusable `TrendBarChart` from DesignSystem. Each bar
    // carries the cycle's classification tint so the in-range /
    // outside-range vocabulary stays visible regardless of which
    // bar is selected. Tap on a column hands the cycle's `id` down
    // and the detail block beneath the chart re-keys to it.

    private var chart: some View {
        let visible = visiblePoints
        return TrendBarChart(
            items: visible.map { point in
                TrendBarChart<Date>.Item(
                    id: point.id,
                    value: Double(point.days),
                    xLabel: monthLabel(for: point.startDate),
                    tint: tint(for: point)
                )
            },
            selectedID: selectedCycleID,
            onSelect: { id in
                selectedCycleID = id
            },
            yLabelFormatter: { "\(Int($0.rounded()))d" },
            yTickCount: 4,
            chartHeight: 180
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chartAccessibilityLabel(for: visible))
    }

    // MARK: - Detail block
    //
    // Sub-card beneath the chart that names the selected cycle's
    // numbers — length, variation vs. average, range classification,
    // and position within the visible window. Re-keys with the
    // selection so the numeric content transitions can fire.

    @ViewBuilder
    private var detailBlock: some View {
        if let point = selectedPoint, let position = selectedPosition {
            CycleTrendDetailBlock(
                cycleLength: point.days,
                startDate: point.startDate,
                averageDays: averageDays,
                positionIndex: position.index,
                positionTotal: position.total,
                isInTypicalRange: CycleNormality.classifyCycleLength(days: point.days).tone == .normal
            )
            .id(point.id)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: point.id)
        }
    }

    private var detailDivider: some View {
        Rectangle()
            .fill(DesignColors.text.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private var selectedPoint: Point? {
        guard let id = selectedCycleID else { return nil }
        return visiblePoints.first { $0.id == id }
    }

    private var selectedPosition: (index: Int, total: Int)? {
        guard let id = selectedCycleID else { return nil }
        let visible = visiblePoints
        guard let idx = visible.firstIndex(where: { $0.id == id }) else { return nil }
        return (idx + 1, visible.count)
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
        let windowCap = window.maxEntries ?? Self.maxVisibleBars
        let cap = min(windowCap, Self.maxVisibleBars)
        return Array(sorted.suffix(cap))
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
            let range = CycleNormality.classifyCycleLength(days: point.days).tone == .normal
                ? "in range"
                : "outside range"
            return "\(monthLabel(for: point.startDate)) \(point.days) days, \(range)\(suffix)"
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
