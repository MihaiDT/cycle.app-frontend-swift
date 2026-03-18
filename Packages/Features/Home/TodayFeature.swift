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

        @Presents var checkIn: DailyCheckInFeature.State?
        @Presents var calendar: CalendarFeature.State?
        @Presents var editPeriod: EditPeriodFeature.State?

        public var hasAppeared: Bool = false
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

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case loadDashboard
        case dashboardLoaded(Result<HBIDashboardResponse, Error>)
        case loadMenstrualStatus
        case menstrualStatusLoaded(Result<MenstrualStatusResponse, Error>)
        case checkInTapped
        case calendarTapped
        case logPeriodTapped
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
                return .run { send in
                    guard let token = try? await sessionClient.getAccessToken() else {
                        await send(.menstrualStatusLoaded(.failure(MenstrualError.noToken)))
                        return
                    }
                    let result = await Result {
                        try await menstrualClient.getStatus(token)
                    }
                    await send(.menstrualStatusLoaded(result))
                }

            case .menstrualStatusLoaded(.success(let status)):
                state.isLoadingMenstrual = false
                state.menstrualStatus = status
                print("✅ Menstrual status loaded: day \(status.currentCycle.cycleDay), phase \(status.currentCycle.phase)")
                return .none

            case .menstrualStatusLoaded(.failure(let error)):
                state.isLoadingMenstrual = false
                state.dashboardError = "Menstrual: \(error)"
                print("❌ Menstrual status FAILED: \(error)")
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
                print("❌ Dashboard FAILED: \(error)")
                return .none

            case .checkInTapped:
                state.checkIn = DailyCheckInFeature.State()
                return .none

            case .calendarTapped:
                state.calendar = CalendarFeature.State(menstrualStatus: state.menstrualStatus)
                return .send(.calendar(.presented(.loadCalendar)))

            case .logPeriodTapped:
                guard let status = state.menstrualStatus else {
                    // Don't open log period until data is loaded
                    return .send(.loadDashboard)
                }
                let cal = Calendar.current
                let startDate = cal.startOfDay(for: status.currentCycle.startDate)
                let cycleLength = status.profile.avgCycleLength
                let bleedingDays = status.currentCycle.bleedingDays

                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                var days: Set<String> = []
                for i in 0..<bleedingDays {
                    if let d = cal.date(byAdding: .day, value: i, to: startDate) {
                        days.insert(fmt.string(from: d))
                    }
                }

                state.editPeriod = EditPeriodFeature.State(
                    cycleStartDate: startDate,
                    cycleLength: cycleLength,
                    bleedingDays: bleedingDays,
                    periodDays: days,
                    periodFlowIntensity: [:]
                )
                return .none

            case .checkIn(.presented(.delegate(.didCompleteCheckIn(_)))):
                return .send(.loadDashboard)

            case .checkIn:
                return .none

            case .calendar(.presented(.delegate(.didDismiss(let periodDays)))):
                // Update menstrualStatus locally from calendar period edits
                if let existing = state.menstrualStatus, !periodDays.isEmpty {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "yyyy-MM-dd"
                    let sortedDays = periodDays.sorted()
                    if let startStr = sortedDays.first,
                       let newStart = fmt.date(from: startStr) {
                        let cal = Calendar.current
                        let today = cal.startOfDay(for: Date())
                        let newCycleDay = max(1, cal.dateComponents([.day], from: newStart, to: today).day! + 1)
                        let newCycle = CycleInfo(
                            startDate: newStart,
                            cycleDay: newCycleDay,
                            phase: existing.currentCycle.phase,
                            bleedingDays: periodDays.count
                        )
                        state.menstrualStatus = MenstrualStatusResponse(
                            currentCycle: newCycle,
                            profile: existing.profile,
                            nextPrediction: existing.nextPrediction,
                            fertileWindow: existing.fertileWindow
                        )
                    }
                }
                return .none

            case .calendar(.presented(.delegate(.openAriaChat(let context)))):
                state.calendar = nil
                return .send(.delegate(.openAriaChat(context: context)))

            case .calendar(.dismiss):
                return .send(.loadDashboard)

            case .calendar:
                return .none

            case .editPeriod(.presented(.delegate(let delegate))):
                if case .didSave(let periodDays, _) = delegate {
                    // Update menstrualStatus locally so circle + calendar refresh immediately
                    if let existing = state.menstrualStatus, !periodDays.isEmpty {
                        let fmt = DateFormatter()
                        fmt.dateFormat = "yyyy-MM-dd"
                        let sortedDays = periodDays.sorted()
                        if let startStr = sortedDays.first,
                           let newStart = fmt.date(from: startStr) {
                            let cal = Calendar.current
                            let today = cal.startOfDay(for: Date())
                            let newCycleDay = max(1, cal.dateComponents([.day], from: newStart, to: today).day! + 1)
                            let bleedingDays = periodDays.count

                            let newCycle = CycleInfo(
                                startDate: newStart,
                                cycleDay: newCycleDay,
                                phase: existing.currentCycle.phase,
                                bleedingDays: bleedingDays
                            )
                            state.menstrualStatus = MenstrualStatusResponse(
                                currentCycle: newCycle,
                                profile: existing.profile,
                                nextPrediction: existing.nextPrediction,
                                fertileWindow: existing.fertileWindow
                            )
                        }
                    }
                }
                state.editPeriod = nil
                return .send(.loadDashboard)

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
    @State private var exploringDay: Int?

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
        if let status = store.menstrualStatus {
            let cycleDay = status.currentCycle.cycleDay
            let cycleLength = status.profile.avgCycleLength
            let bleedingDays = status.currentCycle.bleedingDays
            let cycleStartDate = Calendar.current.startOfDay(for: status.currentCycle.startDate)
            let predictedStart: Date? = status.nextPrediction?.predictedDate
                ?? Calendar.current.date(byAdding: .day, value: cycleLength, to: cycleStartDate)

            GlassWeekCalendar(
                cycleDay: cycleDay,
                cycleLength: cycleLength,
                cycleStartDate: cycleStartDate,
                bleedingDays: bleedingDays,
                predictedPeriodStart: predictedStart,
                selectedDay: $exploringDay,
                isCompact: calendarIsCompact
            )
        } else {
            Color.clear
        }
    }

    // MARK: - Celestial Cycle

    @ViewBuilder
    private var celestialCycleSection: some View {
        if let status = store.menstrualStatus {
            CelestialCycleView(
                cycleDay: status.currentCycle.cycleDay,
                cycleLength: status.profile.avgCycleLength,
                phase: status.currentCycle.phase,
                nextPeriodIn: status.nextPrediction?.daysUntil,
                fertileWindowActive: status.fertileWindow?.isActive ?? false,
                collapseProgress: collapseProgress,
                exploringDay: $exploringDay,
                onLogPeriod: { store.send(.logPeriodTapped) }
            )
        } else {
            CelestialCycleView(
                cycleDay: 1,
                cycleLength: 28,
                phase: "follicular",
                nextPeriodIn: nil,
                fertileWindowActive: false,
                collapseProgress: collapseProgress,
                exploringDay: .constant(nil)
            )
            .redacted(reason: store.isLoadingMenstrual ? .placeholder : [])
        }
    }

    // MARK: - Collapsed Cycle Info

    @ViewBuilder
    private var collapsedCycleInfo: some View {
        let phaseStr = store.menstrualStatus?.currentCycle.phase ?? "follicular"
        let phase = CyclePhase(rawValue: phaseStr) ?? .follicular
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
