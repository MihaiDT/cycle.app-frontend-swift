import ComposableArchitecture
import Testing

@testable import Features

@MainActor
struct AuthenticationFeatureTests {
    @Test
    func testInitialState() {
        let store = TestStore(initialState: AuthenticationFeature.State()) {
            AuthenticationFeature()
        }

        #expect(store.state.mode == .login)
        #expect(store.state.email == "")
        #expect(store.state.password == "")
        #expect(store.state.isLoading == false)
        #expect(store.state.error == nil)
    }

    @Test
    func testModeSwitch() async {
        let store = TestStore(initialState: AuthenticationFeature.State()) {
            AuthenticationFeature()
        }

        await store.send(.setMode(.register)) {
            $0.mode = .register
        }

        await store.send(.setMode(.forgotPassword)) {
            $0.mode = .forgotPassword
        }

        await store.send(.setMode(.login)) {
            $0.mode = .login
        }
    }

    @Test
    func testEmailBinding() async {
        let store = TestStore(initialState: AuthenticationFeature.State()) {
            AuthenticationFeature()
        }

        await store.send(\.binding.email, "test@example.com") {
            $0.email = "test@example.com"
            $0.emailValidation = .valid
        }
    }

    @Test
    func testInvalidEmail() async {
        let store = TestStore(initialState: AuthenticationFeature.State()) {
            AuthenticationFeature()
        }

        await store.send(\.binding.email, "invalid-email") {
            $0.email = "invalid-email"
            $0.emailValidation = .invalid("Please enter a valid email address")
        }
    }

    @Test
    func testFormValidation() {
        var state = AuthenticationFeature.State()

        #expect(state.isFormValid == false)

        state.email = "test@example.com"
        #expect(state.isFormValid == false)

        state.password = "Password123"
        #expect(state.isFormValid == true)
    }

    @Test
    func testRegisterFormValidation() {
        var state = AuthenticationFeature.State(mode: .register)

        state.email = "test@example.com"
        state.password = "Password123"
        #expect(state.isFormValid == false)

        state.confirmPassword = "Password123"
        #expect(state.isFormValid == true)

        state.confirmPassword = "DifferentPassword"
        #expect(state.isFormValid == false)
    }
}
