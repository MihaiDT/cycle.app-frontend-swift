import Foundation
import SwiftData

// MARK: - Read-Only Queries

extension MenstrualLocalClient {
    // MARK: getStatus

    static func liveGetStatus() -> @Sendable () async throws -> MenstrualStatusResponse {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)

            // Deduplicate cycle records (cleanup stale duplicates from repeated edits)
            try deduplicateCycles(context: context)

            let profile = try fetchProfile(context: context)
            let latestCycle = try fetchLatestCycle(context: context)
            let prediction = try fetchActivePrediction(context: context)
            let today = Calendar.current.startOfDay(for: Date())

            let avgCycleLength = profile?.avgCycleLength ?? 28
            let avgBleedingDays = profile?.avgBleedingDays ?? 5

            // Current cycle info
            let cycleDay: Int
            let phase: String
            let isLate: Bool
            let daysLate: Int
            if let lc = latestCycle {
                cycleDay = CycleMath.cycleDay(cycleStart: lc.startDate, date: today)
                if cycleDay > avgCycleLength {
                    // Period is late — past expected cycle length
                    phase = "late"
                    isLate = true
                    daysLate = cycleDay - avgCycleLength
                } else {
                    phase = CycleMath.cyclePhase(
                        cycleDay: cycleDay, cycleLength: avgCycleLength,
                        bleedingDays: lc.bleedingDays ?? avgBleedingDays
                    ).rawValue
                    isLate = false
                    daysLate = 0
                }
            } else {
                cycleDay = 1
                phase = "unknown"
                isLate = false
                daysLate = 0
            }

            let cycleInfo = CycleInfo(
                startDate: latestCycle?.startDate ?? today,
                cycleDay: cycleDay,
                phase: isLate ? "late" : phase,
                bleedingDays: latestCycle?.bleedingDays ?? avgBleedingDays
            )

            let profileInfo = MenstrualProfileInfo(
                avgCycleLength: avgCycleLength,
                cycleRegularity: profile?.cycleRegularity ?? "unknown",
                trackingSince: profile?.createdAt ?? today
            )

            // Prediction
            var predictionInfo: PredictionInfo?
            var fertileWindowInfo: FertileWindowInfo?

            if let pred = prediction {
                let daysUntil = CycleMath.daysBetween(today, pred.predictedDate)
                let predIsLate = daysUntil < 0

                predictionInfo = PredictionInfo(
                    predictedDate: pred.predictedDate,
                    daysUntil: max(0, daysUntil),
                    confidenceScore: pred.confidenceLevel,
                    predictionRange: DateRangeInfo(start: pred.rangeStart, end: pred.rangeEnd),
                    isLate: isLate || predIsLate,
                    daysLate: isLate ? daysLate : (predIsLate ? abs(daysUntil) : 0)
                )

                if let fStart = pred.fertileWindowStart,
                   let fEnd = pred.fertileWindowEnd,
                   let ovDate = pred.ovulationDate
                {
                    let daysUntilPeak = CycleMath.daysBetween(today, ovDate)
                    fertileWindowInfo = FertileWindowInfo(
                        start: fStart, peak: ovDate, end: fEnd,
                        isActive: today >= fStart && today <= fEnd,
                        daysUntilPeak: max(0, daysUntilPeak)
                    )
                }
            }

            return MenstrualStatusResponse(
                currentCycle: cycleInfo,
                profile: profileInfo,
                nextPrediction: predictionInfo,
                fertileWindow: fertileWindowInfo,
                hasCycleData: latestCycle != nil
            )
        }
    }

    // MARK: getCalendar

    static func liveGetCalendar() -> @Sendable (Date, Date) async throws -> MenstrualCalendarResponse {
        return { startDate, endDate in
            let container = CycleDataStore.shared
            let context = ModelContext(container)

            let start = Calendar.current.startOfDay(for: startDate)
            let end = Calendar.current.startOfDay(for: endDate)

            // Fetch cycles in range (extend start by 50 days for bleeding overlap)
            let cycleRangeStart = CycleMath.addDays(start, -50)
            let cycleDescriptor = FetchDescriptor<CycleRecord>(
                predicate: #Predicate<CycleRecord> { cycle in
                    cycle.startDate >= cycleRangeStart && cycle.startDate <= end
                },
                sortBy: [SortDescriptor(\.startDate)]
            )
            let cycles = try context.fetch(cycleDescriptor)

            // Fetch predictions in range
            let predDescriptor = FetchDescriptor<PredictionRecord>(
                predicate: #Predicate<PredictionRecord> { pred in
                    pred.predictedDate >= start && pred.predictedDate <= end
                },
                sortBy: [SortDescriptor(\.predictedDate)]
            )
            let predictions = try context.fetch(predDescriptor)

            // Fetch symptoms in range
            let symptomDescriptor = FetchDescriptor<SymptomRecord>(
                predicate: #Predicate<SymptomRecord> { sym in
                    sym.symptomDate >= start && sym.symptomDate <= end
                }
            )
            let symptoms = try context.fetch(symptomDescriptor)

            var entries: [MenstrualCalendarEntry] = []

            // Period entries + retroactive fertile window for confirmed cycles
            // Sort by createdAt desc so we always pick the latest
            // profile if multiple records ended up in storage. An
            // unsorted fetch can return the original onboarding
            // profile with stale defaults, hiding manual overrides
            // saved later.
            let profileDescCal = FetchDescriptor<MenstrualProfileRecord>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let latestProfile = try? context.fetch(profileDescCal).first
            let avgCycleLen = latestProfile?.avgCycleLength ?? 28
            let showOvulation = latestProfile?.showOvulation ?? true
            let showFertile = latestProfile?.showFertileWindow ?? true

            // A CycleRecord with a startDate in the future is an
            // anomaly (confirmPeriod rejects future dates, so this can
            // only happen via legacy data or migration bugs). Treating
            // those as period bands clobbers the predicted spacing —
            // skip them. Future periods are the predictor's job.
            let todayCutoff = CycleMath.startOfDay(Date())
            let pastCycles = cycles.filter { $0.startDate <= todayCutoff }
            // The latest confirmed cycle's retroactive fertile window
            // overlaps the upcoming prediction's fertile window (both
            // cover the current cycle). We skip the retroactive entry
            // for the last past cycle so the user doesn't see two
            // "Fertile" labels separated by a day's worth of anchor
            // drift between `simpleFertileWindow(cycleStart:)` and
            // the live-recomputed `predicted - 14` ovulation peak.
            let lastPastCycleStart = pastCycles
                .map { CycleMath.startOfDay($0.startDate) }
                .max()

            for cycle in pastCycles {
                let bd = cycle.bleedingDays ?? 5
                let cl = cycle.actualCycleLength ?? avgCycleLen
                let isLastPast = CycleMath.startOfDay(cycle.startDate) == lastPastCycleStart

                // Period days
                for dayOffset in 0..<bd {
                    let date = CycleMath.addDays(cycle.startDate, dayOffset)
                    if date >= start, date <= end {
                        entries.append(MenstrualCalendarEntry(
                            date: date, type: "period",
                            label: cycle.isConfirmed ? "Period" : "Projected period"
                        ))
                    }
                }

                // Retroactive fertile window + ovulation for confirmed cycles
                if cycle.isConfirmed, !isLastPast {
                    let fertile = CycleMath.simpleFertileWindow(
                        cycleStart: cycle.startDate, cycleLength: cl
                    )

                    // Ovulation peak marker — gated on showOvulation
                    // so the user can hide the peak gradient point
                    // independently of the fertile band.
                    if showOvulation, fertile.peak >= start, fertile.peak <= end {
                        entries.append(MenstrualCalendarEntry(
                            date: fertile.peak, type: "ovulation",
                            label: "Ovulation", fertilityLevel: "peak"
                        ))
                    }

                    // Fertile days — entries are always emitted so
                    // the renderer knows the band's full span. The
                    // show/hide gate runs in the phase-pill layer:
                    // ON colors the band, OFF blanks the same days.
                    var current = fertile.start
                    while current <= fertile.end {
                        if current >= start, current <= end {
                            let diff = abs(CycleMath.daysBetween(current, fertile.peak))
                            let level: String = switch diff {
                            case 0: "peak"
                            case 1: "high"
                            case 2: "medium"
                            default: "low"
                            }
                            entries.append(MenstrualCalendarEntry(
                                date: current, type: "fertile",
                                label: "Fertile window", fertilityLevel: level
                            ))
                        }
                        current = CycleMath.addDays(current, 1)
                    }
                }
            }

            // Predicted period entries
            let profileDesc = FetchDescriptor<MenstrualProfileRecord>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let predictionProfile = try? context.fetch(profileDesc).first
            let bleedingDays = predictionProfile?.avgBleedingDays ?? 5
            for pred in predictions where !pred.isConfirmed {
                for dayOffset in 0..<bleedingDays {
                    let date = CycleMath.addDays(pred.predictedDate, dayOffset)
                    if date >= start, date <= end {
                        entries.append(MenstrualCalendarEntry(
                            date: date, type: "predicted_period",
                            label: "Predicted period"
                        ))
                    }
                }

                // Fertile window — recalculated live from the
                // predicted period start instead of reading
                // `pred.fertileWindowStart/End`. The stored values
                // come from `simpleFertileWindow(cycleStart:
                // currentStart, ...)` in `MenstrualLocalClient+
                // Predictions` where `currentStart` is the NEXT
                // period start — that anchor produces a window
                // sitting inside the cycle AFTER the prediction,
                // not the cycle leading up to it. Recomputing here
                // anchors the window on the cycle the user is
                // actually in: peak = predicted - 14, start =
                // peak - 5, end = peak.
                let ovPeak = CycleMath.addDays(pred.predictedDate, -14)
                let fStart = CycleMath.addDays(ovPeak, -5)
                let fEnd = ovPeak
                var current = fStart
                while current <= fEnd {
                    if current >= start, current <= end {
                        let diff = abs(CycleMath.daysBetween(current, ovPeak))
                        let level: String = switch diff {
                        case 0: "peak"
                        case 1: "high"
                        case 2: "medium"
                        default: "low"
                        }
                        entries.append(MenstrualCalendarEntry(
                            date: current, type: "fertile",
                            label: "Fertile window", fertilityLevel: level
                        ))
                    }
                    current = CycleMath.addDays(current, 1)
                }

                if showOvulation, ovPeak >= start, ovPeak <= end {
                    entries.append(MenstrualCalendarEntry(
                        date: ovPeak, type: "ovulation",
                        label: "Ovulation", fertilityLevel: "peak"
                    ))
                }
            }

            // Symptom entries
            for symptom in symptoms {
                entries.append(MenstrualCalendarEntry(
                    date: symptom.symptomDate, type: "symptom",
                    label: symptom.symptomType
                ))
            }

            return MenstrualCalendarResponse(
                startDate: start,
                endDate: end,
                entries: entries,
                effectiveBleedingDays: bleedingDays,
                showOvulation: showOvulation,
                showFertileWindow: showFertile
            )
        }
    }

    // MARK: getCycleStats

    static func liveGetCycleStats() -> @Sendable () async throws -> CycleStatsDetailedResponse {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)

            let profile = try fetchProfile(context: context)
            let cycles = try fetchAllCycles(context: context)

            // Extract cycle lengths
            var lengths: [Int] = []
            for (i, cycle) in cycles.enumerated() {
                if let len = cycle.actualCycleLength {
                    lengths.append(len)
                } else if i + 1 < cycles.count {
                    let gap = CycleMath.cycleLength(
                        periodStart1: cycles[i + 1].startDate,
                        periodStart2: cycle.startDate
                    )
                    if gap >= 18, gap <= 50 { lengths.append(gap) }
                }
            }

            let history = cycles.prefix(12).map { cycle in
                CycleHistoryPoint(
                    startDate: cycle.startDate,
                    length: cycle.actualCycleLength ?? (profile?.avgCycleLength ?? 28),
                    bleeding: cycle.bleedingDays ?? (profile?.avgBleedingDays ?? 5)
                )
            }

            let avg = lengths.isEmpty ? Double(profile?.avgCycleLength ?? 28) : CycleMath.mean(lengths)
            let sd = CycleMath.stdDev(lengths)
            let trend = CycleMath.detectTrend(lengths)
            let trendStr: String = trend > 0 ? "longer" : (trend < 0 ? "shorter" : "stable")

            // Current cycle context
            let today = Calendar.current.startOfDay(for: Date())
            let latestCycle = cycles.first
            let currentDay = latestCycle.map { CycleMath.cycleDay(cycleStart: $0.startDate, date: today) } ?? 1
            let expectedLength = profile?.avgCycleLength ?? 28
            let delay = currentDay - expectedLength
            let delayContext: String
            switch delay {
            case ...0: delayContext = "within_range"
            case 1...3: delayContext = "slightly_outside"
            default: delayContext = "significantly_outside"
            }

            return CycleStatsDetailedResponse(
                cycleLength: CycleLengthStats(
                    average: avg,
                    min: lengths.min() ?? Int(avg),
                    max: lengths.max() ?? Int(avg),
                    stdDev: sd,
                    history: Array(history),
                    trend: trendStr
                ),
                currentCycle: CurrentCycleStats(
                    day: currentDay,
                    cycleLength: expectedLength,
                    delayContext: delayContext,
                    delayDays: max(0, delay)
                ),
                totalTracked: cycles.count,
                trackingSince: profile?.createdAt
            )
        }
    }

    // MARK: unviewedRecapMonth

    static func liveUnviewedRecapMonth() -> @Sendable () async throws -> String? {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let cycles = try context.fetch(FetchDescriptor<CycleRecord>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            ))
            // Need at least 2 cycles (current + past) for a recap to exist
            guard cycles.count >= 2 else { return nil }
            let keyFormatter = DateFormatter()
            keyFormatter.dateFormat = "yyyy-MM-dd"
            keyFormatter.timeZone = TimeZone(identifier: "UTC")
            keyFormatter.locale = Locale(identifier: "en_US_POSIX")
            // All past cycles (except the most recent = current) can have recaps
            let localCal = Calendar.current
            let pastCycleKeys = Set(cycles.dropFirst().map {
                keyFormatter.string(from: localCal.startOfDay(for: $0.startDate))
            })

            let allRecaps = (try? context.fetch(FetchDescriptor<CycleRecapRecord>())) ?? []
            let viewedKeys = Set(UserDefaults.standard.stringArray(forKey: "ViewedRecapCycleKeys") ?? [])
            // Only match recaps to actual past cycles — ignore orphaned CloudKit records
            let unviewed = allRecaps
                .filter { pastCycleKeys.contains($0.cycleKey) && !viewedKeys.contains($0.cycleKey) }
                .sorted { $0.createdAt > $1.createdAt }
            guard let record = unviewed.first else { return nil }
            guard let date = keyFormatter.date(from: record.cycleKey) else { return nil }
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMMM"
            return monthFormatter.string(from: date)
        }
    }

    // MARK: markAllRecapsViewed

    static func liveMarkAllRecapsViewed() -> @Sendable () async throws -> Void {
        return {
            let container = CycleDataStore.shared
            let context = ModelContext(container)
            let allRecaps = (try? context.fetch(FetchDescriptor<CycleRecapRecord>())) ?? []
            let keys = allRecaps.map(\.cycleKey)
            var viewed = Set(UserDefaults.standard.stringArray(forKey: "ViewedRecapCycleKeys") ?? [])
            for key in keys { viewed.insert(key) }
            UserDefaults.standard.set(Array(viewed), forKey: "ViewedRecapCycleKeys")
        }
    }
}
