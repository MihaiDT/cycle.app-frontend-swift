import ComposableArchitecture
import Inject
import SwiftData
import SwiftUI

// MARK: - Today Feature

@Reducer
public struct TodayFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var dashboard: HBIDashboardResponse?
        public var isLoadingDashboard: Bool = false
        public var dashboardError: String?

        public var menstrualStatus: MenstrualStatusResponse?
        public var isLoadingMenstrual: Bool = false
        /// Period day keys from server calendar entries
        public var serverPeriodDays: Set<String> = []
        /// Predicted period day keys (subset of serverPeriodDays)
        public var serverPredictedDays: Set<String> = []
        /// Fertile days with their level from server calendar (keys: "yyyy-MM-dd")
        public var serverFertileDays: [String: FertilityLevel] = [:]
        /// Ovulation day keys from server calendar (keys: "yyyy-MM-dd")
        public var serverOvulationDays: Set<String> = []

        @Presents var checkIn: DailyCheckInFeature.State?
        @Presents var moodArc: MoodArcFeature.State?
        /// Always-present calendar state — pre-loaded so opening is instant
        public var calendarState: CalendarFeature.State = CalendarFeature.State()
        /// Controls calendar visibility (fullScreenCover)
        public var isCalendarVisible: Bool = false

        /// True while reloading cycle data after an edit (shows loading on hero)
        public var isRefreshingCycleData: Bool = false
        public var hasCompletedCalendarLoad: Bool = false

        /// Pending calendar data — held until refresh animation finishes
        public var pendingCalendarData: PendingCalendarData?
        public struct PendingCalendarData: Equatable, Sendable {
            public var periodDays: Set<String>
            public var predictedDays: Set<String>
            public var fertileDays: [String: FertilityLevel]
            public var ovulationDays: Set<String>
        }

        /// Sync status for the toast on Home
        public enum SyncStatus: Equatable, Sendable {
            case idle
            case syncing
            case synced
        }
        public var syncStatus: SyncStatus = .idle

        /// Single source of truth for all cycle data — derived from server responses.
        /// Shows immediately with menstrualStatus; calendar data enriches when ready.
        public var cycle: CycleContext? {
            guard let status = menstrualStatus else { return nil }
            return CycleContext.from(
                status: status,
                periodDays: serverPeriodDays,
                predictedDays: serverPredictedDays,
                fertileDays: serverFertileDays,
                ovulationDays: serverOvulationDays
            )
        }

        /// Cached stats from last CycleInsights visit (for entry card sparkline)
        public var cachedCycleStats: CycleStatsDetailedResponse?

        // Late period confirm sheet
        public var isShowingLateConfirmSheet: Bool = false

        public var hasAppeared: Bool = false

        // AI Wellness message
        public var wellnessMessage: String?
        public var isLoadingWellnessMessage: Bool = false
        public var hasTriggeredScoreAnimation: Bool = false
        public var scoreAnimationProgress: Double = 0

        public var hasCompletedCheckIn: Bool {
            dashboard?.latestReport != nil
        }

        public var todayScore: Int {
            dashboard?.today?.hbiAdjusted ?? 0
        }

        public var trendDirection: String? {
            dashboard?.today?.trendDirection
        }

        // Card stack
        public var cardStackState: CardStackFeature.State = CardStackFeature.State()

        // Daily Glow challenge
        public var dailyChallengeState: DailyChallengeFeature.State = DailyChallengeFeature.State()

        // Notifications
        public var recapBannerMonth: String?
        public var isRecapSheetVisible: Bool = false
        public var isNotificationsPanelVisible: Bool = false

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case loadDashboard
        case cardStack(CardStackFeature.Action)
        case dailyChallenge(DailyChallengeFeature.Action)
        case dashboardLoaded(Result<HBIDashboardResponse, Error>)
        case loadMenstrualStatus
        case menstrualStatusLoaded(Result<MenstrualStatusResponse, Error>)
        case checkInTapped
        case calendarTapped
        case calendarDismissed
        case calendarEntriesLoaded(Result<MenstrualCalendarResponse, Error>)
        case checkIn(PresentationAction<DailyCheckInFeature.Action>)
        case moodArc(PresentationAction<MoodArcFeature.Action>)
        case moodTapped
        case calendar(CalendarFeature.Action)
        case triggerScoreAnimation
        case scoreAnimationTick(Double)
        case refreshTapped
        case logPeriodTapped(Date)
        case logPeriodCompleted
        case latePeriodConfirmTapped
        case latePeriodStartedOnPredicted
        case latePeriodStartedDifferent
        case latePeriodNotStarted
        case hideSyncStatus
        case finishRefreshAnimation
        /// Background save + predict + reload — survives child dismissals
        case backgroundSyncPeriod(
            periodDays: Set<String>,
            originalPeriodDays: Set<String>,
            periodFlowIntensity: [String: FlowIntensity],
            bleedingDays: Int
        )
        case phaseResolved(CyclePhase, Int)
        case backgroundSyncCompleted
        case loadWellnessMessage
        case wellnessMessageLoaded(String?)
        case refreshRecapBanner
        case recapBannerLoaded(String?)
        case recapSheetDismissed
        case notificationsTapped
        case notificationsPanelDismissed
        case generateMissingRecaps
        case delegate(Delegate)
        public enum Delegate: Sendable, Equatable {
            case openAriaChat(context: String)
            case openCycleInsights
            case openCycleJourney
        }
    }

    @Dependency(\.hbiLocal) var hbiLocal
    @Dependency(\.menstrualLocal) var menstrualLocal
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case recapGeneration }

    public init() {}

    /// Single source of truth: compute phase from CycleContext and broadcast to all components.
    /// Called from both menstrualStatusLoaded and calendarEntriesLoaded — whoever has complete data first.
    private static func handleLoadWellness(_ state: inout State) -> Effect<Action> {
        state.isLoadingWellnessMessage = true
        if let cached = WellnessClient.loadCached(container: CycleDataStore.shared) {
            state.wellnessMessage = WellnessClient.messageForNow(from: cached)
            state.isLoadingWellnessMessage = false
            return .none
        }
        let phase = state.cycle?.phase(for: Date())?.rawValue ?? "unknown"
        let day = state.cycle?.cycleDay ?? 1
        let daysUntil = state.cycle?.daysUntilPeriod(from: Date()) ?? 14
        let isLate = state.cycle?.isLate ?? false
        let tracked = 10 // Approximation — exact count not in profile
        return .run { send in
            let record = await WellnessClient.fetchAndCache(
                cyclePhase: phase, cycleDay: day, daysUntilPeriod: daysUntil,
                isLate: isLate, recentSymptoms: [], moodLevel: 3, energyLevel: 3,
                cyclesTracked: tracked, container: CycleDataStore.shared
            )
            let message = record.map { WellnessClient.messageForNow(from: $0) }
            await send(.wellnessMessageLoaded(message))
        }
    }

    private static func syncPhaseEffect(state: State) -> Effect<Action> {
        guard let cycle = state.cycle,
              let status = state.menstrualStatus else {
            return .none
        }
        let today = Calendar.current.startOfDay(for: Date())
        let cycleDay = cycle.cycleDayNumber(for: today) ?? cycle.cycleDay
        let phase = cycle.resolvedPhase(for: today)
        let displayDay = phase == .late ? cycle.effectiveDaysLate : cycleDay
        return .send(.phaseResolved(phase, displayDay))
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .loadDashboard:
                state.isLoadingDashboard = true
                state.dashboardError = nil
                return .merge(
                    .run { send in
                        let result = await Result {
                            try await hbiLocal.getDashboard()
                        }
                        await send(.dashboardLoaded(result))
                    },
                    .send(.loadMenstrualStatus)
                )

            case .loadMenstrualStatus:
                state.isLoadingMenstrual = true
                return .merge(
                    .run { send in
                        let result = await Result {
                            try await menstrualLocal.getStatus()
                        }
                        await send(.menstrualStatusLoaded(result))
                    },
                    .run { [menstrualLocal] send in
                        let start = Calendar.current.date(byAdding: .month, value: -24, to: Date())!
                        let end = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
                        let result = await Result {
                            try await menstrualLocal.getCalendar(start, end)
                        }
                        await send(.calendarEntriesLoaded(result), animation: .easeInOut(duration: 0.3))
                    }
                )

            case .menstrualStatusLoaded(.success(let status)):
                state.isLoadingMenstrual = false
                state.menstrualStatus = status
                // Sync to always-present calendar state
                state.calendarState.menstrualStatus = status
                let hasCycleData = status.hasCycleData
                let localCal = Calendar.current
                if hasCycleData {
                    let startDate = CalendarFeature.localDate(from: status.currentCycle.startDate)
                    state.calendarState.cycleStartDate = localCal.startOfDay(for: startDate)
                }
                state.calendarState.cycleLength = status.profile.avgCycleLength ?? 28
                state.calendarState.bleedingDays = status.currentCycle.bleedingDays ?? 5
                // Pre-load full calendar data (36 months) so opening is instant
                var effects: [Effect<Action>] = []
                // Pre-load calendar
                if !state.calendarState.hasPreloaded {
                    state.calendarState.hasPreloaded = true
                    effects.append(.send(.calendar(.loadCalendar)))
                }
                if !hasCycleData {
                    state.cardStackState.cards = []
                    state.cardStackState.currentPhase = nil
                } else if state.hasCompletedCalendarLoad {
                    // Only sync phase if calendar is loaded (periodDays available)
                    // Otherwise, calendarEntriesLoaded will sync when ready
                    effects.append(Self.syncPhaseEffect(state: state))
                }
                // Load AI wellness message
                if hasCycleData && state.wellnessMessage == nil {
                    effects.append(.send(.loadWellnessMessage))
                }
                return effects.isEmpty ? .none : .merge(effects)

            case .menstrualStatusLoaded(.failure):
                state.isLoadingMenstrual = false
                return .none

            case .calendarEntriesLoaded(.success(let response)):
                var days: Set<String> = []
                var predicted: Set<String> = []
                var fertile: [String: FertilityLevel] = [:]
                var ovulation: Set<String> = []
                let cal = Calendar.current
                for entry in response.entries {
                    let localDay = CalendarFeature.localDate(from: entry.date)
                    let comps = cal.dateComponents([.year, .month, .day], from: localDay)
                    let key = String(
                        format: "%04d-%02d-%02d",
                        comps.year ?? 0,
                        comps.month ?? 0,
                        comps.day ?? 0
                    )
                    switch entry.type {
                    case "period":
                        days.insert(key)
                    case "predicted_period":
                        days.insert(key)
                        predicted.insert(key)
                    case "fertile":
                        if let levelStr = entry.fertilityLevel,
                            let level = FertilityLevel(rawValue: levelStr)
                        {
                            fertile[key] = level
                        }
                    case "ovulation":
                        ovulation.insert(key)
                    default:
                        break
                    }
                }
                state.hasCompletedCalendarLoad = true
                let wasSyncing = state.syncStatus == .syncing
                if wasSyncing {
                    state.syncStatus = .synced
                }
                // Always sync to calendar state for instant open
                state.calendarState.periodDays = days
                state.calendarState.predictedPeriodDays = predicted
                state.calendarState.fertileDays = fertile
                state.calendarState.ovulationDays = ovulation

                // Always update server state immediately so cycle context is available
                state.serverPeriodDays = days
                state.serverPredictedDays = predicted
                state.serverFertileDays = fertile
                state.serverOvulationDays = ovulation

                let cardEffect = Self.syncPhaseEffect(state: state)

                if state.isRefreshingCycleData {
                    // Keep wave active for 2.5s minimum — premium processing feel
                    state.pendingCalendarData = nil
                    return .merge(
                        .run { send in
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            await send(.hideSyncStatus, animation: .easeOut(duration: 0.3))
                        },
                        cardEffect
                    )
                } else if wasSyncing {
                    return .merge(
                        .run { send in
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            await send(.hideSyncStatus, animation: .easeOut(duration: 0.3))
                        },
                        cardEffect
                    )
                }
                return .merge(cardEffect, .send(.generateMissingRecaps))

            case .calendarEntriesLoaded(.failure):
                state.hasCompletedCalendarLoad = true
                state.isRefreshingCycleData = false
                state.syncStatus = .idle
                return .none

            case .dashboardLoaded(.success(let dashboard)):
                state.isLoadingDashboard = false
                state.dashboard = dashboard
                if !state.hasAppeared { state.hasAppeared = true }
                if !state.hasTriggeredScoreAnimation {
                    state.hasTriggeredScoreAnimation = true
                    return .send(.triggerScoreAnimation)
                }
                return .none

            case .dashboardLoaded(.failure(let error)):
                state.isLoadingDashboard = false
                state.dashboardError = error.localizedDescription
                if !state.hasAppeared { state.hasAppeared = true }
                return .none

            case .checkInTapped:
                state.checkIn = DailyCheckInFeature.State()
                return .none

            case .moodTapped:
                state.moodArc = MoodArcFeature.State()
                return .none

            case .moodArc(.presented(.delegate(.didLogMood))):
                return .send(.loadDashboard)

            case .moodArc:
                return .none

            case .calendarTapped:
                // Reset displayedMonth to current month so scrollTo targets it
                var comps = Calendar.current.dateComponents([.year, .month], from: Date())
                comps.day = 1
                state.calendarState.displayedMonth = Calendar.current.date(from: comps) ?? Date()
                state.calendarState.selectedDate = Calendar.current.startOfDay(for: Date())
                state.isCalendarVisible = true
                return .none

            case .checkIn(.presented(.delegate(.didCompleteCheckIn(_)))):
                return .send(.loadDashboard)

            case .checkIn:
                return .none

            case .calendar(.delegate(.didDismiss)):
                state.isCalendarVisible = false
                return .send(.loadDashboard)

            case .calendarDismissed:
                state.isCalendarVisible = false
                state.isRefreshingCycleData = false
                state.pendingCalendarData = nil
                state.syncStatus = .idle
                return .send(.loadDashboard)

            case .calendar(.delegate(.periodDataChanged)):
                // Skip if already refreshing (periodDataNeedsSync handles the full cycle)
                guard !state.isRefreshingCycleData else { return .none }
                state.isRefreshingCycleData = true
                if state.syncStatus == .idle {
                    state.syncStatus = .syncing
                }
                return .send(.loadMenstrualStatus)

            case .calendar(.delegate(.periodDataNeedsSync(
                let periodDays, let originalPeriodDays, let flowIntensity, let bleedingDays
            ))):
                state.isRefreshingCycleData = true
                state.syncStatus = .syncing
                return .send(.backgroundSyncPeriod(
                    periodDays: periodDays,
                    originalPeriodDays: originalPeriodDays,
                    periodFlowIntensity: flowIntensity,
                    bleedingDays: bleedingDays
                ))

            case .calendar(.delegate(.openAriaChat(let context))):
                state.isCalendarVisible = false
                return .send(.delegate(.openAriaChat(context: context)))

            case .calendar:
                return .none

            case .triggerScoreAnimation:
                return .run { send in
                    let steps = 60
                    let duration: Double = 1.2
                    for i in 1...steps {
                        try await clock.sleep(for: .milliseconds(Int(duration / Double(steps) * 1000)))
                        let progress = Double(i) / Double(steps)
                        let eased = 1 - pow(1 - progress, 3)
                        await send(.scoreAnimationTick(eased))
                    }
                }

            case .scoreAnimationTick(let progress):
                state.scoreAnimationProgress = progress
                return .none

            case .refreshTapped:
                return .send(.loadDashboard)

            case .logPeriodTapped(let date):
                // Open calendar in edit period mode with date pre-selected
                state.isCalendarVisible = true
                // Existing confirmed days
                let confirmedDays = state.calendarState.periodDays.subtracting(state.calendarState.predictedPeriodDays)
                // Pre-fill new days from selected date + bleeding length
                let bleedingDays = state.cycle?.bleedingDays ?? 5
                let cal = Calendar.current
                var preFilled = confirmedDays
                for i in 0..<bleedingDays {
                    if let d = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: date)) {
                        preFilled.insert(CalendarFeature.dateKey(d))
                    }
                }
                state.calendarState.editPeriodDays = preFilled
                state.calendarState.editOriginalPeriodDays = confirmedDays
                state.calendarState.isEditingPeriod = true
                state.calendarState.isUpdatingPredictions = false
                state.calendarState.predictionsDone = false
                return .none

            case .logPeriodCompleted:
                return .send(.loadMenstrualStatus)

            case .latePeriodConfirmTapped:
                state.isShowingLateConfirmSheet = true
                return .none

            case .latePeriodStartedOnPredicted:
                state.isShowingLateConfirmSheet = false
                // Confirm period on predicted date
                guard let expectedDate = state.cycle?.effectiveExpectedDate else {
                    return .none
                }
                return .send(.logPeriodTapped(expectedDate))

            case .latePeriodStartedDifferent:
                state.isShowingLateConfirmSheet = false
                // Open calendar in edit period mode
                state.isCalendarVisible = true
                return .send(.calendar(.editPeriodToggled))

            case .latePeriodNotStarted:
                state.isShowingLateConfirmSheet = false
                return .none

            case .hideSyncStatus:
                state.syncStatus = .idle
                state.isRefreshingCycleData = false
                return .send(.generateMissingRecaps)

            case .finishRefreshAnimation:
                state.isRefreshingCycleData = false
                // Apply held calendar data in sync with animation end
                if let pending = state.pendingCalendarData {
                    state.serverPeriodDays = pending.periodDays
                    state.serverPredictedDays = pending.predictedDays
                    state.serverFertileDays = pending.fertileDays
                    state.serverOvulationDays = pending.ovulationDays
                    state.pendingCalendarData = nil
                }
                return .none

            // MARK: — Phase broadcast hub
            // All components that react to phase changes subscribe here.
            // To add a new component: add one .send line below.
            case let .phaseResolved(phase, day):
                // Energy from HBI (0-100) → 1-10 for challenge selection
                let rawEnergy = state.dashboard?.today?.energyScore ?? 50
                let energy = max(1, min(10, (rawEnergy / 10) + 1))
                return .merge(
                    .send(.cardStack(.loadCards(phase, day))),
                    .send(.dailyChallenge(.selectChallenge(phase: phase.rawValue, energyLevel: energy)))
                )

            case .backgroundSyncPeriod(let periodDays, let originalPeriodDays, let flowIntensity, let bleedingDays):
                // Clear recap banner — cycle data is changing
                state.recapBannerMonth = nil
                let periodGroups = EditPeriodFeature.groupConsecutivePeriods(periodDays)
                let removedDays = originalPeriodDays.subtracting(periodDays)
                return .run { [menstrualLocal] send in
                    // Remove days first
                    if !removedDays.isEmpty {
                        let datesToRemove = removedDays.compactMap { CalendarFeature.parseDate($0) }
                        try? await menstrualLocal.removePeriodDays(datesToRemove)
                    }
                    // Confirm remaining period groups (skip predictions — done once below)
                    for group in periodGroups {
                        try? await menstrualLocal.confirmPeriod(
                            group.startDate, group.dayCount, nil, true
                        )
                    }
                    // Regenerate predictions only if we have period data
                    if !periodGroups.isEmpty {
                        try? await menstrualLocal.generatePrediction()
                    }
                    await send(.backgroundSyncCompleted)
                }

            case .loadWellnessMessage:
                return Self.handleLoadWellness(&state)

            case .wellnessMessageLoaded(let message):
                state.isLoadingWellnessMessage = false
                state.wellnessMessage = message
                return .none

            case .backgroundSyncCompleted:
                return .send(.loadMenstrualStatus)

            case .refreshRecapBanner:
                return .run { [menstrualLocal] send in
                    let month = try? await menstrualLocal.unviewedRecapMonth()
                    await send(.recapBannerLoaded(month))
                }

            case .recapBannerLoaded(let month):
                state.recapBannerMonth = month
                // Show sheet only after cards have loaded
                if month != nil && !state.cardStackState.isLoading {
                    state.isRecapSheetVisible = true
                }
                return .none

            case .recapSheetDismissed:
                state.isRecapSheetVisible = false
                return .none

            case .notificationsTapped:
                state.isNotificationsPanelVisible = true
                return .none

            case .notificationsPanelDismissed:
                state.isNotificationsPanelVisible = false
                return .none

            case .generateMissingRecaps:
                return .run { [menstrualLocal] send in
                    CycleJourneyFeature.cleanupLegacyRecapDefaults()
                    let data = try await menstrualLocal.getJourneyData()
                    let summaries = CycleJourneyEngine.buildSummaries(
                        inputs: data.records,
                        reports: data.reports,
                        profileAvgCycleLength: data.profileAvgCycleLength,
                        profileAvgBleedingDays: data.profileAvgBleedingDays,
                        currentCycleStartDate: data.currentCycleStartDate
                    )
                    // Invalidate stale CloudKit-synced recaps from before reset/new account
                    let accountDate = UserDefaults.standard.object(forKey: "CycleDataResetDate") as? Date ?? .distantPast
                    let maxAge: TimeInterval? = accountDate == .distantPast ? nil : Date.now.timeIntervalSince(accountDate)
                    for summary in summaries where !summary.isCurrentCycle {
                        let hasCached = CycleJourneyFeature.loadCachedRecap(cycleStart: summary.startDate, maxAge: maxAge) != nil
                        if !hasCached {
                            if let recap = await CycleJourneyFeature.fetchRecapAI(summary: summary, allSummaries: summaries) {
                                CycleJourneyFeature.cacheRecap(recap, cycleStart: summary.startDate)
                            }
                        }
                    }
                    await send(.refreshRecapBanner)
                }
                .cancellable(id: CancelID.recapGeneration, cancelInFlight: true)

            case .cardStack(.cardsGenerated):
                // Cards just loaded — show recap sheet if recap is ready
                if state.recapBannerMonth != nil && !state.isRecapSheetVisible {
                    state.isRecapSheetVisible = true
                }
                return .none

            case .cardStack(.delegate(.openLens)):
                return .send(.delegate(.openCycleInsights))

            case .cardStack(.delegate(.openCheckIn)):
                return .send(.moodTapped)

            case .cardStack(.delegate(.startBreathing)):
                // Future: present breathing modal
                return .none

            case .cardStack(.delegate(.openJournal)):
                // Future: present journal modal
                return .none

            case .cardStack(.delegate(.challengeDoItTapped)):
                return .send(.dailyChallenge(.doItTapped))

            case .cardStack(.delegate(.challengeSkipTapped)):
                return .send(.dailyChallenge(.skipTapped))

            case .cardStack(.delegate(.challengeMaybeLaterTapped)):
                return .send(.dailyChallenge(.maybeLaterTapped))

            case let .dailyChallenge(.delegate(.challengeStateChanged(snapshot))):
                state.cardStackState.challengeSnapshot = snapshot
                return .none

            case .dailyChallenge:
                return .none

            case .cardStack:
                return .none

            case .binding, .delegate:
                return .none
            }
        }
        .ifLet(\.$checkIn, action: \.checkIn) {
            DailyCheckInFeature()
        }
        .ifLet(\.$moodArc, action: \.moodArc) {
            MoodArcFeature()
        }
        Scope(state: \.calendarState, action: \.calendar) {
            CalendarFeature()
        }
        Scope(state: \.cardStackState, action: \.cardStack) {
            CardStackFeature()
        }
        Scope(state: \.dailyChallengeState, action: \.dailyChallenge) {
            DailyChallengeFeature()
        }
    }
}

private enum MenstrualError: Error { case noToken }

// MARK: - Today View

public struct TodayView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<TodayFeature>

    @State private var showHero = false
    @State private var showContent = false
    @State private var selectedDate: Date?
    @State private var scrollOffset: CGFloat = 0
    @State private var initialScrollY: CGFloat?
    @State private var safeAreaTop: CGFloat = 0
    public init(store: StoreOf<TodayFeature>) {
        self.store = store
    }

    private static let confirmDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt
    }()

    // MARK: - Layout Constants

    private let expandedHeroHeight: CGFloat = 290
    private let collapsedHeroHeight: CGFloat = 64
    private let collapseThreshold: CGFloat = 260

    /// Collapse progress: 0 = expanded, 1 = collapsed. Driven by scroll offset.
    /// Steep S-curve so it snaps visually — stays near 0/1, jumps through middle.
    private var collapseProgress: CGFloat {
        let t = min(max(scrollOffset / collapseThreshold, 0), 1)
        // Steep logistic-style curve: t²/(t²+(1-t)²)
        let tSq = t * t
        let inv = (1 - t) * (1 - t)
        let denom = tSq + inv
        return denom > 0 ? tSq / denom : 0
    }

    private var currentHeroHeight: CGFloat {
        expandedHeroHeight + (collapsedHeroHeight - expandedHeroHeight) * collapseProgress + safeAreaTop
    }

    /// Spacer height that keeps content pinned to hero bottom during collapse.
    /// Matches scrollOffset 1:1 during collapse, then caps so normal scrolling resumes.
    private var collapseCompensation: CGFloat {
        min(scrollOffset, collapseThreshold)
    }

    public var body: some View {
        GeometryReader { rootGeo in
        VStack(spacing: 0) {
            // MARK: Sticky Hero (above scroll — content never goes behind it)
            if let cycle = store.cycle, store.hasCompletedCalendarLoad {
                CycleHeroView(
                    cycle: cycle,
                    selectedDate: $selectedDate,
                    isRefreshing: store.isRefreshingCycleData,
                    isSynced: store.syncStatus == .synced,
                    onEditPeriod: { store.send(.calendarTapped) },
                    onLogPeriod: {
                        let date = selectedDate ?? Calendar.current.startOfDay(for: Date())
                        store.send(.logPeriodTapped(date))
                    },
                    onCalendarTapped: { store.send(.calendarTapped) },
                    hasNotification: store.recapBannerMonth != nil,
                    onNotificationTapped: {
                        store.send(.notificationsTapped)
                    },
                    collapseProgress: collapseProgress,
                    safeAreaTop: safeAreaTop,
                    aiWellnessMessage: store.wellnessMessage,
                    isLoadingWellnessMessage: store.isLoadingWellnessMessage
                )
                .opacity(showHero ? 1 : 0)
                .allowsHitTesting(true)
                .zIndex(1)
            } else if store.menstrualStatus != nil, store.menstrualStatus?.hasCycleData == false {
                // No cycle data — prompt to log first period
                noCycleDataHero
                    .opacity(showHero ? 1 : 0)
            } else {
                // Skeleton hero while cycle data loads
                heroSkeleton
                    .opacity(showHero ? 1 : 0)
            }

            // MARK: Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Scroll tracker (must be direct child with non-zero height)
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetKey.self,
                                value: geo.frame(in: .global).minY
                            )
                    }
                    .frame(height: 1)

                    // Compensate for hero collapse — pins content to hero bottom
                    // Use transaction to prevent this height change from feeding back into scroll offset
                    if store.cycle != nil {
                        Color.clear.frame(height: collapseCompensation)
                            .transaction { $0.animation = nil }
                    }

                    // MARK: Content
                    VStack(spacing: 0) {
                        if !store.cardStackState.cards.isEmpty || store.cardStackState.isLoading {
                            CardStackView(
                                store: store.scope(
                                    state: \.cardStackState,
                                    action: \.cardStack
                                )
                            )
                            .padding(.top, AppLayout.spacingL)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        }

                        VerticalSpace.xl

                        // Journey preview
                        if let cycle = store.cycle {
                            JourneyPreviewSection(
                                cycleCount: cycle.cycleDay > 0 ? max(1, cycle.cycleDay / cycle.cycleLength) : 1,
                                currentCycleNumber: cycle.cycleDay > 0 ? max(1, cycle.cycleDay / cycle.cycleLength) : 1,
                                onTap: { store.send(.delegate(.openCycleJourney)) }
                            )
                            .padding(.horizontal, AppLayout.horizontalPadding)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 24)
                        }

                        VerticalSpace.xxl
                    }
                }
            }
            .scrollTargetBehavior(CollapseSnapBehavior(threshold: collapseThreshold))
            .trackingScrollOffset($scrollOffset)
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                // iOS 17 fallback only
                if #unavailable(iOS 18.0) {
                    if initialScrollY == nil { initialScrollY = value }
                    scrollOffset = max(0, (initialScrollY ?? 0) - value)
                }
            }
            .refreshable {
                store.send(.refreshTapped)
            }
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: Binding(
            get: { store.isNotificationsPanelVisible },
            set: { if !$0 { store.send(.notificationsPanelDismissed) } }
        )) {
            NotificationsPanel(
                recapMonth: store.recapBannerMonth,
                onRecapTapped: {
                    store.send(.notificationsPanelDismissed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        store.send(.delegate(.openCycleJourney))
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(AppLayout.cornerRadiusL)
            .presentationBackground(DesignColors.background)
        }
        .sheet(isPresented: Binding(
            get: { store.isRecapSheetVisible },
            set: { if !$0 { store.send(.recapSheetDismissed) } }
        )) {
            if let month = store.recapBannerMonth {
                AriaRecapSheet(monthName: month) {
                    store.send(.recapSheetDismissed)
                    store.send(.delegate(.openCycleJourney))
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppLayout.cornerRadiusL)
                .presentationBackground(DesignColors.background)
            }
        }
        .sheet(item: $store.scope(state: \.checkIn, action: \.checkIn)) { checkInStore in
            DailyCheckInView(store: checkInStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppLayout.cornerRadiusL)
        }
        .sheet(item: $store.scope(state: \.moodArc, action: \.moodArc)) { moodStore in
            MoodArcView(store: moodStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(AppLayout.cornerRadiusL)
        }
        .modifier(DailyGlowPresentations(store: store))
        .confirmationDialog(
            "Log your period",
            isPresented: $store.isShowingLateConfirmSheet,
            titleVisibility: .visible
        ) {
            if let expectedDate = store.cycle?.effectiveExpectedDate {
                Button("Started on \(Self.confirmDateFormatter.string(from: expectedDate))") {
                    store.send(.latePeriodStartedOnPredicted)
                }
            }
            Button("Started on a different date") {
                store.send(.latePeriodStartedDifferent)
            }
            Button("It hasn't started yet", role: .cancel) {
                store.send(.latePeriodNotStarted)
            }
        } message: {
            Text("Did your new cycle start around the expected date, or would you like to pick the correct dates?")
        }
        .onChange(of: store.hasAppeared) { _, appeared in
            guard appeared else { return }
            triggerStaggeredAnimations()
        }
        .onChange(of: store.isRefreshingCycleData) { _, isRefreshing in
            // Content stays visible during refresh — hero wave is the only indicator.
            // Only ensure showContent is true when refresh ends (covers edge case
            // where refresh starts before initial staggered animation completes).
            if !isRefreshing && !showContent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showContent = true
                    }
                }
            }
        }
        .onAppear { safeAreaTop = rootGeo.safeAreaInsets.top }
        .enableInjection()
        } // GeometryReader
    }

    // MARK: - Staggered Animations

    private func triggerStaggeredAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            showHero = true
        }
        // Content appears after hero wave settles — real delay, not animation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
        }
    }

    // MARK: - No Cycle Data Hero

    @ViewBuilder
    private var noCycleDataHero: some View {
        let creamTop = Color(hex: 0xFEFCF7)
        let creamBottom = Color(red: 0.95, green: 0.91, blue: 0.88)

        VStack(spacing: 0) {
            LinearGradient(
                colors: [creamTop, creamBottom],
                startPoint: .top, endPoint: .bottom
            )
            .overlay {
                VStack(spacing: 16) {
                    Spacer().frame(height: safeAreaTop + 20)

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(DesignColors.accentWarm.opacity(0.6))

                    Text("No cycle logged")
                        .font(.custom("Raleway-Bold", size: 22, relativeTo: .title3))
                        .foregroundStyle(DesignColors.text)

                    Text("Start logging to discover your inner rhythm")
                        .font(.custom("Raleway-Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        store.send(.calendarTapped)
                    } label: {
                        Text("Open Calendar")
                            .font(.custom("Raleway-SemiBold", size: 15))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background {
                                Capsule()
                                    .fill(DesignColors.accentWarm)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Spacer()
                }
                .padding(.horizontal, AppLayout.horizontalPadding)
            }
        }
        .frame(height: 320)
    }

    // MARK: - Skeleton Hero

    @ViewBuilder
    private var heroSkeleton: some View {
        let creamTop = Color(hex: 0xFEFCF7)
        let creamBottom = Color(red: 0.95, green: 0.91, blue: 0.88)
        let shimmer = Color.white.opacity(0.45)

        VStack(spacing: 0) {
            Color.clear.frame(height: safeAreaTop)

            VStack(spacing: 0) {
                // Top row placeholders
                HStack {
                    Circle()
                        .fill(shimmer)
                        .frame(width: 36, height: 36)
                    Spacer()
                    Circle()
                        .fill(shimmer)
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Week calendar placeholder
                HStack(spacing: 10) {
                    ForEach(0..<7, id: \.self) { _ in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(shimmer)
                                .frame(width: 16, height: 8)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(shimmer)
                                .frame(width: 34, height: 34)
                        }
                    }
                }
                .padding(.top, 14)

                Spacer(minLength: 12)

                // Phase label placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmer)
                    .frame(width: 90, height: 14)

                // Day number placeholder
                RoundedRectangle(cornerRadius: 10)
                    .fill(shimmer)
                    .frame(width: 120, height: 44)
                    .padding(.top, 8)

                // Subtitle placeholder
                RoundedRectangle(cornerRadius: 5)
                    .fill(shimmer)
                    .frame(width: 140, height: 12)
                    .padding(.top, 8)

                Spacer(minLength: 16)

                // Button placeholders
                HStack(spacing: 10) {
                    Capsule()
                        .fill(shimmer)
                        .frame(width: 110, height: 36)
                    Capsule()
                        .fill(shimmer)
                        .frame(width: 90, height: 36)
                }
                .padding(.bottom, 20)
            }
        }
        .frame(height: expandedHeroHeight + safeAreaTop)
        .background(
            LinearGradient(
                colors: [creamTop, creamBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(Rectangle())
        .modifier(ShimmerModifier())
    }

}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Collapse Snap Behavior

/// Snaps scroll to either fully expanded (0) or fully collapsed (threshold).
/// Prevents the hero from resting at intermediate collapse states.
private struct CollapseSnapBehavior: ScrollTargetBehavior {
    let threshold: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let y = target.rect.origin.y
        if y > 0 && y < threshold {
            // Snap at 35% — collapses easily, resists expanding back
            target.rect.origin.y = y < threshold * 0.35 ? 0 : threshold
        }
    }
}

// MARK: - Scroll Offset Tracking (iOS 18+ uses onScrollGeometryChange)

private extension View {
    @ViewBuilder
    func trackingScrollOffset(_ offset: Binding<CGFloat>) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldValue, newValue in
                let clamped = max(0, newValue)
                // Skip tiny changes to break feedback oscillation
                if abs(clamped - offset.wrappedValue) > 0.5 {
                    offset.wrappedValue = clamped
                }
            }
        } else {
            self
        }
    }
}

// MARK: - Daily Glow Presentations

/// Extracted to a ViewModifier to reduce type-check complexity in TodayView.body.
private struct DailyGlowPresentations: ViewModifier {
    @Bindable var store: StoreOf<TodayFeature>

    func body(content: Content) -> some View {
        content
            // Daily Glow — accept (full-screen)
            .fullScreenCover(
                item: $store.scope(
                    state: \.dailyChallengeState.acceptSheet,
                    action: \.dailyChallenge.acceptSheet
                )
            ) { acceptStore in
                ChallengeAcceptView(store: acceptStore)
            }
            // Daily Glow — photo review
            .fullScreenCover(
                item: $store.scope(
                    state: \.dailyChallengeState.photoReview,
                    action: \.dailyChallenge.photoReview
                )
            ) { reviewStore in
                PhotoReviewView(store: reviewStore)
            }
            // Daily Glow — validation result
            .sheet(
                item: $store.scope(
                    state: \.dailyChallengeState.validation,
                    action: \.dailyChallenge.validation
                )
            ) { validationStore in
                ValidationResultView(store: validationStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(AppLayout.cornerRadiusL)
                    .presentationBackground(DesignColors.background)
            }
            // Daily Glow — camera
            .fullScreenCover(isPresented: Binding(
                get: { store.dailyChallengeState.isShowingCamera },
                set: { newValue in
                    if !newValue { store.send(.dailyChallenge(.photoCancelled)) }
                }
            )) {
                CameraPickerRepresentable(
                    onCapture: { data in store.send(.dailyChallenge(.photoCaptured(data))) },
                    onCancel: { store.send(.dailyChallenge(.photoCancelled)) }
                )
                .ignoresSafeArea()
            }
            // Daily Glow — gallery
            .fullScreenCover(isPresented: Binding(
                get: { store.dailyChallengeState.isShowingGallery },
                set: { newValue in
                    if !newValue { store.send(.dailyChallenge(.photoCancelled)) }
                }
            )) {
                GalleryPickerRepresentable(
                    onPick: { data in store.send(.dailyChallenge(.photoCaptured(data))) },
                    onCancel: { store.send(.dailyChallenge(.photoCancelled)) }
                )
            }
            // Daily Glow — level up overlay
            .sheet(
                item: $store.scope(
                    state: \.dailyChallengeState.levelUp,
                    action: \.dailyChallenge.levelUp
                )
            ) { levelUpStore in
                LevelUpOverlay(store: levelUpStore)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(.ultraThinMaterial)
            }
    }
}

// MARK: - Shimmer Effect

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        let leading = max(0, min(phase - 0.15, 1))
        let center = max(0, min(phase, 1))
        let trailing = max(0, min(phase + 0.15, 1))

        content
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: leading),
                        .init(color: .white.opacity(0.25), location: center),
                        .init(color: .clear, location: trailing),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)
            }
            .onAppear {
                // withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    // phase = 1.15
                // }
            }
    }
}



