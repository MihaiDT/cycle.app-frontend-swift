import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - Menstrual Local Client

/// On-device menstrual tracking and prediction.
/// Replaces MenstrualClient (network) — same return types for minimal feature refactoring.
public struct MenstrualLocalClient: Sendable {
    /// Current cycle status, prediction, and fertile window.
    public var getStatus: @Sendable () async throws -> MenstrualStatusResponse

    /// Calendar entries (periods, fertile days, ovulation, symptoms) for a date range.
    public var getCalendar: @Sendable (Date, Date) async throws -> MenstrualCalendarResponse

    /// Detailed cycle statistics (averages, trend, history).
    public var getCycleStats: @Sendable () async throws -> CycleStatsDetailedResponse

    /// TEMP: Delete all cycles, predictions, and symptoms. Used during re-onboarding.
    public var resetAllCycleData: @Sendable () async throws -> Void

    /// Confirm a new period (create/update cycle record + regenerate prediction).
    /// Pass `skipPredictions: true` when confirming in a batch — call `generatePrediction` once at the end.
    public var confirmPeriod: @Sendable (Date, Int, String?, Bool) async throws -> Void

    /// Remove period days (delete cycle records containing those dates).
    public var removePeriodDays: @Sendable ([Date]) async throws -> Void

    /// Aggregated journey data (cycles, predictions, profile) for the journey engine.
    public var getJourneyData: @Sendable () async throws -> JourneyData

    /// Log a symptom for a specific date.
    public var logSymptom: @Sendable (Date, String, Int, String?) async throws -> Void

    /// Get symptoms logged for a specific date.
    public var getSymptoms: @Sendable (Date) async throws -> [MenstrualSymptomResponse]

    /// Regenerate predictions from current cycle data.
    public var generatePrediction: @Sendable () async throws -> Void

    /// Get or create the menstrual profile (for onboarding + ongoing).
    public var getProfile: @Sendable () async throws -> MenstrualProfileInfo?

    /// Save/update the menstrual profile.
    public var saveProfile: @Sendable (MenstrualProfileInfo, [String], String?, Bool, String?) async throws -> Void

    /// Returns the month name of the most recent unviewed recap, or nil.
    public var unviewedRecapMonth: @Sendable () async throws -> String?

    /// Marks all unviewed recaps as viewed.
    public var markAllRecapsViewed: @Sendable () async throws -> Void
}

// MARK: - Dependency

extension MenstrualLocalClient: DependencyKey {
    public static let liveValue = MenstrualLocalClient.live()
    public static let testValue = MenstrualLocalClient.mock()
    public static let previewValue = MenstrualLocalClient.mock()
}

extension DependencyValues {
    public var menstrualLocal: MenstrualLocalClient {
        get { self[MenstrualLocalClient.self] }
        set { self[MenstrualLocalClient.self] = newValue }
    }
}

// MARK: - Live

extension MenstrualLocalClient {
    static func live() -> Self {
        MenstrualLocalClient(
            // MARK: getStatus
            getStatus: {
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
            },

            // MARK: getCalendar
            getCalendar: { startDate, endDate in
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
            },

            // MARK: getCycleStats
            getCycleStats: {
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
            },

            // MARK: resetAllCycleData (TEMP)
            resetAllCycleData: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                for record in try context.fetch(FetchDescriptor<CycleRecord>()) { context.delete(record) }
                for record in try context.fetch(FetchDescriptor<PredictionRecord>()) { context.delete(record) }
                for record in try context.fetch(FetchDescriptor<SymptomRecord>()) { context.delete(record) }
                for record in try context.fetch(FetchDescriptor<MenstrualProfileRecord>()) { context.delete(record) }
                for record in try context.fetch(FetchDescriptor<DailyCardRecord>()) { context.delete(record) }
                for record in try context.fetch(FetchDescriptor<CycleRecapRecord>()) { context.delete(record) }
                try context.save()
                UserDefaults.standard.removeObject(forKey: "ViewedRecapCycleKeys")
                UserDefaults.standard.set(Date(), forKey: "CycleDataResetDate")
            },

            // MARK: confirmPeriod
            confirmPeriod: { startDate, bleedingDays, notes, skipPredictions in
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let start = Calendar.current.startOfDay(for: startDate)
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
                // Validation: reject future dates, clamp bleeding days
                guard start <= tomorrow else { return }
                let bleedingDays = CycleMath.validateBleedingDays(bleedingDays, cycleLength: 28)

                // Match to prediction for accuracy tracking
                let predDescriptor = FetchDescriptor<PredictionRecord>(
                    predicate: #Predicate<PredictionRecord> { !$0.isConfirmed },
                    sortBy: [SortDescriptor(\.predictedDate)]
                )
                let predictions = try context.fetch(predDescriptor)
                // Rank by distance — pick the closest prediction within ±14 days
                let matchedPrediction = predictions
                    .map { ($0, abs(CycleMath.daysBetween($0.predictedDate, start))) }
                    .filter { $0.1 <= 14 }
                    .min(by: { $0.1 < $1.1 })
                    .map(\.0)

                // Check for existing cycle with same start date (upsert)
                let existingDescriptor = FetchDescriptor<CycleRecord>(
                    predicate: #Predicate<CycleRecord> { $0.startDate == start }
                )
                let existingCycles = try context.fetch(existingDescriptor)

                // Update previous cycle's length (only if this is a NEW cycle)
                if existingCycles.isEmpty {
                    let latestCycle = try fetchLatestCycle(context: context)
                    if let prev = latestCycle, prev.startDate != start {
                        let gap = CycleMath.cycleLength(
                            periodStart1: prev.startDate, periodStart2: start
                        )
                        if gap >= 18, gap <= 50 {
                            prev.actualCycleLength = gap
                        }
                    }
                }

                // Delete all duplicates, keep none — we'll insert a fresh one
                for existing in existingCycles {
                    context.delete(existing)
                }

                // Create cycle record
                let cycle = CycleRecord(
                    startDate: start,
                    endDate: CycleMath.addDays(start, bleedingDays - 1),
                    bleedingDays: bleedingDays,
                    notes: notes,
                    isConfirmed: true,
                    predictedStartDate: matchedPrediction?.predictedDate,
                    actualDeviationDays: matchedPrediction.map {
                        CycleMath.daysBetween($0.predictedDate, start)
                    }
                )
                context.insert(cycle)

                // Set journeyStartDate on first period confirmation
                if let profile = try fetchProfile(context: context),
                   profile.journeyStartDate == nil {
                    profile.journeyStartDate = start
                }

                // Mark matched prediction as confirmed
                if let pred = matchedPrediction {
                    pred.isConfirmed = true
                    pred.actualStartDate = start
                    pred.accuracyDays = abs(CycleMath.daysBetween(pred.predictedDate, start))
                }

                try context.save()

                // Recalculate all cycle lengths and profile from scratch
                try recalculateCycleStats(context: context)

                // Regenerate predictions (skip in batch mode — caller does it once at the end)
                if !skipPredictions {
                    try await regeneratePredictions(container: container)
                }

            },

            // MARK: removePeriodDays
            removePeriodDays: { dates in
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let cal = Calendar.current
                let datesToRemove = Set(dates.map { cal.startOfDay(for: $0) })

                let descriptor = FetchDescriptor<CycleRecord>(
                    sortBy: [SortDescriptor(\.startDate)]
                )
                let cycles = try context.fetch(descriptor)

                for cycle in cycles {
                    let bd = cycle.bleedingDays ?? 5
                    var cycleDates: [Date] = []
                    for dayOffset in 0..<bd {
                        cycleDates.append(CycleMath.addDays(cycle.startDate, dayOffset))
                    }
                    let removedFromCycle = cycleDates.filter { datesToRemove.contains($0) }
                    guard !removedFromCycle.isEmpty else { continue }

                    let remainingDates = cycleDates.filter { !datesToRemove.contains($0) }
                    if remainingDates.isEmpty {
                        // All days removed → delete entire cycle
                        context.delete(cycle)
                    } else {
                        // Partial removal → adjust cycle to remaining days
                        let newStart = remainingDates.min()!
                        cycle.startDate = newStart
                        cycle.bleedingDays = remainingDates.count
                        cycle.endDate = CycleMath.addDays(newStart, remainingDates.count - 1)
                    }
                }
                try context.save()

                // Recalculate all cycle lengths and profile from scratch
                try recalculateCycleStats(context: context)

                try await regeneratePredictions(container: container)
            },

            // MARK: getJourneyData
            getJourneyData: liveJourneyData(),

            // MARK: logSymptom
            logSymptom: { date, symptomType, severity, notes in
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let day = Calendar.current.startOfDay(for: date)

                // Determine cycle day
                let latestCycle = try fetchLatestCycle(context: context)
                let cycleDay = latestCycle.map {
                    CycleMath.cycleDay(cycleStart: $0.startDate, date: day)
                }

                let symptom = SymptomRecord(
                    symptomDate: day,
                    symptomType: symptomType,
                    severity: severity,
                    notes: notes,
                    cycleDay: cycleDay
                )
                context.insert(symptom)
                try context.save()
            },

            // MARK: getSymptoms
            getSymptoms: { date in
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let day = Calendar.current.startOfDay(for: date)
                let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)!

                let descriptor = FetchDescriptor<SymptomRecord>(
                    predicate: #Predicate { $0.symptomDate >= day && $0.symptomDate < nextDay },
                    sortBy: [SortDescriptor(\.createdAt)]
                )
                let records = try context.fetch(descriptor)

                return records.enumerated().map { index, record in
                    MenstrualSymptomResponse(
                        id: index,
                        symptomDate: record.symptomDate,
                        symptomType: record.symptomType,
                        severity: record.severity,
                        notes: record.notes
                    )
                }
            },

            // MARK: generatePrediction
            generatePrediction: {
                try await regeneratePredictions(container: CycleDataStore.shared)
            },

            // MARK: getProfile
            getProfile: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                guard let profile = try fetchProfile(context: context) else { return nil }
                return MenstrualProfileInfo(
                    avgCycleLength: profile.avgCycleLength,
                    cycleRegularity: profile.cycleRegularity,
                    trackingSince: profile.createdAt
                )
            },

            // MARK: saveProfile
            saveProfile: { profileInfo, symptoms, flowIntensity, usesContraception, contraceptionType in
                let container = CycleDataStore.shared
                let context = ModelContext(container)

                let existing = try fetchProfile(context: context)
                if let record = existing {
                    record.avgCycleLength = profileInfo.avgCycleLength
                    record.onboardingCycleLength = profileInfo.avgCycleLength
                    record.cycleRegularity = profileInfo.cycleRegularity
                    record.typicalSymptoms = symptoms
                    record.typicalFlowIntensity = flowIntensity
                    record.usesContraception = usesContraception
                    record.contraceptionType = contraceptionType
                    record.updatedAt = .now
                } else {
                    let record = MenstrualProfileRecord(
                        avgCycleLength: profileInfo.avgCycleLength,
                        cycleRegularity: profileInfo.cycleRegularity,
                        typicalSymptoms: symptoms,
                        typicalFlowIntensity: flowIntensity,
                        usesContraception: usesContraception,
                        contraceptionType: contraceptionType,
                        onboardingCompletedAt: .now
                    )
                    context.insert(record)
                }
                try context.save()
            },

            // MARK: unviewedRecapMonth
            unviewedRecapMonth: {
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
                // Only include cycles that ENDED after tracking began
                let localCal = Calendar.current
                let accountDate = UserDefaults.standard.object(forKey: "CycleDataResetDate") as? Date ?? .distantPast
                let trackingStart = localCal.startOfDay(for: accountDate)
                let pastCycleKeys = Set(cycles.dropFirst().filter { cycle in
                    let length = cycle.actualCycleLength ?? 28
                    let cycleEnd = localCal.date(byAdding: .day, value: length, to: cycle.startDate) ?? cycle.startDate
                    return cycleEnd >= trackingStart
                }.map {
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
            },

            // MARK: markAllRecapsViewed
            markAllRecapsViewed: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let allRecaps = (try? context.fetch(FetchDescriptor<CycleRecapRecord>())) ?? []
                let keys = allRecaps.map(\.cycleKey)
                var viewed = Set(UserDefaults.standard.stringArray(forKey: "ViewedRecapCycleKeys") ?? [])
                for key in keys { viewed.insert(key) }
                UserDefaults.standard.set(Array(viewed), forKey: "ViewedRecapCycleKeys")
            }

        )
    }

    // MARK: - Shared Helpers

    private static func fetchProfile(context: ModelContext) throws -> MenstrualProfileRecord? {
        let descriptor = FetchDescriptor<MenstrualProfileRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    private static func fetchLatestCycle(context: ModelContext) throws -> CycleRecord? {
        let descriptor = FetchDescriptor<CycleRecord>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    /// Recalculate all actualCycleLength values and profile stats from scratch.
    /// Ensures consistency regardless of edit order.
    private static func recalculateCycleStats(context: ModelContext) throws {
        let cycles = try fetchAllCycles(context: context) // sorted by startDate desc
        let sorted = cycles.reversed() // oldest first

        // Reset all actualCycleLength, then recompute from gaps
        for cycle in sorted {
            cycle.actualCycleLength = nil
        }
        let arr = Array(sorted)
        for i in 0..<arr.count {
            if i + 1 < arr.count {
                let gap = CycleMath.cycleLength(
                    periodStart1: arr[i].startDate, periodStart2: arr[i + 1].startDate
                )
                if gap >= 18, gap <= 50 {
                    arr[i].actualCycleLength = gap
                }
            }
        }

        // Recalculate profile
        if let profile = try fetchProfile(context: context) {
            let bleedingValues = arr.compactMap(\.bleedingDays)
            if !bleedingValues.isEmpty {
                profile.avgBleedingDays = Int(round(CycleMath.mean(bleedingValues)))
            }

            var cycleLengths: [Int] = []
            for cycle in arr {
                if let len = cycle.actualCycleLength {
                    cycleLengths.append(len)
                }
            }
            if !cycleLengths.isEmpty {
                profile.avgCycleLength = Int(round(CycleMath.mean(cycleLengths)))
                profile.cycleRegularity = CycleMath.classifyVariability(cycleLengths)
                // Promote observed average to baseline once we have enough data
                if cycleLengths.count >= 3 {
                    profile.onboardingCycleLength = profile.avgCycleLength
                }
            } else {
                // No observed cycle gaps — revert to baseline
                profile.avgCycleLength = profile.onboardingCycleLength
            }
            profile.updatedAt = .now
        }

        try context.save()
    }

    /// Remove duplicate CycleRecords sharing the same startDate, keeping the newest.
    private static func deduplicateCycles(context: ModelContext) throws {
        let all = try fetchAllCycles(context: context)
        var seen: [Date: CycleRecord] = [:]
        for cycle in all {
            let key = Calendar.current.startOfDay(for: cycle.startDate)
            if let existing = seen[key] {
                // Keep whichever was created/updated more recently
                if cycle.startDate > existing.startDate {
                    context.delete(existing)
                    seen[key] = cycle
                } else {
                    context.delete(cycle)
                }
            } else {
                seen[key] = cycle
            }
        }
        try context.save()
    }

    private static func fetchAllCycles(context: ModelContext) throws -> [CycleRecord] {
        let descriptor = FetchDescriptor<CycleRecord>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private static func fetchActivePrediction(context: ModelContext) throws -> PredictionRecord? {
        let today = Calendar.current.startOfDay(for: Date())
        let cutoff = CycleMath.addDays(today, -60)
        let descriptor = FetchDescriptor<PredictionRecord>(
            predicate: #Predicate<PredictionRecord> { pred in
                !pred.isConfirmed && pred.predictedDate >= cutoff
            },
            sortBy: [SortDescriptor(\.predictedDate)]
        )
        return try context.fetch(descriptor).first
    }

    /// Clear unconfirmed predictions and regenerate from current cycle data.
    private static func regeneratePredictions(container: ModelContainer) async throws {
        let context = ModelContext(container)

        // Clear unconfirmed predictions
        let clearDescriptor = FetchDescriptor<PredictionRecord>(
            predicate: #Predicate<PredictionRecord> { !$0.isConfirmed }
        )
        for pred in try context.fetch(clearDescriptor) {
            context.delete(pred)
        }

        // Save deletions before checking if we can regenerate
        try context.save()

        // Gather inputs
        guard let profile = try fetchProfile(context: context) else { return }
        let cycles = try fetchAllCycles(context: context)
        guard !cycles.isEmpty else { return }

        let cycleInputs = cycles.map { cycle in
            CycleInput(
                startDate: cycle.startDate,
                actualCycleLength: cycle.actualCycleLength,
                isConfirmed: cycle.isConfirmed,
                actualDeviationDays: cycle.actualDeviationDays
            )
        }

        let profileInput = ProfileInput(
            avgCycleLength: profile.avgCycleLength,
            avgBleedingDays: profile.avgBleedingDays,
            cycleRegularity: profile.cycleRegularity
        )

        // Generate primary prediction using the adaptive engine
        let result = MenstrualPredictor.predict(
            cycles: cycleInputs,
            profile: profileInput,
            hasSymptomData: false
        )

        let extractedLengths = MenstrualPredictor.extractedCycleLengths(
            cycles: cycleInputs, fallbackLength: profile.avgCycleLength
        )
        let sd = CycleMath.stdDev(extractedLengths)
        let cycleLen = profile.avgCycleLength
        // Apply trend to future projections (not just flat avgCycleLength)
        let trend = CycleMath.detectTrend(extractedLengths)
        let trendAdjust = trend != 0 ? (trend > 0 ? 1 : -1) : 0

        // Project 12 cycles into the future (~1 year of predictions)
        var currentStart = result.predictedStart
        var currentConfidence = result.confidence

        for i in 0..<12 {
            let rangeDays = CycleMath.predictionRangeDays(confidence: currentConfidence, stdDev: sd)
            let projectedLen = max(18, min(50, cycleLen + trendAdjust * min(i, 3)))
            let fertile = i == 0
                ? result.fertileWindow
                : CycleMath.simpleFertileWindow(cycleStart: currentStart, cycleLength: projectedLen)

            let pred = PredictionRecord(
                predictedDate: currentStart,
                rangeStart: CycleMath.addDays(currentStart, -rangeDays),
                rangeEnd: CycleMath.addDays(currentStart, rangeDays),
                confidenceLevel: currentConfidence,
                algorithmVersion: i == 0 ? result.algorithmVersion.rawValue : "v1_basic",
                basedOnCycles: result.basedOnCycles,
                fertileWindowStart: fertile.start,
                fertileWindowEnd: fertile.end,
                ovulationDate: fertile.peak
            )
            context.insert(pred)

            // Next cycle: advance by projected length (trend-aware), decay confidence
            currentStart = CycleMath.addDays(currentStart, projectedLen)
            currentConfidence = max(0.3, currentConfidence * 0.95)
        }

        try context.save()
    }
}

// MARK: - Mock

extension MenstrualLocalClient {
    static func mock() -> Self {
        MenstrualLocalClient(
            getStatus: { .mock },
            getCalendar: { _, _ in .mock },
            getCycleStats: { .mock },
            resetAllCycleData: { },
            confirmPeriod: { _, _, _, _ in },
            removePeriodDays: { _ in },
            getJourneyData: { JourneyData(records: [], predictions: [], reports: [], profileAvgCycleLength: 28, profileAvgBleedingDays: 5, currentCycleStartDate: nil) },
            logSymptom: { _, _, _, _ in },
            getSymptoms: { _ in [] },
            generatePrediction: { },
            getProfile: { nil },
            saveProfile: { _, _, _, _, _ in },
            unviewedRecapMonth: { nil },
            markAllRecapsViewed: { }
        )
    }
}
