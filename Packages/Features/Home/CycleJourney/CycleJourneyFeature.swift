import ComposableArchitecture
import SwiftData
import SwiftUI

// MARK: - Cycle Journey Feature

@Reducer
public struct CycleJourneyFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var cycleContext: CycleContext?
        public var menstrualStatus: MenstrualStatusResponse?
        public var summaries: [JourneyCycleSummary] = []
        public var predictions: [JourneyPredictionInput] = []
        public var insight: JourneyInsight?
        public var isLoading: Bool = false
        public var hasAppeared: Bool = false
        public var missedMonths: [MissedMonth] = []
        public var recap: RecapState?
        public var highlightRecapCycle: Bool = false
        /// When true, the feature auto-presents the most recent completed
        /// cycle's recap as soon as journey data loads. Consumed on the
        /// first `.journeyLoaded(.success)`; resets to false so reopening
        /// the screen manually doesn't pop the recap unexpectedly.
        public var autoOpenLatestRecap: Bool = false

        /// When true, the Journey screen acts purely as a host for the
        /// recap overlay — header + list are hidden. Dismissing the recap
        /// closes the whole Journey cover (returns to Home). Used by
        /// the Home "Latest Story" deep-link to avoid a visible flash of
        /// the Journey list before the recap covers it.
        public var directRecapMode: Bool = false

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case refresh
        case journeyLoaded(Result<JourneyData, Error>)
        case logMissedTapped
        case dismissTapped
        case cycleRecapTapped(JourneyCycleSummary)
        case recapLoaded(RecapData)
        case recapPageChanged(Int)
        case recapDismissed
        case askAriaAboutCycle(JourneyCycleSummary)
        /// Broadcast from TodayFeature via HomeFeature — keeps `cycleContext`
        /// fresh when the user edits period data without requiring a re-entry.
        case cycleDataChanged(CycleContext?)
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case dismiss
            case logMissedMonth(Date)
            case openAriaChat(context: String)
        }
    }

    @Dependency(\.menstrualLocal) var menstrualLocal

    private enum CancelID { case recapFetch, recapPreGenerate }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasAppeared else { return .none }
                state.hasAppeared = true
                state.isLoading = true
                return .merge(
                    .run { [menstrualLocal] send in
                        await send(.journeyLoaded(Result { try await menstrualLocal.getJourneyData() }))
                    },
                    .run { [menstrualLocal] _ in
                        try? await menstrualLocal.markAllRecapsViewed()
                    }
                )

            case .refresh:
                return .run { [menstrualLocal] send in
                    await send(.journeyLoaded(Result { try await menstrualLocal.getJourneyData() }))
                }

            case .journeyLoaded(.success(let data)):
                state.isLoading = false
                let currentStart = state.cycleContext?.cycleStartDate
                state.summaries = CycleJourneyEngine.buildSummaries(
                    inputs: data.records,
                    reports: data.reports,
                    profileAvgCycleLength: data.profileAvgCycleLength,
                    profileAvgBleedingDays: data.profileAvgBleedingDays,
                    currentCycleStartDate: currentStart
                )
                state.predictions = data.predictions
                state.insight = CycleJourneyEngine.buildInsight(summaries: state.summaries)
                state.missedMonths = CycleJourneyEngine.findMissedMonths(
                    predictions: data.predictions,
                    confirmedStartDates: data.records.map(\.startDate)
                )
                let summaries = state.summaries

                // Handle Home's "Latest Story" deep-link: once summaries
                // are ready, auto-tap the most recent completed cycle's
                // recap. One-shot — reset the flag so reopening the
                // screen later doesn't pop the recap again.
                var effects: [Effect<Action>] = [
                    .run { _ in
                        await CycleRecapGenerator.preGenerateAll(summaries: summaries)
                    }
                    .cancellable(id: CancelID.recapPreGenerate, cancelInFlight: true)
                ]
                if state.autoOpenLatestRecap {
                    state.autoOpenLatestRecap = false
                    if let latest = summaries.last(where: { !$0.isCurrentCycle }) {
                        effects.append(.send(.cycleRecapTapped(latest)))
                    }
                }
                return .merge(effects)

            case .journeyLoaded(.failure):
                state.isLoading = false
                return .none

            case .logMissedTapped:
                let targetDate = state.missedMonths.first?.date ?? Date()
                return .send(.delegate(.logMissedMonth(targetDate)))

            case .dismissTapped:
                return .send(.delegate(.dismiss))

            case .cycleRecapTapped(let summary):
                state.recap = RecapState(summary: summary)
                let allSummaries = state.summaries
                let isCurrent = summary.isCurrentCycle
                return .run { send in
                    if let cached = CycleJourneyFeature.loadCachedRecap(
                        cycleStart: summary.startDate,
                        maxAge: isCurrent ? 86400 : nil
                    ) {
                        await send(.recapLoaded(cached))
                        return
                    }
                    await CycleRecapGenerator.generateForClosedCycle(summary.startDate)
                    if let fresh = CycleJourneyFeature.loadCachedRecap(cycleStart: summary.startDate) {
                        await send(.recapLoaded(fresh))
                    } else {
                        // Last-ditch fallback with empty key days — keeps
                        // the sheet from hanging if persistence also fails.
                        let fallback = CycleJourneyFeature.templateRecap(
                            summary: summary,
                            allSummaries: allSummaries,
                            keyDays: []
                        )
                        await send(.recapLoaded(fallback))
                    }
                }
                .cancellable(id: CancelID.recapFetch, cancelInFlight: true)

            case .recapLoaded(let data):
                state.recap?.isLoading = false
                state.recap?.headline = data.headline
                state.recap?.cycleVibe = data.cycleVibe
                state.recap?.themeText = data.themeText
                state.recap?.bodyText = data.bodyText
                state.recap?.heartMindText = data.heartMindText
                state.recap?.rhythmText = data.rhythmText
                state.recap?.keyDays = data.keyDays
                state.recap?.whatsComingText = data.whatsComingText
                return .none

            case .recapPageChanged(let page):
                state.recap?.currentPage = page
                return .none

            case .recapDismissed:
                // In direct-recap mode, the parent owns the cover
                // animation and clears state after the slide-down
                // completes — so we keep `state.recap` populated here
                // to avoid an empty/white frame during dismissal.
                if state.directRecapMode {
                    return .none
                }
                state.recap = nil
                return .cancel(id: CancelID.recapFetch)

            case .askAriaAboutCycle(let summary):
                state.recap = nil
                let dateStr = Self.shortDateFormatter.string(from: summary.startDate)
                var context = "Tell me about my cycle from \(dateStr) — it was \(summary.cycleLength) days with a \(summary.bleedingDays) day period."
                if let mood = summary.avgMood {
                    context += " My average mood was \(String(format: "%.1f", mood))/5."
                }
                if let energy = summary.avgEnergy {
                    context += " My average energy was \(String(format: "%.1f", energy))/5."
                }
                return .send(.delegate(.openAriaChat(context: context)))

            case let .cycleDataChanged(newCycle):
                // Refresh cached cycle context so current-cycle card and
                // summaries reflect the latest edit. Derived state (summaries,
                // insight, predictions) rebuilds on the next `.refresh` / `.onAppear`.
                state.cycleContext = newCycle
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Recap State Types

public struct RecapState: Equatable, Sendable, Identifiable {
    public var id: Date { summary.id }
    public var summary: JourneyCycleSummary
    public var currentPage: Int = 0
    public var isLoading: Bool = true

    // Headline + short vibe word — shown on Chapter 1.
    public var headline: String = ""
    public var cycleVibe: String = ""

    // Six chapters.
    public var themeText: String = ""        // Ch1
    public var bodyText: String = ""         // Ch2
    public var heartMindText: String = ""    // Ch3
    public var rhythmText: String = ""       // Ch4
    public var keyDays: [KeyDay] = []        // Ch5 — structured
    public var whatsComingText: String = ""  // Ch6

    public static let totalPages = 6
}

public struct RecapData: Equatable, Sendable {
    public let headline: String
    public let cycleVibe: String
    public let themeText: String
    public let bodyText: String
    public let heartMindText: String
    public let rhythmText: String
    public let keyDays: [KeyDay]
    public let whatsComingText: String
}
