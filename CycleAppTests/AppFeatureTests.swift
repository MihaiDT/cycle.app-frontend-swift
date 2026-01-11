import ComposableArchitecture
import Testing

@testable import Features

@MainActor
struct AppFeatureTests {
    @Test
    func testInitialState() {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        #expect(store.state.isLoading == true)
        #expect(store.state.isAuthenticated == false)
        #expect(store.state.destination == .splash)
    }

    @Test
    func testCheckAuthenticationWhenNotAuthenticated() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.sessionClient = .mock(isAuthenticated: false)
        }

        await store.send(.onAppear)

        await store.receive(\.checkAuthenticationCompleted) {
            $0.isLoading = false
            $0.isAuthenticated = false
            $0.destination = .authentication
            $0.authentication = AuthenticationFeature.State()
        }
    }

    @Test
    func testCheckAuthenticationWhenAuthenticated() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.sessionClient = .mock(isAuthenticated: true)
        }

        await store.send(.onAppear)

        await store.receive(\.checkAuthenticationCompleted) {
            $0.isLoading = false
            $0.isAuthenticated = true
            $0.destination = .home
            $0.home = HomeFeature.State()
        }
    }
}
