import ComposableArchitecture
import SwiftData
import SwiftUI


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
            .modelContainer(CycleDataStore.shared)
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
