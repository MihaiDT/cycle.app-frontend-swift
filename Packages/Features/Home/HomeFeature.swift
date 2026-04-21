import ComposableArchitecture
import Inject
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
        public var bondsState: BondsFeature.State = BondsFeature.State()
        public var profileState: ProfileFeature.State = ProfileFeature.State()
        public var cycleInsightsState: CycleInsightsFeature.State = CycleInsightsFeature.State()
        public var isCycleInsightsVisible: Bool = false
        public var cycleJourneyState: CycleJourneyFeature.State = CycleJourneyFeature.State()
        public var isCycleJourneyVisible: Bool = false
        public var shouldReopenJourney: Bool = false
        public var isSettingsVisible: Bool = false

        public enum Tab: Int, Equatable, Sendable, CaseIterable {
            case today = 0
            case chat = 1
            case bonds = 2
            case me = 3

            var title: String {
                switch self {
                case .today: "Today"
                case .chat: "Aria"
                case .bonds: "Bonds"
                case .me: "Me"
                }
            }

            var icon: String {
                switch self {
                case .today: "sun.horizon"
                case .chat: "bubble.left.and.text.bubble.right"
                case .bonds: "person.2"
                case .me: "person"
                }
            }

            var selectedIcon: String {
                switch self {
                case .today: "sun.horizon.fill"
                case .chat: "bubble.left.and.text.bubble.right.fill"
                case .bonds: "person.2.fill"
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
        case bonds(BondsFeature.Action)
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

        Scope(state: \.bondsState, action: \.bonds) {
            BondsFeature()
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

            case .today, .chat, .bonds, .profile, .cycleInsights, .cycleJourney, .delegate:
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

                // Me Tab — briefing design (profile accessible via gear)
                meTab
            }
            .tint(DesignColors.accentWarm)
            .safeAreaInset(edge: .top, spacing: 0) {
                // Persistent top bar with settings gear — reserves space, never overlaps tab content
                HStack {
                    Spacer()
                    Button(action: { store.isSettingsVisible = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignColors.text)
                            .frame(width: 38, height: 38)
                            .background(DesignColors.cardWarm, in: Circle())
                            .overlay(Circle().strokeBorder(DesignColors.structure.opacity(0.22), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.clear)
            }

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

            // Initial profile bootstrap — subtle non-blocking top indicator.
            // Tabs stay interactive; hero already has its own skeleton state.
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
                .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isLoading)
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
        .sheet(isPresented: $store.isSettingsVisible) {
            NavigationStack {
                ProfileView(
                    store: store.scope(state: \.profileState, action: \.profile)
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { store.isSettingsVisible = false }
                            .tint(DesignColors.accentWarm)
                    }
                }
            }
        }
        .onAppear { safeAreaTop = rootGeo.safeAreaInsets.top }
        .task {
            store.send(.onAppear)
        }
        .enableInjection()
        } // GeometryReader
    }

    private var meTab: some View {
        MeTabView(
            userName: store.user?.firstName ?? "You",
            bonds: store.bondsState.readings,
            bondsStore: store.scope(state: \.bondsState, action: \.bonds),
            onOpenBond: { r in store.send(.bonds(.readingTapped(r))) },
            onAddBond: { }
        )
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


}


// MARK: - Preview


#Preview {
    HomeView(
        store: .init(initialState: HomeFeature.State(user: .mock)) {
            HomeFeature()
        }
    )
}



// MARK: - Me Tab (briefing design)

// Asymmetric gallery frame — open on the left edge, draws top/right/bottom
private struct GalleryFrameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

private struct MeTabView: View {
    let userName: String
    let bonds: [BondReading]
    let bondsStore: StoreOf<BondsFeature>
    let onOpenBond: (BondReading) -> Void
    let onAddBond: () -> Void

    @State private var isAddBondVisible: Bool = false
    @State private var carouselPage: Int = 0
    @State private var selectedMood: Mood? = .tender
    @State private var showsBonds: Bool = false
    @State private var meSection: MeSection = .reading
    @Namespace private var meTabNS

    enum MeSection: String, CaseIterable, Identifiable {
        case reading = "Reading"
        case people = "People"
        var id: String { rawValue }
    }

    enum Mood: String, CaseIterable, Identifiable {
        case quiet = "Quiet"
        case tender = "Tender"
        case restless = "Restless"
        case fierce = "Fierce"
        case grounded = "Grounded"
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                DesignColors.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Dark hero panel — bleeds to top edge
                        ZStack(alignment: .top) {
                            darkPanelShape
                                .frame(height: 580 + proxy.safeAreaInsets.top)
                                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)

                            briefingContent
                                .padding(.top, proxy.safeAreaInsets.top + 4)
                        }
                        .frame(height: 580 + proxy.safeAreaInsets.top)

                        // Segmented tab switcher — one focused section at a time
                        meTabSwitcher
                            .padding(.top, 28)

                        Spacer().frame(height: 72)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .fullScreenCover(isPresented: $isAddBondVisible) {
            AddBondScreenView(
                onBack: { isAddBondVisible = false },
                onCreate: { _, _ in isAddBondVisible = false }
            )
        }
        .fullScreenCover(isPresented: $showsBonds) {
            BondsView(store: bondsStore)
        }
    }

    // Day-of-week index used to rotate the gradient (all warm family)
    private var dayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) - 1 + 7) % 7
    }

    // Dynamic warm gradient — softer, cream-anchored so the panel feathers into the page
    private var dynamicGradientColors: [Color] {
        switch dayIndex {
        case 0: // Sunday — dusty rose wash
            return [DesignColors.roseTaupe.opacity(0.55), DesignColors.roseTaupeLight.opacity(0.45), DesignColors.cardWarm]
        case 1: // Monday — soft blush
            return [DesignColors.accent.opacity(0.55), DesignColors.roseTaupeLight.opacity(0.4), DesignColors.cardWarm]
        case 2: // Tuesday — terracotta drift
            return [DesignColors.accentWarm.opacity(0.45), DesignColors.accent.opacity(0.5), DesignColors.cardWarm]
        case 3: // Wednesday — rose taupe
            return [DesignColors.roseTaupe.opacity(0.55), DesignColors.accent.opacity(0.45), DesignColors.cardWarm]
        case 4: // Thursday — golden warmth
            return [DesignColors.accentSecondary.opacity(0.55), DesignColors.accent.opacity(0.45), DesignColors.cardWarm]
        case 5: // Friday — deep warmth
            return [DesignColors.accentWarmText.opacity(0.45), DesignColors.accentWarm.opacity(0.4), DesignColors.cardWarm]
        case 6: // Saturday — sandstone
            return [DesignColors.structure.opacity(0.55), DesignColors.roseTaupeLight.opacity(0.4), DesignColors.cardWarm]
        default:
            return [DesignColors.accentWarm.opacity(0.45), DesignColors.accent.opacity(0.5), DesignColors.cardWarm]
        }
    }

    private var darkPanelShape: some View {
        UnevenRoundedRectangle(cornerRadii: .init(
            topLeading: 0, bottomLeading: 32,
            bottomTrailing: 32, topTrailing: 0
        ))
        .fill(
            LinearGradient(
                colors: dynamicGradientColors,
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: 0, bottomLeading: 32,
                bottomTrailing: 32, topTrailing: 0
            ))
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.22), .clear],
                    startPoint: .top, endPoint: .center
                )
            )
        )
        .overlay(
            RadialGradient(
                colors: [Color.white.opacity(0.35), .clear],
                center: UnitPoint(x: 0.2, y: 0.08),
                startRadius: 0, endRadius: 240
            )
            .allowsHitTesting(false)
            .clipShape(UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: 0, bottomLeading: 32,
                bottomTrailing: 32, topTrailing: 0
            )))
        )
    }

    // Big essential reading card — uses the app's warm aurora (glowCardBackground)
    private var essentialReadingCard: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 0) {
                // Small caps label
                HStack(spacing: 6) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("YOUR ESSENTIAL READING")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(1.6)
                }
                .foregroundStyle(DesignColors.accentWarmText)
                .shadow(color: DesignColors.background.opacity(0.6), radius: 3, x: 0, y: 0)

                Spacer().frame(height: 16)

                Text("Who you are,\nin depth.")
                    .font(.raleway("Bold", size: 24, relativeTo: .title2))
                    .tracking(-0.3)
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(2)
                    .shadow(color: DesignColors.background.opacity(0.75), radius: 4, x: 0, y: 0)

                Spacer().frame(height: 10)

                Text("A long-form reading of your nature — what fuels you, what slows you, what you carry with you.")
                    .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textPrincipal)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: DesignColors.background.opacity(0.6), radius: 3, x: 0, y: 0)

                Spacer().frame(height: 18)

                // Quiet read affordance
                HStack(spacing: 6) {
                    Text("Read your reading")
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignColors.text)
                .shadow(color: DesignColors.background.opacity(0.6), radius: 3, x: 0, y: 0)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glowCardBackground(tint: .rose)
        }
        .buttonStyle(.plain)
    }

    // User's first initial for the personal emblem
    private var userInitial: String {
        String(userName.prefix(1)).uppercased()
    }

    // Painterly aura block representing the user — warm watercolor feel, tappable
    private var natalAura: some View {
        Button(action: {}) {
            ZStack(alignment: .bottomLeading) {
                // Painterly gradient stack — layered radial blooms to mimic watercolor
                ZStack {
                    Rectangle()
                        .fill(DesignColors.cardWarm)
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [DesignColors.accent.opacity(0.85), .clear],
                                center: UnitPoint(x: 0.18, y: 0.28),
                                startRadius: 10, endRadius: 220
                            )
                        )
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [DesignColors.accentWarm.opacity(0.7), .clear],
                                center: UnitPoint(x: 0.82, y: 0.75),
                                startRadius: 10, endRadius: 240
                            )
                        )
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [DesignColors.roseTaupe.opacity(0.55), .clear],
                                center: UnitPoint(x: 0.55, y: 0.35),
                                startRadius: 20, endRadius: 200
                            )
                        )
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [DesignColors.accentWarmText.opacity(0.25), .clear],
                                center: UnitPoint(x: 0.3, y: 0.8),
                                startRadius: 8, endRadius: 180
                            )
                        )
                    // Subtle top-edge highlight
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.25)
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(DesignColors.structure.opacity(0.22), lineWidth: 0.5)
                )

                // Text overlay anchored bottom-left
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOU, IN DEPTH")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2)
                        .foregroundStyle(DesignColors.accentWarmText)

                    Text(userName)
                        .font(.raleway("Bold", size: 42, relativeTo: .largeTitle))
                        .tracking(-0.8)
                        .foregroundStyle(DesignColors.text)

                    Text("A reading of your nature — warmth, rhythms, what fuels you, what slows you.")
                        .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(DesignColors.text.opacity(0.72))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 8)

                    HStack(spacing: 7) {
                        Text("Open your reading")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarm)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(DesignColors.background.opacity(0.7), in: Capsule())
                    .overlay(Capsule().strokeBorder(DesignColors.accentWarm.opacity(0.35), lineWidth: 0.5))
                }
                .padding(22)
            }
            .frame(height: 280)
            .shadow(color: DesignColors.text.opacity(0.1), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    // People section — caps label + horizontal scroll of painterly portrait tiles
    private var peopleTiles: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR PEOPLE")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Text("How you move together.")
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .tracking(-0.3)
                        .foregroundStyle(DesignColors.text)
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(bonds.enumerated()), id: \.element.id) { idx, r in
                        Button(action: { onOpenBond(r) }) {
                            paintedBondTile(r, idx: idx)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: { isAddBondVisible = true }) {
                        addPaintedTile
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
        }
    }

    // Painterly bond portrait tile — unique watercolor gradient per bond
    private func paintedBondTile(_ r: BondReading, idx: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                Rectangle().fill(r.color.opacity(0.2))
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [r.color.opacity(0.95), .clear],
                            center: UnitPoint(x: 0.3, y: 0.3),
                            startRadius: 5, endRadius: 160
                        )
                    )
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [r.color.opacity(0.65), .clear],
                            center: UnitPoint(x: 0.75, y: 0.75),
                            startRadius: 5, endRadius: 150
                        )
                    )
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [DesignColors.cardWarm.opacity(0.6), .clear],
                            center: UnitPoint(x: 0.55, y: 0.2),
                            startRadius: 5, endRadius: 120
                        )
                    )
                LinearGradient(
                    colors: [.white.opacity(0.3), .clear],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(r.bondType.uppercased())
                    .font(.raleway("Bold", size: 8, relativeTo: .caption2))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: r.color.opacity(0.6), radius: 2, x: 0, y: 1)
                Text(r.name)
                    .font(.raleway("Bold", size: 22, relativeTo: .title2))
                    .tracking(-0.3)
                    .foregroundStyle(.white)
                    .shadow(color: r.color.opacity(0.7), radius: 4, x: 0, y: 2)
            }
            .padding(16)
        }
        .frame(width: 168, height: 220)
        .shadow(color: r.color.opacity(0.3), radius: 14, x: 0, y: 8)
    }

    // Add tile — painterly dashed ghost
    private var addPaintedTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignColors.cardWarm.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            DesignColors.accentWarm.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                )

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            DesignColors.accentWarm.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignColors.accentWarm)
                }
                VStack(spacing: 2) {
                    Text("Add")
                        .font(.raleway("Bold", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.accentWarm)
                    Text("by birthday")
                        .font(.raleway("Regular", size: 10, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }
        }
        .frame(width: 140, height: 220)
    }

    // NATAL access card — compact, horizontal, low-height pill (secondary: read once, reference)
    private var natalAccessCard: some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: 16) {
                // Small emblem on the left
                ZStack {
                    Circle()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.35), lineWidth: 0.5)
                        .frame(width: 54, height: 54)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarmText, DesignColors.accentWarm],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: DesignColors.accentWarmText.opacity(0.3), radius: 8, x: 0, y: 3)
                    Text(userInitial)
                        .font(.raleway("Bold", size: 18, relativeTo: .title3))
                        .foregroundStyle(.white)
                }

                // Middle — two-line label, minimal
                VStack(alignment: .leading, spacing: 3) {
                    Text("WHO YOU ARE")
                        .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                        .tracking(1.6)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Text("Your full reading")
                        .font(.raleway("Bold", size: 17, relativeTo: .body))
                        .tracking(-0.2)
                        .foregroundStyle(DesignColors.text)
                    Text("Written from your chart, for \(userName).")
                        .font(.raleway("Regular", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DesignColors.accentWarm)
                    .padding(10)
                    .background(DesignColors.cardWarm.opacity(0.6), in: Circle())
                    .overlay(Circle().strokeBorder(DesignColors.accent.opacity(0.4), lineWidth: 0.5))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .liquidGlass(cornerRadius: 24)
            .shadow(color: DesignColors.text.opacity(0.07), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: Portrait — WARM GRADIENT hero (dark, immersive, white text on warm)
    private var mePortrait: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 0) {
                Text("WHO YOU ARE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.4)
                    .foregroundStyle(.white.opacity(0.88))

                Spacer().frame(height: 12)

                Text("Your reading")
                    .font(.raleway("Bold", size: 34, relativeTo: .largeTitle))
                    .tracking(-0.8)
                    .foregroundStyle(.white)

                Spacer().frame(height: 22)

                Rectangle()
                    .fill(.white.opacity(0.28))
                    .frame(height: 0.6)

                Spacer().frame(height: 22)

                // Preview excerpt — actual reading text
                Text("You lead with warmth and notice what others don't. Beneath the softness, a spine — you just don't show it until you have to.")
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 14)

                Text("You were born in transition, and it shows in how you decide, how you love, how you recover.")
                    .font(.raleway("Medium", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 22)

                HStack(spacing: 8) {
                    Rectangle()
                        .fill(.white.opacity(0.55))
                        .frame(width: 14, height: 0.6)
                    Text("Written from your chart, for \(displayName)")
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer().frame(height: 26)

                HStack(spacing: 8) {
                    Text("Continue reading")
                        .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarmText)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Capsule().fill(DesignColors.cardWarm))
                .shadow(color: DesignColors.accentWarmText.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(meReadingMesh)
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: DesignColors.accentWarmText.opacity(0.32), radius: 22, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    // Mesh gradient background — Denim-inspired painterly depth (iOS 18+) with fallback
    @ViewBuilder
    private var meReadingMesh: some View {
        if #available(iOS 18.0, *) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        MeshGradient(
                            width: 3,
                            height: 3,
                            points: [
                                SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
                                SIMD2<Float>(0.0, 0.5), SIMD2<Float>(0.5, 0.5), SIMD2<Float>(1.0, 0.5),
                                SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
                            ],
                            colors: [
                                DesignColors.accentWarmText, DesignColors.accentWarm, DesignColors.accent,
                                DesignColors.accentWarm, DesignColors.roseTaupe, DesignColors.accentWarmText,
                                DesignColors.roseTaupe, DesignColors.accentWarmText, DesignColors.accentWarm
                            ]
                        )
                    )
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center)
                    )
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DesignColors.accentWarmText, DesignColors.accentWarm, DesignColors.roseTaupe.opacity(0.9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RadialGradient(
                    colors: [DesignColors.accent.opacity(0.6), .clear],
                    center: UnitPoint(x: 0.9, y: 0.1),
                    startRadius: 0, endRadius: 300
                )
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center)
                    )
            }
        }
    }

    // MARK: Cycle tile — small bento companion (bottom-left)
    private var meCycleTile: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 0) {
                Text("CYCLE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.2)
                    .foregroundStyle(DesignColors.accentWarmText)

                Spacer().frame(height: 10)

                Text("Day 12")
                    .font(.raleway("Bold", size: 26, relativeTo: .title))
                    .tracking(-0.6)
                    .foregroundStyle(DesignColors.text)

                Spacer().frame(height: 4)

                Text("Follicular phase")
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)

                Spacer(minLength: 14)

                // Tiny visual indicator — 7-dot phase strip
                HStack(spacing: 4) {
                    ForEach(0..<7) { idx in
                        Circle()
                            .fill(idx < 3 ? DesignColors.accentWarm : DesignColors.structure)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DesignColors.cardWarm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(DesignColors.structure, lineWidth: 0.8)
            )
            .shadow(color: DesignColors.text.opacity(0.05), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: People tile — small bento companion (bottom-right) opens Bonds
    private var mePeopleTile: some View {
        Button(action: { showsBonds = true }) {
            VStack(alignment: .leading, spacing: 0) {
                Text("PEOPLE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.2)
                    .foregroundStyle(DesignColors.accentWarmText)

                Spacer().frame(height: 10)

                Text("\(wordCount(for: bonds.count))")
                    .font(.raleway("Bold", size: 26, relativeTo: .title))
                    .tracking(-0.6)
                    .foregroundStyle(DesignColors.text)

                Spacer().frame(height: 4)

                Text("in your life")
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)

                Spacer(minLength: 14)

                // Avatar cluster (smaller, subtle)
                HStack(spacing: -8) {
                    ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                        ZStack {
                            Circle()
                                .fill(DesignColors.cardWarm)
                                .frame(width: 26, height: 26)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: meAvatarGradient(for: r.bondType),
                                        center: UnitPoint(x: 0.3, y: 0.3),
                                        startRadius: 2, endRadius: 18
                                    )
                                )
                                .frame(width: 22, height: 22)
                            Text(r.initial)
                                .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                                .foregroundStyle(.white)
                        }
                        .zIndex(Double(4 - idx))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DesignColors.cardWarm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(DesignColors.structure, lineWidth: 0.8)
            )
            .shadow(color: DesignColors.text.opacity(0.05), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Tab switcher — refined, softer proportions
    private var meTabSwitcher: some View {
        VStack(alignment: .leading, spacing: 40) {
            // Segmented pill control — larger padding, softer fills, refined active state
            HStack(spacing: 0) {
                ForEach(MeSection.allCases) { section in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            meSection = section
                        }
                    } label: {
                        ZStack {
                            if meSection == section {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.white.opacity(0.22), .clear],
                                                    startPoint: .top, endPoint: .center
                                                )
                                            )
                                    )
                                    .matchedGeometryEffect(id: "meTabPill", in: meTabNS)
                                    .shadow(color: DesignColors.accentWarmText.opacity(0.28), radius: 10, x: 0, y: 4)
                                    .shadow(color: DesignColors.accentWarmText.opacity(0.14), radius: 2, x: 0, y: 1)
                            }
                            Text(section.rawValue)
                                .font(.raleway(meSection == section ? "SemiBold" : "Medium", size: 14, relativeTo: .subheadline))
                                .tracking(0.2)
                                .foregroundStyle(meSection == section ? .white : DesignColors.text.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background(
                Capsule()
                    .fill(DesignColors.cardWarm)
                    .shadow(color: DesignColors.text.opacity(0.05), radius: 10, x: 0, y: 4)
            )
            .overlay(Capsule().strokeBorder(DesignColors.structure.opacity(0.8), lineWidth: 0.8))
            .padding(.horizontal, 28)

            Group {
                if meSection == .reading {
                    meTabReading
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    meTabPeople
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 28)
        }
    }

    // Reading tab — bento: hero profile-style card, 2-column, wide feature
    private var meTabReading: some View {
        VStack(spacing: 12) {
            readingHeroCard
            HStack(spacing: 12) {
                readingSmallBento(
                    kind: "Your Chart",
                    description: "A long-form portrait of your nature.",
                    gradient: [DesignColors.roseTaupeLight, DesignColors.roseTaupe],
                    symbol: "book.closed.fill"
                )
                readingSmallBento(
                    kind: "Today's Verse",
                    description: "A quiet confidence moves you today.",
                    gradient: [DesignColors.cardGradientEnd, DesignColors.accent],
                    symbol: "quote.opening"
                )
            }
            readingWideFeatureCard

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }

    private var readingHeroCard: some View {
        VStack(spacing: 0) {
            // Top stat strip — stat | avatar | stat
            HStack(alignment: .center, spacing: 0) {
                VStack(spacing: 2) {
                    Text("Day 4")
                        .font(.raleway("Bold", size: 20, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)
                    Text("of cycle")
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text.opacity(0.5))
                }
                .frame(maxWidth: .infinity)

                // Aria avatar — the "profile" photo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accent, DesignColors.accentWarm, DesignColors.accentWarmText],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RadialGradient(
                                colors: [Color.white.opacity(0.55), .clear],
                                center: UnitPoint(x: 0.25, y: 0.2),
                                startRadius: 1, endRadius: 40
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.95))
                }
                .frame(width: 80, height: 80)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
                .shadow(color: DesignColors.accentWarmText.opacity(0.2), radius: 8, x: 0, y: 4)

                VStack(spacing: 2) {
                    Text("4 min")
                        .font(.raleway("Bold", size: 20, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)
                    Text("to read")
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 24)

            Spacer().frame(height: 16)

            HStack(spacing: 4) {
                Text("The Letter")
                    .font(.raleway("Bold", size: 22, relativeTo: .title2))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignColors.accentWarmText)
            }

            Spacer().frame(height: 4)

            Text("Gentle  |  Reflective  |  Warm")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.text.opacity(0.55))

            Spacer().frame(height: 16)

            // 2 action pills
            HStack(spacing: 10) {
                pillButton(icon: "book.fill", label: "Read") {}
                pillButton(icon: "bookmark", label: "Save") {}
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(DesignColors.cardWarm)
        )
        .shadow(color: DesignColors.accentWarmText.opacity(0.1), radius: 14, x: 0, y: 6)
    }

    private func pillButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
            }
            .foregroundStyle(DesignColors.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                Capsule().fill(DesignColors.background)
            )
            .overlay(
                Capsule().strokeBorder(DesignColors.structure.opacity(0.7), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func readingSmallBento(kind: String, description: String, gradient: [Color], symbol: String) -> some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 0) {
                // Mini gradient thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RadialGradient(
                                colors: [Color.white.opacity(0.55), .clear],
                                center: UnitPoint(x: 0.25, y: 0.2),
                                startRadius: 0, endRadius: 90
                            )
                        )
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.95))
                }
                .frame(height: 86)

                Spacer().frame(height: 14)

                Text(kind)
                    .font(.raleway("Bold", size: 16, relativeTo: .body))
                    .tracking(-0.3)
                    .foregroundStyle(DesignColors.text)

                Spacer().frame(height: 4)

                Text(description)
                    .font(.raleway("Medium", size: 11, relativeTo: .caption))
                    .foregroundStyle(DesignColors.text.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 10)

                HStack(spacing: 5) {
                    Text("Open")
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(DesignColors.background))
                .overlay(Capsule().strokeBorder(DesignColors.structure.opacity(0.6), lineWidth: 0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignColors.cardWarm)
            )
            .shadow(color: DesignColors.accentWarmText.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var readingWideFeatureCard: some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text("All your readings")
                            .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)

                    Text("See every letter,")
                        .font(.raleway("Bold", size: 18, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)
                    Text("chart and verse")
                        .font(.raleway("Bold", size: 18, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)

                    Spacer().frame(height: 4)

                    Text("See all")
                        .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text.opacity(0.55))
                }

                Spacer()

                // Right-side thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accent, DesignColors.accentWarm, DesignColors.accentWarmText],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RadialGradient(
                                colors: [Color.white.opacity(0.55), .clear],
                                center: UnitPoint(x: 0.3, y: 0.25),
                                startRadius: 0, endRadius: 70
                            )
                        )
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.95))
                }
                .frame(width: 88, height: 78)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignColors.cardWarm)
            )
            .shadow(color: DesignColors.accentWarmText.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // DEAD old: car-details reading artwork — unused, kept for compile
    private var meTabReadingOld: some View {
        VStack(spacing: 0) {
            // BIG BLUSH HERO CARD
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Spacer()
                    Text("Today's Reading")
                        .font(.raleway("Bold", size: 16, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignColors.text)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)

                Spacer().frame(height: 14)

                Text("From Aria")
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.text.opacity(0.55))

                Spacer().frame(height: 12)

                // Big warm-gradient abstract disc (hero visual)
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    DesignColors.accentWarmText,
                                    DesignColors.accentWarm,
                                    DesignColors.roseTaupe.opacity(0.85)
                                ],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 6, endRadius: 130
                            )
                        )
                        .frame(width: 170, height: 170)
                        .overlay(
                            Circle().stroke(
                                LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center),
                                lineWidth: 1
                            )
                        )
                        .shadow(color: DesignColors.accentWarmText.opacity(0.3), radius: 16, x: 0, y: 8)

                    Text(userInitial)
                        .font(.raleway("Bold", size: 60, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                }

                Spacer().frame(height: 10)

                // Thin horizontal rule with a dot (like the reference's slider indicator)
                ZStack {
                    Rectangle()
                        .fill(DesignColors.text.opacity(0.25))
                        .frame(height: 0.6)
                    Circle()
                        .fill(DesignColors.text)
                        .frame(width: 8, height: 8)
                }
                .frame(width: 200)

                Spacer().frame(height: 22)

                // Small avatar dot + big title
                HStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 0.6))

                    Text("Your Reading")
                        .font(.raleway("Bold", size: 26, relativeTo: .title))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)

                    Spacer()
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 10)

                // Description
                (
                    Text("A quiet confidence moves you today. ")
                        .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                        .foregroundColor(DesignColors.text.opacity(0.7))
                    + Text(Image(systemName: "sparkle"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignColors.accentWarm)
                    + Text(" Decisions feel clearer than last week, instincts sharper.")
                        .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                        .foregroundColor(DesignColors.text.opacity(0.7))
                )
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

                Spacer().frame(height: 18)

                // Reviews-style row: chapter preview + "Open →"
                HStack(spacing: 10) {
                    HStack(spacing: -8) {
                        ForEach(0..<3, id: \.self) { idx in
                            Circle()
                                .fill(
                                    [DesignColors.accent, DesignColors.roseTaupeLight, DesignColors.accentWarm][idx]
                                )
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(DesignColors.accent.opacity(0.6), lineWidth: 1.2))
                        }
                    }
                    Text("4 chapters")
                        .font(.raleway("Bold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)

                    Spacer()

                    HStack(spacing: 5) {
                        Text("Read")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.text)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                }
                .padding(14)
                .background(
                    Capsule().fill(DesignColors.background.opacity(0.55))
                )
                .overlay(Capsule().strokeBorder(DesignColors.accent.opacity(0.6), lineWidth: 0.8))
                .padding(.horizontal, 20)

                Spacer().frame(height: 22)
            }
            .background(
                ZStack {
                    LinearGradient(
                        colors: [DesignColors.accent.opacity(0.78), DesignColors.roseTaupeLight.opacity(0.55), DesignColors.accent.opacity(0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            // DARK BOTTOM STRIP with 3 stat pills
            HStack(spacing: 0) {
                statCell(icon: "book.closed.fill", value: "4", unit: "chapters")
                Divider().frame(height: 32).overlay(DesignColors.cardWarm.opacity(0.12))
                statCell(icon: "clock.fill", value: "Today", unit: "updated")
                Divider().frame(height: 32).overlay(DesignColors.cardWarm.opacity(0.12))
                statCell(icon: "sparkle", value: "Warm", unit: "tone")
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(DesignColors.text)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.top, -16)
            .padding(.horizontal, 14)

            Spacer().frame(height: 16)

            // Price-style bottom row with CTA
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Chapter I")
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .foregroundStyle(DesignColors.text)
                    Text("/ today")
                        .font(.raleway("Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text.opacity(0.55))
                }

                Spacer()

                Button(action: {}) {
                    HStack(spacing: 7) {
                        Text("Open letter")
                            .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .shadow(color: DesignColors.accentWarmText.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private func statCell(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(DesignColors.accentWarmText.opacity(0.5)))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.raleway("Bold", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.cardWarm)
                Text(unit)
                    .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.cardWarm.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // People tab — bento: featured bond hero, 2-column, wide "add/see all" card
    @ViewBuilder
    private var meTabPeople: some View {
        if let featured = bonds.first {
            VStack(spacing: 12) {
                peopleHeroCard(featured: featured)
                let others = Array(bonds.dropFirst().prefix(2))
                HStack(spacing: 12) {
                    if others.count > 0 {
                        peopleSmallBento(bond: others[0])
                    } else {
                        emptyBentoPlaceholder
                    }
                    if others.count > 1 {
                        peopleSmallBento(bond: others[1])
                    } else {
                        emptyBentoPlaceholder
                    }
                }
                peopleWideFeatureCard

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)
        }
    }

    private var emptyBentoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(DesignColors.cardWarm.opacity(0.5))
            .frame(minHeight: 220)
    }

    private func peopleHeroCard(featured: BondReading) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                VStack(spacing: 2) {
                    Text("2 yrs")
                        .font(.raleway("Bold", size: 20, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)
                    Text("bond")
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text.opacity(0.5))
                }
                .frame(maxWidth: .infinity)

                // Painterly portrait
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: meAvatarGradient(for: featured.bondType),
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RadialGradient(
                                colors: [Color.white.opacity(0.55), .clear],
                                center: UnitPoint(x: 0.25, y: 0.2),
                                startRadius: 1, endRadius: 40
                            )
                        )
                    Text(String(featured.name.prefix(1)))
                        .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .frame(width: 80, height: 80)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
                .shadow(color: DesignColors.accentWarmText.opacity(0.2), radius: 8, x: 0, y: 4)

                VStack(spacing: 2) {
                    Text("12")
                        .font(.raleway("Bold", size: 20, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)
                    Text("words")
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 24)

            Spacer().frame(height: 16)

            HStack(spacing: 4) {
                Text(featured.name)
                    .font(.raleway("Bold", size: 22, relativeTo: .title2))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignColors.accentWarmText)
            }

            Spacer().frame(height: 4)

            Text("\(featured.bondType.capitalized)  |  Close  |  Today")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.text.opacity(0.55))

            Spacer().frame(height: 16)

            HStack(spacing: 10) {
                pillButton(icon: "paperplane.fill", label: "Send") {}
                pillButton(icon: "message", label: "Open") { onOpenBond(featured) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(DesignColors.cardWarm)
        )
        .shadow(color: DesignColors.accentWarmText.opacity(0.1), radius: 14, x: 0, y: 6)
    }

    private func peopleSmallBento(bond: BondReading) -> some View {
        Button(action: { onOpenBond(bond) }) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: meAvatarGradient(for: bond.bondType),
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RadialGradient(
                                colors: [Color.white.opacity(0.55), .clear],
                                center: UnitPoint(x: 0.25, y: 0.2),
                                startRadius: 0, endRadius: 90
                            )
                        )
                    Text(String(bond.name.prefix(1)))
                        .font(.raleway("Bold", size: 32, relativeTo: .largeTitle))
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .frame(height: 86)

                Spacer().frame(height: 14)

                Text(bond.name)
                    .font(.raleway("Bold", size: 16, relativeTo: .body))
                    .tracking(-0.3)
                    .foregroundStyle(DesignColors.text)
                    .lineLimit(1)

                Spacer().frame(height: 4)

                Text("A \(bond.bondType.lowercased()) bond — steady and close.")
                    .font(.raleway("Medium", size: 11, relativeTo: .caption))
                    .foregroundStyle(DesignColors.text.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 10)

                HStack(spacing: 5) {
                    Text("Open")
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(DesignColors.background))
                .overlay(Capsule().strokeBorder(DesignColors.structure.opacity(0.6), lineWidth: 0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignColors.cardWarm)
            )
            .shadow(color: DesignColors.accentWarmText.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var peopleWideFeatureCard: some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Your whole circle")
                            .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)

                    Text("See everyone you")
                        .font(.raleway("Bold", size: 18, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)
                    Text("love and carry")
                        .font(.raleway("Bold", size: 18, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)

                    Spacer().frame(height: 4)

                    Text("See all")
                        .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text.opacity(0.55))
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.roseTaupeLight, DesignColors.accentWarm],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RadialGradient(
                                colors: [Color.white.opacity(0.55), .clear],
                                center: UnitPoint(x: 0.3, y: 0.25),
                                startRadius: 0, endRadius: 70
                            )
                        )
                    // Stacked mini avatars
                    HStack(spacing: -10) {
                        ForEach(bonds.prefix(3), id: \.id) { r in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: meAvatarGradient(for: r.bondType),
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.2))
                        }
                    }
                }
                .frame(width: 88, height: 78)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignColors.cardWarm)
            )
            .shadow(color: DesignColors.accentWarmText.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // DEAD old: car-details people artwork — unused, kept for compile
    private var meTabPeopleOld: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Your People")
                        .font(.raleway("Bold", size: 16, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignColors.text)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)

                Spacer().frame(height: 14)

                Text("In your life")
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.text.opacity(0.55))

                Spacer().frame(height: 12)

                // Hero visual: avatar cluster
                HStack(spacing: -22) {
                    ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                        Button(action: { onOpenBond(r) }) {
                            ZStack {
                                Circle()
                                    .fill(DesignColors.cardWarm)
                                    .frame(width: 94, height: 94)
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: meAvatarGradient(for: r.bondType),
                                            center: UnitPoint(x: 0.3, y: 0.3),
                                            startRadius: 4, endRadius: 70
                                        )
                                    )
                                    .frame(width: 88, height: 88)
                                    .overlay(
                                        Circle().stroke(
                                            LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center),
                                            lineWidth: 0.8
                                        )
                                    )
                                Text(r.initial)
                                    .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: DesignColors.accentWarmText.opacity(0.28), radius: 14, x: 0, y: 7)
                            .zIndex(Double(4 - idx))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(height: 170)

                Spacer().frame(height: 10)

                ZStack {
                    Rectangle()
                        .fill(DesignColors.text.opacity(0.25))
                        .frame(height: 0.6)
                    Circle()
                        .fill(DesignColors.text)
                        .frame(width: 8, height: 8)
                }
                .frame(width: 200)

                Spacer().frame(height: 22)

                HStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 0.6))

                    Text("\(wordCount(for: bonds.count)) bonds")
                        .font(.raleway("Bold", size: 26, relativeTo: .title))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)

                    Spacer()
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 10)

                Text(bondsNameSentence)
                    .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.text.opacity(0.7))
                    .lineSpacing(3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(height: 18)

                // Info chip
                HStack(spacing: 10) {
                    HStack(spacing: -8) {
                        ForEach(bonds.prefix(3), id: \.id) { r in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: meAvatarGradient(for: r.bondType),
                                        center: UnitPoint(x: 0.3, y: 0.3),
                                        startRadius: 2, endRadius: 14
                                    )
                                )
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(DesignColors.accent.opacity(0.6), lineWidth: 1.2))
                        }
                    }
                    Text("Today")
                        .font(.raleway("Bold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)

                    Spacer()

                    HStack(spacing: 5) {
                        Text("Open")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.text)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                }
                .padding(14)
                .background(
                    Capsule().fill(DesignColors.background.opacity(0.55))
                )
                .overlay(Capsule().strokeBorder(DesignColors.accent.opacity(0.6), lineWidth: 0.8))
                .padding(.horizontal, 20)

                Spacer().frame(height: 22)
            }
            .background(
                ZStack {
                    LinearGradient(
                        colors: [DesignColors.roseTaupeLight.opacity(0.7), DesignColors.cardWarm, DesignColors.accent.opacity(0.55)],
                        startPoint: .topTrailing, endPoint: .bottomLeading
                    )
                    LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            // DARK STRIP
            HStack(spacing: 0) {
                statCell(icon: "person.2.fill", value: "\(bonds.count)", unit: "bonds")
                Divider().frame(height: 32).overlay(DesignColors.cardWarm.opacity(0.12))
                statCell(icon: "heart.fill", value: "Close", unit: "today")
                Divider().frame(height: 32).overlay(DesignColors.cardWarm.opacity(0.12))
                statCell(icon: "sparkle", value: "All", unit: "active")
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(DesignColors.text)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.top, -16)
            .padding(.horizontal, 14)

            Spacer().frame(height: 16)

            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(wordCount(for: bonds.count))")
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .foregroundStyle(DesignColors.text)
                    Text("/ people")
                        .font(.raleway("Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text.opacity(0.55))
                }

                Spacer()

                Button(action: { showsBonds = true }) {
                    HStack(spacing: 7) {
                        Text("See all")
                            .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .shadow(color: DesignColors.accentWarmText.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Ribbon sections — vertical warm ribbons (unused — kept for compile)
    private var meRibbonSections: some View {
        VStack(alignment: .leading, spacing: 0) {
            // SECTION 1 — Reading: ribbon left, content right
            HStack(alignment: .top, spacing: 20) {
                // Warm vertical gradient ribbon
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 6)
                    .shadow(color: DesignColors.accentWarmText.opacity(0.25), radius: 6, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 0) {
                    Text("A LETTER FROM ARIA")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarmText)

                    Spacer().frame(height: 14)

                    Text("Your reading")
                        .font(.raleway("Bold", size: 30, relativeTo: .title))
                        .tracking(-0.6)
                        .foregroundStyle(DesignColors.text)

                    Spacer().frame(height: 14)

                    Text("A quiet confidence moves you today — decisions feel clearer than last week, instincts sharper than usual.")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text.opacity(0.7))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 20)

                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Text("Open the letter")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                        }
                        .shadow(color: DesignColors.accentWarmText.opacity(0.35), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 56)

            // SECTION 2 — People: mirrored — avatars LEFT as the anchor, content right (asymmetric rhyme)
            HStack(alignment: .top, spacing: 20) {
                // Stack of avatars (visual marker — different from ribbon)
                VStack(spacing: -10) {
                    ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                        Button(action: { onOpenBond(r) }) {
                            ZStack {
                                Circle()
                                    .fill(DesignColors.background)
                                    .frame(width: 38, height: 38)
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: meAvatarGradient(for: r.bondType),
                                            center: UnitPoint(x: 0.3, y: 0.3),
                                            startRadius: 2, endRadius: 26
                                        )
                                    )
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().stroke(
                                            LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center),
                                            lineWidth: 0.7
                                        )
                                    )
                                Text(r.initial)
                                    .font(.raleway("Bold", size: 13, relativeTo: .body))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: DesignColors.text.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 38)

                VStack(alignment: .leading, spacing: 0) {
                    Text("YOUR PEOPLE  ·  \(bonds.count)")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarmText)

                    Spacer().frame(height: 14)

                    Text("In your life")
                        .font(.raleway("Bold", size: 30, relativeTo: .title))
                        .tracking(-0.6)
                        .foregroundStyle(DesignColors.text)

                    Spacer().frame(height: 14)

                    Text(bondsNameSentence)
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text.opacity(0.7))
                        .lineSpacing(4)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 20)

                    Button(action: { showsBonds = true }) {
                        HStack(spacing: 8) {
                            Text("See all \(bonds.count) bonds")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                        }
                        .shadow(color: DesignColors.accentWarmText.opacity(0.35), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Atmospheric zone — ivory bg, warm elements that POP (unused)
    private var meAtmosphericZone: some View {
        VStack(alignment: .leading, spacing: 0) {
            // — LETTER SECTION with warm backdrop bloom —
            ZStack(alignment: .topLeading) {
                // Asymmetric warm bloom (not a box — atmospheric, no edges)
                RadialGradient(
                    colors: [DesignColors.accent.opacity(0.48), DesignColors.accent.opacity(0.15), .clear],
                    center: UnitPoint(x: 0.82, y: 0.2),
                    startRadius: 0, endRadius: 260
                )
                .frame(height: 320)
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Text("A LETTER FROM ARIA")
                            .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                            .tracking(2.4)
                            .foregroundStyle(DesignColors.accentWarmText)
                        Rectangle()
                            .fill(DesignColors.accentWarmText.opacity(0.35))
                            .frame(height: 0.6)
                    }

                    Spacer().frame(height: 16)

                    Text("Your reading")
                        .font(.raleway("Bold", size: 32, relativeTo: .title))
                        .tracking(-0.7)
                        .foregroundStyle(DesignColors.text)

                    Spacer().frame(height: 18)

                    Text("There's a quiet confidence in you today — the kind that doesn't need to prove itself. Decisions feel clearer than last week.")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text.opacity(0.72))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 26)

                    // Rich warm gradient pill — pops on ivory
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Text("Open the letter")
                                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .shadow(color: DesignColors.accentWarmText.opacity(0.4), radius: 12, x: 0, y: 5)
                        .shadow(color: DesignColors.text.opacity(0.12), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer().frame(height: 56)

            // — PEOPLE SECTION with warm backdrop bloom (mirrored corner) —
            ZStack(alignment: .topTrailing) {
                RadialGradient(
                    colors: [DesignColors.roseTaupeLight.opacity(0.5), DesignColors.accent.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.18, y: 0.2),
                    startRadius: 0, endRadius: 260
                )
                .frame(height: 320)
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Text("YOUR PEOPLE  ·  \(bonds.count)")
                            .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                            .tracking(2.4)
                            .foregroundStyle(DesignColors.accentWarmText)
                        Rectangle()
                            .fill(DesignColors.accentWarmText.opacity(0.35))
                            .frame(height: 0.6)
                    }

                    Spacer().frame(height: 16)

                    Text("In your life")
                        .font(.raleway("Bold", size: 32, relativeTo: .title))
                        .tracking(-0.7)
                        .foregroundStyle(DesignColors.text)

                    Spacer().frame(height: 22)

                    // Rich portraits with stronger shadows to pop on ivory
                    HStack(spacing: -14) {
                        ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                            Button(action: { onOpenBond(r) }) {
                                ZStack {
                                    Circle()
                                        .fill(DesignColors.background)
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: meAvatarGradient(for: r.bondType),
                                                center: UnitPoint(x: 0.3, y: 0.3),
                                                startRadius: 3, endRadius: 42
                                            )
                                        )
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Circle().stroke(
                                                LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center),
                                                lineWidth: 0.8
                                            )
                                        )
                                    Text(r.initial)
                                        .font(.raleway("Bold", size: 20, relativeTo: .body))
                                        .foregroundStyle(.white)
                                }
                                .shadow(color: DesignColors.accentWarmText.opacity(0.25), radius: 10, x: 0, y: 5)
                                .zIndex(Double(4 - idx))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer().frame(height: 16)

                    Text(bondsNameSentence)
                        .font(.raleway("Medium", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.text.opacity(0.72))
                        .lineLimit(2)

                    Spacer().frame(height: 24)

                    Button(action: { showsBonds = true }) {
                        HStack(spacing: 8) {
                            Text("See all \(bonds.count) bonds")
                                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .shadow(color: DesignColors.accentWarmText.opacity(0.4), radius: 12, x: 0, y: 5)
                        .shadow(color: DesignColors.text.opacity(0.12), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: Reading box — exact CardStackFeature pattern (unused, kept for compile)
    private var meReadingBox: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your reading")
                .font(.custom("Raleway-Bold", size: 22, relativeTo: .title2))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .lineSpacing(2)
                .lineLimit(2)
                .shadow(color: DesignColors.background.opacity(0.75), radius: 4, x: 0, y: 0)

            Text("A quiet confidence moves you today — decisions feel clearer, instincts sharper. A good day for honest conversations.")
                .font(.custom("Raleway-Medium", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .lineSpacing(3)
                .lineLimit(6)
                .shadow(color: DesignColors.background.opacity(0.6), radius: 3, x: 0, y: 0)

            Button(action: {}) {
                HStack(spacing: 8) {
                    Text("Open the letter")
                        .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .shadow(color: DesignColors.text.opacity(0.32), radius: 12, x: 0, y: 5)
                .shadow(color: DesignColors.text.opacity(0.16), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 240)
        .glowCardBackground(tint: .neutral)
    }

    // MARK: People box — exact CardStackFeature pattern, .taupe tint
    private var mePeopleBox: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your people")
                .font(.custom("Raleway-Bold", size: 22, relativeTo: .title2))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .lineSpacing(2)
                .lineLimit(2)
                .shadow(color: DesignColors.background.opacity(0.75), radius: 4, x: 0, y: 0)

            Text(bondsNameSentence)
                .font(.custom("Raleway-Medium", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .lineSpacing(3)
                .lineLimit(2)
                .shadow(color: DesignColors.background.opacity(0.6), radius: 3, x: 0, y: 0)

            // Avatar cluster
            HStack(spacing: -14) {
                ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                    ZStack {
                        Circle()
                            .fill(DesignColors.cardWarm)
                            .frame(width: 52, height: 52)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: meAvatarGradient(for: r.bondType),
                                    center: UnitPoint(x: 0.3, y: 0.3),
                                    startRadius: 3, endRadius: 36
                                )
                            )
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center),
                                    lineWidth: 0.8
                                )
                            )
                        Text(r.initial)
                            .font(.custom("Raleway-Bold", size: 17, relativeTo: .body))
                            .foregroundStyle(.white)
                    }
                    .zIndex(Double(4 - idx))
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 0)

            Button(action: { showsBonds = true }) {
                HStack(spacing: 8) {
                    Text("See all \(bonds.count) bonds")
                        .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .shadow(color: DesignColors.text.opacity(0.32), radius: 12, x: 0, y: 5)
                .shadow(color: DesignColors.text.opacity(0.16), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 260)
        .glowCardBackground(tint: .neutral)
    }

    // MARK: Designed letter — drop cap, pull quote, rule ornaments, woven names (unused)
    private var meWovenLetter: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow with date
            HStack(spacing: 10) {
                Text("A LETTER FROM ARIA")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.4)
                    .foregroundStyle(DesignColors.accentWarmText)
                Rectangle().fill(DesignColors.accentWarmText.opacity(0.3)).frame(height: 0.6)
                Text("APR 21")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(1.6)
                    .foregroundStyle(DesignColors.textSecondary)
                    .fixedSize()
            }

            Spacer().frame(height: 32)

            // Drop cap + first paragraph — editorial design element
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    // Warm spotlight behind the drop cap
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DesignColors.accent.opacity(0.7), DesignColors.accent.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 0, endRadius: 48
                            )
                        )
                        .frame(width: 96, height: 96)
                        .offset(x: -8, y: -8)
                    Text("T")
                        .font(.raleway("Bold", size: 62, relativeTo: .largeTitle))
                        .tracking(-2)
                        .foregroundStyle(DesignColors.accentWarmText)
                }
                .frame(width: 56, height: 68, alignment: .topLeading)

                prose("here's a quiet confidence in you today — the kind that doesn't need to prove itself.")
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }

            Spacer().frame(height: 18)

            prose("Decisions feel clearer than last week, and your instincts are sharper than usual.")
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 28)

            // Pull quote — visual anchor, with rules top + bottom
            VStack(alignment: .leading, spacing: 16) {
                Rectangle()
                    .fill(DesignColors.accentWarm.opacity(0.6))
                    .frame(width: 44, height: 0.6)

                wovenPullQuote(
                    prefix: "With ",
                    leftName: bonds[safe: 0]?.name ?? "Andrei",
                    middle: ", this clarity will feel like a gift. With ",
                    rightName: bonds[safe: 1]?.name ?? "Ana",
                    suffix: ", soften."
                )

                Rectangle()
                    .fill(DesignColors.accentWarm.opacity(0.6))
                    .frame(width: 44, height: 0.6)
            }
            .padding(.leading, 4)

            Spacer().frame(height: 28)

            // Closing paragraph with remaining woven names
            wovenParagraph(
                prefix: "Honest conversations open easily. ",
                leftName: bonds[safe: 2]?.name ?? "Mama",
                middle: " will answer if you reach first. ",
                rightName: bonds[safe: 3]?.name ?? "Ioana",
                suffix: " is thinking of you, whether she says so or not."
            )

            Spacer().frame(height: 28)

            // Signature with sparkle ornament
            HStack(spacing: 10) {
                Rectangle()
                    .fill(DesignColors.accentWarm.opacity(0.55))
                    .frame(width: 20, height: 0.6)
                Image(systemName: "sparkle")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(DesignColors.accentWarm.opacity(0.7))
                Rectangle()
                    .fill(DesignColors.accentWarm.opacity(0.55))
                    .frame(width: 20, height: 0.6)
                Text("Aria, for you")
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Spacer().frame(height: 36)

            // Portrait avatars of the people mentioned — small visual closure
            HStack(spacing: -10) {
                ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                    Button(action: { onOpenBond(r) }) {
                        ZStack {
                            Circle()
                                .fill(DesignColors.cardWarm)
                                .frame(width: 38, height: 38)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: meAvatarGradient(for: r.bondType),
                                        center: UnitPoint(x: 0.3, y: 0.3),
                                        startRadius: 2, endRadius: 26
                                    )
                                )
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle().stroke(
                                        LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center),
                                        lineWidth: 0.7
                                    )
                                )
                            Text(r.initial)
                                .font(.raleway("Bold", size: 13, relativeTo: .body))
                                .foregroundStyle(.white)
                        }
                        .zIndex(Double(4 - idx))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer().frame(height: 32)

            HStack(spacing: 28) {
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Text("Continue reading")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(DesignColors.structure)
                    .frame(width: 0.6, height: 16)

                Button(action: { showsBonds = true }) {
                    HStack(spacing: 6) {
                        Text("Your people")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Text("·")
                            .font(.raleway("Medium", size: 12, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                        Text("\(bonds.count)")
                            .font(.raleway("Medium", size: 12, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 64)
    }

    @ViewBuilder
    private func wovenPullQuote(prefix: String, leftName: String, middle: String, rightName: String, suffix: String) -> some View {
        (
            Text(prefix)
                .font(.raleway("Bold", size: 22, relativeTo: .title3))
                .foregroundColor(DesignColors.text)
            + Text(leftName)
                .font(.raleway("Bold", size: 22, relativeTo: .title3))
                .foregroundColor(DesignColors.accentWarmText)
            + Text(middle)
                .font(.raleway("Bold", size: 22, relativeTo: .title3))
                .foregroundColor(DesignColors.text)
            + Text(rightName)
                .font(.raleway("Bold", size: 22, relativeTo: .title3))
                .foregroundColor(DesignColors.accentWarmText)
            + Text(suffix)
                .font(.raleway("Bold", size: 22, relativeTo: .title3))
                .foregroundColor(DesignColors.text)
        )
        .tracking(-0.3)
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func prose(_ text: String) -> Text {
        Text(text)
            .font(.raleway("Regular", size: 17, relativeTo: .body))
            .foregroundColor(DesignColors.text.opacity(0.88))
    }

    @ViewBuilder
    private func wovenParagraph(prefix: String, leftName: String, middle: String, rightName: String, suffix: String) -> some View {
        (
            prose(prefix)
            + Text(leftName)
                .font(.raleway("Bold", size: 17, relativeTo: .body))
                .foregroundColor(DesignColors.accentWarmText)
            + prose(middle)
            + Text(rightName)
                .font(.raleway("Bold", size: 17, relativeTo: .body))
                .foregroundColor(DesignColors.accentWarmText)
            + prose(suffix)
        )
        .lineSpacing(7)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Letter-peek + people-strip on a warm mesh bottom panel (unused — kept for compile)
    private var meLetterPeek: some View {
        ZStack(alignment: .top) {
            meBondsMesh
                .shadow(color: DesignColors.accentWarmText.opacity(0.18), radius: 22, x: 0, y: -6)

            VStack(alignment: .leading, spacing: 0) {
                // Top eyebrow
                HStack(spacing: 10) {
                    Text("A LETTER, FOR YOU")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Rectangle()
                        .fill(DesignColors.accentWarmText.opacity(0.35))
                        .frame(height: 0.6)
                }

                Spacer().frame(height: 22)

                // The actual letter text — shown, not described
                Text("There's a quiet confidence in you today — the kind that doesn't need to prove itself. Decisions feel clearer than they did last week, and your instincts are sharper than usual.")
                    .font(.raleway("Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.9))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 14)

                Text("This is a good day for honest conversations.")
                    .font(.raleway("Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.6))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 24)

                // Warm pill CTA
                Button(action: {}) {
                    HStack(spacing: 7) {
                        Text("Continue your reading")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .shadow(color: DesignColors.accentWarmText.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 44)

                // Decorative divider — rule · dot · rule
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(DesignColors.accentWarmText.opacity(0.3))
                        .frame(height: 0.6)
                    Circle()
                        .fill(DesignColors.accentWarm.opacity(0.7))
                        .frame(width: 3, height: 3)
                    Rectangle()
                        .fill(DesignColors.accentWarmText.opacity(0.3))
                        .frame(height: 0.6)
                }

                Spacer().frame(height: 28)

                HStack {
                    Text("YOUR PEOPLE")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Spacer()
                    Button(action: { showsBonds = true }) {
                        HStack(spacing: 5) {
                            Text("See all")
                                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(DesignColors.accentWarmText)
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 22)

                // Horizontal portrait strip — fundamentally different shape from the letter
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(bonds.prefix(4)), id: \.id) { r in
                        bondPortraitChip(r)
                        if r.id != bonds.prefix(4).last?.id {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 80)
        }
    }

    private func bondPortraitChip(_ r: BondReading) -> some View {
        Button(action: { onOpenBond(r) }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: meAvatarGradient(for: r.bondType),
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 3, endRadius: 42
                            )
                        )
                        .frame(width: 58, height: 58)
                        .overlay(
                            Circle().stroke(
                                LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center),
                                lineWidth: 0.8
                            )
                        )
                    Text(r.initial)
                        .font(.raleway("Bold", size: 21, relativeTo: .title3))
                        .foregroundStyle(.white)
                }
                .shadow(color: DesignColors.text.opacity(0.08), radius: 8, x: 0, y: 4)

                Text(r.name)
                    .font(.raleway("Medium", size: 13, relativeTo: .caption))
                    .foregroundStyle(DesignColors.text.opacity(0.85))

                Text(relationalWord(for: r.bondType))
                    .font(.raleway("Regular", size: 11, relativeTo: .caption2))
                    .foregroundStyle(DesignColors.accentWarmText)
            }
        }
        .buttonStyle(.plain)
    }

    private func relationalWord(for bondType: String) -> String {
        switch bondType.lowercased() {
        case "extraordinary": return "Intense"
        case "soulmate": return "Safe"
        case "powerful": return "Steady"
        case "meaningful": return "Close"
        default: return "Near"
        }
    }

    // MARK: Editorial zone (unused — kept for compile)
    private var meEditorialZone: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reading block
            Button(action: {}) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR READING")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarmText)

                    Text("A letter,\nfor who you are.")
                        .font(.raleway("Bold", size: 30, relativeTo: .title))
                        .tracking(-0.6)
                        .foregroundStyle(DesignColors.text)
                        .lineSpacing(2)

                    Text("Written from your chart — what fuels you, what slows you, what you carry.")
                        .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(DesignColors.text.opacity(0.65))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 4)

                    HStack(spacing: 8) {
                        Text("Open your reading")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .shadow(color: DesignColors.accentWarmText.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.top, 36)

            Spacer().frame(height: 40)

            // Decorative divider
            HStack(spacing: 10) {
                Rectangle()
                    .fill(DesignColors.structure)
                    .frame(height: 0.6)
                Circle()
                    .fill(DesignColors.accentWarm.opacity(0.65))
                    .frame(width: 3, height: 3)
                Rectangle()
                    .fill(DesignColors.structure)
                    .frame(height: 0.6)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 40)

            // Bonds block
            Button(action: { showsBonds = true }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR PEOPLE  ·  \(bonds.count)")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarmText)

                    Text(bondsSalutation)
                        .font(.raleway("Bold", size: 30, relativeTo: .title))
                        .tracking(-0.6)
                        .foregroundStyle(DesignColors.text)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Avatar cluster + names line
                    HStack(alignment: .center, spacing: 14) {
                        HStack(spacing: -12) {
                            ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                                ZStack {
                                    Circle()
                                        .fill(DesignColors.background)
                                        .frame(width: 40, height: 40)
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: meAvatarGradient(for: r.bondType),
                                                center: UnitPoint(x: 0.3, y: 0.3),
                                                startRadius: 2, endRadius: 28
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle().stroke(
                                                LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center),
                                                lineWidth: 0.7
                                            )
                                        )
                                    Text(r.initial)
                                        .font(.raleway("Bold", size: 13, relativeTo: .body))
                                        .foregroundStyle(.white)
                                }
                                .zIndex(Double(4 - idx))
                            }
                        }
                        Spacer()
                    }

                    Spacer().frame(height: 4)

                    HStack(spacing: 8) {
                        Text("See all \(bonds.count) bonds")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentWarmText],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .shadow(color: DesignColors.accentWarmText.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
        .background(
            // Subtle warm wash that connects to the hero (no hard card)
            LinearGradient(
                colors: [DesignColors.accent.opacity(0.2), DesignColors.background],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )
        )
    }

    // Natural salutation for bonds: "Ana, Andrei,\nMama and Ioana." etc.
    private var bondsSalutation: String {
        let names = bonds.map { $0.name }
        guard !names.isEmpty else { return "" }
        if names.count == 1 { return "\(names[0])." }
        if names.count == 2 { return "\(names[0])\nand \(names[1])." }
        let head = names.dropLast().joined(separator: ", ")
        let tail = names.last ?? ""
        return "\(head)\nand \(tail)."
    }

    // MARK: Feature hero — editorial pull-quote with Aria's signature warm dot (unused)
    private var meFeatureHero: some View {
        Button(action: {}) {
            ZStack(alignment: .topLeading) {
                // Canvas with warm morning glow
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignColors.cardWarm)
                RadialGradient(
                    colors: [DesignColors.accent.opacity(0.55), DesignColors.accent.opacity(0.12), .clear],
                    center: UnitPoint(x: 0.82, y: 0.14),
                    startRadius: 0, endRadius: 300
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                RadialGradient(
                    colors: [DesignColors.roseTaupeLight.opacity(0.4), .clear],
                    center: UnitPoint(x: 0.1, y: 0.9),
                    startRadius: 0, endRadius: 240
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                // Top light wash
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.4))
                    )

                VStack(alignment: .leading, spacing: 0) {
                    // Signature row — Aria's warm dot + caps
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [DesignColors.accentWarmText, DesignColors.accentWarm],
                                        center: UnitPoint(x: 0.3, y: 0.3),
                                        startRadius: 1, endRadius: 14
                                    )
                                )
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(.white.opacity(0.4), lineWidth: 0.6)
                                .frame(width: 20, height: 20)
                        }
                        Text("ARIA, FOR YOU")
                            .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                            .tracking(2.2)
                            .foregroundStyle(DesignColors.accentWarmText)
                    }

                    Spacer().frame(height: 24)

                    // Large decorative opening quote mark
                    Text("\u{201C}")
                        .font(.system(size: 80, weight: .regular))
                        .foregroundStyle(DesignColors.accentWarm.opacity(0.45))
                        .offset(x: -6, y: 30)
                        .frame(height: 36)

                    Spacer().frame(height: 10)

                    // Pull-quote — the hero statement
                    Text("You lead with warmth and notice what others don't.")
                        .font(.raleway("Bold", size: 24, relativeTo: .title2))
                        .tracking(-0.5)
                        .foregroundStyle(DesignColors.text)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 14)

                    Text("Beneath the softness, a spine — you just don't show it until you have to.")
                        .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(DesignColors.text.opacity(0.7))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 26)

                    // Signature + link on the same row
                    HStack {
                        Text("— from your reading")
                            .font(.raleway("Medium", size: 11, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Text("Continue")
                                .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(DesignColors.accentWarmText)
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.6), DesignColors.structure.opacity(0.5)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: DesignColors.accentWarmText.opacity(0.15), radius: 22, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: Bonds lineup — 4 clean portrait circles with name labels, row of 4
    private var meBondsLineup: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Text("YOUR PEOPLE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.4)
                    .foregroundStyle(DesignColors.accentWarmText)
                Spacer()
                Button(action: { showsBonds = true }) {
                    HStack(spacing: 5) {
                        Text("See all")
                            .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                ForEach(bonds.prefix(4), id: \.id) { r in
                    bondLineupTile(r)
                    if r.id != bonds.prefix(4).last?.id {
                        Spacer(minLength: 8)
                    }
                }
            }
        }
    }

    private func bondLineupTile(_ r: BondReading) -> some View {
        Button(action: { onOpenBond(r) }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: meAvatarGradient(for: r.bondType),
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 3, endRadius: 46
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle().stroke(
                                LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center),
                                lineWidth: 0.8
                            )
                        )
                    Text(r.initial)
                        .font(.raleway("Bold", size: 22, relativeTo: .title3))
                        .foregroundStyle(.white)
                }
                .shadow(color: DesignColors.text.opacity(0.08), radius: 8, x: 0, y: 4)

                Text(r.name)
                    .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.text.opacity(0.78))
                    .lineLimit(1)

                Text(r.bondType)
                    .font(.raleway("Medium", size: 9, relativeTo: .caption2))
                    .tracking(0.4)
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Letter card — cream with a visible fold crease (unused — kept for compile)
    private var meLetterCard: some View {
        Button(action: {}) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DesignColors.cardWarm)

                RadialGradient(
                    colors: [DesignColors.accent.opacity(0.32), .clear],
                    center: UnitPoint(x: 0.85, y: 0.18),
                    startRadius: 0, endRadius: 220
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                // The fold — hairline with soft shadow suggesting paper crease
                VStack(spacing: 0) {
                    Spacer().frame(height: 150)
                    Rectangle()
                        .fill(DesignColors.structure.opacity(0.55))
                        .frame(height: 0.6)
                    Rectangle()
                        .fill(DesignColors.text.opacity(0.05))
                        .frame(height: 2)
                        .blur(radius: 1.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                // Content
                VStack(alignment: .leading, spacing: 0) {
                    // Stamp in top-right
                    HStack {
                        Spacer()
                        Text("FOR YOU")
                            .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                            .tracking(2.2)
                            .foregroundStyle(DesignColors.accentWarmText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(DesignColors.accentWarmText.opacity(0.45), lineWidth: 0.6)
                            )
                    }

                    Spacer().frame(height: 22)

                    Text("A letter,\nfrom Aria")
                        .font(.raleway("Medium", size: 26, relativeTo: .title2))
                        .tracking(-0.3)
                        .lineSpacing(4)
                        .foregroundStyle(DesignColors.text)

                    Spacer().frame(height: 12)

                    Text("Today you move steady, bright, tender — a warmth that notices what others miss.")
                        .font(.raleway("Medium", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.text.opacity(0.7))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // Fold space
                    Spacer(minLength: 40)

                    // Signature line (below fold, bottom-right)
                    HStack {
                        Spacer()
                        Text("— Aria, for you")
                            .font(.raleway("Medium", size: 11, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                    }

                    Spacer().frame(height: 10)

                    // Unfold link
                    HStack(spacing: 7) {
                        Text("Unfold the full letter")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(DesignColors.structure, lineWidth: 0.8)
            )
            .shadow(color: DesignColors.text.opacity(0.09), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Bonds gallery — asymmetric portrait arrangement, no container
    private var meBondsGallery: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("YOUR PEOPLE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.4)
                    .foregroundStyle(DesignColors.accentWarmText)
                Rectangle()
                    .fill(DesignColors.structure)
                    .frame(height: 0.6)
                Text("\(bonds.count)")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.accentWarmText)
                    .fixedSize()
            }

            Spacer().frame(height: 28)

            // Asymmetric portrait gallery (no container, different sizes, organic)
            let sizes: [CGFloat] = [58, 44, 52, 40]
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                    bondPortraitTile(r, size: sizes[idx % sizes.count])
                }
                Spacer()
            }

            Spacer().frame(height: 24)

            Button(action: { showsBonds = true }) {
                HStack(spacing: 7) {
                    Text("See all \(bonds.count) people")
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarmText)
            }
            .buttonStyle(.plain)
        }
    }

    private func bondPortraitTile(_ r: BondReading, size: CGFloat) -> some View {
        Button(action: { onOpenBond(r) }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: meAvatarGradient(for: r.bondType),
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 3, endRadius: size * 0.7
                            )
                        )
                        .frame(width: size, height: size)
                        .overlay(
                            Circle().stroke(
                                LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center),
                                lineWidth: 0.8
                            )
                        )
                    Text(r.initial)
                        .font(.raleway("Bold", size: size * 0.38, relativeTo: .body))
                        .foregroundStyle(.white)
                }
                .shadow(color: DesignColors.text.opacity(0.08), radius: 6, x: 0, y: 3)

                Text(r.name)
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                    .foregroundStyle(DesignColors.text.opacity(0.74))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Gallery frame — asymmetric editorial composition (unused — kept for compile)
    private var meGalleryFrame: some View {
        Button(action: {}) {
            ZStack(alignment: .topLeading) {
                // Canvas — warm cream with subtle layered blush glows
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignColors.cardWarm)
                RadialGradient(
                    colors: [DesignColors.accent.opacity(0.6), .clear],
                    center: UnitPoint(x: 0.8, y: 0.18),
                    startRadius: 0, endRadius: 260
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                RadialGradient(
                    colors: [DesignColors.roseTaupeLight.opacity(0.4), .clear],
                    center: UnitPoint(x: 0.15, y: 0.85),
                    startRadius: 0, endRadius: 220
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                // Asymmetric double-line gallery frame (top + right + bottom — not left)
                GalleryFrameShape()
                    .stroke(DesignColors.accentWarmText.opacity(0.35), lineWidth: 0.6)
                    .padding(16)

                GalleryFrameShape()
                    .stroke(DesignColors.accentWarmText.opacity(0.22), lineWidth: 0.6)
                    .padding(20)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(DesignColors.accentWarm.opacity(0.65))
                            .frame(width: 18, height: 0.6)
                        Text("VOL I  ·  SPRING")
                            .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                            .tracking(2.6)
                            .foregroundStyle(DesignColors.accentWarmText)
                    }

                    Spacer().frame(height: 48)

                    // Sun disc — abstract warm sphere, not a portrait
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        DesignColors.accent.opacity(0.9),
                                        DesignColors.accentWarm.opacity(0.6),
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.3, y: 0.3),
                                    startRadius: 4, endRadius: 80
                                )
                            )
                            .frame(width: 110, height: 110)
                        Circle()
                            .strokeBorder(DesignColors.accentWarmText.opacity(0.3), lineWidth: 0.5)
                            .frame(width: 88, height: 88)
                    }
                    .offset(x: 40, y: -12)

                    Spacer().frame(height: 8)

                    Text("Your reading")
                        .font(.raleway("Bold", size: 32, relativeTo: .largeTitle))
                        .tracking(-0.8)
                        .foregroundStyle(DesignColors.text)

                    Spacer().frame(height: 10)

                    Text("A long-form letter\nof your nature.")
                        .font(.raleway("Medium", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(DesignColors.text.opacity(0.7))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 32)

                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(DesignColors.accentWarm.opacity(0.65))
                            .frame(width: 18, height: 0.6)
                        Text("Open the letter")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.accentWarmText)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DesignColors.accentWarmText)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, minHeight: 400)
            .shadow(color: DesignColors.text.opacity(0.1), radius: 22, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: Immersive surface — iOS 26 Liquid Glass inspired, one big hero below the top panel
    private var meImmersiveSurface: some View {
        ZStack(alignment: .bottom) {
            meBondsMesh
                .frame(minHeight: 620)
                .shadow(color: DesignColors.accentWarmText.opacity(0.2), radius: 22, x: 0, y: -6)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Text("WHO YOU ARE")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.6)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Rectangle()
                        .fill(DesignColors.accentWarmText.opacity(0.35))
                        .frame(height: 0.6)
                }

                Spacer().frame(height: 22)

                Text("Your reading")
                    .font(.raleway("Bold", size: 36, relativeTo: .largeTitle))
                    .tracking(-0.9)
                    .foregroundStyle(DesignColors.text)

                Spacer().frame(height: 20)

                Text("You lead with warmth and notice what others don't. Beneath the softness, a spine — you just don't show it until you have to.")
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.88))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 14)

                Text("You were born in transition, and it shows in how you decide, how you love, how you recover.")
                    .font(.raleway("Medium", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text.opacity(0.62))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 22)

                HStack(spacing: 8) {
                    Rectangle()
                        .fill(DesignColors.accentWarm.opacity(0.65))
                        .frame(width: 14, height: 0.6)
                    Text("Aria, for you")
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                }

                Spacer(minLength: 180)
            }
            .padding(.horizontal, 28)
            .padding(.top, 38)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Floating Liquid Glass CTAs at the bottom — iOS 26 pattern (AllTrails/Fantastical)
            HStack(spacing: 10) {
                Button(action: {}) {
                    HStack(spacing: 7) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Continue reading")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    }
                    .foregroundStyle(DesignColors.text)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .liquidGlassCapsule()
                    .shadow(color: DesignColors.text.opacity(0.12), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                Button(action: { showsBonds = true }) {
                    HStack(spacing: 7) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Your people")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    }
                    .foregroundStyle(DesignColors.text)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .liquidGlassCapsule()
                    .shadow(color: DesignColors.text.opacity(0.12), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 54)
        }
    }

    // Mesh gradient for bottom bleed panel — iOS 18+ with fallback
    @ViewBuilder
    private var meBondsMesh: some View {
        let shape = UnevenRoundedRectangle(cornerRadii: .init(
            topLeading: 32, bottomLeading: 0,
            bottomTrailing: 0, topTrailing: 32
        ))
        if #available(iOS 18.0, *) {
            ZStack {
                shape
                    .fill(
                        MeshGradient(
                            width: 3,
                            height: 3,
                            points: [
                                SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
                                SIMD2<Float>(0.0, 0.5), SIMD2<Float>(0.5, 0.5), SIMD2<Float>(1.0, 0.5),
                                SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
                            ],
                            colors: [
                                DesignColors.accent, DesignColors.roseTaupeLight, DesignColors.accentWarm,
                                DesignColors.roseTaupeLight, DesignColors.accent, DesignColors.accentWarm,
                                DesignColors.cardWarm, DesignColors.roseTaupeLight, DesignColors.accent
                            ]
                        )
                    )
                shape
                    .fill(LinearGradient(colors: [.white.opacity(0.32), .clear], startPoint: .top, endPoint: .center))
            }
        } else {
            ZStack {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignColors.accent.opacity(0.6),
                                DesignColors.roseTaupeLight.opacity(0.55),
                                DesignColors.cardWarm
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                shape
                    .fill(LinearGradient(colors: [.white.opacity(0.32), .clear], startPoint: .top, endPoint: .center))
            }
        }
    }

    // MARK: Bonds bottom panel — mesh-gradient warm, bleeds to bottom (Denim-inspired)
    private var meBondsBottomPanel: some View {
        Button(action: { showsBonds = true }) {
            ZStack(alignment: .top) {
                meBondsMesh
                    .shadow(color: DesignColors.accentWarmText.opacity(0.22), radius: 20, x: 0, y: -6)

                // Ultra-minimal content inside the bottom panel
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR PEOPLE")
                            .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                            .tracking(2.4)
                            .foregroundStyle(DesignColors.accentWarmText)
                        Text("Four in your life")
                            .font(.raleway("Bold", size: 28, relativeTo: .title))
                            .tracking(-0.6)
                            .foregroundStyle(DesignColors.text)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DesignColors.accentWarmText)
                        .frame(width: 44, height: 44)
                        .background(DesignColors.background.opacity(0.8), in: Circle())
                        .overlay(Circle().strokeBorder(DesignColors.accent.opacity(0.5), lineWidth: 0.7))
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)
                .padding(.bottom, 72)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Bonds — minimal footer entry (unused — kept for compile)
    private var meBondsStrip: some View {
        Button(action: { showsBonds = true }) {
            VStack(spacing: 14) {
                // Editorial rule with caps label
                HStack(spacing: 10) {
                    Rectangle().fill(DesignColors.structure).frame(height: 0.6)
                    Text("YOUR PEOPLE  ·  \(wordCount(for: bonds.count).uppercased())")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarmText)
                        .fixedSize()
                    Rectangle().fill(DesignColors.structure).frame(height: 0.6)
                }

                HStack(alignment: .center, spacing: 14) {
                    HStack(spacing: -12) {
                        ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                            ZStack {
                                Circle()
                                    .fill(DesignColors.background)
                                    .frame(width: 38, height: 38)
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: meAvatarGradient(for: r.bondType),
                                            center: UnitPoint(x: 0.3, y: 0.3),
                                            startRadius: 2, endRadius: 26
                                        )
                                    )
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().stroke(
                                            LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center),
                                            lineWidth: 0.8
                                        )
                                    )
                                Text(r.initial)
                                    .font(.raleway("Bold", size: 12, relativeTo: .caption))
                                    .foregroundStyle(.white)
                            }
                            .zIndex(Double(4 - idx))
                        }
                    }

                    Text(bondsPreviewNames)
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(DesignColors.text.opacity(0.72))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    HStack(spacing: 6) {
                        Text("See all")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Names preview like "Andrei, Ana, Mama & 1 more"
    private var bondsPreviewNames: String {
        let names = bonds.prefix(3).map { $0.name }
        guard !names.isEmpty else { return "" }
        let remainder = bonds.count - names.count
        let head = names.joined(separator: ", ")
        return remainder > 0 ? "\(head) & \(remainder) more" : head
    }

    // Natural-language list of all bond names — e.g. "Ana, Andrei, Mama and Ioana"
    private var bondsNameSentence: String {
        let names = bonds.map { $0.name }
        guard !names.isEmpty else { return "" }
        if names.count == 1 { return names[0] }
        if names.count == 2 { return "\(names[0]) and \(names[1])" }
        let head = names.dropLast().joined(separator: ", ")
        let tail = names.last ?? ""
        return "\(head) and \(tail)"
    }

    private func bondPreviewRow(_ r: BondReading) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(DesignColors.cardWarm)
                    .frame(width: 48, height: 48)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: meAvatarGradient(for: r.bondType),
                            center: UnitPoint(x: 0.3, y: 0.3),
                            startRadius: 3, endRadius: 34
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center),
                            lineWidth: 0.8
                        )
                    )
                Text(r.initial)
                    .font(.raleway("Bold", size: 15, relativeTo: .body))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(r.name)
                        .font(.raleway("Bold", size: 16, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                    Text("·")
                        .foregroundStyle(DesignColors.textSecondary)
                    Text(r.bondType)
                        .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.accentWarmText)
                }
                Text(r.todayInsight)
                    .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.text.opacity(0.72))
                    .lineSpacing(3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    // MARK: Your story (unused) — timeline of personal milestones
    private var meStoryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Your story")
                    .font(.raleway("Bold", size: 22, relativeTo: .title2))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.cardWarm)
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.cardWarm.opacity(0.78))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)

            VStack(spacing: 0) {
                ForEach(Array(storyList.enumerated()), id: \.offset) { idx, moment in
                    storyRow(moment)
                    if idx < storyList.count - 1 {
                        Rectangle()
                            .fill(DesignColors.cardWarm.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, 22)
                    }
                }
            }
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DesignColors.text)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(DesignColors.accentWarmText.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: DesignColors.text.opacity(0.22), radius: 20, x: 0, y: 10)
    }

    private func storyRow(_ m: StoryMoment) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Colored dot indicator (matches the warm palette)
            ZStack {
                Circle()
                    .fill(m.tint.opacity(0.22))
                    .frame(width: 40, height: 40)
                Image(systemName: m.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(m.tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(m.title)
                    .font(.raleway("Bold", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.cardWarm)
                HStack(spacing: 6) {
                    Text(m.date)
                        .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
                        .tracking(0.4)
                        .foregroundStyle(DesignColors.cardWarm.opacity(0.72))
                    Circle()
                        .fill(DesignColors.cardWarm.opacity(0.3))
                        .frame(width: 2.5, height: 2.5)
                    Text(m.relative)
                        .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                        .foregroundStyle(DesignColors.cardWarm.opacity(0.55))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignColors.cardWarm.opacity(0.35))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private struct StoryMoment {
        let title: String
        let date: String
        let relative: String
        let icon: String
        let tint: Color
    }

    private var storyList: [StoryMoment] {
        [
            StoryMoment(
                title: "Generated your reading",
                date: "Apr 21",
                relative: "Today",
                icon: "book.closed.fill",
                tint: DesignColors.accent
            ),
            StoryMoment(
                title: "Added Andrei to your bonds",
                date: "Apr 18",
                relative: "3 days ago",
                icon: "person.2.fill",
                tint: DesignColors.accentWarm
            ),
            StoryMoment(
                title: "First period logged",
                date: "Apr 5",
                relative: "Cycle began",
                icon: "drop.fill",
                tint: DesignColors.roseTaupe
            ),
            StoryMoment(
                title: "You started tracking",
                date: "Apr 3",
                relative: "Your first day",
                icon: "sparkle",
                tint: DesignColors.accentWarmText
            )
        ]
    }

    // MARK: Practices — dark section card with list items (unused, kept for compile)
    private var mePracticesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — title + See All
            HStack {
                Text("Practices")
                    .font(.raleway("Bold", size: 22, relativeTo: .title2))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.cardWarm)
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.cardWarm.opacity(0.78))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)

            VStack(spacing: 0) {
                ForEach(Array(practicesList.enumerated()), id: \.offset) { idx, practice in
                    practiceRow(practice)
                    if idx < practicesList.count - 1 {
                        Rectangle()
                            .fill(DesignColors.cardWarm.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, 22)
                    }
                }
            }
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DesignColors.text)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(DesignColors.accentWarmText.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: DesignColors.text.opacity(0.22), radius: 20, x: 0, y: 10)
    }

    private func practiceRow(_ p: Practice) -> some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(p.title)
                        .font(.raleway("Bold", size: 17, relativeTo: .body))
                        .foregroundStyle(DesignColors.cardWarm)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 7) {
                        Text(p.duration)
                            .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                            .foregroundStyle(DesignColors.cardWarm)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(DesignColors.cardWarm.opacity(0.16)))
                            .overlay(Capsule().strokeBorder(DesignColors.cardWarm.opacity(0.22), lineWidth: 0.5))
                        Text(p.category)
                            .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                            .foregroundStyle(DesignColors.cardWarm.opacity(0.82))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(DesignColors.cardWarm.opacity(0.08)))
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(DesignColors.accent)
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignColors.text)
                }
                .shadow(color: DesignColors.accent.opacity(0.5), radius: 10, x: 0, y: 4)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private struct Practice {
        let title: String
        let duration: String
        let category: String
    }

    private var practicesList: [Practice] {
        [
            Practice(title: "Morning intention", duration: "5 min", category: "Today"),
            Practice(title: "Cycle reflection", duration: "7 min", category: "Weekly"),
            Practice(title: "Evening check-in", duration: "3 min", category: "Tonight"),
            Practice(title: "Gratitude note", duration: "2 min", category: "Any time")
        ]
    }

    // MARK: Reading stat card — side-by-side layout inspired by reference
    private var meReadingStatCard: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("Your\nreading")
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)
                        .lineSpacing(-2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Text("DEEP")
                        .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                        .tracking(1.4)
                        .foregroundStyle(DesignColors.background)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignColors.text))
                }

                Spacer(minLength: 28)

                // Mini portrait in the middle-left for character
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DesignColors.accentWarmText, DesignColors.accentWarm],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 2, endRadius: 28
                            )
                        )
                        .frame(width: 36, height: 36)
                    Text(userInitial)
                        .font(.raleway("Bold", size: 14, relativeTo: .body))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 14)

                HStack(alignment: .center, spacing: 0) {
                    Text("Long-form")
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(DesignColors.background.opacity(0.75), in: Capsule())
                        .overlay(Capsule().strokeBorder(DesignColors.structure, lineWidth: 0.5))

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(DesignColors.accentWarm)
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: DesignColors.accentWarm.opacity(0.4), radius: 8, x: 0, y: 3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DesignColors.cardWarm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(DesignColors.structure.opacity(0.7), lineWidth: 0.8)
            )
            .shadow(color: DesignColors.text.opacity(0.06), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: Bonds stat card — side-by-side companion
    private var meBondsStatCard: some View {
        Button(action: { showsBonds = true }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("Your\npeople")
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)
                        .lineSpacing(-2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }

                Spacer(minLength: 28)

                // Stacked mini avatars for visual interest
                HStack(spacing: -10) {
                    ForEach(Array(bonds.prefix(3).enumerated()), id: \.element.id) { idx, r in
                        ZStack {
                            Circle()
                                .fill(DesignColors.cardWarm)
                                .frame(width: 34, height: 34)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: meAvatarGradient(for: r.bondType),
                                        center: UnitPoint(x: 0.3, y: 0.3),
                                        startRadius: 2, endRadius: 24
                                    )
                                )
                                .frame(width: 30, height: 30)
                            Text(r.initial)
                                .font(.raleway("Bold", size: 12, relativeTo: .caption))
                                .foregroundStyle(.white)
                        }
                        .zIndex(Double(3 - idx))
                    }
                }

                Spacer(minLength: 14)

                HStack(alignment: .center, spacing: 0) {
                    Text("\(bonds.count) bonds")
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.text)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(DesignColors.background.opacity(0.75), in: Capsule())
                        .overlay(Capsule().strokeBorder(DesignColors.structure, lineWidth: 0.5))

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(DesignColors.accentWarm)
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: DesignColors.accentWarm.opacity(0.4), radius: 8, x: 0, y: 3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DesignColors.cardWarm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(DesignColors.structure.opacity(0.7), lineWidth: 0.8)
            )
            .shadow(color: DesignColors.text.opacity(0.06), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: Reading hero (unused — kept for compile)
    private var meReadingHero: some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: 18) {
                // Portrait on the warm gradient
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.85), .white.opacity(0.55)],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 2, endRadius: 48
                            )
                        )
                        .frame(width: 62, height: 62)
                    Text(userInitial)
                        .font(.raleway("Bold", size: 26, relativeTo: .title3))
                        .foregroundStyle(DesignColors.accentWarmText)
                }
                .shadow(color: DesignColors.accentWarmText.opacity(0.25), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 5) {
                    Text("WHO YOU ARE")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.2)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Your reading")
                        .font(.raleway("Bold", size: 24, relativeTo: .title2))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                    Text("Open your nature")
                        .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.22), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.32), lineWidth: 0.8))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Warm gradient base — same family as the hero panel
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignColors.accentWarmText.opacity(0.92),
                                    DesignColors.accentWarm,
                                    DesignColors.roseTaupe.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    // Top light highlight
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.22), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                    // Soft warm hotspot
                    RadialGradient(
                        colors: [DesignColors.accent.opacity(0.55), .clear],
                        center: UnitPoint(x: 0.85, y: 0.15),
                        startRadius: 0, endRadius: 220
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
            )
            .shadow(color: DesignColors.accentWarmText.opacity(0.28), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Bonds row — compact ivory row (not a card), opens the Bonds page
    private var meBondsRow: some View {
        Button(action: { showsBonds = true }) {
            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: -14) {
                    ForEach(Array(bonds.prefix(3).enumerated()), id: \.element.id) { idx, r in
                        ZStack {
                            Circle()
                                .fill(DesignColors.background)
                                .frame(width: 48, height: 48)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: meAvatarGradient(for: r.bondType),
                                        center: UnitPoint(x: 0.3, y: 0.3),
                                        startRadius: 3, endRadius: 34
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle().stroke(
                                        LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center),
                                        lineWidth: 0.8
                                    )
                                )
                            Text(r.initial)
                                .font(.raleway("Bold", size: 15, relativeTo: .body))
                                .foregroundStyle(.white)
                        }
                        .zIndex(Double(3 - idx))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR PEOPLE")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.2)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Text("\(wordCount(for: bonds.count)) in your life")
                        .font(.raleway("Bold", size: 17, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignColors.accentWarmText)
                    .frame(width: 40, height: 40)
                    .background(DesignColors.cardWarm, in: Circle())
                    .overlay(Circle().strokeBorder(DesignColors.structure, lineWidth: 0.6))
                    .shadow(color: DesignColors.text.opacity(0.05), radius: 6, x: 0, y: 3)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Natal wheel (unused — kept for compile)
    private var meNatalWheel: some View {
        Button(action: {}) {
            VStack(spacing: 0) {
                // Masthead
                HStack(spacing: 12) {
                    Rectangle().fill(DesignColors.structure).frame(height: 0.6)
                    Text("ARIA  ·  VOL I")
                        .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                        .tracking(2.8)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Rectangle().fill(DesignColors.structure).frame(height: 0.6)
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 26)

                // Natal wheel composition
                ZStack {
                    // Outer decorative ring
                    Circle()
                        .strokeBorder(DesignColors.structure.opacity(0.7), lineWidth: 0.5)
                        .frame(width: 232, height: 232)

                    // 12 tick marks around outer ring
                    ForEach(0..<12) { i in
                        Rectangle()
                            .fill(DesignColors.structure.opacity(0.8))
                            .frame(width: 0.5, height: i % 3 == 0 ? 10 : 6)
                            .offset(y: -116)
                            .rotationEffect(.degrees(Double(i) * 30))
                    }

                    // Inner warm ring
                    Circle()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.35), lineWidth: 0.5)
                        .frame(width: 190, height: 190)

                    // Decorative dots at cardinal positions
                    ForEach([30, 150, 210, 330], id: \.self) { angle in
                        Circle()
                            .fill(DesignColors.accentWarm.opacity(0.65))
                            .frame(width: 3, height: 3)
                            .offset(y: -95)
                            .rotationEffect(.degrees(Double(angle)))
                    }

                    // Center portrait — the "sun" of the chart
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [DesignColors.accentWarmText, DesignColors.accentWarm],
                                    center: UnitPoint(x: 0.3, y: 0.3),
                                    startRadius: 4, endRadius: 76
                                )
                            )
                            .frame(width: 104, height: 104)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .clear],
                                        startPoint: .top, endPoint: .center
                                    ),
                                    lineWidth: 1
                                )
                            )
                        Text(userInitial)
                            .font(.raleway("Bold", size: 40, relativeTo: .largeTitle))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: DesignColors.accentWarmText.opacity(0.35), radius: 16, x: 0, y: 6)
                }
                .frame(width: 240, height: 240)
                .background(
                    RadialGradient(
                        colors: [DesignColors.accent.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0, endRadius: 180
                    )
                    .allowsHitTesting(false)
                )

                Spacer().frame(height: 24)

                // Label
                Text("WHO YOU ARE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.6)
                    .foregroundStyle(DesignColors.accentWarm)

                Spacer().frame(height: 8)

                Text("Your reading")
                    .font(.raleway("Bold", size: 26, relativeTo: .title2))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)

                Spacer().frame(height: 6)

                Text("Written from your chart")
                    .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)

                Spacer().frame(height: 20)

                // Open button — warm pill
                HStack(spacing: 8) {
                    Text("Open the reading")
                        .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(DesignColors.accent, in: Capsule())
                .overlay(Capsule().strokeBorder(DesignColors.accentWarm.opacity(0.4), lineWidth: 0.5))
                .shadow(color: DesignColors.accentWarm.opacity(0.35), radius: 12, x: 0, y: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: Orbital map — bonds as satellites around the user
    private var meOrbitalMap: some View {
        Button(action: { showsBonds = true }) {
            VStack(spacing: 0) {
                // Masthead
                HStack(spacing: 12) {
                    Rectangle().fill(DesignColors.structure).frame(height: 0.6)
                    Text("YOUR ORBIT  ·  \(wordCount(for: bonds.count).uppercased())")
                        .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                        .tracking(2.8)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Rectangle().fill(DesignColors.structure).frame(height: 0.6)
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 24)

                // Orbital composition
                ZStack {
                    // Dashed orbit path
                    Circle()
                        .strokeBorder(
                            DesignColors.accentWarm.opacity(0.25),
                            style: StrokeStyle(lineWidth: 0.7, dash: [2, 5])
                        )
                        .frame(width: 200, height: 200)

                    // Second subtle orbit
                    Circle()
                        .strokeBorder(DesignColors.structure.opacity(0.5), lineWidth: 0.4)
                        .frame(width: 232, height: 232)

                    // User at center — smaller since bonds orbit around
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [DesignColors.accentWarmText, DesignColors.accentWarm],
                                    center: UnitPoint(x: 0.3, y: 0.3),
                                    startRadius: 2, endRadius: 32
                                )
                            )
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center),
                                    lineWidth: 1
                                )
                            )
                        Text(userInitial)
                            .font(.raleway("Bold", size: 18, relativeTo: .title3))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: DesignColors.accentWarmText.opacity(0.3), radius: 10, x: 0, y: 4)

                    // Bond satellites — positioned around the 100-radius orbit
                    ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                        bondSatellite(r, index: idx)
                    }
                }
                .frame(width: 240, height: 240)
                .background(
                    RadialGradient(
                        colors: [DesignColors.accent.opacity(0.22), .clear],
                        center: .center,
                        startRadius: 0, endRadius: 160
                    )
                    .allowsHitTesting(false)
                )

                Spacer().frame(height: 22)

                Text("YOUR PEOPLE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.6)
                    .foregroundStyle(DesignColors.accentWarm)

                Spacer().frame(height: 8)

                Text("Read who they are to you")
                    .font(.raleway("Bold", size: 22, relativeTo: .title3))
                    .tracking(-0.3)
                    .foregroundStyle(DesignColors.text)

                Spacer().frame(height: 20)

                HStack(spacing: 8) {
                    Text("Open your orbit")
                        .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(DesignColors.accent, in: Capsule())
                .overlay(Capsule().strokeBorder(DesignColors.accentWarm.opacity(0.4), lineWidth: 0.5))
                .shadow(color: DesignColors.accentWarm.opacity(0.3), radius: 12, x: 0, y: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func bondSatellite(_ r: BondReading, index: Int) -> some View {
        // Position 4 bonds evenly: -45°, 45°, 135°, 225°
        let angleDeg = Double(index) * 90.0 - 45.0
        let angleRad = angleDeg * .pi / 180.0
        let radius: CGFloat = 100

        return ZStack {
            Circle()
                .fill(DesignColors.background)
                .frame(width: 46, height: 46)
            Circle()
                .fill(
                    RadialGradient(
                        colors: meAvatarGradient(for: r.bondType),
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 2, endRadius: 30
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Circle().stroke(
                        LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center),
                        lineWidth: 0.8
                    )
                )
            Text(r.initial)
                .font(.raleway("Bold", size: 15, relativeTo: .body))
                .foregroundStyle(.white)
        }
        .shadow(color: DesignColors.text.opacity(0.1), radius: 6, x: 0, y: 3)
        .offset(x: CGFloat(cos(angleRad)) * radius, y: CGFloat(sin(angleRad)) * radius)
    }

    // MARK: Reading card (unused, kept for compile) — horizontal cream card with portrait
    private var meReadingCard: some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: 16) {
                // Portrait — small warm monogram
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DesignColors.accentWarmText, DesignColors.accentWarm],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 4, endRadius: 50
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle().stroke(
                                LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center),
                                lineWidth: 0.8
                            )
                        )
                    Text(userInitial)
                        .font(.raleway("Bold", size: 22, relativeTo: .title3))
                        .foregroundStyle(.white)
                }
                .shadow(color: DesignColors.accentWarmText.opacity(0.3), radius: 10, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("WHO YOU ARE")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Text("Your reading")
                        .font(.raleway("Bold", size: 20, relativeTo: .title3))
                        .tracking(-0.3)
                        .foregroundStyle(DesignColors.text)
                    Text("A long-form read of your nature")
                        .font(.raleway("Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignColors.accentWarm)
                    .frame(width: 40, height: 40)
                    .background(DesignColors.background.opacity(0.55), in: Circle())
                    .overlay(Circle().strokeBorder(DesignColors.accent.opacity(0.45), lineWidth: 0.6))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(DesignColors.cardWarm)
                    // Warm radial glow from the portrait side
                    RadialGradient(
                        colors: [DesignColors.accent.opacity(0.3), .clear],
                        center: UnitPoint(x: 0.15, y: 0.3),
                        startRadius: 0, endRadius: 200
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(DesignColors.structure, lineWidth: 0.8)
            )
            .shadow(color: DesignColors.text.opacity(0.07), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: Bonds — masthead + avatar cluster + arrow (editorial row, no card)
    private var meBondsMasthead: some View {
        Button(action: { showsBonds = true }) {
            VStack(spacing: 16) {
                // Masthead row: rule · caps · rule
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(DesignColors.structure)
                        .frame(height: 0.6)
                    Text("YOUR PEOPLE  ·  \(wordCount(for: bonds.count).uppercased())")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarmText)
                        .fixedSize()
                    Rectangle()
                        .fill(DesignColors.structure)
                        .frame(height: 0.6)
                }
                .frame(maxWidth: .infinity)

                // Bond row — centered cluster + arrow
                HStack(alignment: .center, spacing: 18) {
                    HStack(spacing: -14) {
                        ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                            ZStack {
                                Circle()
                                    .fill(DesignColors.background)
                                    .frame(width: 48, height: 48)
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: meAvatarGradient(for: r.bondType),
                                            center: UnitPoint(x: 0.3, y: 0.3),
                                            startRadius: 3, endRadius: 34
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle().stroke(
                                            LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center),
                                            lineWidth: 0.8
                                        )
                                    )
                                Text(r.initial)
                                    .font(.raleway("Bold", size: 15, relativeTo: .body))
                                    .foregroundStyle(.white)
                            }
                            .zIndex(Double(4 - idx))
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text("Open")
                            .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Reading opening — magazine spread, masthead + calm chapter (unused)
    private var meReadingOpening: some View {
        ZStack {
            // Very subtle warm wash — depth without visual weight
            RadialGradient(
                colors: [DesignColors.accent.opacity(0.18), .clear],
                center: UnitPoint(x: 0.3, y: 0.4),
                startRadius: 0, endRadius: 260
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Masthead — rule · caps · rule
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(DesignColors.structure)
                        .frame(height: 0.6)
                    Text("ARIA  ·  VOL I")
                        .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                        .tracking(2.8)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Rectangle()
                        .fill(DesignColors.structure)
                        .frame(height: 0.6)
                }
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 44)

                // Chapter title — elegant, calm
                Text("Chapter I")
                    .font(.raleway("Bold", size: 32, relativeTo: .title))
                    .tracking(-0.6)
                    .foregroundStyle(DesignColors.text)

                Spacer().frame(height: 6)

                Text("A reading for \(displayName)")
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)

                Spacer().frame(height: 32)

                // Section eyebrow
                Text("WHO YOU ARE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.4)
                    .foregroundStyle(DesignColors.accentWarm)

                Spacer().frame(height: 14)

                // Preview paragraph
                Text("You lead with warmth and notice what others don't. Beneath the softness, a spine — you just don't show it until you have to.")
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.85))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 26)

                // Ornament divider — rule · ✦ · rule
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(DesignColors.structure)
                        .frame(width: 38, height: 0.6)
                    Image(systemName: "sparkle")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(DesignColors.accentWarm.opacity(0.7))
                    Rectangle()
                        .fill(DesignColors.structure)
                        .frame(width: 38, height: 0.6)
                }
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 22)

                // Continue link
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Text("Turn the page")
                            .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Decorative chapter break
    private var meChapterDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(DesignColors.structure)
                .frame(height: 0.6)
            Circle()
                .fill(DesignColors.accentWarm.opacity(0.6))
                .frame(width: 3, height: 3)
            Rectangle()
                .fill(DesignColors.structure)
                .frame(height: 0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private var displayName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "You" : trimmed
    }

    private func wordCount(for n: Int) -> String {
        switch n {
        case 0: return "None"
        case 1: return "One"
        case 2: return "Two"
        case 3: return "Three"
        case 4: return "Four"
        case 5: return "Five"
        case 6: return "Six"
        case 7: return "Seven"
        case 8: return "Eight"
        case 9: return "Nine"
        default: return "\(n)"
        }
    }

    // MARK: Reading cover — editorial, centered, the Me page hero (unused — kept for compile)
    private var meReadingCover: some View {
        Button(action: {}) {
            VStack(spacing: 0) {
                // Editorial top rail: caps · hairline · caps
                HStack(spacing: 10) {
                    Text("WHO YOU ARE")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarm)
                    Rectangle()
                        .fill(DesignColors.structure)
                        .frame(height: 0.6)
                    Text("READING")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(DesignColors.accentWarmText)
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)

                Spacer().frame(height: 30)

                // Monogram — embossed seal
                ZStack {
                    Circle()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.35), lineWidth: 1)
                        .frame(width: 90, height: 90)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DesignColors.accentWarmText, DesignColors.accentWarm],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 4, endRadius: 72
                            )
                        )
                        .frame(width: 78, height: 78)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .clear],
                                        startPoint: .top, endPoint: .center
                                    ),
                                    lineWidth: 1
                                )
                        )
                    Text(userInitial)
                        .font(.raleway("Bold", size: 34, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                }
                .shadow(color: DesignColors.accentWarmText.opacity(0.28), radius: 14, x: 0, y: 6)

                Spacer().frame(height: 22)

                // Display name
                Text(userName)
                    .font(.raleway("Bold", size: 40, relativeTo: .largeTitle))
                    .tracking(-1)
                    .foregroundStyle(DesignColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 6)

                // Subtitle — italic-feel via medium weight, not serif italic
                Text("Warmth, and a quiet fire.")
                    .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)
                    .tracking(0.2)

                Spacer().frame(height: 26)

                // Decorative divider — rule · dot · rule
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(DesignColors.structure)
                        .frame(width: 36, height: 0.6)
                    Circle()
                        .fill(DesignColors.accentWarm.opacity(0.75))
                        .frame(width: 3, height: 3)
                    Rectangle()
                        .fill(DesignColors.structure)
                        .frame(width: 36, height: 0.6)
                }

                Spacer().frame(height: 24)

                // Preview lines — soft editorial taste of the reading
                VStack(spacing: 10) {
                    Text("You lead with warmth and notice what others don't.")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Beneath the softness, a spine — you just don't show it until you have to.")
                        .font(.raleway("Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 30)

                Spacer().frame(height: 26)

                // Open affordance
                HStack(spacing: 8) {
                    Text("Open the full reading")
                        .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarmText)

                Spacer().frame(height: 28)
            }
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(DesignColors.cardWarm)
                    // Warm top glow from monogram
                    RadialGradient(
                        colors: [DesignColors.accent.opacity(0.25), .clear],
                        center: UnitPoint(x: 0.5, y: 0.22),
                        startRadius: 0, endRadius: 220
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    // Subtle light wash at the very top
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .clear],
                                startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35)
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(DesignColors.structure, lineWidth: 1)
            )
            .shadow(color: DesignColors.text.opacity(0.1), radius: 26, x: 0, y: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: Bonds — Chapter II (no card, consistent with reading)
    private var meBondsEntry: some View {
        Button(action: { showsBonds = true }) {
            VStack(alignment: .leading, spacing: 0) {
                // Chapter title
                Text("Chapter II")
                    .font(.raleway("Bold", size: 32, relativeTo: .title))
                    .tracking(-0.6)
                    .foregroundStyle(DesignColors.text)

                Spacer().frame(height: 6)

                Text("The people in your orbit")
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)

                Spacer().frame(height: 32)

                // Section eyebrow
                Text("YOUR PEOPLE  ·  \(wordCount(for: bonds.count).uppercased())")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.4)
                    .foregroundStyle(DesignColors.accentWarm)

                Spacer().frame(height: 18)

                HStack(alignment: .center, spacing: 0) {
                    HStack(spacing: -14) {
                        ForEach(Array(bonds.prefix(4).enumerated()), id: \.element.id) { idx, r in
                            ZStack {
                                Circle()
                                    .fill(DesignColors.background)
                                    .frame(width: 48, height: 48)
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: meAvatarGradient(for: r.bondType),
                                            center: UnitPoint(x: 0.3, y: 0.3),
                                            startRadius: 3, endRadius: 34
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle().stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.4), .clear],
                                                startPoint: .top, endPoint: .center
                                            ),
                                            lineWidth: 0.8
                                        )
                                    )
                                Text(r.initial)
                                    .font(.raleway("Bold", size: 15, relativeTo: .body))
                                    .foregroundStyle(.white)
                            }
                            .zIndex(Double(4 - idx))
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text("Turn the page")
                            .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarmText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func meAvatarGradient(for bondType: String) -> [Color] {
        switch bondType.lowercased() {
        case "soulmate": return [DesignColors.accent, DesignColors.accentWarm]
        case "extraordinary": return [DesignColors.roseTaupeLight, DesignColors.accentWarm]
        case "powerful": return [DesignColors.accentWarm, DesignColors.accentWarmText]
        case "meaningful": return [DesignColors.structure, DesignColors.roseTaupe]
        default: return [DesignColors.accent, DesignColors.accentWarm]
        }
    }

    // PEOPLE big card — primary daily-use surface with real insights per bond
    private var peopleBigCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — bold, editorial
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR PEOPLE, TODAY")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(1.8)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Text("What's alive between you.")
                        .font(.raleway("Bold", size: 24, relativeTo: .title2))
                        .tracking(-0.4)
                        .foregroundStyle(DesignColors.text)
                }
                Spacer()
                Text("\(bonds.count)")
                    .font(.raleway("Bold", size: 22, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text.opacity(0.25))
            }

            Spacer().frame(height: 22)

            // Per-bond rows — avatar + name + bond type + today insight + chevron
            VStack(spacing: 0) {
                ForEach(Array(bonds.enumerated()), id: \.element.id) { idx, r in
                    Button(action: { onOpenBond(r) }) {
                        peopleInsightRow(r, insight: todayInsight(for: idx))
                    }
                    .buttonStyle(.plain)

                    if idx < bonds.count - 1 {
                        Rectangle()
                            .fill(DesignColors.divider.opacity(0.4))
                            .frame(height: 0.5)
                            .padding(.vertical, 16)
                    }
                }
            }

            Spacer().frame(height: 22)

            // Add — inline at the bottom of the card
            Button(action: { isAddBondVisible = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                DesignColors.accentWarm.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Add someone new")
                            .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                            .foregroundStyle(DesignColors.text)
                        Text("By their birthday.")
                            .font(.raleway("Regular", size: 11, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignColors.text.opacity(0.25))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .liquidGlass(cornerRadius: 28)
        .shadow(color: DesignColors.text.opacity(0.09), radius: 22, x: 0, y: 10)
    }

    // Row used inside the big people card
    private func peopleInsightRow(_ r: BondReading, insight: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(r.color.opacity(0.3), lineWidth: 0.5)
                    .frame(width: 48, height: 48)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [r.color.opacity(0.95), r.color.opacity(0.75)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: r.color.opacity(0.25), radius: 5, x: 0, y: 2)
                Text(r.initial)
                    .font(.raleway("Bold", size: 14, relativeTo: .body))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(r.name)
                        .font(.raleway("Bold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                    Text("·")
                        .foregroundStyle(DesignColors.text.opacity(0.3))
                    Text(r.bondType.lowercased())
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                        .foregroundStyle(r.color)
                }
                Text(insight)
                    .font(.raleway("Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.78))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignColors.text.opacity(0.25))
                .padding(.top, 16)
        }
    }

    // CHAPTER ONE — "You" as editorial magazine spread
    private var chapterOne_You: some View {
        HStack(alignment: .top, spacing: 14) {
            // Chapter mark — narrow column with tracked caps + hairline
            VStack(alignment: .leading, spacing: 4) {
                Text("ONE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(2.2)
                    .foregroundStyle(DesignColors.accentWarm)
                Rectangle()
                    .fill(DesignColors.accentWarm.opacity(0.7))
                    .frame(width: 20, height: 1)
            }
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 0) {
                // Giant magazine title
                Text("You.")
                    .font(.raleway("Bold", size: 56, relativeTo: .largeTitle))
                    .tracking(-1.4)
                    .foregroundStyle(DesignColors.text)

                Spacer().frame(height: 22)

                // Natal body — narrow reading column feel
                Text("You lead with warmth and notice what others don't. Beneath the softness there's a spine — you just don't show it until you have to.")
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.9))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 16)

                Text("You were born in transition, and it shows in how you decide, how you love, how you recover.")
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.68))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 22)

                // Signed, dated — magazine signature
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(DesignColors.text.opacity(0.3))
                        .frame(width: 14, height: 0.5)
                    Text("written from your chart, for \(userName)")
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .italic()
                        .foregroundStyle(DesignColors.text.opacity(0.5))
                }

                Spacer().frame(height: 22)

                Button(action: {}) {
                    HStack(spacing: 7) {
                        Text("Continue reading")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.accentWarm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // CHAPTER TWO — "Your people" as constellation map
    private var chapterTwo_People: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TWO")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.2)
                        .foregroundStyle(DesignColors.accentWarm)
                    Rectangle()
                        .fill(DesignColors.accentWarm.opacity(0.7))
                        .frame(width: 20, height: 1)
                }
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Your people.")
                        .font(.raleway("Bold", size: 44, relativeTo: .largeTitle))
                        .tracking(-1)
                        .foregroundStyle(DesignColors.text)

                    Spacer().frame(height: 6)

                    Text("Hairlines show how close each one is to you today.")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                        .lineSpacing(2)
                }
                Spacer()
            }

            Spacer().frame(height: 24)

            // Constellation — full width
            constellationMap
                .frame(height: 360)
                .padding(.horizontal, -4)

            Spacer().frame(height: 20)

            // Featured today insight below constellation
            if let featured = bonds.first {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(featured.color.opacity(0.85))
                        .frame(width: 2)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text("TODAY")
                                .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                                .tracking(1.5)
                                .foregroundStyle(featured.color)
                            Circle().fill(featured.color).frame(width: 2.5, height: 2.5)
                            Text(featured.name.uppercased())
                                .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                                .tracking(1.5)
                                .foregroundStyle(DesignColors.text.opacity(0.5))
                        }
                        Text("There's a softness between you today. She'll reach out before you do — let her.")
                            .font(.raleway("Medium", size: 15, relativeTo: .body))
                            .foregroundStyle(DesignColors.text.opacity(0.85))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // Constellation map — YOU at center, bonds as satellite stars with hairline connections
    private var constellationMap: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center = CGPoint(x: w/2, y: h/2)

            // Soft asymmetric positions for up to 4 bonds — looks like a natural constellation
            let positions: [CGPoint] = [
                CGPoint(x: w*0.18, y: h*0.22),
                CGPoint(x: w*0.82, y: h*0.18),
                CGPoint(x: w*0.15, y: h*0.74),
                CGPoint(x: w*0.84, y: h*0.78),
            ]

            ZStack {
                // Soft ambient glow behind the central YOU node
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DesignColors.accentWarm.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 0, endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .position(center)

                // Hairline connections from center to each bond
                ForEach(Array(bonds.prefix(4).enumerated()), id: \.offset) { idx, r in
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: positions[idx])
                    }
                    .stroke(
                        r.color.opacity(0.35),
                        style: StrokeStyle(lineWidth: 0.7, lineCap: .round, dash: [1.5, 3])
                    )
                }

                // Each bond as a star
                ForEach(Array(bonds.prefix(4).enumerated()), id: \.offset) { idx, r in
                    Button(action: { onOpenBond(r) }) {
                        VStack(spacing: 7) {
                            ZStack {
                                Circle()
                                    .strokeBorder(r.color.opacity(0.3), lineWidth: 0.5)
                                    .frame(width: 64, height: 64)
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [r.color.opacity(0.95), r.color.opacity(0.75)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)
                                    .shadow(color: r.color.opacity(0.28), radius: 8, x: 0, y: 3)
                                Text(r.initial)
                                    .font(.raleway("Bold", size: 16, relativeTo: .body))
                                    .foregroundStyle(.white)
                            }
                            Text(r.name)
                                .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                                .foregroundStyle(DesignColors.text)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(positions[idx])
                }

                // Central YOU node — larger, signature
                ZStack {
                    Circle()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.25), lineWidth: 0.5)
                        .frame(width: 92, height: 92)
                    Circle()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.4), lineWidth: 0.5)
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarmText, DesignColors.accentWarm],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 66, height: 66)
                        .shadow(color: DesignColors.accentWarmText.opacity(0.32), radius: 12, x: 0, y: 5)
                    Text(userInitial)
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .foregroundStyle(.white)
                }
                .position(center)

                // Add tile — dashed satellite at the bottom
                Button(action: { isAddBondVisible = true }) {
                    VStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    DesignColors.accentWarm.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                )
                                .frame(width: 52, height: 52)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DesignColors.accentWarm)
                        }
                        Text("Add")
                            .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                }
                .buttonStyle(.plain)
                .position(x: w/2, y: h*0.95)
            }
        }
    }

    // YOU — natal reading as a warm editorial letter (singular, static, distinct from hero and bonds)
    private var youLetter: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 0) {
                // Letter header — caps + signature line
                HStack(spacing: 10) {
                    Text("A LETTER ABOUT YOU")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(1.8)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Rectangle()
                        .fill(DesignColors.accentWarm.opacity(0.4))
                        .frame(height: 0.5)
                }

                Spacer().frame(height: 22)

                // Editorial passage — beautiful body text, large
                Text("You lead with warmth and notice what others don't. Beneath the softness there's a spine — you just don't show it until you have to.")
                    .font(.raleway("Medium", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.9))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 14)

                Text("You were born in transition, and it shows in how you decide, how you love, how you recover.")
                    .font(.raleway("Medium", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.68))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 24)

                // Signature — feels like it was written for them
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(DesignColors.text.opacity(0.3))
                        .frame(width: 14, height: 0.5)
                    Text("written from your chart, for \(userName)")
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .italic()
                        .foregroundStyle(DesignColors.text.opacity(0.5))
                }

                Spacer().frame(height: 20)

                HStack(spacing: 7) {
                    Text("Continue reading")
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarm)
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignColors.cardWarm.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(DesignColors.divider.opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: DesignColors.text.opacity(0.06), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // YOUR PEOPLE — caps header + horizontal paged carousel (bonds only + add)
    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("YOUR PEOPLE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(1.8)
                    .foregroundStyle(DesignColors.accentWarmText)
                Rectangle()
                    .fill(DesignColors.accentWarm.opacity(0.4))
                    .frame(height: 0.5)
                Text("SWIPE")
                    .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                    .tracking(1.3)
                    .foregroundStyle(DesignColors.text.opacity(0.35))
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignColors.text.opacity(0.35))
            }
            .padding(.horizontal, 24)

            peopleCarousel
        }
    }

    // Bond-only carousel — pages: each bond, then Add
    private var carouselPageCount: Int { bonds.count + 1 }

    private var peopleCarousel: some View {
        VStack(spacing: 16) {
            TabView(selection: $carouselPage) {
                ForEach(Array(bonds.enumerated()), id: \.element.id) { idx, r in
                    bondStoryPage(r, idx: idx)
                        .tag(idx)
                }
                addStoryPage
                    .tag(bonds.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 420)

            HStack(spacing: 6) {
                ForEach(0..<carouselPageCount, id: \.self) { i in
                    Capsule()
                        .fill(
                            i == carouselPage
                                ? DesignColors.accentWarm
                                : DesignColors.text.opacity(0.18)
                        )
                        .frame(width: i == carouselPage ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: carouselPage)
                }
            }
        }
    }

    // Pages 1..N — one per bond, full focus on their today-reading
    private func bondStoryPage(_ r: BondReading, idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .strokeBorder(r.color.opacity(0.3), lineWidth: 0.5)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [r.color.opacity(0.95), r.color.opacity(0.75)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)
                        .shadow(color: r.color.opacity(0.3), radius: 10, x: 0, y: 4)
                    Text(r.initial)
                        .font(.raleway("Bold", size: 24, relativeTo: .title))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle().fill(r.color).frame(width: 4, height: 4)
                        Text("\(r.bondType.uppercased()) BOND")
                            .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                            .tracking(1.4)
                            .foregroundStyle(r.color)
                    }
                    Text(r.name)
                        .font(.raleway("Bold", size: 26, relativeTo: .title))
                        .tracking(-0.3)
                        .foregroundStyle(DesignColors.text)
                }
                Spacer()
            }

            Spacer().frame(height: 26)

            // Today insight — real content per bond
            Text(todayInsight(for: idx))
                .font(.raleway("Medium", size: 17, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.9))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: { onOpenBond(r) }) {
                HStack(spacing: 10) {
                    Text("Read what's alive between you")
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignColors.background)
                .padding(.horizontal, 20)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(DesignColors.accentWarm, in: Capsule())
                .shadow(color: DesignColors.accentWarm.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .liquidGlass(cornerRadius: 32)
        .padding(.horizontal, 20)
        .shadow(color: DesignColors.text.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    // Last page — prompt to add someone new
    private var addStoryPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .strokeBorder(
                        DesignColors.accentWarm.opacity(0.6),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
                    .frame(width: 78, height: 78)
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(DesignColors.accentWarm)
            }

            Spacer().frame(height: 22)

            Text("ADD SOMEONE NEW")
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(1.8)
                .foregroundStyle(DesignColors.accentWarmText)

            Spacer().frame(height: 6)

            Text("By their birthday.")
                .font(.raleway("Bold", size: 26, relativeTo: .title))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)

            Spacer().frame(height: 16)

            Text("See how you move together. What's steady between you, what's shifting, what to say or leave unsaid today.")
                .font(.raleway("Medium", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.8))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: { isAddBondVisible = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add a bond")
                        .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                }
                .foregroundStyle(DesignColors.background)
                .padding(.horizontal, 20)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(DesignColors.accentWarm, in: Capsule())
                .shadow(color: DesignColors.accentWarm.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .liquidGlass(cornerRadius: 32)
        .padding(.horizontal, 20)
        .shadow(color: DesignColors.text.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    // You panel — content-first journal: real natal preview + real bond insights
    private var youPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section 1: WHO YOU ARE — real natal preview
            Text("WHO YOU ARE")
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(1.8)
                .foregroundStyle(DesignColors.accentWarmText)

            Spacer().frame(height: 14)

            // Real natal opener — conversational, speaks to the user directly
            Text("You lead with warmth and notice what others don't. Beneath the softness there's a spine — you just don't show it until you have to.")
                .font(.raleway("Medium", size: 17, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.9))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 8)

            Text("The full reading goes deeper: your rhythms, your tensions, what fuels you, what slows you down.")
                .font(.raleway("Regular", size: 13, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text.opacity(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 14)

            Button(action: {}) {
                HStack(spacing: 7) {
                    Text("Read your full story")
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarm)
            }
            .buttonStyle(.plain)

            // Delicate divider with soft centered accent
            HStack(spacing: 10) {
                Rectangle()
                    .fill(DesignColors.divider.opacity(0.5))
                    .frame(height: 0.5)
                Circle()
                    .fill(DesignColors.accentWarm.opacity(0.55))
                    .frame(width: 3, height: 3)
                Rectangle()
                    .fill(DesignColors.divider.opacity(0.5))
                    .frame(height: 0.5)
            }
            .padding(.vertical, 26)

            // Section 2: YOUR PEOPLE — per-bond insight entries
            HStack(alignment: .firstTextBaseline) {
                Text("YOUR PEOPLE, TODAY")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(1.8)
                    .foregroundStyle(DesignColors.accentWarmText)
                Spacer()
                Text("\(bonds.count)")
                    .font(.raleway("Bold", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.text.opacity(0.35))
            }

            Spacer().frame(height: 18)

            // Per-bond editorial rows — real content per person
            VStack(spacing: 22) {
                ForEach(Array(bonds.enumerated()), id: \.element.id) { idx, r in
                    Button(action: { onOpenBond(r) }) {
                        bondInsightRow(r, todayInsight: todayInsight(for: idx))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer().frame(height: 22)

            // Add someone — inline, discreet, clearly actionable
            Button(action: { isAddBondVisible = true }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                DesignColors.accentWarm.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                            .frame(width: 38, height: 38)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Add someone new")
                            .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                            .foregroundStyle(DesignColors.text)
                        Text("By their birthday. See how you move together.")
                            .font(.raleway("Regular", size: 11, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // Per-bond editorial row: small avatar + name + bond type + one real today-sentence
    private func bondInsightRow(_ r: BondReading, todayInsight: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Small avatar with soft glow ring
            ZStack {
                Circle()
                    .strokeBorder(r.color.opacity(0.3), lineWidth: 0.5)
                    .frame(width: 44, height: 44)
                Text(r.initial)
                    .font(.raleway("Bold", size: 14, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        LinearGradient(
                            colors: [r.color.opacity(0.95), r.color.opacity(0.75)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .shadow(color: r.color.opacity(0.25), radius: 5, x: 0, y: 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Name + bond type — single readable line
                HStack(spacing: 6) {
                    Text(r.name)
                        .font(.raleway("Bold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                    Text("·")
                        .foregroundStyle(DesignColors.text.opacity(0.3))
                    Text(r.bondType.lowercased())
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                        .foregroundStyle(r.color)
                }

                // Real today-insight for this bond
                Text(todayInsight)
                    .font(.raleway("Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.8))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignColors.text.opacity(0.25))
                .padding(.top, 14)
        }
    }

    // Mock today-insights per bond — in real app these come from the daily transit engine
    private func todayInsight(for idx: Int) -> String {
        switch idx {
        case 0: return "There's a softness between you today. She'll reach out before you do — let her."
        case 1: return "She might need space today. Give her room — it's not about you."
        case 2: return "A good day to call. She has something on her mind she hasn't said yet."
        case 3: return "Check in. She's thinking of you more than she shows."
        default: return r_placeholder
        }
    }
    private var r_placeholder: String { "Something between you is shifting today." }

    // Essence — clean typography-driven section, no emblems, no chips (Apple/Awwwards)
    private var essenceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR ESSENCE")
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(1.8)
                .foregroundStyle(DesignColors.accentWarmText)

            Spacer().frame(height: 14)

            Text(userName)
                .font(.raleway("Bold", size: 36, relativeTo: .largeTitle))
                .tracking(-0.5)
                .foregroundStyle(DesignColors.text)

            Spacer().frame(height: 6)

            Text("The full picture of you.")
                .font(.raleway("Medium", size: 15, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text.opacity(0.55))

            Spacer().frame(height: 22)

            Text("You lead with warmth and notice what others don't. Beneath the softness there's a spine — you just don't show it until you have to.")
                .font(.raleway("Medium", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.82))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 24)

            // Thin accent leading into the action
            HStack(spacing: 12) {
                Rectangle()
                    .fill(DesignColors.accentWarm.opacity(0.5))
                    .frame(width: 28, height: 1)
                HStack(spacing: 7) {
                    Text("Read your essence")
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarm)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Circle — bonds row, clean and parallel structure with essence
    private var circleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR CIRCLE")
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(1.8)
                .foregroundStyle(DesignColors.accentWarmText)

            Spacer().frame(height: 14)

            Text("The people\nyou move with.")
                .font(.raleway("Bold", size: 28, relativeTo: .largeTitle))
                .tracking(-0.4)
                .foregroundStyle(DesignColors.text)
                .lineSpacing(2)

            Spacer().frame(height: 22)

            // Horizontal row of portraits + inline add
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(bonds, id: \.id) { r in
                        Button(action: { onOpenBond(r) }) {
                            bondPortraitTile(r)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { isAddBondVisible = true }) {
                        addPortraitTileInline
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollClipDisabled()

            Spacer().frame(height: 24)

            // Featured today-insight — one line, quiet
            if let featured = bonds.first {
                Text("Today, \(featured.name) is close. Let her reach first.")
                    .font(.raleway("Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.72))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer().frame(height: 18)

            HStack(spacing: 12) {
                Rectangle()
                    .fill(DesignColors.accentWarm.opacity(0.5))
                    .frame(width: 28, height: 1)
                HStack(spacing: 7) {
                    Text("See what's alive")
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarm)
                Spacer()
            }
        }
    }

    // Circular avatar portrait with name beneath
    private func bondPortraitTile(_ r: BondReading) -> some View {
        VStack(spacing: 10) {
            Text(r.initial)
                .font(.raleway("Bold", size: 20, relativeTo: .title3))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(
                        colors: [r.color.opacity(0.95), r.color.opacity(0.75)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: r.color.opacity(0.28), radius: 10, x: 0, y: 4)

            Text(r.name)
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.text)
        }
    }

    // Plus tile sized identically to portraits — fits naturally at the end of the row
    private var addPortraitTileInline: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .strokeBorder(
                        DesignColors.accentWarm.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                    .frame(width: 64, height: 64)
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignColors.accentWarm)
            }
            Text("Add")
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.accentWarm)
        }
    }

    // Featured bond insight — one sentence with a colored accent bar on the left
    private func featuredInsight(_ r: BondReading) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 1)
                .fill(r.color.opacity(0.8))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("CLOSE TODAY")
                        .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                        .tracking(1.5)
                        .foregroundStyle(r.color)
                    Circle().fill(r.color).frame(width: 3, height: 3)
                    Text(r.name.uppercased())
                        .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                        .tracking(1.5)
                        .foregroundStyle(DesignColors.text.opacity(0.55))
                }

                Text("There's a softness between you today. She'll reach out before you do — let her.")
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text("Read what's alive")
                        .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 4)
    }

    // Who you are — the permanent natal reading, prominent but calm (Raleway only)
    private var whoYouAreSection: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 0) {
                Text("WHO YOU ARE")
                    .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                    .tracking(1.8)
                    .foregroundStyle(DesignColors.accentWarmText)

                Spacer().frame(height: 12)

                Text("The full picture\nof you.")
                    .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                    .tracking(-0.3)
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(2)

                Spacer().frame(height: 18)

                Text("You lead with warmth and notice what others don't. Beneath the softness there's a spine — you just don't show it until you have to.")
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.82))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 20)

                Text("Written once, from your birth chart. Yours to return to anytime.")
                    .font(.raleway("Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(2)

                Spacer().frame(height: 22)

                HStack(spacing: 7) {
                    Text("Read the full picture")
                        .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // You, with others — simple, user-friendly bonds entry on Me (Raleway only)
    private var youWithOthersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOU, WITH OTHERS")
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(1.8)
                .foregroundStyle(DesignColors.accentWarmText)

            Spacer().frame(height: 12)

            Text("The people\nin your life.")
                .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .lineSpacing(2)

            Spacer().frame(height: 10)

            Text("Add someone by their birthday and see how you show up together.")
                .font(.raleway("Regular", size: 13, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(3)
                .padding(.trailing, 20)

            Spacer().frame(height: 24)

            // Existing bonds — compact list rows
            if !bonds.isEmpty {
                VStack(spacing: 10) {
                    ForEach(bonds.prefix(4), id: \.id) { r in
                        Button(action: { onOpenBond(r) }) {
                            bondRow(r)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer().frame(height: 14)
            }

            // Primary CTA — unmissable, warm
            Button(action: { isAddBondVisible = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text(bonds.isEmpty ? "Add your first bond" : "Add another bond")
                        .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                }
                .foregroundStyle(DesignColors.background)
                .padding(.horizontal, 22)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(DesignColors.accentWarm, in: Capsule())
                .shadow(color: DesignColors.accentWarm.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    // Simple bond row — avatar + name + bond type + chevron
    private func bondRow(_ r: BondReading) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(r.initial)
                .font(.raleway("Bold", size: 16, relativeTo: .body))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [r.color.opacity(0.95), r.color.opacity(0.75)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: r.color.opacity(0.22), radius: 5, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(r.name)
                    .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)

                HStack(spacing: 5) {
                    Circle().fill(r.color).frame(width: 4, height: 4)
                    Text("\(r.bondType.uppercased()) BOND")
                        .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                        .tracking(1.3)
                        .foregroundStyle(r.color)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColors.text.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignColors.cardWarm.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(DesignColors.divider.opacity(0.45), lineWidth: 0.5)
        )
    }

    // Unified "people" zone — section header with natal chip + horizontal bond cards
    private var peopleZone: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header row: title + natal chip (always accessible, top-right)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your people")
                        .font(.raleway("Bold", size: 22, relativeTo: .title2))
                        .tracking(-0.3)
                        .foregroundStyle(DesignColors.text)
                    Text("Who's close, how you move together.")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                Spacer()
                coreReadingChip
            }
            .padding(.horizontal, 20)

            // Horizontal scroll of bond portraits
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(bonds.enumerated()), id: \.element.id) { idx, r in
                        Button(action: { onOpenBond(r) }) {
                            bondPortrait(r, featured: idx == 0)
                        }
                        .buttonStyle(.plain)
                    }

                    // Inline add tile — same height as portraits
                    addPortraitTile
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
        }
    }

    // Small pill in header — discreet access to natal reading
    private var coreReadingChip: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Your reading")
                    .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
            }
            .foregroundStyle(DesignColors.accentWarmText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignColors.cardWarm.opacity(0.7), in: Capsule())
            .overlay(Capsule().strokeBorder(DesignColors.accent.opacity(0.4), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // Bond portrait card — featured is wider with quote, others are compact
    private func bondPortrait(_ r: BondReading, featured: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Avatar with orbit ring
            ZStack {
                Circle()
                    .strokeBorder(r.color.opacity(0.3), lineWidth: 0.5)
                    .frame(width: 62, height: 62)
                Text(r.initial)
                    .font(.raleway("Bold", size: 18, relativeTo: .title3))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(
                            colors: [r.color.opacity(0.95), r.color.opacity(0.75)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .shadow(color: r.color.opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)

            Spacer().frame(height: 14)

            Text(r.name)
                .font(.raleway("Bold", size: 18, relativeTo: .title3))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 18)

            HStack(spacing: 5) {
                Circle().fill(r.color).frame(width: 4, height: 4)
                Text(r.bondType.uppercased())
                    .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                    .tracking(1.3)
                    .foregroundStyle(r.color)
            }
            .padding(.top, 3)
            .padding(.horizontal, 18)

            if featured {
                Text("\u{201C}There's a softness between you today. Let them reach first.\u{201D}")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(DesignColors.text.opacity(0.78))
                    .lineSpacing(3)
                    .lineLimit(3)
                    .padding(.top, 12)
                    .padding(.horizontal, 18)
            }

            Spacer(minLength: 18)
        }
        .frame(width: featured ? 240 : 164, height: 220, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignColors.cardWarm.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(DesignColors.divider.opacity(0.45), lineWidth: 0.5)
        )
    }

    // Inline add tile sized to match portraits
    private var addPortraitTile: some View {
        Button(action: onAddBond) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            DesignColors.accentWarm.opacity(0.55),
                            style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
                        )
                        .frame(width: 52, height: 52)
                    Text("+")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(DesignColors.accentWarm)
                }
                Text("Add a bond")
                    .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.accentWarm)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 124, height: 220)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignColors.cardWarm.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        DesignColors.accentWarm.opacity(0.25),
                        style: StrokeStyle(lineWidth: 0.6, dash: [4, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // Editorial footer — soft, quiet access to the permanent natal reading
    private var coreReadingFooter: some View {
        Button(action: {}) {
            VStack(spacing: 18) {
                // Thin divider with a small accent dot in the middle
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(DesignColors.divider.opacity(0.6))
                        .frame(height: 0.5)
                    Circle()
                        .fill(DesignColors.accentWarm.opacity(0.7))
                        .frame(width: 4, height: 4)
                    Rectangle()
                        .fill(DesignColors.divider.opacity(0.6))
                        .frame(height: 0.5)
                }

                VStack(spacing: 6) {
                    Text("The longer story of who you are.")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(DesignColors.text.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text("A reading of your nature, written once. Open it when you want to be reminded.")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 30)
                }

                HStack(spacing: 6) {
                    Text("Read your core reading")
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // Bonds — editorial vignette, no cards, no icons
    private var bondsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Editorial header — single italic line
            Text("Close today.")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            Text("The bond most alive in today's air.")
                .font(.raleway("Regular", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 28)

            // Featured bond — no card, flows on page
            if let featured = bonds.first {
                featuredBondVignette(featured)
            }

            // Thin divider
            Rectangle()
                .fill(DesignColors.divider.opacity(0.6))
                .frame(height: 0.5)
                .padding(.vertical, 28)

            // Other bonds — minimal horizontal row with names below avatars
            if bonds.count > 1 {
                otherBondsRow(Array(bonds.dropFirst()))
            } else {
                addBondCTA
            }
        }
    }

    // Featured bond — pure typography + avatar, no card background
    private func featuredBondVignette(_ r: BondReading) -> some View {
        Button(action: { onOpenBond(r) }) {
            VStack(alignment: .leading, spacing: 0) {
                // Large avatar with concentric orbit rings — the "activated" symbol
                ZStack {
                    Circle()
                        .strokeBorder(r.color.opacity(0.18), lineWidth: 0.5)
                        .frame(width: 108, height: 108)
                    Circle()
                        .strokeBorder(r.color.opacity(0.35), lineWidth: 0.5)
                        .frame(width: 90, height: 90)
                    Text(r.initial)
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(
                            LinearGradient(
                                colors: [r.color.opacity(0.95), r.color.opacity(0.75)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(color: r.color.opacity(0.3), radius: 10, x: 0, y: 4)
                }
                .padding(.bottom, 22)

                // Name as editorial headline
                Text(r.name)
                    .font(.raleway("Bold", size: 34, relativeTo: .largeTitle))
                    .tracking(-0.5)
                    .foregroundStyle(DesignColors.text)

                // Bond type line — tiny caps + color dot
                HStack(spacing: 6) {
                    Circle().fill(r.color).frame(width: 4, height: 4)
                    Text("\(r.bondType.uppercased()) BOND")
                        .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                        .tracking(1.6)
                        .foregroundStyle(r.color)
                }
                .padding(.top, 4)
                .padding(.bottom, 18)

                // Today's transit toward this person — serif italic pull quote
                Text("\u{201C}There's a softness between you today. She'll reach out before you do — let her.\u{201D}")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(DesignColors.text.opacity(0.85))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // Other bonds — minimal avatar row, names under each
    private func otherBondsRow(_ others: [BondReading]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("In your orbit.")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 22) {
                    ForEach(others.prefix(6), id: \.id) { r in
                        Button(action: { onOpenBond(r) }) {
                            VStack(spacing: 8) {
                                Text(r.initial)
                                    .font(.system(size: 16, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundStyle(.white)
                                    .frame(width: 52, height: 52)
                                    .background(
                                        LinearGradient(
                                            colors: [r.color.opacity(0.95), r.color.opacity(0.75)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        in: Circle()
                                    )
                                    .shadow(color: r.color.opacity(0.22), radius: 6, x: 0, y: 3)

                                Text(r.name)
                                    .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                                    .foregroundStyle(DesignColors.text)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Add-bond — sits inline with the others
                    Button(action: onAddBond) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        DesignColors.accentWarm.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
                                    )
                                    .frame(width: 52, height: 52)
                                Text("+")
                                    .font(.system(size: 20, weight: .regular, design: .serif))
                                    .foregroundStyle(DesignColors.accentWarm)
                            }

                            Text("Add")
                                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                                .foregroundStyle(DesignColors.accentWarm)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            .scrollClipDisabled()
        }
    }

    // Shown when there's only one bond — invitation to add
    private var addBondCTA: some View {
        Button(action: onAddBond) {
            HStack(spacing: 10) {
                Text("+")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                Text("Add a bond")
                    .font(.raleway("SemiBold", size: 14, relativeTo: .body))
            }
            .foregroundStyle(DesignColors.accentWarm)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // Warm aurora row (matches CardStack pattern)
    private func auroraBondRow(_ r: BondReading, tint: GlowCardTint) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Avatar with bond color
            Text(r.initial)
                .font(.raleway("Bold", size: 16, relativeTo: .body))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(r.color, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                .shadow(color: r.color.opacity(0.25), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text("You & \(r.name)")
                    .font(.raleway("Bold", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                    .shadow(color: DesignColors.background.opacity(0.75), radius: 3, x: 0, y: 0)

                HStack(spacing: 5) {
                    Circle().fill(r.color).frame(width: 4, height: 4)
                    Text("\(r.bondType.uppercased()) BOND")
                        .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                        .tracking(1.3)
                        .foregroundStyle(r.color)
                }
                .shadow(color: DesignColors.background.opacity(0.6), radius: 3, x: 0, y: 0)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColors.text.opacity(0.35))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glowCardBackground(tint: tint)
    }

    private var briefingContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pushes the briefing down from the top edge — breathing room
            Spacer().frame(height: 64)

            // Date — quieter, smaller (no dash)
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(2)
                .foregroundStyle(DesignColors.text.opacity(0.6))

            Spacer().frame(height: 24)

            // Hero briefing
            briefingLines

            Spacer().frame(height: 24)

            // Rich summary — the content is the star
            richSummary

            Spacer(minLength: 20)

            // CTA — anchored to the panel bottom, position fixed regardless of text length
            HStack {
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 7) {
                        Text("Read full day")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignColors.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(DesignColors.background.opacity(0.55), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(DesignColors.text.opacity(0.18), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer().frame(height: 32)
        }
        .padding(.horizontal, 28)
    }

    private var bodyParagraph: some View {
        Text("Your energy is rising. A good day to begin something — not to finish it.")
            .font(.raleway("Regular", size: 14, relativeTo: .body))
            .foregroundStyle(Color.white.opacity(0.68))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }

    // Rich summary — truncated preview; full text lives behind "Read full day"
    private var richSummary: some View {
        Text("There's a quiet confidence in you today — the kind that doesn't need to prove itself. Decisions feel clearer than they did last week, and your instincts are sharper than usual.\n\nThis is a good day for honest conversations. The words you've been avoiding will land more softly than you expect. Say them.\n\nWatch for the moment in the afternoon when your energy dips — it's not tiredness, it's your body asking you to pause before committing to something bigger.")
            .font(.raleway("Medium", size: 17, relativeTo: .body))
            .foregroundStyle(DesignColors.text.opacity(0.82))
            .lineSpacing(6)
            .lineLimit(8)
            .truncationMode(.tail)
    }

    private var reactiveText: String {
        switch selectedMood {
        case .quiet:
            return "Let yourself move slowly. The still moments are the ones you'll remember."
        case .tender:
            return "You're feeling more than usual. That's not fragility — it's an opening."
        case .restless:
            return "Something underneath is asking for motion. Listen, don't override."
        case .fierce:
            return "The fire in you has purpose today. Use it to draw a line, not a wound."
        case .grounded:
            return "You're centered. The people near you will feel steadier too."
        case .none:
            return "Tell yourself how you're arriving today — the words below will meet you there."
        }
    }

    // Compact mood strip — cocoa on cream pills
    private var moodCheckIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("I'M MEETING MYSELF AS —")
                .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                .tracking(1.6)
                .foregroundStyle(DesignColors.text.opacity(0.55))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Mood.allCases) { mood in
                        moodChip(mood)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func moodChip(_ mood: Mood) -> some View {
        let active = selectedMood == mood
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedMood = active ? nil : mood
            }
        }) {
            Text(mood.rawValue)
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .foregroundStyle(active ? DesignColors.background : DesignColors.text)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(active ? DesignColors.text : DesignColors.background.opacity(0.55))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(active ? Color.clear : DesignColors.text.opacity(0.18), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // Compact chips showing today's snapshot — fills the mid-space
    private var statsPillsRow: some View {
        HStack(spacing: 8) {
            statsPill(label: "ENERGY", value: "Rising")
            statsPill(label: "MOOD", value: "Tender")
            statsPill(label: "DAY", value: "8")
        }
    }

    private func statsPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.45))
            Text(value)
                .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var briefingLines: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("You move")
                .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)

            heroSecondLine

            Text("today.")
                .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text.opacity(0.75))
        }
    }

    private var heroSecondLine: some View {
        let word = Text("steady, bright,").foregroundStyle(DesignColors.background)
        return word
            .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
            .tracking(-0.3)
    }
}

