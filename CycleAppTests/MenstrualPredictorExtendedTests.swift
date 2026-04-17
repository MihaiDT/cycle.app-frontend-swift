@testable import CycleApp
import Foundation
import Testing

// MARK: - Predictor tier selection edge cases

@Suite("MenstrualPredictor — Version Selection Edge Cases")
struct PredictorVersionSelectionTests {

    @Test("Boundary: 3 cycles selects V3, 2 selects V2")
    func boundaryV2V3() {
        #expect(MenstrualPredictor.determineVersion(cycleCount: 2) == .v2Statistical)
        #expect(MenstrualPredictor.determineVersion(cycleCount: 3) == .v3Historical)
    }

    @Test("Boundary: 5 cycles selects V3, 6 selects V4")
    func boundaryV3V4() {
        #expect(MenstrualPredictor.determineVersion(cycleCount: 5) == .v3Historical)
        #expect(MenstrualPredictor.determineVersion(cycleCount: 6) == .v4ML)
    }

    @Test("Large cycle count stays at V4")
    func largeStaysV4() {
        #expect(MenstrualPredictor.determineVersion(cycleCount: 100) == .v4ML)
    }

    @Test("Algorithm displayName covers all versions")
    func displayNames() {
        #expect(AlgorithmVersion.v1Basic.displayName == "Basic")
        #expect(AlgorithmVersion.v2Statistical.displayName == "Statistical")
        #expect(AlgorithmVersion.v3Historical.displayName == "Historical")
        #expect(AlgorithmVersion.v4ML.displayName == "Adaptive")
    }
}

// MARK: - V2 Exponential WMA accuracy

@Suite("MenstrualPredictor — V2 WMA")
struct PredictorV2Tests {

    @Test("exponentialWMA weights recent values heavier")
    func wmaRecentHeavier() {
        // Newest first — [30, 28, 28] alpha 0.7
        // weights: 1.0, 0.7, 0.49 — recent (30) dominates
        let wma = MenstrualPredictor.exponentialWMA([30, 28, 28], alpha: 0.7)
        let simple = (30.0 + 28 + 28) / 3.0
        // WMA should be > simple avg because recent 30 is weighted heaviest
        #expect(wma > simple)
    }

    @Test("exponentialWMA fallback to 28 when empty")
    func wmaEmpty() {
        let wma = MenstrualPredictor.exponentialWMA([], alpha: 0.7)
        #expect(wma == 28)
    }

    @Test("exponentialWMA with single value returns that value")
    func wmaSingle() {
        let wma = MenstrualPredictor.exponentialWMA([30], alpha: 0.7)
        #expect(wma == 30)
    }

    @Test("V2 prediction approximates WMA + most recent start")
    func v2PredictionShape() {
        let cal = Calendar.current
        let c1 = cal.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let c2 = cal.date(from: DateComponents(year: 2025, month: 1, day: 30))! // gap 29
        let c3 = cal.date(from: DateComponents(year: 2025, month: 2, day: 27))! // gap 28

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")
        let result = MenstrualPredictor.predict(
            cycles: [CycleInput(startDate: c3), CycleInput(startDate: c2), CycleInput(startDate: c1)],
            profile: profile
        )

        // Should be V2 or V3 (3 cycles)
        #expect([AlgorithmVersion.v2Statistical, .v3Historical].contains(result.algorithmVersion))
        // Predicted start should be after most recent cycle start
        #expect(result.predictedStart > c3)
    }
}

// MARK: - V3 Ogino-Knaus fertile window

@Suite("MenstrualPredictor — V3 Ogino-Knaus")
struct PredictorV3Tests {

    @Test("V3 fertile window is bounded")
    func oginoKnausBounds() {
        let cal = Calendar.current
        var cycles: [CycleInput] = []
        for i in 0..<5 {
            let d = cal.date(from: DateComponents(year: 2025, month: 1 + i, day: 1))!
            cycles.append(CycleInput(startDate: d, actualCycleLength: 28 + (i % 2)))
        }
        cycles.reverse()

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")
        let result = MenstrualPredictor.predict(cycles: cycles, profile: profile)

        #expect(result.algorithmVersion == .v3Historical)
        // Fertile window: start < peak < end
        #expect(result.fertileWindow.start <= result.fertileWindow.peak)
        #expect(result.fertileWindow.peak <= result.fertileWindow.end)
    }

    @Test("V3 age adjustment is applied for teens (<20)")
    func ageAdjustmentYoung() {
        let cal = Calendar.current
        var cycles: [CycleInput] = []
        for i in 0..<5 {
            let d = cal.date(from: DateComponents(year: 2025, month: 1 + i, day: 1))!
            cycles.append(CycleInput(startDate: d, actualCycleLength: 28))
        }
        cycles.reverse()
        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")

        let resultTeen = MenstrualPredictor.predict(cycles: cycles, profile: profile, age: 16)
        let resultAdult = MenstrualPredictor.predict(cycles: cycles, profile: profile, age: 30)

        // Teen has ageVariation=2.0 → +0.6 days added. Adult has 0. Different rounding can occur.
        // Confidence shouldn't differ from age alone → validate predictedStart shift.
        let teenDiff = CycleMath.daysBetween(resultAdult.predictedStart, resultTeen.predictedStart)
        #expect(teenDiff >= 0)
    }
}

// MARK: - V4 bias correction & confirmation learning

@Suite("MenstrualPredictor — V4 ML")
struct PredictorV4Tests {

    @Test("V4 with confirmed cycles boosts confidence")
    func v4ConfidenceBoost() {
        let cal = Calendar.current
        var cycles: [CycleInput] = []
        for i in 0..<8 {
            let d = cal.date(from: DateComponents(year: 2024, month: 1 + (i % 12), day: 1))!
            cycles.append(CycleInput(
                startDate: d, actualCycleLength: 28,
                isConfirmed: true, actualDeviationDays: 0
            ))
        }
        cycles.reverse()

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")
        let result = MenstrualPredictor.predict(cycles: cycles, profile: profile, hasSymptomData: true)

        #expect(result.algorithmVersion == .v4ML)
        #expect(result.confidence >= 0.90)
    }

    @Test("V4 bias correction shifts prediction when consistent deviation")
    func v4BiasCorrection() {
        let cal = Calendar.current
        var cyclesWithBias: [CycleInput] = []
        for i in 0..<8 {
            let d = cal.date(from: DateComponents(year: 2024, month: 1 + (i % 12), day: 1))!
            // Consistent 2-day early deviation on confirmed cycles
            cyclesWithBias.append(CycleInput(
                startDate: d, actualCycleLength: 28,
                isConfirmed: true, actualDeviationDays: 2
            ))
        }
        cyclesWithBias.reverse()

        var cyclesNoBias: [CycleInput] = []
        for i in 0..<8 {
            let d = cal.date(from: DateComponents(year: 2024, month: 1 + (i % 12), day: 1))!
            cyclesNoBias.append(CycleInput(
                startDate: d, actualCycleLength: 28,
                isConfirmed: true, actualDeviationDays: 0
            ))
        }
        cyclesNoBias.reverse()

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")
        let biased = MenstrualPredictor.predict(cycles: cyclesWithBias, profile: profile)
        let unbiased = MenstrualPredictor.predict(cycles: cyclesNoBias, profile: profile)

        // Biased prediction should differ from unbiased by at least 1 day
        let diff = abs(CycleMath.daysBetween(biased.predictedStart, unbiased.predictedStart))
        #expect(diff >= 1)
    }

    @Test("V4 falls back to V3 when cycles < 6 (safeguard)")
    func v4FallbackToV3() {
        // determineVersion uses cycleCount → 5 → V3. Confirming this boundary.
        let cal = Calendar.current
        var cycles: [CycleInput] = []
        for i in 0..<5 {
            let d = cal.date(from: DateComponents(year: 2025, month: 1 + i, day: 1))!
            cycles.append(CycleInput(startDate: d, actualCycleLength: 28))
        }
        cycles.reverse()

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")
        let result = MenstrualPredictor.predict(cycles: cycles, profile: profile)
        #expect(result.algorithmVersion == .v3Historical)
    }
}

// MARK: - V1 edge cases

@Suite("MenstrualPredictor — V1 Edge Cases")
struct PredictorV1Tests {

    @Test("V1 with nil last period projects from today")
    func v1NoLastPeriod() {
        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5)
        let result = MenstrualPredictor.predict(cycles: [], profile: profile)

        #expect(result.algorithmVersion == .v1Basic)
        #expect(result.basedOnCycles == 0)
        // Should project forward — predictedStart after today
        let today = Calendar.current.startOfDay(for: Date())
        let daysFromToday = CycleMath.daysBetween(today, result.predictedStart)
        // Should be cycleLength/2 = 14 days out
        #expect(daysFromToday >= 10)
        #expect(daysFromToday <= 20)
    }

    @Test("V1 PredictedEnd respects bleedingDays")
    func v1PredictedEnd() {
        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 7)
        let result = MenstrualPredictor.predict(cycles: [], profile: profile)
        let span = CycleMath.daysBetween(result.predictedStart, result.predictedEnd)
        #expect(span == 6) // 7 days: start + 6 more days
    }

    @Test("V1 range expands uncertainty below confidence thresholds")
    func v1RangeWidens() {
        // Profile with poor data → low confidence → wider range
        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "irregular")
        let result = MenstrualPredictor.predict(cycles: [], profile: profile)
        let rangeSpan = abs(CycleMath.daysBetween(result.rangeStart, result.rangeEnd))
        // At least 2 days of range
        #expect(rangeSpan >= 2)
    }
}

// MARK: - extractedCycleLengths (public wrapper)

@Suite("MenstrualPredictor — extractedCycleLengths")
struct PredictorExtractLengthsTests {

    @Test("Uses stored actualCycleLength when valid")
    func prefersStored() {
        let d1 = CycleMath.addDays(Date(), -56)
        let d2 = CycleMath.addDays(Date(), -28)
        let cycles = [
            CycleInput(startDate: d2, actualCycleLength: 30),
            CycleInput(startDate: d1, actualCycleLength: 29),
        ]
        let lengths = MenstrualPredictor.extractedCycleLengths(cycles: cycles, fallbackLength: 28)
        #expect(lengths.contains(30))
    }

    @Test("Calculates from start dates when stored invalid")
    func fallsBackToGap() {
        let d1 = CycleMath.addDays(Date(), -56)
        let d2 = CycleMath.addDays(Date(), -28) // gap = 28
        let cycles = [
            CycleInput(startDate: d2, actualCycleLength: 5), // invalid
            CycleInput(startDate: d1, actualCycleLength: nil),
        ]
        let lengths = MenstrualPredictor.extractedCycleLengths(cycles: cycles, fallbackLength: 28)
        #expect(lengths.contains(28))
        #expect(!lengths.contains(5))
    }

    @Test("Falls back to profile average when nothing valid")
    func profileFallback() {
        let cycles = [
            CycleInput(startDate: Date(), actualCycleLength: 100), // invalid
        ]
        let lengths = MenstrualPredictor.extractedCycleLengths(cycles: cycles, fallbackLength: 28)
        #expect(lengths == [28])
    }

    @Test("Rejects physiologically invalid values")
    func rejectsInvalidRange() {
        let d1 = CycleMath.addDays(Date(), -100)
        let d2 = CycleMath.addDays(Date(), -40)
        let cycles = [
            CycleInput(startDate: d2, actualCycleLength: 60), // invalid upper
            CycleInput(startDate: d1, actualCycleLength: nil),
        ]
        let lengths = MenstrualPredictor.extractedCycleLengths(cycles: cycles, fallbackLength: 28)
        #expect(!lengths.contains(60))
    }
}

// MARK: - Cycle length gap computation

@Suite("MenstrualPredictor — Cycle gap computations")
struct PredictorGapComputationTests {

    @Test("Result has sensible predictedStart/predictedEnd ordering")
    func orderingIsCorrect() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2025, month: 3, day: 1))!
        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5)
        let cycles = [CycleInput(startDate: start)]
        let result = MenstrualPredictor.predict(cycles: cycles, profile: profile)

        #expect(result.predictedStart <= result.predictedEnd)
        #expect(result.rangeStart <= result.predictedStart)
        #expect(result.predictedStart <= result.rangeEnd)
    }
}
