import ComposableArchitecture
import Foundation
import SwiftUI

// MARK: - View

public struct CycleInsightsView: View {
    let store: StoreOf<CycleInsightsFeature>

    /// Typed navigation path for Cycle Stats' inner stack. Using
    /// `NavigationStack(path:)` with a single `Hashable` enum keeps
    /// pushes in the right direction (slide from trailing) and lets
    /// us chain archive → detail without the dual-`isPresented`
    /// navigationDestinations fighting over which route is on top.
    @State private var historyPath: [HistoryRoute] = []

    /// Preview-before-share cover for the rhythm reflection card.
    /// Keeps the user from firing a raw `UIActivityViewController`
    /// before they've seen what actually gets shared – matches the
    /// Lively-style pattern where the export sits on its own surface
    /// with only a share button, no "Instagram Story" shortcut.
    @State var isShareReflectionVisible: Bool = false

    enum HistoryRoute: Hashable {
        case allHistory
        case detail(String)
        case customize
        case statInfo(CycleStatInfoKind)
    }

    func popLast() {
        guard !historyPath.isEmpty else { return }
        historyPath.removeLast()
    }

    public init(store: StoreOf<CycleInsightsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $historyPath) {
            // UIKit-backed UICollectionView via `CycleStatsCardList`.
            // SwiftUI's `List` and `ScrollView + VStack` both showed
            // AttributeGraph/SwiftUI layout engine dominating CPU in
            // Time Profiler on iOS 26 even with plain Text rows —
            // the scroll overhead was structural, not content-bound.
            // UIKit's scroll view engine (battle-tested since iOS 2)
            // handles the scroll, and each card's SwiftUI body only
            // runs once when its cell is configured, not per-frame.
            ZStack {
                JourneyAnimatedBackground(animated: false)

                if store.statsLayout.visibleOrder.isEmpty {
                    ScrollView {
                        emptyLayoutPrompt
                            .padding(.horizontal, AppLayout.screenHorizontal)
                            .padding(.top, AppLayout.spacingL)
                        customizeEntryPoint
                            .padding(.horizontal, AppLayout.screenHorizontal)
                            .padding(.top, AppLayout.spacingL)
                            .padding(.bottom, AppLayout.spacingXXL)
                    }
                } else {
                    CycleStatsCardList(
                        cards: store.statsLayout.visibleOrder,
                        contentInsets: UIEdgeInsets(
                            top: AppLayout.spacingL,
                            left: AppLayout.screenHorizontal,
                            bottom: AppLayout.spacingXXL,
                            right: AppLayout.screenHorizontal
                        ),
                        interItemSpacing: AppLayout.spacingL,
                        cardContent: { card in AnyView(statsCardView(for: card)) },
                        trailingContent: { AnyView(customizeEntryPoint) }
                    )
                    // Extend the collection view under both safe areas
                    // so content scrolls under the translucent nav bar
                    // (top) and past the home indicator (bottom).
                    // UICollectionView's `contentInsetAdjustmentBehavior
                    // = .automatic` (set in `makeUIView`) auto-pads the
                    // top by the nav bar height so the first card still
                    // starts visually under the bar.
                    .ignoresSafeArea(.container, edges: [.top, .bottom])
                }
            }
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if !historyPath.isEmpty { historyPath.removeAll() }
                        DispatchQueue.main.async {
                            store.send(.dismissTapped)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignColors.text)
                    }
                    .accessibilityLabel("Back")
                }
            }
            .navigationDestination(for: HistoryRoute.self) { route in
                switch route {
                case .allHistory:
                    CycleHistoryAllView(
                        timelines: historyTimelines,
                        hiddenKeys: store.hiddenCycleKeys,
                        onHide: { key in store.send(.hideCycle(key)) },
                        onUnhide: { key in store.send(.unhideCycle(key)) },
                        onOpenDetail: { id in historyPath.append(.detail(id)) },
                        onOpenStatInfo: { kind in historyPath.append(.statInfo(kind)) },
                        onDismiss: { popLast() }
                    )
                case .detail(let id):
                    if let timeline = historyTimelines.first(where: { $0.id == id }) {
                        CycleDetailsView(
                            timeline: timeline,
                            onDismiss: { popLast() },
                            onStatInfoTap: { kind in
                                historyPath.append(.statInfo(kind))
                            }
                        )
                    }
                case .customize:
                    CycleStatsCustomizeView(
                        layout: Binding(
                            get: { store.statsLayout },
                            set: { store.send(.layoutChanged($0)) }
                        ),
                        onDismiss: { popLast() }
                    )
                case .statInfo(let kind):
                    CycleStatInfoDetailView(
                        kind: kind,
                        previousValue: previousValueLabel(for: kind),
                        badge: statBadge(for: kind)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { store.send(.onAppear) }
        .fullScreenCover(isPresented: $isShareReflectionVisible) {
            RhythmReflectionShareScreen(
                copy: store.rhythmReflectionCopy,
                onDismiss: { isShareReflectionVisible = false }
            )
        }
    }

    // MARK: - Data Accessors

    struct PastCycleEntry: Equatable, Identifiable {
        let id: Date
        let startDate: Date
        let length: Int
    }

    var pastCycleEntries: [PastCycleEntry] {
        guard let history = store.stats?.cycleLength.history else { return [] }
        return history.map {
            PastCycleEntry(id: $0.startDate, startDate: $0.startDate, length: $0.length)
        }
    }

    var averageLengthInt: Int {
        if let avg = store.stats?.cycleLength.average, avg > 0 {
            return Int(avg.rounded())
        }
        if let profileAvg = store.cycleContext?.cycleLength, profileAvg > 0 {
            return profileAvg
        }
        return 0
    }

    /// Rounded cycle-length mean used by the overview row. Returns
    /// nil so the box can render its muted "No data" state instead
    /// of a meaningless "0 days".
    var cycleAverageDays: Int? {
        if let avg = store.stats?.cycleLength.average, avg > 0 {
            return Int(avg.rounded())
        }
        if let profileAvg = store.cycleContext?.cycleLength, profileAvg > 0 {
            return profileAvg
        }
        return nil
    }

    /// Mean bleeding-days across logged cycles. Falls back to the
    /// profile's `bleedingDays` when stats history isn't available
    /// yet (fresh install, only the current cycle logged).
    var periodAverageDays: Int? {
        let history = store.stats?.cycleLength.history ?? []
        let bleeds = history.map(\.bleeding).filter { $0 > 0 }
        if !bleeds.isEmpty {
            let avg = Double(bleeds.reduce(0, +)) / Double(bleeds.count)
            return Int(avg.rounded())
        }
        if let profileBleeds = store.cycleContext?.bleedingDays, profileBleeds > 0 {
            return profileBleeds
        }
        return nil
    }

    // MARK: - Normality card inputs

    /// Length of the most recently completed cycle — the "one just
    /// before the one you're living in now". Drawn from the sorted
    /// history so it matches the pill timeline below the card.
    var previousCycleLength: Int? {
        let history = (store.stats?.cycleLength.history ?? [])
            .sorted { $0.startDate < $1.startDate }
        return history.last?.length
    }

    /// Bleeding duration of the most recently logged period.
    var previousPeriodLength: Int? {
        let history = (store.stats?.cycleLength.history ?? [])
            .sorted { $0.startDate < $1.startDate }
        if let latest = history.last, latest.bleeding > 0 {
            return latest.bleeding
        }
        if let profileBleeds = store.cycleContext?.bleedingDays, profileBleeds > 0 {
            return profileBleeds
        }
        return nil
    }

    /// Standard deviation of logged cycle lengths — drives the variation
    /// verdict. The Normality card hides the value until we have enough
    /// cycles to report honestly (see `minimumCyclesForVariation`).
    var variationStdDev: Double? {
        store.stats?.cycleLength.stdDev
    }

    var loggedCycleCount: Int {
        store.stats?.cycleLength.history.count ?? 0
    }

    /// Feed for the Cycle Trend card: real logged cycles plus the
    /// forecasts the predictor already generated for the calendar. Each
    /// predicted cycle length is derived from the gap to the previous
    /// start date, so the ghost bars reflect the same variance the
    /// calendar shows — not a flat `avg` row.
    ///
    /// Anchors forecasts from `currentCycleStartDate` when available
    /// (the in-progress cycle's start), falling back to the last closed
    /// cycle. Anchoring from the last *closed* cycle would double-count
    /// the current cycle in the gap — prediction[0] would read as a
    /// 60-day "phantom" spanning both.
    var trendPoints: [CycleTrendCard.Point] {
        let real = pastCycleEntries.map {
            CycleTrendCard.Point(
                id: $0.id,
                startDate: $0.startDate,
                days: $0.length,
                isPredicted: false
            )
        }
        guard
            let predictions = store.journey?.predictions,
            !predictions.isEmpty,
            let anchor = store.journey?.currentCycleStartDate ?? real.last?.startDate
        else { return real }

        let cal = Calendar.current
        var previous = anchor
        let fallback = max(averageLengthInt, 1)
        let predicted: [CycleTrendCard.Point] = predictions
            .sorted { $0.predictedDate < $1.predictedDate }
            .map { prediction in
                let days = cal.dateComponents([.day], from: previous, to: prediction.predictedDate).day ?? fallback
                previous = prediction.predictedDate
                return CycleTrendCard.Point(
                    id: prediction.predictedDate,
                    startDate: prediction.predictedDate,
                    days: max(days, 1),
                    isPredicted: true
                )
            }
        return real + predicted
    }

    @ViewBuilder
    func statsCardView(for card: CycleStatsCard) -> some View {
        // `.drawingGroup(opaque: false)` on every card **except** the
        // chart card rasterizes each card's full visual tree into a
        // Metal bitmap at the cell's hosting boundary. Scrolling the
        // UICollectionView then only translates those bitmaps — the
        // SwiftUI view tree inside each cell doesn't have to re-
        // composite its shadow/clip/fill stack per frame. The chart
        // card (`.avgCycle`) skips drawingGroup because Swift Charts'
        // `Path`-based rendering disappears inside Metal flattening
        // on iOS 26 — we tested this several times.
        // `widgetCardStyle` now owns the per-card `drawingGroup`
        // internally, so dispatcher cases render the bare component
        // and let the style modifier handle rasterization + shadow
        // layering. Applying drawingGroup here too would double-
        // rasterize and re-introduce the clipped-shadow artifact.
        switch card {
        case .overview:
            if store.stats != nil {
                CycleStatsOverviewRow(
                    cycleAverageDays: cycleAverageDays,
                    periodAverageDays: periodAverageDays
                )
            } else {
                CycleStatsOverviewSkeleton()
            }
        case .normality:
            if store.stats != nil {
                CycleNormalityCard(
                    previousCycleLength: previousCycleLength,
                    previousPeriodLength: previousPeriodLength,
                    variationStdDev: variationStdDev,
                    averageCycleLength: store.stats?.cycleLength.average,
                    cycleCount: loggedCycleCount,
                    onInfoTap: { kind in historyPath.append(.statInfo(kind)) }
                )
            } else {
                CycleNormalitySkeleton()
            }
        case .avgCycle:
            if store.stats != nil {
                CycleTrendCard(
                    points: trendPoints,
                    averageDays: averageLengthInt
                )
            } else {
                CycleTrendSkeleton()
            }
        case .history:
            if store.journey != nil {
                CycleHistoryCard(
                    timelines: historyTimelines,
                    hiddenKeys: store.hiddenCycleKeys,
                    onHide: { key in store.send(.hideCycle(key)) },
                    onUnhide: { key in store.send(.unhideCycle(key)) },
                    onOpenDetail: { id in historyPath.append(.detail(id)) },
                    onSeeAll: { historyPath.append(.allHistory) }
                )
            } else {
                CycleHistorySkeleton()
            }
        case .reflection:
            rhythmReflection
                .drawingGroup(opaque: false)
        }
    }

    /// Entry point at the foot of the stats screen. Styled as a
    /// quiet tertiary action so it doesn't compete with the cards
    /// above — just enough affordance to invite exploration.
    @ViewBuilder
    var customizeEntryPoint: some View {
        Button {
            historyPath.append(.customize)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                Text("Customize this screen")
                    .font(.raleway("Medium", size: 14, relativeTo: .callout))
            }
            .foregroundStyle(DesignColors.accentWarmText)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .overlay {
                        Capsule()
                            .stroke(DesignColors.text.opacity(DesignColors.borderOpacitySubtle), lineWidth: 0.6)
                    }
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .accessibilityLabel("Customize this screen")
    }

    /// Shown when the user has hidden every card. Gives them a
    /// zero-state pointer back to the customize screen so they're
    /// never stranded on a blank stats page.
    @ViewBuilder
    var emptyLayoutPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your stats screen is empty.")
                .font(.raleway("SemiBold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text)
            Text("Open customize to bring any card back.")
                .font(.raleway("Regular", size: 14, relativeTo: .callout))
                .foregroundStyle(DesignColors.text.opacity(0.75))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Stat Info helpers

    func previousValueLabel(for kind: CycleStatInfoKind) -> String? {
        switch kind {
        case .cycleLength:
            return previousCycleLength.map { "\($0) days" }
        case .periodLength:
            return previousPeriodLength.map { "\($0) \($0 == 1 ? "day" : "days")" }
        case .cycleVariation:
            return CycleNormality.classifyVariation(
                stdDev: variationStdDev,
                averageLength: store.stats?.cycleLength.average,
                cycleCount: loggedCycleCount
            )?.value
        }
    }

    // MARK: - History inputs

    var historyTimelines: [CycleHistoryTimeline] {
        store.historyTimelines
    }

    func statBadge(for kind: CycleStatInfoKind) -> CycleStatusBadge? {
        switch kind {
        case .cycleLength:
            return previousCycleLength.map(CycleNormality.classifyCycleLength(days:))
        case .periodLength:
            return previousPeriodLength.map(CycleNormality.classifyPeriodLength(days:))
        case .cycleVariation:
            return CycleNormality.classifyVariation(
                stdDev: variationStdDev,
                averageLength: store.stats?.cycleLength.average,
                cycleCount: loggedCycleCount
            )?.badge
        }
    }

    // MARK: - Sheet Nav

    @ViewBuilder
    var sheetNav: some View {
        ZStack {
            Text(headerTitle)
                .font(.raleway("Bold", size: 17, relativeTo: .headline))
                .tracking(-0.2)
                .foregroundStyle(DesignColors.text)

            HStack {
                Spacer()
                Button {
                    store.send(.dismissTapped)
                } label: {
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

    // MARK: - Header Copy
    //
    // Parent screen is always Cycle Stats — the Body Patterns entry point
    // from Home is a deep-link that should open a detail sheet on top, not
    // rename the host. Keeping this tied to `activeDetail` previously left
    // the title stuck on "Body Patterns" after the sheet was dismissed.

    var headerTitle: String { "Cycle Stats" }

    var headerEyebrow: String? { "Averages & trends" }
}

