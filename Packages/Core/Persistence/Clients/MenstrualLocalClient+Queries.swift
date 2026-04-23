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
            let profileDescCal = FetchDescriptor<MenstrualProfileRecord>()
            let avgCycleLen = (try? context.fetch(profileDescCal).first?.avgCycleLength) ?? 28

            for cycle in cycles {
                let bd = cycle.bleedingDays ?? 5
                let cl = cycle.actualCycleLength ?? avgCycleLen

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
                if cycle.isConfirmed {
                    let fertile = CycleMath.simpleFertileWindow(
                        cycleStart: cycle.startDate, cycleLength: cl
                    )

                    // Ovulation
                    if fertile.peak >= start, fertile.peak <= end {
                        entries.append(MenstrualCalendarEntry(
                            date: fertile.peak, type: "ovulation",
                            label: "Ovulation", fertilityLevel: "peak"
                        ))
                    }

                    // Fertile days
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
            let profileDesc = FetchDescriptor<MenstrualProfileRecord>()
            let bleedingDays = (try? context.fetch(profileDesc).first?.avgBleedingDays) ?? 5
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

                // Fertile window
                if let fStart = pred.fertileWindowStart,
                   let fEnd = pred.fertileWindowEnd
                {
                    var current = fStart
                    while current <= fEnd {
                        if current >= start, current <= end {
                            let level: String
                            if let ovDate = pred.ovulationDate {
                                let diff = abs(CycleMath.daysBetween(current, ovDate))
                                switch diff {
                                case 0: level = "peak"
                                case 1: level = "high"
                                case 2: level = "medium"
                                default: level = "low"
                                }
                            } else {
                                level = "low"
                            }
                            entries.append(MenstrualCalendarEntry(
                                date: current, type: "fertile",
                                label: "Fertile window", fertilityLevel: level
                            ))
                        }
                        current = CycleMath.addDays(current, 1)
                    }
                }

                if let ovDate = pred.ovulationDate, ovDate >= start, ovDate <= end {
                    entries.append(MenstrualCalendarEntry(
                        date: ovDate, type: "ovulation",
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
                startDate: start, endDate: end, entries: entries
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
