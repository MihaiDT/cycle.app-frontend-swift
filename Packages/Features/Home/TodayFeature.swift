import ComposableArchitecture
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

        /// Unified cycle-derived calendar data — single source of truth for
        /// `periodDays` / `predictedDays` / `fertileDays` / `ovulationDays` /
        /// `flowIntensity`. Propagated to `calendarState.snapshot` on every
        /// server load so Calendar/EditPeriod read from the same source.
        public var snapshot: CycleSnapshot = .empty

        @Presents var checkIn: DailyCheckInFeature.State?
        @Presents var moodArc: MoodArcFeature.State?
        /// Always-present calendar state — pre-loaded so opening is instant
        public var calendarState: CalendarFeature.State = CalendarFeature.State()
        /// Controls calendar visibility (fullScreenCover)
        public var isCalendarVisible: Bool = false

        /// True while reloading cycle data after an edit (shows loading on hero)
        public var isRefreshingCycleData: Bool = false
        public var hasCompletedCalendarLoad: Bool = false

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
                periodDays: snapshot.periodDays,
                predictedDays: snapshot.predictedDays,
                fertileDays: snapshot.fertileDays,
                ovulationDays: snapshot.ovulationDays
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
            /// Broadcast that the underlying cycle data has changed — siblings
            /// (CycleInsights, CycleJourney) should refresh their cached context.
            /// Fires after `menstrualStatusLoaded` and `calendarEntriesLoaded`.
            /// A `nil` payload signals unavailable / errored data so subscribers
            /// can surface empty / error state instead of stale data.
            case cycleDataUpdated(CycleContext?)
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

    /// Fan out HBI score to every child that subscribes. Single source,
    /// many subscribers — add a new `.send` line here when wiring up a
    /// new HBI-reactive feature.
    private static func broadcastHBIEffect(_ score: HBIScore) -> Effect<Action> {
        .merge(
            .send(.cardStack(.hbiUpdated(score))),
            .send(.dailyChallenge(.hbiUpdated(score)))
        )
    }

    /// Broadcast the latest CycleContext to downstream sibling features
    /// (CycleInsights, CycleJourney) so they refresh without a tab switch.
    /// Called from `menstrualStatusLoaded` and `calendarEntriesLoaded` — both
    /// success and failure handlers. `nil` signals unavailable data so
    /// subscribers can show empty/error state instead of stale data.
    /// HomeFeature handles the delegate and forwards to siblings.
    private static func broadcastCycleDataEffect(_ cycle: CycleContext?) -> Effect<Action> {
        .send(.delegate(.cycleDataUpdated(cycle)))
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
                // Broadcast refreshed cycle context to sibling features
                // (CycleInsights, CycleJourney) via HomeFeature delegate.
                effects.append(Self.broadcastCycleDataEffect(state.cycle))
                return effects.isEmpty ? .none : .merge(effects)

            case .menstrualStatusLoaded(.failure):
                state.isLoadingMenstrual = false
                // Broadcast nil so siblings drop stale data and can show error state.
                return Self.broadcastCycleDataEffect(nil)

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
                // Unified single-source update: build one snapshot and propagate
                // to both TodayFeature (cycle context) and CalendarFeature (views).
                // Flow intensity is preserved — only server-derived fields are replaced.
                let refreshedSnapshot = CycleSnapshot(
                    periodDays: days,
                    predictedDays: predicted,
                    fertileDays: fertile,
                    ovulationDays: ovulation,
                    flowIntensity: state.snapshot.flowIntensity
                )
                state.snapshot = refreshedSnapshot
                state.calendarState.snapshot = refreshedSnapshot

                let cardEffect = Self.syncPhaseEffect(state: state)
                // Broadcast enriched cycle context (now includes calendar-derived
                // period/fertile/ovulation days) to sibling features.
                let cycleBroadcast = Self.broadcastCycleDataEffect(state.cycle)

                if state.isRefreshingCycleData {
                    // Keep wave active for 2.5s minimum — premium processing feel
                    return .merge(
                        .run { send in
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            await send(.hideSyncStatus, animation: .easeOut(duration: 0.3))
                        },
                        cardEffect,
                        cycleBroadcast
                    )
                } else if wasSyncing {
                    return .merge(
                        .run { send in
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            await send(.hideSyncStatus, animation: .easeOut(duration: 0.3))
                        },
                        cardEffect,
                        cycleBroadcast
                    )
                }
                return .merge(cardEffect, .send(.generateMissingRecaps), cycleBroadcast)

            case .calendarEntriesLoaded(.failure):
                state.hasCompletedCalendarLoad = true
                state.isRefreshingCycleData = false
                state.syncStatus = .idle
                // Broadcast whatever context is currently resolvable from
                // menstrualStatus alone (may be nil) so siblings can reflect
                // the partial/failed state.
                return Self.broadcastCycleDataEffect(state.cycle)

            case .dashboardLoaded(.success(let dashboard)):
                state.isLoadingDashboard = false
                state.dashboard = dashboard
                if !state.hasAppeared { state.hasAppeared = true }
                // Broadcast the fresh HBI score once per successful load.
                // Subscribers (CardStack, DailyChallenge) react via inner scoping.
                let broadcast: Effect<Action> = dashboard.today.map(Self.broadcastHBIEffect) ?? .none
                if !state.hasTriggeredScoreAnimation {
                    state.hasTriggeredScoreAnimation = true
                    return .merge(broadcast, .send(.triggerScoreAnimation))
                }
                return broadcast

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
                let confirmedDays = state.snapshot.periodDays.subtracting(state.snapshot.predictedDays)
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
                // Snapshot is updated immediately when calendar loads now, so
                // this hook just clears the refresh flag.
                state.isRefreshingCycleData = false
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

            case .cardStack(.delegate(.challengeContinueTapped)):
                return .send(.dailyChallenge(.continueTapped))

            case .cardStack(.delegate(.challengeSkipTapped)):
                return .send(.dailyChallenge(.skipTapped))

            case .cardStack(.delegate(.challengeMaybeLaterTapped)):
                return .send(.dailyChallenge(.maybeLaterTapped))

            case let .dailyChallenge(.delegate(.challengeStateChanged(snapshot))):
                state.cardStackState.challengeSnapshot = snapshot
                if case .inProgress = state.dailyChallengeState.challengeState {
                    state.cardStackState.challengeInProgress = true
                } else {
                    state.cardStackState.challengeInProgress = false
                }
                return .none

            case .dailyChallenge:
                // Sync inProgress flag to card stack after any challenge action
                if case .inProgress = state.dailyChallengeState.challengeState {
                    state.cardStackState.challengeInProgress = true
                } else {
                    state.cardStackState.challengeInProgress = false
                }
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

