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

// MARK: - Insights Response (GET /api/menstrual/insights)

public struct MenstrualInsightsResponse: Codable, Equatable, Sendable {
    public let cycleStats: CycleStatsInfo
    public let predictionAccuracy: AccuracyInfo
    public let trends: [String]?
    public let recommendations: [String]?

    public init(cycleStats: CycleStatsInfo, predictionAccuracy: AccuracyInfo, trends: [String]? = nil, recommendations: [String]? = nil) {
        self.cycleStats = cycleStats
        self.predictionAccuracy = predictionAccuracy
        self.trends = trends
        self.recommendations = recommendations
    }
}

public struct CycleStatsInfo: Codable, Equatable, Sendable {
    public let averageCycleLength: Double
    public let regularity: String
    public let totalCyclesTracked: Int

    public init(averageCycleLength: Double, regularity: String, totalCyclesTracked: Int) {
        self.averageCycleLength = averageCycleLength
        self.regularity = regularity
        self.totalCyclesTracked = totalCyclesTracked
    }
}

public struct AccuracyInfo: Codable, Equatable, Sendable {
    public let averageAccuracy: Double
    public let confirmedCycles: Int
    public let totalPredictions: Int

    public init(averageAccuracy: Double, confirmedCycles: Int, totalPredictions: Int) {
        self.averageAccuracy = averageAccuracy
        self.confirmedCycles = confirmedCycles
        self.totalPredictions = totalPredictions
    }
}

// MARK: - Calendar Response (GET /api/menstrual/calendar)

public struct MenstrualCalendarResponse: Codable, Equatable, Sendable {
    public let startDate: Date
    public let endDate: Date
    public let entries: [MenstrualCalendarEntry]

    public init(startDate: Date, endDate: Date, entries: [MenstrualCalendarEntry]) {
        self.startDate = startDate
        self.endDate = endDate
        self.entries = entries
    }
}

public struct MenstrualCalendarEntry: Codable, Equatable, Sendable {
    public let date: Date
    public let type: String
    public let label: String

    public init(date: Date, type: String, label: String) {
        self.date = date
        self.type = type
        self.label = label
    }
}

// MARK: - Symptom Response (GET /api/menstrual/symptoms)

public struct MenstrualSymptomResponse: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let symptomDate: Date
    public let symptomType: String
    public let severity: Int
    public let notes: String?

    public init(id: Int, symptomDate: Date, symptomType: String, severity: Int, notes: String? = nil) {
        self.id = id
        self.symptomDate = symptomDate
        self.symptomType = symptomType
        self.severity = severity
        self.notes = notes
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

extension MenstrualInsightsResponse {
    public static let mock = MenstrualInsightsResponse(
        cycleStats: CycleStatsInfo(averageCycleLength: 28.5, regularity: "regular", totalCyclesTracked: 6),
        predictionAccuracy: AccuracyInfo(averageAccuracy: 0.85, confirmedCycles: 4, totalPredictions: 6),
        trends: ["Cycles are stable", "Sleep quality improving during follicular phase"],
        recommendations: ["Confirm your periods to improve prediction accuracy", "Track symptoms daily for personalized insights"]
    )
}

extension MenstrualCalendarResponse {
    public static let mock = MenstrualCalendarResponse(
        startDate: Calendar.current.date(byAdding: .month, value: -1, to: Date())!,
        endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
        entries: []
    )
}
