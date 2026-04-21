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

// MARK: - Cycle Journey View

public struct CycleJourneyView: View {
    let store: StoreOf<CycleJourneyFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardWidthRatio: CGFloat = 0.72
    private let cardHeight: CGFloat = 170
    private let horizontalInset: CGFloat = AppLayout.horizontalPadding

    public init(store: StoreOf<CycleJourneyFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Direct-recap mode hides the list UI entirely — the view
            // is just a backdrop for the recap sheet that is about to
            // present. Prevents the "Journey list flash" when deep-linking
            // from Home's Latest Story tile.
            if !store.directRecapMode {
                journeyHeader

                if store.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(DesignColors.accentWarm)
                    Spacer()
                } else if store.summaries.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    journeyScrollContent
                }
            } else {
                Spacer()
                ProgressView()
                    .tint(DesignColors.accentWarm)
                Spacer()
            }
        }
        .background { JourneyAnimatedBackground() }
        .onAppear { store.send(.onAppear) }
        .fullScreenCover(item: Binding(
            get: { store.recap },
            set: { if $0 == nil { store.send(.recapDismissed) } }
        )) { _ in
            AriaRecapStories(store: store)
        }
    }

    // MARK: - Header

    private var journeyHeader: some View {
        SheetHeader(
            title: "Your Journey",
            eyebrow: "Every cycle, a chapter",
            onDismiss: { store.send(.dismissTapped) }
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppLayout.spacingL) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DesignColors.accentWarm.opacity(0.6))

            VStack(spacing: 8) {
                Text("Every cycle tells a story")
                    .font(.raleway("Bold", size: 20, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)

                Text("Log your first period and Aria will start building your personal rhythm insights.")
                    .font(.raleway("Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, AppLayout.spacingXL)
            }
        }
    }

    // MARK: - Scroll Content

    private var journeyScrollContent: some View {
        let currentIndex = store.summaries.firstIndex(where: \.isCurrentCycle) ?? (store.summaries.count - 1)
        let today = Calendar.current.startOfDay(for: Date())
        let futurePredictions = store.predictions.filter { $0.predictedDate > today }

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    JourneyMandala(
                        summaries: store.summaries,
                        currentCycleProgress: currentCycleProgress,
                        targetCycles: nextMilestoneTarget
                    )

                    ForEach(Array(store.summaries.enumerated()), id: \.element.id) { index, summary in
                        let currentPhase = currentPhaseFor(summary: summary)
                        let isFutureSegment = index >= currentIndex
                        let isRecapTarget = store.highlightRecapCycle
                            && !summary.isCurrentCycle
                            && summary.id == store.summaries.last(where: { !$0.isCurrentCycle })?.id

                        journeyCardRow(
                            summary: summary,
                            phase: currentPhase,
                            isFuture: false,
                            index: index,
                            highlightRecap: isRecapTarget
                        )
                        .id(summary.id)

                        if index < store.summaries.count - 1 || !store.missedMonths.isEmpty || !futurePredictions.isEmpty {
                            ConnectorLine(
                                fromLeft: index % 2 == 0,
                                toLeft: (index + 1) % 2 == 0,
                                isDashed: isFutureSegment
                            )
                        }
                    }

                    if !store.missedMonths.isEmpty {
                        AriaJourneyNudge(
                            missedMonths: store.missedMonths,
                            onLogTapped: { store.send(.logMissedTapped) }
                        )
                        .padding(.horizontal, horizontalInset)

                        if !futurePredictions.isEmpty {
                            let afterSummaryIndex = store.summaries.count
                            ConnectorLine(
                                fromLeft: afterSummaryIndex % 2 == 0,
                                toLeft: (afterSummaryIndex + 1) % 2 == 0,
                                isDashed: true
                            )
                        }
                    }

                    ForEach(Array(futurePredictions.enumerated()), id: \.offset) { predIndex, prediction in
                        let globalIndex = store.summaries.count + (store.missedMonths.isEmpty ? 0 : 1) + predIndex
                        let cycleNumber = (store.summaries.last?.cycleNumber ?? 0) + predIndex + 1
                        let fakeSummary = predictionSummary(
                            prediction: prediction,
                            cycleNumber: cycleNumber,
                            avgLength: store.menstrualStatus?.profile.avgCycleLength ?? 28
                        )

                        journeyCardRow(
                            summary: fakeSummary,
                            phase: nil,
                            isFuture: true,
                            index: globalIndex
                        )

                        if predIndex < futurePredictions.count - 1 {
                            ConnectorLine(
                                fromLeft: globalIndex % 2 == 0,
                                toLeft: (globalIndex + 1) % 2 == 0,
                                isDashed: true
                            )
                        }
                    }
                }
                .padding(.top, AppLayout.spacingM)
                .padding(.bottom, AppLayout.spacingXXL)
            }
            .onAppear {
                scrollToCurrentCycle(proxy: proxy)
            }
        }
    }

    // MARK: - Card Row

    private func journeyCardRow(
        summary: JourneyCycleSummary,
        phase: CyclePhase?,
        isFuture: Bool,
        index: Int,
        highlightRecap: Bool = false
    ) -> some View {
        let isLeftAligned = index % 2 == 0
        let currentDay: Int? = summary.isCurrentCycle
            ? store.cycleContext?.cycleDay
            : nil

        return GeometryReader { geo in
            let cardWidth = geo.size.width * cardWidthRatio
            HStack {
                if !isLeftAligned {
                    Spacer()
                }

                JourneyCycleCard(
                    summary: summary,
                    phase: phase,
                    isFuture: isFuture,
                    currentDay: currentDay
                )
                .frame(width: cardWidth, height: cardHeight)
                .modifier(PulseHighlight(isActive: highlightRecap))
                .accessibilityLabel(cardAccessibilityLabel(summary: summary, isFuture: isFuture))
                .accessibilityHint("Double tap to view cycle details")
                .onTapGesture {
                    guard !isFuture, !summary.isCurrentCycle else { return }
                    store.send(.cycleRecapTapped(summary))
                }

                if isLeftAligned {
                    Spacer()
                }
            }
        }
        .frame(height: cardHeight)
        .padding(.horizontal, horizontalInset)
    }

    // MARK: - Helpers

    /// Zoom-pulse that draws attention to the recap card.
    private struct PulseHighlight: ViewModifier {
        let isActive: Bool
        @State private var scale: CGFloat = 1.0

        func body(content: Content) -> some View {
            content
                .scaleEffect(scale)
                .onAppear {
                    guard isActive else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scale = 1.08
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                scale = 1.0
                            }
                        }
                    }
                }
        }
    }

    private var currentCycleProgress: CGFloat? {
        guard let cycle = store.cycleContext,
              let current = store.summaries.first(where: \.isCurrentCycle) else { return nil }
        let length = current.cycleLength > 0 ? current.cycleLength : 28
        return min(1.0, CGFloat(cycle.cycleDay) / CGFloat(length))
    }

    private var nextMilestoneTarget: Int {
        let completed = store.summaries.filter { !$0.isCurrentCycle }.count
        if completed < 3 { return 3 }
        if completed < 6 { return 6 }
        if completed < 12 { return 12 }
        return completed
    }

    private func currentPhaseFor(summary: JourneyCycleSummary) -> CyclePhase? {
        guard summary.isCurrentCycle, let cycle = store.cycleContext else { return nil }
        return cycle.resolvedPhase(for: Calendar.current.startOfDay(for: Date()))
    }

    private func scrollToCurrentCycle(proxy: ScrollViewProxy) {
        if let currentID = store.summaries.first(where: \.isCurrentCycle)?.id {
            let delay: TimeInterval = reduceMotion ? 0.1 : 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if reduceMotion {
                    proxy.scrollTo(currentID, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(currentID, anchor: .center)
                    }
                }
            }
        }
    }

    private func predictionSummary(
        prediction: JourneyPredictionInput,
        cycleNumber: Int,
        avgLength: Int
    ) -> JourneyCycleSummary {
        let breakdown = CycleJourneyEngine.phaseBreakdown(
            cycleLength: avgLength,
            bleedingDays: 5
        )
        return JourneyCycleSummary(
            id: prediction.predictedDate,
            cycleNumber: cycleNumber,
            startDate: prediction.predictedDate,
            endDate: nil,
            cycleLength: avgLength,
            bleedingDays: 5,
            phaseBreakdown: breakdown,
            predictionAccuracyDays: nil,
            accuracyLabel: nil,
            isCurrentCycle: false,
            avgEnergy: nil,
            avgMood: nil,
            moodLabel: nil
        )
    }

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private func cardAccessibilityLabel(summary: JourneyCycleSummary, isFuture: Bool) -> String {
        if isFuture {
            return "Predicted Cycle \(summary.cycleNumber), estimated \(Self.mediumDateFormatter.string(from: summary.startDate))."
        }
        if summary.isCurrentCycle {
            let day = store.cycleContext?.cycleDay ?? summary.cycleLength
            let phase = store.cycleContext?.currentPhase.displayName ?? "Tracking"
            return "Current Cycle \(summary.cycleNumber), Day \(day), \(phase) phase."
        }
        return "Cycle \(summary.cycleNumber), \(summary.cycleLength) days, started \(Self.mediumDateFormatter.string(from: summary.startDate))."
    }
}
