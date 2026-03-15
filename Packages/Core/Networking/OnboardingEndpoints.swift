import Foundation

// MARK: - Onboarding Endpoints

public enum OnboardingEndpoints {

    // MARK: - Progress

    /// Get user's onboarding progress
    public static func getProgress() -> Endpoint {
        .get("/api/onboarding/progress")
    }

    // MARK: - Screen Submissions

    /// Submit identity/birth data
    public static func submitIdentityBasic(_ request: IdentityBasicRequest) -> Endpoint {
        .post("/api/onboarding/screens/identity_basic", body: request)
    }

    /// Submit personal context (relationship, profession, lifestyle, goals)
    public static func submitContextPersonal(_ request: ContextPersonalRequest) -> Endpoint {
        .post("/api/onboarding/screens/context_personal", body: request)
    }

    /// Submit wellbeing data
    public static func submitWellbeing(_ request: WellbeingRequest) -> Endpoint {
        .post("/api/onboarding/screens/wellbeing", body: request)
    }

    /// Submit spiritual interests
    public static func submitSpiritualInterests(_ request: SpiritualInterestsRequest) -> Endpoint {
        .post("/api/onboarding/screens/spiritual_interests", body: request)
    }

    /// Submit menstrual/cycle setup
    public static func submitMenstrualSetup(_ request: MenstrualSetupRequest) -> Endpoint {
        .post("/api/onboarding/screens/menstrual_setup", body: request)
    }

    /// Submit consent
    public static func submitConsent(_ request: ConsentRequest) -> Endpoint {
        .post("/api/onboarding/screens/consent", body: request)
    }

    /// Submit notification preferences
    public static func submitNotificationPermission(_ request: NotificationPermissionRequest) -> Endpoint {
        .post("/api/onboarding/screens/notification_permission", body: request)
    }
}

// MARK: - Request Models

/// Identity/birth data matching backend IdentityBasicRequest
public struct IdentityBasicRequest: Encodable, Sendable {
    public let birthDate: String  // Format: YYYY-MM-DD
    public let birthTime: String?  // Format: HH:MM (optional)
    public let birthPlaceName: String
    public let birthLat: Double
    public let birthLng: Double
    public let birthPlaceTimezone: String?

    public init(
        birthDate: Date,
        birthTime: Date?,
        birthPlaceName: String,
        birthLat: Double,
        birthLng: Double,
        birthPlaceTimezone: String? = nil
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.birthDate = dateFormatter.string(from: birthDate)

        if let time = birthTime {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            self.birthTime = timeFormatter.string(from: time)
        } else {
            self.birthTime = nil
        }

        self.birthPlaceName = birthPlaceName
        self.birthLat = birthLat
        self.birthLng = birthLng
        self.birthPlaceTimezone = birthPlaceTimezone
    }
}

/// Personal context matching backend ContextPersonalRequest
public struct ContextPersonalRequest: Encodable, Sendable {
    public let relationshipStatus: String  // single, in_relationship, married, other
    public let currentStatus: String  // student, employed, freelancer, parent, other
    public let dailyRhythm: String  // calm, active, mixed
    public let lifestyle: String  // sedentary, balanced, active, very_active
    public let primaryGoal: String  // hormonal_balance, emotional_clarity, fertility, energy_focus, self_knowledge

    public init(
        relationshipStatus: RelationshipStatusAPI,
        currentStatus: ProfessionalContextAPI,
        dailyRhythm: DailyRhythmAPI,
        lifestyle: LifestyleAPI,
        primaryGoal: PrimaryGoalAPI
    ) {
        self.relationshipStatus = relationshipStatus.rawValue
        self.currentStatus = currentStatus.rawValue
        self.dailyRhythm = dailyRhythm.rawValue
        self.lifestyle = lifestyle.rawValue
        self.primaryGoal = primaryGoal.rawValue
    }
}

/// Wellbeing data matching backend WellbeingRequest
public struct WellbeingRequest: Encodable, Sendable {
    public let energyLevel: Int  // 1-5
    public let sleepQuality: Int  // 1-5
    public let stressLevel: Int  // 1-5
    public let mentalClarity: Int  // 1-5

    public init(energyLevel: Int, sleepQuality: Int, stressLevel: Int, mentalClarity: Int) {
        self.energyLevel = max(1, min(5, energyLevel))
        self.sleepQuality = max(1, min(5, sleepQuality))
        self.stressLevel = max(1, min(5, stressLevel))
        self.mentalClarity = max(1, min(5, mentalClarity))
    }
}

/// Spiritual interests matching backend SpiritualInterestsRequest
public struct SpiritualInterestsRequest: Encodable, Sendable {
    public let interests: [String]

    public init(interests: [SpiritualInterest]) {
        self.interests = interests.map { $0.rawValue }
    }
}

/// Menstrual setup matching backend MenstrualSetupRequest
public struct MenstrualSetupRequest: Encodable, Sendable {
    public let lastPeriodStartDate: String  // Format: YYYY-MM-DD
    public let avgCycleLength: Int  // 21-40 days
    public let avgBleedingDays: Int  // 2-10 days
    public let cycleRegularity: String  // regular, somewhat_regular, irregular
    public let typicalFlowIntensity: Int?  // 1-5
    public let typicalSymptoms: [String: Bool]?
    public let usesContraception: Bool
    public let contraceptionType: String?

    public init(
        lastPeriodStartDate: Date,
        avgCycleLength: Int,
        avgBleedingDays: Int,
        cycleRegularity: CycleRegularityAPI,
        typicalFlowIntensity: Int? = nil,
        typicalSymptoms: [String]? = nil,
        usesContraception: Bool = false,
        contraceptionType: ContraceptionTypeAPI? = nil
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.lastPeriodStartDate = dateFormatter.string(from: lastPeriodStartDate)
        self.avgCycleLength = max(21, min(40, avgCycleLength))
        self.avgBleedingDays = max(2, min(10, avgBleedingDays))
        self.cycleRegularity = cycleRegularity.rawValue
        self.typicalFlowIntensity = typicalFlowIntensity.map { max(1, min(5, $0)) }

        if let symptoms = typicalSymptoms {
            var symptomsDict: [String: Bool] = [:]
            symptoms.forEach { symptomsDict[$0] = true }
            self.typicalSymptoms = symptomsDict
        } else {
            self.typicalSymptoms = nil
        }

        self.usesContraception = usesContraception
        self.contraceptionType = contraceptionType?.rawValue
    }
}

/// Consent matching backend ConsentRequest
public struct ConsentRequest: Encodable, Sendable {
    public let privacyConsent: Bool
    public let healthDataConsent: Bool
    public let consentedAt: String

    public init(privacyConsent: Bool, healthDataConsent: Bool) {
        self.privacyConsent = privacyConsent
        self.healthDataConsent = healthDataConsent

        let formatter = ISO8601DateFormatter()
        self.consentedAt = formatter.string(from: Date())
    }
}

/// Notification permission matching backend NotificationPreferencesRequest
public struct NotificationPermissionRequest: Encodable, Sendable {
    public let notificationsEnabled: Bool
    public let dailyCheckinEnabled: Bool
    public let dailyCheckinHour: Int
    public let dailyCheckinMinute: Int
    public let timezone: String

    public init(notificationsEnabled: Bool, dailyCheckinHour: Int, dailyCheckinMinute: Int) {
        self.notificationsEnabled = notificationsEnabled
        self.dailyCheckinEnabled = notificationsEnabled
        self.dailyCheckinHour = dailyCheckinHour
        self.dailyCheckinMinute = dailyCheckinMinute
        self.timezone = TimeZone.current.identifier
    }
}

// MARK: - Response Models

/// Onboarding progress response
public struct OnboardingProgressResponse: Decodable, Sendable {
    public let completedScreens: [String]
    public let totalScreens: Int
    public let isComplete: Bool
}

/// Generic success response
public struct OnboardingSuccessResponse: Decodable, Sendable {
    public let success: Bool
    public let message: String
}

// MARK: - API Enums (matching backend exactly)

public enum RelationshipStatusAPI: String, CaseIterable, Sendable {
    case single = "single"
    case inRelationship = "in_relationship"
    case married = "married"
    case other = "other"

    public var displayName: String {
        switch self {
        case .single: return "Single"
        case .inRelationship: return "In a relationship"
        case .married: return "Married"
        case .other: return "Other"
        }
    }
}

public enum ProfessionalContextAPI: String, CaseIterable, Sendable {
    case student = "student"
    case employed = "employed"
    case freelancer = "freelancer"
    case parent = "parent"
    case other = "other"

    public var displayName: String {
        switch self {
        case .student: return "Student"
        case .employed: return "Employed"
        case .freelancer: return "Freelancer"
        case .parent: return "Stay-at-home parent"
        case .other: return "Other"
        }
    }
}

public enum DailyRhythmAPI: String, CaseIterable, Sendable {
    case calm = "calm"
    case active = "active"
    case mixed = "mixed"

    public var displayName: String {
        switch self {
        case .calm: return "Calm & Stable"
        case .active: return "Active & On-the-go"
        case .mixed: return "Mixed"
        }
    }
}

public enum LifestyleAPI: String, CaseIterable, Sendable {
    case sedentary = "sedentary"
    case balanced = "balanced"
    case active = "active"
    case veryActive = "very_active"

    public var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .balanced: return "Balanced"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }
}

public enum PrimaryGoalAPI: String, CaseIterable, Sendable {
    case hormonalBalance = "hormonal_balance"
    case emotionalClarity = "emotional_clarity"
    case fertility = "fertility"
    case energyFocus = "energy_focus"
    case selfKnowledge = "self_knowledge"

    public var displayName: String {
        switch self {
        case .hormonalBalance: return "Hormonal Balance"
        case .emotionalClarity: return "Emotional Clarity"
        case .fertility: return "Fertility Tracking"
        case .energyFocus: return "Energy & Focus"
        case .selfKnowledge: return "Self Knowledge"
        }
    }
}

public enum SpiritualInterest: String, CaseIterable, Sendable {
    case emotionsRelationships = "emotions_relationships"
    case cycleBody = "cycle_body"
    case intuitionFeminine = "intuition_feminine"
    case astrologyMoon = "astrology_moon"
    case balanceMindfulness = "balance_mindfulness"

    public var displayName: String {
        switch self {
        case .emotionsRelationships: return "Emotions & Relationships"
        case .cycleBody: return "Cycle & Body"
        case .intuitionFeminine: return "Intuition & Feminine Energy"
        case .astrologyMoon: return "Astrology & Moon Cycles"
        case .balanceMindfulness: return "Balance & Mindfulness"
        }
    }
}

public enum CycleRegularityAPI: String, CaseIterable, Sendable {
    case regular = "regular"
    case somewhatRegular = "somewhat_regular"
    case irregular = "irregular"

    public var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .somewhatRegular: return "Somewhat Regular"
        case .irregular: return "Irregular"
        }
    }
}

public enum ContraceptionTypeAPI: String, CaseIterable, Sendable {
    case none = "none"
    case pill = "pill"
    case iud = "iud"
    case implant = "implant"
    case patch = "patch"
    case ring = "ring"
    case condom = "condom"
    case natural = "natural"
    case other = "other"

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .pill: return "Birth Control Pill"
        case .iud: return "IUD"
        case .implant: return "Implant"
        case .patch: return "Patch"
        case .ring: return "Ring"
        case .condom: return "Condom"
        case .natural: return "Natural Methods"
        case .other: return "Other"
        }
    }
}
