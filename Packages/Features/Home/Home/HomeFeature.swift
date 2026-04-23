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
    @Dependency(\.menstrualLocal) var menstrualLocal

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
                    .send(.today(.loadDashboard)),
                    // Silent one-shot repair of any overlapping /
                    // duplicate cycle records left behind by older
                    // edit paths. Runs once per session, off the
                    // main actor, transparent to the user. Cheap
                    // when the DB is already clean.
                    .run { [menstrualLocal] _ in
                        try? await menstrualLocal.cleanupDuplicateCycles()
                    }
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
                state.cycleInsightsState.cycleContext = state.todayState.cycle
                state.isCycleInsightsVisible = true
                return .send(.cycleInsights(.onAppear))

            case .today(.delegate(.openCycleStats)):
                // Journey widget → Cycle Stats tile. Same destination as
                // openCycleInsights but entered via the Journey page so
                // we reset to the top-level view (no auto-open detail).
                state.cycleInsightsState.cycleContext = state.todayState.cycle
                state.cycleInsightsState.pendingInitialDetail = nil
                state.isCycleInsightsVisible = true
                return .send(.cycleInsights(.onAppear))

            case .today(.delegate(.openBodyPatterns)):
                // Journey widget → Body Patterns tile. Opens CycleInsights
                // and auto-presents the Body detail section on appear.
                state.cycleInsightsState.cycleContext = state.todayState.cycle
                state.cycleInsightsState.pendingInitialDetail = .body
                state.isCycleInsightsVisible = true
                return .send(.cycleInsights(.onAppear))

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
