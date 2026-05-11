import Foundation
import SwiftData

// MARK: - Pattern Detection (Phase 2)
//
// Live `detectPatterns` implementation: reads cycles + symptoms
// from SwiftData over a 12-month lookback window, builds the
// detector's value-type snapshots, and runs `PatternDetector.detect`
// on a background task. The reducer dispatches the result back to
// the main actor.

extension MenstrualLocalClient {

    static func liveRecentSymptoms() -> @Sendable (Int) async throws -> [RecentSymptomEntry] {
        return { daysBack in
            try await Task.detached(priority: .userInitiated) {
                let container = CycleDataStore.shared
                let context = ModelContext(container)

                let calendar = Calendar.current
                let now = Date()
                let cutoff = calendar.date(byAdding: .day, value: -daysBack, to: now) ?? now

                let descriptor = FetchDescriptor<SymptomRecord>(
                    predicate: #Predicate { $0.symptomDate >= cutoff },
                    sortBy: [SortDescriptor(\.symptomDate, order: .reverse)]
                )
                let records = try context.fetch(descriptor)

                return records.map { record in
                    RecentSymptomEntry(
                        id: "\(record.symptomDate.timeIntervalSince1970).\(record.symptomType)",
                        symptomTypeRaw: record.symptomType,
                        date: record.symptomDate
                    )
                }
            }.value
        }
    }

    static func liveDetectPatterns() -> @Sendable () async throws -> [PatternDetector.RawPatternSignal] {
        return {
            try await Task.detached(priority: .userInitiated) {
                let container = CycleDataStore.shared
                let context = ModelContext(container)

                // Lookback window: last 12 months from today.
                let calendar = Calendar.current
                let now = Date()
                let lookbackStart = calendar.date(byAdding: .month, value: -12, to: now) ?? now

                let profile = try fetchProfile(context: context)
                let avgBleedingDays = profile?.avgBleedingDays ?? 5
                let avgCycleLength = profile?.avgCycleLength ?? 28

                // Cycles in window, ordered by startDate descending.
                var cycleDescriptor = FetchDescriptor<CycleRecord>(
                    predicate: #Predicate { $0.startDate >= lookbackStart },
                    sortBy: [SortDescriptor(\.startDate, order: .reverse)]
                )
                cycleDescriptor.fetchLimit = 50
                let cycles = try context.fetch(cycleDescriptor)

                // Symptoms in window — fetched in one query so we
                // don't N+1 per cycle.
                let symptomDescriptor = FetchDescriptor<SymptomRecord>(
                    predicate: #Predicate { $0.symptomDate >= lookbackStart }
                )
                let symptoms = try context.fetch(symptomDescriptor)

                // Build cycle snapshots. Sorted descending so we can
                // assign each symptom to the most recent cycle whose
                // startDate <= symptomDate.
                let cycleSnapshots: [PatternDetector.CycleSnapshot] = cycles.map {
                    // CycleRecord has no `id` field — each cycle is
                    // uniquely identified by its `startDate` (cycles
                    // don't overlap), so the timestamp is stable + safe
                    // as a snapshot identifier.
                    PatternDetector.CycleSnapshot(
                        id: $0.startDate.timeIntervalSince1970.description,
                        cycleLength: $0.actualCycleLength ?? avgCycleLength,
                        bleedingDays: $0.bleedingDays ?? avgBleedingDays
                    )
                }

                // Map symptoms → snapshots, dropping logs that fall
                // outside any known cycle window or are missing
                // `cycleDay`.
                let symptomSnapshots: [PatternDetector.SymptomSnapshot] = symptoms.compactMap { record -> PatternDetector.SymptomSnapshot? in
                    guard let cycleDay = record.cycleDay, cycleDay > 0 else { return nil }

                    // Find the cycle this log belongs to: the most
                    // recent cycle whose startDate <= symptomDate.
                    guard let cycle = cycles.first(where: { $0.startDate <= record.symptomDate }) else {
                        return nil
                    }

                    return PatternDetector.SymptomSnapshot(
                        cycleID: cycle.startDate.timeIntervalSince1970.description,
                        symptomTypeRaw: record.symptomType,
                        cycleDay: cycleDay
                    )
                }

                return PatternDetector.detect(
                    cycles: cycleSnapshots,
                    symptoms: symptomSnapshots,
                    symptomFilter: { rawType in
                        // Drop neutral / positive entries that
                        // shouldn't surface as a "pattern" — the
                        // user logging "all good" three menstrual
                        // phases in a row isn't a body pattern.
                        !PatternDetector.neutralSymptoms.contains(rawType)
                    }
                )
            }.value
        }
    }

    // MARK: - Pattern Metrics (Phase 2.5)
    //
    // Severity-history rollup for one detected pattern. Reads the
    // same cycles + symptoms as `liveDetectPatterns`, then groups by
    // cycle and computes per-cycle averages restricted to symptoms
    // logged in the pattern's phase.
    //
    // Phase resolution uses `CycleMath.cyclePhase(...)` against each
    // log's `cycleDay`, the cycle's `actualCycleLength` (or profile
    // average), and bleeding length. This matches the resolver the
    // detector uses, so a log surfaced as part of the pattern in
    // `detectPatterns` will be counted here under the same phase.
    static func livePatternMetrics() -> @Sendable (String, CyclePhase) async throws -> PatternMetrics {
        return { symptomTypeRaw, phase in
            try await Task.detached(priority: .userInitiated) {
                let container = CycleDataStore.shared
                let context = ModelContext(container)

                let calendar = Calendar.current
                let now = Date()
                let lookbackStart = calendar.date(byAdding: .month, value: -12, to: now) ?? now

                let profile = try fetchProfile(context: context)
                let avgBleedingDays = profile?.avgBleedingDays ?? 5
                let avgCycleLength = profile?.avgCycleLength ?? 28

                // Cycles in window, oldest first so cycleIndex maps
                // to chronological order.
                let cycleDescriptor = FetchDescriptor<CycleRecord>(
                    predicate: #Predicate { $0.startDate >= lookbackStart },
                    sortBy: [SortDescriptor(\.startDate, order: .forward)]
                )
                let cycles = try context.fetch(cycleDescriptor)
                guard !cycles.isEmpty else {
                    return PatternMetrics.empty(window: lookbackStart...now)
                }

                // Symptoms matching this type in window — single fetch.
                let symptomDescriptor = FetchDescriptor<SymptomRecord>(
                    predicate: #Predicate {
                        $0.symptomType == symptomTypeRaw &&
                        $0.symptomDate >= lookbackStart
                    },
                    sortBy: [SortDescriptor(\.symptomDate, order: .forward)]
                )
                let symptoms = try context.fetch(symptomDescriptor)
                guard !symptoms.isEmpty else {
                    return PatternMetrics.empty(window: lookbackStart...now)
                }

                let targetPhase: CyclePhaseResult? = mapPhase(phase)

                // Group symptoms by their owning cycle (most recent
                // cycle whose startDate <= log date). Filter to logs
                // inside the target phase using CycleMath. Capture
                // raw per-day logs in parallel so the heatmap viz
                // doesn't need a second query.
                struct CycleAcc {
                    let cycle: CycleRecord
                    let cycleIndex: Int
                    var severities: [Double] = []
                    var lastDate: Date = .distantPast
                }

                // Pre-build cycle accumulators with chronological
                // index. cycles is already oldest-first.
                var accumulators: [CycleAcc] = cycles.enumerated().map { idx, cycle in
                    CycleAcc(cycle: cycle, cycleIndex: idx + 1)
                }
                var dayLogs: [PatternDayLog] = []

                for record in symptoms {
                    guard let cycleDay = record.cycleDay, cycleDay > 0 else { continue }
                    // Find owning cycle — last in oldest-first list
                    // whose startDate <= record.symptomDate.
                    guard let accIndex = accumulators.lastIndex(where: { $0.cycle.startDate <= record.symptomDate }) else {
                        continue
                    }
                    let acc = accumulators[accIndex]
                    let cycleLength = acc.cycle.actualCycleLength ?? avgCycleLength
                    let bleeding = acc.cycle.bleedingDays ?? avgBleedingDays

                    let logPhase = CycleMath.cyclePhase(
                        cycleDay: cycleDay,
                        cycleLength: cycleLength,
                        bleedingDays: bleeding
                    )
                    guard let target = targetPhase, logPhase == target else { continue }

                    accumulators[accIndex].severities.append(Double(record.severity))
                    if record.symptomDate > accumulators[accIndex].lastDate {
                        accumulators[accIndex].lastDate = record.symptomDate
                    }

                    // Capture raw per-day log for the heatmap. Stable
                    // id = owning cycle stamp + log timestamp + day so
                    // re-fetching produces identical identifiers.
                    let logID = "\(acc.cycle.startDate.timeIntervalSince1970).\(record.symptomDate.timeIntervalSince1970).\(cycleDay)"
                    dayLogs.append(PatternDayLog(
                        id: logID,
                        cycleStartDate: acc.cycle.startDate,
                        cycleDay: cycleDay,
                        severity: Double(record.severity),
                        logDate: record.symptomDate
                    ))
                }

                // Build cycle points — only cycles where the pattern
                // had at least one log.
                let points: [PatternCyclePoint] = accumulators.compactMap { acc in
                    guard !acc.severities.isEmpty else { return nil }
                    let mean = acc.severities.reduce(0, +) / Double(acc.severities.count)
                    let peak = acc.severities.max() ?? 0
                    return PatternCyclePoint(
                        id: acc.cycle.startDate.timeIntervalSince1970.description,
                        cycleIndex: acc.cycleIndex,
                        cycleStartDate: acc.cycle.startDate,
                        averageSeverity: mean,
                        peakSeverity: peak,
                        logCount: acc.severities.count
                    )
                }

                guard !points.isEmpty else {
                    return PatternMetrics.empty(window: lookbackStart...now)
                }

                // Re-index sequentially across the kept cycles so the
                // cycle-axis labels read 1, 2, 3 even when the user
                // skipped a cycle in between.
                let indexed = points.enumerated().map { idx, p in
                    PatternCyclePoint(
                        id: p.id,
                        cycleIndex: idx + 1,
                        cycleStartDate: p.cycleStartDate,
                        averageSeverity: p.averageSeverity,
                        peakSeverity: p.peakSeverity,
                        logCount: p.logCount
                    )
                }

                let avg = indexed.map(\.averageSeverity).reduce(0, +) / Double(indexed.count)
                let peak = indexed.map(\.peakSeverity).max() ?? 0
                let peakPoint = indexed.max(by: { $0.peakSeverity < $1.peakSeverity }) ?? indexed[0]
                let lastSeen = accumulators.map(\.lastDate).max() ?? now

                let trend: PatternTrend
                if indexed.count < 2 {
                    trend = .justAppearing
                } else if let first = indexed.first, let last = indexed.last {
                    let delta = last.averageSeverity - first.averageSeverity
                    if delta > 0.4 { trend = .strengthening }
                    else if delta < -0.4 { trend = .easing }
                    else { trend = .persisting }
                } else {
                    trend = .persisting
                }

                // Most active day — cycle day that hits the most
                // distinct cycles. Ties resolved by lower day so the
                // earliest day in the cycle wins ("hits hardest").
                let dayCycleCounts: [Int: Set<Date>] = dayLogs.reduce(into: [:]) { acc, log in
                    acc[log.cycleDay, default: []].insert(log.cycleStartDate)
                }
                let topActive = dayCycleCounts.max { lhs, rhs in
                    if lhs.value.count != rhs.value.count {
                        return lhs.value.count < rhs.value.count
                    }
                    return lhs.key > rhs.key
                }
                let mostActiveDay = topActive?.key
                let mostActiveDayCycleCount = topActive?.value.count ?? 0

                // Avg distinct days affected per cycle that has any
                // logs for this pattern (NOT all cycles in window —
                // an unaffected cycle distorts the mean toward zero).
                let perCycleDistinctDays: [Date: Set<Int>] = dayLogs.reduce(into: [:]) { acc, log in
                    acc[log.cycleStartDate, default: []].insert(log.cycleDay)
                }
                let avgDaysAffected: Double = perCycleDistinctDays.isEmpty
                    ? 0
                    : Double(perCycleDistinctDays.values.map(\.count).reduce(0, +))
                        / Double(perCycleDistinctDays.count)

                // Co-occurring symptom — fetch every symptom in the
                // window once, attribute each to its owning cycle,
                // count the distinct affected cycles each non-target,
                // non-neutral type appears in. Top one wins. Same
                // neutral denylist as `PatternDetector.neutralSymptoms`.
                let neutralSymptoms: Set<String> = [
                    "all_good", "calm", "happy", "energetic", "focused",
                ]
                let affectedCycleStarts = Set(indexed.map(\.cycleStartDate))
                let allSymptomDescriptor = FetchDescriptor<SymptomRecord>(
                    predicate: #Predicate {
                        $0.symptomDate >= lookbackStart
                    },
                    sortBy: [SortDescriptor(\.symptomDate, order: .forward)]
                )
                let allSymptoms = (try? context.fetch(allSymptomDescriptor)) ?? []
                var perCycleTypes: [Date: Set<String>] = [:]
                for symptom in allSymptoms {
                    guard symptom.symptomType != symptomTypeRaw else { continue }
                    guard !neutralSymptoms.contains(symptom.symptomType) else { continue }
                    guard let owning = cycles.last(where: { $0.startDate <= symptom.symptomDate }) else {
                        continue
                    }
                    guard affectedCycleStarts.contains(owning.startDate) else { continue }
                    perCycleTypes[owning.startDate, default: []].insert(symptom.symptomType)
                }
                var coOccurrenceCounts: [String: Int] = [:]
                for (_, types) in perCycleTypes {
                    for type in types {
                        coOccurrenceCounts[type, default: 0] += 1
                    }
                }
                let topCoOccurring = coOccurrenceCounts.max(by: { $0.value < $1.value })
                let coOccurringSymptomRaw = topCoOccurring?.key
                let coOccurringSymptomCount = topCoOccurring?.value ?? 0

                // Next predicted window — anchor on the latest cycle's
                // start + the user's avg cycle length, then offset by
                // the observed [minDay, maxDay] from this pattern's
                // logs. Uses the dayLogs we already collected — no
                // need to thread `pattern.dayRange` through.
                let cycleDays = dayLogs.map(\.cycleDay)
                let nextPredictedWindow: ClosedRange<Date>?
                if let latestCycle = cycles.last,
                   let minDay = cycleDays.min(),
                   let maxDay = cycleDays.max(),
                   let nextStart = calendar.date(
                       byAdding: .day,
                       value: avgCycleLength,
                       to: latestCycle.startDate
                   ),
                   let windowStart = calendar.date(byAdding: .day, value: minDay - 1, to: nextStart),
                   let windowEnd = calendar.date(byAdding: .day, value: maxDay - 1, to: nextStart),
                   windowStart <= windowEnd {
                    nextPredictedWindow = windowStart...windowEnd
                } else {
                    nextPredictedWindow = nil
                }

                return PatternMetrics(
                    cycles: indexed,
                    dayLogs: dayLogs,
                    averageSeverity: avg,
                    peakSeverity: peak,
                    peakDate: peakPoint.cycleStartDate,
                    lastSeen: lastSeen,
                    lookbackStart: lookbackStart,
                    lookbackEnd: now,
                    trend: trend,
                    mostActiveDay: mostActiveDay,
                    mostActiveDayCycleCount: mostActiveDayCycleCount,
                    avgDaysAffected: avgDaysAffected,
                    coOccurringSymptomRaw: coOccurringSymptomRaw,
                    coOccurringSymptomCount: coOccurringSymptomCount,
                    nextPredictedWindow: nextPredictedWindow
                )
            }.value
        }
    }

    /// Translate the app-level `CyclePhase` into the engine's
    /// `CyclePhaseResult` so the resolver in `CycleMath.cyclePhase`
    /// can compare against it.
    private static func mapPhase(_ phase: CyclePhase) -> CyclePhaseResult? {
        switch phase {
        case .menstrual:  return .menstrual
        case .follicular: return .follicular
        case .ovulatory:  return .ovulatory
        case .luteal:     return .luteal
        case .late:       return .late
        }
    }
}
