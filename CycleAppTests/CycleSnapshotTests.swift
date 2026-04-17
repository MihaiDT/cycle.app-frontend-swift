@testable import CycleApp
import Foundation
import Testing

// MARK: - CycleSnapshot Tests

@Suite("CycleSnapshot")
struct CycleSnapshotTests {

    @Test(".empty has no data")
    func emptySentinel() {
        let s = CycleSnapshot.empty
        #expect(s.periodDays.isEmpty)
        #expect(s.predictedDays.isEmpty)
        #expect(s.fertileDays.isEmpty)
        #expect(s.ovulationDays.isEmpty)
        #expect(s.flowIntensity.isEmpty)
    }

    @Test("Default init matches .empty")
    func defaultInitEmpty() {
        let s = CycleSnapshot()
        #expect(s == .empty)
    }

    @Test("Init with explicit values round-trips")
    func roundTrip() {
        let periods: Set<String> = ["2026-01-01", "2026-01-02"]
        let predicted: Set<String> = ["2026-01-28"]
        let fertile: [String: FertilityLevel] = ["2026-01-14": .peak]
        let ovulation: Set<String> = ["2026-01-14"]
        let flow: [String: FlowIntensity] = ["2026-01-01": .medium]

        let s = CycleSnapshot(
            periodDays: periods,
            predictedDays: predicted,
            fertileDays: fertile,
            ovulationDays: ovulation,
            flowIntensity: flow
        )

        #expect(s.periodDays == periods)
        #expect(s.predictedDays == predicted)
        #expect(s.fertileDays == fertile)
        #expect(s.ovulationDays == ovulation)
        #expect(s.flowIntensity == flow)
    }

    @Test("Equatable — same data equals")
    func equatableSame() {
        let a = CycleSnapshot(periodDays: ["2026-01-01"], predictedDays: ["2026-01-28"])
        let b = CycleSnapshot(periodDays: ["2026-01-01"], predictedDays: ["2026-01-28"])
        #expect(a == b)
    }

    @Test("Equatable — different periodDays differ")
    func equatableDifferent() {
        let a = CycleSnapshot(periodDays: ["2026-01-01"])
        let b = CycleSnapshot(periodDays: ["2026-01-02"])
        #expect(a != b)
    }

    @Test("Mutating periodDays preserves other fields")
    func mutatePeriod() {
        var s = CycleSnapshot(
            periodDays: ["a"],
            predictedDays: ["b"],
            fertileDays: ["c": .peak],
            ovulationDays: ["d"],
            flowIntensity: ["a": .heavy]
        )
        s.periodDays.insert("e")
        #expect(s.periodDays == ["a", "e"])
        #expect(s.predictedDays == ["b"])
        #expect(s.fertileDays == ["c": .peak])
        #expect(s.ovulationDays == ["d"])
        #expect(s.flowIntensity == ["a": .heavy])
    }
}
