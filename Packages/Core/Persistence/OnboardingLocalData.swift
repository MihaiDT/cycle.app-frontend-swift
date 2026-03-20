import Foundation

// MARK: - Onboarding Local Data

/// Stores onboarding data locally for guest users who haven't created an account.
/// When the user later creates an account, this data is uploaded to the server.
public struct OnboardingLocalData: Codable, Sendable, Equatable {
    public var userName: String
    public var birthDate: Date
    public var birthTime: Date
    public var birthPlace: String
    public var birthPlaceLat: Double
    public var birthPlaceLng: Double
    public var birthPlaceTimezone: String?
    public var relationshipStatus: String?
    public var professionalContext: String?
    public var lifestyleType: Int?
    public var personalGoals: [String]
    public var lastPeriodDate: Date?
    public var cycleDuration: Int
    public var periodDuration: Int
    public var cycleRegularity: String
    public var flowIntensity: Int
    public var selectedSymptoms: [String]
    public var usesContraception: Bool
    public var contraceptionType: String?
    public var healthDataConsent: Bool
    public var termsConsent: Bool

    public init(
        userName: String,
        birthDate: Date,
        birthTime: Date,
        birthPlace: String,
        birthPlaceLat: Double,
        birthPlaceLng: Double,
        birthPlaceTimezone: String?,
        relationshipStatus: String?,
        professionalContext: String?,
        lifestyleType: Int?,
        personalGoals: [String],
        lastPeriodDate: Date?,
        cycleDuration: Int,
        periodDuration: Int,
        cycleRegularity: String,
        flowIntensity: Int,
        selectedSymptoms: [String],
        usesContraception: Bool,
        contraceptionType: String?,
        healthDataConsent: Bool,
        termsConsent: Bool
    ) {
        self.userName = userName
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.birthPlace = birthPlace
        self.birthPlaceLat = birthPlaceLat
        self.birthPlaceLng = birthPlaceLng
        self.birthPlaceTimezone = birthPlaceTimezone
        self.relationshipStatus = relationshipStatus
        self.professionalContext = professionalContext
        self.lifestyleType = lifestyleType
        self.personalGoals = personalGoals
        self.lastPeriodDate = lastPeriodDate
        self.cycleDuration = cycleDuration
        self.periodDuration = periodDuration
        self.cycleRegularity = cycleRegularity
        self.flowIntensity = flowIntensity
        self.selectedSymptoms = selectedSymptoms
        self.usesContraception = usesContraception
        self.contraceptionType = contraceptionType
        self.healthDataConsent = healthDataConsent
        self.termsConsent = termsConsent
    }
}
