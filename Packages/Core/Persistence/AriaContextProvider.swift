import Foundation
import SwiftData

// MARK: - Aria Ephemeral Context

/// Health context sent with each Aria chat message.
/// Backend includes this in Claude's system prompt but does NOT store it.
public struct AriaEphemeralContext: Codable, Sendable, Equatable {
    public let cyclePhase: String?
    public let cycleDay: Int?
    public let hbiScore: Int?
    public let mood: Int?
    public let energy: Int?
    public let recentSymptoms: [String]

    public init(
        cyclePhase: String? = nil,
        cycleDay: Int? = nil,
        hbiScore: Int? = nil,
        mood: Int? = nil,
        energy: Int? = nil,
        recentSymptoms: [String] = []
    ) {
        self.cyclePhase = cyclePhase
        self.cycleDay = cycleDay
        self.hbiScore = hbiScore
        self.mood = mood
        self.energy = energy
        self.recentSymptoms = recentSymptoms
    }
}

// MARK: - Context Provider

/// Builds ephemeral health context from local SwiftData for Aria chat messages.
public enum AriaContextProvider {

    /// Gather current health context from on-device data.
    /// This context is transient — sent with each message, never stored server-side.
    public static func currentContext(container: ModelContainer) -> AriaEphemeralContext {
        let context = ModelContext(container)

        // Latest cycle
        let cycleDescriptor = FetchDescriptor<CycleRecord>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let latestCycle = try? context.fetch(cycleDescriptor).first

        // Profile
        let profileDescriptor = FetchDescriptor<MenstrualProfileRecord>()
        let profile = try? context.fetch(profileDescriptor).first

        // Latest HBI score
        let scoreDescriptor = FetchDescriptor<HBIScoreRecord>(
            sortBy: [SortDescriptor(\.scoreDate, order: .reverse)]
        )
        let latestScore = try? context.fetch(scoreDescriptor).first

        // Latest self-report
        let reportDescriptor = FetchDescriptor<SelfReportRecord>(
            sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
        )
        let latestReport = try? context.fetch(reportDescriptor).first

        // Recent symptoms (last 7 days)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let symptomDescriptor = FetchDescriptor<SymptomRecord>(
            predicate: #Predicate { $0.symptomDate >= weekAgo },
            sortBy: [SortDescriptor(\.symptomDate, order: .reverse)]
        )
        let recentSymptoms = (try? context.fetch(symptomDescriptor))?.map(\.symptomType) ?? []

        // Compute phase
        var phase: String?
        var cycleDay: Int?
        if let cycle = latestCycle {
            let today = Calendar.current.startOfDay(for: Date())
            let day = CycleMath.cycleDay(cycleStart: cycle.startDate, date: today)
            let cl = profile?.avgCycleLength ?? 28
            let bd = cycle.bleedingDays ?? profile?.avgBleedingDays ?? 5
            phase = CycleMath.cyclePhase(cycleDay: day, cycleLength: cl, bleedingDays: bd).rawValue
            cycleDay = day
        }

        return AriaEphemeralContext(
            cyclePhase: phase,
            cycleDay: cycleDay,
            hbiScore: latestScore.map { Int($0.hbiAdjusted) },
            mood: latestReport?.moodLevel,
            energy: latestReport?.energyLevel,
            recentSymptoms: Array(Set(recentSymptoms))
        )
    }
}
