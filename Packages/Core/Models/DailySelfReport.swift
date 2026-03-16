import Foundation
import Tagged

// MARK: - Daily Self Report

public struct DailySelfReport: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = Tagged<DailySelfReport, Int64>

    public let id: ID
    public let userId: Int64
    public let reportDate: Date
    public let energyLevel: Int  // 1-5
    public let stressLevel: Int  // 1-5
    public let sleepQuality: Int  // 1-5
    public let moodLevel: Int  // 1-5
    public let notes: String?
    public let createdAt: Date

    public init(
        id: ID,
        userId: Int64,
        reportDate: Date,
        energyLevel: Int,
        stressLevel: Int,
        sleepQuality: Int,
        moodLevel: Int,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.reportDate = reportDate
        self.energyLevel = energyLevel
        self.stressLevel = stressLevel
        self.sleepQuality = sleepQuality
        self.moodLevel = moodLevel
        self.notes = notes
        self.createdAt = createdAt
    }
}

// MARK: - Mock Data

extension DailySelfReport {
    public static let mock = DailySelfReport(
        id: .init(1),
        userId: 1,
        reportDate: .now,
        energyLevel: 4,
        stressLevel: 2,
        sleepQuality: 4,
        moodLevel: 5,
        notes: nil
    )
}
