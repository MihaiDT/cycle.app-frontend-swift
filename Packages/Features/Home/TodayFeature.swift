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
        case checkIn(PresentationAction<DailyCheckInFeature.Action>)
        case triggerScoreAnimation
        case scoreAnimationTick(Double)
        case refreshTapped
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
                        guard let token = try? await sessionClient.getAccessToken() else { return }
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
                    guard let token = try? await sessionClient.getAccessToken() else { return }
                    let result = await Result {
                        try await menstrualClient.getStatus(token)
                    }
                    await send(.menstrualStatusLoaded(result))
                }

            case .menstrualStatusLoaded(.success(let status)):
                state.isLoadingMenstrual = false
                state.menstrualStatus = status
                return .none

            case .menstrualStatusLoaded(.failure):
                state.isLoadingMenstrual = false
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

            case .checkIn(.presented(.delegate(.didCompleteCheckIn(_)))):
                return .send(.loadDashboard)

            case .checkIn:
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

            case .binding:
                return .none
            }
        }
        .ifLet(\.$checkIn, action: \.checkIn) {
            DailyCheckInFeature()
        }
    }
}

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

// MARK: - Today View

public struct TodayView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<TodayFeature>

    @State private var showHeader = false
    @State private var showCelestial = false
    @State private var scrollOffset: CGFloat = 0
    @State private var celestialBottomY: CGFloat = 1000
    @State private var showCheckIn = false
    @State private var showScore = false
    @State private var showPillars = false
    @State private var showInsights = false

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
                WellnessPillar(name: "Energy", score: 72, icon: "bolt.fill", trend: "up"),
                WellnessPillar(name: "Mood", score: 85, icon: "face.smiling.fill", trend: "up"),
                WellnessPillar(name: "Sleep", score: 65, icon: "moon.fill", trend: "stable"),
                WellnessPillar(name: "Calm", score: 78, icon: "leaf.fill", trend: "up"),
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
        store.dashboard?.today?.hbiAdjusted ?? 78
    }

    private var displayedTrendDirection: String {
        store.trendDirection ?? "up"
    }

    private var displayedInsights: [String] {
        if let insights = store.dashboard?.insights, !insights.isEmpty {
            return insights
        }
        return [
            "Your wellness is trending up this week!",
            "Connect HealthKit for more accurate scores.",
        ]
    }

    /// How far the circle has collapsed (0 = fully visible, 1 = fully collapsed)
    private var collapseProgress: CGFloat {
        let threshold: CGFloat = 350
        let fullyCollapsed: CGFloat = 120
        let maxY = celestialBottomY
        guard maxY < threshold else { return 0 }
        guard maxY > fullyCollapsed else { return 1 }
        return 1 - (maxY - fullyCollapsed) / (threshold - fullyCollapsed)
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppLayout.spacingL) {
                // MARK: Header
                todayHeader
                    .opacity(showHeader ? 1 : 0)
                    .offset(y: showHeader ? 0 : 12)

                // MARK: Celestial Cycle (morphs circle → bar on scroll)
                celestialCycleSection
                    .opacity(showCelestial ? 1 : 0)
                    .offset(y: showCelestial ? 0 : 20)
                    .scaleEffect(showCelestial ? 1 : 0.95)
                    .overlay {
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.frame(in: .global).maxY) { _, newValue in
                                    celestialBottomY = newValue
                                }
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
        .refreshable {
            store.send(.refreshTapped)
        }
        .sheet(item: $store.scope(state: \.checkIn, action: \.checkIn)) { checkInStore in
            DailyCheckInView(store: checkInStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppLayout.cornerRadiusL)
        }
        .onChange(of: store.hasAppeared) { _, appeared in
            guard appeared else { return }
            triggerStaggeredAnimations()
        }
        .enableInjection()
    }

    // MARK: - Staggered Animations

    private func triggerStaggeredAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showHeader = true
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.12)) {
            showCelestial = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.30)) {
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
        VStack(spacing: 4) {
            Text(greeting)
                .font(.custom("Raleway-Bold", size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignColors.text, DesignColors.textPrincipal, DesignColors.accentWarm],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(dateString)
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundColor(DesignColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Celestial Cycle

    private var celestialCycleSection: some View {
        let status = store.menstrualStatus
        let cycleDay = status?.currentCycle.cycleDay ?? 8
        let cycleLength = status?.profile.avgCycleLength ?? 28
        let phase = status?.currentCycle.phase ?? "follicular"
        let nextPeriodIn = status?.nextPrediction?.daysUntil
        let fertileWindowActive = status?.fertileWindow?.isActive ?? false

        return CelestialCycleView(
            cycleDay: cycleDay,
            cycleLength: cycleLength,
            phase: phase,
            nextPeriodIn: nextPeriodIn,
            fertileWindowActive: fertileWindowActive,
            collapseProgress: collapseProgress
        )
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
