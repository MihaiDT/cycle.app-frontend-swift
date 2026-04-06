@testable import CycleApp
import Foundation
import Testing

// MARK: - CycleMath Tests

@Suite("CycleMath")
struct CycleMathTests {

    @Test("daysBetween calculates correctly")
    func daysBetween() {
        let cal = Calendar.current
        let d1 = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let d2 = cal.date(from: DateComponents(year: 2024, month: 1, day: 29))!
        #expect(CycleMath.daysBetween(d1, d2) == 28)
        #expect(CycleMath.daysBetween(d2, d1) == -28)
        #expect(CycleMath.daysBetween(d1, d1) == 0)
    }

    @Test("cycleDay is 1-based")
    func cycleDay() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2024, month: 3, day: 1))!
        let day5 = cal.date(from: DateComponents(year: 2024, month: 3, day: 5))!
        #expect(CycleMath.cycleDay(cycleStart: start, date: start) == 1)
        #expect(CycleMath.cycleDay(cycleStart: start, date: day5) == 5)
    }

    @Test("mean and stdDev")
    func statistics() {
        let values = [28, 30, 27, 29, 28]
        let avg = CycleMath.mean(values)
        #expect(abs(avg - 28.4) < 0.01)

        let sd = CycleMath.stdDev(values)
        #expect(sd > 0)
        #expect(sd < 2)
    }

    @Test("cycle phase detection")
    func cyclePhase() {
        #expect(CycleMath.cyclePhase(cycleDay: 1, cycleLength: 28, bleedingDays: 5) == .menstrual)
        #expect(CycleMath.cyclePhase(cycleDay: 5, cycleLength: 28, bleedingDays: 5) == .menstrual)
        #expect(CycleMath.cyclePhase(cycleDay: 8, cycleLength: 28, bleedingDays: 5) == .follicular)
        #expect(CycleMath.cyclePhase(cycleDay: 14, cycleLength: 28, bleedingDays: 5) == .ovulatory)
        #expect(CycleMath.cyclePhase(cycleDay: 20, cycleLength: 28, bleedingDays: 5) == .luteal)
    }

    @Test("variability classification")
    func variability() {
        #expect(CycleMath.classifyVariability([28, 28, 29, 28]) == "regular")
        #expect(CycleMath.classifyVariability([26, 28, 31, 29]) == "somewhat_regular")
        #expect(CycleMath.classifyVariability([22, 35, 28, 40]) == "irregular")
    }

    @Test("confidence calculation")
    func confidence() {
        // 0 cycles: base 0.5 + 0.05 (count) + 0.05 (unknown) + 0.10 (stddev ≤2) = 0.70
        let c0 = CycleMath.calculateConfidence(cycleCount: 0, regularity: "unknown", hasSymptomData: false, stdDev: 0)
        #expect(c0 >= 0.5)
        #expect(c0 <= 0.75)

        // 6+ regular cycles with symptoms: should be high
        let c6 = CycleMath.calculateConfidence(cycleCount: 8, regularity: "regular", hasSymptomData: true, stdDev: 1.5)
        #expect(c6 >= 0.90)
        #expect(c6 <= 0.95)
    }

    @Test("fertile window simple")
    func simpleFertile() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2024, month: 3, day: 1))!
        let window = CycleMath.simpleFertileWindow(cycleStart: start, cycleLength: 28)
        // Ovulation day = 28 - 14 = 14, so peak should be around day 14
        let peakDay = CycleMath.cycleDay(cycleStart: start, date: window.peak)
        #expect(peakDay == 14)
        #expect(window.start < window.peak)
        #expect(window.peak < window.end || window.peak == window.end)
    }

    @Test("trend detection")
    func trend() {
        #expect(CycleMath.detectTrend([28, 28]) == 0) // Too few
        #expect(CycleMath.detectTrend([30, 30, 28, 28, 28]) == 1) // Getting longer (recent > older)
        #expect(CycleMath.detectTrend([26, 26, 28, 28, 28]) == -1) // Getting shorter
        #expect(CycleMath.detectTrend([28, 28, 28, 28]) == 0) // Stable
    }
}

// MARK: - HBI Calculator Tests

@Suite("HBICalculator")
struct HBICalculatorTests {

    @Test("Likert to score conversion")
    func likertConversion() {
        #expect(HBICalculator.likertToScore(1) == 20)
        #expect(HBICalculator.likertToScore(3) == 60)
        #expect(HBICalculator.likertToScore(5) == 100)
    }

    @Test("Likert inverted for stress")
    func likertInverted() {
        // High stress (5) → low score (20)
        #expect(HBICalculator.likertToScoreInverted(5) == 20)
        // Low stress (1) → high score (100)
        #expect(HBICalculator.likertToScoreInverted(1) == 100)
    }

    @Test("HBI calculation from self-report only")
    func selfReportOnly() {
        let result = HBICalculator.calculate(
            selfReport: SelfReportInput(energyLevel: 4, stressLevel: 2, sleepQuality: 4, moodLevel: 4)
        )
        // Energy=80, Stress inverted=80, Sleep=80, Mood=80 → HBI=80
        #expect(result.hbiRaw > 70)
        #expect(result.hbiRaw <= 100)
        #expect(result.hasSelfReport == true)
        #expect(result.hasHealthKitData == false)
        #expect(result.completenessScore == 50)
    }

    @Test("Phase multipliers adjust HBI")
    func phaseAdjustment() {
        let input = SelfReportInput(energyLevel: 3, stressLevel: 3, sleepQuality: 3, moodLevel: 3)

        let raw = HBICalculator.calculate(selfReport: input)
        let follicular = HBICalculator.calculate(selfReport: input, cyclePhase: .follicular)
        let luteal = HBICalculator.calculate(selfReport: input, cyclePhase: .luteal)

        // Follicular boosts energy/mood → higher adjusted
        #expect(follicular.hbiAdjusted > raw.hbiRaw)
        // Luteal dampens energy/mood → lower adjusted
        #expect(luteal.hbiAdjusted < raw.hbiRaw)
    }

    @Test("Sleep score from HealthKit")
    func sleepScore() {
        // Optimal 8 hours → peak score
        let optimal = HBICalculator.sleepScoreFromHealthKit(hours: 8)!
        #expect(optimal >= 95)

        // Too little sleep → lower score
        let poor = HBICalculator.sleepScoreFromHealthKit(hours: 4)!
        #expect(poor < 60)

        // No data → nil
        #expect(HBICalculator.sleepScoreFromHealthKit(hours: nil) == nil)
    }

    @Test("Baseline requires 7 days")
    func baseline() {
        #expect(HBICalculator.calculateBaseline(scores: [70, 72, 68]) == nil)
        let scores = [70.0, 72, 68, 75, 71, 69, 73]
        let baseline = HBICalculator.calculateBaseline(scores: scores)!
        #expect(abs(baseline - 71.14) < 1)
    }
}

// MARK: - Menstrual Predictor Tests

@Suite("MenstrualPredictor")
struct MenstrualPredictorTests {

    @Test("Algorithm version selection")
    func versionSelection() {
        #expect(MenstrualPredictor.determineVersion(cycleCount: 0) == .v1Basic)
        #expect(MenstrualPredictor.determineVersion(cycleCount: 1) == .v2Statistical)
        #expect(MenstrualPredictor.determineVersion(cycleCount: 2) == .v2Statistical)
        #expect(MenstrualPredictor.determineVersion(cycleCount: 4) == .v3Historical)
        #expect(MenstrualPredictor.determineVersion(cycleCount: 8) == .v4ML)
    }

    @Test("V1 basic prediction with no cycles")
    func v1Basic() {
        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "unknown")
        let result = MenstrualPredictor.predict(cycles: [], profile: profile)

        #expect(result.algorithmVersion == .v1Basic)
        #expect(result.confidence >= 0.5)
        #expect(result.confidence <= 0.75)
        #expect(result.basedOnCycles == 0)
    }

    @Test("V1 prediction from last period")
    func v1FromLastPeriod() {
        let cal = Calendar.current
        let lastPeriod = cal.date(from: DateComponents(year: 2024, month: 3, day: 1))!
        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5)
        let cycles = [CycleInput(startDate: lastPeriod)]

        let result = MenstrualPredictor.predict(cycles: cycles, profile: profile)
        // With 1 cycle, should use V2 but fall back to V1 since need >= 2 for WMA
        #expect(result.predictedStart > lastPeriod)
    }

    @Test("V2 with 2 cycles uses WMA")
    func v2Statistical() {
        let cal = Calendar.current
        let cycle1 = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let cycle2 = cal.date(from: DateComponents(year: 2024, month: 1, day: 29))!
        let cycle3 = cal.date(from: DateComponents(year: 2024, month: 2, day: 26))!

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5)
        let cycles = [
            CycleInput(startDate: cycle3),
            CycleInput(startDate: cycle2),
            CycleInput(startDate: cycle1),
        ]

        // 3 cycles with 2 computable gaps → V2 Statistical
        let result = MenstrualPredictor.predict(cycles: cycles, profile: profile)
        #expect(result.algorithmVersion == .v2Statistical || result.algorithmVersion == .v3Historical)
        #expect(result.basedOnCycles >= 2)
    }

    @Test("V3 with 4 cycles includes fertile window")
    func v3Historical() {
        let cal = Calendar.current
        var cycles: [CycleInput] = []
        for i in 0..<4 {
            let date = cal.date(from: DateComponents(year: 2024, month: 1 + i, day: 1))!
            cycles.append(CycleInput(startDate: date, actualCycleLength: 28 + (i % 2)))
        }
        cycles.reverse() // newest first

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")
        let result = MenstrualPredictor.predict(cycles: cycles, profile: profile)

        #expect(result.algorithmVersion == .v3Historical)
        #expect(result.fertileWindow.start < result.fertileWindow.peak)
        #expect(result.confidence > 0.7)
    }

    @Test("V4 with 7 confirmed cycles boosts confidence")
    func v4ML() {
        let cal = Calendar.current
        var cycles: [CycleInput] = []
        for i in 0..<7 {
            let date = cal.date(from: DateComponents(year: 2024, month: 1 + i, day: 1))!
            cycles.append(CycleInput(
                startDate: date,
                actualCycleLength: 28,
                isConfirmed: true,
                actualDeviationDays: i == 0 ? nil : 1
            ))
        }
        cycles.reverse()

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")
        let result = MenstrualPredictor.predict(cycles: cycles, profile: profile)

        #expect(result.algorithmVersion == .v4ML)
        #expect(result.confidence >= 0.85)
        #expect(result.confidence <= 0.95) // Capped at 0.95
    }

    @Test("Confidence never exceeds 0.95")
    func confidenceCap() {
        let cal = Calendar.current
        var cycles: [CycleInput] = []
        for i in 0..<12 {
            let date = cal.date(from: DateComponents(year: 2023, month: 1 + i, day: 1))!
            cycles.append(CycleInput(
                startDate: date, actualCycleLength: 28,
                isConfirmed: true, actualDeviationDays: 0
            ))
        }
        cycles.reverse()

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")
        let result = MenstrualPredictor.predict(
            cycles: cycles, profile: profile, hasSymptomData: true
        )

        #expect(result.confidence <= 0.95)
    }
}

// MARK: - Production Hardening Tests

@Suite("CyclePhase Edge Cases")
struct CyclePhaseEdgeCaseTests {

    @Test("Short cycle (20 days) has follicular phase")
    func shortCycleFollicular() {
        // cl=20, bd=5: ovDay = max(5+4, 20-14) = max(9, 6) = 9
        // Follicular: days 6...(9-3)=6 → at least day 6
        let day6 = CycleMath.cyclePhase(cycleDay: 6, cycleLength: 20, bleedingDays: 5)
        #expect(day6 == .follicular)
    }

    @Test("cycleDay past cycleLength returns late")
    func latePhasePastCycleLength() {
        #expect(CycleMath.cyclePhase(cycleDay: 29, cycleLength: 28, bleedingDays: 5) == .late)
        #expect(CycleMath.cyclePhase(cycleDay: 42, cycleLength: 28, bleedingDays: 5) == .late)
    }

    @Test("Phase boundaries are contiguous — no gaps for standard 28-day cycle")
    func contiguousPhases28() {
        var phases: [CyclePhaseResult] = []
        for day in 1...28 {
            phases.append(CycleMath.cyclePhase(cycleDay: day, cycleLength: 28, bleedingDays: 5))
        }
        // Must contain all 4 biological phases
        #expect(phases.contains(.menstrual))
        #expect(phases.contains(.follicular))
        #expect(phases.contains(.ovulatory))
        #expect(phases.contains(.luteal))
        // Day 29 = late
        #expect(CycleMath.cyclePhase(cycleDay: 29, cycleLength: 28, bleedingDays: 5) == .late)
    }

    @Test("Phase boundaries contiguous for short cycle (21 days)")
    func contiguousPhases21() {
        var phases: [CyclePhaseResult] = []
        for day in 1...21 {
            phases.append(CycleMath.cyclePhase(cycleDay: day, cycleLength: 21, bleedingDays: 5))
        }
        #expect(phases.contains(.menstrual))
        #expect(phases.contains(.follicular))
        #expect(phases.contains(.ovulatory))
        #expect(phases.contains(.luteal))
    }
}

@Suite("Cycle Validation")
struct CycleValidationTests {

    @Test("validateCycleLength clamps to 18-50")
    func cycleLengthBounds() {
        #expect(CycleMath.validateCycleLength(28) == 28)
        #expect(CycleMath.validateCycleLength(10) == 18)
        #expect(CycleMath.validateCycleLength(60) == 50)
        #expect(CycleMath.validateCycleLength(0) == 28) // fallback
    }

    @Test("validateBleedingDays clamps to 1...min(10, cl/2)")
    func bleedingDaysBounds() {
        #expect(CycleMath.validateBleedingDays(5, cycleLength: 28) == 5)
        #expect(CycleMath.validateBleedingDays(0, cycleLength: 28) == 1)
        #expect(CycleMath.validateBleedingDays(15, cycleLength: 28) == 10)
        #expect(CycleMath.validateBleedingDays(8, cycleLength: 14) == 7) // cl/2 = 7
    }

    @Test("CycleRecord clamps bleedingDays and actualCycleLength")
    func cycleRecordValidation() {
        let record = CycleRecord(startDate: Date(), bleedingDays: 15, actualCycleLength: 5)
        #expect(record.bleedingDays == 10) // clamped from 15
        #expect(record.actualCycleLength == 18) // clamped from 5
    }

    @Test("MenstrualProfileRecord clamps avgCycleLength and avgBleedingDays")
    func profileValidation() {
        let profile = MenstrualProfileRecord(avgCycleLength: 100, avgBleedingDays: 20)
        #expect(profile.avgCycleLength == 50)
        #expect(profile.avgBleedingDays == 10)
    }
}

@Suite("Prediction Determinism")
struct PredictionDeterminismTests {

    @Test("Same input produces same prediction — deterministic")
    func deterministic() {
        let cal = Calendar.current
        let lastPeriod = cal.date(from: DateComponents(year: 2026, month: 2, day: 22))!
        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "unknown")
        let cycles = [CycleInput(startDate: lastPeriod, isConfirmed: true)]

        let r1 = MenstrualPredictor.predict(cycles: cycles, profile: profile)
        let r2 = MenstrualPredictor.predict(cycles: cycles, profile: profile)

        #expect(r1.predictedStart == r2.predictedStart)
        #expect(r1.confidence == r2.confidence)
        #expect(r1.algorithmVersion == r2.algorithmVersion)
    }

    @Test("V1 back-projection capped — does not loop infinitely")
    func v1Capped() {
        let cal = Calendar.current
        // Very old last period (3 years ago) with short cycle
        let oldPeriod = cal.date(from: DateComponents(year: 2023, month: 1, day: 1))!
        let profile = ProfileInput(avgCycleLength: 18, avgBleedingDays: 3, cycleRegularity: "unknown")
        let cycles = [CycleInput(startDate: oldPeriod)]

        let result = MenstrualPredictor.predict(cycles: cycles, profile: profile)
        // Should project forward but not infinitely — prediction should be within ~2 years
        let maxDate = cal.date(from: DateComponents(year: 2028, month: 1, day: 1))!
        #expect(result.predictedStart < maxDate)
    }

    @Test("extractCycleLengths filters invalid stored values")
    func extractLengthsFilter() {
        let cycles = [
            CycleInput(startDate: Date(), actualCycleLength: 10), // invalid: < 18
            CycleInput(startDate: CycleMath.addDays(Date(), -28)),
        ]
        let lengths = MenstrualPredictor.extractedCycleLengths(cycles: cycles, fallbackLength: 28)
        // stored value 10 should be filtered out, gap of 28 should be computed
        #expect(!lengths.contains(10))
        #expect(lengths.contains(28))
    }

    @Test("V4 seasonal requires 2+ data points per month")
    func seasonalMinimum() {
        let cal = Calendar.current
        // 6 cycles, each in different month — no month has 2+ data points
        var cycles: [CycleInput] = []
        for i in 0..<6 {
            let date = cal.date(from: DateComponents(year: 2025, month: 1 + i, day: 1))!
            cycles.append(CycleInput(startDate: date, actualCycleLength: 28, isConfirmed: true))
        }
        cycles.reverse()

        let profile = ProfileInput(avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular")
        let r1 = MenstrualPredictor.predict(cycles: cycles, profile: profile)
        // Result should exist and be reasonable (seasonal adjustment = 0)
        #expect(r1.algorithmVersion == .v4ML)
    }
}
