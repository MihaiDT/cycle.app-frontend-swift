import Foundation
import SwiftData

// MARK: - Journey Data Transport

public struct JourneyData: Sendable, Equatable {
    public let records: [JourneyCycleInput]
    public let predictions: [JourneyPredictionInput]
    public let reports: [JourneyReportInput]
    public let profileAvgCycleLength: Int
    public let profileAvgBleedingDays: Int
    public let currentCycleStartDate: Date?
}

public struct JourneyReportInput: Sendable, Equatable {
    public let date: Date
    public let energy: Int
    public let mood: Int
    public let stress: Int
    public let sleep: Int
}

// JourneyCycleInput is defined in CycleJourneyEngine.swift (flat compilation target)

public struct JourneyPredictionInput: Sendable, Equatable {
    public let predictedDate: Date
    public let confidenceLevel: Double

    public init(predictedDate: Date, confidenceLevel: Double) {
        self.predictedDate = predictedDate
        self.confidenceLevel = confidenceLevel
    }
}

// MARK: - Live Implementation

extension MenstrualLocalClient {
    static func liveJourneyData() -> @Sendable () async throws -> JourneyData {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)

            // Fetch all cycles
            let cycleDescriptor = FetchDescriptor<CycleRecord>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            let cycles = try context.fetch(cycleDescriptor)

            // Fetch unconfirmed predictions for future cycles
            let predDescriptor = FetchDescriptor<PredictionRecord>(
                predicate: #Predicate<PredictionRecord> { !$0.isConfirmed },
                sortBy: [SortDescriptor(\.predictedDate)]
            )
            let predictions = try context.fetch(predDescriptor)

            // Fetch all daily reports
            let reportDescriptor = FetchDescriptor<SelfReportRecord>(
                sortBy: [SortDescriptor(\.reportDate)]
            )
            let reports = try context.fetch(reportDescriptor)

            // Fetch profile
            let profileDescriptor = FetchDescriptor<MenstrualProfileRecord>()
            let profile = try context.fetch(profileDescriptor).first

            return JourneyData(
                records: cycles.map { cycle in
                    JourneyCycleInput(
                        startDate: cycle.startDate,
                        endDate: cycle.endDate,
                        bleedingDays: cycle.bleedingDays ?? 5,
                        actualCycleLength: cycle.actualCycleLength,
                        actualDeviationDays: cycle.actualDeviationDays,
                        isConfirmed: cycle.isConfirmed
                    )
                },
                predictions: predictions.prefix(3).map { pred in
                    JourneyPredictionInput(
                        predictedDate: pred.predictedDate,
                        confidenceLevel: pred.confidenceLevel
                    )
                },
                reports: reports.map { r in
                    JourneyReportInput(
                        date: r.reportDate,
                        energy: r.energyLevel,
                        mood: r.moodLevel,
                        stress: r.stressLevel,
                        sleep: r.sleepQuality
                    )
                },
                profileAvgCycleLength: profile?.avgCycleLength ?? 28,
                profileAvgBleedingDays: profile?.avgBleedingDays ?? 5,
                currentCycleStartDate: cycles.first?.startDate
            )
        }
    }
}
