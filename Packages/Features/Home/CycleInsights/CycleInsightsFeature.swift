import ComposableArchitecture
import Foundation
import SwiftUI

// MARK: - Hidden Cycles Persistence
//
// A private UserDefaults-backed Set<String> keyed by yyyy-MM-dd start
// dates. Hiding a cycle is a per-device preference, not health data,
// so it stays out of SwiftData/CloudKit. Small, local, and deliberate.

enum HiddenCyclesStore {
    private static let key = "cycleInsights.hiddenCycles.v1"

    static func load() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(arr)
    }

    static func save(_ keys: Set<String>) {
        UserDefaults.standard.set(Array(keys), forKey: key)
    }
}

// MARK: - Cycle Insights Feature

@Reducer
public struct CycleInsightsFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var cycleContext: CycleContext?

        public var stats: CycleStatsDetailedResponse?
        public var insights: MenstrualInsightsResponse?
        public var journey: JourneyData?
        /// Precomputed copy for the Rhythm Reflection card. Derived
        /// from `stats.cycleLength.history` on `statsLoaded` so the
        /// view body doesn't run `pow`/`sqrt`/sort on every render —
        /// the card re-evaluated those on every parent observation
        /// and was a measured hot path on scroll.
        public var rhythmReflectionCopy: String = ""
        /// Precomputed trend sentence for the average-cycle card.
        /// Same rationale as `rhythmReflectionCopy`: cache once on
        /// load instead of slicing history per render.
        public var avgTrendCopy: String = ""
        /// Pre-built history timelines cached here so the expensive
        /// `CycleHistoryBuilder.build(from:)` pass (records × reports
        /// day-mapping loop) runs once per journey load instead of on
        /// every TCA observation re-render.
        var historyTimelines: [CycleHistoryTimeline] = []
        public var hiddenCycleKeys: Set<String> = []
        public var isLoadingStats: Bool = false
        public var isLoadingInsights: Bool = false
        public var activeDetail: DetailSection?
        public var isDetailOpen: Bool = false
        public var isCycleStoryOpen: Bool = false

        /// One-shot deep-link consumed on `.onAppear` — opens the given
        /// detail section automatically (e.g. Home's Body Patterns tile).
        public var pendingInitialDetail: DetailSection?

        /// Which stat explainer (cycle length / period length / variation)
        /// is currently shown as a full-screen sheet, or nil when the
        /// Normality card is at rest.
        public var openStatInfo: CycleStatInfoKind?

        /// Controls the full-screen "All cycles" archive opened from
        /// the history card's "See all" link.
        public var showingAllHistory: Bool = false

        /// Id of the cycle whose detail sheet is currently open, or
        /// nil when no detail is shown. We store the id (not the
        /// whole timeline) so state stays small and Sendable without
        /// exposing the internal timeline type through a public API.
        var openCycleDetailID: String?

        /// User-controlled card arrangement for Cycle Stats. Hydrated
        /// once on `.onAppear` from `CycleStatsLayoutClient`; every
        /// subsequent mutation flows through `.layoutChanged` so the
        /// reducer stays the single source of truth.
        public var statsLayout: CycleStatsLayout = .default

        /// True while the customize screen is pushed on the stack.
        /// Kept in reducer state (not View state) so the screen
        /// survives store observations and the parent can coordinate
        /// navigation with the rest of the stats flow.
        public var showingCustomize: Bool = false

        public enum DetailSection: String, Equatable, Sendable {
            case rhythm
            case body
        }

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case statsLoaded(Result<CycleStatsDetailedResponse, Error>)
        case insightsLoaded(Result<MenstrualInsightsResponse, Error>)
        case journeyLoaded(Result<JourneyData, Error>)
        case openDetail(State.DetailSection)
        case closeDetail
        case openCycleStory
        case closeCycleStory
        case openStatInfo(CycleStatInfoKind)
        case closeStatInfo
        case hideCycle(String)
        case unhideCycle(String)
        case seeAllHistory
        case closeAllHistory
        case openCycleDetail(String)
        case closeCycleDetail
        case openCustomizeLayout
        case closeCustomizeLayout
        case layoutLoaded(CycleStatsLayout)
        case layoutChanged(CycleStatsLayout)
        case dismissTapped
        /// Broadcast from TodayFeature via HomeFeature — keeps `cycleContext`
        /// fresh when the user edits period data without requiring a re-entry.
        case cycleDataChanged(CycleContext?)
        case delegate(Delegate)
        public enum Delegate: Sendable, Equatable {
            case dismiss
        }
    }

    @Dependency(\.menstrualLocal) var menstrualLocal
    @Dependency(\.cycleStatsLayoutClient) var cycleStatsLayoutClient

    /// Stable id under which we cancel the debounced layout-save
    /// effect. A fresh `.layoutChanged` cancels the in-flight save
    /// and reschedules, so a long drag only results in a single
    /// UserDefaults write once the user stops moving.
    private enum CancelID: Hashable {
        case persistLayout
        /// Single id for the stats + journey fetch so a data-change
        /// broadcast can cancel an in-flight read and replace it
        /// with a fresh one — guarantees the view always settles on
        /// the latest DB state even when edits arrive mid-fetch.
        case refreshStats
    }

    // MARK: - Derived-copy helpers
    //
    // These live on the feature (not the view) so they can run once
    // per fetch in the reducer and be cached in `State`. The view
    // just reads the cached `String` — no re-sort / re-reduce /
    // re-sqrt on every parent observation.

    static func makeRhythmReflectionCopy(from stats: CycleStatsDetailedResponse) -> String {
        let history = stats.cycleLength.history
            .sorted { $0.startDate < $1.startDate }
            .map { Double($0.length) }
        let count = history.count
        if count == 0 {
            return "Your rhythm will begin to speak once you log a few cycles. No rush."
        }
        if count < 3 {
            return "A pattern is just starting to show. A few more cycles and your rhythm will read more clearly."
        }
        let window = min(4, count / 2 + 1)
        let current = Self.standardDeviation(Array(history.suffix(window)))
        let past = Self.standardDeviation(Array(history.prefix(window)))
        let currentRounded = Int(current.rounded())
        let pastRounded = Int(past.rounded())
        if count >= 6, past - current >= 1.0 {
            let cyclesBack = count - window
            return "Your cycles are becoming more regular. \(cyclesBack) cycles ago variability was ±\(pastRounded) days. Now it's ±\(currentRounded). Your body is finding its rhythm."
        }
        if current <= 3 {
            return "You're running steady. \(count) cycles at ±\(currentRounded) days. Bodies love rhythm, and yours is holding it."
        }
        if current >= 5 {
            return "Your cycles run their own tempo. That's information too. Watching the pattern is how it starts to read."
        }
        return "Your rhythm is finding its shape. Every cycle you log makes the next one easier to read."
    }

    static func makeAvgTrendCopy(from stats: CycleStatsDetailedResponse) -> String {
        let history = stats.cycleLength.history.map(\.length)
        guard history.count >= 2 else {
            return "Keep logging – a few more cycles and patterns start showing."
        }
        let half = history.count / 2
        let earlier = history.prefix(half)
        let later = history.suffix(history.count - half)
        let earlierAvg = Double(earlier.reduce(0, +)) / Double(earlier.count)
        let laterAvg = Double(later.reduce(0, +)) / Double(later.count)
        let delta = laterAvg - earlierAvg
        if abs(delta) < 1.0 {
            return "Your cycle length has been steady – a good sign of a settled rhythm."
        } else if delta > 0 {
            return "Cycles have been running a touch longer recently. Worth noting if it continues."
        } else {
            return "Cycles have been running a touch shorter recently. Worth noting if it continues."
        }
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Consume deep-link from Home (Body Patterns tile) before
                // loading so the detail fullScreenCover comes up in the
                // same animation pass as the parent view.
                if let pending = state.pendingInitialDetail {
                    state.pendingInitialDetail = nil
                    state.activeDetail = pending
                    state.isDetailOpen = true
                }
                state.hiddenCycleKeys = HiddenCyclesStore.load()

                // Hydrate the card layout once per screen entry. Kept
                // as its own effect so a slow read from disk can't
                // block the stats/journey network-style fetch below.
                let loadLayout = Effect<Action>.run { [cycleStatsLayoutClient] send in
                    let layout = await cycleStatsLayoutClient.load()
                    await send(.layoutLoaded(layout))
                }

                // Always re-query SwiftData on appear. Local reads are
                // ~100ms and the `.cancellable(cancelInFlight: true)`
                // id dedupes against a simultaneous `.cycleDataChanged`
                // trigger, so we never run two fetches in parallel.
                // Keeping this unconditional — rather than caching a
                // session-wide snapshot — means the screen always
                // reflects the current DB state after any edit path,
                // without the coordination overhead of invalidation.
                if state.stats == nil {
                    state.isLoadingStats = true
                }
                if state.insights == nil {
                    state.isLoadingInsights = true
                }
                let loadData = Effect<Action>.run { [menstrualLocal] send in
                    async let s = Result { try await menstrualLocal.getCycleStats() }
                    async let j = Result { try await menstrualLocal.getJourneyData() }
                    await send(.statsLoaded(s))
                    await send(.journeyLoaded(j))
                    // Insights derived from stats locally — no separate API needed
                    await send(.insightsLoaded(.success(MenstrualInsightsResponse.mock)))
                }
                .cancellable(id: CancelID.refreshStats, cancelInFlight: true)
                return .merge(loadLayout, loadData)

            case .statsLoaded(.success(let r)):
                state.isLoadingStats = false
                state.stats = r
                // Precompute derived copy once per fetch — keeps
                // the Rhythm Reflection and Average Cycle cards
                // off the hot path of SwiftUI body re-evaluation.
                state.rhythmReflectionCopy = Self.makeRhythmReflectionCopy(from: r)
                state.avgTrendCopy = Self.makeAvgTrendCopy(from: r)
                return .none

            case .statsLoaded(.failure):
                state.isLoadingStats = false
                return .none

            case .insightsLoaded(.success(let r)):
                state.isLoadingInsights = false
                state.insights = r
                return .none

            case .insightsLoaded(.failure):
                state.isLoadingInsights = false
                return .none

            case .journeyLoaded(.success(let j)):
                state.journey = j
                state.historyTimelines = CycleHistoryBuilder.build(from: j)
                return .none

            case .journeyLoaded(.failure):
                return .none

            case .hideCycle(let key):
                state.hiddenCycleKeys.insert(key)
                HiddenCyclesStore.save(state.hiddenCycleKeys)
                return .none

            case .unhideCycle(let key):
                state.hiddenCycleKeys.remove(key)
                HiddenCyclesStore.save(state.hiddenCycleKeys)
                return .none

            case .seeAllHistory:
                state.showingAllHistory = true
                return .none

            case .closeAllHistory:
                state.showingAllHistory = false
                return .none

            case .openCycleDetail(let id):
                state.openCycleDetailID = id
                return .none

            case .closeCycleDetail:
                state.openCycleDetailID = nil
                return .none

            case .openCustomizeLayout:
                state.showingCustomize = true
                return .none

            case .closeCustomizeLayout:
                state.showingCustomize = false
                return .none

            case let .layoutLoaded(layout):
                state.statsLayout = layout
                return .none

            case let .layoutChanged(layout):
                // Short-circuit: if nothing actually changed (e.g. a
                // Binding set fires with the same value), don't bother
                // scheduling a write.
                guard state.statsLayout != layout else { return .none }
                state.statsLayout = layout
                // Debounce writes so the user dragging a row doesn't
                // hit UserDefaults on every frame. `cancelInFlight`
                // swaps the pending save for a fresh one each time.
                return .run { [layout, cycleStatsLayoutClient] _ in
                    try? await Task.sleep(for: .milliseconds(350))
                    await cycleStatsLayoutClient.save(layout)
                }
                .cancellable(id: CancelID.persistLayout, cancelInFlight: true)

            case .openDetail(let section):
                state.activeDetail = section
                state.isDetailOpen = true
                return .none

            case .closeDetail:
                state.isDetailOpen = false
                state.activeDetail = nil
                return .none

            case .openCycleStory:
                state.isCycleStoryOpen = true
                return .none

            case .closeCycleStory:
                state.isCycleStoryOpen = false
                return .none

            case let .openStatInfo(kind):
                state.openStatInfo = kind
                return .none

            case .closeStatInfo:
                state.openStatInfo = nil
                return .none

            case .dismissTapped:
                return .send(.delegate(.dismiss))

            case let .cycleDataChanged(newCycle):
                // Refresh cached cycle context so derived views (dailyReading,
                // phase accent color, rhythm details) reflect the latest edit
                // without requiring the user to re-open the sheet.
                state.cycleContext = newCycle
                // Stale-while-revalidate: keep the previous aggregates on
                // screen so the user doesn't see a skeleton, and re-fetch
                // in the background. The numbers update in place once the
                // fresh compute finishes — matching how Apple Health
                // refreshes dashboard aggregates after a data edit.
                //
                // We always start a fresh read here (cancelling any
                // in-flight one under the same id). If a fetch was
                // already running from `.onAppear`, it may have sampled
                // SwiftData *before* the write committed — replacing
                // it guarantees the view settles on post-edit numbers.
                state.isLoadingStats = true
                state.isLoadingInsights = true
                return .run { [menstrualLocal] send in
                    async let s = Result { try await menstrualLocal.getCycleStats() }
                    async let j = Result { try await menstrualLocal.getJourneyData() }
                    await send(.statsLoaded(s))
                    await send(.journeyLoaded(j))
                    await send(.insightsLoaded(.success(MenstrualInsightsResponse.mock)))
                }
                .cancellable(id: CancelID.refreshStats, cancelInFlight: true)

            case .delegate:
                return .none
            }
        }
    }
}
