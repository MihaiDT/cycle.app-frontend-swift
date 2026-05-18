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
        /// Body Signals detail. Optional `focused` deep-links the
        /// detail screen to a specific metric section — set when
        /// the user taps an individual tile (wrist temp / HRV /
        /// resting HR), nil when they tap the header / chevron.
        case bodySignalsDetail(focused: BodySignalMetric.Kind?)
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
                AppleHealthBackground()

                if store.statsLayout.visibleOrder.isEmpty {
                    ScrollView {
                        emptyLayoutPrompt
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
                        // `.id(card)` pins each card to its enum case so
                        // SwiftUI keeps the same identity across the
                        // `AnyView` wrapping that the collection list
                        // requires. Without this pin, every reconfigure
                        // (and every scroll-driven re-host) gave the
                        // hosted SwiftUI tree a fresh identity, which
                        // tore down `@State` (window picker, sheet
                        // state, drawer expansion) and forced full
                        // re-evaluation of the card body — the dominant
                        // mid-scroll churn `_printChanges` surfaced.
                        cardContent: { card in AnyView(statsCardView(for: card).id(card)) },
                        trailingContent: { AnyView(EmptyView()) },
                        // Today anchor — single editorial sentence
                        // ("Day 22. Luteal phase. Next period in 6
                        // days.") above the first card. Pins the
                        // reader to "where am I now" before the
                        // screen plonges into stats. Hidden when
                        // cycleContext hasn't loaded yet so the
                        // first card doesn't shift on appear.
                        leadingContent: store.cycleContext.map { ctx in
                            { AnyView(CycleStatsTodayHeader(context: ctx)) }
                        },
                        onScroll: nil,
                        reconfigureToken: AnyHashable(cardsReconfigureToken)
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if !historyPath.isEmpty { historyPath.removeAll() }
                        DispatchQueue.main.async {
                            store.send(.dismissTapped)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(DesignColors.text)
                    }
                    .glassToolbar()
                    .accessibilityLabel("Back")
                }
                ToolbarItem(placement: .principal) {
                    Text(headerTitle)
                        .font(AppTypography.rowTitleEmphasized)
                        .foregroundStyle(DesignColors.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        historyPath.append(.customize)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(DesignColors.text)
                    }
                    .glassToolbar()
                    .accessibilityLabel("Customize this screen")
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
                        badge: statBadge(for: kind),
                        cycleLengthDays: cycleAverageDays,
                        bleedingDays: periodAverageDays,
                        variationStdDev: variationStdDev
                    )
                case .bodySignalsDetail(let focused):
                    if let snapshot = store.bodySignals {
                        BodySignalsDetailView(
                            snapshot: snapshot,
                            focusedMetric: focused
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(DesignColors.text)
        .task { store.send(.onAppear) }
        .fullScreenCover(isPresented: $isShareReflectionVisible) {
            RhythmReflectionShareScreen(
                copy: store.rhythmReflectionCopy,
                phase: store.cycleContext?.currentPhase,
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

    /// Feed for the Cycle Trend card — only real logged cycles. The
    /// predictor currently writes every future prediction at the same
    /// `avgCycleLength`, so rendering forecasts as bars produced a
    /// deceptive flat row. Once the predictor emits per-cycle length
    /// variance, revisit and re-enable the forecast branch.
    var trendPoints: [CycleTrendCard.Point] {
        pastCycleEntries.map {
            CycleTrendCard.Point(id: $0.id, startDate: $0.startDate, days: $0.length)
        }
    }

    /// Wraps a card with an editorial section title rendered
    /// **above** the card surface — same pattern as Body
    /// Patterns ("Recurring patterns" + carousel below). Pulls
    /// the title out of the card's own header so the per-card
    /// chrome stays focused on its data and the typography
    /// system reads consistently across surfaces.
    @ViewBuilder
    func sectionWrap<Content: View>(
        _ title: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.raleway("SemiBold", size: 18, relativeTo: .title3))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignColors.text,
                                DesignColors.textPrincipal,
                                DesignColors.text.opacity(0.85),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            content()
        }
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
        // Treat `pendingInvalidation` as "skeleton, no matter what
        // the cached value is". The flag is set the moment a Period
        // edit lands in Calendar (HomeFeature catches
        // `editPeriodPredictionsUpdated`), so the very first frame of
        // Cycle Stats after the edit reads as a skeleton — no chance
        // for the pre-edit numbers to flash before `.onAppear` clears
        // them. The flag clears at `.onAppear` after the load kicks
        // off, and the skeleton stays visible because `store.stats`
        // is now nil until the fetch returns.
        let showStatsSkeleton = store.stats == nil || store.pendingInvalidation
        let showJourneySkeleton = store.journey == nil || store.pendingInvalidation
        switch card {
        case .overview:
            if showStatsSkeleton {
                CycleStatsOverviewSkeleton()
            } else {
                CycleStatsOverviewRow(
                    cycleAverageDays: cycleAverageDays,
                    periodAverageDays: periodAverageDays
                )
            }
        case .normality:
            if showStatsSkeleton {
                CycleNormalitySkeleton()
            } else {
                CycleNormalityCard(
                    previousCycleLength: previousCycleLength,
                    previousPeriodLength: previousPeriodLength,
                    variationStdDev: variationStdDev,
                    averageCycleLength: store.stats?.cycleLength.average,
                    cycleCount: loggedCycleCount,
                    onInfoTap: { kind in historyPath.append(.statInfo(kind)) }
                )
                .equatable()
            }
        case .avgCycle:
            sectionWrap("Cycle trend") {
                if showStatsSkeleton {
                    CycleTrendSkeleton()
                } else {
                    CycleTrendCard(
                        points: trendPoints,
                        averageDays: averageLengthInt
                    )
                    .equatable()
                }
            }
        case .history:
            sectionWrap("Cycle history") {
                if showJourneySkeleton {
                    CycleHistorySkeleton()
                } else {
                    CycleHistoryCard(
                        timelines: historyTimelines,
                        hiddenKeys: store.hiddenCycleKeys,
                        onHide: { key in store.send(.hideCycle(key)) },
                        onUnhide: { key in store.send(.unhideCycle(key)) },
                        onOpenDetail: { id in historyPath.append(.detail(id)) },
                        onSeeAll: { historyPath.append(.allHistory) }
                    )
                    .equatable()
                }
            }
        case .bodySignals:
            sectionWrap("Your body") {
                BodySignalsCard(
                    snapshot: store.bodySignals,
                    authProbe: store.bodySignalsAuth,
                    isLoading: store.isLoadingBodySignals,
                    onEnable: { store.send(.requestBodySignalsPermission) },
                    onOpenDetail: { focused in
                        historyPath.append(.bodySignalsDetail(focused: focused))
                    }
                )
            }
        case .reflection:
            sectionWrap("Rhythm reflection") {
                rhythmReflection
            }
        }
    }

    /// Shown when the user has hidden every card. Points to the
    /// toolbar slider so they're never stranded on a blank stats page.
    @ViewBuilder
    var emptyLayoutPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your stats screen is empty.")
                .font(.raleway("SemiBold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text)
            HStack(spacing: 6) {
                Text("Tap")
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                Text("in the top right to bring any card back.")
            }
            .font(.raleway("Regular", size: 14, relativeTo: .callout))
            .foregroundStyle(DesignColors.text.opacity(0.75))
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
                .font(AppTypography.cardTitleTertiary)
                .tracking(-0.2)
                .foregroundStyle(DesignColors.text)

            HStack {
                Spacer()
                AppCloseButton(action: { store.send(.dismissTapped) })
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

    /// Token bumped whenever downstream data that any card renders
    /// has changed. When this changes, `CycleStatsCardList` reconfigures
    /// its visible cells so the hosted SwiftUI views pick up the new
    /// closure values without a full reload.
    var cardsReconfigureToken: some Hashable {
        struct Token: Hashable {
            let hiddenKeys: Set<String>
            let statsIdentity: Int
            let journeyIdentity: Int
            let insightsIdentity: Int
            let layoutOrder: [String]
        }
        return Token(
            hiddenKeys: store.hiddenCycleKeys,
            statsIdentity: store.stats == nil ? 0 : 1,
            journeyIdentity: store.journey == nil ? 0 : 1,
            insightsIdentity: store.insights == nil ? 0 : 1,
            layoutOrder: store.statsLayout.visibleOrder.map(\.rawValue)
        )
    }
}

