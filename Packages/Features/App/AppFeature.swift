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
            case splineIntro
            case privacy
            case nameInput
            case nameGreeting
            case birthData
            case relationshipStatus
            case professionalContext
            case lifestyleRhythm
            case cycleData
            case healthPermission
            case personalGoals
        }

        public var healthDataConsent: Bool = false
        public var termsConsent: Bool = false
        public var userName: String = ""
        public var birthDate: Date = Date()
        public var birthTime: Date = Date()
        public var birthPlace: String = ""
        public var relationshipStatus: RelationshipStatus?
        public var professionalContext: ProfessionalContext?
        public var lifestyleType: LifestyleType?
        public var personalGoals: Set<PersonalGoal> = []

        // Cycle Data (matching backend API)
        public var lastPeriodDate: Date = Date()
        public var cycleDuration: Int = 28  // avgCycleLength (21-40)
        public var periodDuration: Int = 5  // avgBleedingDays (2-10)
        public var cycleRegularity: CycleRegularity = .regular
        public var flowIntensity: Int = 3  // 1-5 scale
        public var selectedSymptoms: Set<SymptomType> = []
        public var usesContraception: Bool = false
        public var contraceptionType: ContraceptionType? = nil

        public init(destination: Destination = .splash) {
            self.destination = destination
        }
    }

    public enum Action: Sendable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case showOnboarding
        case onboardingBeginTapped
        case splineIntroContinueTapped
        case toggleHealthDataConsent
        case toggleTermsConsent
        case privacyNextTapped
        case nameInputNextTapped
        case nameGreetingContinue
        case birthDataNextTapped
        case relationshipStatusNextTapped
        case professionalContextNextTapped
        case lifestyleRhythmNextTapped
        case personalGoalsNextTapped
        case cycleDataNextTapped
        case healthPermissionConnectTapped
        case healthPermissionSkipTapped
        case backTapped
        case backToHealthPermission
        case backToPrivacy
        case backToNameInput
        case backToBirthData
        case backToRelationshipStatus
        case backToProfessionalContext
        case backToLifestyleRhythm
        case backToCycleData
        case backToPersonalGoals
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

            case .splineIntroContinueTapped:
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
                state.destination = .professionalContext
                return .none

            case .professionalContextNextTapped:
                state.destination = .lifestyleRhythm
                return .none

            case .lifestyleRhythmNextTapped:
                state.destination = .cycleData
                return .none

            case .cycleDataNextTapped:
                state.destination = .healthPermission
                return .none

            case .healthPermissionConnectTapped:
                state.destination = .personalGoals
                return .none

            case .healthPermissionSkipTapped:
                state.destination = .personalGoals
                return .none

            case .personalGoalsNextTapped:
                // TODO: Navigate to main app
                return .none

            case .backToProfessionalContext:
                state.destination = .professionalContext
                return .none

            case .backToRelationshipStatus:
                state.destination = .relationshipStatus
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

            case .backToHealthPermission:
                state.destination = .healthPermission
                return .none

            case .backToLifestyleRhythm:
                state.destination = .lifestyleRhythm
                return .none

            case .backToCycleData:
                state.destination = .cycleData
                return .none

            case .backToPersonalGoals:
                state.destination = .personalGoals
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
        destinationView
            .animation(.easeInOut(duration: 0.5), value: store.destination)
            .task {
                store.send(.onAppear)
            }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch store.destination {
        case .splash:
            SplashView()

        case .onboarding:
            OnboardingView {
                store.send(.onboardingBeginTapped)
            }

        case .splineIntro:
            SplineIntroView {
                store.send(.splineIntroContinueTapped)
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

        case .professionalContext:
            ProfessionalContextView(
                selectedContext: $store.professionalContext,
                onNext: { store.send(.professionalContextNextTapped) },
                onBack: { store.send(.backToRelationshipStatus) }
            )

        case .lifestyleRhythm:
            LifestyleRhythmView(
                selectedType: $store.lifestyleType,
                onNext: { store.send(.lifestyleRhythmNextTapped) },
                onBack: { store.send(.backToProfessionalContext) }
            )

        case .cycleData:
            CycleDataView(
                lastPeriodDate: $store.lastPeriodDate,
                cycleDuration: $store.cycleDuration,
                periodDuration: $store.periodDuration,
                cycleRegularity: $store.cycleRegularity,
                flowIntensity: $store.flowIntensity,
                selectedSymptoms: $store.selectedSymptoms,
                usesContraception: $store.usesContraception,
                contraceptionType: $store.contraceptionType,
                onNext: { store.send(.cycleDataNextTapped) },
                onBack: { store.send(.backToLifestyleRhythm) }
            )

        case .healthPermission:
            HealthPermissionView(
                onConnect: { store.send(.healthPermissionConnectTapped) },
                onSkip: { store.send(.healthPermissionSkipTapped) },
                onBack: { store.send(.backToCycleData) }
            )

        case .personalGoals:
            PersonalGoalsView(
                selectedGoals: $store.personalGoals,
                onNext: { store.send(.personalGoalsNextTapped) },
                onBack: { store.send(.backToHealthPermission) }
            )
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
