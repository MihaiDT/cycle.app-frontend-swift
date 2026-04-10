import Foundation
import SwiftData

// MARK: - Menstrual Profile Record

/// Cycle tracking configuration — one per device.
/// Stores averages and preferences from onboarding + ongoing tracking.
@Model
public final class MenstrualProfileRecord {

    @Attribute(.allowsCloudEncryption)
    public var avgCycleLength: Int = 28

    @Attribute(.allowsCloudEncryption)
    public var avgBleedingDays: Int = 5

    @Attribute(.allowsCloudEncryption)
    public var cycleRegularity: String = "unknown"

    @Attribute(.allowsCloudEncryption)
    public var typicalSymptoms: [String] = []

    @Attribute(.allowsCloudEncryption)
    public var typicalFlowIntensity: String?

    @Attribute(.allowsCloudEncryption)
    public var usesContraception: Bool = false

    @Attribute(.allowsCloudEncryption)
    public var contraceptionType: String?

    /// User's manually-set cycle length (from onboarding or profile edit).
    /// Used as fallback when no observed cycle data is available.
    @Attribute(.allowsCloudEncryption)
    public var onboardingCycleLength: Int = 28

    /// Luteal phase length for ovulation estimation (default 14).
    /// Note: CloudKit schema has this as non-encrypted (NUMBER_INT64).
    /// Do NOT add .allowsCloudEncryption without resetting CloudKit Development environment.
    public var phaseLutealLength: Int = 14

    public var onboardingCompletedAt: Date?

    /// Date of the first period confirmed in-app. Journey shows cycles from this date forward.
    public var journeyStartDate: Date?

    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init(
        avgCycleLength: Int = 28,
        avgBleedingDays: Int = 5,
        cycleRegularity: String = "unknown",
        typicalSymptoms: [String] = [],
        typicalFlowIntensity: String? = nil,
        usesContraception: Bool = false,
        contraceptionType: String? = nil,
        phaseLutealLength: Int = 14,
        onboardingCompletedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = Date.now
    ) {
        self.avgCycleLength = max(18, min(50, avgCycleLength))
        self.onboardingCycleLength = max(18, min(50, avgCycleLength))
        self.avgBleedingDays = max(1, min(10, avgBleedingDays))
        self.cycleRegularity = cycleRegularity
        self.typicalSymptoms = typicalSymptoms
        self.typicalFlowIntensity = typicalFlowIntensity
        self.usesContraception = usesContraception
        self.contraceptionType = contraceptionType
        self.phaseLutealLength = phaseLutealLength
        self.onboardingCompletedAt = onboardingCompletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Cycle Record

/// A single menstrual cycle (period). Start date is Day 1.
/// Linked to predictions by date, not by relationship (simpler CloudKit sync).
@Model
public final class CycleRecord {

    @Attribute(.allowsCloudEncryption)
    public var startDate: Date = Date.now

    @Attribute(.allowsCloudEncryption)
    public var endDate: Date?

    @Attribute(.allowsCloudEncryption)
    public var bleedingDays: Int?

    @Attribute(.allowsCloudEncryption)
    public var flowIntensity: String?

    @Attribute(.allowsCloudEncryption)
    public var notes: String?

    /// Whether this cycle was confirmed by the user (vs auto-projected).
    public var isConfirmed: Bool = false

    /// Actual cycle length in days (calculated when next cycle starts).
    /// CloudKit schema: INT(64) non-encrypted
    public var actualCycleLength: Int?

    /// If this was predicted, the expected start date for accuracy tracking.
    @Attribute(.allowsCloudEncryption)
    public var predictedStartDate: Date?

    /// Days between predicted and actual start (positive = late, negative = early).
    @Attribute(.allowsCloudEncryption)
    public var actualDeviationDays: Int?

    public var createdAt: Date = Date.now

    public init(
        startDate: Date,
        endDate: Date? = nil,
        bleedingDays: Int? = nil,
        flowIntensity: String? = nil,
        notes: String? = nil,
        isConfirmed: Bool = true,
        actualCycleLength: Int? = nil,
        predictedStartDate: Date? = nil,
        actualDeviationDays: Int? = nil,
        createdAt: Date = Date.now
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.bleedingDays = bleedingDays.map { max(1, min(10, $0)) }
        self.flowIntensity = flowIntensity
        self.notes = notes
        self.isConfirmed = isConfirmed
        self.actualCycleLength = actualCycleLength.map { max(18, min(50, $0)) }
        self.predictedStartDate = predictedStartDate
        self.actualDeviationDays = actualDeviationDays
        self.createdAt = createdAt
    }
}

// MARK: - Symptom Record

/// A single symptom logged for a specific date.
@Model
public final class SymptomRecord {

    @Attribute(.allowsCloudEncryption)
    public var symptomDate: Date = Date.now

    @Attribute(.allowsCloudEncryption)
    public var symptomType: String = ""

    @Attribute(.allowsCloudEncryption)
    public var severity: Int = 3

    @Attribute(.allowsCloudEncryption)
    public var notes: String?

    /// 1-based day within the current cycle (filled by the engine at log time).
    public var cycleDay: Int?

    public var createdAt: Date = Date.now

    public init(
        symptomDate: Date,
        symptomType: String,
        severity: Int = 3,
        notes: String? = nil,
        cycleDay: Int? = nil,
        createdAt: Date = Date.now
    ) {
        self.symptomDate = symptomDate
        self.symptomType = symptomType
        self.severity = min(5, max(1, severity))
        self.notes = notes
        self.cycleDay = cycleDay
        self.createdAt = createdAt
    }
}

// MARK: - Prediction Record

/// A generated prediction for the next period.
/// Accuracy is tracked when the user confirms the actual period start.
@Model
public final class PredictionRecord {

    @Attribute(.allowsCloudEncryption)
    public var predictedDate: Date = Date.now

    @Attribute(.allowsCloudEncryption)
    public var rangeStart: Date = Date.now

    @Attribute(.allowsCloudEncryption)
    public var rangeEnd: Date = Date.now

    public var confidenceLevel: Double = 0.5

    /// Algorithm that generated this prediction (v1_basic, v2_statistical, v3_historical, v4_ml).
    public var algorithmVersion: String = "v1_basic"

    /// Number of cycles used as input for this prediction.
    public var basedOnCycles: Int = 0

    // Fertile window derived from this prediction

    @Attribute(.allowsCloudEncryption)
    public var fertileWindowStart: Date?

    @Attribute(.allowsCloudEncryption)
    public var fertileWindowEnd: Date?

    @Attribute(.allowsCloudEncryption)
    public var ovulationDate: Date?

    // Accuracy tracking (filled when confirmed)

    @Attribute(.allowsCloudEncryption)
    public var actualStartDate: Date?

    public var accuracyDays: Int?

    /// Whether the user has confirmed this prediction's period.
    public var isConfirmed: Bool = false

    public var createdAt: Date = Date.now

    public init(
        predictedDate: Date,
        rangeStart: Date,
        rangeEnd: Date,
        confidenceLevel: Double,
        algorithmVersion: String,
        basedOnCycles: Int,
        fertileWindowStart: Date? = nil,
        fertileWindowEnd: Date? = nil,
        ovulationDate: Date? = nil,
        actualStartDate: Date? = nil,
        accuracyDays: Int? = nil,
        isConfirmed: Bool = false,
        createdAt: Date = Date.now
    ) {
        self.predictedDate = predictedDate
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.confidenceLevel = confidenceLevel
        self.algorithmVersion = algorithmVersion
        self.basedOnCycles = basedOnCycles
        self.fertileWindowStart = fertileWindowStart
        self.fertileWindowEnd = fertileWindowEnd
        self.ovulationDate = ovulationDate
        self.actualStartDate = actualStartDate
        self.accuracyDays = accuracyDays
        self.isConfirmed = isConfirmed
        self.createdAt = createdAt
    }
}
