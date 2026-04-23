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
    @Namespace private var filterNamespace

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
            VStack(alignment: .leading, spacing: 24) {
                filterRow
                legendRow

                if yearGroups.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(yearGroups, id: \.year) { group in
                            yearSection(year: group.year, cycles: group.cycles)
                        }
                    }
                }
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, AppLayout.spacingL)
            .padding(.bottom, AppLayout.spacingXXL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { JourneyAnimatedBackground(animated: false) }
        .navigationTitle("Cycle history")
        .navigationBarTitleDisplayMode(.inline)
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
                .font(.raleway("Bold", size: 17, relativeTo: .headline))
                .tracking(-0.2)
                .foregroundStyle(DesignColors.text)

            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignColors.text)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(DesignColors.text.opacity(0.06))
                        }
                        .overlay {
                            Circle()
                                .stroke(DesignColors.text.opacity(0.08), lineWidth: 0.6)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    // MARK: - Filter
    //
    // One unified segmented capsule instead of four floating pills.
    // The selected option carries a `matchedGeometryEffect` indicator
    // that slides under taps — the container stays quiet, only the
    // indicator moves. Matches the editorial restraint of the rest
    // of the card language.

    @ViewBuilder
    private var filterRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(filterOptions) { option in
                        filterPill(for: option, proxy: proxy)
                            .id(option.id)
                    }
                }
                .padding(4)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                }
                // Animation is scoped to this HStack so the
                // `matchedGeometryEffect` indicator slides between
                // pills, but the year groups below re-render
                // instantly on filter change — no 400ms transaction
                // across the whole scroll subtree.
                .animation(.smooth(duration: 0.22), value: filter)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private func filterPill(
        for option: CycleHistoryFilter,
        proxy: ScrollViewProxy
    ) -> some View {
        // Flatten the selected-state chrome to a single capsule fill
        // plus a hairline stroke. Tap handler sets the new filter
        // without `withAnimation` so the downstream content (year
        // groups + glass bars + dot rows) doesn't enter an animation
        // transaction just because the user switched tabs.
        let isSelected = filter == option
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            filter = option
            proxy.scrollTo(option.id, anchor: .center)
        } label: {
            Text(option.label)
                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                .lineLimit(1)
                .foregroundStyle(
                    isSelected
                        ? DesignColors.text
                        : DesignColors.textSecondary.opacity(0.55)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white.opacity(0.92))
                            .overlay {
                                Capsule()
                                    .stroke(
                                        DesignColors.text.opacity(0.06),
                                        lineWidth: 0.6
                                    )
                            }
                            .matchedGeometryEffect(id: "activeFilter", in: filterNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Legend

    @ViewBuilder
    private var legendRow: some View {
        HStack(spacing: 16) {
            legendItem(
                tint: CyclePhase.menstrual.orbitColor,
                label: "Period"
            )
            legendItem(
                tint: CyclePhase.ovulatory.orbitColor.opacity(0.55),
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
    private func legendItem(tint: Color, label: String) -> some View {
        HStack(spacing: 6) {
            legendGlassCapsule(tint: tint)
                .frame(width: 18, height: 6)
            Text(label)
                .font(.raleway("Medium", size: 11, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
        }
    }

    /// Miniature of the three-layer glass capsule used on the cycle
    /// bar — outer halo, tint body gradient, top specular — so the
    /// legend key visually matches the markers it's naming.
    @ViewBuilder
    private func legendGlassCapsule(tint: Color) -> some View {
        ZStack {
            Capsule()
                .fill(tint.opacity(0.32))
                .frame(width: 21, height: 9)
                .blur(radius: 1.8)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.95),
                            tint.opacity(0.72),
                            tint.opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 15, height: 2.5)
                .offset(y: -1.4)
                .blur(radius: 0.4)
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
                .font(.raleway("Bold", size: 22, relativeTo: .title2))
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
                .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
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
