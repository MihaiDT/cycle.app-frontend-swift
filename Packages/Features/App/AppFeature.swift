import ComposableArchitecture
import Inject
import SwiftData
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
            case birthData
            case relationshipStatus
            case professionalContext
            case lifestyleRhythm
            case cycleData
            case healthPermission
            case notificationPermission
            case personalGoals
            case recap
            case home
        }

        public var notificationCheckinHour: Int = 20
        public var notificationCheckinMinute: Int = 0
        public var notificationsEnabled: Bool = false
        public var healthDataConsent: Bool = false
        public var termsConsent: Bool = false
        public var userName: String = ""
        public var birthDate: Date = Date()
        public var birthTime: Date = Date()
        public var birthPlace: String = ""
        public var selectedBirthPlace: PlacesAutocompleteTextField.SelectedPlace? = nil
        public var relationshipStatus: RelationshipStatus?
        public var professionalContext: ProfessionalContext?
        public var lifestyleType: LifestyleType?
        public var personalGoals: Set<PersonalGoal> = []

        // Cycle Data (matching backend API)
        public var lastPeriodDate: Date?
        public var cycleDuration: Int = 28  // avgCycleLength (21-40)
        public var periodDuration: Int = 5  // avgBleedingDays (2-10)
        public var cycleRegularity: CycleRegularity = .regular
        public var flowIntensity: Int = 3  // 1-5 scale
        public var selectedSymptoms: Set<SymptomType> = []
        public var usesContraception: Bool = false
        public var contraceptionType: ContraceptionType? = nil

        // Home (child feature)
        public var homeState: HomeFeature.State = HomeFeature.State()

        // Backend submission
        public var isSubmittingOnboarding: Bool = false
        public var onboardingError: String? = nil

        public init(destination: Destination = .splash) {
            self.destination = destination
        }
    }

    public enum Action: Sendable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case showOnboarding
        case showHome
        case onboardingBeginTapped
        case splineIntroContinueTapped
        case toggleHealthDataConsent
        case toggleTermsConsent
        case privacyNextTapped
        case birthDataNextTapped
        case relationshipStatusNextTapped
        case professionalContextNextTapped
        case lifestyleRhythmNextTapped
        case personalGoalsNextTapped
        case recapFinishTapped
        case cycleDataNextTapped
        case healthPermissionConnectTapped
        case healthPermissionSkipTapped
        case notificationPermissionEnableTapped(hour: Int, minute: Int)
        case notificationPermissionSkipTapped
        case backTapped
        case backToHealthPermission
        case backToNotificationPermission
        case backToPrivacy
        case backToBirthData
        case backToRelationshipStatus
        case backToProfessionalContext
        case backToLifestyleRhythm
        case backToCycleData
        case backToPersonalGoals
        case backToRecap
        case ageRestrictionTriggered

        // Home child actions
        case home(HomeFeature.Action)

        // Backend submission
        case submitOnboardingData
        case onboardingSubmitCompleted
        case onboardingSubmitFailed(String)

    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.placesClient) var placesClient
    @Dependency(\.userProfileLocal) var userProfileLocal
    @Dependency(\.menstrualLocal) var menstrualLocal
    @Dependency(\.localNotifications) var localNotifications

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.homeState, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .run { [userProfileLocal, clock] send in
                    let profile = try? await userProfileLocal.getProfile()
                    try await clock.sleep(for: .milliseconds(1500))
                    if profile != nil {
                        await send(.showHome)
                    } else {
                        await send(.showOnboarding)
                    }
                }

            case .showOnboarding:
                state.destination = .onboarding
                return .none

            case .showHome:
                state.destination = .home
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
                state.destination = .notificationPermission
                return .none

            case .healthPermissionSkipTapped:
                state.destination = .notificationPermission
                return .none

            case .notificationPermissionEnableTapped(let hour, let minute):
                state.notificationsEnabled = true
                state.notificationCheckinHour = hour
                state.notificationCheckinMinute = minute
                state.destination = .personalGoals
                return .run { [localNotifications] _ in
                    _ = try? await localNotifications.requestAuthorization()
                    try? await localNotifications.scheduleDailyReminder(hour, minute)
                }

            case .notificationPermissionSkipTapped:
                state.destination = .personalGoals
                return .none

            case .personalGoalsNextTapped:
                state.destination = .recap
                return .none

            case .recapFinishTapped:
                guard !state.isSubmittingOnboarding else { return .none }
                // Local-first: no auth needed, save data and go straight to home
                return .send(.submitOnboardingData)

            // MARK: - Home Delegate

            case .home(.delegate(.didLogout)):
                state.destination = .onboarding
                UserDefaults.standard.removeObject(forKey: "NewRecapCycleKey")
                UserDefaults.standard.removeObject(forKey: "NewRecapMonthName")
                UserDefaults.standard.removeObject(forKey: "LastDismissedRecapKey")
                return .none

            case .home:
                return .none

            // MARK: - Backend Submission

            case .submitOnboardingData:
                guard !state.isSubmittingOnboarding else { return .none }
                state.isSubmittingOnboarding = true
                state.onboardingError = nil

                // Capture all state values for the @Sendable async effect
                let userName = state.userName
                let birthDate = state.birthDate
                let birthTime = state.birthTime
                let birthPlace = state.birthPlace
                let selectedBirthPlace = state.selectedBirthPlace
                let relationshipStatus = state.relationshipStatus
                let professionalContext = state.professionalContext
                let lifestyleType = state.lifestyleType
                let personalGoals = Array(state.personalGoals)
                let lastPeriodDate = state.lastPeriodDate
                let cycleDuration = state.cycleDuration
                let periodDuration = state.periodDuration
                let cycleRegularity = state.cycleRegularity
                let flowIntensity = state.flowIntensity
                let selectedSymptoms = state.selectedSymptoms
                let usesContraception = state.usesContraception
                let contraceptionType = state.contraceptionType
                let healthDataConsent = state.healthDataConsent
                let termsConsent = state.termsConsent
                let notificationsEnabled = state.notificationsEnabled
                let notificationCheckinHour = state.notificationCheckinHour
                let notificationCheckinMinute = state.notificationCheckinMinute
                let userProfileLocal = userProfileLocal
                let menstrualLocal = menstrualLocal

                return .run { send in
                    do {
                        // 0. Clear any existing data (fresh start)
                        let container = CycleDataStore.shared
                        let clearCtx = ModelContext(container)
                        try? clearCtx.delete(model: UserProfileRecord.self)
                        try? clearCtx.delete(model: MenstrualProfileRecord.self)
                        try? clearCtx.delete(model: CycleRecord.self)
                        try? clearCtx.delete(model: SymptomRecord.self)
                        try? clearCtx.delete(model: PredictionRecord.self)
                        try? clearCtx.delete(model: SelfReportRecord.self)
                        try? clearCtx.delete(model: HBIScoreRecord.self)
                        try? clearCtx.save()

                        // 1. Save user profile locally
                        let profile = UserProfileSnapshot(
                            userName: userName,
                            birthDate: birthDate,
                            birthTime: birthTime,
                            birthPlace: selectedBirthPlace?.name ?? birthPlace,
                            birthPlaceLat: selectedBirthPlace?.latitude,
                            birthPlaceLng: selectedBirthPlace?.longitude,
                            birthPlaceTimezone: selectedBirthPlace?.timezone,
                            relationshipStatus: relationshipStatus?.rawValue,
                            professionalContext: professionalContext?.rawValue,
                            lifestyleType: lifestyleType?.title,
                            personalGoals: personalGoals.map(\.rawValue),
                            healthDataConsent: healthDataConsent,
                            termsConsent: termsConsent,
                            notificationsEnabled: notificationsEnabled,
                            dailyCheckinHour: notificationCheckinHour,
                            dailyCheckinMinute: notificationCheckinMinute
                        )
                        try await userProfileLocal.saveProfile(profile)

                        // 2. Save menstrual profile + initial cycle locally
                        let symptomNames = selectedSymptoms.map(\.rawValue)
                        let profileInfo = MenstrualProfileInfo(
                            avgCycleLength: cycleDuration,
                            cycleRegularity: cycleRegularity.rawValue,
                            trackingSince: .now
                        )
                        let flowStr: String? = switch flowIntensity {
                        case 1: "light"
                        case 2: "medium"
                        case 3: "heavy"
                        default: nil
                        }
                        try await menstrualLocal.saveProfile(
                            profileInfo,
                            symptomNames,
                            flowStr,
                            usesContraception,
                            contraceptionType?.rawValue
                        )

                        // 3. Clear stale recap state for new account
                        UserDefaults.standard.removeObject(forKey: "ViewedRecapCycleKeys")
                        UserDefaults.standard.set(Date(), forKey: "CycleDataResetDate")

                        // 4. Create initial cycle from last period date
                        if let lpDate = lastPeriodDate {
                            try await menstrualLocal.confirmPeriod(lpDate, periodDuration, nil, false)
                        }

                        // 4. Generate first prediction locally
                        try await menstrualLocal.generatePrediction()

                        await send(.onboardingSubmitCompleted)
                    } catch {
                        await send(.onboardingSubmitFailed(error.localizedDescription))
                    }
                }

            case .onboardingSubmitCompleted:
                state.isSubmittingOnboarding = false
                state.onboardingError = nil
                state.homeState = HomeFeature.State()
                state.destination = .home
                // Clear any stale recap banner from previous account
                UserDefaults.standard.removeObject(forKey: "NewRecapCycleKey")
                UserDefaults.standard.removeObject(forKey: "NewRecapMonthName")
                UserDefaults.standard.removeObject(forKey: "LastDismissedRecapKey")
                return .none

            case .onboardingSubmitFailed(let errorMessage):
                state.isSubmittingOnboarding = false
                state.onboardingError = errorMessage
                // Still navigate to home — data can be resubmitted later
                state.homeState = HomeFeature.State()
                state.destination = .home
                return .none

            // MARK: - Back Navigation

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


            case .backToBirthData:
                state.destination = .birthData
                return .none

            case .backToHealthPermission:
                state.destination = .healthPermission
                return .none

            case .backToNotificationPermission:
                state.destination = .notificationPermission
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

            case .backToRecap:
                state.destination = .recap
                return .none

            case .ageRestrictionTriggered:
                state.destination = .onboarding
                return .none
            }
        }
    }
}

// MARK: - App View

public struct AppView: View {
    @ObserveInjection var inject
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
            .modelContainer(CycleDataStore.shared)
            .enableInjection()
    }

    @ViewBuilder
    private var destinationView: some View {
        switch store.destination {
        case .splash:
            SplashView()

        case .onboarding:
            OnboardingView(
                onBegin: { store.send(.onboardingBeginTapped) },
                onLogin: { store.send(.onboardingBeginTapped) }
            )

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

        case .birthData:
            BirthDataView(
                birthDate: $store.birthDate,
                birthTime: $store.birthTime,
                birthPlace: $store.birthPlace,
                selectedBirthPlace: $store.selectedBirthPlace,
                onNext: { store.send(.birthDataNextTapped) },
                onBack: { store.send(.backToPrivacy) },
                onAgeRestriction: { store.send(.ageRestrictionTriggered) },
                onSearchPlace: { query in
                    let client = PlacesClient.liveValue
                    do {
                        let results = try await client.autocomplete(query)
                        return results.map { apiResult in
                            PlacesAutocompleteTextField.PlaceResult(
                                id: apiResult.placeId,
                                mainText: apiResult.mainText ?? apiResult.description,
                                secondaryText: apiResult.secondaryText ?? ""
                            )
                        }
                    } catch {
                        print("⚠️ Places autocomplete error: \(error)")
                        return []
                    }
                },
                onSelectPlace: { placeResult in
                    let client = PlacesClient.liveValue
                    guard let details = try? await client.getDetails(placeResult.id) else { return nil }
                    return PlacesAutocompleteTextField.SelectedPlace(
                        placeId: details.placeId,
                        name: details.name,
                        formattedAddress: details.formattedAddress,
                        latitude: details.latitude,
                        longitude: details.longitude,
                        timezone: details.timezone
                    )
                }
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

        case .notificationPermission:
            NotificationPermissionView(
                onEnable: { hour, minute in
                    store.send(.notificationPermissionEnableTapped(hour: hour, minute: minute))
                },
                onSkip: { store.send(.notificationPermissionSkipTapped) },
                onBack: { store.send(.backToHealthPermission) }
            )

        case .personalGoals:
            PersonalGoalsView(
                selectedGoals: $store.personalGoals,
                onNext: { store.send(.personalGoalsNextTapped) },
                onBack: { store.send(.backToNotificationPermission) }
            )

        case .recap:
            OnboardingRecapView(
                userName: "",
                birthDate: store.birthDate,
                relationshipStatus: store.relationshipStatus,
                professionalContext: store.professionalContext,
                lifestyleType: store.lifestyleType,
                cycleDuration: store.cycleDuration,
                periodDuration: store.periodDuration,
                personalGoals: store.personalGoals,
                onFinish: { store.send(.recapFinishTapped) },
                onBack: { store.send(.backToPersonalGoals) }
            )

        case .home:
            HomeView(
                store: store.scope(state: \.homeState, action: \.home)
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
