import ComposableArchitecture
import Inject
import RiveRuntime
import SwiftUI


// MARK: - Home Feature

@Reducer
public struct HomeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var user: User?
        public var isLoading: Bool
        public var selectedTab: Tab

        // Child features
        public var todayState: TodayFeature.State = TodayFeature.State()
        public var profileState: ProfileFeature.State = ProfileFeature.State()
        public var cycleInsightsState: CycleInsightsFeature.State = CycleInsightsFeature.State()
        public var isCycleInsightsVisible: Bool = false

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
        case profile(ProfileFeature.Action)
        case cycleInsights(CycleInsightsFeature.Action)


        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didLogout
        }
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.sessionClient) var sessionClient
    @Dependency(\.firebaseAuthClient) var firebaseAuth

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.todayState, action: \.today) {
            TodayFeature()
        }

        Scope(state: \.profileState, action: \.profile) {
            ProfileFeature()
        }

        Scope(state: \.cycleInsightsState, action: \.cycleInsights) {
            CycleInsightsFeature()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .merge(
                    .send(.loadUser),
                    .send(.today(.loadDashboard))
                )

            case .loadUser:
                state.isLoading = true
                return .run { send in
                    // Retry token fetch — Firebase may not have it ready immediately after registration
                    var token: String?
                    for _ in 0..<3 {
                        token = await sessionClient.getAccessToken()
                        if token != nil { break }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    guard let token else {
                        await send(.delegate(.didLogout))
                        return
                    }
                    let endpoint = UserEndpoints.me().authenticated(with: token)
                    let result = await Result {
                        try await apiClient.send(endpoint) as User
                    }
                    await send(.userLoaded(result))
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
                return .run { [firebaseAuth, sessionClient] send in
                    try? await firebaseAuth.signOut()
                    try? await sessionClient.clearSession()
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

            case .today, .profile, .cycleInsights, .delegate:
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
                chatTabView
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
                    DesignColors.background.ignoresSafeArea()
                    CalendarView(
                        store: store.scope(
                            state: \.todayState.calendarState,
                            action: \.today.calendar
                        )
                    )
                }
                .transition(.move(edge: .trailing))
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
        .onAppear { safeAreaTop = rootGeo.safeAreaInsets.top }
        .task {
            store.send(.onAppear)
        }
        .enableInjection()
        } // GeometryReader
    }

    // MARK: - Chat Tab (Placeholder)

    private var chatTabView: some View {
        VStack(spacing: 0) {
            Spacer()

            RiveViewModel(fileName: "glowing_orb", stateMachineName: "State Machine 1")
                .view()
                .frame(width: 200, height: 200)

            VStack(spacing: 8) {
                Text("Aria")
                    .font(.custom("Raleway-Bold", size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignColors.text, DesignColors.accentWarm],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Your AI wellness companion")
                    .font(.custom("Raleway-Regular", size: 15))
                    .foregroundColor(DesignColors.textSecondary)

                Text("Coming Soon")
                    .font(.custom("Raleway-Medium", size: 13))
                    .foregroundColor(DesignColors.textPlaceholder)
                    .padding(.top, 4)
            }
            .padding(.top, AppLayout.spacingL)

            Spacer()
        }
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
