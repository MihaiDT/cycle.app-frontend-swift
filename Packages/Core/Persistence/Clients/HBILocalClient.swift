import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - HBI Local Client

/// On-device HBI persistence and calculation.
/// Replaces HBIClient (network) — same return types for minimal feature refactoring.
public struct HBILocalClient: Sendable {
    /// Full dashboard: today's score, 7-day trend, latest report, insights.
    public var getDashboard: @Sendable () async throws -> HBIDashboardResponse

    /// Today's score and self-report.
    public var getToday: @Sendable () async throws -> HBITodayResponse

    /// Submit a daily check-in, compute HBI, and store both locally.
    public var submitDailyReport: @Sendable (DailyReportRequest) async throws -> DailyReportResponse

    /// Last 30 days of adjusted HBI scores for baseline calculation.
    public var getRecentScores: @Sendable () async throws -> [Double]

    /// Per-phase personal baseline derived from the user's historical scores.
    /// Returns `.insufficient` confidence (and `nil` average) until the user
    /// has accumulated enough same-phase samples across at least two cycles.
    public var getPersonalBaseline: @Sendable (_ phase: CyclePhase) async throws -> PersonalBaseline

    /// Apply a completed-moment bump to today's component scores, then
    /// recompute + persist the HBI record so the Home widget reflects
    /// the shift. If no check-in exists yet today, a neutral 50-baseline
    /// record is seeded first so the bump has something to land on.
    public var applyMomentBump: @Sendable (_ category: String, _ rating: String) async throws -> Void
}

// MARK: - Dependency

extension HBILocalClient: DependencyKey {
    public static let liveValue = HBILocalClient.live()
    public static let testValue = HBILocalClient.mock()
    public static let previewValue = HBILocalClient.mock()
}

extension DependencyValues {
    public var hbiLocal: HBILocalClient {
        get { self[HBILocalClient.self] }
        set { self[HBILocalClient.self] = newValue }
    }
}

// MARK: - Live

extension HBILocalClient {
    static func live() -> Self {
        HBILocalClient(
            getDashboard: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let today = Calendar.current.startOfDay(for: Date())
                let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!

                // Today's score
                let todayScore = try fetchScore(context: context, date: today)

                // Week trend
                let trendDescriptor = FetchDescriptor<HBIScoreRecord>(
                    predicate: #Predicate { $0.scoreDate >= weekAgo },
                    sortBy: [SortDescriptor(\.scoreDate)]
                )
                let trendRecords = try context.fetch(trendDescriptor)
                let weekTrend = trendRecords.map { $0.toHBIScore() }

                // Latest self-report
                let reportDescriptor = FetchDescriptor<SelfReportRecord>(
                    sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
                )
                let latestReport = try context.fetch(reportDescriptor).first?.toDailySelfReport()

                // Cycle phase from menstrual data
                let (phase, cycleDay) = try currentCycleContext(context: context)

                return HBIDashboardResponse(
                    today: todayScore?.toHBIScore(),
                    weekTrend: weekTrend,
                    latestReport: latestReport,
                    cyclePhase: phase?.rawValue,
                    cycleDay: cycleDay
                )
            },

            getToday: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let today = Calendar.current.startOfDay(for: Date())

                let score = try fetchScore(context: context, date: today)
                let report = try fetchReport(context: context, date: today)

                return HBITodayResponse(
                    hbiScore: score?.toHBIScore(),
                    selfReport: report?.toDailySelfReport(),
                    hasData: score != nil || report != nil,
                    message: score != nil ? "Your wellness snapshot for today" : "Complete your daily check-in"
                )
            },

            submitDailyReport: { request in
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let today = Calendar.current.startOfDay(for: Date())

                // Save self-report (upsert by date)
                let existingDescriptor = FetchDescriptor<SelfReportRecord>(
                    predicate: #Predicate { $0.reportDate == today }
                )
                if let existing = try context.fetch(existingDescriptor).first {
                    context.delete(existing)
                }

                let report = SelfReportRecord(
                    reportDate: today,
                    energyLevel: request.energyLevel,
                    stressLevel: request.stressLevel,
                    sleepQuality: request.sleepQuality,
                    moodLevel: request.moodLevel,
                    notes: request.notes
                )
                context.insert(report)

                // Compute HBI components (reuse existing Likert → 0-100 mapping)
                let (phase, cycleDay) = try currentCycleContext(context: context)

                let hbiResult = HBICalculator.calculate(
                    selfReport: SelfReportInput(
                        energyLevel: request.energyLevel,
                        stressLevel: request.stressLevel,
                        sleepQuality: request.sleepQuality,
                        moodLevel: request.moodLevel
                    ),
                    cyclePhase: phase,
                    cycleDay: cycleDay
                )

                // Resolve the adjusted HBI via phase weights + personal baseline.
                // Falls back to raw when no phase or insufficient samples.
                let uiPhase = phase.flatMap { CyclePhase(rawValue: $0.rawValue) }
                let adjusted: AdjustedHBIResult? = {
                    guard let p = uiPhase else { return nil }
                    let baseline = try? computePersonalBaseline(phase: p, context: context)
                    let components = HBIComponents(
                        energy: hbiResult.energyScore,
                        mood: hbiResult.moodScore,
                        sleep: hbiResult.sleepScore,
                        // anxietyScore is "low stress = high score" already —
                        // a higher value is calmer, matching the `calm` axis.
                        calm: hbiResult.anxietyScore,
                        clarity: hbiResult.clarityScore
                    )
                    return HBICalculator.calculateAdjustedWithBaseline(
                        components: components,
                        phase: p,
                        baseline: baseline,
                        hasHealthKitData: hbiResult.hasHealthKitData,
                        completenessScore: hbiResult.completenessScore
                    )
                }()

                let finalRaw = adjusted?.raw ?? hbiResult.hbiRaw
                let finalAdjusted = adjusted?.adjusted ?? hbiResult.hbiAdjusted
                let finalTrend = adjusted?.trendVsBaseline
                let finalCompleteness = adjusted?.completenessScore ?? hbiResult.completenessScore

                // Save HBI score (upsert by date)
                let scoreDescriptor = FetchDescriptor<HBIScoreRecord>(
                    predicate: #Predicate { $0.scoreDate == today }
                )
                if let existing = try context.fetch(scoreDescriptor).first {
                    context.delete(existing)
                }

                let scoreRecord = HBIScoreRecord(
                    scoreDate: today,
                    energyScore: hbiResult.energyScore,
                    anxietyScore: hbiResult.anxietyScore,
                    sleepScore: hbiResult.sleepScore,
                    moodScore: hbiResult.moodScore,
                    clarityScore: hbiResult.clarityScore,
                    hbiRaw: finalRaw,
                    hbiAdjusted: finalAdjusted,
                    cyclePhase: hbiResult.cyclePhase?.rawValue,
                    cycleDay: hbiResult.cycleDay,
                    // phaseMultiplier retained as nil — new model uses phase
                    // weights directly instead of a single scalar multiplier.
                    phaseMultiplier: nil,
                    trendVsBaseline: finalTrend,
                    hasHealthKitData: hbiResult.hasHealthKitData,
                    hasSelfReport: hbiResult.hasSelfReport,
                    completenessScore: finalCompleteness
                )
                context.insert(scoreRecord)
                try context.save()

                return DailyReportResponse(
                    report: report.toDailySelfReport(),
                    hbiScore: scoreRecord.toHBIScore(),
                    message: "Check-in saved"
                )
            },

            getRecentScores: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

                let descriptor = FetchDescriptor<HBIScoreRecord>(
                    predicate: #Predicate { $0.scoreDate >= thirtyDaysAgo },
                    sortBy: [SortDescriptor(\.scoreDate)]
                )
                return try context.fetch(descriptor).map(\.hbiAdjusted)
            },

            getPersonalBaseline: liveGetPersonalBaseline(),

            applyMomentBump: { category, rating in
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let today = Calendar.current.startOfDay(for: Date())

                // Bump table — calibrated heuristic, not clinical. Moves
                // the components that this kind of moment actually helps.
                let bump = MomentBump.forCategory(category, rating: rating)

                // Start from today's record if it exists, otherwise seed a
                // neutral 50-baseline so a completed moment can still land.
                let existing = try fetchScore(context: context, date: today)

                let baseEnergy: Double = existing?.energyScore ?? 50
                let baseMood: Double = existing?.moodScore ?? 50
                let baseSleep: Double = existing?.sleepScore ?? 50
                let baseCalm: Double = existing?.anxietyScore ?? 50   // stored as anxietyScore, used as calm axis
                let baseClarity: Double? = existing?.clarityScore

                func clamp(_ value: Double) -> Double { max(0, min(100, value)) }

                let newEnergy = clamp(baseEnergy + bump.energy)
                let newMood = clamp(baseMood + bump.mood)
                let newSleep = clamp(baseSleep + bump.sleep)
                let newCalm = clamp(baseCalm + bump.calm)
                let newClarity = baseClarity.map { clamp($0 + bump.clarity) }

                let (phaseResult, cycleDay) = try currentCycleContext(context: context)
                let phase = phaseResult.flatMap { CyclePhase(rawValue: $0.rawValue) }
                    ?? existing?.cyclePhase.flatMap(CyclePhase.init(rawValue:))
                let resolvedPhase = phase ?? .follicular   // fallback neutral weights

                let components = HBIComponents(
                    energy: newEnergy,
                    mood: newMood,
                    sleep: newSleep,
                    calm: newCalm,
                    clarity: newClarity
                )

                // Pull the personal baseline so the adjusted score reflects
                // "you vs your own phase pattern" after the bump.
                let baseline = try computePersonalBaseline(phase: resolvedPhase, context: context)

                let adjusted = HBICalculator.calculateAdjustedWithBaseline(
                    components: components,
                    phase: resolvedPhase,
                    baseline: baseline
                )

                // Upsert: update today's record or insert a new one.
                if let record = existing {
                    record.energyScore = newEnergy
                    record.moodScore = newMood
                    record.sleepScore = newSleep
                    record.anxietyScore = newCalm
                    record.clarityScore = newClarity
                    record.hbiRaw = adjusted.raw
                    record.hbiAdjusted = adjusted.adjusted
                    record.cyclePhase = resolvedPhase.rawValue
                    record.cycleDay = cycleDay
                    record.trendVsBaseline = adjusted.trendVsBaseline
                    record.hasSelfReport = existing?.hasSelfReport ?? false
                    record.hasHealthKitData = adjusted.hasHealthKitData
                    record.completenessScore = adjusted.completenessScore
                } else {
                    let fresh = HBIScoreRecord(
                        scoreDate: today,
                        energyScore: newEnergy,
                        anxietyScore: newCalm,
                        sleepScore: newSleep,
                        moodScore: newMood,
                        clarityScore: newClarity,
                        hbiRaw: adjusted.raw,
                        hbiAdjusted: adjusted.adjusted,
                        cyclePhase: resolvedPhase.rawValue,
                        cycleDay: cycleDay,
                        phaseMultiplier: nil,
                        trendVsBaseline: adjusted.trendVsBaseline,
                        trendDirection: nil,
                        hasHealthKitData: adjusted.hasHealthKitData,
                        hasSelfReport: false,
                        completenessScore: adjusted.completenessScore,
                        createdAt: Date()
                    )
                    context.insert(fresh)
                }

                try context.save()
            }
        )
    }

    // MARK: - Moment Bump Table

    /// Per-category component delta applied on top of today's components
    /// when a moment is completed. Rating scales the magnitude so a gold
    /// reflection nudges more than a bronze one. Bronze=1.0 / silver=1.3 /
    /// gold=1.6. Deliberately small: the point is to let moments shift
    /// the needle a little, not inflate Wellness.
    private struct MomentBump: Sendable {
        var energy: Double = 0
        var mood: Double = 0
        var sleep: Double = 0
        var calm: Double = 0
        var clarity: Double = 0

        static func forCategory(_ category: String, rating: String) -> MomentBump {
            let multiplier: Double = {
                switch rating.lowercased() {
                case "gold":   return 1.6
                case "silver": return 1.3
                default:       return 1.0   // bronze or anything else
                }
            }()

            var bump: MomentBump
            switch category.lowercased() {
            case "mindfulness", "self_care":
                bump = MomentBump(energy: 0, mood: 2, sleep: 0, calm: 4, clarity: 1)
            case "movement":
                bump = MomentBump(energy: 4, mood: 2, sleep: 0, calm: 1, clarity: 0)
            case "creative":
                bump = MomentBump(energy: 1, mood: 4, sleep: 0, calm: 1, clarity: 2)
            case "social":
                bump = MomentBump(energy: 1, mood: 4, sleep: 0, calm: 1, clarity: 0)
            case "nutrition":
                bump = MomentBump(energy: 2, mood: 3, sleep: 0, calm: 1, clarity: 0)
            default:
                bump = MomentBump(energy: 1, mood: 3, sleep: 0, calm: 1, clarity: 0)
            }

            return MomentBump(
                energy: bump.energy * multiplier,
                mood: bump.mood * multiplier,
                sleep: bump.sleep * multiplier,
                calm: bump.calm * multiplier,
                clarity: bump.clarity * multiplier
            )
        }
    }

    // MARK: Helpers

    private static func fetchScore(context: ModelContext, date: Date) throws -> HBIScoreRecord? {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        let descriptor = FetchDescriptor<HBIScoreRecord>(
            predicate: #Predicate { $0.scoreDate >= date && $0.scoreDate < nextDay },
            sortBy: [SortDescriptor(\.scoreDate, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    private static func fetchReport(context: ModelContext, date: Date) throws -> SelfReportRecord? {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        let descriptor = FetchDescriptor<SelfReportRecord>(
            predicate: #Predicate { $0.reportDate >= date && $0.reportDate < nextDay },
            sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    /// Get current cycle phase and day from local menstrual data.
    private static func currentCycleContext(context: ModelContext) throws -> (CyclePhaseResult?, Int?) {
        let descriptor = FetchDescriptor<CycleRecord>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        guard let latestCycle = try context.fetch(descriptor).first else {
            return (nil, nil)
        }

        let profileDescriptor = FetchDescriptor<MenstrualProfileRecord>()
        let profile = try context.fetch(profileDescriptor).first

        let today = Calendar.current.startOfDay(for: Date())
        let day = CycleMath.cycleDay(cycleStart: latestCycle.startDate, date: today)
        let cl = profile?.avgCycleLength ?? 28
        let bd = latestCycle.bleedingDays ?? profile?.avgBleedingDays ?? 5

        let phase = CycleMath.cyclePhase(cycleDay: day, cycleLength: cl, bleedingDays: bd)
        return (phase, day)
    }
}

// MARK: - Mock

extension HBILocalClient {
    static func mock() -> Self {
        HBILocalClient(
            getDashboard: { HBIDashboardResponse() },
            getToday: { HBITodayResponse() },
            submitDailyReport: { _ in DailyReportResponse(report: .mock) },
            getRecentScores: { [] },
            getPersonalBaseline: { phase in .empty(phase: phase) },
            applyMomentBump: { _, _ in }
        )
    }
}

// MARK: - Record → Models Conversions

extension HBIScoreRecord {
    func toHBIScore() -> HBIScore {
        HBIScore(
            id: .init(Int64(scoreDate.timeIntervalSince1970)),
            userId: 0,
            scoreDate: scoreDate,
            energyScore: Int(energyScore.rounded()),
            anxietyScore: Int(anxietyScore.rounded()),
            sleepScore: Int(sleepScore.rounded()),
            moodScore: Int(moodScore.rounded()),
            clarityScore: clarityScore.map { Int($0.rounded()) },
            hbiRaw: Int(hbiRaw.rounded()),
            hbiAdjusted: Int(hbiAdjusted.rounded()),
            cyclePhase: cyclePhase,
            cycleDay: cycleDay,
            phaseMultiplier: phaseMultiplier,
            trendVsBaseline: trendVsBaseline,
            trendDirection: trendDirection,
            hasHealthkitData: hasHealthKitData,
            hasSelfReport: hasSelfReport,
            completenessScore: Int(completenessScore),
            createdAt: createdAt
        )
    }
}

extension SelfReportRecord {
    func toDailySelfReport() -> DailySelfReport {
        DailySelfReport(
            id: .init(Int64(reportDate.timeIntervalSince1970)),
            userId: 0,
            reportDate: reportDate,
            energyLevel: energyLevel,
            stressLevel: stressLevel,
            sleepQuality: sleepQuality,
            moodLevel: moodLevel,
            notes: notes,
            createdAt: createdAt
        )
    }
}
