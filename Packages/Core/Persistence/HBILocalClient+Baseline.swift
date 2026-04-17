import Foundation
import SwiftData

// MARK: - Personal Baseline Live Query

extension HBILocalClient {

    /// Live implementation of `getPersonalBaseline`.
    ///
    /// Reads every `HBIScoreRecord` with a matching `cyclePhase.rawValue`,
    /// converts them to domain `HBIScore` values, then delegates to
    /// `HBICalculator.personalBaseline` for the pure math.
    static func liveGetPersonalBaseline() -> @Sendable (_ phase: CyclePhase) async throws -> PersonalBaseline {
        return { phase in
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            return try computePersonalBaseline(phase: phase, context: context)
        }
    }

    /// Shared implementation — also used by the save path so a single
    /// context/transaction can compute the baseline and persist the score.
    static func computePersonalBaseline(
        phase: CyclePhase,
        context: ModelContext
    ) throws -> PersonalBaseline {
        let phaseRaw = phase.rawValue
        let descriptor = FetchDescriptor<HBIScoreRecord>(
            predicate: #Predicate<HBIScoreRecord> { record in
                record.cyclePhase == phaseRaw
            },
            sortBy: [SortDescriptor(\.scoreDate)]
        )
        let records = try context.fetch(descriptor)
        let scores = records.map { $0.toHBIScore() }
        return HBICalculator.personalBaseline(
            phase: phase,
            historicalScores: scores
        )
    }
}
