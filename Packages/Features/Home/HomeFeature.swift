import ComposableArchitecture
import SwiftUI

// MARK: - Home Feature

@Reducer
public struct HomeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var user: User?
        public var isLoading: Bool
        public var selectedTab: Tab

        public enum Tab: Int, Equatable, Sendable, CaseIterable {
            case home = 0
            case search = 1
            case notifications = 2
            case profile = 3

            var title: String {
                switch self {
                case .home: "Home"
                case .search: "Search"
                case .notifications: "Notifications"
                case .profile: "Profile"
                }
            }

            var icon: String {
                switch self {
                case .home: "house"
                case .search: "magnifyingglass"
                case .notifications: "bell"
                case .profile: "person"
                }
            }

            var selectedIcon: String {
                switch self {
                case .home: "house.fill"
                case .search: "magnifyingglass"
                case .notifications: "bell.fill"
                case .profile: "person.fill"
                }
            }
        }

        public init(
            user: User? = nil,
            isLoading: Bool = false,
            selectedTab: Tab = .home
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

        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didLogout
        }
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.sessionClient) var sessionClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .send(.loadUser)

            case .loadUser:
                state.isLoading = true

                return .run { send in
                    guard let token = await sessionClient.getAccessToken() else {
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
                return .none

            case .userLoaded(.failure):
                state.isLoading = false
                return .none

            case .logoutTapped:
                return .run { send in
                    try? await sessionClient.clearSession()
                    await send(.logoutCompleted)
                }

            case .logoutCompleted:
                return .send(.delegate(.didLogout))

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Home View

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab) {
            ForEach(HomeFeature.State.Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(
                            tab.title,
                            systemImage: store.selectedTab == tab ? tab.selectedIcon : tab.icon
                        )
                    }
                    .tag(tab)
            }
        }
        .task {
            store.send(.onAppear)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: HomeFeature.State.Tab) -> some View {
        NavigationStack {
            switch tab {
            case .home:
                homeTabView
            case .search:
                searchTabView
            case .notifications:
                notificationsTabView
            case .profile:
                profileTabView
            }
        }
    }

    private var homeTabView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let user = store.user {
                    Text("Welcom]e, \(user.fullName ?? user.email)!")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                // Placeholder content
                ForEach(0..<10) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 120)
                        .overlay {
                            Text("Content \(index + 1)")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Home")
    }

    private var searchTabView: some View {
        Text("Search")
            .navigationTitle("Search")
    }

    private var notificationsTabView: some View {
        Text("Notifications")
            .navigationTitle("Notifications")
    }

    private var profileTabView: some View {
        List {
            if let user = store.user {
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Text(user.initials)
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            if let fullName = user.fullName {
                                Text(fullName)
                                    .font(.headline)
                            }
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Account") {
                    NavigationLink("Edit Profile") {
                        Text("Edit Profile")
                    }

                    NavigationLink("Settings") {
                        Text("Settings")
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        store.send(.logoutTapped)
                    }
                }
            }
        }
        .navigationTitle("Profile")
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
