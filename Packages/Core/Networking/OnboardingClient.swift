import ComposableArchitecture
import Foundation

// MARK: - Onboarding Client

/// Client for onboarding API operations
public struct OnboardingClient: Sendable {
    public var getProgress: @Sendable () async throws -> OnboardingProgressResponse
    public var submitIdentityBasic: @Sendable (IdentityBasicRequest) async throws -> OnboardingSuccessResponse
    public var submitContextPersonal: @Sendable (ContextPersonalRequest) async throws -> OnboardingSuccessResponse
    public var submitWellbeing: @Sendable (WellbeingRequest) async throws -> OnboardingSuccessResponse
    public var submitSpiritualInterests: @Sendable (SpiritualInterestsRequest) async throws -> OnboardingSuccessResponse
    public var submitMenstrualSetup: @Sendable (MenstrualSetupRequest) async throws -> OnboardingSuccessResponse
    public var submitConsent: @Sendable (ConsentRequest) async throws -> OnboardingSuccessResponse

    public init(
        getProgress: @escaping @Sendable () async throws -> OnboardingProgressResponse,
        submitIdentityBasic: @escaping @Sendable (IdentityBasicRequest) async throws -> OnboardingSuccessResponse,
        submitContextPersonal: @escaping @Sendable (ContextPersonalRequest) async throws -> OnboardingSuccessResponse,
        submitWellbeing: @escaping @Sendable (WellbeingRequest) async throws -> OnboardingSuccessResponse,
        submitSpiritualInterests:
            @escaping @Sendable (SpiritualInterestsRequest) async throws -> OnboardingSuccessResponse,
        submitMenstrualSetup: @escaping @Sendable (MenstrualSetupRequest) async throws -> OnboardingSuccessResponse,
        submitConsent: @escaping @Sendable (ConsentRequest) async throws -> OnboardingSuccessResponse
    ) {
        self.getProgress = getProgress
        self.submitIdentityBasic = submitIdentityBasic
        self.submitContextPersonal = submitContextPersonal
        self.submitWellbeing = submitWellbeing
        self.submitSpiritualInterests = submitSpiritualInterests
        self.submitMenstrualSetup = submitMenstrualSetup
        self.submitConsent = submitConsent
    }
}

// MARK: - Dependency Key

extension OnboardingClient: DependencyKey {
    public static let liveValue = OnboardingClient.live()
    public static let testValue = OnboardingClient.mock()
    public static let previewValue = OnboardingClient.mock()
}

extension DependencyValues {
    public var onboardingClient: OnboardingClient {
        get { self[OnboardingClient.self] }
        set { self[OnboardingClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension OnboardingClient {
    public static func live() -> Self {
        @Dependency(\.apiClient) var apiClient

        return OnboardingClient(
            getProgress: {
                try await apiClient.send(OnboardingEndpoints.getProgress())
            },
            submitIdentityBasic: { request in
                try await apiClient.send(OnboardingEndpoints.submitIdentityBasic(request))
            },
            submitContextPersonal: { request in
                try await apiClient.send(OnboardingEndpoints.submitContextPersonal(request))
            },
            submitWellbeing: { request in
                try await apiClient.send(OnboardingEndpoints.submitWellbeing(request))
            },
            submitSpiritualInterests: { request in
                try await apiClient.send(OnboardingEndpoints.submitSpiritualInterests(request))
            },
            submitMenstrualSetup: { request in
                try await apiClient.send(OnboardingEndpoints.submitMenstrualSetup(request))
            },
            submitConsent: { request in
                try await apiClient.send(OnboardingEndpoints.submitConsent(request))
            }
        )
    }
}

// MARK: - Mock Implementation

extension OnboardingClient {
    public static func mock() -> Self {
        OnboardingClient(
            getProgress: {
                OnboardingProgressResponse(
                    completedScreens: [],
                    totalScreens: 6,
                    isComplete: false
                )
            },
            submitIdentityBasic: { _ in
                OnboardingSuccessResponse(success: true, message: "Identity saved")
            },
            submitContextPersonal: { _ in
                OnboardingSuccessResponse(success: true, message: "Context saved")
            },
            submitWellbeing: { _ in
                OnboardingSuccessResponse(success: true, message: "Wellbeing saved")
            },
            submitSpiritualInterests: { _ in
                OnboardingSuccessResponse(success: true, message: "Interests saved")
            },
            submitMenstrualSetup: { _ in
                OnboardingSuccessResponse(success: true, message: "Menstrual data saved")
            },
            submitConsent: { _ in
                OnboardingSuccessResponse(success: true, message: "Consent saved")
            }
        )
    }
}

// MARK: - Onboarding Data Mapper

/// Maps frontend onboarding state to backend API requests
public struct OnboardingDataMapper: Sendable {

    /// Map frontend RelationshipStatus to backend API enum
    public static func mapRelationshipStatus(_ status: String) -> RelationshipStatusAPI {
        switch status.lowercased() {
        case "single": return .single
        case "in a relationship", "inrelationship": return .inRelationship
        case "married": return .married
        default: return .other
        }
    }

    /// Map frontend ProfessionalContext to backend API enum
    public static func mapProfessionalContext(_ context: String) -> ProfessionalContextAPI {
        switch context.lowercased() {
        case "student": return .student
        case "employed": return .employed
        case "freelancer": return .freelancer
        case "stay-at-home mom", "stayathome", "parent": return .parent
        default: return .other
        }
    }

    /// Map frontend LifestyleType to backend DailyRhythm
    public static func mapLifestyleToRhythm(_ lifestyle: String) -> DailyRhythmAPI {
        switch lifestyle.lowercased() {
        case "calm & stable", "calm": return .calm
        case "active & on-the-go", "active": return .active
        default: return .mixed
        }
    }

    /// Map frontend PersonalGoals to backend PrimaryGoal
    public static func mapPrimaryGoal(from goals: [String]) -> PrimaryGoalAPI {
        // Use first goal as primary, or default to self_knowledge
        guard let first = goals.first?.lowercased() else { return .selfKnowledge }

        switch first {
        case "emotional balance", "emotionalbalance": return .emotionalClarity
        case "energy & clarity", "energyclarity": return .energyFocus
        case "harmonious relationships": return .emotionalClarity
        case "motivation": return .energyFocus
        case "self understanding", "selfunderstanding": return .selfKnowledge
        default: return .selfKnowledge
        }
    }

    /// Map frontend PersonalGoals to backend SpiritualInterests
    public static func mapGoalsToInterests(from goals: [String]) -> [SpiritualInterest] {
        var interests: [SpiritualInterest] = []

        for goal in goals {
            switch goal.lowercased() {
            case "emotional balance", "emotionalbalance":
                interests.append(.balanceMindfulness)
            case "energy & clarity", "energyclarity":
                interests.append(.cycleBody)
            case "harmonious relationships":
                interests.append(.emotionsRelationships)
            case "motivation":
                interests.append(.balanceMindfulness)
            case "self understanding", "selfunderstanding":
                interests.append(.intuitionFeminine)
            default:
                break
            }
        }

        // Ensure at least one interest
        if interests.isEmpty {
            interests.append(.balanceMindfulness)
        }

        return Array(Set(interests))
    }

    /// Map frontend CycleRegularity to backend enum
    public static func mapCycleRegularity(_ regularity: String) -> CycleRegularityAPI {
        switch regularity.lowercased() {
        case "regular": return .regular
        case "somewhat regular", "somewhatregular", "somewhat_regular": return .somewhatRegular
        case "irregular": return .irregular
        default: return .regular
        }
    }
}
