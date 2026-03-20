import ComposableArchitecture
import Inject
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
            case notificationPermission
            case personalGoals
            case recap
            case authChoice
            case authentication
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

        // Authentication (child feature)
        public var authState: AuthenticationFeature.State = AuthenticationFeature.State()

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
        case onboardingLoginTapped
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
        case recapFinishTapped
        case authChoiceEmailTapped
        case authChoiceGoogleTapped
        case authChoiceAppleTapped
        case backToAuthChoice
        case cycleDataNextTapped
        case healthPermissionConnectTapped
        case healthPermissionSkipTapped
        case notificationPermissionEnableTapped(hour: Int, minute: Int)
        case notificationPermissionSkipTapped
        case backTapped
        case backToHealthPermission
        case backToNotificationPermission
        case backToPrivacy
        case backToNameInput
        case backToBirthData
        case backToRelationshipStatus
        case backToProfessionalContext
        case backToLifestyleRhythm
        case backToCycleData
        case backToPersonalGoals
        case backToRecap
        case ageRestrictionTriggered

        // Authentication child actions
        case auth(AuthenticationFeature.Action)

        // Home child actions
        case home(HomeFeature.Action)

        // Backend submission
        case submitOnboardingData
        case onboardingSubmitCompleted
        case onboardingSubmitFailed(String)

        // Guest mode
        case guestContinueTapped
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.onboardingClient) var onboardingClient
    @Dependency(\.sessionClient) var sessionClient
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.placesClient) var placesClient
    @Dependency(\.firebaseAuthClient) var firebaseAuth
    @Dependency(\.userDefaultsClient) var userDefaults

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.authState, action: \.auth) {
            AuthenticationFeature()
        }

        Scope(state: \.homeState, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .run { [sessionClient, firebaseAuth] send in
                    // Check for existing authenticated session
                    if let session = try? await sessionClient.getSession(),
                       session.isValid {
                        // Refresh Firebase token to ensure it's still valid
                        if let freshToken = try? await firebaseAuth.getIDToken() {
                            let refreshedSession = Session(
                                id: session.id,
                                accessToken: freshToken,
                                refreshToken: session.refreshToken,
                                expiresAt: Date().addingTimeInterval(3600),
                                user: session.user
                            )
                            try? await sessionClient.setSession(refreshedSession)
                            await send(.showHome)
                            return
                        }
                    }
                    // No valid session — show onboarding
                    try await clock.sleep(for: .milliseconds(1500))
                    await send(.showOnboarding)
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

            case .onboardingLoginTapped:
                state.authState.mode = .login
                state.destination = .authentication
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
                return .none

            case .notificationPermissionSkipTapped:
                state.destination = .personalGoals
                return .none

            case .personalGoalsNextTapped:
                state.destination = .recap
                return .none

            case .recapFinishTapped:
                guard !state.isSubmittingOnboarding else { return .none }
                state.destination = .authChoice
                return .none

            case .authChoiceEmailTapped:
                state.authState.mode = .register
                state.destination = .authentication
                return .none

            case .authChoiceGoogleTapped:
                return .send(.auth(.googleSignInTapped))
                return .none

            case .authChoiceAppleTapped:
                // TODO: Implement Apple Sign In
                return .none

            case .backToAuthChoice:
                state.destination = .authChoice
                return .none

            // MARK: - Authentication Delegate

            case .auth(.delegate(.didAuthenticate)):
                if state.authState.mode == .login {
                    // Returning user — skip onboarding, go straight to home
                    state.destination = .home
                    return .none
                }
                // New user (register) — submit all onboarding data to backend
                return .send(.submitOnboardingData)

            case .auth:
                // All other auth actions handled by scoped AuthenticationFeature
                return .none

            // MARK: - Home Delegate

            case .home(.delegate(.didLogout)):
                state.destination = .onboarding
                return .none

            case .home:
                return .none

            // MARK: - Backend Submission

            case .submitOnboardingData:
                guard !state.isSubmittingOnboarding else { return .none }
                state.isSubmittingOnboarding = true
                state.onboardingError = nil

                // Capture all state values for the @Sendable async effect
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
                let apiClient = apiClient
                let sessionClient = sessionClient

                return .run { send in
                    do {
                        // Get auth token from session
                        guard let token = await sessionClient.getAccessToken() else {
                            await send(.onboardingSubmitFailed("Not authenticated"))
                            return
                        }

                        // Retry helper — backend upserts are idempotent so retries are safe
                        @Sendable func withRetry<T: Decodable & Sendable>(
                            maxAttempts: Int = 3,
                            _ operation: @Sendable () async throws -> T
                        ) async throws -> T {
                            var lastError: Error?
                            for attempt in 1...maxAttempts {
                                do {
                                    return try await operation()
                                } catch {
                                    lastError = error
                                    if attempt < maxAttempts {
                                        try await Task.sleep(for: .seconds(pow(2.0, Double(attempt - 1))))
                                    }
                                }
                            }
                            throw lastError!
                        }

                        // 1. Submit identity_basic (birth data)
                        let identityRequest = IdentityBasicRequest(
                            birthDate: birthDate,
                            birthTime: birthTime,
                            birthPlaceName: selectedBirthPlace?.name ?? birthPlace,
                            birthLat: selectedBirthPlace?.latitude ?? 0.0,
                            birthLng: selectedBirthPlace?.longitude ?? 0.0,
                            birthPlaceTimezone: selectedBirthPlace?.timezone
                        )
                        let _: OnboardingSuccessResponse = try await withRetry {
                            try await apiClient.send(
                                OnboardingEndpoints.submitIdentityBasic(identityRequest)
                                    .authenticated(with: token)
                            )
                        }

                        // 2. Submit context_personal
                        let mappedRelationship = OnboardingDataMapper.mapRelationshipStatus(
                            relationshipStatus?.rawValue ?? "Single"
                        )
                        let mappedProfessional = OnboardingDataMapper.mapProfessionalContext(
                            professionalContext?.rawValue ?? "Student"
                        )
                        let mappedRhythm = OnboardingDataMapper.mapLifestyleToRhythm(
                            lifestyleType?.title ?? "Calm & Stable"
                        )
                        let mappedGoal = OnboardingDataMapper.mapPrimaryGoal(
                            from: personalGoals.map(\.rawValue)
                        )

                        let mappedLifestyle: LifestyleAPI = {
                            guard let lifestyle = lifestyleType else { return .balanced }
                            switch lifestyle {
                            case .calm: return .sedentary
                            case .active: return .active
                            case .intuitive: return .balanced
                            case .analytical: return .balanced
                            }
                        }()

                        let contextRequest = ContextPersonalRequest(
                            relationshipStatus: mappedRelationship,
                            currentStatus: mappedProfessional,
                            dailyRhythm: mappedRhythm,
                            lifestyle: mappedLifestyle,
                            primaryGoal: mappedGoal
                        )
                        let _: OnboardingSuccessResponse = try await withRetry {
                            try await apiClient.send(
                                OnboardingEndpoints.submitContextPersonal(contextRequest)
                                    .authenticated(with: token)
                            )
                        }

                        // 3. Submit wellbeing
                        let wellbeingRequest = WellbeingRequest(
                            energyLevel: 3,
                            sleepQuality: 3,
                            stressLevel: 3,
                            mentalClarity: 3
                        )
                        let _: OnboardingSuccessResponse = try await withRetry {
                            try await apiClient.send(
                                OnboardingEndpoints.submitWellbeing(wellbeingRequest)
                                    .authenticated(with: token)
                            )
                        }

                        // 4. Submit spiritual_interests
                        let mappedInterests = OnboardingDataMapper.mapGoalsToInterests(
                            from: personalGoals.map(\.rawValue)
                        )
                        let spiritualRequest = SpiritualInterestsRequest(
                            interests: mappedInterests
                        )
                        let _: OnboardingSuccessResponse = try await withRetry {
                            try await apiClient.send(
                                OnboardingEndpoints.submitSpiritualInterests(spiritualRequest)
                                    .authenticated(with: token)
                            )
                        }

                        // 5. Submit menstrual_setup
                        let mappedRegularity = OnboardingDataMapper.mapCycleRegularity(
                            cycleRegularity.rawValue
                        )
                        let symptomNames = selectedSymptoms.map(\.rawValue)
                        let menstrualRequest = MenstrualSetupRequest(
                            lastPeriodStartDate: lastPeriodDate,
                            avgCycleLength: cycleDuration,
                            avgBleedingDays: periodDuration,
                            cycleRegularity: mappedRegularity,
                            typicalFlowIntensity: flowIntensity,
                            typicalSymptoms: symptomNames.isEmpty ? nil : symptomNames,
                            usesContraception: usesContraception,
                            contraceptionType: contraceptionType.map {
                                ContraceptionTypeAPI(rawValue: $0.rawValue) ?? .other
                            }
                        )
                        let _: OnboardingSuccessResponse = try await withRetry {
                            try await apiClient.send(
                                OnboardingEndpoints.submitMenstrualSetup(menstrualRequest)
                                    .authenticated(with: token)
                            )
                        }

                        // 6. Submit consent (triggers persona generation on backend)
                        let consentRequest = ConsentRequest(
                            privacyConsent: termsConsent,
                            healthDataConsent: healthDataConsent
                        )
                        let _: OnboardingSuccessResponse = try await withRetry {
                            try await apiClient.send(
                                OnboardingEndpoints.submitConsent(consentRequest)
                                    .authenticated(with: token)
                            )
                        }

                        // 7. Submit notification preferences
                        let notificationRequest = NotificationPermissionRequest(
                            notificationsEnabled: notificationsEnabled,
                            dailyCheckinHour: notificationCheckinHour,
                            dailyCheckinMinute: notificationCheckinMinute
                        )
                        let _: OnboardingSuccessResponse = try await withRetry {
                            try await apiClient.send(
                                OnboardingEndpoints.submitNotificationPermission(notificationRequest)
                                    .authenticated(with: token)
                            )
                        }

                        await send(.onboardingSubmitCompleted)
                    } catch {
                        await send(.onboardingSubmitFailed(error.localizedDescription))
                    }
                }

            case .onboardingSubmitCompleted:
                state.isSubmittingOnboarding = false
                state.onboardingError = nil
                state.destination = .home
                return .none

            case .onboardingSubmitFailed(let errorMessage):
                state.isSubmittingOnboarding = false
                state.onboardingError = errorMessage
                // Still navigate to home — data can be resubmitted later
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

            case .backToNameInput:
                state.destination = .nameInput
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

            // MARK: - Guest Mode

            case .guestContinueTapped:
                state.isSubmittingOnboarding = true
                let localData = OnboardingLocalData(
                    userName: state.userName,
                    birthDate: state.birthDate,
                    birthTime: state.birthTime,
                    birthPlace: state.selectedBirthPlace?.name ?? state.birthPlace,
                    birthPlaceLat: state.selectedBirthPlace?.latitude ?? 0,
                    birthPlaceLng: state.selectedBirthPlace?.longitude ?? 0,
                    birthPlaceTimezone: state.selectedBirthPlace?.timezone,
                    relationshipStatus: state.relationshipStatus?.rawValue,
                    professionalContext: state.professionalContext?.rawValue,
                    lifestyleType: state.lifestyleType?.rawValue,
                    personalGoals: state.personalGoals.map(\.rawValue),
                    lastPeriodDate: state.lastPeriodDate,
                    cycleDuration: state.cycleDuration,
                    periodDuration: state.periodDuration,
                    cycleRegularity: state.cycleRegularity.rawValue,
                    flowIntensity: state.flowIntensity,
                    selectedSymptoms: state.selectedSymptoms.map(\.rawValue),
                    usesContraception: state.usesContraception,
                    contraceptionType: state.contraceptionType?.rawValue,
                    healthDataConsent: state.healthDataConsent,
                    termsConsent: state.termsConsent
                )
                return .run { [firebaseAuth, sessionClient, userDefaults, localData] send in
                    let authUser = try await firebaseAuth.signInAnonymously()
                    let token = try await firebaseAuth.getIDToken()
                    let session = Session(
                        id: Session.ID(authUser.uid),
                        accessToken: token,
                        refreshToken: "",
                        expiresAt: Date().addingTimeInterval(3600),
                        user: User(
                            id: User.ID(authUser.uid),
                            email: "",
                            firstName: localData.userName.isEmpty ? nil : localData.userName,
                            lastName: nil
                        )
                    )
                    try await sessionClient.setSession(session)
                    userDefaults.setCodable(localData, forKey: UserDefaultsClient.Keys.onboardingLocalData)
                    await send(.onboardingSubmitCompleted)
                } catch: { error, send in
                    await send(.onboardingSubmitFailed(error.localizedDescription))
                }
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
                onLogin: { store.send(.onboardingLoginTapped) }
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
                selectedBirthPlace: $store.selectedBirthPlace,
                onNext: { store.send(.birthDataNextTapped) },
                onBack: { store.send(.backToNameInput) },
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
                userName: store.userName,
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

        case .authChoice:
            AuthChoiceView(
                onEmailTapped: { store.send(.authChoiceEmailTapped) },
                onGoogleTapped: { store.send(.authChoiceGoogleTapped) },
                onAppleTapped: { store.send(.authChoiceAppleTapped) },
                onGuestTapped: { store.send(.guestContinueTapped) },
                onBack: { store.send(.backToRecap) }
            )

        case .authentication:
            AuthenticationView(
                store: store.scope(state: \.authState, action: \.auth),
                onBack: {
                    if store.authState.mode == .login {
                        store.send(.showOnboarding)
                    } else {
                        store.send(.backToAuthChoice)
                    }
                }
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
