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
        /// Wellness detail sheet — hydrated from today's HBI on tap so the
        /// sheet opens with the same numbers the widget just rendered.
        @Presents var wellnessDetail: WellnessDetailFeature.State?
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

        // MARK: — Wellness hero (W2)
        //
        // Mirrors of the latest `HBIScore` used to feed `WellnessWidget` on
        // Home and seed the `WellnessDetailFeature` when the sheet opens.
        // All values derive from `dashboard?.today` — never from math here.

        /// 0-100 adjusted score from W1.
        public var wellnessAdjusted: Double? {
            guard let today = dashboard?.today else { return nil }
            return Double(today.hbiAdjusted)
        }

        /// Signed delta vs the user's own phase baseline. `nil` when baseline
        /// confidence is insufficient — widget renders the "building" copy.
        public var wellnessTrendVsBaseline: Double? {
            dashboard?.today?.trendVsBaseline
        }

        /// Resolved `CyclePhase` for the widget's header. Late is downgraded
        /// to `.luteal` for layout (widget hides meta on `.late`).
        public var wellnessPhase: CyclePhase? {
            guard let raw = dashboard?.today?.cyclePhase else {
                return cycle?.currentPhase
            }
            return CyclePhase(rawValue: raw) ?? cycle?.currentPhase
        }

        /// Cycle day paired with phase label ("Luteal · Day 22").
        public var wellnessCycleDay: Int? {
            dashboard?.today?.cycleDay ?? cycle?.cycleDay
        }

        /// "Based on" footer copy. Uses whichever signals hydrated today's
        /// score; empty check-in state falls back to a gentle onboarding line.
        public var wellnessSourceLabel: String {
            guard let today = dashboard?.today else {
                return "Complete your first check-in"
            }
            var pieces: [String] = []
            if today.hasSelfReport { pieces.append("Today's check-in") }
            if today.hasHealthkitData { pieces.append("Health data") }
            if pieces.isEmpty { pieces.append("Building your picture") }
            return pieces.joined(separator: " · ")
        }

        /// True when the Aria voice line should render under the widget.
        /// Only fires when the trend is meaningfully positive so we don't
        /// nag on routine fluctuations.
        public var shouldShowAriaVoice: Bool {
            guard let trend = wellnessTrendVsBaseline else { return false }
            return trend > 3
        }

        // MARK: — Cycle Live (Journey page)
        //
        // Editorial snippet for the Journey page Cycle Live widget.
        // Mirrors the Your moment category from Rhythm so both pages
        // reference the same underlying choice (action vs context).

        public var cycleLiveContent: CycleLiveContent? {
            guard let phase = wellnessPhase else { return nil }
            let category = dailyChallengeState.challenge?.challengeCategory
            return CycleLiveEngine.content(
                phase: phase,
                cycleDay: wellnessCycleDay,
                momentCategory: category
            )
        }

        public var cycleLiveDaysUntilPeriod: Int? {
            guard let days = cycle?.daysUntilPeriod(from: Date()) else {
                return nil
            }
            return days > 0 ? days : nil
        }

        // Your Day — Lens previews
        public var yourDayState: YourDayFeature.State = YourDayFeature.State()

        // Daily Glow challenge
        public var dailyChallengeState: DailyChallengeFeature.State = DailyChallengeFeature.State()

        // Notifications
        public var recapBannerMonth: String?
        public var isRecapSheetVisible: Bool = false
        public var isNotificationsPanelVisible: Bool = false

        // Echo from last cycle (same cycle-day, one cycle ago).
        // Surfaces on Home's Journey page and drives the Day Detail sheet.
        public var echoPayload: DayDetailPayload?
        public var dayDetailPayload: DayDetailPayload?

        public init() {}
    }

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

    /// Muted placeholder shown when the wellness AI fetch returns nil (network
    /// failure, backend down, etc.). Intentionally gentle — keeps the hero
    /// from collapsing to empty whitespace without screaming "error".
    private static let wellnessPlaceholder = "Checking in with you soon."

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
        // HBI only fans out to features that actually re-weight on it.
        // YourDay's content is now phase-driven via LensPreviewClient —
        // HBI changes don't invalidate today's preview list.
        .send(.dailyChallenge(.hbiUpdated(score)))
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

    /// Extracted from the main `Reduce` to keep the switch small and
    /// avoid Swift type-checker timeouts on the full reducer body.
    private static func handleMenstrualStatusLoaded(
        status: MenstrualStatusResponse,
        state: inout State
    ) -> Effect<Action> {
        state.isLoadingMenstrual = false
        state.menstrualStatus = status
        state.calendarState.menstrualStatus = status
        let hasCycleData = status.hasCycleData
        let localCal = Calendar.current
        if hasCycleData {
            let startDate = CalendarFeature.localDate(from: status.currentCycle.startDate)
            state.calendarState.cycleStartDate = localCal.startOfDay(for: startDate)
        }
        state.calendarState.cycleLength = status.profile.avgCycleLength ?? 28
        state.calendarState.bleedingDays = status.currentCycle.bleedingDays ?? 5

        var effects: [Effect<Action>] = []
        if !state.calendarState.hasPreloaded {
            state.calendarState.hasPreloaded = true
            effects.append(.send(.calendar(.loadCalendar)))
        }
        if !hasCycleData {
            state.yourDayState.previews = []
            state.yourDayState.currentPhase = nil
        } else if state.hasCompletedCalendarLoad {
            effects.append(Self.syncPhaseEffect(state: state))
        }
        if hasCycleData && state.wellnessMessage == nil {
            effects.append(.send(.loadWellnessMessage))
        }
        effects.append(Self.broadcastCycleDataEffect(state.cycle))
        return effects.isEmpty ? .none : .merge(effects)
    }

    /// Extracted — see `handleMenstrualStatusLoaded` for rationale.
    private static func handleCalendarEntriesLoaded(
        response: MenstrualCalendarResponse,
        state: inout State
    ) -> Effect<Action> {
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
        let cycleBroadcast = Self.broadcastCycleDataEffect(state.cycle)

        if state.isRefreshingCycleData {
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
    }

    /// Extracted — the `.merge(.run, .send)` pattern was a notable
    /// contributor to the type-checker timeout.
    private static func loadDashboardEffect(hbiLocal: HBILocalClient) -> Effect<Action> {
        .merge(
            .run { send in
                let result = await Result {
                    try await hbiLocal.getDashboard()
                }
                await send(.dashboardLoaded(result))
            },
            .send(.loadMenstrualStatus)
        )
    }

    /// Extracted — two parallel fetches merged.
    private static func loadMenstrualStatusEffect(
        menstrualLocal: MenstrualLocalClient
    ) -> Effect<Action> {
        .merge(
            .run { send in
                let result = await Result {
                    try await menstrualLocal.getStatus()
                }
                await send(.menstrualStatusLoaded(result))
            },
            .run { send in
                let start = Calendar.current.date(byAdding: .month, value: -24, to: Date())!
                let end = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
                let result = await Result {
                    try await menstrualLocal.getCalendar(start, end)
                }
                await send(.calendarEntriesLoaded(result), animation: .easeInOut(duration: 0.3))
            }
        )
    }

    /// Extracted — big `.run` block that confirms/removes period groups
    /// and regenerates predictions. Inlining it alongside the rest of
    /// the cases tips Swift's type-checker over the edge.
    private static func handleBackgroundSyncPeriod(
        periodDays: Set<String>,
        originalPeriodDays: Set<String>,
        menstrualLocal: MenstrualLocalClient
    ) -> Effect<Action> {
        let periodGroups = EditPeriodFeature.groupConsecutivePeriods(periodDays)
        let removedDays = originalPeriodDays.subtracting(periodDays)
        return .run { send in
            if !removedDays.isEmpty {
                let datesToRemove = removedDays.compactMap { CalendarFeature.parseDate($0) }
                try? await menstrualLocal.removePeriodDays(datesToRemove)
            }
            for group in periodGroups {
                try? await menstrualLocal.confirmPeriod(
                    group.startDate, group.dayCount, nil, true
                )
            }
            if !periodGroups.isEmpty {
                try? await menstrualLocal.generatePrediction()
            }
            await send(.backgroundSyncCompleted)
        }
    }

    /// Extracted to keep the main `Reduce` switch small — Swift's type
    /// checker starts timing out when the body has too many complex
    /// `.merge` / `.run` patterns side by side.
    private static func handleYourDay(
        _ action: YourDayFeature.Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .previewsLoaded:
            if state.recapBannerMonth != nil && !state.isRecapSheetVisible {
                state.isRecapSheetVisible = true
            }
            return .none
        case .delegate(.openLens(_)):
            return .send(.delegate(.openCycleInsights))
        default:
            return .none
        }
    }

    // MARK: - Echo loader
    //
    // Builds a `DayDetailPayload` for "today's cycle day, one cycle ago".
    // Walks the journey records to find the previous cycle's start date,
    // targets the matching day, then queries SwiftData for the day's
    // self-report / moment / HBI signals. Returns `nil` when the user
    // has no previous cycle to compare against.
    static func fetchEchoPayload(
        currentCycleDay: Int,
        bleedingDays: Int
    ) async -> DayDetailPayload? {
        guard currentCycleDay > 0 else { return nil }
        let data: JourneyData
        do {
            data = try await MenstrualLocalClient.liveJourneyData()()
        } catch {
            return nil
        }

        let cal = Calendar.current
        let sortedOldestFirst = data.records.sorted { $0.startDate < $1.startDate }
        guard sortedOldestFirst.count >= 2 else { return nil }
        let previousRecord = sortedOldestFirst[sortedOldestFirst.count - 2]

        let previousStart = cal.startOfDay(for: previousRecord.startDate)
        guard let targetDate = cal.date(
            byAdding: .day,
            value: currentCycleDay - 1,
            to: previousStart
        ) else { return nil }

        // Past-cycle length: prefer the actual recorded length; fall
        // back to profile average so the phase math still lands somewhere
        // sensible for older data.
        let cycleLength: Int = {
            if let actual = previousRecord.actualCycleLength {
                return actual
            }
            let current = sortedOldestFirst.last?.startDate
            if let current {
                let gap = cal.dateComponents([.day], from: previousStart, to: current).day ?? data.profileAvgCycleLength
                if gap >= 18 && gap <= 50 { return gap }
            }
            return data.profileAvgCycleLength
        }()

        let previousBleedingDays = previousRecord.bleedingDays > 0
            ? previousRecord.bleedingDays
            : bleedingDays

        let signals = fetchDaySignals(on: targetDate)
        let cycleNumber = sortedOldestFirst.count - 1 // previous cycle's ordinal

        return JourneyEchoEngine.buildEcho(
            for: targetDate,
            cycleStartDate: previousStart,
            cycleNumber: cycleNumber,
            cycleDay: currentCycleDay,
            cycleLength: cycleLength,
            bleedingDays: previousBleedingDays,
            signals: signals
        )
    }

    /// Pulls per-day signals for a given calendar date from the shared
    /// `CycleDataStore`. Returns a `DaySignals` with `nil`s wherever the
    /// user has no log — the engine treats that as "untracked".
    private static func fetchDaySignals(on date: Date) -> JourneyEchoEngine.DaySignals {
        let context = ModelContext(CycleDataStore.shared)
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            return JourneyEchoEngine.DaySignals()
        }

        let reportDesc = FetchDescriptor<SelfReportRecord>(
            predicate: #Predicate { $0.reportDate >= dayStart && $0.reportDate < dayEnd }
        )
        let challengeDesc = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd && $0.status == "completed" }
        )
        let hbiDesc = FetchDescriptor<HBIScoreRecord>(
            predicate: #Predicate { $0.scoreDate >= dayStart && $0.scoreDate < dayEnd }
        )

        let report = (try? context.fetch(reportDesc))?.first
        let challenge = (try? context.fetch(challengeDesc))?.first
        let hbi = (try? context.fetch(hbiDesc))?.first

        return JourneyEchoEngine.DaySignals(
            mood: report?.moodLevel,
            energy: report?.energyLevel,
            stress: report?.stressLevel,
            sleep: report?.sleepQuality,
            momentCategory: challenge?.challengeCategory,
            momentTitle: challenge?.challengeTitle,
            momentValidationFeedback: challenge?.validationFeedback,
            momentValidationRating: challenge?.validationRating,
            momentPhotoThumbnail: challenge?.photoThumbnail,
            hbiAdjusted: hbi?.hbiAdjusted,
            hbiTrendVsBaseline: hbi?.trendVsBaseline
        )
    }

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

