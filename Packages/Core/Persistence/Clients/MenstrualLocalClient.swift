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

    /// Remove all logged entries for the given symptom type on the
    /// given date. Idempotent — no-op if the symptom isn't logged.
    public var removeSymptom: @Sendable (Date, String) async throws -> Void

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

    /// Detect recurring body-pattern signals from the user's symptom
    /// + cycle history over the last 12 months. Returns raw signals
    /// (pure algorithm output); the caller maps `RawPatternSignal`
    /// → display models with display names + editorial copy.
    public var detectPatterns: @Sendable () async throws -> [PatternDetector.RawPatternSignal]

    /// Recent symptom logs across the last `daysBack` days. Used by
    /// Body Patterns to show the user their captured logs even when
    /// no recurring pattern has formed yet.
    public var recentSymptoms: @Sendable (Int) async throws -> [RecentSymptomEntry]

    /// Severity metrics for one detected pattern over the 12-month
    /// lookback window. Returns per-cycle averages so the detail
    /// screen's chart + Highlights row stay grounded in real
    /// `SymptomRecord.severity` values, not synthetic placeholders.
    public var patternMetrics: @Sendable (
        _ symptomTypeRaw: String,
        _ phase: CyclePhase
    ) async throws -> PatternMetrics
}

// MARK: - Recent Symptom Entry

public struct RecentSymptomEntry: Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let symptomTypeRaw: String
    public let date: Date

    public init(id: String, symptomTypeRaw: String, date: Date) {
        self.id = id
        self.symptomTypeRaw = symptomTypeRaw
        self.date = date
    }
}

// MARK: - Pattern Metrics

/// One cycle's worth of severity data for a detected pattern. Carries
/// both the calendar date (`cycleStartDate`) and the 1-based ordinal
/// (`cycleIndex`) so the chart can switch between a date-axis ("Jun –
/// May") and a cycle-axis ("Cycle 1, 2, 3...") without a second query.
public struct PatternCyclePoint: Sendable, Equatable, Hashable, Identifiable {
    /// Stable identifier — uses the cycle's start-date timestamp like
    /// the rest of the BodyPatterns layer.
    public let id: String
    /// 1-based ordinal across the pattern's occurrences (oldest → 1).
    public let cycleIndex: Int
    public let cycleStartDate: Date
    /// Mean severity across this cycle's matching `SymptomRecord`
    /// logs. 1.0 – 5.0.
    public let averageSeverity: Double
    /// Highest severity logged in this cycle for the pattern.
    public let peakSeverity: Double
    /// Number of logs that matched the pattern in this cycle (a single
    /// pattern can be logged across multiple days within the phase).
    public let logCount: Int

    public init(
        id: String,
        cycleIndex: Int,
        cycleStartDate: Date,
        averageSeverity: Double,
        peakSeverity: Double,
        logCount: Int
    ) {
        self.id = id
        self.cycleIndex = cycleIndex
        self.cycleStartDate = cycleStartDate
        self.averageSeverity = averageSeverity
        self.peakSeverity = peakSeverity
        self.logCount = logCount
    }
}

/// Direction of the pattern across recent cycles. Computed from the
/// difference between the first and last severity points.
public enum PatternTrend: String, Sendable, Equatable, Hashable, CaseIterable {
    case strengthening
    case persisting
    case easing
    case justAppearing

    public var displayName: String {
        switch self {
        case .strengthening: return "Strengthening"
        case .persisting:    return "Persisting"
        case .easing:        return "Easing"
        case .justAppearing: return "Just appearing"
        }
    }
}

/// One log inside a detected pattern — the cycle it belongs to, the
/// day-within-cycle, the severity logged, and the calendar date. Used
/// by the day-heatmap visualisation that plots logs as cycle × day
/// dots so the user reads "where in the cycle the symptom hits"
/// without needing severity to vary.
public struct PatternDayLog: Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    /// Owning cycle's `startDate` — same identifier shape used by
    /// `PatternCyclePoint`. Multiple logs in the same cycle share
    /// this value.
    public let cycleStartDate: Date
    /// 1-based day within the cycle when this log was made.
    public let cycleDay: Int
    /// Severity logged on that day (1.0 – 5.0).
    public let severity: Double
    /// Calendar date the log was made.
    public let logDate: Date

    public init(
        id: String,
        cycleStartDate: Date,
        cycleDay: Int,
        severity: Double,
        logDate: Date
    ) {
        self.id = id
        self.cycleStartDate = cycleStartDate
        self.cycleDay = cycleDay
        self.severity = severity
        self.logDate = logDate
    }
}

/// Aggregated severity-history view for one detected pattern.
public struct PatternMetrics: Sendable, Equatable, Hashable {
    /// Per-cycle severity points, oldest → newest. Empty when the
    /// pattern has no logs in the lookback window.
    public let cycles: [PatternCyclePoint]
    /// Per-day raw logs. Drives the cycle × day heatmap on
    /// `PatternChartCard` — shows where in the cycle the symptom
    /// hits, even when severity is uniform across cycles.
    public let dayLogs: [PatternDayLog]
    /// Mean of `averageSeverity` across `cycles`. Zero when empty.
    public let averageSeverity: Double
    /// Highest severity ever logged for this pattern in the window.
    public let peakSeverity: Double
    /// Date of the highest-severity log.
    public let peakDate: Date
    /// Most recent log date (any severity).
    public let lastSeen: Date
    /// Inclusive 12-month lookback window. Caller uses these for the
    /// chart's date-axis domain.
    public let lookbackStart: Date
    public let lookbackEnd: Date
    public let trend: PatternTrend

    /// Cycle day that has the most logs across the pattern's cycles
    /// — "the day this hits hardest". Nil when there are no logs.
    public let mostActiveDay: Int?
    /// How many cycles have a log on `mostActiveDay`.
    public let mostActiveDayCycleCount: Int
    /// Mean number of distinct cycle days the symptom hits per
    /// cycle. Zero when no cycles.
    public let avgDaysAffected: Double
    /// Top co-occurring symptom — the `SymptomType.rawValue`
    /// (excluding the pattern's own symptom and neutral symptoms)
    /// that appears in the most of the pattern's cycles. Nil when
    /// no other symptom co-occurs.
    public let coOccurringSymptomRaw: String?
    /// How many of the pattern's cycles also include the
    /// co-occurring symptom.
    public let coOccurringSymptomCount: Int
    /// Predicted window for the next occurrence — anchored to the
    /// latest cycle's start + the user's avg cycle length, then
    /// offset by the pattern's `dayRange`. Nil if we have no cycles
    /// to anchor against.
    public let nextPredictedWindow: ClosedRange<Date>?

    public init(
        cycles: [PatternCyclePoint],
        dayLogs: [PatternDayLog],
        averageSeverity: Double,
        peakSeverity: Double,
        peakDate: Date,
        lastSeen: Date,
        lookbackStart: Date,
        lookbackEnd: Date,
        trend: PatternTrend,
        mostActiveDay: Int? = nil,
        mostActiveDayCycleCount: Int = 0,
        avgDaysAffected: Double = 0,
        coOccurringSymptomRaw: String? = nil,
        coOccurringSymptomCount: Int = 0,
        nextPredictedWindow: ClosedRange<Date>? = nil
    ) {
        self.cycles = cycles
        self.dayLogs = dayLogs
        self.averageSeverity = averageSeverity
        self.peakSeverity = peakSeverity
        self.peakDate = peakDate
        self.lastSeen = lastSeen
        self.lookbackStart = lookbackStart
        self.lookbackEnd = lookbackEnd
        self.trend = trend
        self.mostActiveDay = mostActiveDay
        self.mostActiveDayCycleCount = mostActiveDayCycleCount
        self.avgDaysAffected = avgDaysAffected
        self.coOccurringSymptomRaw = coOccurringSymptomRaw
        self.coOccurringSymptomCount = coOccurringSymptomCount
        self.nextPredictedWindow = nextPredictedWindow
    }

    /// Empty / loading-state metrics. Caller renders skeleton-ish
    /// values until the real query resolves.
    public static func empty(window: ClosedRange<Date>) -> PatternMetrics {
        PatternMetrics(
            cycles: [],
            dayLogs: [],
            averageSeverity: 0,
            peakSeverity: 0,
            peakDate: window.upperBound,
            lastSeen: window.upperBound,
            lookbackStart: window.lowerBound,
            lookbackEnd: window.upperBound,
            trend: .justAppearing
        )
    }
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
            removeSymptom: { _, _ in },
            getSymptoms: { _ in [] },
            generatePrediction: { },
            getProfile: { nil },
            saveProfile: { _, _, _, _, _ in },
            unviewedRecapMonth: { nil },
            markAllRecapsViewed: { },
            detectPatterns: { [] },
            recentSymptoms: { _ in [] },
            patternMetrics: { _, _ in
                let now = Date()
                let start = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
                return .empty(window: start...now)
            }
        )
    }
}
