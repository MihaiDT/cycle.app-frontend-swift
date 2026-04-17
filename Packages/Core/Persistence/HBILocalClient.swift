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

            getPersonalBaseline: liveGetPersonalBaseline()
        )
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
            getPersonalBaseline: { phase in .empty(phase: phase) }
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
