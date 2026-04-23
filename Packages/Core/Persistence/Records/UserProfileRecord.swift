import Foundation
import SwiftData

// MARK: - User Profile Record

/// On-device user profile with CloudKit E2E encryption for sensitive fields.
/// Single record per device — represents the logged-in user.
@Model
public final class UserProfileRecord {

    // MARK: Identity

    @Attribute(.allowsCloudEncryption)
    public var userName: String = ""

    @Attribute(.allowsCloudEncryption)
    public var birthDate: Date?

    @Attribute(.allowsCloudEncryption)
    public var birthTime: Date?

    @Attribute(.allowsCloudEncryption)
    public var birthPlace: String?

    @Attribute(.allowsCloudEncryption)
    public var birthPlaceLat: Double?

    @Attribute(.allowsCloudEncryption)
    public var birthPlaceLng: Double?

    public var birthPlaceTimezone: String?

    // MARK: Context

    @Attribute(.allowsCloudEncryption)
    public var relationshipStatus: String?

    @Attribute(.allowsCloudEncryption)
    public var professionalContext: String?

    public var lifestyleType: String?
    public var personalGoals: [String] = []

    // MARK: Consent

    public var healthDataConsent: Bool = false
    public var termsConsent: Bool = false

    // MARK: Notifications

    public var notificationsEnabled: Bool = false
    public var dailyCheckinHour: Int = 20
    public var dailyCheckinMinute: Int = 0

    // MARK: Timestamps

    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init(
        userName: String,
        birthDate: Date? = nil,
        birthTime: Date? = nil,
        birthPlace: String? = nil,
        birthPlaceLat: Double? = nil,
        birthPlaceLng: Double? = nil,
        birthPlaceTimezone: String? = nil,
        relationshipStatus: String? = nil,
        professionalContext: String? = nil,
        lifestyleType: String? = nil,
        personalGoals: [String] = [],
        healthDataConsent: Bool = false,
        termsConsent: Bool = false,
        notificationsEnabled: Bool = false,
        dailyCheckinHour: Int = 20,
        dailyCheckinMinute: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = Date.now
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
        self.healthDataConsent = healthDataConsent
        self.termsConsent = termsConsent
        self.notificationsEnabled = notificationsEnabled
        self.dailyCheckinHour = dailyCheckinHour
        self.dailyCheckinMinute = dailyCheckinMinute
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
