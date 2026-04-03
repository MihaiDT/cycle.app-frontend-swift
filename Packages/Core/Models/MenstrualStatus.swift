import Foundation
import SwiftUI

// MARK: - Menstrual Status Response (GET /api/menstrual/status)

public struct MenstrualStatusResponse: Codable, Equatable, Sendable {
    public let currentCycle: CycleInfo
    public let profile: MenstrualProfileInfo
    public let nextPrediction: PredictionInfo?
    public let fertileWindow: FertileWindowInfo?
    public let hasCycleData: Bool

    public init(
        currentCycle: CycleInfo,
        profile: MenstrualProfileInfo,
        nextPrediction: PredictionInfo? = nil,
        fertileWindow: FertileWindowInfo? = nil,
        hasCycleData: Bool = true
    ) {
        self.currentCycle = currentCycle
        self.profile = profile
        self.nextPrediction = nextPrediction
        self.fertileWindow = fertileWindow
        self.hasCycleData = hasCycleData
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentCycle = try container.decode(CycleInfo.self, forKey: .currentCycle)
        profile = try container.decode(MenstrualProfileInfo.self, forKey: .profile)
        nextPrediction = try container.decodeIfPresent(PredictionInfo.self, forKey: .nextPrediction)
        fertileWindow = try container.decodeIfPresent(FertileWindowInfo.self, forKey: .fertileWindow)
        hasCycleData = (try? container.decodeIfPresent(Bool.self, forKey: .hasCycleData)) ?? true
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
    public let isLate: Bool
    public let daysLate: Int

    public init(
        predictedDate: Date,
        daysUntil: Int,
        confidenceScore: Double,
        predictionRange: DateRangeInfo,
        isLate: Bool = false,
        daysLate: Int = 0
    ) {
        self.predictedDate = predictedDate
        self.daysUntil = daysUntil
        self.confidenceScore = confidenceScore
        self.predictionRange = predictionRange
        self.isLate = isLate
        self.daysLate = daysLate
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
    public let fertilityLevel: String?

    public init(date: Date, type: String, label: String, fertilityLevel: String? = nil) {
        self.date = date
        self.type = type
        self.label = label
        self.fertilityLevel = fertilityLevel
    }
}

// MARK: - Fertility Level

public enum FertilityLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case low
    case medium
    case high
    case peak

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .peak: "Peak"
        }
    }

    /// Color for calendar visualization (warm gradient: teal → gold)
    public var color: Color {
        switch self {
        case .low: Color(red: 0.36, green: 0.72, blue: 0.65).opacity(0.4) // Teal light
        case .medium: Color(red: 0.36, green: 0.72, blue: 0.65)           // Teal
        case .high: Color(red: 0.91, green: 0.66, blue: 0.22).opacity(0.7) // Amber warm
        case .peak: Color(red: 0.91, green: 0.66, blue: 0.22)             // Amber Gold
        }
    }

    /// Probability of conception (Wilcox et al. 2000 BMJ)
    public var probability: String {
        switch self {
        case .low: "~4%"
        case .medium: "~15%"
        case .high: "~25%"
        case .peak: "~30%"
        }
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

// MARK: - Cycle Stats Response (GET /api/menstrual/cycle-stats)

public struct CycleStatsDetailedResponse: Codable, Equatable, Sendable {
    public let cycleLength: CycleLengthStats
    public let currentCycle: CurrentCycleStats
    public let totalTracked: Int
    public let trackingSince: Date?
}

public struct CycleLengthStats: Codable, Equatable, Sendable {
    public let average: Double
    public let min: Int
    public let max: Int
    public let stdDev: Double
    public let history: [CycleHistoryPoint]
    public let trend: String
}

public struct CycleHistoryPoint: Codable, Equatable, Sendable, Identifiable {
    public let startDate: Date
    public let length: Int
    public let bleeding: Int

    public var id: Date { startDate }
}

public struct CurrentCycleStats: Codable, Equatable, Sendable {
    public let day: Int
    public let cycleLength: Int
    public let delayContext: String
    public let delayDays: Int
}

extension CycleStatsDetailedResponse {
    public static let mock = CycleStatsDetailedResponse(
        cycleLength: CycleLengthStats(
            average: 28.5, min: 26, max: 31, stdDev: 1.8,
            history: [
                CycleHistoryPoint(startDate: Date(), length: 28, bleeding: 5),
                CycleHistoryPoint(startDate: Date(), length: 27, bleeding: 4),
                CycleHistoryPoint(startDate: Date(), length: 31, bleeding: 5),
            ],
            trend: "stable"
        ),
        currentCycle: CurrentCycleStats(day: 35, cycleLength: 28, delayContext: "slightly_outside", delayDays: 7),
        totalTracked: 6,
        trackingSince: nil
    )
}
