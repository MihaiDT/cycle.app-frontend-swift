import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - Wellness Detail Feature
//
// Loads and shapes the data for the Wellness detail screen:
// - The latest HBI score + trend (hydrated by parent from the dashboard)
// - A per-phase breakdown row for each biological phase (Menstrual,
//   Follicular, Ovulatory, Luteal) using the W1 `personalBaseline` math.
// - "Rhythm" insights computed synchronously from the same breakdown.
//
// Parent (`TodayFeature`) presents this via a sheet and owns dismissal.

@Reducer
public struct WellnessDetailFeature: Sendable {

    // MARK: State

    @ObservableState
    public struct State: Equatable, Sendable {
        /// Seeded from TodayFeature — mirrored here so the compact widget can
        /// render without waiting on the detail load.
        public var adjusted: Double
        public var trendVsBaseline: Double?
        public var phase: CyclePhase?
        public var cycleDay: Int?
        public var sourceLabel: String

        /// Phase rows populated asynchronously from HBI history.
        public var rows: [PhaseRow] = []
        /// Rhythm insights derived once rows resolve.
        public var insights: [WellnessInsight] = []

        public var isLoadingBreakdown: Bool = false
        public var hasLoadedBreakdown: Bool = false

        public init(
            adjusted: Double,
            trendVsBaseline: Double?,
            phase: CyclePhase?,
            cycleDay: Int?,
            sourceLabel: String
        ) {
            self.adjusted = adjusted
            self.trendVsBaseline = trendVsBaseline
            self.phase = phase
            self.cycleDay = cycleDay
            self.sourceLabel = sourceLabel
        }
    }

    // MARK: Action

    public enum Action: Sendable, Equatable {
        case onAppear
        case breakdownLoaded(BreakdownPayload)
        case dismissTapped
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case dismiss
        }
    }

    /// Snapshot shape passed back from the async breakdown worker. Keeping
    /// rows and insights in one payload means a single reducer write per
    /// load, which keeps the sheet's appearance animation coherent.
    public struct BreakdownPayload: Sendable, Equatable {
        public let rows: [PhaseRow]
        public let insights: [WellnessInsight]
    }

    @Dependency(\.hbiLocal) var hbiLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasLoadedBreakdown else { return .none }
                state.isLoadingBreakdown = true
                let currentPhase = state.phase
                let currentAdjusted = state.adjusted
                return .run { [hbiLocal] send in
                    let payload = await Self.loadBreakdown(
                        hbiLocal: hbiLocal,
                        currentPhase: currentPhase,
                        currentAdjusted: currentAdjusted
                    )
                    await send(.breakdownLoaded(payload))
                }

            case .breakdownLoaded(let payload):
                state.rows = payload.rows
                state.insights = payload.insights
                state.isLoadingBreakdown = false
                state.hasLoadedBreakdown = true
                return .none

            case .dismissTapped:
                return .send(.delegate(.dismiss))

            case .delegate:
                return .none
            }
        }
    }

    // MARK: Breakdown Loader

    /// Pulls every per-phase baseline and computes "this cycle" scores from
    /// the current cycle's HBI records — all values are the user's own history.
    static func loadBreakdown(
        hbiLocal: HBILocalClient,
        currentPhase: CyclePhase?,
        currentAdjusted: Double
    ) async -> BreakdownPayload {
        // Baselines per biological phase (ignores `.late`).
        var baselines: [CyclePhase: PersonalBaseline] = [:]
        for phase in CyclePhase.biologicalPhases {
            if let baseline = try? await hbiLocal.getPersonalBaseline(phase) {
                baselines[phase] = baseline
            }
        }

        // Current-cycle scores per phase — read from the SwiftData store so
        // we don't need an extra client method. Small scan (<30 days).
        let thisCycleScores = currentCycleScoresByPhase()

        var rows: [PhaseRow] = []
        for phase in CyclePhase.biologicalPhases {
            let baseline = baselines[phase]
            let avg = baseline?.averageScore.map { Int($0.rounded()) }
            let isCurrent = (currentPhase == phase)

            let thisScore: Int? = {
                if isCurrent {
                    return max(0, min(100, Int(currentAdjusted.rounded())))
                }
                return thisCycleScores[phase].map { Int($0.rounded()) }
            }()

            let delta: Int? = {
                guard let thisScore, let avg else { return nil }
                return thisScore - avg
            }()

            rows.append(
                PhaseRow(
                    id: phase,
                    name: phase.displayName,
                    personalAverage: avg,
                    thisCycleScore: thisScore,
                    delta: delta,
                    isCurrent: isCurrent
                )
            )
        }

        let insights = buildInsights(rows: rows, baselines: baselines)
        return BreakdownPayload(rows: rows, insights: insights)
    }

    /// Reads HBI records from the current cycle window and averages them by
    /// phase. Returns the per-phase mean of `hbiAdjusted` so the UI shows the
    /// user's actual-experienced score for this cycle.
    private static func currentCycleScoresByPhase() -> [CyclePhase: Double] {
        let container = CycleDataStore.shared
        let context = ModelContext(container)
        // Look back ~45 days — comfortably covers one irregular cycle.
        let windowStart = Calendar.current.date(
            byAdding: .day, value: -45, to: Date()
        ) ?? Date()
        let descriptor = FetchDescriptor<HBIScoreRecord>(
            predicate: #Predicate { $0.scoreDate >= windowStart },
            sortBy: [SortDescriptor(\.scoreDate)]
        )
        guard let records = try? context.fetch(descriptor), !records.isEmpty else {
            return [:]
        }
        var buckets: [CyclePhase: [Double]] = [:]
        for record in records {
            guard let phaseRaw = record.cyclePhase,
                  let phase = CyclePhase(rawValue: phaseRaw),
                  CyclePhase.biologicalPhases.contains(phase) else { continue }
            buckets[phase, default: []].append(record.hbiAdjusted)
        }
        var result: [CyclePhase: Double] = [:]
        for (phase, values) in buckets where !values.isEmpty {
            result[phase] = values.reduce(0, +) / Double(values.count)
        }
        return result
    }

    // MARK: Insight Builder

    static func buildInsights(
        rows: [PhaseRow],
        baselines: [CyclePhase: PersonalBaseline]
    ) -> [WellnessInsight] {
        // Detect enough signal across at least two cycles for any phase.
        let hasSignal = baselines.values.contains {
            $0.confidence != .insufficient && $0.averageScore != nil
        }
        guard hasSignal else {
            return [
                WellnessInsight(
                    id: .earlyDays,
                    kicker: "Early days",
                    body: "Your rhythm becomes clear after 2 full cycles."
                )
            ]
        }

        var insights: [WellnessInsight] = []

        // Best phase — highest averageScore among established/building rows.
        let bestPhaseRow = rows
            .filter { $0.personalAverage != nil }
            .max { ($0.personalAverage ?? 0) < ($1.personalAverage ?? 0) }
        if let best = bestPhaseRow {
            insights.append(
                WellnessInsight(
                    id: .bestPhase,
                    kicker: "Best phase for you",
                    body: "\(best.name) — consistently your strongest week"
                )
            )
        }

        // Moment impact — placeholder until W3 wires moment logging. Hides
        // on purpose when we can't honestly compute it.
        // Kept as a discoverable second insight once data arrives.
        if insights.count == 1, let best = bestPhaseRow,
           let avg = best.personalAverage, avg >= 60 {
            insights.append(
                WellnessInsight(
                    id: .momentImpact,
                    kicker: "Your rhythm",
                    body: "Your higher-energy phases cluster around \(best.name.lowercased())"
                )
            )
        }

        return insights
    }
}

// MARK: - Row & Insight Models

public struct PhaseRow: Identifiable, Sendable, Equatable {
    public let id: CyclePhase
    public let name: String
    public let personalAverage: Int?
    public let thisCycleScore: Int?
    public let delta: Int?
    public let isCurrent: Bool

    public init(
        id: CyclePhase,
        name: String,
        personalAverage: Int?,
        thisCycleScore: Int?,
        delta: Int?,
        isCurrent: Bool
    ) {
        self.id = id
        self.name = name
        self.personalAverage = personalAverage
        self.thisCycleScore = thisCycleScore
        self.delta = delta
        self.isCurrent = isCurrent
    }
}

public struct WellnessInsight: Identifiable, Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case earlyDays
        case bestPhase
        case momentImpact
    }

    public let id: Kind
    public let kicker: String
    public let body: String

    public init(id: Kind, kicker: String, body: String) {
        self.id = id
        self.kicker = kicker
        self.body = body
    }
}
