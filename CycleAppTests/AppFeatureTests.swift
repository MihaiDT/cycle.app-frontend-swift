@testable import CycleApp
import ComposableArchitecture
import Testing

@MainActor
struct AppFeatureTests {
    @Test
    func testInitialState() {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        #expect(store.state.destination == .splash)
        #expect(store.state.healthDataConsent == false)
        #expect(store.state.termsConsent == false)
        #expect(store.state.userName == "")
        #expect(store.state.selectedBirthPlace == nil)
        #expect(store.state.isSubmittingOnboarding == false)
    }

    @Test
    func testSplashTransitionsToOnboarding() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.onAppear)

        await store.receive(\.showOnboarding) {
            $0.destination = .onboarding
        }
    }

    @Test
    func testOnboardingFlowNavigation() async {
        let store = TestStore(initialState: AppFeature.State(destination: .onboarding)) {
            AppFeature()
        }

        await store.send(.onboardingBeginTapped) {
            $0.destination = .privacy
        }

        await store.send(.privacyNextTapped) {
            $0.destination = .nameInput
        }

        await store.send(.nameInputNextTapped) {
            $0.destination = .nameGreeting
        }

        await store.send(.nameGreetingContinue) {
            $0.destination = .birthData
        }

        await store.send(.birthDataNextTapped) {
            $0.destination = .relationshipStatus
        }

        await store.send(.relationshipStatusNextTapped) {
            $0.destination = .professionalContext
        }

        await store.send(.professionalContextNextTapped) {
            $0.destination = .lifestyleRhythm
        }

        await store.send(.lifestyleRhythmNextTapped) {
            $0.destination = .cycleData
        }

        await store.send(.cycleDataNextTapped) {
            $0.destination = .healthPermission
        }

        await store.send(.healthPermissionSkipTapped) {
            $0.destination = .personalGoals
        }

        await store.send(.personalGoalsNextTapped) {
            $0.destination = .recap
        }

        await store.send(.recapFinishTapped) {
            $0.destination = .authentication
        }
    }
}
