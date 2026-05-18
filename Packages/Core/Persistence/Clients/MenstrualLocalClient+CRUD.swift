import Foundation
import SwiftData

// MARK: - CRUD Operations

extension MenstrualLocalClient {
    // MARK: resetAllCycleData (TEMP)

    static func liveResetAllCycleData() -> @Sendable () async throws -> Void {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            for record in try context.fetch(FetchDescriptor<CycleRecord>()) { context.delete(record) }
            for record in try context.fetch(FetchDescriptor<PredictionRecord>()) { context.delete(record) }
            for record in try context.fetch(FetchDescriptor<SymptomRecord>()) { context.delete(record) }
            for record in try context.fetch(FetchDescriptor<MenstrualProfileRecord>()) { context.delete(record) }
            for record in try context.fetch(FetchDescriptor<CycleRecapRecord>()) { context.delete(record) }
            for record in try context.fetch(FetchDescriptor<WellnessMessageRecord>()) { context.delete(record) }
            try context.save()
            UserDefaults.standard.removeObject(forKey: "ViewedRecapCycleKeys")
            UserDefaults.standard.set(Date(), forKey: "CycleDataResetDate")
        }
    }

    // MARK: confirmPeriod

    static func liveConfirmPeriod() -> @Sendable (Date, Int, String?, Bool) async throws -> Void {
        return { startDate, bleedingDays, notes, skipPredictions in
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let start = Calendar.current.startOfDay(for: startDate)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
            // Validation: reject future dates, clamp bleeding days
            guard start <= tomorrow else { return }
            let bleedingDays = CycleMath.validateBleedingDays(bleedingDays, cycleLength: 28)

            // Match to prediction for accuracy tracking
            let predDescriptor = FetchDescriptor<PredictionRecord>(
                predicate: #Predicate<PredictionRecord> { !$0.isConfirmed },
                sortBy: [SortDescriptor(\.predictedDate)]
            )
            let predictions = try context.fetch(predDescriptor)
            // Rank by distance — pick the closest prediction within ±14 days
            let matchedPrediction = predictions
                .map { ($0, abs(CycleMath.daysBetween($0.predictedDate, start))) }
                .filter { $0.1 <= 14 }
                .min(by: { $0.1 < $1.1 })
                .map(\.0)

            // Find every existing cycle whose bleed days overlap
            // the new period's date range. Previously this was an
            // exact `startDate == start` match, which let an edit
            // like "shift period from Mar 22–29 to Mar 24–29" create
            // a second cycle alongside the first instead of replacing
            // it — two CycleRecords with overlapping period ranges,
            // both rendered in Cycle History as "Period: 6 days".
            let newEnd = CycleMath.addDays(start, bleedingDays - 1)
            let allCycles = try fetchAllCycles(context: context)
            let overlappingCycles = allCycles.filter { cycle in
                let cycleStart = Calendar.current.startOfDay(for: cycle.startDate)
                let cycleBleed = cycle.bleedingDays ?? 5
                let cycleEnd = CycleMath.addDays(cycleStart, cycleBleed - 1)
                return cycleStart <= newEnd && cycleEnd >= start
            }

            // Update previous cycle's length (only if this is a truly
            // new cycle — no overlap with existing records).
            if overlappingCycles.isEmpty {
                let latestCycle = try fetchLatestCycle(context: context)
                if let prev = latestCycle, prev.startDate != start {
                    let gap = CycleMath.cycleLength(
                        periodStart1: prev.startDate, periodStart2: start
                    )
                    if gap >= 18, gap <= 50 {
                        prev.actualCycleLength = gap
                    }
                }
            }

            // Delete every overlapping record — we insert a single
            // fresh one right after, so the upsert stays idempotent
            // no matter how many stale duplicates accumulated.
            for existing in overlappingCycles {
                context.delete(existing)
            }

            // Create cycle record
            let cycle = CycleRecord(
                startDate: start,
                endDate: CycleMath.addDays(start, bleedingDays - 1),
                bleedingDays: bleedingDays,
                notes: notes,
                isConfirmed: true,
                predictedStartDate: matchedPrediction?.predictedDate,
                actualDeviationDays: matchedPrediction.map {
                    CycleMath.daysBetween($0.predictedDate, start)
                }
            )
            context.insert(cycle)

            // Set journeyStartDate on first period confirmation
            if let profile = try fetchProfile(context: context),
               profile.journeyStartDate == nil {
                profile.journeyStartDate = start
            }

            // Mark matched prediction as confirmed
            if let pred = matchedPrediction {
                pred.isConfirmed = true
                pred.actualStartDate = start
                pred.accuracyDays = abs(CycleMath.daysBetween(pred.predictedDate, start))
            }

            try context.save()

            // Prune any residual overlapping records (e.g. from an
            // earlier version of confirmPeriod that only dedupe'd
            // exact startDate matches) before we recompute averages.
            try deduplicateCycles(context: context)

            // Recalculate all cycle lengths and profile from scratch
            try recalculateCycleStats(context: context)

            // Regenerate predictions (skip in batch mode — caller does it once at the end)
            if !skipPredictions {
                try await regeneratePredictions(container: container)
            }
        }
    }

    // MARK: removePeriodDays

    static func liveRemovePeriodDays() -> @Sendable ([Date]) async throws -> Void {
        return { dates in
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let cal = Calendar.current
            let datesToRemove = Set(dates.map { cal.startOfDay(for: $0) })

            let descriptor = FetchDescriptor<CycleRecord>(
                sortBy: [SortDescriptor(\.startDate)]
            )
            let cycles = try context.fetch(descriptor)

            for cycle in cycles {
                let bd = cycle.bleedingDays ?? 5
                var cycleDates: [Date] = []
                for dayOffset in 0..<bd {
                    cycleDates.append(CycleMath.addDays(cycle.startDate, dayOffset))
                }
                let removedFromCycle = cycleDates.filter { datesToRemove.contains($0) }
                guard !removedFromCycle.isEmpty else { continue }

                let remainingDates = cycleDates.filter { !datesToRemove.contains($0) }
                if remainingDates.isEmpty {
                    // All days removed → delete entire cycle
                    context.delete(cycle)
                } else {
                    // Partial removal → adjust cycle to remaining days
                    let newStart = remainingDates.min()!
                    cycle.startDate = newStart
                    cycle.bleedingDays = remainingDates.count
                    cycle.endDate = CycleMath.addDays(newStart, remainingDates.count - 1)
                }
            }
            try context.save()

            // Same overlap dedupe as confirmPeriod — partial day
            // removals can leave two records on identical ranges if
            // the user ping-ponged an edit before this fix landed.
            try deduplicateCycles(context: context)

            // Recalculate all cycle lengths and profile from scratch
            try recalculateCycleStats(context: context)

            try await regeneratePredictions(container: container)
        }
    }

    // MARK: logSymptom

    static func liveLogSymptom() -> @Sendable (Date, String, Int, String?) async throws -> Void {
        return { date, symptomType, severity, notes in
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let day = Calendar.current.startOfDay(for: date)

            // Find the cycle this symptom belongs to: the most
            // recent cycle whose startDate is on or before the
            // symptom date. (Previously this always used the latest
            // cycle, which produced negative / wildly off cycleDays
            // when logging symptoms on past dates and broke
            // PatternDetector aggregation.)
            let allCycles = try fetchAllCycles(context: context)
            let owningCycle = allCycles.first { $0.startDate <= day }
            let cycleDay = owningCycle.map {
                CycleMath.cycleDay(cycleStart: $0.startDate, date: day)
            }

            let symptom = SymptomRecord(
                symptomDate: day,
                symptomType: symptomType,
                severity: severity,
                notes: notes,
                cycleDay: cycleDay
            )
            context.insert(symptom)
            try context.save()
        }
    }

    // MARK: removeSymptom

    static func liveRemoveSymptom() -> @Sendable (Date, String) async throws -> Void {
        return { date, symptomType in
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let day = Calendar.current.startOfDay(for: date)
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day

            let descriptor = FetchDescriptor<SymptomRecord>(
                predicate: #Predicate {
                    $0.symptomDate >= day
                        && $0.symptomDate < nextDay
                        && $0.symptomType == symptomType
                }
            )

            for record in try context.fetch(descriptor) {
                context.delete(record)
            }
            try context.save()
        }
    }

    // MARK: getSymptoms

    static func liveGetSymptoms() -> @Sendable (Date) async throws -> [MenstrualSymptomResponse] {
        return { date in
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let day = Calendar.current.startOfDay(for: date)
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)!

            let descriptor = FetchDescriptor<SymptomRecord>(
                predicate: #Predicate { $0.symptomDate >= day && $0.symptomDate < nextDay },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            let records = try context.fetch(descriptor)

            return records.enumerated().map { index, record in
                MenstrualSymptomResponse(
                    id: index,
                    symptomDate: record.symptomDate,
                    symptomType: record.symptomType,
                    severity: record.severity,
                    notes: record.notes
                )
            }
        }
    }

    // MARK: getProfile

    static func liveGetProfile() -> @Sendable () async throws -> MenstrualProfileInfo? {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            guard let profile = try fetchProfile(context: context) else { return nil }
            return MenstrualProfileInfo(
                avgCycleLength: profile.avgCycleLength,
                cycleRegularity: profile.cycleRegularity,
                trackingSince: profile.createdAt
            )
        }
    }

    // MARK: saveProfile

    static func liveSaveProfile() -> @Sendable (MenstrualProfileInfo, [String], String?, Bool, String?) async throws -> Void {
        return { profileInfo, symptoms, flowIntensity, usesContraception, contraceptionType in
            let container = CycleDataStore.shared
            let context = ModelContext(container)

            let existing = try fetchProfile(context: context)
            if let record = existing {
                record.avgCycleLength = profileInfo.avgCycleLength
                record.onboardingCycleLength = profileInfo.avgCycleLength
                record.cycleRegularity = profileInfo.cycleRegularity
                record.typicalSymptoms = symptoms
                record.typicalFlowIntensity = flowIntensity
                record.usesContraception = usesContraception
                record.contraceptionType = contraceptionType
                record.updatedAt = .now
            } else {
                let record = MenstrualProfileRecord(
                    avgCycleLength: profileInfo.avgCycleLength,
                    cycleRegularity: profileInfo.cycleRegularity,
                    typicalSymptoms: symptoms,
                    typicalFlowIntensity: flowIntensity,
                    usesContraception: usesContraception,
                    contraceptionType: contraceptionType,
                    onboardingCompletedAt: .now
                )
                context.insert(record)
            }
            try context.save()
        }
    }

    // MARK: setCycleLengthOverride

    /// Pass `Int` to pin cycle length manually; `nil` to revert to
    /// auto-mode (the Live reconciliation loop will pick a new value
    /// from observed cycles the next time it runs).
    static func liveSetCycleLengthOverride() -> @Sendable (Int?) async throws -> Void {
        return { override in
            let container = CycleDataStore.shared
            let context = ModelContext(container)

            let existing = try fetchProfile(context: context)
            let record: MenstrualProfileRecord
            if let existing {
                record = existing
            } else {
                record = MenstrualProfileRecord(onboardingCompletedAt: .now)
                context.insert(record)
            }

            if let value = override {
                // Match the picker's 10–90 range exactly. Used to be
                // clamped to 18–50 (historic sanity for auto-WMA),
                // but in manual mode the user has explicitly chosen
                // the value, so don't silently rewrite it down to 50.
                let clamped = max(10, min(90, value))
                record.useManualCycleLength = true
                record.avgCycleLength = clamped
                // Do NOT touch `onboardingCycleLength` — that's the
                // user's original onboarding answer. Manual overrides
                // are temporary pins; the recommended fallback needs
                // an untouched baseline to default to.
            } else {
                // Switching back to Recommended: clear the flag AND
                // re-derive `avgCycleLength` from observed cycle gaps.
                // Otherwise the value stays pinned at whatever the
                // user typed in manual mode until the next cycle is
                // confirmed.
                record.useManualCycleLength = false
                let today = CycleMath.startOfDay(Date())
                let allCycles = try fetchAllCycles(context: context)
                let pastCycles = allCycles
                    .filter { $0.startDate <= today }
                    .sorted { $0.startDate > $1.startDate }
                var gaps: [Int] = []
                for cycle in pastCycles {
                    if let stored = cycle.actualCycleLength { gaps.append(stored) }
                }
                if gaps.isEmpty, pastCycles.count >= 2 {
                    for i in 0..<(pastCycles.count - 1) {
                        let gap = CycleMath.cycleLength(
                            periodStart1: pastCycles[i + 1].startDate,
                            periodStart2: pastCycles[i].startDate
                        )
                        if gap > 0 { gaps.append(gap) }
                    }
                }
                if gaps.isEmpty {
                    // No observed data — fall back to a neutral 28.
                    // (Used to fall back to onboardingCycleLength but
                    // earlier code mirrored manual overrides into it,
                    // so we lost a trustworthy baseline.)
                    record.avgCycleLength = 28
                } else {
                    record.avgCycleLength = Int(round(CycleMath.mean(gaps)))
                    if gaps.count >= 3 {
                        record.onboardingCycleLength = record.avgCycleLength
                    }
                }
            }
            record.updatedAt = .now
            try context.save()
        }
    }

    // MARK: getCycleLengthOverride

    /// Returns the manually pinned cycle length if active, otherwise `nil`.
    static func liveGetCycleLengthOverride() -> @Sendable () async throws -> Int? {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            guard let profile = try fetchProfile(context: context),
                  profile.useManualCycleLength else { return nil }
            return profile.avgCycleLength
        }
    }

    // MARK: setPeriodLengthOverride

    /// Pass `Int` to pin period (bleeding) length manually; `nil` to revert
    /// to auto mode.
    static func liveSetPeriodLengthOverride() -> @Sendable (Int?) async throws -> Void {
        return { override in
            let container = CycleDataStore.shared
            let context = ModelContext(container)

            let existing = try fetchProfile(context: context)
            let record: MenstrualProfileRecord
            if let existing {
                record = existing
            } else {
                record = MenstrualProfileRecord(onboardingCompletedAt: .now)
                context.insert(record)
            }

            if let value = override {
                let clamped = max(1, min(10, value))
                record.useManualPeriodLength = true
                record.avgBleedingDays = clamped
            } else {
                // Switching back to Recommended: recompute the mean
                // bleeding length from the cycles already on record.
                record.useManualPeriodLength = false
                let today = CycleMath.startOfDay(Date())
                let allCycles = try fetchAllCycles(context: context)
                let bleedings = allCycles
                    .filter { $0.startDate <= today }
                    .compactMap(\.bleedingDays)
                if !bleedings.isEmpty {
                    record.avgBleedingDays = max(1, min(10, Int(round(CycleMath.mean(bleedings)))))
                }
                // If empty, leave the existing value — there's nothing
                // to derive from, and forcing a default would silently
                // change a setting the user never touched.
            }
            record.updatedAt = .now
            try context.save()
        }
    }

    // MARK: getPeriodLengthOverride

    static func liveGetPeriodLengthOverride() -> @Sendable () async throws -> Int? {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            guard let profile = try fetchProfile(context: context),
                  profile.useManualPeriodLength else { return nil }
            return profile.avgBleedingDays
        }
    }

    // MARK: showOvulation / showFertileWindow

    static func liveGetShowOvulation() -> @Sendable () async throws -> Bool {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            return (try fetchProfile(context: context))?.showOvulation ?? true
        }
    }

    static func liveSetShowOvulation() -> @Sendable (Bool) async throws -> Void {
        return { value in
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let record: MenstrualProfileRecord
            if let existing = try fetchProfile(context: context) {
                record = existing
            } else {
                record = MenstrualProfileRecord(onboardingCompletedAt: .now)
                context.insert(record)
            }
            record.showOvulation = value
            record.updatedAt = .now
            try context.save()
        }
    }

    static func liveGetShowFertileWindow() -> @Sendable () async throws -> Bool {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            return (try fetchProfile(context: context))?.showFertileWindow ?? true
        }
    }

    static func liveSetShowFertileWindow() -> @Sendable (Bool) async throws -> Void {
        return { value in
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let record: MenstrualProfileRecord
            if let existing = try fetchProfile(context: context) {
                record = existing
            } else {
                record = MenstrualProfileRecord(onboardingCompletedAt: .now)
                context.insert(record)
            }
            record.showFertileWindow = value
            record.updatedAt = .now
            try context.save()
        }
    }

    // MARK: getEffectiveCycleLength

    /// Returns the cycle length currently in use. If manual override
    /// is active, returns the pinned value. Otherwise returns the
    /// recommended (mean of observed gaps, fallback 28). Ignores any
    /// stale `avgCycleLength` value left from a previous manual save.
    static func liveGetEffectiveCycleLength() -> @Sendable () async throws -> Int {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            guard let profile = try fetchProfile(context: context) else { return 28 }
            if profile.useManualCycleLength {
                return max(10, min(90, profile.avgCycleLength))
            }
            // Recompute live so a polluted `avgCycleLength` from an
            // earlier manual save doesn't leak through.
            let today = CycleMath.startOfDay(Date())
            let allCycles = try fetchAllCycles(context: context)
            let pastCycles = allCycles
                .filter { $0.startDate <= today }
                .sorted { $0.startDate > $1.startDate }
            var gaps: [Int] = pastCycles.compactMap(\.actualCycleLength)
            if gaps.isEmpty, pastCycles.count >= 2 {
                for i in 0..<(pastCycles.count - 1) {
                    let gap = CycleMath.cycleLength(
                        periodStart1: pastCycles[i + 1].startDate,
                        periodStart2: pastCycles[i].startDate
                    )
                    if gap > 0 { gaps.append(gap) }
                }
            }
            if !gaps.isEmpty {
                return Int(round(CycleMath.mean(gaps)))
            }
            return 28
        }
    }

    // MARK: getRecommendedCycleLength

    /// Computes the cycle length Recommended mode would use, ignoring
    /// any manual override. Mean of observed cycle gaps, fallback to
    /// the onboarding baseline if no data.
    static func liveGetRecommendedCycleLength() -> @Sendable () async throws -> Int {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let today = CycleMath.startOfDay(Date())
            let allCycles = try fetchAllCycles(context: context)
            let pastCycles = allCycles
                .filter { $0.startDate <= today }
                .sorted { $0.startDate > $1.startDate }

            var gaps: [Int] = pastCycles.compactMap(\.actualCycleLength)
            if gaps.isEmpty, pastCycles.count >= 2 {
                for i in 0..<(pastCycles.count - 1) {
                    let gap = CycleMath.cycleLength(
                        periodStart1: pastCycles[i + 1].startDate,
                        periodStart2: pastCycles[i].startDate
                    )
                    if gap > 0 { gaps.append(gap) }
                }
            }
            if !gaps.isEmpty {
                return Int(round(CycleMath.mean(gaps)))
            }
            // No observed data — return a neutral 28-day baseline.
            // Intentionally ignoring `onboardingCycleLength` here:
            // earlier code paths used to mirror the manual override
            // into it, which then leaked back as the "recommended"
            // value after the user toggled away from Manual.
            return 28
        }
    }

    // MARK: getRecommendedPeriodLength

    static func liveGetRecommendedPeriodLength() -> @Sendable () async throws -> Int {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let today = CycleMath.startOfDay(Date())
            let allCycles = try fetchAllCycles(context: context)
            let bleedings = allCycles
                .filter { $0.startDate <= today }
                .compactMap(\.bleedingDays)
            if !bleedings.isEmpty {
                return max(1, min(10, Int(round(CycleMath.mean(bleedings)))))
            }
            // No observed data — return a neutral 5-day baseline.
            // Intentionally ignoring `profile.avgBleedingDays` here:
            // earlier code paths used to mirror the manual override
            // into it, which then leaked back as the "recommended"
            // value after the user toggled away from Manual.
            return 5
        }
    }

    // MARK: getEffectivePeriodLength

    /// Returns the period length currently in use. If manual override
    /// is active, returns the pinned value. Otherwise returns the
    /// recommended (mean of observed bleeding days, fallback 5).
    /// Mirrors `getEffectiveCycleLength` for the same reason: avoid
    /// leaking a stale `avgBleedingDays` value pinned by a previous
    /// manual save.
    static func liveGetEffectivePeriodLength() -> @Sendable () async throws -> Int {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            guard let profile = try fetchProfile(context: context) else { return 5 }
            if profile.useManualPeriodLength {
                return max(1, min(10, profile.avgBleedingDays))
            }
            // Recompute live to ignore any polluted stored value.
            let today = CycleMath.startOfDay(Date())
            let allCycles = try fetchAllCycles(context: context)
            let bleedings = allCycles
                .filter { $0.startDate <= today }
                .compactMap(\.bleedingDays)
            if !bleedings.isEmpty {
                return max(1, min(10, Int(round(CycleMath.mean(bleedings)))))
            }
            return 5
        }
    }
}
