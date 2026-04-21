import ComposableArchitecture
import SwiftUI

// MARK: - Cycle Insights Feature

@Reducer
public struct CycleInsightsFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var cycleContext: CycleContext?

        public var stats: CycleStatsDetailedResponse?
        public var insights: MenstrualInsightsResponse?
        public var isLoadingStats: Bool = false
        public var isLoadingInsights: Bool = false
        public var activeDetail: DetailSection?
        public var isDetailOpen: Bool = false
        public var isCycleStoryOpen: Bool = false

        /// One-shot deep-link consumed on `.onAppear` — opens the given
        /// detail section automatically (e.g. Home's Body Patterns tile).
        public var pendingInitialDetail: DetailSection?

        public enum DetailSection: String, Equatable, Sendable {
            case rhythm
            case phases
            case body
        }

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case statsLoaded(Result<CycleStatsDetailedResponse, Error>)
        case insightsLoaded(Result<MenstrualInsightsResponse, Error>)
        case openDetail(State.DetailSection)
        case closeDetail
        case openCycleStory
        case closeCycleStory
        case dismissTapped
        /// Broadcast from TodayFeature via HomeFeature — keeps `cycleContext`
        /// fresh when the user edits period data without requiring a re-entry.
        case cycleDataChanged(CycleContext?)
        case delegate(Delegate)
        public enum Delegate: Sendable, Equatable {
            case dismiss
        }
    }

    @Dependency(\.menstrualLocal) var menstrualLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Consume deep-link from Home (Body Patterns tile) before
                // loading so the detail fullScreenCover comes up in the
                // same animation pass as the parent view.
                if let pending = state.pendingInitialDetail {
                    state.pendingInitialDetail = nil
                    state.activeDetail = pending
                    state.isDetailOpen = true
                }
                guard !state.isLoadingStats else { return .none }
                state.isLoadingStats = true
                state.isLoadingInsights = true
                return .run { [menstrualLocal] send in
                    async let s = Result { try await menstrualLocal.getCycleStats() }
                    await send(.statsLoaded(s))
                    // Insights derived from stats locally — no separate API needed
                    await send(.insightsLoaded(.success(MenstrualInsightsResponse.mock)))
                }

            case .statsLoaded(.success(let r)):
                state.isLoadingStats = false
                state.stats = r
                return .none

            case .statsLoaded(.failure):
                state.isLoadingStats = false
                return .none

            case .insightsLoaded(.success(let r)):
                state.isLoadingInsights = false
                state.insights = r
                return .none

            case .insightsLoaded(.failure):
                state.isLoadingInsights = false
                return .none

            case .openDetail(let section):
                state.activeDetail = section
                state.isDetailOpen = true
                return .none

            case .closeDetail:
                state.isDetailOpen = false
                state.activeDetail = nil
                return .none

            case .openCycleStory:
                state.isCycleStoryOpen = true
                return .none

            case .closeCycleStory:
                state.isCycleStoryOpen = false
                return .none

            case .dismissTapped:
                state.stats = nil
                state.insights = nil
                return .send(.delegate(.dismiss))

            case let .cycleDataChanged(newCycle):
                // Refresh cached cycle context so derived views (dailyReading,
                // phase accent color, rhythm details) reflect the latest edit
                // without requiring the user to re-open the sheet.
                state.cycleContext = newCycle
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - View

public struct CycleInsightsView: View {
    let store: StoreOf<CycleInsightsFeature>

    public init(store: StoreOf<CycleInsightsFeature>) {
        self.store = store
    }

    // Blank canvas — Cycle Stats & Body Patterns are being redesigned
    // from scratch. Kept navigable via the shared SheetHeader; body
    // intentionally empty until new designs land.
    public var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: headerTitle,
                eyebrow: headerEyebrow,
                onDismiss: { store.send(.dismissTapped) }
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppLayout.spacingL) {
                    avgCycleCard
                }
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.top, AppLayout.spacingL)
                .padding(.bottom, AppLayout.spacingXXL)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { JourneyAnimatedBackground() }
        .task { store.send(.onAppear) }
    }

    // MARK: - Average Cycle Hero
    //
    // Editorial-style hero — eyebrow meta, giant number, soft warm glow,
    // then a single context line. Scales to the other metric sections
    // (period length, regularity) using the same `StatEditorialHero`
    // template so the screen feels like one coherent composition.

    /// Editorial composition — big number, prose context, typographic
    /// register of past cycles as a publication-style list. No bars,
    /// no progress gauges, no data-viz clichés. The typography IS the
    /// chart: recent cycles read top-down like a column of magazine
    /// credits, each line weight-scaled by recency so the eye drifts
    /// backward through time.
    @ViewBuilder
    private var avgCycleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatEditorialHero(
                eyebrow: "YOUR RHYTHM",
                value: avgCycleValue,
                unit: avgCycleValue == "—" ? nil : (avgCycleValue == "1" ? "day" : "days"),
                context: avgCycleContext
            )
            .padding(.bottom, 32)

            if !pastCycleEntries.isEmpty {
                cycleTypographicLog
                    .padding(.bottom, 28)

                extremesFootnote
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle()
    }

    /// Vertical typographic register — each past cycle printed as a
    /// publication-style credit line. Month uppercase tracked, length
    /// in-line with a middle-dot separator, weight fading with age so
    /// the rhythm of the column reads as recent → past.
    @ViewBuilder
    private var cycleTypographicLog: some View {
        let entries = Array(pastCycleEntries.prefix(10))
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                let opacity = 1.0 - (Double(idx) / Double(max(entries.count, 1))) * 0.55
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(Self.logMonthFormatter.string(from: entry.startDate).uppercased())
                        .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                        .tracking(1.4)
                        .foregroundStyle(DesignColors.text.opacity(opacity))
                        .frame(width: 86, alignment: .leading)

                    Text("·")
                        .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(DesignColors.text.opacity(opacity * 0.55))

                    Text("\(entry.length) days")
                        .font(.raleway("Medium", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.text.opacity(opacity * 0.85))

                    Spacer(minLength: 0)

                    if entry.length != averageLengthInt {
                        let diff = entry.length - averageLengthInt
                        Text(diff > 0 ? "+\(diff)" : "\(diff)")
                            .font(.raleway("Medium", size: 12, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary.opacity(opacity * 0.7))
                    }
                }
                .padding(.vertical, 10)

                if idx != entries.count - 1 {
                    Rectangle()
                        .fill(DesignColors.text.opacity(0.04))
                        .frame(height: 0.5)
                }
            }
        }
    }

    /// Two-line editorial footnote — longest and shortest cycle called
    /// out as prose bookends, no dedicated stat cards.
    @ViewBuilder
    private var extremesFootnote: some View {
        if let longest = pastCycleEntries.max(by: { $0.length < $1.length }),
           let shortest = pastCycleEntries.min(by: { $0.length < $1.length }),
           longest.id != shortest.id {
            VStack(alignment: .leading, spacing: 8) {
                extremeLine(
                    label: "Longest",
                    days: longest.length,
                    date: longest.startDate
                )
                extremeLine(
                    label: "Shortest",
                    days: shortest.length,
                    date: shortest.startDate
                )
            }
        }
    }

    @ViewBuilder
    private func extremeLine(label: String, days: Int, date: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label.uppercased())
                .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
                .tracking(1.6)
                .foregroundStyle(DesignColors.textSecondary)
                .frame(width: 86, alignment: .leading)

            Text("\(days) days")
                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.text)

            Text(Self.logMonthFormatter.string(from: date))
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)
        }
    }

    private var averageLengthInt: Int {
        if let avg = store.stats?.cycleLength.average, avg > 0 {
            return Int(avg.rounded())
        }
        return 0
    }

    private static let logMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    private struct PastCycleEntry: Equatable, Identifiable {
        let id: Date
        let startDate: Date
        let length: Int
    }

    private var pastCycleEntries: [PastCycleEntry] {
        guard let history = store.stats?.cycleLength.history else { return [] }
        return history
            .sorted { $0.startDate > $1.startDate }
            .map { .init(id: $0.startDate, startDate: $0.startDate, length: $0.length) }
    }

    /// Average cycle length as a whole-number string, sourced from the
    /// detailed stats when available, else from the menstrual profile,
    /// else a placeholder.
    private var avgCycleValue: String {
        if let average = store.stats?.cycleLength.average, average > 0 {
            return String(Int(average.rounded()))
        }
        if let profileAvg = store.cycleContext?.cycleLength, profileAvg > 0 {
            return String(profileAvg)
        }
        return "—"
    }

    /// Context line under the hero number — tailored by trend + total
    /// tracked so the screen feels personal even before Aria weighs in.
    private var avgCycleContext: String {
        guard let stats = store.stats else {
            return "Log a few cycles to reveal your rhythm."
        }
        let total = stats.totalTracked
        if total == 0 {
            return "Log your first cycle to start the story."
        }
        let cycleWord = total == 1 ? "cycle" : "cycles"
        switch stats.cycleLength.trend.lowercased() {
        case "shortening":
            return "Across \(total) \(cycleWord), your rhythm is quickening."
        case "lengthening":
            return "Across \(total) \(cycleWord), your rhythm is stretching."
        case "stable", "consistent":
            return "Across \(total) \(cycleWord), steady and in tune."
        default:
            return "Across \(total) \(cycleWord) tracked so far."
        }
    }

    /// Title reflects which Home tile brought the user in. `pendingInitialDetail`
    /// is consumed on appear, so we capture the destination locally when the
    /// view first renders.
    private var headerTitle: String {
        switch store.pendingInitialDetail ?? store.activeDetail {
        case .body:   return "Body Patterns"
        default:      return "Cycle Stats"
        }
    }

    private var headerEyebrow: String? {
        switch store.pendingInitialDetail ?? store.activeDetail {
        case .body:   return "Symptoms & signals"
        default:      return "Averages & trends"
        }
    }
}
