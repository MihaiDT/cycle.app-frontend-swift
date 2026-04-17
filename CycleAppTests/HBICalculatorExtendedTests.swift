@testable import CycleApp
import Foundation
import Testing

// MARK: - HealthKit Component Scoring

@Suite("HBICalculator — HealthKit scoring")
struct HBICalculatorHealthKitTests {

    @Test("Energy score blends HRV (60%) and steps (40%)")
    func energyBlend() {
        // HRV 60 (mid) normalizes to 0.5 → 50 * 0.6 = 30
        // Steps 7500 (mid) normalizes to 0.5 → 50 * 0.4 = 20
        // Total = 50
        let score = HBICalculator.energyScoreFromHealthKit(hrvAvg: 60, steps: 7500)!
        #expect(abs(score - 50) < 0.5)
    }

    @Test("Energy score falls back to 50 when one component missing")
    func energyFallbackMissing() {
        // Only steps; hrv defaults to 50 neutral
        let score = HBICalculator.energyScoreFromHealthKit(hrvAvg: nil, steps: 15000)!
        // hrv→50 * 0.6 = 30, steps → 100 * 0.4 = 40 → 70
        #expect(abs(score - 70) < 0.5)
    }

    @Test("Energy returns nil only when both HealthKit fields nil")
    func energyReturnsNilBoth() {
        #expect(HBICalculator.energyScoreFromHealthKit(hrvAvg: nil, steps: nil) == nil)
    }

    @Test("Anxiety inverts HRV and RHR")
    func anxietyInverts() {
        // High HRV (100) → low anxiety → (1 - 1.0) * 100 = 0 * 0.7 = 0
        // Low RHR (40)  → low anxiety → (1 - 0) * 100 = 100 * 0.3 = 30
        // Total = 30 (low stress)
        let low = HBICalculator.anxietyScoreFromHealthKit(hrvAvg: 100, rhrAvg: 40)!
        #expect(low < 40)

        // Low HRV (20) + High RHR (90) → high anxiety
        // hrvComponent = (1 - 0) * 100 = 100 * 0.7 = 70
        // rhrComponent = (1 - 1) * 100 = 0 * 0.3 = 0
        // Total = 70
        let high = HBICalculator.anxietyScoreFromHealthKit(hrvAvg: 20, rhrAvg: 90)!
        #expect(high >= 60)
        #expect(high > low)
    }

    @Test("Anxiety returns nil only when both fields nil")
    func anxietyReturnsNilBoth() {
        #expect(HBICalculator.anxietyScoreFromHealthKit(hrvAvg: nil, rhrAvg: nil) == nil)
    }

    @Test("Sleep score peaks at 8 hours")
    func sleepPeakAt8() {
        let s8 = HBICalculator.sleepScoreFromHealthKit(hours: 8.0)!
        let s7 = HBICalculator.sleepScoreFromHealthKit(hours: 7.0)!
        let s9 = HBICalculator.sleepScoreFromHealthKit(hours: 9.0)!
        // 8h should be highest, with 7 and 9 at the boundary 90.0
        #expect(s8 > s7)
        #expect(s8 > s9)
        #expect(s7 == 90.0)
        #expect(s9 == 90.0)
    }

    @Test("Sleep score degrades below 7h")
    func sleepDegradesLow() {
        let s5 = HBICalculator.sleepScoreFromHealthKit(hours: 5.0)!
        let s3 = HBICalculator.sleepScoreFromHealthKit(hours: 3.0)!
        #expect(s5 > s3)
    }

    @Test("Sleep score degrades above 9h, floored at 50")
    func sleepDegradesHigh() {
        let s10 = HBICalculator.sleepScoreFromHealthKit(hours: 10.0)!
        let s15 = HBICalculator.sleepScoreFromHealthKit(hours: 15.0)!
        #expect(s10 > s15)
        #expect(s15 >= 50) // floor
    }

    @Test("Mood score uses HRV + mindfulness bonus, capped at 100")
    func moodScoreBonus() {
        // No mindfulness, HRV=60 → 50 base
        let base = HBICalculator.moodScoreFromHealthKit(hrvAvg: 60, mindfulMinutes: nil)!
        #expect(abs(base - 50) < 1)

        // With 30 min mindfulness bonus = 30/6 = 5 → 55
        let bonus = HBICalculator.moodScoreFromHealthKit(hrvAvg: 60, mindfulMinutes: 30)!
        #expect(bonus > base)

        // Cap at 100 with max HRV + big bonus
        let maxMood = HBICalculator.moodScoreFromHealthKit(hrvAvg: 100, mindfulMinutes: 120)!
        #expect(maxMood <= 100)
    }

    @Test("Mood returns nil when HRV is nil")
    func moodNilWithoutHRV() {
        #expect(HBICalculator.moodScoreFromHealthKit(hrvAvg: nil, mindfulMinutes: 30) == nil)
    }
}

// MARK: - HBI calculation — mixed inputs

@Suite("HBICalculator — Combined Inputs")
struct HBICalculatorCombinedTests {

    @Test("HealthKit data preferred over self-report when available")
    func healthKitPreferred() {
        // Self-report gives 5/5 → energyScore=100 from self-report.
        // HealthKit should override: HRV 20 (min) + 0 steps → low energy.
        let result = HBICalculator.calculate(
            selfReport: SelfReportInput(energyLevel: 5, stressLevel: 1, sleepQuality: 5, moodLevel: 5),
            healthKit: HealthKitInput(hrvAvg: 20, rhrAvg: 40, steps: 0, sleepHours: 8, mindfulMinutes: nil)
        )
        // Energy from HK should be low despite self-report saying 5
        #expect(result.energyScore < 50)
        #expect(result.hasHealthKitData == true)
        #expect(result.hasSelfReport == true)
        #expect(result.completenessScore == 100)
    }

    @Test("Phase multiplier reduces HBI in luteal phase")
    func lutealMultiplier() {
        let input = SelfReportInput(energyLevel: 4, stressLevel: 2, sleepQuality: 4, moodLevel: 4)
        let lutealResult = HBICalculator.calculate(selfReport: input, cyclePhase: .luteal)
        let noPhase = HBICalculator.calculate(selfReport: input)

        // Luteal multipliers are energy 0.85, anxiety 1.20 (high), sleep 0.90, mood 0.85
        #expect(lutealResult.hbiAdjusted < noPhase.hbiRaw)
    }

    @Test("Phase multiplier increases HBI in ovulatory phase")
    func ovulatoryBoost() {
        let input = SelfReportInput(energyLevel: 3, stressLevel: 3, sleepQuality: 3, moodLevel: 3)
        let ovulatory = HBICalculator.calculate(selfReport: input, cyclePhase: .ovulatory)
        #expect(ovulatory.hbiAdjusted > ovulatory.hbiRaw)
    }

    @Test("phaseMultiplier exposes correct ovulatory multiplier")
    func phaseMultiplierOvulatory() {
        let multipliers = HBICalculator.phaseMultipliers(for: .ovulatory)
        #expect(multipliers.energy == 1.20)
        #expect(multipliers.anxiety == 0.85)
        #expect(multipliers.mood == 1.15)
    }

    @Test("phaseMultiplier late matches luteal behavior")
    func phaseMultiplierLate() {
        let multipliers = HBICalculator.phaseMultipliers(for: .late)
        // Late uses slightly different multipliers than luteal (anxiety 1.15 vs 1.20)
        #expect(multipliers.energy == 0.85)
        #expect(multipliers.anxiety == 1.15)
    }
}

// MARK: - HBI Trend

@Suite("HBICalculator — Trend Analysis")
struct HBICalculatorTrendTests {

    @Test("trendVsBaseline — deviation up")
    func trendUp() {
        // current 75, baseline 70 → +7.14%
        let trend = HBICalculator.trendVsBaseline(current: 75, baseline: 70)
        #expect(trend > 5)
        #expect(trend < 10)
    }

    @Test("trendVsBaseline — deviation down")
    func trendDown() {
        let trend = HBICalculator.trendVsBaseline(current: 65, baseline: 70)
        #expect(trend < -5)
    }

    @Test("trendVsBaseline — zero baseline returns 0")
    func trendZeroBaseline() {
        let trend = HBICalculator.trendVsBaseline(current: 75, baseline: 0)
        #expect(trend == 0)
    }

    @Test("trendDirection classifies deviations")
    func trendDirectionClassifies() {
        #expect(HBICalculator.trendDirection(deviation: 3) == "up")
        #expect(HBICalculator.trendDirection(deviation: -3) == "down")
        #expect(HBICalculator.trendDirection(deviation: 0) == "stable")
        #expect(HBICalculator.trendDirection(deviation: 1.5) == "stable")
        #expect(HBICalculator.trendDirection(deviation: -1.5) == "stable")
    }

    @Test("Baseline rejects < 7 scores")
    func baselineRejectsFew() {
        let scores: [Double] = [70, 72, 68, 75, 71, 69] // 6 scores
        #expect(HBICalculator.calculateBaseline(scores: scores) == nil)
    }

    @Test("Baseline averages a large set of scores")
    func baselineAveragesLarge() {
        let scores: [Double] = Array(repeating: 70.0, count: 30)
        let baseline = HBICalculator.calculateBaseline(scores: scores)
        #expect(baseline == 70)
    }
}

// MARK: - Likert bounds / clamping

@Suite("HBICalculator — Likert clamping")
struct HBILikertBoundsTests {

    @Test("Likert clamps above 5")
    func clampAbove() {
        // value 10 should clamp to 5 → 100
        #expect(HBICalculator.likertToScore(10) == 100)
    }

    @Test("Likert clamps below 1")
    func clampBelow() {
        // value 0 should clamp to 1 → 20
        #expect(HBICalculator.likertToScore(0) == 20)
        // negative clamp
        #expect(HBICalculator.likertToScore(-5) == 20)
    }

    @Test("Inverted Likert clamps symmetrically")
    func clampInverted() {
        // value 0 → 1 → 100
        #expect(HBICalculator.likertToScoreInverted(0) == 100)
        // value 10 → 5 → 20
        #expect(HBICalculator.likertToScoreInverted(10) == 20)
    }
}
