import ComposableArchitecture
import SwiftData
import SwiftUI

// MARK: - Today Feature

@Reducer
public struct TodayFeature: Sendable {
    // State lives in TodayFeature+State.swift

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case loadDashboard
        case yourDay(YourDayFeature.Action)
        case dailyChallenge(DailyChallengeFeature.Action)
        case dashboardLoaded(Result<HBIDashboardResponse, Error>)
        case loadMenstrualStatus
        case menstrualStatusLoaded(Result<MenstrualStatusResponse, Error>)
        case checkInTapped
        case calendarTapped
        case logSymptomsTapped
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
        case wellnessTapped
        case wellnessDetail(PresentationAction<WellnessDetailFeature.Action>)
        case generateMissingRecaps
        case loadEcho
        case echoLoaded(DayDetailPayload?)
        case echoCardTapped
        case dayDetailDismissed
        case delegate(Delegate)
        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case openAriaChat(context: String)
            case openCycleInsights
            case openCycleJourney
            /// Opens CycleInsights focused on averages & trends (the
            /// Rhythm/Phases sections). Journey widget's Cycle Stats tile.
            case openCycleStats
            /// Opens CycleInsights and deep-links to the Body detail
            /// section (symptoms & signals). Journey widget's Body
            /// Patterns tile.
            case openBodyPatterns
            /// Opens the Journey screen and immediately presents the
            /// recap of the most recent completed cycle. Used by Home's
            /// Latest Story tile — skips the "tap cycle card then tap
            /// recap" hop and drops the user straight into the story.
            case openLatestRecap
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


    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .loadDashboard:
                state.isLoadingDashboard = true
                state.dashboardError = nil
                return Self.loadDashboardEffect(hbiLocal: hbiLocal)

            case .loadMenstrualStatus:
                state.isLoadingMenstrual = true
                return Self.loadMenstrualStatusEffect(menstrualLocal: menstrualLocal)

            case .menstrualStatusLoaded(.success(let status)):
                return Self.handleMenstrualStatusLoaded(status: status, state: &state)

            case .menstrualStatusLoaded(.failure):
                state.isLoadingMenstrual = false
                // Broadcast nil so siblings drop stale data and can show error state.
                return Self.broadcastCycleDataEffect(nil)

            case .calendarEntriesLoaded(.success(let response)):
                return Self.handleCalendarEntriesLoaded(response: response, state: &state)

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

            case .logSymptomsTapped:
                // "Log Symptoms" on Home surfaces today's symptom sheet
                // directly — no calendar overlay. The sheet itself is
                // presented on Home via the calendarState scope.
                let today = Calendar.current.startOfDay(for: Date())
                state.calendarState.selectedDate = today
                return .send(.calendar(.daySelected(today)))

            case .checkIn(.presented(.delegate(.didCompleteCheckIn(_)))):
                return .send(.loadDashboard)

            case .checkIn:
                return .none

            case .calendar(.delegate(.didDismiss)):
                // No automatic `.loadDashboard` here — if period data
                // actually changed while the user was on the calendar,
                // `.periodDataChanged` / `.periodDataNeedsSync`
                // delegates will fire their own reloads. Unconditional
                // reload on dismiss flashed the dashboardRefreshIndicator
                // and pushed the Rhythm widgets down-then-up mid-dismiss.
                state.isCalendarVisible = false
                return .none

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

            // MARK: — Phase broadcast hub
            // All components that react to phase changes subscribe here.
            // To add a new component: add one .send line below.
            case let .phaseResolved(phase, day):
                // Energy from HBI (0-100) → 1-10 for challenge selection
                let rawEnergy = state.dashboard?.today?.energyScore ?? 50
                let energy = max(1, min(10, (rawEnergy / 10) + 1))
                return .merge(
                    .send(.yourDay(.loadPreviews(phase, day))),
                    .send(.dailyChallenge(.selectChallenge(phase: phase.rawValue, energyLevel: energy))),
                    .send(.loadEcho)
                )

            case .backgroundSyncPeriod(let periodDays, let originalPeriodDays, _, _):
                state.recapBannerMonth = nil
                return Self.handleBackgroundSyncPeriod(
                    periodDays: periodDays,
                    originalPeriodDays: originalPeriodDays,
                    menstrualLocal: menstrualLocal
                )

            case .loadWellnessMessage:
                return Self.handleLoadWellness(&state)

            case .wellnessMessageLoaded(let message):
                state.isLoadingWellnessMessage = false
                // Fall back to a muted placeholder on nil (network failure) so
                // the hero keeps its line of copy instead of collapsing to
                // a default cycle phrase from CycleHeroView.
                state.wellnessMessage = message ?? Self.wellnessPlaceholder
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
                if month != nil && !state.yourDayState.isLoading {
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

            case .wellnessTapped:
                guard let adjusted = state.wellnessAdjusted else { return .none }
                state.wellnessDetail = WellnessDetailFeature.State(
                    adjusted: adjusted,
                    trendVsBaseline: state.wellnessTrendVsBaseline,
                    phase: state.wellnessPhase,
                    cycleDay: state.wellnessCycleDay,
                    sourceLabel: state.wellnessSourceLabel
                )
                return .none

            case .wellnessDetail(.presented(.delegate(.dismiss))):
                state.wellnessDetail = nil
                return .none

            case .wellnessDetail:
                return .none

            case .generateMissingRecaps:
                // Delegates to `CycleRecapGenerator.generateMissing()`,
                // which handles the full 6-chapter pipeline (Key Day
                // extraction + AI call + template fallback + cache). Keeps
                // this reducer case small enough to type-check quickly.
                return .run { send in
                    CycleJourneyFeature.cleanupLegacyRecapDefaults()
                    await CycleRecapGenerator.generateMissing()
                    await send(.refreshRecapBanner)
                }
                .cancellable(id: CancelID.recapGeneration, cancelInFlight: true)

            case let .yourDay(inner):
                return Self.handleYourDay(inner, state: &state)

            case let .dailyChallenge(.delegate(.challengeStateChanged(snapshot))):
                // Challenge lives solely in the Rhythm widget now, so no
                // card-stack mirroring is required. Kept as a named case
                // to make the data flow obvious at a glance.
                _ = snapshot
                return .none

            case .dailyChallenge(.delegate(.challengeJustCompleted)):
                // Fires only at the transition moment (after validation
                // success), not on every app launch with an already-
                // completed challenge. Safe to reload dashboard here.
                return .send(.loadDashboard)

            case .dailyChallenge:
                return .none

            case .loadEcho:
                guard let cycle = state.cycle else { return .none }
                let cycleDay = cycle.cycleDay
                let bleedingDays = cycle.bleedingDays
                return .run { send in
                    let payload = await Self.fetchEchoPayload(
                        currentCycleDay: cycleDay,
                        bleedingDays: bleedingDays
                    )
                    await send(.echoLoaded(payload))
                }

            case let .echoLoaded(payload):
                state.echoPayload = payload
                return .none

            case .echoCardTapped:
                state.dayDetailPayload = state.echoPayload
                return .none

            case .dayDetailDismissed:
                state.dayDetailPayload = nil
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
        .ifLet(\.$wellnessDetail, action: \.wellnessDetail) {
            WellnessDetailFeature()
        }
        Scope(state: \.calendarState, action: \.calendar) {
            CalendarFeature()
        }
        Scope(state: \.yourDayState, action: \.yourDay) {
            YourDayFeature()
        }
        Scope(state: \.dailyChallengeState, action: \.dailyChallenge) {
            DailyChallengeFeature()
        }
    }
}

