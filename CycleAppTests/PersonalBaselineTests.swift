@testable import CycleApp
import Foundation
import Testing

// MARK: - Personal Baseline Computation

@Suite("HBICalculator — Personal Baseline")
struct PersonalBaselineTests {

    // Helper — build an HBIScore sample for a phase on a given date.
    private func sample(
        phase: CyclePhase,
        hbiRaw: Int,
        daysAgo: Int,
        id: Int64 = 0
    ) -> HBIScore {
        let date = Calendar.current.date(
            byAdding: .day, value: -daysAgo, to: Date()
        )!
        return HBIScore(
            id: .init(id == 0 ? Int64(daysAgo) : id),
            userId: 0,
            scoreDate: date,
            energyScore: 70,
            anxietyScore: 70,
            sleepScore: 70,
            moodScore: 70,
            hbiRaw: hbiRaw,
            hbiAdjusted: hbiRaw,
            cyclePhase: phase.rawValue,
            cycleDay: 1
        )
    }

    @Test("0 samples → insufficient confidence, averageScore nil")
    func zeroSamplesInsufficient() {
        let baseline = HBICalculator.personalBaseline(
            phase: .luteal,
            historicalScores: []
        )
        #expect(baseline.confidence == .insufficient)
        #expect(baseline.averageScore == nil)
        #expect(baseline.sampleCount == 0)
        #expect(baseline.cyclesRepresented == 0)
    }

    @Test("5 samples across 2 cycles → insufficient (below minSamplesRequired)")
    func fiveSamplesBelowMin() {
        // 3 samples in one cycle (cycleDays 0-2 days ago), 2 in another (~28-30 days ago)
        let scores: [HBIScore] = [
            sample(phase: .luteal, hbiRaw: 70, daysAgo: 0),
            sample(phase: .luteal, hbiRaw: 72, daysAgo: 1),
            sample(phase: .luteal, hbiRaw: 68, daysAgo: 2),
            sample(phase: .luteal, hbiRaw: 75, daysAgo: 28),
            sample(phase: .luteal, hbiRaw: 71, daysAgo: 29),
        ]
        let baseline = HBICalculator.personalBaseline(
            phase: .luteal,
            historicalScores: scores
        )
        #expect(baseline.sampleCount == 5)
        #expect(baseline.cyclesRepresented == 2)
        #expect(baseline.confidence == .insufficient)
        #expect(baseline.averageScore == nil)
    }

    @Test("6 samples across 2 cycles → building confidence")
    func sixSamplesBuilding() {
        // 3 samples in cycle A, 3 in cycle B
        let scores: [HBIScore] = [
            sample(phase: .luteal, hbiRaw: 70, daysAgo: 0, id: 1),
            sample(phase: .luteal, hbiRaw: 72, daysAgo: 1, id: 2),
            sample(phase: .luteal, hbiRaw: 68, daysAgo: 2, id: 3),
            sample(phase: .luteal, hbiRaw: 75, daysAgo: 28, id: 4),
            sample(phase: .luteal, hbiRaw: 71, daysAgo: 29, id: 5),
            sample(phase: .luteal, hbiRaw: 73, daysAgo: 30, id: 6),
        ]
        let baseline = HBICalculator.personalBaseline(
            phase: .luteal,
            historicalScores: scores
        )
        #expect(baseline.sampleCount == 6)
        #expect(baseline.cyclesRepresented == 2)
        #expect(baseline.confidence == .building)
        #expect(baseline.averageScore != nil)
    }

    @Test("12 samples across 3 cycles → established confidence")
    func twelveSamplesEstablished() {
        // 4 samples in each of 3 cycles: day 0-3, day 28-31, day 56-59
        var scores: [HBIScore] = []
        var id: Int64 = 1
        for cycleStart in [0, 28, 56] {
            for offset in 0..<4 {
                scores.append(sample(
                    phase: .luteal,
                    hbiRaw: 70,
                    daysAgo: cycleStart + offset,
                    id: id
                ))
                id += 1
            }
        }
        let baseline = HBICalculator.personalBaseline(
            phase: .luteal,
            historicalScores: scores
        )
        #expect(baseline.sampleCount == 12)
        #expect(baseline.cyclesRepresented == 3)
        #expect(baseline.confidence == .established)
        #expect(baseline.averageScore == 70)
    }

    @Test("Average correctly computed from matching samples only")
    func averageComputedFromMatching() {
        // 6 luteal samples with varying raw scores across 2 cycles
        let lutealScores = [60, 70, 80, 90, 50, 100]
        var scores: [HBIScore] = []
        var id: Int64 = 1
        for (i, raw) in lutealScores.enumerated() {
            let daysAgo = i < 3 ? i : 28 + (i - 3)
            scores.append(sample(phase: .luteal, hbiRaw: raw, daysAgo: daysAgo, id: id))
            id += 1
        }
        // Add follicular samples — should be filtered out
        for i in 0..<5 {
            scores.append(sample(phase: .follicular, hbiRaw: 99, daysAgo: i, id: id))
            id += 1
        }
        let baseline = HBICalculator.personalBaseline(
            phase: .luteal,
            historicalScores: scores
        )
        let expectedAvg = Double(lutealScores.reduce(0, +)) / Double(lutealScores.count)
        #expect(baseline.averageScore != nil)
        #expect(abs((baseline.averageScore ?? 0) - expectedAvg) < 0.5)
    }

    @Test("Samples from wrong phase are excluded")
    func filtersWrongPhase() {
        // Only follicular samples, asking for luteal → 0 matches
        let scores: [HBIScore] = (0..<10).map {
            sample(phase: .follicular, hbiRaw: 70, daysAgo: $0, id: Int64($0 + 1))
        }
        let baseline = HBICalculator.personalBaseline(
            phase: .luteal,
            historicalScores: scores
        )
        #expect(baseline.sampleCount == 0)
        #expect(baseline.confidence == .insufficient)
    }

    @Test("Distinct cycle count clusters dates within 14 days")
    func distinctCycleCountClusters() {
        let today = Date()
        let cal = Calendar.current
        // Three dates within 10 days → 1 cluster
        let tight = [
            cal.date(byAdding: .day, value: 0, to: today)!,
            cal.date(byAdding: .day, value: 5, to: today)!,
            cal.date(byAdding: .day, value: 10, to: today)!,
        ]
        #expect(HBICalculator.distinctCycleCount(from: tight) == 1)

        // Spread across 3 cycles (0, 28, 56)
        let spread = [
            cal.date(byAdding: .day, value: 0, to: today)!,
            cal.date(byAdding: .day, value: 28, to: today)!,
            cal.date(byAdding: .day, value: 56, to: today)!,
        ]
        #expect(HBICalculator.distinctCycleCount(from: spread) == 3)

        // Empty
        #expect(HBICalculator.distinctCycleCount(from: []) == 0)
    }

    @Test("PersonalBaseline.empty returns insufficient zero-state")
    func emptyState() {
        let baseline = PersonalBaseline.empty(phase: .ovulatory)
        #expect(baseline.phase == .ovulatory)
        #expect(baseline.averageScore == nil)
        #expect(baseline.sampleCount == 0)
        #expect(baseline.cyclesRepresented == 0)
        #expect(baseline.confidence == .insufficient)
    }
}
