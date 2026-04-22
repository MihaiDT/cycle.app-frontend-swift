import ComposableArchitecture
import RiveRuntime
import SwiftData
import SwiftUI


// MARK: - Home Feature

@Reducer
public struct HomeFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
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

        /// Deep-link path for Home's "Latest Story" tile. We load Journey
        /// data silently, then present `AriaRecapStories` directly as a
        /// cover on Home — skipping the Journey screen entirely so the
        /// user never sees the list flash behind the recap.
        public var isWaitingForLatestRecap: Bool = false
        public var isLatestRecapDirectVisible: Bool = false

        public enum Tab: Int, Equatable, Sendable, CaseIterable {
            case today = 0
            case chat = 1
            case toDo = 2
            case me = 3

            var title: String {
                switch self {
                case .today: "Today"
                case .chat: "Aria"
                case .toDo: "To Do"
                case .me: "Me"
                }
            }

            var icon: String {
                switch self {
                case .today: "sun.horizon"
                case .chat: "bubble.left.and.text.bubble.right"
                case .toDo: "checklist"
                case .me: "person"
                }
            }

            var selectedIcon: String {
                switch self {
                case .today: "sun.horizon.fill"
                case .chat: "bubble.left.and.text.bubble.right.fill"
                case .toDo: "checklist.checked"
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
        /// Fired after the direct-recap cover finishes its dismiss
        /// animation — clears the preserved recap state so memory
        /// doesn't leak and the flag resets for the next deep-link.
        case clearDirectRecapState

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
                state.isCycleInsightsVisible = true
                return .none

            case .today(.delegate(.openCycleStats)):
                // Journey widget → Cycle Stats tile. Same destination as
                // openCycleInsights but entered via the Journey page so
                // we reset to the top-level view (no auto-open detail).
                state.cycleInsightsState.cycleContext = state.todayState.cycle
                state.cycleInsightsState.pendingInitialDetail = nil
                state.isCycleInsightsVisible = true
                return .none

            case .today(.delegate(.openBodyPatterns)):
                // Journey widget → Body Patterns tile. Opens CycleInsights
                // and auto-presents the Body detail section on appear.
                state.cycleInsightsState.cycleContext = state.todayState.cycle
                state.cycleInsightsState.pendingInitialDetail = .body
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

            case .today(.delegate(.openLatestRecap)):
                // Deep-link directly to the latest cycle's recap.
                // Load Journey data silently in the background (without
                // presenting the Journey cover), then present the recap
                // as a fullScreenCover on Home when it's ready. This
                // avoids the double-animation (Journey slide-up + recap
                // slide-up) the user was seeing.
                state.cycleJourneyState = CycleJourneyFeature.State()
                state.cycleJourneyState.cycleContext = state.todayState.cycle
                state.cycleJourneyState.menstrualStatus = state.todayState.menstrualStatus
                state.cycleJourneyState.autoOpenLatestRecap = true
                state.cycleJourneyState.directRecapMode = true
                state.isWaitingForLatestRecap = true
                return .send(.cycleJourney(.onAppear))

            case .cycleJourney(.cycleRecapTapped(_)):
                // When we're waiting on the deep-link, the child's own
                // `autoOpenLatestRecap` logic will fire this action right
                // after Journey data loads. Child state already holds a
                // `recap` at this point — present the cover directly.
                if state.isWaitingForLatestRecap {
                    state.isWaitingForLatestRecap = false
                    state.isLatestRecapDirectVisible = true
                }
                return .none

            case .cycleJourney(.recapDismissed):
                // Direct-path: child reducer intentionally keeps
                // `state.recap` populated so the dismiss animation still
                // has the recap UI to render. We hide the cover here,
                // then clear state after the slide-down completes.
                if state.isLatestRecapDirectVisible {
                    state.isLatestRecapDirectVisible = false
                    return .run { send in
                        try? await Task.sleep(for: .milliseconds(450))
                        await send(.clearDirectRecapState)
                    }
                }
                return .none

            case .clearDirectRecapState:
                state.cycleJourneyState.recap = nil
                state.cycleJourneyState.directRecapMode = false
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
                return .none

            case .today(.dashboardLoaded(.success(let dashboard))):
                state.profileState.hbiDashboard = dashboard
                return .none

            // Fan out cycle-data broadcast from TodayFeature (the data owner)
            // to sibling features so they refresh without requiring a tab/sheet
            // re-entry. Fires after menstrualStatusLoaded and calendarEntriesLoaded.
            case .today(.delegate(.cycleDataUpdated(let cycle))):
                return .merge(
                    .send(.cycleInsights(.cycleDataChanged(cycle))),
                    .send(.cycleJourney(.cycleDataChanged(cycle)))
                )

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
    @Bindable var store: StoreOf<HomeFeature>
    @State private var safeAreaTop: CGFloat = 0
    /// Local mirror of `isCalendarVisible` — the parallax offset
    /// animation is driven from this instead of the store so SwiftUI's
    /// animation transaction doesn't cascade into Today's ScrollView
    /// and cause widgets to briefly shift down-then-back when the
    /// calendar dismisses.
    @State private var isCalendarOpen: Bool = false

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

                // To Do Tab
                ToDoView()
                    .tabItem {
                        Label(
                            HomeFeature.State.Tab.toDo.title,
                            systemImage: store.selectedTab == .toDo
                                ? HomeFeature.State.Tab.toDo.selectedIcon
                                : HomeFeature.State.Tab.toDo.icon
                        )
                    }
                    .tag(HomeFeature.State.Tab.toDo)

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
            // Parallax driven from a LOCAL state mirror + scoped
            // `.animation(_, value:)` — animates ONLY offset/overlay
            // on this view. The pre-existing Rhythm-widget bounce on
            // calendar dismiss is unrelated to this transform (it
            // happened before the parallax was introduced).
            .compositingGroup()
            .offset(x: isCalendarOpen ? -rootGeo.size.width * 0.22 : 0)
            .overlay(
                Color.black
                    .opacity(isCalendarOpen ? 0.22 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .animation(.easeInOut(duration: 0.32), value: isCalendarOpen)

            // Calendar overlay — animation is scoped to this inner
            // ZStack only so the `.transition` of the calendar doesn't
            // emit a transaction that bleeds back into the parent's
            // sibling views (previously animated Today's hero height
            // while the overlay was sliding off, causing the Rhythm
            // widgets to drift back up at the tail of dismiss).
            ZStack {
                if isCalendarOpen {
                    ZStack {
                        Color.white.ignoresSafeArea()
                        CalendarView(
                            store: store.scope(
                                state: \.todayState.calendarState,
                                action: \.today.calendar
                            )
                        )
                    }
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.32), value: isCalendarOpen)
            .zIndex(1)

            // Initial profile bootstrap — subtle non-blocking top indicator.
            // Tabs stay interactive; hero already has its own skeleton state.
            ZStack {
                if store.isLoading && store.user == nil {
                    VStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .tint(DesignColors.accentWarm)
                            .padding(.top, 8)
                            .accessibilityLabel("Loading your profile")
                            .accessibilityAddTraits(.updatesFrequently)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.isLoading)
            .zIndex(2)
        }
        .onChange(of: store.todayState.isCalendarVisible) { _, newValue in
            // Raw assignment — no `withAnimation` here. The animation
            // is on the `.animation(_, value: isCalendarOpen)` modifier
            // scoped to just the TabView's offset/overlay, so the
            // transaction can't leak into sibling views.
            isCalendarOpen = newValue
        }
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
        // Direct-recap deep-link from Home's Latest Story tile. Shows
        // the recap immediately over Home (single slide-up animation)
        // instead of going Home → Journey → Recap (double animation).
        .fullScreenCover(isPresented: Binding(
            get: { store.isLatestRecapDirectVisible },
            set: { if !$0 { store.send(.cycleJourney(.recapDismissed)) } }
        )) {
            // ZStack with a warm backdrop under AriaRecapStories: when
            // the close button clears `state.recap`, the recap view
            // renders empty — this backdrop keeps the cover solid during
            // the slide-down animation instead of flashing white.
            ZStack {
                DesignColors.background.ignoresSafeArea()
                AriaRecapStories(
                    store: store.scope(
                        state: \.cycleJourneyState,
                        action: \.cycleJourney
                    )
                )
            }
        }
        .onAppear { safeAreaTop = rootGeo.safeAreaInsets.top }
        .task {
            store.send(.onAppear)
        }
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
