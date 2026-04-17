@testable import CycleApp
import Foundation
import Testing

// MARK: - Phase Weights Table

@Suite("HBICalculator — Phase Weights")
struct HBICalculatorPhaseWeightsTests {

    private let allBiological: [CyclePhase] = [.menstrual, .follicular, .ovulatory, .luteal]

    @Test("All four biological phase weights sum to 1.0 (pre-normalize)")
    func allPhasesSumToOne() {
        for phase in allBiological {
            let w = HBICalculator.phaseWeights(for: phase)
            // Inner tolerance — raw table entries should be exact 1.0 (Double math).
            #expect(abs(w.total - 1.0) < 0.0001, "Phase \(phase.rawValue) weights sum = \(w.total)")
        }
    }

    @Test("Menstrual has the lowest energy weight")
    func menstrualLowestEnergy() {
        let energyByPhase = allBiological.map { ($0, HBICalculator.phaseWeights(for: $0).energy) }
        let lowest = energyByPhase.min(by: { $0.1 < $1.1 })!
        #expect(lowest.0 == .menstrual)
    }

    @Test("Follicular has the highest energy weight")
    func follicularHighestEnergy() {
        let energyByPhase = allBiological.map { ($0, HBICalculator.phaseWeights(for: $0).energy) }
        let highest = energyByPhase.max(by: { $0.1 < $1.1 })!
        #expect(highest.0 == .follicular)
    }

    @Test("Luteal + menstrual have the highest combined sleep+calm weighting")
    func lutealMenstrualHighestRestCalm() {
        let restCalm: (CyclePhase) -> Double = { phase in
            let w = HBICalculator.phaseWeights(for: phase)
            return w.sleep + w.calm
        }
        let menstrualRC = restCalm(.menstrual)
        let lutealRC = restCalm(.luteal)
        let follicularRC = restCalm(.follicular)
        let ovulatoryRC = restCalm(.ovulatory)

        #expect(menstrualRC >= follicularRC)
        #expect(menstrualRC >= ovulatoryRC)
        #expect(lutealRC >= follicularRC)
        #expect(lutealRC >= ovulatoryRC)
    }

    @Test("phaseWeights(for: .late) returns luteal weights")
    func lateMatchesLuteal() {
        let late = HBICalculator.phaseWeights(for: .late)
        let luteal = HBICalculator.phaseWeights(for: .luteal)
        #expect(late == luteal)
    }

    @Test("normalized() scales any weights to sum 1.0")
    func normalizedSumsToOne() {
        let weights = HBIComponentWeights(
            energy: 2.0, mood: 4.0, sleep: 2.0, calm: 2.0, clarity: 0
        )
        let normalized = weights.normalized()
        #expect(abs(normalized.total - 1.0) < 0.0001)
        // Mood should double energy/sleep/calm after scaling (2:4:2:2 → .2:.4:.2:.2)
        #expect(abs(normalized.mood - 0.4) < 0.0001)
        #expect(abs(normalized.energy - 0.2) < 0.0001)
    }

    @Test("normalized() on zero weights returns self unchanged")
    func normalizedZeroReturnsSelf() {
        let zero = HBIComponentWeights(energy: 0, mood: 0, sleep: 0, calm: 0)
        let normalized = zero.normalized()
        #expect(normalized == zero)
    }
}
