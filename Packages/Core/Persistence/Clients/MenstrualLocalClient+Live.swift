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
            cleanupDuplicateCycles: liveCleanupDuplicateCycles(),
            confirmPeriod: liveConfirmPeriod(),
            removePeriodDays: liveRemovePeriodDays(),
            getJourneyData: liveJourneyData(),
            logSymptom: liveLogSymptom(),
            removeSymptom: liveRemoveSymptom(),
            getSymptoms: liveGetSymptoms(),
            generatePrediction: liveGeneratePrediction(),
            getProfile: liveGetProfile(),
            saveProfile: liveSaveProfile(),
            setCycleLengthOverride: liveSetCycleLengthOverride(),
            getCycleLengthOverride: liveGetCycleLengthOverride(),
            getRecommendedCycleLength: liveGetRecommendedCycleLength(),
            getEffectiveCycleLength: liveGetEffectiveCycleLength(),
            setPeriodLengthOverride: liveSetPeriodLengthOverride(),
            getPeriodLengthOverride: liveGetPeriodLengthOverride(),
            getRecommendedPeriodLength: liveGetRecommendedPeriodLength(),
            getEffectivePeriodLength: liveGetEffectivePeriodLength(),
            getShowOvulation: liveGetShowOvulation(),
            setShowOvulation: liveSetShowOvulation(),
            getShowFertileWindow: liveGetShowFertileWindow(),
            setShowFertileWindow: liveSetShowFertileWindow(),
            unviewedRecapMonth: liveUnviewedRecapMonth(),
            markAllRecapsViewed: liveMarkAllRecapsViewed(),
            detectPatterns: liveDetectPatterns(),
            recentSymptoms: liveRecentSymptoms(),
            patternMetrics: livePatternMetrics()
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

        // Recalculate profile — only use cycles that have actually
        // happened. A CycleRecord dated in the future would pull
        // avgCycleLength toward a nonsense observed length.
        let nowDay = CycleMath.startOfDay(Date())
        let pastCycles = arr.filter { $0.startDate <= nowDay }
        if let profile = try fetchProfile(context: context) {
            let bleedingValues = pastCycles.compactMap(\.bleedingDays)
            if !bleedingValues.isEmpty && !profile.useManualPeriodLength {
                profile.avgBleedingDays = Int(round(CycleMath.mean(bleedingValues)))
            }

            var cycleLengths: [Int] = []
            for cycle in pastCycles {
                if let len = cycle.actualCycleLength {
                    cycleLengths.append(len)
                }
            }
            if !cycleLengths.isEmpty {
                // Manual override mode: user pinned the cycle length —
                // keep `avgCycleLength` untouched, only refresh regularity.
                if !profile.useManualCycleLength {
                    profile.avgCycleLength = Int(round(CycleMath.mean(cycleLengths)))
                    // Promote observed average to baseline once we have enough data
                    if cycleLengths.count >= 3 {
                        profile.onboardingCycleLength = profile.avgCycleLength
                    }
                }
                profile.cycleRegularity = CycleMath.classifyVariability(cycleLengths)
            } else if !profile.useManualCycleLength {
                // No observed cycle gaps — fall back to 28 instead of
                // `onboardingCycleLength`. Earlier code paths leaked
                // manual override values into `onboardingCycleLength`,
                // so using it as a baseline silently re-pinned the
                // old manual value after the user switched away from
                // Manual mode.
                profile.avgCycleLength = 28
            }

            // Keep `journeyStartDate` anchored to the oldest logged
            // cycle. It was originally stamped once on the very first
            // confirm and never moved, so back-logging a past period
            // (e.g. a cycle the user forgot to log last month) left
            // that cycle hidden from Journey / Cycle History — their
            // filter is `startDate >= journeyStartDate`. Re-anchoring
            // here on every recalc guarantees every real cycle on
            // file is part of the journey the UI shows.
            if let firstStart = arr.first?.startDate {
                if profile.journeyStartDate == nil
                    || (profile.journeyStartDate.map { $0 > firstStart } ?? false) {
                    profile.journeyStartDate = firstStart
                }
            }

            profile.updatedAt = .now
        }

        try context.save()
    }

    static func liveCleanupDuplicateCycles() -> @Sendable () async throws -> Void {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            try deduplicateCycles(context: context)
            // Gaps may have changed after collapse — recompute so the
            // stats screen reflects real cycle lengths, not the stale
            // ones computed against the removed duplicate.
            try recalculateCycleStats(context: context)
        }
    }

    /// Collapse duplicate and overlapping CycleRecords down to a
    /// single record per real period. Two cycles overlap when their
    /// bleed ranges intersect (previously we only matched on exact
    /// `startDate` — an edit that shifted a period start by a day
    /// would leave the original record orphaned with a stale
    /// `startDate`, so two cycles ended up in Cycle History showing
    /// the same bleed with different labels).
    ///
    /// Iteration order: newest `startDate` first. When we find a
    /// later record that overlaps with one we already kept, the
    /// kept (newer) record wins and the older duplicate is deleted.
    static func deduplicateCycles(context: ModelContext) throws {
        let all = try fetchAllCycles(context: context) // sorted startDate desc
        var kept: [CycleRecord] = []
        for cycle in all {
            let start = Calendar.current.startOfDay(for: cycle.startDate)
            let bleed = cycle.bleedingDays ?? 5
            let end = CycleMath.addDays(start, bleed - 1)
            let overlapsKept = kept.contains { other in
                let oStart = Calendar.current.startOfDay(for: other.startDate)
                let oEnd = CycleMath.addDays(oStart, (other.bleedingDays ?? 5) - 1)
                return start <= oEnd && end >= oStart
            }
            if overlapsKept {
                context.delete(cycle)
            } else {
                kept.append(cycle)
            }
        }
        try context.save()
    }
}
