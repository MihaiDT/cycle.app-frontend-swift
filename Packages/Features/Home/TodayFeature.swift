import ComposableArchitecture
import Inject
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
        /// Period day keys from server calendar entries (source of truth for week calendar)
        public var serverPeriodDays: Set<String> = []
        /// Predicted period day keys (subset of serverPeriodDays) — for dashed styling
        public var serverPredictedDays: Set<String> = []
        /// Fertile days with their level from server calendar (keys: "yyyy-MM-dd")
        public var serverFertileDays: [String: FertilityLevel] = [:]
        /// Ovulation day keys from server calendar (keys: "yyyy-MM-dd")
        public var serverOvulationDays: Set<String> = []

        @Presents var checkIn: DailyCheckInFeature.State?
        @Presents var calendar: CalendarFeature.State?
        @Presents var editPeriod: EditPeriodFeature.State?

        public var hasAppeared: Bool = false
        public var scoreAnimationProgress: Double = 0

        /// Single source of truth for all cycle data — derived from server responses
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

        public var hasCompletedCheckIn: Bool {
            dashboard?.latestReport != nil
        }

        public var todayScore: Int {
            dashboard?.today?.hbiAdjusted ?? 0
        }

        public var trendDirection: String? {
            dashboard?.today?.trendDirection
        }

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case loadDashboard
        case dashboardLoaded(Result<HBIDashboardResponse, Error>)
        case loadMenstrualStatus
        case menstrualStatusLoaded(Result<MenstrualStatusResponse, Error>)
        case calendarEntriesLoaded(Result<MenstrualCalendarResponse, Error>)
        case checkInTapped
        case calendarTapped
        case logPeriodTapped(focusDate: Date? = nil)
        case checkIn(PresentationAction<DailyCheckInFeature.Action>)
        case calendar(PresentationAction<CalendarFeature.Action>)
        case editPeriod(PresentationAction<EditPeriodFeature.Action>)
        case triggerScoreAnimation
        case scoreAnimationTick(Double)
        case refreshTapped
        case delegate(Delegate)
        public enum Delegate: Sendable, Equatable {
            case openAriaChat(context: String)
        }
    }

    @Dependency(\.hbiClient) var hbiClient
    @Dependency(\.menstrualClient) var menstrualClient
    @Dependency(\.sessionClient) var sessionClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .loadDashboard:
                state.isLoadingDashboard = true
                state.dashboardError = nil
                if !state.hasAppeared {
                    state.hasAppeared = true
                }
                return .merge(
                    .run { send in
                        guard let token = try? await sessionClient.getAccessToken() else {
                            await send(.dashboardLoaded(.failure(MenstrualError.noToken)))
                            return
                        }
                        let result = await Result {
                            try await hbiClient.getDashboard(token)
                        }
                        await send(.dashboardLoaded(result))
                    },
                    .send(.loadMenstrualStatus)
                )

            case .loadMenstrualStatus:
                state.isLoadingMenstrual = true
                return .merge(
                    .run { send in
                        guard let token = try? await sessionClient.getAccessToken() else {
                            await send(.menstrualStatusLoaded(.failure(MenstrualError.noToken)))
                            return
                        }
                        let result = await Result {
                            try await menstrualClient.getStatus(token)
                        }
                        await send(.menstrualStatusLoaded(result))
                    },
                    .run { [menstrualClient, sessionClient] send in
                        guard let token = try? await sessionClient.getAccessToken() else { return }
                        let start = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
                        let end = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
                        let result = await Result {
                            try await menstrualClient.getCalendar(token, start, end)
                        }
                        await send(.calendarEntriesLoaded(result))
                    }
                )

            case .menstrualStatusLoaded(.success(let status)):
                state.isLoadingMenstrual = false
                state.menstrualStatus = status
                return .none

            case .menstrualStatusLoaded(.failure):
                state.isLoadingMenstrual = false
                return .none

            case .calendarEntriesLoaded(.success(let response)):
                var days: Set<String> = []
                var predicted: Set<String> = []
                var fertile: [String: FertilityLevel] = [:]
                var ovulation: Set<String> = []
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                let todayKey = fmt.string(from: Calendar.current.startOfDay(for: Date()))
                for entry in response.entries {
                    let localDay = CalendarFeature.localDate(from: entry.date)
                    let key = fmt.string(from: localDay)
                    if entry.type == "period" {
                        days.insert(key)
                        // Future bleeding days from current cycle → show as predicted
                        if key > todayKey {
                            predicted.insert(key)
                        }
                    } else if entry.type == "predicted_period" {
                        days.insert(key)
                        predicted.insert(key)
                    } else if entry.type == "fertile", let levelStr = entry.fertilityLevel,
                              let level = FertilityLevel(rawValue: levelStr) {
                        fertile[key] = level
                    } else if entry.type == "ovulation" {
                        ovulation.insert(key)
                    }
                }
                state.serverPeriodDays = days
                state.serverPredictedDays = predicted
                state.serverFertileDays = fertile
                state.serverOvulationDays = ovulation
                return .none

            case .calendarEntriesLoaded(.failure):
                return .none

            case .dashboardLoaded(.success(let dashboard)):
                state.isLoadingDashboard = false
                state.dashboard = dashboard
                if !state.hasAppeared {
                    state.hasAppeared = true
                    return .send(.triggerScoreAnimation)
                }
                return .none

            case .dashboardLoaded(.failure(let error)):
                state.isLoadingDashboard = false
                state.dashboardError = error.localizedDescription
                state.hasAppeared = true
                return .none

            case .checkInTapped:
                state.checkIn = DailyCheckInFeature.State()
                return .none

            case .calendarTapped:
                state.calendar = CalendarFeature.State(
                    menstrualStatus: state.menstrualStatus,
                    periodDays: state.serverPeriodDays,
                    predictedPeriodDays: state.serverPredictedDays,
                    fertileDays: state.serverFertileDays,
                    ovulationDays: state.serverOvulationDays
                )
                return .send(.calendar(.presented(.loadCalendar)))

            case .logPeriodTapped(let focusDate):
                let today = Calendar.current.startOfDay(for: Date())
                let status = state.menstrualStatus
                let startDate = status.flatMap { s in
                    s.hasCycleData ? CalendarFeature.localDate(from: s.currentCycle.startDate) : nil
                } ?? today
                let cycleLength = status?.profile.avgCycleLength ?? 28
                let bleedingDays = status?.currentCycle.bleedingDays ?? 5

                // Exclude predicted days from periodDays — EditPeriod shows them separately
                let confirmedDays = state.serverPeriodDays.subtracting(state.serverPredictedDays)
                state.editPeriod = EditPeriodFeature.State(
                    cycleStartDate: startDate,
                    cycleLength: cycleLength,
                    bleedingDays: bleedingDays,
                    periodDays: confirmedDays,
                    periodFlowIntensity: [:],
                    predictedPeriodDays: state.serverPredictedDays,
                    focusDate: focusDate
                )
                return .none

            case .checkIn(.presented(.delegate(.didCompleteCheckIn(_)))):
                return .send(.loadDashboard)

            case .checkIn:
                return .none

            case .calendar(.presented(.delegate(.didDismiss))):
                // Server will be refreshed via .calendar(.dismiss) → .loadDashboard
                return .none

            case .calendar(.presented(.delegate(.openAriaChat(let context)))):
                state.calendar = nil
                return .send(.delegate(.openAriaChat(context: context)))

            case .calendar(.dismiss):
                // Grab fresh data from CalendarFeature before it's dismissed
                if let calState = state.calendar {
                    state.serverPeriodDays = calState.periodDays
                    state.serverPredictedDays = calState.predictedPeriodDays
                }
                // Refresh status in background (for cycleDay, phase, etc.)
                return .merge(
                    .send(.loadDashboard),
                    .send(.loadMenstrualStatus)
                )

            case .calendar:
                return .none

            case .editPeriod(.presented(.delegate(let delegate))):
                if case .didSave(let periodDays, let predictedDays, _) = delegate {
                    // Use fresh data from EditPeriod instantly
                    state.serverPeriodDays = periodDays.union(predictedDays)
                    state.serverPredictedDays = predictedDays
                }
                state.editPeriod = nil
                // Also refresh menstrual status for cycleDay etc.
                return .merge(
                    .send(.loadDashboard),
                    .send(.loadMenstrualStatus)
                )

            case .editPeriod:
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

            case .binding, .delegate:
                return .none
            }
        }
        .ifLet(\.$checkIn, action: \.checkIn) {
            DailyCheckInFeature()
        }
        .ifLet(\.$calendar, action: \.calendar) {
            CalendarFeature()
        }
        .ifLet(\.$editPeriod, action: \.editPeriod) {
            EditPeriodFeature()
        }
    }
}

private enum MenstrualError: Error { case noToken }

// MARK: - Wellness Pillar Model

public struct WellnessPillar: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let score: Int
    public let icon: String
    public let trend: String?

    public init(name: String, score: Int, icon: String, trend: String?) {
        self.id = name
        self.name = name
        self.score = score
        self.icon = icon
        self.trend = trend
    }
}

// MARK: - Celestial Snap Behavior

private struct CelestialSnapBehavior: ScrollTargetBehavior {
    /// The scroll offset at which the circle becomes fully collapsed
    let collapseOffset: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let y = target.rect.minY
        // If we're in the transition zone (between 0 and collapseOffset),
        // snap to either fully expanded (0) or fully collapsed (collapseOffset)
        guard y > 0 && y < collapseOffset else { return }
        
        if y > collapseOffset * 0.35 {
            // Past 35% → snap to collapsed
            target.rect.origin.y = collapseOffset
        } else {
            // Before 35% → snap back to expanded
            target.rect.origin.y = 0
        }
    }
}

// MARK: - Today View

public struct TodayView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<TodayFeature>

    @State private var showHeader = false
    @State private var showCalendar = false
    @State private var showCelestial = false
    @State private var containerMinY: CGFloat = 0
    @State private var celestialMinY: CGFloat = 0
    @State private var calendarMinY: CGFloat = 0
    @State private var showCheckIn = false
    @State private var showScore = false
    @State private var showPillars = false
    @State private var showInsights = false
    /// Ring drag exploring day (1-based, current cycle only)
    @State private var ringExploringDay: Int?
    /// Calendar-selected date (any date in cycle range)
    @State private var calendarDate: Date?

    public init(store: StoreOf<TodayFeature>) {
        self.store = store
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    private var pillars: [WellnessPillar] {
        guard let today = store.dashboard?.today else {
            return [
                WellnessPillar(name: "Energy", score: 0, icon: "bolt.fill", trend: nil),
                WellnessPillar(name: "Mood", score: 0, icon: "face.smiling.fill", trend: nil),
                WellnessPillar(name: "Sleep", score: 0, icon: "moon.fill", trend: nil),
                WellnessPillar(name: "Calm", score: 0, icon: "leaf.fill", trend: nil),
            ]
        }
        return [
            WellnessPillar(name: "Energy", score: today.energyScore, icon: "bolt.fill", trend: today.trendDirection),
            WellnessPillar(
                name: "Mood",
                score: today.moodScore,
                icon: "face.smiling.fill",
                trend: today.trendDirection
            ),
            WellnessPillar(name: "Sleep", score: today.sleepScore, icon: "moon.fill", trend: today.trendDirection),
            WellnessPillar(name: "Calm", score: today.anxietyScore, icon: "leaf.fill", trend: today.trendDirection),
        ]
    }

    private var displayedScore: Int {
        store.dashboard?.today?.hbiAdjusted ?? 0
    }

    private var displayedTrendDirection: String {
        store.trendDirection ?? "stable"
    }

    private var displayedInsights: [String] {
        if let insights = store.dashboard?.insights, !insights.isEmpty {
            return insights
        }
        if store.dashboard == nil {
            return ["Complete your daily check-in to see wellness insights."]
        }
        return ["Complete your daily check-in to see wellness insights."]
    }

    private var relativeMinY: CGFloat {
        celestialMinY - containerMinY
    }

    private var collapseProgress: CGFloat {
        let start: CGFloat = 80
        let end: CGFloat = -100
        return min(1, max(0, (start - relativeMinY) / (start - end)))
    }

    private var smoothCollapse: CGFloat {
        let t = collapseProgress
        return t * t * (3 - 2 * t) // smoothstep
    }

    private var celestialScale: CGFloat {
        max(0.194, 1.0 - smoothCollapse * 0.806)
    }

    // Calendar height smoothly interpolated: full=86pt → compact=40pt
    private var calendarVisualHeight: CGFloat {
        let full: CGFloat = 86
        let compact: CGFloat = 40
        return full + (compact - full) * smoothCollapse
    }

    private var calendarIsCompact: Bool {
        collapseProgress > 0.3
    }

    private var celestialFloatY: CGFloat {
        // Circle center = offset + 190. Orbit radius = 170pt.
        // Visible top of circle = offset + 190 - 170 * scale.
        // Calendar bottom = calendarFloatY + calendarVisualHeight.
        // Constraint: visible top >= calendar bottom
        //   → offset >= calendarFloatY + calendarVisualHeight - 190 + 170*scale
        let restOffset = relativeMinY
        let collapsedOffset: CGFloat = -95
        let baseY = restOffset + (collapsedOffset - restOffset) * smoothCollapse

        let minOffset = calendarFloatY + calendarVisualHeight - 190 + 170 * celestialScale
        return max(baseY, minOffset)
    }

    private var celestialFloatX: CGFloat {
        // At rest: centered → offset = 0
        // Collapsed: align circle left edge with calendar left edge (horizontalPadding)
        // Circle diameter collapsed = 340 * minScale ≈ 66pt, radius ≈ 33pt
        // Circle center = horizontalPadding + radius
        let screenW = UIScreen.main.bounds.width
        let collapsedRadius = (340 * 0.194) / 2
        let collapsedCenterX = AppLayout.horizontalPadding + collapsedRadius
        let collapsedX = collapsedCenterX - screenW / 2
        return collapsedX * smoothCollapse
    }

    // MARK: - Calendar Collapse (synced with circle)

    private var calendarRelativeMinY: CGFloat {
        calendarMinY - containerMinY
    }

    private var calendarFloatY: CGFloat {
        // Float with scroll, but pin at top (never go above 0)
        max(0, calendarRelativeMinY)
    }

    private var calendarOpacity: CGFloat {
        1.0 // Always visible — it's a sticky header
    }

    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppLayout.spacingL) {
                    // MARK: Header
                    todayHeader
                        .opacity(showHeader ? 1 : 0)
                        .offset(y: showHeader ? 0 : 12)

                    // MARK: Week Calendar Placeholder
                    Color.clear
                        .frame(height: 86)
                        .background {
                            GeometryReader { geo in
                                let minY = geo.frame(in: .global).minY
                                Color.clear
                                    .onAppear { calendarMinY = minY }
                                    .onChange(of: minY) { _, val in calendarMinY = val }
                            }
                        }

                    // MARK: Celestial Placeholder
                    Color.clear
                        .frame(height: 380)
                        .background {
                            GeometryReader { geo in
                                let minY = geo.frame(in: .global).minY
                                Color.clear
                                    .onAppear { celestialMinY = minY }
                                    .onChange(of: minY) { _, val in celestialMinY = val }
                            }
                        }

                    // MARK: Check-in CTA
                    checkInCard
                        .opacity(showCheckIn ? 1 : 0)
                        .offset(y: showCheckIn ? 0 : 16)

                    // MARK: Fertile Window Banner
                    if let cycle = store.cycle, shouldShowFertileBanner(cycle: cycle) {
                        FertileWindowBanner(cycle: cycle)
                            .opacity(showCheckIn ? 1 : 0)
                            .offset(y: showCheckIn ? 0 : 16)
                    }

                    // MARK: HBI Score Hero
                    hbiScoreHero
                        .opacity(showScore ? 1 : 0)
                        .offset(y: showScore ? 0 : 16)

                    // MARK: Wellness Pillars
                    wellnessPillarsGrid
                        .opacity(showPillars ? 1 : 0)
                        .offset(y: showPillars ? 0 : 16)

                    // MARK: Insights
                    insightsSection(displayedInsights)
                        .opacity(showInsights ? 1 : 0)
                        .offset(y: showInsights ? 0 : 16)

                    VerticalSpace.xl
                }
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.top, AppLayout.spacingM)
            }
            .scrollTargetBehavior(CelestialSnapBehavior(collapseOffset: 420))
            .background {
                GeometryReader { geo in
                    let minY = geo.frame(in: .global).minY
                    Color.clear
                        .onAppear { containerMinY = minY }
                        .onChange(of: minY) { _, val in containerMinY = val }
                }
            }
            .refreshable {
                store.send(.refreshTapped)
            }
            .sheet(item: $store.scope(state: \.checkIn, action: \.checkIn)) { checkInStore in
                DailyCheckInView(store: checkInStore)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(AppLayout.cornerRadiusL)
            }
            .fullScreenCover(item: $store.scope(state: \.calendar, action: \.calendar)) { calendarStore in
                CalendarView(store: calendarStore)
            }
            .fullScreenCover(item: $store.scope(state: \.editPeriod, action: \.editPeriod)) { editStore in
                EditPeriodView(store: editStore)
            }
            .onChange(of: store.hasAppeared) { _, appeared in
                guard appeared else { return }
                triggerStaggeredAnimations()
            }
            .onChange(of: calendarDate) { _, newDate in
                // Calendar selection clears ring exploration (mutually exclusive)
                if newDate != nil && ringExploringDay != nil {
                    ringExploringDay = nil
                }
            }
            .onChange(of: store.calendar == nil) { _, dismissed in
                // Reset exploration state when calendar/editPeriod is dismissed
                if dismissed {
                    ringExploringDay = nil
                    calendarDate = nil
                }
            }
            .onChange(of: store.editPeriod == nil) { _, dismissed in
                if dismissed {
                    ringExploringDay = nil
                    calendarDate = nil
                }
            }

            // MARK: Floating Celestial Circle
            celestialCycleSection
                .frame(height: 380, alignment: .top)
                .scaleEffect(celestialScale)
                .offset(x: celestialFloatX, y: celestialFloatY)
                .opacity(showCelestial ? 1 : 0)
                .allowsHitTesting(collapseProgress < 0.3)

            // MARK: Floating Week Calendar (above circle)
            VStack(spacing: 0) {
                weekCalendarSection
                    .padding(.horizontal, 12)
                Spacer(minLength: 0)
            }
            .offset(y: calendarFloatY)
            .opacity(showCalendar ? calendarOpacity : 0)
            .allowsHitTesting(collapseProgress < 0.5)

            // MARK: Collapsed Info
            collapsedCycleInfo
        }
        .enableInjection()
    }

    // MARK: - Staggered Animations

    private func triggerStaggeredAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showHeader = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.08)) {
            showCalendar = true
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.16)) {
            showCelestial = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.34)) {
            showCheckIn = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45)) {
            showScore = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.60)) {
            showPillars = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.75)) {
            showInsights = true
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var todayHeader: some View {
        HStack {
            Text(greeting)
                .font(.custom("Raleway-Bold", size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignColors.text, DesignColors.textPrincipal, DesignColors.accentWarm],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Spacer()

            Button { store.send(.calendarTapped) } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Week Calendar

    @ViewBuilder
    private var weekCalendarSection: some View {
        if let cycle = store.cycle {
            GlassWeekCalendar(
                cycle: cycle,
                selectedDate: $calendarDate,
                isCompact: calendarIsCompact
            )
        } else {
            Color.clear
        }
    }

    // MARK: - Celestial Cycle

    @ViewBuilder
    private var celestialCycleSection: some View {
        if let cycle = store.cycle {
            CelestialCycleView(
                cycle: cycle,
                collapseProgress: collapseProgress,
                exploringDay: $ringExploringDay,
                calendarDate: $calendarDate,
                onLogPeriod: { date in store.send(.logPeriodTapped(focusDate: date)) }
            )
        } else if store.menstrualStatus != nil {
            // Has profile but no cycle data — show empty state
            noCycleDataView
        } else {
            noCycleDataView
        }
    }

    @ViewBuilder
    private var noCycleDataView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignColors.accentWarm.opacity(0.3),
                                DesignColors.accentWarm.opacity(0.1),
                                Color.purple.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 8
                    )
                    .frame(width: 200, height: 200)

                VStack(spacing: 8) {
                    Image(systemName: "drop")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignColors.accentWarm.opacity(0.7), Color.purple.opacity(0.5)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                    Text("No cycle data yet")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundColor(DesignColors.text.opacity(0.8))

                    Text("Log your period to start tracking")
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                store.send(.logPeriodTapped())
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("Log Period")
                        .font(.custom("Raleway-SemiBold", size: 15))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, Color.pink.opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                }
            }
        }
        .frame(height: 340)
    }

    // MARK: - Collapsed Cycle Info

    @ViewBuilder
    private var collapsedCycleInfo: some View {
        let phase = store.cycle?.currentPhase ?? .follicular
        let infoOpacity = min(1.0, max(0, (Double(collapseProgress) - 0.85) / 0.15))

        // Circle visible diameter = 340 * celestialScale
        // Circle center X when collapsed = horizontalPadding + collapsedRadius
        let collapsedRadius: CGFloat = (340 * 0.194) / 2
        let circleCenterX: CGFloat = AppLayout.horizontalPadding + collapsedRadius
        let circleRightEdge: CGFloat = circleCenterX + (340 * celestialScale) / 2
        // Circle center Y = frame center (190) + celestialFloatY
        let circleCenterY = 190 + celestialFloatY

        HStack(spacing: 6) {
            Text(phase.displayName)
                .font(.custom("Raleway-SemiBold", size: 15))
                .foregroundColor(phase.orbitColor)
        }
        .padding(.leading, circleRightEdge + 20)
        .padding(.top, circleCenterY - 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(infoOpacity)
        .allowsHitTesting(false)
    }

    // MARK: - Check-In Card

    @ViewBuilder
    private var checkInCard: some View {
        if store.hasCompletedCheckIn {
            // Completed state
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(DesignColors.accentWarm)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Check-in Complete")
                        .font(.custom("Raleway-SemiBold", size: 15))
                        .foregroundColor(DesignColors.text)

                    Text("Your HBI score has been updated")
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(DesignColors.textSecondary)
                }

                Spacer()
            }
            .padding(AppLayout.spacingM)
            .background {
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        DesignColors.accentWarm.opacity(0.6), DesignColors.accentSecondary.opacity(0.3),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: DesignColors.accentWarm.opacity(0.1), radius: 8, x: 0, y: 2)
            }
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                )
            )
        } else {
            // CTA state
            Button(action: { store.send(.checkInTapped) }) {
                VStack(spacing: 12) {
                    Image(systemName: "sun.and.horizon")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(DesignColors.accentWarm)

                    Text("How are you feeling today?")
                        .font(.custom("Raleway-SemiBold", size: 17))
                        .foregroundColor(DesignColors.text)

                    Text("Take a quick check-in to track your wellness")
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(DesignColors.textSecondary)

                    Text("Start Check-in")
                        .font(.custom("Raleway-SemiBold", size: 15))
                        .foregroundColor(DesignColors.text)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .glassEffectCapsule()
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                }
                .padding(.vertical, AppLayout.spacingL)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }
    }

    // MARK: - Fertile Window Banner

    private func shouldShowFertileBanner(cycle: CycleContext) -> Bool {
        // Show if fertile window is active or approaching (within 3 days)
        if cycle.fertileWindowActive { return true }
        if let days = cycle.daysUntilOvulation, days > 0, days <= 8 { return true }
        // Also show if today is a fertile day from calendar data
        let today = Calendar.current.startOfDay(for: Date())
        let c = Calendar.current.dateComponents([.year, .month, .day], from: today)
        let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        return cycle.fertileDays[key] != nil
    }

    // MARK: - HBI Score Hero

    @ViewBuilder
    private var hbiScoreHero: some View {
        VStack(spacing: AppLayout.spacingM) {
            HBIScoreRing(
                score: displayedScore,
                animationProgress: store.scoreAnimationProgress,
                size: 180
            )

            // Trend indicator
            HStack(spacing: 4) {
                Image(
                    systemName: displayedTrendDirection == "up"
                        ? "arrow.up.right" : displayedTrendDirection == "down" ? "arrow.down.right" : "arrow.right"
                )
                .font(.system(size: 12, weight: .bold))
                Text(
                    displayedTrendDirection == "up"
                        ? "Trending Up" : displayedTrendDirection == "down" ? "Trending Down" : "Stable"
                )
                .font(.custom("Raleway-Medium", size: 13))
            }
            .foregroundColor(displayedTrendDirection == "up" ? DesignColors.accentWarm : DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppLayout.spacingM)
    }

    // MARK: - Wellness Pillars Grid

    @ViewBuilder
    private var wellnessPillarsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WELLNESS")
                .font(.custom("Raleway-Regular", size: 13))
                .foregroundColor(DesignColors.textSecondary.opacity(0.7))
                .tracking(3)

            LazyVGrid(columns: [.init(), .init()], spacing: 12) {
                ForEach(pillars) { pillar in
                    WellnessPillarCard(
                        name: pillar.name,
                        score: pillar.score,
                        icon: pillar.icon,
                        trend: pillar.trend
                    )
                }
            }
        }
    }

    // MARK: - Insights

    @ViewBuilder
    private func insightsSection(_ insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSIGHTS")
                .font(.custom("Raleway-Regular", size: 13))
                .foregroundColor(DesignColors.textSecondary.opacity(0.7))
                .tracking(3)

            ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                InsightCard(text: insight)
            }
        }
    }
}

// MARK: - Fertile Window Banner

private struct FertileWindowBanner: View {
    let cycle: CycleContext

    private var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private var todayLevel: FertilityLevel? { cycle.fertileDays[todayKey] }
    private var isOvulationToday: Bool { cycle.ovulationDays.contains(todayKey) }

    var body: some View {
        HStack(spacing: 14) {
            // Fertility icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(accentColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Raleway-SemiBold", size: 15))
                    .foregroundColor(DesignColors.text)
                Text(subtitle)
                    .font(.custom("Raleway-Regular", size: 12))
                    .foregroundColor(DesignColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Level badge
            if let level = todayLevel {
                VStack(spacing: 2) {
                    Text(level.probability)
                        .font(.custom("Raleway-Bold", size: 14))
                        .foregroundColor(level.color)
                    Text(level.displayName)
                        .font(.custom("Raleway-Medium", size: 9))
                        .foregroundColor(level.color.opacity(0.8))
                }
            } else if let days = cycle.daysUntilOvulation, days > 0 {
                VStack(spacing: 2) {
                    Text("\(days)")
                        .font(.custom("Raleway-Bold", size: 18))
                        .foregroundColor(CyclePhase.ovulatory.orbitColor)
                    Text("days")
                        .font(.custom("Raleway-Medium", size: 9))
                        .foregroundColor(CyclePhase.ovulatory.orbitColor.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(accentColor.opacity(0.15), lineWidth: 0.5)
                }
        }
    }

    private var accentColor: Color {
        if isOvulationToday { return CyclePhase.ovulatory.orbitColor }
        return todayLevel?.color ?? CyclePhase.ovulatory.orbitColor.opacity(0.7)
    }

    private var iconName: String {
        if isOvulationToday { return "sparkle" }
        if cycle.fertileWindowActive { return "leaf.fill" }
        return "calendar.badge.clock"
    }

    private var title: String {
        if isOvulationToday { return "Ovulation Day" }
        if cycle.fertileWindowActive {
            if let level = todayLevel {
                return "Fertile Window · \(level.displayName)"
            }
            return "Fertile Window Active"
        }
        if let days = cycle.daysUntilOvulation, days > 0 {
            return "Ovulation in \(days) days"
        }
        return "Fertile Window"
    }

    private var subtitle: String {
        if isOvulationToday {
            return "Peak fertility today. The egg is viable for 12-24 hours."
        }
        if cycle.fertileWindowActive {
            if let days = cycle.daysUntilOvulation, days > 0 {
                return "Ovulation expected in \(days) days. Sperm can survive up to 5 days."
            }
            return "You're in your fertile window. Conception is possible."
        }
        if let days = cycle.daysUntilOvulation, days > 0 {
            return "Your fertile window is approaching."
        }
        return "Track your cycle for fertility predictions."
    }
}
