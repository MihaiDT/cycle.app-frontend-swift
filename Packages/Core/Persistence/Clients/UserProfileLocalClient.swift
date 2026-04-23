import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - User Profile Local Client

public struct UserProfileLocalClient: Sendable {
    public var getProfile: @Sendable () async throws -> UserProfileSnapshot?
    public var saveProfile: @Sendable (UserProfileSnapshot) async throws -> Void
    public var deleteProfile: @Sendable () async throws -> Void
}

// MARK: - Snapshot (Sendable value type for TCA state)

public struct UserProfileSnapshot: Sendable, Equatable, Codable {
    public var userName: String
    public var birthDate: Date?
    public var birthTime: Date?
    public var birthPlace: String?
    public var birthPlaceLat: Double?
    public var birthPlaceLng: Double?
    public var birthPlaceTimezone: String?
    public var relationshipStatus: String?
    public var professionalContext: String?
    public var lifestyleType: String?
    public var personalGoals: [String]
    public var healthDataConsent: Bool
    public var termsConsent: Bool
    public var notificationsEnabled: Bool
    public var dailyCheckinHour: Int
    public var dailyCheckinMinute: Int
    public var createdAt: Date

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
        createdAt: Date = .now
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
    }
}

// MARK: - Dependency

extension UserProfileLocalClient: DependencyKey {
    public static let liveValue = UserProfileLocalClient.live()
    public static let testValue = UserProfileLocalClient.mock()
    public static let previewValue = UserProfileLocalClient.mock()
}

extension DependencyValues {
    public var userProfileLocal: UserProfileLocalClient {
        get { self[UserProfileLocalClient.self] }
        set { self[UserProfileLocalClient.self] = newValue }
    }
}

// MARK: - Live

extension UserProfileLocalClient {
    static func live() -> Self {
        UserProfileLocalClient(
            getProfile: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<UserProfileRecord>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                guard let record = try context.fetch(descriptor).first else { return nil }
                return record.toSnapshot()
            },
            saveProfile: { snapshot in
                let container = CycleDataStore.shared
                let context = ModelContext(container)

                // Upsert: find existing or create new
                let descriptor = FetchDescriptor<UserProfileRecord>()
                let existing = try context.fetch(descriptor).first

                if let record = existing {
                    record.update(from: snapshot)
                } else {
                    let record = UserProfileRecord.from(snapshot)
                    context.insert(record)
                }
                try context.save()
            },
            deleteProfile: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<UserProfileRecord>()
                for record in try context.fetch(descriptor) {
                    context.delete(record)
                }
                try context.save()
            }
        )
    }
}

// MARK: - Mock

extension UserProfileLocalClient {
    static func mock() -> Self {
        UserProfileLocalClient(
            getProfile: { nil },
            saveProfile: { _ in },
            deleteProfile: { }
        )
    }
}

// MARK: - Record ↔ Snapshot

extension UserProfileRecord {
    func toSnapshot() -> UserProfileSnapshot {
        UserProfileSnapshot(
            userName: userName,
            birthDate: birthDate,
            birthTime: birthTime,
            birthPlace: birthPlace,
            birthPlaceLat: birthPlaceLat,
            birthPlaceLng: birthPlaceLng,
            birthPlaceTimezone: birthPlaceTimezone,
            relationshipStatus: relationshipStatus,
            professionalContext: professionalContext,
            lifestyleType: lifestyleType,
            personalGoals: personalGoals,
            healthDataConsent: healthDataConsent,
            termsConsent: termsConsent,
            notificationsEnabled: notificationsEnabled,
            dailyCheckinHour: dailyCheckinHour,
            dailyCheckinMinute: dailyCheckinMinute,
            createdAt: createdAt
        )
    }

    func update(from snapshot: UserProfileSnapshot) {
        userName = snapshot.userName
        birthDate = snapshot.birthDate
        birthTime = snapshot.birthTime
        birthPlace = snapshot.birthPlace
        birthPlaceLat = snapshot.birthPlaceLat
        birthPlaceLng = snapshot.birthPlaceLng
        birthPlaceTimezone = snapshot.birthPlaceTimezone
        relationshipStatus = snapshot.relationshipStatus
        professionalContext = snapshot.professionalContext
        lifestyleType = snapshot.lifestyleType
        personalGoals = snapshot.personalGoals
        healthDataConsent = snapshot.healthDataConsent
        termsConsent = snapshot.termsConsent
        notificationsEnabled = snapshot.notificationsEnabled
        dailyCheckinHour = snapshot.dailyCheckinHour
        dailyCheckinMinute = snapshot.dailyCheckinMinute
        updatedAt = .now
    }

    static func from(_ snapshot: UserProfileSnapshot) -> UserProfileRecord {
        UserProfileRecord(
            userName: snapshot.userName,
            birthDate: snapshot.birthDate,
            birthTime: snapshot.birthTime,
            birthPlace: snapshot.birthPlace,
            birthPlaceLat: snapshot.birthPlaceLat,
            birthPlaceLng: snapshot.birthPlaceLng,
            birthPlaceTimezone: snapshot.birthPlaceTimezone,
            relationshipStatus: snapshot.relationshipStatus,
            professionalContext: snapshot.professionalContext,
            lifestyleType: snapshot.lifestyleType,
            personalGoals: snapshot.personalGoals,
            healthDataConsent: snapshot.healthDataConsent,
            termsConsent: snapshot.termsConsent,
            notificationsEnabled: snapshot.notificationsEnabled,
            dailyCheckinHour: snapshot.dailyCheckinHour,
            dailyCheckinMinute: snapshot.dailyCheckinMinute,
            createdAt: snapshot.createdAt
        )
    }
}
