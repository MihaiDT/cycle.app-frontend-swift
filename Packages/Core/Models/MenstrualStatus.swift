import Foundation

// MARK: - Menstrual Status Response (GET /api/menstrual/status)

public struct MenstrualStatusResponse: Codable, Equatable, Sendable {
    public let currentCycle: CycleInfo
    public let profile: MenstrualProfileInfo
    public let nextPrediction: PredictionInfo?
    public let fertileWindow: FertileWindowInfo?

    public init(
        currentCycle: CycleInfo,
        profile: MenstrualProfileInfo,
        nextPrediction: PredictionInfo? = nil,
        fertileWindow: FertileWindowInfo? = nil
    ) {
        self.currentCycle = currentCycle
        self.profile = profile
        self.nextPrediction = nextPrediction
        self.fertileWindow = fertileWindow
    }
}

// MARK: - Cycle Info

public struct CycleInfo: Codable, Equatable, Sendable {
    public let startDate: Date
    public let cycleDay: Int
    public let phase: String
    public let bleedingDays: Int

    public init(startDate: Date, cycleDay: Int, phase: String, bleedingDays: Int) {
        self.startDate = startDate
        self.cycleDay = cycleDay
        self.phase = phase
        self.bleedingDays = bleedingDays
    }
}

// MARK: - Profile Info

public struct MenstrualProfileInfo: Codable, Equatable, Sendable {
    public let avgCycleLength: Int
    public let cycleRegularity: String
    public let trackingSince: Date

    public init(avgCycleLength: Int, cycleRegularity: String, trackingSince: Date) {
        self.avgCycleLength = avgCycleLength
        self.cycleRegularity = cycleRegularity
        self.trackingSince = trackingSince
    }
}

// MARK: - Prediction Info

public struct PredictionInfo: Codable, Equatable, Sendable {
    public let predictedDate: Date
    public let daysUntil: Int
    public let confidenceScore: Double
    public let predictionRange: DateRangeInfo

    public init(predictedDate: Date, daysUntil: Int, confidenceScore: Double, predictionRange: DateRangeInfo) {
        self.predictedDate = predictedDate
        self.daysUntil = daysUntil
        self.confidenceScore = confidenceScore
        self.predictionRange = predictionRange
    }
}

// MARK: - Fertile Window Info

public struct FertileWindowInfo: Codable, Equatable, Sendable {
    public let start: Date
    public let peak: Date
    public let end: Date
    public let isActive: Bool
    public let daysUntilPeak: Int

    public init(start: Date, peak: Date, end: Date, isActive: Bool, daysUntilPeak: Int) {
        self.start = start
        self.peak = peak
        self.end = end
        self.isActive = isActive
        self.daysUntilPeak = daysUntilPeak
    }
}

// MARK: - Date Range Info

public struct DateRangeInfo: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

// MARK: - Mock

extension MenstrualStatusResponse {
    public static let mock = MenstrualStatusResponse(
        currentCycle: CycleInfo(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            cycleDay: 8,
            phase: "follicular",
            bleedingDays: 5
        ),
        profile: MenstrualProfileInfo(
            avgCycleLength: 28,
            cycleRegularity: "regular",
            trackingSince: Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        ),
        nextPrediction: PredictionInfo(
            predictedDate: Calendar.current.date(byAdding: .day, value: 21, to: Date())!,
            daysUntil: 21,
            confidenceScore: 0.85,
            predictionRange: DateRangeInfo(
                start: Calendar.current.date(byAdding: .day, value: 19, to: Date())!,
                end: Calendar.current.date(byAdding: .day, value: 23, to: Date())!
            )
        ),
        fertileWindow: FertileWindowInfo(
            start: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            peak: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            end: Calendar.current.date(byAdding: .day, value: 9, to: Date())!,
            isActive: false,
            daysUntilPeak: 7
        )
    )
}
