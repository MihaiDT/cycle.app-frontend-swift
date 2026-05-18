import SwiftUI

// MARK: - Cycle History (All)
//
// Full-screen archive of every logged cycle. Shares the
// CycleHistoryEntry rendering with the compact card so a cycle
// reads identically in both surfaces — only the grouping (by year)
// and filtering (All / 3 / 6 / 12 months) are new.

enum CycleHistoryFilter: Hashable, Identifiable {
    case all
    case last3
    case last6
    case lastYear
    case year(Int)

    var id: String {
        switch self {
        case .all:           return "all"
        case .last3:         return "last3"
        case .last6:         return "last6"
        case .lastYear:      return "lastYear"
        case .year(let y):   return "year-\(y)"
        }
    }

    var label: String {
        switch self {
        case .all:           return "All cycles"
        case .last3:         return "Last 3 cycles"
        case .last6:         return "Last 6 cycles"
        case .lastYear:      return "Last year"
        case .year(let y):   return String(y)
        }
    }

    /// Compact label used inside the native segmented picker, which
    /// divides the row evenly — long phrases like "Last 3 cycles"
    /// truncate once you add a couple of year pills. Short forms
    /// preserve scanability when 5+ segments are visible.
    var shortLabel: String {
        switch self {
        case .all:           return "All"
        case .last3:         return "3"
        case .last6:         return "6"
        case .lastYear:      return "1Y"
        case .year(let y):   return String(y)
        }
    }

    func apply(to timelines: [CycleHistoryTimeline]) -> [CycleHistoryTimeline] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch self {
        case .all:
            return timelines
        case .last3:
            return Array(timelines.suffix(3))
        case .last6:
            return Array(timelines.suffix(6))
        case .lastYear:
            guard let cutoff = cal.date(byAdding: .year, value: -1, to: today)
            else { return timelines }
            return timelines.filter { $0.startDate >= cutoff }
        case .year(let y):
            return timelines.filter {
                cal.component(.year, from: $0.startDate) == y
            }
        }
    }
}

struct CycleHistoryAllView: View {
    let timelines: [CycleHistoryTimeline]
    let hiddenKeys: Set<String>
    let onHide: (String) -> Void
    let onUnhide: (String) -> Void
    let onOpenDetail: (String) -> Void
    let onOpenStatInfo: (CycleStatInfoKind) -> Void
    let onDismiss: () -> Void

    @State private var filter: CycleHistoryFilter = .all
    @State private var pendingHide: CycleHistoryTimeline?
    /// Deferred content gate. The push animation evaluates this view's
    /// body synchronously; rendering year sections (each with a Canvas
    /// dot bar + Canvas mood/energy/sleep rows per cycle) inside that
    /// pass fights the 60fps slide and produces the "stuck a couple
    /// seconds" feel on first push. Holding off until after the
    /// transition lets nav complete cleanly, then content materializes
    /// below the perceptual threshold.
    @State private var isHydrated = false

    private var filteredTimelines: [CycleHistoryTimeline] {
        // Mirror the main history card: this screen shows *completed*
        // cycles only. The in-progress one is surfaced elsewhere
        // (Today hero, phases) so it doesn't need to appear here.
        filter.apply(to: timelines.filter { !$0.isCurrent })
    }

    /// Filter pill list = the 4 curated ranges plus a pill per
    /// previous calendar year that has logged cycles. The current
    /// year isn't listed because it already overlaps "Last year"
    /// and the 4 rolling-window pills.
    private var filterOptions: [CycleHistoryFilter] {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let years = Set(timelines.map { cal.component(.year, from: $0.startDate) })
            .filter { $0 < currentYear }
            .sorted(by: >)
        return [.all, .last3, .last6, .lastYear] + years.map(CycleHistoryFilter.year)
    }

    /// Cycles grouped by start year. Oldest-first inside each year,
    /// latest year first so the reader lands on recent history.
    private var yearGroups: [(year: Int, cycles: [CycleHistoryTimeline])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredTimelines) {
            cal.component(.year, from: $0.startDate)
        }
        return grouped
            .map { (year: $0.key, cycles: $0.value.sorted { $0.startDate > $1.startDate }) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
                filterRow
                legendRow

                if isHydrated {
                    if yearGroups.isEmpty {
                        emptyState
                    } else {
                        // Lazy + deferred: each year section
                        // instantiates its `CycleHistoryEntry` views
                        // (dot bar + Canvas mood/energy/sleep rows)
                        // only when its row enters the viewport, and
                        // the whole block waits for `isHydrated` so
                        // the push animation runs against an empty
                        // sub-tree first.
                        LazyVStack(alignment: .leading, spacing: 28, pinnedViews: []) {
                            ForEach(yearGroups, id: \.year) { group in
                                yearSection(year: group.year, cycles: group.cycles)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingL)
            .padding(.bottom, AppLayout.spacingXXL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Match the Cycle Stats / BodyPatterns surface — peach
        // gradient top + cream extending edge-to-edge under the
        // nav bar. JourneyAnimatedBackground belonged to the
        // earlier journey-tab framing that was retired; using it
        // here made Cycle History feel like a different feature.
        .background { AppleHealthBackground().ignoresSafeArea() }
        .navigationTitle("Cycle history")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // ~80ms is enough for the navigation slide to land on
            // most devices without becoming visible as a separate
            // "things popping in" beat.
            try? await Task.sleep(nanoseconds: 80_000_000)
            isHydrated = true
        }
        .sheet(item: $pendingHide) { timeline in
            HideCycleDialog(
                cycleLabel: Self.sheetCycleLabel(for: timeline),
                onConfirm: {
                    onHide(timeline.id)
                    pendingHide = nil
                },
                onCancel: { pendingHide = nil }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: - Sheet Nav

    @ViewBuilder
    private var sheetNav: some View {
        ZStack {
            Text("Cycle history")
                .font(AppTypography.cardTitleTertiary)
                .tracking(-0.2)
                .foregroundStyle(DesignColors.text)

            HStack {
                Spacer()
                AppCloseButton(action: onDismiss)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    // MARK: - Filter
    //
    // Native segmented picker — simpler than the custom pill row and
    // picks up the app-wide Cocoa Dark title attrs already registered
    // by `CycleTrendCard`. The row divides its width evenly across
    // options, so `shortLabel` is used to keep things scannable when
    // several year pills are present.

    @ViewBuilder
    private var filterRow: some View {
        Picker("Filter", selection: $filter) {
            ForEach(filterOptions) { option in
                Text(option.shortLabel).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Legend

    @ViewBuilder
    private var legendRow: some View {
        HStack(spacing: 16) {
            legendItem(
                tint: CyclePhase.menstrual.orbitColor,
                tintOpacity: 0.95,
                label: "Period"
            )
            legendItem(
                tint: CyclePhase.ovulatory.orbitColor,
                tintOpacity: 0.55,
                label: "Fertile window"
            )
            legendDotItem(
                tint: CyclePhase.ovulatory.orbitColor,
                label: "Ovulation"
            )
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func legendItem(tint: Color, tintOpacity: Double, label: String) -> some View {
        HStack(spacing: 6) {
            PhaseGlossyDot(tint: tint, size: 8, tintOpacity: tintOpacity)
            Text(label)
                .font(.raleway("Medium", size: 11, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
        }
    }

    @ViewBuilder
    private func legendDotItem(tint: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(DesignColors.background)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle()
                        .stroke(tint, lineWidth: 1.4)
                }
            Text(label)
                .font(.raleway("Medium", size: 11, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
        }
    }

    // MARK: - Year Section

    @ViewBuilder
    private func yearSection(year: Int, cycles: [CycleHistoryTimeline]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(year))
                .font(AppTypography.cardTitleSecondary)
                .tracking(-0.4)
                .foregroundStyle(DesignColors.text)

            VStack(spacing: 18) {
                ForEach(Array(cycles.enumerated()), id: \.element.id) { idx, timeline in
                    VStack(alignment: .leading, spacing: 18) {
                        yearCycleRow(for: timeline)

                        if idx < cycles.count - 1 {
                            Rectangle()
                                .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetCardStyle(cornerRadius: 28)
        }
    }

    @ViewBuilder
    private func yearCycleRow(for timeline: CycleHistoryTimeline) -> some View {
        if hiddenKeys.contains(timeline.id) {
            hiddenYearRow(for: timeline)
        } else {
            CycleHistoryEntry(
                timeline: timeline,
                onMenuTap: { pendingHide = timeline }
            )
            .contentShape(Rectangle())
            .onTapGesture { onOpenDetail(timeline.id) }
        }
    }

    @ViewBuilder
    private func hiddenYearRow(for timeline: CycleHistoryTimeline) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Self.sheetCycleLabel(for: timeline))
                    .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text.opacity(0.6))
                    .lineLimit(1)

                Spacer(minLength: 6)

                Button {
                    onUnhide(timeline.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Bring back")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    }
                    .foregroundStyle(DesignColors.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            CycleHistoryBar(timeline: timeline)
                .opacity(0.45)
        }
    }

    // MARK: - Empty

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing here yet.")
                .font(AppTypography.rowTitleEmphasized)
                .foregroundStyle(DesignColors.text)
            Text("Once you log a period, cycles will collect here by year.")
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Shared label

    private static let sheetDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static func sheetCycleLabel(for timeline: CycleHistoryTimeline) -> String {
        let start = sheetDateFormatter.string(from: timeline.startDate)
        if timeline.isCurrent {
            return "Current cycle · from \(start)"
        }
        let end = sheetDateFormatter.string(from: timeline.endDate)
        return "\(timeline.length) days · \(start) – \(end)"
    }
}
