@testable import CycleApp
import Foundation
import Testing

// MARK: - HBIScore codable round-trip

@Suite("HBIScore — Codable")
struct HBIScoreCodableTests {

    @Test("Round-trip preserves all fields")
    func roundTrip() throws {
        let original = HBIScore.mock
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HBIScore.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.energyScore == original.energyScore)
        #expect(decoded.anxietyScore == original.anxietyScore)
        #expect(decoded.hbiRaw == original.hbiRaw)
        #expect(decoded.hbiAdjusted == original.hbiAdjusted)
        #expect(decoded.cyclePhase == original.cyclePhase)
        #expect(decoded.hasSelfReport == original.hasSelfReport)
    }

    @Test("Optional clarityScore survives nil round-trip")
    func optionalsNilRoundTrip() throws {
        let score = HBIScore(
            id: .init(42), userId: 1, scoreDate: Date(),
            energyScore: 50, anxietyScore: 50, sleepScore: 50, moodScore: 50,
            clarityScore: nil, hbiRaw: 50, hbiAdjusted: 50
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(score)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HBIScore.self, from: data)
        #expect(decoded.clarityScore == nil)
        #expect(decoded.cyclePhase == nil)
        #expect(decoded.phaseMultiplier == nil)
    }
}

// MARK: - DailyReportRequest clamping

@Suite("DailyReportRequest — Clamping")
struct DailyReportRequestClampTests {

    @Test("Clamps all fields to 1...5")
    func clampAll() {
        let req = DailyReportRequest(
            energyLevel: 99, stressLevel: -10,
            sleepQuality: 7, moodLevel: 0
        )
        #expect(req.energyLevel == 5)
        #expect(req.stressLevel == 1)
        #expect(req.sleepQuality == 5)
        #expect(req.moodLevel == 1)
    }

    @Test("Valid values pass through unchanged")
    func validPassThrough() {
        let req = DailyReportRequest(energyLevel: 3, stressLevel: 4, sleepQuality: 5, moodLevel: 1)
        #expect(req.energyLevel == 3)
        #expect(req.stressLevel == 4)
        #expect(req.sleepQuality == 5)
        #expect(req.moodLevel == 1)
    }

    @Test("Notes preserved optional")
    func notesPreserved() {
        let with = DailyReportRequest(
            energyLevel: 3, stressLevel: 3, sleepQuality: 3, moodLevel: 3,
            notes: "test"
        )
        #expect(with.notes == "test")

        let without = DailyReportRequest(
            energyLevel: 3, stressLevel: 3, sleepQuality: 3, moodLevel: 3
        )
        #expect(without.notes == nil)
    }
}

// MARK: - CyclePhase display/Codable

@Suite("CyclePhase — Display & Codable")
struct CyclePhaseDisplayTests {

    @Test("displayName covers all cases")
    func displayNames() {
        #expect(CyclePhase.menstrual.displayName == "Menstrual")
        #expect(CyclePhase.follicular.displayName == "Follicular")
        #expect(CyclePhase.ovulatory.displayName == "Ovulatory")
        #expect(CyclePhase.luteal.displayName == "Luteal")
        #expect(CyclePhase.late.displayName == "Late")
    }

    @Test("biologicalPhases excludes .late")
    func biologicalExcludesLate() {
        let phases = CyclePhase.biologicalPhases
        #expect(phases.count == 4)
        #expect(!phases.contains(.late))
    }

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() throws {
        for phase in CyclePhase.allCases {
            let encoded = try JSONEncoder().encode(phase)
            let decoded = try JSONDecoder().decode(CyclePhase.self, from: encoded)
            #expect(decoded == phase)
        }
    }

    @Test("dayRange for 28-day cycle tiles without overlap")
    func dayRangeTiles() {
        let menstrual = CyclePhase.menstrual.dayRange(cycleLength: 28, bleedingDays: 5)
        let follicular = CyclePhase.follicular.dayRange(cycleLength: 28, bleedingDays: 5)
        let ovulatory = CyclePhase.ovulatory.dayRange(cycleLength: 28, bleedingDays: 5)
        let luteal = CyclePhase.luteal.dayRange(cycleLength: 28, bleedingDays: 5)

        #expect(menstrual.lowerBound == 1)
        #expect(menstrual.upperBound == 5)
        #expect(follicular.lowerBound == 6)
        #expect(ovulatory.lowerBound > follicular.upperBound)
        #expect(luteal.lowerBound > ovulatory.upperBound)
        #expect(luteal.upperBound == 28)
    }

    @Test("Phase guidance — energyLevel ranges 1-5")
    func energyGuidance() {
        for phase in CyclePhase.allCases {
            #expect(phase.energyLevel >= 1)
            #expect(phase.energyLevel <= 5)
        }
    }

    @Test("Phase guidance — bestFor/avoid not empty")
    func guidanceNotEmpty() {
        for phase in CyclePhase.allCases {
            #expect(!phase.bestFor.isEmpty)
            #expect(!phase.avoid.isEmpty)
            #expect(!phase.readings.isEmpty)
            #expect(!phase.description.isEmpty)
            #expect(!phase.emoji.isEmpty)
        }
    }
}

// MARK: - FlowIntensity

@Suite("FlowIntensity")
struct FlowIntensityTests {

    @Test("dropletCount monotonically increases")
    func dropletCount() {
        #expect(FlowIntensity.spotting.dropletCount == 0)
        #expect(FlowIntensity.light.dropletCount == 1)
        #expect(FlowIntensity.medium.dropletCount == 2)
        #expect(FlowIntensity.heavy.dropletCount == 3)
    }

    @Test("label present for every case")
    func labels() {
        for flow in FlowIntensity.allCases {
            #expect(!flow.label.isEmpty)
        }
    }

    @Test("Codable round-trip")
    func codable() throws {
        for flow in FlowIntensity.allCases {
            let data = try JSONEncoder().encode(flow)
            let decoded = try JSONDecoder().decode(FlowIntensity.self, from: data)
            #expect(decoded == flow)
        }
    }
}

// MARK: - FertilityLevel

@Suite("FertilityLevel")
struct FertilityLevelTests {

    @Test("probability strings present")
    func probability() {
        for level in FertilityLevel.allCases {
            #expect(!level.probability.isEmpty)
            #expect(level.probability.contains("%"))
        }
    }

    @Test("Codable round-trip")
    func codable() throws {
        for level in FertilityLevel.allCases {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(FertilityLevel.self, from: data)
            #expect(decoded == level)
        }
    }
}
