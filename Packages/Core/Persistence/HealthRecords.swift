import Foundation
import SwiftData

// MARK: - Self Report Record

/// Daily wellness check-in (energy, stress, sleep, mood on 1-5 scale).
/// One per day. The HBI score is computed from this + optional HealthKit data.
@Model
public final class SelfReportRecord {

    @Attribute(.allowsCloudEncryption)
    public var reportDate: Date = Date.now

    @Attribute(.allowsCloudEncryption)
    public var energyLevel: Int = 3

    @Attribute(.allowsCloudEncryption)
    public var stressLevel: Int = 3

    @Attribute(.allowsCloudEncryption)
    public var sleepQuality: Int = 3

    @Attribute(.allowsCloudEncryption)
    public var moodLevel: Int = 3

    @Attribute(.allowsCloudEncryption)
    public var notes: String?

    public var createdAt: Date = Date.now

    public init(
        reportDate: Date = .now,
        energyLevel: Int,
        stressLevel: Int,
        sleepQuality: Int,
        moodLevel: Int,
        notes: String? = nil,
        createdAt: Date = Date.now
    ) {
        self.reportDate = reportDate
        self.energyLevel = max(1, min(5, energyLevel))
        self.stressLevel = max(1, min(5, stressLevel))
        self.sleepQuality = max(1, min(5, sleepQuality))
        self.moodLevel = max(1, min(5, moodLevel))
        self.notes = notes
        self.createdAt = createdAt
    }
}

// MARK: - HBI Score Record

/// Hormonal Balance Index — computed daily from self-reports, HealthKit, and cycle phase.
/// Scores are 0-100 per component and composite.
@Model
public final class HBIScoreRecord {

    @Attribute(.allowsCloudEncryption)
    public var scoreDate: Date = Date.now

    // Component scores (0-100)

    @Attribute(.allowsCloudEncryption)
    public var energyScore: Double = 0

    @Attribute(.allowsCloudEncryption)
    public var anxietyScore: Double = 0

    @Attribute(.allowsCloudEncryption)
    public var sleepScore: Double = 0

    @Attribute(.allowsCloudEncryption)
    public var moodScore: Double = 0

    @Attribute(.allowsCloudEncryption)
    public var clarityScore: Double?

    // Composite scores

    @Attribute(.allowsCloudEncryption)
    public var hbiRaw: Double = 0

    @Attribute(.allowsCloudEncryption)
    public var hbiAdjusted: Double = 0

    // Cycle context at time of calculation

    @Attribute(.allowsCloudEncryption)
    public var cyclePhase: String?
    @Attribute(.allowsCloudEncryption)
    public var cycleDay: Int?
    public var phaseMultiplier: Double?

    // Trend

    public var trendVsBaseline: Double?
    public var trendDirection: String?

    // Data completeness

    public var hasHealthKitData: Bool = false
    public var hasSelfReport: Bool = true
    public var completenessScore: Double = 50

    public var createdAt: Date = Date.now

    public init(
        scoreDate: Date,
        energyScore: Double,
        anxietyScore: Double,
        sleepScore: Double,
        moodScore: Double,
        clarityScore: Double? = nil,
        hbiRaw: Double,
        hbiAdjusted: Double,
        cyclePhase: String? = nil,
        cycleDay: Int? = nil,
        phaseMultiplier: Double? = nil,
        trendVsBaseline: Double? = nil,
        trendDirection: String? = nil,
        hasHealthKitData: Bool = false,
        hasSelfReport: Bool = true,
        completenessScore: Double = 50,
        createdAt: Date = Date.now
    ) {
        self.scoreDate = scoreDate
        self.energyScore = energyScore
        self.anxietyScore = anxietyScore
        self.sleepScore = sleepScore
        self.moodScore = moodScore
        self.clarityScore = clarityScore
        self.hbiRaw = hbiRaw
        self.hbiAdjusted = hbiAdjusted
        self.cyclePhase = cyclePhase
        self.cycleDay = cycleDay
        self.phaseMultiplier = phaseMultiplier
        self.trendVsBaseline = trendVsBaseline
        self.trendDirection = trendDirection
        self.hasHealthKitData = hasHealthKitData
        self.hasSelfReport = hasSelfReport
        self.completenessScore = completenessScore
        self.createdAt = createdAt
    }
}
