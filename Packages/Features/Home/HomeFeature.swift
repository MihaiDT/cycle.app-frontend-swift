import ComposableArchitecture
import Inject
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

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .send(.loadUser)

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
                return .send(.today(.loadDashboard))

            case .userLoaded(.failure):
                state.isLoading = false
                return .send(.today(.loadDashboard))

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

            case .today, .delegate:
                return .none
            }
        }
    }
}

// MARK: - Home View

public struct HomeView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
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
                    profileTabView
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
        }
        .task {
            store.send(.onAppear)
        }
        .enableInjection()
    }

    // MARK: - Chat Tab (Placeholder)

    private var chatTabView: some View {
        VStack(spacing: AppLayout.spacingL) {
            Spacer()

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignColors.accentWarm.opacity(0.6))

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

            Spacer()
        }
    }

    // MARK: - Profile Tab

    private var profileTabView: some View {
        ScrollView {
            VStack(spacing: AppLayout.spacingL) {
                // User info card
                if let user = store.user {
                    VStack(spacing: AppLayout.spacingM) {
                        // Avatar
                        Circle()
                            .fill(DesignColors.accent.opacity(0.4))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Text(user.initials)
                                    .font(.custom("Raleway-Bold", size: 28))
                                    .foregroundColor(DesignColors.text)
                            }

                        VStack(spacing: 4) {
                            if let fullName = user.fullName {
                                Text(fullName)
                                    .font(.custom("Raleway-SemiBold", size: 20))
                                    .foregroundColor(DesignColors.text)
                            }

                            Text(user.email)
                                .font(.custom("Raleway-Regular", size: 14))
                                .foregroundColor(DesignColors.textSecondary)
                        }
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

                // Sign Out
                Button(action: { store.send(.logoutTapped) }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                        Text("Sign Out")
                            .font(.custom("Raleway-Medium", size: 15))
                    }
                    .foregroundColor(DesignColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppLayout.horizontalPadding)
            .padding(.top, AppLayout.spacingL)
        }
        .navigationTitle("Me")
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
