import ComposableArchitecture
import SwiftUI
import os.log

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
            case recap
            case authentication
            case home
        }

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
        public var lastPeriodDate: Date = Date()
        public var cycleDuration: Int = 28  // avgCycleLength (21-40)
        public var periodDuration: Int = 5  // avgBleedingDays (2-10)
        public var cycleRegularity: CycleRegularity = .regular
        public var flowIntensity: Int = 3  // 1-5 scale
        public var selectedSymptoms: Set<SymptomType> = []
        public var usesContraception: Bool = false
        public var contraceptionType: ContraceptionType? = nil

        // Authentication (child feature)
        public var authState: AuthenticationFeature.State = AuthenticationFeature.State()

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
        case recapFinishTapped
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
        case backToRecap
        case ageRestrictionTriggered

        // Authentication child actions
        case auth(AuthenticationFeature.Action)

        // Backend submission
        case submitOnboardingData
        case onboardingSubmitCompleted
        case onboardingSubmitFailed(String)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.onboardingClient) var onboardingClient
    @Dependency(\.sessionClient) var sessionClient
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.placesClient) var placesClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.authState, action: \.auth) {
            AuthenticationFeature()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                NSLog("🚀 [APP] onAppear - BUILD v5 with comprehensive auth logging")
                return .run { send in
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
                state.destination = .recap
                return .none

            case .recapFinishTapped:
                state.destination = .authentication
                return .none

            // MARK: - Authentication Delegate

            case .auth(.delegate(.didAuthenticate)):
                // User authenticated; submit all onboarding data to backend
                print("🔴🔴🔴 [APP] didAuthenticate RECEIVED - will submit onboarding data")
                NSLog("🔑 [APP] didAuthenticate received - submitting onboarding data")
                // DEBUG: Write marker file to confirm this code runs
                let marker = "didAuthenticate fired at \(Date())"
                try? marker.write(toFile: NSTemporaryDirectory() + "onboarding_debug.txt", atomically: true, encoding: .utf8)
                return .send(.submitOnboardingData)

            case .auth(let authAction):
                // All other auth actions handled by scoped AuthenticationFeature
                NSLog("🔑 [APP] auth action forwarded: %@", String(describing: authAction))
                return .none

            // MARK: - Backend Submission

            case .submitOnboardingData:
                state.isSubmittingOnboarding = true
                state.onboardingError = nil
                // DEBUG: Write marker file
                try? "submitOnboardingData at \(Date())".write(toFile: NSTemporaryDirectory() + "submit_debug.txt", atomically: true, encoding: .utf8)

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
                let apiClient = apiClient
                let sessionClient = sessionClient

                return .run { send in
                    do {
                        // Get auth token from session
                        print("🔴🔴🔴 [ONBOARDING] submitOnboardingData STARTED")
                        guard let token = await sessionClient.getAccessToken() else {
                            print("🔴🔴🔴 [ONBOARDING] NO TOKEN - getAccessToken returned nil")
                            NSLog("❌ [ONBOARDING] No access token available")
                            await send(.onboardingSubmitFailed("Not authenticated"))
                            return
                        }
                        print("🟢🟢🟢 [ONBOARDING] Got token: \(token.prefix(20))...")
                        NSLog("✅ [ONBOARDING] Got token: %@...", String(token.prefix(20)))

                        // 1. Submit identity_basic (birth data)
                        NSLog("📤 [ONBOARDING] Submitting identity_basic...")
                        let identityRequest = IdentityBasicRequest(
                            birthDate: birthDate,
                            birthTime: birthTime,
                            birthPlaceName: selectedBirthPlace?.name ?? birthPlace,
                            birthLat: selectedBirthPlace?.latitude ?? 0.0,
                            birthLng: selectedBirthPlace?.longitude ?? 0.0,
                            birthPlaceTimezone: selectedBirthPlace?.timezone
                        )
                        let _: OnboardingSuccessResponse = try await apiClient.send(
                            OnboardingEndpoints.submitIdentityBasic(identityRequest)
                                .authenticated(with: token)
                        )

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
                        let _: OnboardingSuccessResponse = try await apiClient.send(
                            OnboardingEndpoints.submitContextPersonal(contextRequest)
                                .authenticated(with: token)
                        )

                        // 3. Submit wellbeing
                        let wellbeingRequest = WellbeingRequest(
                            energyLevel: 3,
                            sleepQuality: 3,
                            stressLevel: 3,
                            mentalClarity: 3
                        )
                        let _: OnboardingSuccessResponse = try await apiClient.send(
                            OnboardingEndpoints.submitWellbeing(wellbeingRequest)
                                .authenticated(with: token)
                        )

                        // 4. Submit spiritual_interests
                        let mappedInterests = OnboardingDataMapper.mapGoalsToInterests(
                            from: personalGoals.map(\.rawValue)
                        )
                        let spiritualRequest = SpiritualInterestsRequest(
                            interests: mappedInterests
                        )
                        let _: OnboardingSuccessResponse = try await apiClient.send(
                            OnboardingEndpoints.submitSpiritualInterests(spiritualRequest)
                                .authenticated(with: token)
                        )

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
                        let _: OnboardingSuccessResponse = try await apiClient.send(
                            OnboardingEndpoints.submitMenstrualSetup(menstrualRequest)
                                .authenticated(with: token)
                        )

                        // 6. Submit consent (triggers persona generation on backend)
                        let consentRequest = ConsentRequest(
                            privacyConsent: termsConsent,
                            healthDataConsent: healthDataConsent
                        )
                        let _: OnboardingSuccessResponse = try await apiClient.send(
                            OnboardingEndpoints.submitConsent(consentRequest)
                                .authenticated(with: token)
                        )

                        await send(.onboardingSubmitCompleted)
                    } catch {
                        print("🔴🔴🔴 [ONBOARDING] CATCH ERROR: \(error)")
                        NSLog("❌ [ONBOARDING] Submit failed: %@", String(describing: error))
                        await send(.onboardingSubmitFailed(error.localizedDescription))
                    }
                }

            case .onboardingSubmitCompleted:
                NSLog("✅ [ONBOARDING] All screens submitted successfully!")
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
                selectedBirthPlace: $store.selectedBirthPlace,
                onNext: { store.send(.birthDataNextTapped) },
                onBack: { store.send(.backToNameInput) },
                onAgeRestriction: { store.send(.ageRestrictionTriggered) },
                onSearchPlace: { query in
                    let client = PlacesClient.liveValue
                    let results = (try? await client.autocomplete(query)) ?? []
                    return results.map { apiResult in
                        PlacesAutocompleteTextField.PlaceResult(
                            id: apiResult.placeId,
                            mainText: apiResult.mainText ?? apiResult.description,
                            secondaryText: apiResult.secondaryText ?? ""
                        )
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

        case .personalGoals:
            PersonalGoalsView(
                selectedGoals: $store.personalGoals,
                onNext: { store.send(.personalGoalsNextTapped) },
                onBack: { store.send(.backToHealthPermission) }
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

        case .authentication:
            AuthenticationView(
                store: store.scope(state: \.authState, action: \.auth)
            )

        case .home:
            HomeView(
                store: Store(initialState: HomeFeature.State()) {
                    HomeFeature()
                }
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
