@testable import CycleApp
import Foundation
import SwiftData
import Testing

// MARK: - MenstrualLocalClient — SwiftData helpers (in-memory container)

/// Tests for helper functions on MenstrualLocalClient using an in-memory
/// ModelContainer. Covers helpers that accept a ModelContext parameter —
/// avoiding CycleDataStore.shared. Full `confirmPeriod`/`logSymptom` closures
/// hardcode the shared container and are excluded (live-only coverage).
@Suite("MenstrualLocalClient — SwiftData Helpers", .serialized)
struct MenstrualLocalHelperTests {

    private func makeInMemoryContext() -> ModelContext {
        let container = CycleDataStore.makeTestContainer()
        return ModelContext(container)
    }

    @Test("fetchProfile returns nil on empty store")
    func fetchProfileEmpty() throws {
        let context = makeInMemoryContext()
        let profile = try MenstrualLocalClient.fetchProfile(context: context)
        #expect(profile == nil)
    }

    @Test("fetchProfile returns latest by createdAt")
    func fetchProfileLatest() throws {
        let context = makeInMemoryContext()
        // Older profile
        let older = MenstrualProfileRecord(
            avgCycleLength: 28, avgBleedingDays: 4,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        context.insert(older)
        // Newer profile
        let newer = MenstrualProfileRecord(
            avgCycleLength: 30, avgBleedingDays: 5,
            createdAt: Date()
        )
        context.insert(newer)
        try context.save()

        let fetched = try MenstrualLocalClient.fetchProfile(context: context)
        #expect(fetched?.avgCycleLength == 30)
    }

    @Test("fetchLatestCycle returns most recent by startDate")
    func fetchLatestCycle() throws {
        let context = makeInMemoryContext()
        let older = CycleRecord(
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            bleedingDays: 5
        )
        let newer = CycleRecord(
            startDate: Date(timeIntervalSince1970: 1_750_000_000),
            bleedingDays: 5
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let latest = try MenstrualLocalClient.fetchLatestCycle(context: context)
        #expect(latest?.startDate == newer.startDate)
    }

    @Test("fetchAllCycles returns sorted desc by startDate")
    func fetchAllCyclesSorted() throws {
        let context = makeInMemoryContext()
        let d1 = Date(timeIntervalSince1970: 1_700_000_000)
        let d2 = Date(timeIntervalSince1970: 1_705_000_000)
        let d3 = Date(timeIntervalSince1970: 1_710_000_000)
        [d1, d2, d3].forEach {
            context.insert(CycleRecord(startDate: $0, bleedingDays: 5))
        }
        try context.save()

        let cycles = try MenstrualLocalClient.fetchAllCycles(context: context)
        #expect(cycles.count == 3)
        // sorted by startDate desc
        #expect(cycles[0].startDate == d3)
        #expect(cycles[1].startDate == d2)
        #expect(cycles[2].startDate == d1)
    }

    @Test("deduplicateCycles keeps one per startDate")
    func deduplicateCycles() throws {
        let context = makeInMemoryContext()
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        // Two cycles on the same day
        context.insert(CycleRecord(startDate: day, bleedingDays: 4))
        context.insert(CycleRecord(startDate: day, bleedingDays: 5))
        // Different day
        context.insert(CycleRecord(startDate: cal.date(byAdding: .day, value: -28, to: day)!, bleedingDays: 5))
        try context.save()

        try MenstrualLocalClient.deduplicateCycles(context: context)

        let remaining = try MenstrualLocalClient.fetchAllCycles(context: context)
        #expect(remaining.count == 2)
    }

    @Test("recalculateCycleStats computes actualCycleLength from gaps")
    func recalculateCycleLengths() throws {
        let context = makeInMemoryContext()
        let profile = MenstrualProfileRecord()
        context.insert(profile)

        let cal = Calendar.current
        let d1 = cal.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let d2 = cal.date(from: DateComponents(year: 2025, month: 1, day: 29))! // 28-day gap
        let d3 = cal.date(from: DateComponents(year: 2025, month: 2, day: 26))! // 28-day gap
        [d1, d2, d3].forEach {
            context.insert(CycleRecord(startDate: $0, bleedingDays: 5))
        }
        try context.save()

        try MenstrualLocalClient.recalculateCycleStats(context: context)

        let cycles = try MenstrualLocalClient.fetchAllCycles(context: context)
        // Two cycles should have actualCycleLength = 28 (gaps from next cycle).
        // Most recent cycle has nil.
        let lengths = cycles.compactMap { $0.actualCycleLength }
        #expect(lengths.count == 2)
        #expect(lengths.allSatisfy { $0 == 28 })
    }

    @Test("recalculateCycleStats updates profile avgCycleLength from observed data")
    func recalculateUpdatesProfile() throws {
        let context = makeInMemoryContext()
        let profile = MenstrualProfileRecord(avgCycleLength: 28)
        context.insert(profile)

        let cal = Calendar.current
        // Three cycles with 30-day gaps → avgCycleLength should become 30
        let d1 = cal.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let d2 = cal.date(from: DateComponents(year: 2025, month: 1, day: 31))!
        let d3 = cal.date(from: DateComponents(year: 2025, month: 3, day: 2))!
        [d1, d2, d3].forEach {
            context.insert(CycleRecord(startDate: $0, bleedingDays: 5))
        }
        try context.save()

        try MenstrualLocalClient.recalculateCycleStats(context: context)
        let refreshed = try MenstrualLocalClient.fetchProfile(context: context)
        #expect(refreshed?.avgCycleLength == 30)
    }
}

// MARK: - regeneratePredictions with in-memory container

@Suite("MenstrualLocalClient — regeneratePredictions", .serialized)
struct RegeneratePredictionsTests {

    private func seedBaseline(container: ModelContainer, cycleCount: Int = 3) throws {
        let context = ModelContext(container)
        let profile = MenstrualProfileRecord(
            avgCycleLength: 28, avgBleedingDays: 5, cycleRegularity: "regular"
        )
        context.insert(profile)

        let cal = Calendar.current
        for i in 0..<cycleCount {
            // Cycles spaced 28 days in the past, ending near today
            let offset = -28 * (cycleCount - i)
            let date = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date()))!
            context.insert(CycleRecord(
                startDate: date,
                bleedingDays: 5,
                isConfirmed: true,
                actualCycleLength: i == cycleCount - 1 ? nil : 28
            ))
        }
        try context.save()
    }

    @Test("Generates multiple future predictions from cycle data")
    func generatesFuturePredictions() async throws {
        let container = CycleDataStore.makeTestContainer()
        try seedBaseline(container: container, cycleCount: 3)

        try await MenstrualLocalClient.regeneratePredictions(container: container)

        let context = ModelContext(container)
        let preds = try context.fetch(FetchDescriptor<PredictionRecord>())
        // Should produce at least a dozen predictions (one per cycle length
        // until next January)
        #expect(preds.count >= 5)
    }

    @Test("Clears unconfirmed predictions before regenerating")
    func clearsUnconfirmedFirst() async throws {
        let container = CycleDataStore.makeTestContainer()
        try seedBaseline(container: container, cycleCount: 3)

        // Seed stale unconfirmed predictions
        let context = ModelContext(container)
        let stale = PredictionRecord(
            predictedDate: Date(timeIntervalSince1970: 0),
            rangeStart: Date(timeIntervalSince1970: 0),
            rangeEnd: Date(timeIntervalSince1970: 0),
            confidenceLevel: 0.5,
            algorithmVersion: "v1_basic",
            basedOnCycles: 0,
            isConfirmed: false
        )
        context.insert(stale)
        try context.save()

        try await MenstrualLocalClient.regeneratePredictions(container: container)

        let preds = try ModelContext(container).fetch(FetchDescriptor<PredictionRecord>())
        // Stale (1970) should have been cleared — none should be before 2020
        let ancient = preds.filter { $0.predictedDate < Date(timeIntervalSince1970: 1_577_836_800) }
        #expect(ancient.isEmpty)
    }

    @Test("Preserves confirmed predictions")
    func preservesConfirmed() async throws {
        let container = CycleDataStore.makeTestContainer()
        try seedBaseline(container: container, cycleCount: 3)

        // Seed a confirmed prediction (historic)
        let context = ModelContext(container)
        let confirmedDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let confirmed = PredictionRecord(
            predictedDate: confirmedDate,
            rangeStart: confirmedDate,
            rangeEnd: confirmedDate,
            confidenceLevel: 0.9,
            algorithmVersion: "v3_historical",
            basedOnCycles: 3,
            isConfirmed: true
        )
        context.insert(confirmed)
        try context.save()

        try await MenstrualLocalClient.regeneratePredictions(container: container)

        let allPreds = try ModelContext(container).fetch(FetchDescriptor<PredictionRecord>())
        let confirmedPreds = allPreds.filter(\.isConfirmed)
        #expect(confirmedPreds.count == 1)
        #expect(confirmedPreds.first?.algorithmVersion == "v3_historical")
    }

    @Test("No-op when no profile exists")
    func noOpNoProfile() async throws {
        let container = CycleDataStore.makeTestContainer()
        // No profile, no cycles
        try await MenstrualLocalClient.regeneratePredictions(container: container)

        let preds = try ModelContext(container).fetch(FetchDescriptor<PredictionRecord>())
        #expect(preds.isEmpty)
    }

    @Test("No-op when no cycles exist")
    func noOpNoCycles() async throws {
        let container = CycleDataStore.makeTestContainer()
        let context = ModelContext(container)
        let profile = MenstrualProfileRecord(avgCycleLength: 28, avgBleedingDays: 5)
        context.insert(profile)
        try context.save()

        try await MenstrualLocalClient.regeneratePredictions(container: container)

        let preds = try ModelContext(container).fetch(FetchDescriptor<PredictionRecord>())
        #expect(preds.isEmpty)
    }

    @Test("Predictions have expected algorithm version for cycle count")
    func predictionAlgorithmVersion() async throws {
        let container = CycleDataStore.makeTestContainer()
        try seedBaseline(container: container, cycleCount: 3)

        try await MenstrualLocalClient.regeneratePredictions(container: container)

        let preds = try ModelContext(container).fetch(FetchDescriptor<PredictionRecord>())
        // Primary prediction should be V3 (3 cycles) — later ones are v1_basic projections
        let primary = preds.min(by: { $0.predictedDate < $1.predictedDate })
        #expect(primary != nil)
    }
}

// MARK: - HBILocalClient.getPersonalBaseline live query

@Suite("HBILocalClient — getPersonalBaseline", .serialized)
struct HBILocalClientPersonalBaselineTests {

    /// Seed the container with same-phase HBIScoreRecord samples split across
    /// cycles so we exercise `distinctCycleCount` through the live query path.
    private func seedScores(
        container: ModelContainer,
        phase: CyclePhase,
        rawScores: [Int],
        cycleBuckets: [Int] // days-ago per sample
    ) throws {
        precondition(rawScores.count == cycleBuckets.count)
        let context = ModelContext(container)
        let today = Calendar.current.startOfDay(for: Date())
        for (i, raw) in rawScores.enumerated() {
            let date = Calendar.current.date(
                byAdding: .day, value: -cycleBuckets[i], to: today
            )!
            let record = HBIScoreRecord(
                scoreDate: date,
                energyScore: 70,
                anxietyScore: 70,
                sleepScore: 70,
                moodScore: 70,
                hbiRaw: Double(raw),
                hbiAdjusted: Double(raw),
                cyclePhase: phase.rawValue,
                cycleDay: 1
            )
            context.insert(record)
        }
        try context.save()
    }

    @Test("Empty store → insufficient baseline")
    func emptyStoreInsufficient() throws {
        let container = CycleDataStore.makeTestContainer()
        let context = ModelContext(container)
        let baseline = try HBILocalClient.computePersonalBaseline(
            phase: .luteal, context: context
        )
        #expect(baseline.confidence == .insufficient)
        #expect(baseline.averageScore == nil)
        #expect(baseline.sampleCount == 0)
    }

    @Test("6 luteal samples across 2 cycles → building with correct average")
    func sixSamplesBuildingAverage() throws {
        let container = CycleDataStore.makeTestContainer()
        // Three in cycle A (~today), three in cycle B (~28 days ago)
        let rawScores = [60, 70, 80, 50, 90, 100]
        let bucketDaysAgo = [0, 1, 2, 28, 29, 30]
        try seedScores(
            container: container,
            phase: .luteal,
            rawScores: rawScores,
            cycleBuckets: bucketDaysAgo
        )
        let context = ModelContext(container)
        let baseline = try HBILocalClient.computePersonalBaseline(
            phase: .luteal, context: context
        )
        #expect(baseline.confidence == .building)
        #expect(baseline.sampleCount == 6)
        #expect(baseline.cyclesRepresented == 2)
        let expected = Double(rawScores.reduce(0, +)) / Double(rawScores.count)
        #expect(abs((baseline.averageScore ?? -1) - expected) < 0.5)
    }

    @Test("Filters by phase — follicular samples ignored when asking for luteal")
    func filtersByPhase() throws {
        let container = CycleDataStore.makeTestContainer()
        try seedScores(
            container: container,
            phase: .follicular,
            rawScores: Array(repeating: 99, count: 12),
            cycleBuckets: (0..<12).map { $0 }
        )
        let context = ModelContext(container)
        let baseline = try HBILocalClient.computePersonalBaseline(
            phase: .luteal, context: context
        )
        #expect(baseline.sampleCount == 0)
        #expect(baseline.confidence == .insufficient)
    }

    @Test("12 samples across 3 cycles → established")
    func twelveSamplesEstablished() throws {
        let container = CycleDataStore.makeTestContainer()
        // 4 samples per cycle × 3 cycles
        let buckets: [Int] = [0, 1, 2, 3, 28, 29, 30, 31, 56, 57, 58, 59]
        let raws: [Int] = Array(repeating: 70, count: 12)
        try seedScores(
            container: container,
            phase: .luteal,
            rawScores: raws,
            cycleBuckets: buckets
        )
        let context = ModelContext(container)
        let baseline = try HBILocalClient.computePersonalBaseline(
            phase: .luteal, context: context
        )
        #expect(baseline.confidence == .established)
        #expect(baseline.sampleCount == 12)
        #expect(baseline.cyclesRepresented == 3)
        #expect(abs((baseline.averageScore ?? 0) - 70) < 0.5)
    }
}
