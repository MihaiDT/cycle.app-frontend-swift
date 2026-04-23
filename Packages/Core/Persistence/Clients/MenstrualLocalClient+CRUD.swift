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

            // Determine cycle day
            let latestCycle = try fetchLatestCycle(context: context)
            let cycleDay = latestCycle.map {
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
}
