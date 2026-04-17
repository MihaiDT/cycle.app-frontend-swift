import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - Live Factory

extension MenstrualLocalClient {
    static func live() -> Self {
        MenstrualLocalClient(
            getStatus: liveGetStatus(),
            getCalendar: liveGetCalendar(),
            getCycleStats: liveGetCycleStats(),
            resetAllCycleData: liveResetAllCycleData(),
            confirmPeriod: liveConfirmPeriod(),
            removePeriodDays: liveRemovePeriodDays(),
            getJourneyData: liveJourneyData(),
            logSymptom: liveLogSymptom(),
            getSymptoms: liveGetSymptoms(),
            generatePrediction: liveGeneratePrediction(),
            getProfile: liveGetProfile(),
            saveProfile: liveSaveProfile(),
            unviewedRecapMonth: liveUnviewedRecapMonth(),
            markAllRecapsViewed: liveMarkAllRecapsViewed()
        )
    }

    // MARK: - Shared Helpers

    static func fetchProfile(context: ModelContext) throws -> MenstrualProfileRecord? {
        let descriptor = FetchDescriptor<MenstrualProfileRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    static func fetchLatestCycle(context: ModelContext) throws -> CycleRecord? {
        let descriptor = FetchDescriptor<CycleRecord>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    static func fetchAllCycles(context: ModelContext) throws -> [CycleRecord] {
        let descriptor = FetchDescriptor<CycleRecord>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    static func fetchActivePrediction(context: ModelContext) throws -> PredictionRecord? {
        let today = Calendar.current.startOfDay(for: Date())
        let cutoff = CycleMath.addDays(today, -60)
        let descriptor = FetchDescriptor<PredictionRecord>(
            predicate: #Predicate<PredictionRecord> { pred in
                !pred.isConfirmed && pred.predictedDate >= cutoff
            },
            sortBy: [SortDescriptor(\.predictedDate)]
        )
        return try context.fetch(descriptor).first
    }

    /// Recalculate all actualCycleLength values and profile stats from scratch.
    /// Ensures consistency regardless of edit order.
    static func recalculateCycleStats(context: ModelContext) throws {
        let cycles = try fetchAllCycles(context: context) // sorted by startDate desc
        let sorted = cycles.reversed() // oldest first

        // Reset all actualCycleLength, then recompute from gaps
        for cycle in sorted {
            cycle.actualCycleLength = nil
        }
        let arr = Array(sorted)
        for i in 0..<arr.count {
            if i + 1 < arr.count {
                let gap = CycleMath.cycleLength(
                    periodStart1: arr[i].startDate, periodStart2: arr[i + 1].startDate
                )
                if gap >= 18, gap <= 50 {
                    arr[i].actualCycleLength = gap
                }
            }
        }

        // Recalculate profile
        if let profile = try fetchProfile(context: context) {
            let bleedingValues = arr.compactMap(\.bleedingDays)
            if !bleedingValues.isEmpty {
                profile.avgBleedingDays = Int(round(CycleMath.mean(bleedingValues)))
            }

            var cycleLengths: [Int] = []
            for cycle in arr {
                if let len = cycle.actualCycleLength {
                    cycleLengths.append(len)
                }
            }
            if !cycleLengths.isEmpty {
                profile.avgCycleLength = Int(round(CycleMath.mean(cycleLengths)))
                profile.cycleRegularity = CycleMath.classifyVariability(cycleLengths)
                // Promote observed average to baseline once we have enough data
                if cycleLengths.count >= 3 {
                    profile.onboardingCycleLength = profile.avgCycleLength
                }
            } else {
                // No observed cycle gaps — revert to baseline
                profile.avgCycleLength = profile.onboardingCycleLength
            }
            profile.updatedAt = .now
        }

        try context.save()
    }

    /// Remove duplicate CycleRecords sharing the same startDate, keeping the newest.
    static func deduplicateCycles(context: ModelContext) throws {
        let all = try fetchAllCycles(context: context)
        var seen: [Date: CycleRecord] = [:]
        for cycle in all {
            let key = Calendar.current.startOfDay(for: cycle.startDate)
            if let existing = seen[key] {
                // Keep whichever was created/updated more recently
                if cycle.startDate > existing.startDate {
                    context.delete(existing)
                    seen[key] = cycle
                } else {
                    context.delete(cycle)
                }
            } else {
                seen[key] = cycle
            }
        }
        try context.save()
    }
}
