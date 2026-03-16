import Foundation
import Tagged

// MARK: - HBI Score

public struct HBIScore: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = Tagged<HBIScore, Int64>

    public let id: ID
    public let userId: Int64
    public let scoreDate: Date

    // Component scores (0-100)
    public let energyScore: Int
    public let anxietyScore: Int
    public let sleepScore: Int
    public let moodScore: Int
    public let clarityScore: Int?

    // Overall HBI scores
    public let hbiRaw: Int
    public let hbiAdjusted: Int

    // Cycle context
    public let cyclePhase: String?
    public let cycleDay: Int?
    public let phaseMultiplier: Double?

    // Trend analysis
    public let trendVsBaseline: Double?
    public let trendDirection: String?  // "up", "down", "stable"

    // Data completeness
    public let hasHealthkitData: Bool
    public let hasSelfReport: Bool
    public let completenessScore: Int?

    public let createdAt: Date

    public init(
        id: ID,
        userId: Int64,
        scoreDate: Date,
        energyScore: Int,
        anxietyScore: Int,
        sleepScore: Int,
        moodScore: Int,
        clarityScore: Int? = nil,
        hbiRaw: Int,
        hbiAdjusted: Int,
        cyclePhase: String? = nil,
        cycleDay: Int? = nil,
        phaseMultiplier: Double? = nil,
        trendVsBaseline: Double? = nil,
        trendDirection: String? = nil,
        hasHealthkitData: Bool = false,
        hasSelfReport: Bool = false,
        completenessScore: Int? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
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
        self.hasHealthkitData = hasHealthkitData
        self.hasSelfReport = hasSelfReport
        self.completenessScore = completenessScore
        self.createdAt = createdAt
    }
}

// MARK: - Mock Data

extension HBIScore {
    public static let mock = HBIScore(
        id: .init(1),
        userId: 1,
        scoreDate: .now,
        energyScore: 72,
        anxietyScore: 65,
        sleepScore: 80,
        moodScore: 75,
        clarityScore: 70,
        hbiRaw: 73,
        hbiAdjusted: 76,
        cyclePhase: "follicular",
        cycleDay: 8,
        phaseMultiplier: 1.05,
        trendVsBaseline: 3.5,
        trendDirection: "up",
        hasHealthkitData: false,
        hasSelfReport: true,
        completenessScore: 60
    )
}
