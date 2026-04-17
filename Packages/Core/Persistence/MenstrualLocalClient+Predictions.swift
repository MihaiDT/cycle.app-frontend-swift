import Foundation
import SwiftData

// MARK: - Prediction Generation

extension MenstrualLocalClient {
    static func liveGeneratePrediction() -> @Sendable () async throws -> Void {
        return {
            try await regeneratePredictions(container: CycleDataStore.shared)
        }
    }

    /// Clear unconfirmed predictions and regenerate from current cycle data.
    static func regeneratePredictions(container: ModelContainer) async throws {
        let context = ModelContext(container)

        // Clear unconfirmed predictions
        let clearDescriptor = FetchDescriptor<PredictionRecord>(
            predicate: #Predicate<PredictionRecord> { !$0.isConfirmed }
        )
        for pred in try context.fetch(clearDescriptor) {
            context.delete(pred)
        }

        // Save deletions before checking if we can regenerate
        try context.save()

        // Gather inputs
        guard let profile = try fetchProfile(context: context) else { return }
        let cycles = try fetchAllCycles(context: context)
        guard !cycles.isEmpty else { return }

        let cycleInputs = cycles.map { cycle in
            CycleInput(
                startDate: cycle.startDate,
                actualCycleLength: cycle.actualCycleLength,
                isConfirmed: cycle.isConfirmed,
                actualDeviationDays: cycle.actualDeviationDays
            )
        }

        let profileInput = ProfileInput(
            avgCycleLength: profile.avgCycleLength,
            avgBleedingDays: profile.avgBleedingDays,
            cycleRegularity: profile.cycleRegularity
        )

        // Generate primary prediction using the adaptive engine
        let result = MenstrualPredictor.predict(
            cycles: cycleInputs,
            profile: profileInput,
            hasSymptomData: false
        )


        let extractedLengths = MenstrualPredictor.extractedCycleLengths(
            cycles: cycleInputs, fallbackLength: profile.avgCycleLength
        )
        let sd = CycleMath.stdDev(extractedLengths)
        // Use profile average for maximum prediction stability
        let cycleLen = profile.avgCycleLength

        // Project predictions into the future (~1 year)
        // Use most recent cycle + WMA for consistent spacing (V4 adjustments can over-correct)
        let mostRecentStart = cycles.first?.startDate ?? result.predictedStart
        var currentStart = CycleMath.addDays(mostRecentStart, cycleLen)
        var currentConfidence = result.confidence
        let today = CycleMath.startOfDay(Date())

        // Always store the primary prediction (even if past — needed for late period detection)
        let primaryRangeDays = CycleMath.predictionRangeDays(confidence: currentConfidence, stdDev: sd)
        let primaryFertile = CycleMath.simpleFertileWindow(cycleStart: currentStart, cycleLength: cycleLen)
        let primaryPred = PredictionRecord(
            predictedDate: currentStart,
            rangeStart: CycleMath.addDays(currentStart, -primaryRangeDays),
            rangeEnd: CycleMath.addDays(currentStart, primaryRangeDays),
            confidenceLevel: currentConfidence,
            algorithmVersion: result.algorithmVersion.rawValue,
            basedOnCycles: result.basedOnCycles,
            fertileWindowStart: primaryFertile.start,
            fertileWindowEnd: primaryFertile.end,
            ovulationDate: primaryFertile.peak
        )
        context.insert(primaryPred)

        // Advance past primary prediction
        let primaryLen = max(18, min(50, cycleLen))
        currentStart = CycleMath.addDays(currentStart, primaryLen)
        currentConfidence = max(0.3, currentConfidence * 0.95)

        // If primary prediction was in the past, keep advancing until we reach today
        // so we don't waste prediction slots on dates already passed
        var advanceIterations = 0
        while currentStart < today, advanceIterations < 24 {
            let projectedLen = cycleLen
            // Store past-but-after-primary predictions too (fills calendar history)
            let rangeDays = CycleMath.predictionRangeDays(confidence: currentConfidence, stdDev: sd)
            let fertile = CycleMath.simpleFertileWindow(cycleStart: currentStart, cycleLength: projectedLen)
            let pastPred = PredictionRecord(
                predictedDate: currentStart,
                rangeStart: CycleMath.addDays(currentStart, -rangeDays),
                rangeEnd: CycleMath.addDays(currentStart, rangeDays),
                confidenceLevel: currentConfidence,
                algorithmVersion: "v1_basic",
                basedOnCycles: result.basedOnCycles,
                fertileWindowStart: fertile.start,
                fertileWindowEnd: fertile.end,
                ovulationDate: fertile.peak
            )
            context.insert(pastPred)
            currentStart = CycleMath.addDays(currentStart, projectedLen)
            currentConfidence = max(0.3, currentConfidence * 0.95)
            advanceIterations += 1
        }

        // Generate predictions until end of January next year
        let nextYear = Calendar.current.component(.year, from: Date()) + 1
        let endComps = DateComponents(year: nextYear, month: 2, day: 1)
        let predictionEnd = Calendar.current.date(from: endComps) ?? CycleMath.addDays(today, 365)
        var i = 0
        while currentStart < predictionEnd {
            let rangeDays = CycleMath.predictionRangeDays(confidence: currentConfidence, stdDev: sd)
            let projectedLen = cycleLen
            let fertile = CycleMath.simpleFertileWindow(cycleStart: currentStart, cycleLength: projectedLen)

            let pred = PredictionRecord(
                predictedDate: currentStart,
                rangeStart: CycleMath.addDays(currentStart, -rangeDays),
                rangeEnd: CycleMath.addDays(currentStart, rangeDays),
                confidenceLevel: currentConfidence,
                algorithmVersion: "v1_basic",
                basedOnCycles: result.basedOnCycles,
                fertileWindowStart: fertile.start,
                fertileWindowEnd: fertile.end,
                ovulationDate: fertile.peak
            )
            context.insert(pred)

            currentStart = CycleMath.addDays(currentStart, projectedLen)
            currentConfidence = max(0.3, currentConfidence * 0.95)
            i += 1
        }

        try context.save()
    }
}
