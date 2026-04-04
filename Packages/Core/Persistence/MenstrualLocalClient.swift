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

    /// Confirm a new period (create/update cycle record + regenerate prediction).
    public var confirmPeriod: @Sendable (Date, Int, String?) async throws -> Void

    /// Remove period days (delete cycle records containing those dates).
    public var removePeriodDays: @Sendable ([Date]) async throws -> Void

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
                    hasCycleData: {
                        guard let lc = latestCycle else { return false }
                        // Active if latest cycle started within 2x avg cycle length
                        let maxAge = avgCycleLength * 2
                        let daysSinceCycle = CycleMath.daysBetween(lc.startDate, today)
                        return daysSinceCycle >= 0 && daysSinceCycle <= maxAge
                    }()
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

            // MARK: confirmPeriod
            confirmPeriod: { startDate, bleedingDays, notes in
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let start = Calendar.current.startOfDay(for: startDate)

                // Match to prediction for accuracy tracking
                let predDescriptor = FetchDescriptor<PredictionRecord>(
                    predicate: #Predicate<PredictionRecord> { !$0.isConfirmed },
                    sortBy: [SortDescriptor(\.predictedDate)]
                )
                let predictions = try context.fetch(predDescriptor)
                var matchedPrediction: PredictionRecord?
                for pred in predictions {
                    let diff = abs(CycleMath.daysBetween(pred.predictedDate, start))
                    if diff <= 14 {
                        matchedPrediction = pred
                        break
                    }
                }

                // Update previous cycle's length
                let latestCycle = try fetchLatestCycle(context: context)
                if let prev = latestCycle {
                    let gap = CycleMath.cycleLength(
                        periodStart1: prev.startDate, periodStart2: start
                    )
                    if gap >= 18, gap <= 50 {
                        prev.actualCycleLength = gap
                    }
                }

                // Create new cycle
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

                // Mark matched prediction as confirmed
                if let pred = matchedPrediction {
                    pred.isConfirmed = true
                    pred.actualStartDate = start
                    pred.accuracyDays = abs(CycleMath.daysBetween(pred.predictedDate, start))
                }

                // Update profile bleeding days (rolling average)
                if let profile = try fetchProfile(context: context) {
                    let allCycles = try fetchAllCycles(context: context)
                    let bleedingValues = allCycles.compactMap(\.bleedingDays)
                    if !bleedingValues.isEmpty {
                        profile.avgBleedingDays = Int(round(CycleMath.mean(bleedingValues)))
                    }

                    // Recalculate regularity
                    var cycleLengths: [Int] = []
                    for (i, c) in allCycles.enumerated() {
                        if let len = c.actualCycleLength { cycleLengths.append(len) }
                        else if i + 1 < allCycles.count {
                            let gap = CycleMath.cycleLength(
                                periodStart1: allCycles[i + 1].startDate,
                                periodStart2: c.startDate
                            )
                            if gap >= 18, gap <= 50 { cycleLengths.append(gap) }
                        }
                    }
                    if !cycleLengths.isEmpty {
                        profile.avgCycleLength = Int(round(CycleMath.mean(cycleLengths)))
                        profile.cycleRegularity = CycleMath.classifyVariability(cycleLengths)
                    }
                    profile.updatedAt = .now
                }

                try context.save()

                // Regenerate predictions
                try await regeneratePredictions(container: container)
            },

            // MARK: removePeriodDays
            removePeriodDays: { dates in
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let datesToRemove = Set(dates.map { Calendar.current.startOfDay(for: $0) })

                let descriptor = FetchDescriptor<CycleRecord>(
                    sortBy: [SortDescriptor(\.startDate)]
                )
                let cycles = try context.fetch(descriptor)

                for cycle in cycles {
                    let bd = cycle.bleedingDays ?? 5
                    for dayOffset in 0..<bd {
                        let date = CycleMath.addDays(cycle.startDate, dayOffset)
                        if datesToRemove.contains(date) {
                            context.delete(cycle)
                            break
                        }
                    }
                }
                try context.save()

                try await regeneratePredictions(container: container)
            },

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

        let sd = CycleMath.stdDev(cycleInputs.compactMap(\.actualCycleLength))
        let cycleLen = profile.avgCycleLength

        // Project 12 cycles into the future (~1 year of predictions)
        var currentStart = result.predictedStart
        var currentConfidence = result.confidence

        for i in 0..<12 {
            let rangeDays = CycleMath.predictionRangeDays(confidence: currentConfidence, stdDev: sd)
            let fertile = i == 0
                ? result.fertileWindow
                : CycleMath.simpleFertileWindow(cycleStart: currentStart, cycleLength: cycleLen)

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

            // Next cycle: advance by avg length, decay confidence slightly
            currentStart = CycleMath.addDays(currentStart, cycleLen)
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
            confirmPeriod: { _, _, _ in },
            removePeriodDays: { _ in },
            logSymptom: { _, _, _, _ in },
            getSymptoms: { _ in [] },
            generatePrediction: { },
            getProfile: { nil },
            saveProfile: { _, _, _, _, _ in }
        )
    }
}
