import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - Menstrual Local Client

/// On-device menstrual tracking and prediction.
/// Replaces MenstrualClient (network) — same return types for minimal feature refactoring.
public struct MenstrualLocalClient: Sendable {
    /// Current cycle status, prediction, and fertile window.
    public var getStatus: @Sendable () async throws -> MenstrualStatusResponse

    /// Calendar entries (periods, fertile days, ovulation, symptoms) for a date range.
    public var getCalendar: @Sendable (Date, Date) async throws -> MenstrualCalendarResponse

    /// Detailed cycle statistics (averages, trend, history).
    public var getCycleStats: @Sendable () async throws -> CycleStatsDetailedResponse

    /// TEMP: Delete all cycles, predictions, and symptoms. Used during re-onboarding.
    public var resetAllCycleData: @Sendable () async throws -> Void

    /// One-shot cleanup: collapse overlapping / duplicate CycleRecords
    /// left behind by older versions of `confirmPeriod` (which only
    /// dedup'd on exact `startDate`, missing shifted-edit duplicates).
    /// Safe to call on every launch — O(n²) on ~dozens of cycles is
    /// nothing; noop when the DB is already clean.
    public var cleanupDuplicateCycles: @Sendable () async throws -> Void

    /// Confirm a new period (create/update cycle record + regenerate prediction).
    /// Pass `skipPredictions: true` when confirming in a batch — call `generatePrediction` once at the end.
    public var confirmPeriod: @Sendable (Date, Int, String?, Bool) async throws -> Void

    /// Remove period days (delete cycle records containing those dates).
    public var removePeriodDays: @Sendable ([Date]) async throws -> Void

    /// Aggregated journey data (cycles, predictions, profile) for the journey engine.
    public var getJourneyData: @Sendable () async throws -> JourneyData

    /// Log a symptom for a specific date.
    public var logSymptom: @Sendable (Date, String, Int, String?) async throws -> Void

    /// Get symptoms logged for a specific date.
    public var getSymptoms: @Sendable (Date) async throws -> [MenstrualSymptomResponse]

    /// Regenerate predictions from current cycle data.
    public var generatePrediction: @Sendable () async throws -> Void

    /// Get or create the menstrual profile (for onboarding + ongoing).
    public var getProfile: @Sendable () async throws -> MenstrualProfileInfo?

    /// Save/update the menstrual profile.
    public var saveProfile: @Sendable (MenstrualProfileInfo, [String], String?, Bool, String?) async throws -> Void

    /// Returns the month name of the most recent unviewed recap, or nil.
    public var unviewedRecapMonth: @Sendable () async throws -> String?

    /// Marks all unviewed recaps as viewed.
    public var markAllRecapsViewed: @Sendable () async throws -> Void
}

// MARK: - Dependency

extension MenstrualLocalClient: DependencyKey {
    public static let liveValue = MenstrualLocalClient.live()
    public static let testValue = MenstrualLocalClient.mock()
    public static let previewValue = MenstrualLocalClient.mock()
}

extension DependencyValues {
    public var menstrualLocal: MenstrualLocalClient {
        get { self[MenstrualLocalClient.self] }
        set { self[MenstrualLocalClient.self] = newValue }
    }
}

// MARK: - Mock

extension MenstrualLocalClient {
    static func mock() -> Self {
        MenstrualLocalClient(
            getStatus: { .mock },
            getCalendar: { _, _ in .mock },
            getCycleStats: { .mock },
            resetAllCycleData: { },
            cleanupDuplicateCycles: { },
            confirmPeriod: { _, _, _, _ in },
            removePeriodDays: { _ in },
            getJourneyData: { JourneyData(records: [], predictions: [], reports: [], profileAvgCycleLength: 28, profileAvgBleedingDays: 5, currentCycleStartDate: nil) },
            logSymptom: { _, _, _, _ in },
            getSymptoms: { _ in [] },
            generatePrediction: { },
            getProfile: { nil },
            saveProfile: { _, _, _, _, _ in },
            unviewedRecapMonth: { nil },
            markAllRecapsViewed: { }
        )
    }
}
