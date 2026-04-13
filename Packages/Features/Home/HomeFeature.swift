import ComposableArchitecture
import Inject
import RiveRuntime
import SwiftData
import SwiftUI


// MARK: - Home Feature

@Reducer
public struct HomeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var user: User?
        public var isLoading: Bool
        public var selectedTab: Tab
        public var hasAppeared: Bool = false

        // Child features
        public var todayState: TodayFeature.State = TodayFeature.State()
        public var chatState: ChatFeature.State = ChatFeature.State()
        public var profileState: ProfileFeature.State = ProfileFeature.State()
        public var cycleInsightsState: CycleInsightsFeature.State = CycleInsightsFeature.State()
        public var isCycleInsightsVisible: Bool = false
        public var cycleJourneyState: CycleJourneyFeature.State = CycleJourneyFeature.State()
        public var isCycleJourneyVisible: Bool = false
        public var shouldReopenJourney: Bool = false

        public enum Tab: Int, Equatable, Sendable, CaseIterable {
            case today = 0
            case chat = 1
            case me = 2

            var title: String {
                switch self {
                case .today: "Today"
                case .chat: "Aria"
                case .me: "Me"
                }
            }

            var icon: String {
                switch self {
                case .today: "sun.horizon"
                case .chat: "bubble.left.and.text.bubble.right"
                case .me: "person"
                }
            }

            var selectedIcon: String {
                switch self {
                case .today: "sun.horizon.fill"
                case .chat: "bubble.left.and.text.bubble.right.fill"
                case .me: "person.fill"
                }
            }
        }

        public init(
            user: User? = nil,
            isLoading: Bool = false,
            selectedTab: Tab = .today
        ) {
            self.user = user
            self.isLoading = isLoading
            self.selectedTab = selectedTab
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case loadUser
        case userLoaded(Result<User, Error>)
        case logoutTapped
        case logoutCompleted

        // Child features
        case today(TodayFeature.Action)
        case chat(ChatFeature.Action)
        case profile(ProfileFeature.Action)
        case cycleInsights(CycleInsightsFeature.Action)
        case cycleJourney(CycleJourneyFeature.Action)


        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didLogout
        }
    }

    @Dependency(\.userProfileLocal) var userProfileLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.todayState, action: \.today) {
            TodayFeature()
        }

        Scope(state: \.chatState, action: \.chat) {
            ChatFeature()
        }

        Scope(state: \.profileState, action: \.profile) {
            ProfileFeature()
        }

        Scope(state: \.cycleInsightsState, action: \.cycleInsights) {
            CycleInsightsFeature()
        }

        Scope(state: \.cycleJourneyState, action: \.cycleJourney) {
            CycleJourneyFeature()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                guard !state.hasAppeared else { return .none }
                state.hasAppeared = true
                return .merge(
                    .send(.loadUser),
                    .send(.today(.loadDashboard))
                )

            case .loadUser:
                state.isLoading = true
                return .run { [userProfileLocal] send in
                    let profile = try? await userProfileLocal.getProfile()
                    if let profile {
                        let user = User(
                            id: .init("local"),
                            email: "",
                            firstName: profile.userName,
                            lastName: nil,
                            avatarURL: nil,
                            createdAt: profile.createdAt,
                            updatedAt: profile.createdAt
                        )
                        await send(.userLoaded(.success(user)))
                    } else {
                        await send(.userLoaded(.failure(NSError(domain: "local", code: 0))))
                    }
                }

            case .userLoaded(.success(let user)):
                state.isLoading = false
                state.user = user
                state.profileState.user = user
                // Retry if parallel load failed (token wasn't ready post-registration)
                if state.todayState.menstrualStatus == nil, !state.todayState.isLoadingMenstrual {
                    return .send(.today(.loadDashboard))
                }
                return .none

            case .userLoaded(.failure):
                state.isLoading = false
                if state.todayState.menstrualStatus == nil, !state.todayState.isLoadingMenstrual {
                    return .send(.today(.loadDashboard))
                }
                return .none

            case .logoutTapped:
                return .run { send in
                    // Clear all local health data
                    let container = CycleDataStore.shared
                    let context = ModelContext(container)
                    try? context.delete(model: UserProfileRecord.self)
                    try? context.delete(model: MenstrualProfileRecord.self)
                    try? context.delete(model: CycleRecord.self)
                    try? context.delete(model: SymptomRecord.self)
                    try? context.delete(model: PredictionRecord.self)
                    try? context.delete(model: SelfReportRecord.self)
                    try? context.delete(model: HBIScoreRecord.self)
                    try? context.delete(model: ChatMessageRecord.self)
                    try? context.delete(model: DailyCardRecord.self)
                    try? context.delete(model: CycleRecapRecord.self)
                    try? context.delete(model: WellnessMessageRecord.self)
                    try? context.delete(model: ChallengeRecord.self)
                    try? context.delete(model: GlowProfileRecord.self)
                    try? context.save()
                    // Clear chat session
                    UserDefaults.standard.removeObject(forKey: "cycle.chat.sessionID")
                    await send(.logoutCompleted)
                }

            case .logoutCompleted:
                return .send(.delegate(.didLogout))

            case .today(.delegate(.openAriaChat)):
                state.selectedTab = .chat
                return .none

            case .today(.delegate(.openCycleInsights)):
                // Hydrate insights state with already-loaded data for instant render
                state.cycleInsightsState.cycleContext = state.todayState.cycle
                state.cycleInsightsState.menstrualStatus = state.todayState.menstrualStatus
                state.cycleInsightsState.hbiDashboard = state.todayState.dashboard
                state.isCycleInsightsVisible = true
                return .none

            case .cycleInsights(.delegate(.dismiss)):
                // Cache stats for entry card sparkline on Today tab
                state.todayState.cachedCycleStats = state.cycleInsightsState.stats
                state.isCycleInsightsVisible = false
                return .none

            case .today(.delegate(.openCycleJourney)):
                state.cycleJourneyState = CycleJourneyFeature.State()
                state.cycleJourneyState.cycleContext = state.todayState.cycle
                state.cycleJourneyState.menstrualStatus = state.todayState.menstrualStatus
                // Highlight the recap card if coming from recap notification
                state.cycleJourneyState.highlightRecapCycle = state.todayState.recapBannerMonth != nil
                state.isCycleJourneyVisible = true
                state.todayState.recapBannerMonth = nil
                return .none

            case .cycleJourney(.delegate(.dismiss)):
                state.isCycleJourneyVisible = false
                return .send(.today(.refreshRecapBanner))

            case .cycleJourney(.delegate(.logMissedMonth(let month))):
                // Close journey → open calendar on target month → reopen journey when calendar closes
                state.isCycleJourneyVisible = false
                state.shouldReopenJourney = true
                state.todayState.calendarState.displayedMonth = month
                state.todayState.isCalendarVisible = true
                return .none

            // When calendar closes after logging from journey, reopen journey
            case .today(.calendar(.delegate(.didDismiss))),
                 .today(.calendarDismissed):
                if state.shouldReopenJourney {
                    state.shouldReopenJourney = false
                    return .send(.today(.delegate(.openCycleJourney)))
                }
                return .none

            case .today(.menstrualStatusLoaded(.success(let status))):
                state.profileState.menstrualStatus = status
                state.cycleInsightsState.menstrualStatus = status
                return .none

            case .today(.dashboardLoaded(.success(let dashboard))):
                state.profileState.hbiDashboard = dashboard
                state.cycleInsightsState.hbiDashboard = dashboard
                return .none

            case .profile(.delegate(.didLogout)):
                return .send(.logoutTapped)

            case .today, .chat, .profile, .cycleInsights, .cycleJourney, .delegate:
                return .none
            }
        }
    }
}

// MARK: - Home View

public struct HomeView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<HomeFeature>
    @State private var safeAreaTop: CGFloat = 0

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { rootGeo in
        ZStack {
            GradientBackground()
                .ignoresSafeArea()

            TabView(selection: $store.selectedTab) {
                // Today Tab
                TodayView(
                    store: store.scope(state: \.todayState, action: \.today)
                )
                .tabItem {
                    Label(
                        HomeFeature.State.Tab.today.title,
                        systemImage: store.selectedTab == .today
                            ? HomeFeature.State.Tab.today.selectedIcon
                            : HomeFeature.State.Tab.today.icon
                    )
                }
                .tag(HomeFeature.State.Tab.today)

                // Chat Tab (Aria)
                ChatView(store: store.scope(state: \.chatState, action: \.chat))
                    .tabItem {
                        Label(
                            HomeFeature.State.Tab.chat.title,
                            systemImage: store.selectedTab == .chat
                                ? HomeFeature.State.Tab.chat.selectedIcon
                                : HomeFeature.State.Tab.chat.icon
                        )
                    }
                    .tag(HomeFeature.State.Tab.chat)

                // Me Tab
                NavigationStack {
                    ProfileView(
                        store: store.scope(state: \.profileState, action: \.profile)
                    )
                }
                .tabItem {
                    Label(
                        HomeFeature.State.Tab.me.title,
                        systemImage: store.selectedTab == .me
                            ? HomeFeature.State.Tab.me.selectedIcon
                            : HomeFeature.State.Tab.me.icon
                    )
                }
                .tag(HomeFeature.State.Tab.me)
            }
            .tint(DesignColors.accentWarm)

            if store.todayState.isCalendarVisible {
                ZStack {
                    Color.white.ignoresSafeArea()
                    CalendarView(
                        store: store.scope(
                            state: \.todayState.calendarState,
                            action: \.today.calendar
                        )
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(1)
            }

        }
        .animation(.easeInOut(duration: 0.25), value: store.todayState.isCalendarVisible)
        .fullScreenCover(isPresented: Binding(
            get: { store.isCycleInsightsVisible },
            set: { if !$0 { store.send(.cycleInsights(.delegate(.dismiss))) } }
        )) {
            CycleInsightsView(
                store: store.scope(
                    state: \.cycleInsightsState,
                    action: \.cycleInsights
                )
            )
            .background(DesignColors.background.ignoresSafeArea())
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.isCycleJourneyVisible },
            set: { if !$0 { store.send(.cycleJourney(.delegate(.dismiss))) } }
        )) {
            CycleJourneyView(
                store: store.scope(
                    state: \.cycleJourneyState,
                    action: \.cycleJourney
                )
            )
            .background(DesignColors.background.ignoresSafeArea())
        }
        .onAppear { safeAreaTop = rootGeo.safeAreaInsets.top }
        .task {
            store.send(.onAppear)
        }
        .enableInjection()
        } // GeometryReader
    }


}


// MARK: - Preview


#Preview {
    HomeView(
        store: .init(initialState: HomeFeature.State(user: .mock)) {
            HomeFeature()
        }
    )
}
