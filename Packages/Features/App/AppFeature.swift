import ComposableArchitecture
import SwiftUI

// MARK: - App Feature

@Reducer
public struct AppFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var destination: Destination

        public enum Destination: Equatable, Sendable {
            case splash
            case onboarding
            case privacy
            case nameInput
            case nameGreeting
            case birthData
            case relationshipStatus
        }

        public var healthDataConsent: Bool = false
        public var termsConsent: Bool = false
        public var userName: String = ""
        public var birthDate: Date = Date()
        public var birthTime: Date = Date()
        public var birthPlace: String = ""
        public var relationshipStatus: RelationshipStatus?
        public init(destination: Destination = .splash) {
            self.destination = destination
        }
    }

    public enum Action: Sendable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case showOnboarding
        case onboardingBeginTapped
        case toggleHealthDataConsent
        case toggleTermsConsent
        case privacyNextTapped
        case nameInputNextTapped
        case nameGreetingContinue
        case birthDataNextTapped
        case relationshipStatusNextTapped
        case backTapped
        case backToPrivacy
        case backToNameInput
        case backToBirthData
    }

    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .run { send in
                    // Show splash for 1.5 seconds
                    try await clock.sleep(for: .milliseconds(1500))
                    await send(.showOnboarding)
                }

            case .showOnboarding:
                state.destination = .onboarding
                return .none

            case .onboardingBeginTapped:
                state.destination = .privacy
                return .none

            case .toggleHealthDataConsent:
                state.healthDataConsent.toggle()
                return .none

            case .toggleTermsConsent:
                state.termsConsent.toggle()
                return .none

            case .privacyNextTapped:
                state.destination = .nameInput
                return .none

            case .nameInputNextTapped:
                state.destination = .nameGreeting
                return .none

            case .nameGreetingContinue:
                state.destination = .birthData
                return .none

            case .birthDataNextTapped:
                state.destination = .relationshipStatus
                return .none

            case .relationshipStatusNextTapped:
                // TODO: Navigate to next screen or main app
                return .none

            case .backTapped:
                state.destination = .onboarding
                return .none

            case .backToPrivacy:
                state.destination = .privacy
                return .none

            case .backToNameInput:
                state.destination = .nameInput
                return .none

            case .backToBirthData:
                state.destination = .birthData
                return .none
            }
        }
    }
}

// MARK: - App View

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.destination {
            case .splash:
                SplashView()

            case .onboarding:
                OnboardingView {
                    store.send(.onboardingBeginTapped)
                }

            case .privacy:
                PrivacyConsentView(
                    healthDataConsent: store.healthDataConsent,
                    termsConsent: store.termsConsent,
                    onToggleHealthData: { store.send(.toggleHealthDataConsent) },
                    onToggleTerms: { store.send(.toggleTermsConsent) },
                    onBegin: { store.send(.privacyNextTapped) },
                    onBack: { store.send(.backTapped) }
                )

            case .nameInput:
                NameInputView(
                    name: $store.userName,
                    onNext: { store.send(.nameInputNextTapped) },
                    onBack: { store.send(.backToPrivacy) }
                )

            case .nameGreeting:
                NameGreetingView(
                    name: store.userName,
                    onContinue: { store.send(.nameGreetingContinue) }
                )

            case .birthData:
                BirthDataView(
                    birthDate: $store.birthDate,
                    birthTime: $store.birthTime,
                    birthPlace: $store.birthPlace,
                    onNext: { store.send(.birthDataNextTapped) },
                    onBack: { store.send(.backToNameInput) }
                )

            case .relationshipStatus:
                RelationshipStatusView(
                    selectedStatus: $store.relationshipStatus,
                    onNext: { store.send(.relationshipStatusNextTapped) },
                    onBack: { store.send(.backToBirthData) }
                )
            }
        }
        .animation(.easeInOut(duration: 0.5), value: store.destination)
        .task {
            store.send(.onAppear)
        }
    }
}

// MARK: - Previews

#Preview("App") {
    AppView(
        store: .init(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
