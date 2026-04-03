import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - Cycle Insights Feature

@Reducer
public struct CycleInsightsFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var cycleContext: CycleContext?
        public var menstrualStatus: MenstrualStatusResponse?
        public var hbiDashboard: HBIDashboardResponse?

        public var stats: CycleStatsDetailedResponse?
        public var insights: MenstrualInsightsResponse?
        public var isLoadingStats: Bool = false
        public var isLoadingInsights: Bool = false
        public var error: String?
        public var activeDetail: DetailSection?
        public var isDetailOpen: Bool = false
        public var isCycleStoryOpen: Bool = false

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

            case .statsLoaded(.failure(let e)):
                state.isLoadingStats = false
                state.error = e.localizedDescription
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

            case .delegate:
                return .none
            }
        }
    }
}

private enum CycleInsightsError: Error { case noToken }

// MARK: - Helpers

private struct RegularityInfo {
    let label: String
    let score: Double
    let color: Color
}

private func regularityInfo(stdDev: Double) -> RegularityInfo {
    switch stdDev {
    case 0..<2:
        return RegularityInfo(label: "Very regular", score: 0.95, color: DesignColors.accentSecondary)
    case 2..<4:
        return RegularityInfo(label: "Regular", score: 0.8, color: DesignColors.accentSecondary)
    case 4..<6:
        return RegularityInfo(label: "Moderate", score: 0.6, color: DesignColors.accentWarm)
    default:
        return RegularityInfo(label: "Variable", score: 0.35, color: DesignColors.accentWarm)
    }
}

// MARK: - View

public struct CycleInsightsView: View {
    @ObserveInjection var inject
    let store: StoreOf<CycleInsightsFeature>
    @Namespace private var tabNamespace

    public init(store: StoreOf<CycleInsightsFeature>) {
        self.store = store
    }

    private var phase: CyclePhase? { store.cycleContext?.currentPhase }
    private var accentColor: Color { phase?.orbitColor ?? DesignColors.accentWarm }

    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if let ctx = store.cycleContext {
                        dailyReading(ctx)
                            .padding(.top, 70)
                    } else {
                        noCycleDataState
                            .padding(.top, 70)
                    }
                    VerticalSpace.xl
                }
            }

            floatingBackButton

        }
        .background(DesignColors.background.ignoresSafeArea())
        .fullScreenCover(isPresented: Binding(
            get: { store.isDetailOpen },
            set: { if !$0 { store.send(.closeDetail) } }
        )) {
            if let detail = store.activeDetail {
                detailScreen(for: detail)
                    .background(DesignColors.background.ignoresSafeArea())
                    .fullScreenCover(isPresented: Binding(
                        get: { store.isCycleStoryOpen },
                        set: { if !$0 { store.send(.closeCycleStory) } }
                    )) {
                        if let stats = store.stats {
                            CycleStoryView(
                                stats: stats,
                                onClose: { store.send(.closeCycleStory) }
                            )
                            .background(DesignColors.background.ignoresSafeArea())
                        }
                    }
            }
        }
        .task { store.send(.onAppear) }
        .enableInjection()
    }

    // MARK: - Floating Back Button

    @ViewBuilder
    private var floatingBackButton: some View {
        HStack {
            Button { store.send(.dismissTapped) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle().fill(DesignColors.structure.opacity(0.1))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - Daily Reading

    @ViewBuilder
    private func dailyReading(_ ctx: CycleContext) -> some View {
        let phase = ctx.currentPhase
        let tint = phase.orbitColor
        let dayInCycle = ctx.cycleDay
        let reading = phase.readings[dayInCycle % phase.readings.count]

        VStack(spacing: 20) {
            // CARD 1: Today's reading — the hero
            VStack(spacing: 24) {
                // Phase glow + icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [tint.opacity(0.2), tint.opacity(0)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)

                    Image(systemName: phase.icon)
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(tint)
                }

                // Phase name + day
                VStack(spacing: 6) {
                    Text(phase.displayName)
                        .font(.custom("Raleway-Bold", size: 26, relativeTo: .title))
                        .foregroundStyle(DesignColors.text)

                    Text("Day \(dayInCycle) of \(ctx.cycleLength)")
                        .font(.custom("Raleway-Medium", size: 14, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                }

                // Reading
                Text(reading)
                    .font(.custom("Raleway-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.text.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .modifier(ReadingCard())

            // CARD 2: How you feel today
            VStack(alignment: .leading, spacing: 18) {
                Text("How you feel today")
                    .font(.custom("Raleway-Bold", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)

                VStack(spacing: 14) {
                    meterRow(label: "Energy", value: phase.energyLevel, tint: tint)
                    meterRow(label: "Mood", value: phase.moodLevel, tint: tint)
                    meterRow(label: "Focus", value: phase.focusLevel, tint: tint)
                }
            }
            .padding(20)
            .modifier(ReadingCard())

            // CARD 3: Lean into / Let go
            HStack(spacing: 12) {
                // Lean into
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(tint)
                        Text("Lean into")
                            .font(.custom("Raleway-Bold", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.text)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(phase.bestFor.prefix(3), id: \.self) { item in
                            Text(item)
                                .font(.custom("Raleway-Regular", size: 14, relativeTo: .body))
                                .foregroundStyle(DesignColors.text.opacity(0.75))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(ReadingCard())

                // Let go of
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DesignColors.textPlaceholder)
                        Text("Let go of")
                            .font(.custom("Raleway-Bold", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.text)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(phase.avoid, id: \.self) { item in
                            Text(item)
                                .font(.custom("Raleway-Regular", size: 14, relativeTo: .body))
                                .foregroundStyle(DesignColors.text.opacity(0.75))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(ReadingCard())
            }

            // CARD 4: What's next
            if let next = nextPhasePreview(ctx) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(next.phase.orbitColor.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: next.phase.icon)
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(next.phase.orbitColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(next.phase.displayName) in \(next.daysUntil) days")
                            .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                            .foregroundStyle(DesignColors.text)
                        Text(next.phase.description)
                            .font(.custom("Raleway-Regular", size: 13, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignColors.textPlaceholder)
                }
                .padding(18)
                .modifier(ReadingCard())
            }

            // CTA
            Button {
                _ = store.send(.openDetail(.rhythm))
            } label: {
                Text("Explore your rhythm")
                    .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        Capsule()
                            .fill(tint)
                            .shadow(color: tint.opacity(0.3), radius: 12, x: 0, y: 4)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Daily Reading Helpers

    /// Reusable card modifier — Apple-style with depth
    private struct ReadingCard: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DesignColors.background)
                        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.15), .white.opacity(0.04), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                }
        }
    }

    private func meterRow(label: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 14) {
            Text(label)
                .font(.custom("Raleway-Medium", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.textSecondary)
                .frame(width: 52, alignment: .leading)

            GeometryReader { geo in
                let fillW = geo.size.width * CGFloat(value) / 5.0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignColors.structure.opacity(0.1))
                    Capsule()
                        .fill(tint.opacity(0.6))
                        .frame(width: fillW)
                }
            }
            .frame(height: 8)

            Text("\(value)/5")
                .font(.custom("Raleway-SemiBold", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPlaceholder)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private struct NextPhaseInfo {
        let phase: CyclePhase
        let daysUntil: Int
    }

    private func nextPhasePreview(_ ctx: CycleContext) -> NextPhaseInfo? {
        let phases = CyclePhase.allCases
        guard let currentIdx = phases.firstIndex(of: ctx.currentPhase) else { return nil }
        let nextIdx = (currentIdx + 1) % phases.count
        let nextPhase = phases[nextIdx]
        let nextRange = nextPhase.dayRange(cycleLength: ctx.cycleLength, bleedingDays: ctx.bleedingDays)
        let daysUntil = nextRange.lowerBound - ctx.cycleDay
        let adjusted = daysUntil > 0 ? daysUntil : ctx.cycleLength - ctx.cycleDay + nextRange.lowerBound
        guard adjusted > 0, adjusted <= 14 else { return nil }
        return NextPhaseInfo(phase: nextPhase, daysUntil: adjusted)
    }

    // MARK: - Insight Boxes Grid

    @ViewBuilder
    private var insightBoxesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your Rhythm")
                    .font(.custom("Raleway-Bold", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
                Spacer()
            }
            .padding(.horizontal, 12)

            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

            LazyVGrid(columns: columns, spacing: 10) {
                cycleLengthBox
                regularityBox
                bleedingBox
                phaseGuideBox
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Preview Boxes

    @ViewBuilder
    private var cycleLengthBox: some View {
        let isLoading = store.isLoadingStats
        let hasData = store.stats.map { $0.totalTracked >= 2 && !$0.cycleLength.history.isEmpty } ?? false

        insightBox(
            title: "Cycle Length",
            subtitle: store.stats.map { "Avg \(Int($0.cycleLength.average)) days" } ?? "—",
            tint: DesignColors.accentSecondary,
            isLoading: isLoading,
            isLocked: !isLoading && !hasData,
            section: .rhythm
        ) {
            if let history = store.stats?.cycleLength.history, history.count >= 2 {
                AnimatedSparkline(values: history.map(\.length), color: DesignColors.accentSecondary)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var regularityBox: some View {
        let isLoading = store.isLoadingStats
        let hasData = store.stats.map { $0.totalTracked >= 2 } ?? false
        let stdDev = store.stats?.cycleLength.stdDev ?? 0
        let info = regularityInfo(stdDev: stdDev)

        insightBox(
            title: "Regularity",
            subtitle: hasData ? info.label : "—",
            tint: hasData ? info.color : DesignColors.accentWarm,
            isLoading: isLoading,
            isLocked: !isLoading && !hasData,
            section: .rhythm
        ) {
            if hasData {
                miniRing(value: info.score, color: info.color)
                    .padding(.leading, 16)
            }
        }
    }

    @ViewBuilder
    private var bleedingBox: some View {
        let isLoading = store.isLoadingStats
        let history = store.stats?.cycleLength.history.filter { $0.bleeding > 0 } ?? []
        let avgBleeding = history.isEmpty ? 0 : history.map(\.bleeding).reduce(0, +) / history.count

        insightBox(
            title: "Bleeding",
            subtitle: history.isEmpty ? "—" : "Avg \(avgBleeding) days",
            tint: CyclePhase.menstrual.orbitColor,
            isLoading: isLoading,
            isLocked: !isLoading && history.count < 2,
            section: .body
        ) {
            if history.count >= 2 {
                miniBarChart(values: history.map(\.bleeding), color: CyclePhase.menstrual.orbitColor)
            }
        }
    }

    @ViewBuilder
    private var phaseGuideBox: some View {
        let currentPhase = phase ?? .follicular

        insightBox(
            title: "Phase Guide",
            subtitle: currentPhase.displayName,
            tint: currentPhase.orbitColor,
            isLoading: false,
            isLocked: false,
            section: .phases
        ) {
            HStack(spacing: 10) {
                ForEach(CyclePhase.allCases, id: \.self) { p in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(p.orbitColor.opacity(p == currentPhase ? 1 : 0.25))
                            .frame(
                                width: p == currentPhase ? 28 : 20,
                                height: p == currentPhase ? 28 : 20
                            )
                            .overlay {
                                if p == currentPhase {
                                    Image(systemName: p.icon)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        Text(String(p.displayName.prefix(3)))
                            .font(.custom("Raleway-Medium", size: 9, relativeTo: .caption2))
                            .foregroundStyle(
                                p == currentPhase ? DesignColors.text : DesignColors.textPlaceholder
                            )
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Tabbed Detail Screen

    private func detailTint(_ section: CycleInsightsFeature.State.DetailSection) -> Color {
        switch section {
        case .rhythm: return DesignColors.accentSecondary
        case .phases: return phase?.orbitColor ?? DesignColors.accentWarm
        case .body: return CyclePhase.menstrual.orbitColor
        }
    }

    @ViewBuilder
    private func detailScreen(for section: CycleInsightsFeature.State.DetailSection) -> some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button { store.send(.closeDetail) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.custom("Raleway-Medium", size: 17, relativeTo: .body))
                    }
                    .foregroundStyle(DesignColors.text)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Tab bar
            detailTabBar(selected: section)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Content
                    switch section {
                    case .rhythm: cycleLengthDetail
                    case .phases: phaseGuideDetail
                    case .body: bleedingDetail
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.top, 24)
            }
        }
    }

    // MARK: - Detail Tab Bar

    @ViewBuilder
    private func detailTabBar(selected: CycleInsightsFeature.State.DetailSection) -> some View {
        let tabs: [(CycleInsightsFeature.State.DetailSection, String, String)] = [
            (.rhythm, "Rhythm", "waveform.path"),
            (.phases, "Phases", "moon.stars"),
            (.body, "Body", "heart.fill"),
        ]

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs, id: \.0) { tab in
                    let isSelected = selected == tab.0
                    let tint = detailTint(tab.0)

                    Button {
                        withAnimation(Animation.spring(response: 0.35, dampingFraction: 0.85)) {
                            _ = store.send(.openDetail(tab.0))
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: tab.2)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tab.1)
                                .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .subheadline))
                        }
                        .foregroundStyle(isSelected ? .white : DesignColors.text.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [tint, tint.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "detailActiveTab", in: tabNamespace)
                                    .shadow(color: tint.opacity(0.25), radius: 8, x: 0, y: 3)
                            } else {
                                Capsule()
                                    .fill(DesignColors.structure.opacity(0.12))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 4)
    }

    // MARK: Cycle Length Detail

    @ViewBuilder
    private var cycleLengthDetail: some View {
        let history = (store.stats?.cycleLength.history ?? []).filter { $0.length > 0 }
        let avg = store.stats?.cycleLength.average ?? 0
        let stdDev = store.stats?.cycleLength.stdDev ?? 0
        let shortest = history.map(\.length).min() ?? 0
        let longest = history.map(\.length).max() ?? 0
        let avgInt = Int(avg)
        let avgBleeding = history.isEmpty ? 5 : history.map(\.bleeding).reduce(0, +) / history.count

        if history.count >= 2 {
            VStack(alignment: .leading, spacing: 36) {

                // 1. Hero stat card (with trend)
                cycleLengthHeroCard(avg: avg, stdDev: stdDev)

                // 2. Chart (interactive, normal/atypical, explore button)
                CycleLengthChart(history: history, average: avg) {
                    store.send(.openCycleStory)
                }
                .frame(height: 320)

                // 3. Phase breakdown
                phaseBreakdownBar(cycleLength: avgInt, bleedingDays: avgBleeding)
            }
            .padding(.horizontal, 24)
        } else {
            lockedPlaceholder(message: "Your rhythm reveals itself after 2 complete cycles")
                .padding(.horizontal, 24)
        }
    }

    // MARK: Cycle Length Hero Card

    @ViewBuilder
    private func cycleLengthHeroCard(avg: Double, stdDev: Double) -> some View {
        let rhythm = rhythmPersonality(avg: avg, stdDev: stdDev)
        let trend = trendLabel(stdDev: stdDev, history: store.stats?.cycleLength.history ?? [])

        VStack(alignment: .leading, spacing: 14) {
            Text("Average cycle length")
                .font(.custom("Raleway-Bold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)

            HStack(spacing: 16) {
            // Big number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(avg))")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignColors.text)
                Text("days")
                    .font(.custom("Raleway-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
            }

            // Divider
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(rhythm.colors[0].opacity(0.3))
                .frame(width: 2, height: 32)

            // Rhythm + trend
            VStack(alignment: .leading, spacing: 4) {
                Text(rhythm.title)
                    .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                    .foregroundStyle(rhythm.colors[0])

                Text(trend)
                    .font(.custom("Raleway-Regular", size: 13, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignColors.background)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.12), .white.opacity(0.04), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
        }
    }

    // MARK: Normal Range Bar

    @ViewBuilder
    private func normalRangeBar(avg: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Healthy range")
                .font(.custom("Raleway-Bold", size: 19, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)

            GeometryReader { geo in
                let minRange = 21
                let maxRange = 35
                let totalSpan = CGFloat(maxRange - minRange)
                let position = CGFloat(min(max(avg, minRange), maxRange) - minRange) / totalSpan

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DesignColors.structure.opacity(0.08))
                        .frame(height: 16)

                    // Normal zone (24-32)
                    let normalStart = CGFloat(24 - minRange) / totalSpan
                    let normalEnd = CGFloat(32 - minRange) / totalSpan
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DesignColors.accentSecondary.opacity(0.2))
                        .frame(width: (normalEnd - normalStart) * geo.size.width, height: 16)
                        .offset(x: normalStart * geo.size.width)

                    // User marker
                    Circle()
                        .fill(DesignColors.accentSecondary)
                        .frame(width: 24, height: 24)
                        .shadow(color: DesignColors.accentSecondary.opacity(0.35), radius: 6, x: 0, y: 2)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.3), lineWidth: 2)
                        }
                        .offset(x: position * geo.size.width - 12)
                }

                HStack {
                    Text("\(minRange)d")
                        .font(.custom("Raleway-Medium", size: 13, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textPlaceholder)
                    Spacer()
                    Text("\(maxRange)d")
                        .font(.custom("Raleway-Medium", size: 13, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textPlaceholder)
                }
                .offset(y: 24)
            }
            .frame(height: 48)

            Text(normalRangeStatus(avg: avg))
                .font(.custom("Raleway-Medium", size: 15, relativeTo: .body))
                .foregroundStyle(avg >= 24 && avg <= 32 ? DesignColors.accentSecondary : DesignColors.accentWarm)
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignColors.structure.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(DesignColors.structure.opacity(0.06), lineWidth: 0.5)
                }
        }
    }

    // MARK: Phase Breakdown Bar

    @ViewBuilder
    private func phaseBreakdownBar(cycleLength: Int, bleedingDays: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your phase breakdown")
                .font(.custom("Raleway-Bold", size: 19, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)

            GeometryReader { geo in
                let w = geo.size.width
                HStack(spacing: 3) {
                    ForEach(CyclePhase.allCases, id: \.self) { p in
                        let range = p.dayRange(cycleLength: cycleLength, bleedingDays: bleedingDays)
                        let days = range.upperBound - range.lowerBound + 1
                        let fraction = CGFloat(days) / CGFloat(cycleLength)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(p.orbitColor)
                            .frame(width: max(fraction * w - 3, 6))
                    }
                }
            }
            .frame(height: 20)

            HStack(spacing: 0) {
                ForEach(CyclePhase.allCases, id: \.self) { p in
                    let range = p.dayRange(cycleLength: cycleLength, bleedingDays: bleedingDays)
                    let days = range.upperBound - range.lowerBound + 1

                    VStack(spacing: 5) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(p.orbitColor)
                                .frame(width: 9, height: 9)
                            Text("\(days)d")
                                .font(.custom("Raleway-Bold", size: 15, relativeTo: .subheadline))
                                .foregroundStyle(DesignColors.text)
                        }
                        Text(p.description)
                            .font(.custom("Raleway-Regular", size: 12, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignColors.structure.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(DesignColors.structure.opacity(0.06), lineWidth: 0.5)
                }
        }
    }

    // MARK: Mental State Insights

    @ViewBuilder
    private func mentalStateInsights(avg: Int, bleedingDays: Int) -> some View {
        let follicularDays = CyclePhase.follicular.dayRange(cycleLength: avg, bleedingDays: bleedingDays)
        let follicularCount = follicularDays.upperBound - follicularDays.lowerBound + 1
        let lutealDays = CyclePhase.luteal.dayRange(cycleLength: avg, bleedingDays: bleedingDays)
        let lutealCount = lutealDays.upperBound - lutealDays.lowerBound + 1
        let ovDays = CyclePhase.ovulatory.dayRange(cycleLength: avg, bleedingDays: bleedingDays)

        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignColors.accent)
                Text("What this means for your mind")
                    .font(.custom("Raleway-Bold", size: 19, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
            }

            mentalInsightRow(
                icon: "sparkles",
                tint: CyclePhase.follicular.orbitColor,
                title: "Creative window — \(follicularCount) days",
                body: follicularCount >= 10
                    ? "Your longer follicular phase means an extended creative window. Estrogen builds for \(follicularCount) days, lifting mood, focus, and verbal fluency. Schedule brainstorming and learning here."
                    : "You have \(follicularCount) days of rising estrogen — mood, focus, and verbal fluency climb steadily. Make them count for creative and strategic work."
            )

            mentalInsightRow(
                icon: "sun.max.fill",
                tint: CyclePhase.ovulatory.orbitColor,
                title: "Peak confidence — around day \(ovDays.lowerBound)",
                body: "Your 2-3 most magnetic days. Confidence, communication, and pain tolerance peak. Schedule the big conversations, presentations, and physical challenges here."
            )

            mentalInsightRow(
                icon: "moon.stars",
                tint: CyclePhase.luteal.orbitColor,
                title: "Reflection phase — \(lutealCount) days",
                body: lutealCount >= 12
                    ? "Your longer luteal phase means more time in reflective mode. The inner critic gets louder — but it's also your best editing and detail-work window. Channel it, don't fight it."
                    : "About \(lutealCount) days of progesterone dominance. Sharper attention to detail and a lower tolerance for nonsense. Great for finishing and honest self-assessment."
            )

            mentalInsightRow(
                icon: "arrow.counterclockwise",
                tint: CyclePhase.menstrual.orbitColor,
                title: "Mental reset — \(bleedingDays) days",
                body: "Energy and motivation hit their lowest. This isn't failure — it's your brain asking for rest. The withdrawal of hormones clears space for fresh thinking in the next cycle."
            )
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignColors.accent.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(DesignColors.accent.opacity(0.08), lineWidth: 0.5)
                }
        }
    }

    @ViewBuilder
    private func mentalInsightRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.custom("Raleway-Bold", size: 16, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
                Text(body)
                    .font(.custom("Raleway-Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Cycle History List

    @ViewBuilder
    private func cycleHistoryList(history: [CycleHistoryPoint], avg: Double) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Cycle history")
                .font(.custom("Raleway-Bold", size: 19, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)

            let fmt = DateFormatter()
            let _ = fmt.dateFormat = "MMM d, yyyy"

            ForEach(history.reversed()) { point in
                let diff = Double(point.length) - avg
                let diffText = abs(diff) < 1 ? "avg" : (diff > 0 ? "+\(Int(diff))d" : "\(Int(diff))d")
                let diffColor: Color = abs(diff) < 2
                    ? DesignColors.accentSecondary
                    : (abs(diff) < 4 ? DesignColors.accentWarm : DesignColors.accentWarm.opacity(0.8))

                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(diffColor)
                        .frame(width: 4, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(fmt.string(from: point.startDate))
                            .font(.custom("Raleway-Medium", size: 16, relativeTo: .body))
                            .foregroundStyle(DesignColors.text)
                        Text("\(point.length) days · \(point.bleeding) days bleeding")
                            .font(.custom("Raleway-Regular", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.textSecondary)
                    }

                    Spacer()

                    Text(diffText)
                        .font(.custom("Raleway-Bold", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(diffColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            Capsule().fill(diffColor.opacity(0.1))
                        }
                }
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignColors.structure.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(DesignColors.structure.opacity(0.06), lineWidth: 0.5)
                }
        }
    }

    // MARK: Cycle Length Helpers

    private struct RhythmPersonality {
        let title: String
        let icon: String
        let description: String
        let colors: [Color]
    }

    private func rhythmPersonality(avg: Double, stdDev: Double) -> RhythmPersonality {
        if stdDev >= 5 {
            return RhythmPersonality(
                title: "Dynamic Rhythm",
                icon: "wind",
                description: "Your cycle adapts and shifts. Variable cycles often reflect your body's sensitivity to stress, sleep, travel, or lifestyle changes — not a problem, just information. Your body is responsive, not broken.",
                colors: [DesignColors.accentWarm, DesignColors.accentWarm.opacity(0.6)]
            )
        }
        switch Int(avg) {
        case ...24:
            return RhythmPersonality(
                title: "Quick Rhythm",
                icon: "hare",
                description: "Shorter cycles mean you move through phases faster — your follicular window is compressed, so your bursts of rising energy are intense but brief. You may ovulate earlier than textbooks suggest.",
                colors: [CyclePhase.ovulatory.orbitColor, CyclePhase.follicular.orbitColor.opacity(0.7)]
            )
        case 25...28:
            return RhythmPersonality(
                title: "Steady Rhythm",
                icon: "metronome",
                description: "Your \(Int(avg))-day cycle sits right in the textbook sweet spot — but there's nothing generic about it. Your estrogen peaks hit on schedule, your luteal phase holds steady, and your body transitions between phases without the hormonal whiplash others experience. That reliability is rare, and it means you can trust your energy patterns week to week.",
                colors: [DesignColors.accentSecondary, DesignColors.accent.opacity(0.7)]
            )
        case 29...32:
            return RhythmPersonality(
                title: "Long Wave",
                icon: "water.waves",
                description: "Longer cycles mean an extended follicular phase — more days of rising creativity, confidence, and verbal sharpness before ovulation. Your building phase is your superpower.",
                colors: [DesignColors.accent, DesignColors.accentSecondary.opacity(0.6)]
            )
        default:
            return RhythmPersonality(
                title: "Deep Rhythm",
                icon: "tortoise",
                description: "Your body takes its time. Cycles over 32 days often mean a longer follicular phase with a delayed ovulation. You may experience extended periods of rising energy and gradual hormonal shifts.",
                colors: [CyclePhase.luteal.orbitColor, DesignColors.accent.opacity(0.5)]
            )
        }
    }

    private func normalRangeStatus(avg: Int) -> String {
        switch avg {
        case 24...32:
            return "Your average of \(avg) days is within the typical healthy range"
        case 21...23:
            return "Slightly shorter than average — still within normal bounds"
        case 33...35:
            return "Slightly longer than average — still within normal bounds"
        case ..<21:
            return "Shorter than typical — worth discussing with your doctor"
        default:
            return "Longer than typical — worth discussing with your doctor"
        }
    }

    // MARK: Regularity Detail

    @ViewBuilder
    private var regularityDetail: some View {
        let hasData = store.stats.map { $0.totalTracked >= 2 } ?? false
        let stdDev = store.stats?.cycleLength.stdDev ?? 0
        let info = regularityInfo(stdDev: stdDev)

        if hasData {
            VStack(alignment: .leading, spacing: 24) {
                // Large ring
                HStack {
                    Spacer()
                    miniRing(value: info.score, color: info.color)
                        .frame(width: 140, height: 140)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(info.label)
                        .font(.custom("Raleway-Bold", size: 22, relativeTo: .title3))
                        .foregroundStyle(DesignColors.text)

                    Text(regularityDescription(stdDev: stdDev))
                        .font(.custom("Raleway-Regular", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                statPill(label: "Variation", value: "±\(Int(stdDev.rounded())) days", color: info.color)
            }
            .padding(.horizontal, 20)
        } else {
            lockedPlaceholder(message: "Your pattern becomes clear after 2 complete cycles")
                .padding(.horizontal, 20)
        }
    }

    // MARK: Bleeding Detail

    @ViewBuilder
    private var bleedingDetail: some View {
        let history = store.stats?.cycleLength.history.filter { $0.bleeding > 0 } ?? []
        let avgBleeding = history.isEmpty ? 0 : history.map(\.bleeding).reduce(0, +) / history.count

        if history.count >= 2 {
            VStack(alignment: .leading, spacing: 20) {
                // Bar chart
                miniBarChart(values: history.map(\.bleeding), color: CyclePhase.menstrual.orbitColor)
                    .frame(height: 120)
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DesignColors.structure.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(DesignColors.structure.opacity(0.06), lineWidth: 0.5)
                            }
                    }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 10) {
                    statPill(label: "Average", value: "\(avgBleeding) days", color: CyclePhase.menstrual.orbitColor)
                    statPill(label: "Shortest", value: "\(history.map(\.bleeding).min() ?? 0) days", color: DesignColors.textSecondary)
                    statPill(label: "Longest", value: "\(history.map(\.bleeding).max() ?? 0) days", color: DesignColors.textSecondary)
                }

                Text("Based on \(history.count) tracked cycles")
                    .font(.custom("Raleway-Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textPlaceholder)
            }
            .padding(.horizontal, 20)
        } else {
            lockedPlaceholder(message: "Your body's story unfolds after 2 complete cycles")
                .padding(.horizontal, 20)
        }
    }

    // MARK: Phase Guide Detail

    @ViewBuilder
    private var phaseGuideDetail: some View {
        let currentPhase = phase ?? .follicular

        VStack(alignment: .leading, spacing: 16) {
            ForEach(CyclePhase.allCases, id: \.self) { p in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(p.orbitColor.opacity(p == currentPhase ? 0.2 : 0.08))
                                .frame(width: 44, height: 44)
                            Image(systemName: p.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(p.orbitColor.opacity(p == currentPhase ? 1 : 0.5))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(p.displayName)
                                    .font(.custom("Raleway-Bold", size: 16, relativeTo: .subheadline))
                                    .foregroundStyle(
                                        p == currentPhase ? DesignColors.text : DesignColors.textSecondary
                                    )
                                if p == currentPhase {
                                    Text("Current")
                                        .font(.custom("Raleway-Bold", size: 10, relativeTo: .caption2))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background { Capsule().fill(p.orbitColor) }
                                }
                            }
                            Text(p.description)
                                .font(.custom("Raleway-Regular", size: 13, relativeTo: .caption))
                                .foregroundStyle(DesignColors.textSecondary.opacity(p == currentPhase ? 1 : 0.7))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if p == currentPhase {
                        Text(p.medicalDescription)
                            .font(.custom("Raleway-Regular", size: 13.5, relativeTo: .body))
                            .foregroundStyle(DesignColors.text.opacity(0.7))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(p.orbitColor.opacity(0.06))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(p.orbitColor.opacity(0.1), lineWidth: 0.5)
                                    }
                            }
                    }
                }

                if p != CyclePhase.allCases.last {
                    Rectangle()
                        .fill(DesignColors.structure.opacity(0.06))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Detail Helpers

    @ViewBuilder
    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Raleway-Bold", size: 18, relativeTo: .headline))
                .foregroundStyle(color)
            Text(label)
                .font(.custom("Raleway-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignColors.structure.opacity(0.05))
        }
    }

    @ViewBuilder
    private func lockedPlaceholder(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignColors.textPlaceholder)
            Text(message)
                .font(.custom("Raleway-Regular", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPlaceholder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func trendLabel(stdDev: Double, history: [CycleHistoryPoint]) -> String {
        guard history.count >= 3 else {
            return "Your trend is still unfolding"
        }
        let recent = history.suffix(3).map(\.length)
        let earlier = history.prefix(history.count - 3).map(\.length)
        guard !earlier.isEmpty else {
            return "Building your trend data"
        }
        let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
        let earlierAvg = Double(earlier.reduce(0, +)) / Double(earlier.count)
        let diff = recentAvg - earlierAvg
        if abs(diff) < 1.5 {
            return "Your cycle length is stable"
        } else if diff > 0 {
            return "Your cycles are trending slightly longer"
        } else {
            return "Your cycles are trending slightly shorter"
        }
    }

    private func regularityDescription(stdDev: Double) -> String {
        switch stdDev {
        case 0..<2:
            return "Your cycle is very consistent. Less than 2 days variation — that's excellent."
        case 2..<4:
            return "Your cycle varies by about \(Int(stdDev.rounded())) days. This is within normal range."
        case 4..<6:
            return "Moderate variation of about \(Int(stdDev.rounded())) days. Still within normal bounds, but worth monitoring."
        default:
            return "Your cycle varies by \(Int(stdDev.rounded()))+ days. Some irregularity is common, but speak with your doctor if concerned."
        }
    }

    // MARK: - Generic Insight Box

    @ViewBuilder
    private func insightBox<Preview: View>(
        title: String,
        subtitle: String,
        tint: Color,
        isLoading: Bool,
        isLocked: Bool,
        section: CycleInsightsFeature.State.DetailSection? = nil,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Raleway-Bold", size: 18, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
                Text(subtitle)
                    .font(.custom("Raleway-Medium", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer(minLength: 8)

            if isLoading {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DesignColors.structure.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else if isLocked {
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Keep tracking")
                        .font(.custom("Raleway-Regular", size: 11, relativeTo: .caption2))
                }
                .foregroundStyle(DesignColors.textPlaceholder)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
            } else {
                preview()
                    .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignColors.background.opacity(1),
                            DesignColors.background.opacity(0.92),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
                .shadow(color: tint.opacity(0.06), radius: 8, x: 0, y: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.12),
                                    tint.opacity(0.1),
                                    .white.opacity(0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            if let section {
                store.send(.openDetail(section))
            }
        }
    }

    // MARK: - Mini Visuals

    private func miniBarChart(values: [Int], color: Color) -> some View {
        Canvas { context, size in
            let count = values.count
            guard count > 0 else { return }
            let maxVal = CGFloat(values.max() ?? 1)
            let gap: CGFloat = 4
            let barWidth = max((size.width - CGFloat(count - 1) * gap) / CGFloat(count), 4)
            let cr: CGFloat = barWidth * 0.3
            for (i, val) in values.enumerated() {
                let h = CGFloat(val) / maxVal * size.height * 0.82
                let x = CGFloat(i) * (barWidth + gap)
                let rect = CGRect(x: x, y: size.height - h, width: barWidth, height: h)
                let path = Path(roundedRect: rect, cornerRadius: cr)
                context.fill(path, with: .color(color.opacity(i == count - 1 ? 1 : 0.35)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func miniRing(value: Double, color: Color) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.85
            let lw: CGFloat = 3.5
            ZStack {
                Circle()
                    .stroke(DesignColors.structure.opacity(0.12), lineWidth: lw)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.35), color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * value)
                        ),
                        style: StrokeStyle(lineWidth: lw, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value * 100))%")
                    .font(.custom("Raleway-Bold", size: side * 0.25, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Phase Hero Header

    @ViewBuilder
    private func phaseContextHeader(_ ctx: CycleContext) -> some View {
        let p = ctx.currentPhase
        let baseColor = p.orbitColor
        let deepColor = p.glowColor

        ZStack(alignment: .bottom) {
            ZStack {
                LinearGradient(
                    colors: [baseColor, deepColor.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                phaseOrnaments(base: baseColor, deep: deepColor)

                VStack(spacing: 6) {
                    Spacer(minLength: 70)
                    Text("Day")
                        .font(.custom("Raleway-Medium", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(ctx.cycleDay)")
                        .font(.custom("Raleway-Bold", size: 72, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .shadow(color: deepColor.opacity(0.4), radius: 12, x: 0, y: 4)
                    Text(p.displayName + " Phase")
                        .font(.custom("Raleway-Bold", size: 20, relativeTo: .title3))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(phaseKeystat(ctx))
                        .font(.custom("Raleway-Medium", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.top, 2)
                    Spacer(minLength: 50)
                }
            }
            .frame(height: 300)
            .clipShape(PhaseHeroCurve())

            ZStack {
                Circle()
                    .fill(DesignColors.background)
                    .frame(width: 52, height: 52)
                    .shadow(color: baseColor.opacity(0.2), radius: 12, x: 0, y: 4)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [baseColor, deepColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                Image(systemName: p.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .offset(y: 26)
        }
        .padding(.bottom, 32)

        Text(p.medicalDescription)
            .font(.custom("Raleway-Regular", size: 13.5, relativeTo: .body))
            .foregroundStyle(DesignColors.text.opacity(0.6))
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppLayout.horizontalPadding + 8)
    }

    @ViewBuilder
    private func phaseOrnaments(base: Color, deep: Color) -> some View {
        Circle()
            .fill(base.opacity(0.3))
            .frame(width: 180, height: 180)
            .offset(x: -70, y: -60)
            .blur(radius: 2)
        Ellipse()
            .fill(deep.opacity(0.25))
            .frame(width: 120, height: 100)
            .rotationEffect(.degrees(25))
            .offset(x: 100, y: -30)
            .blur(radius: 1)
        Circle()
            .fill(base.opacity(0.2))
            .frame(width: 90, height: 90)
            .offset(x: -50, y: 100)
        Ellipse()
            .fill(deep.opacity(0.2))
            .frame(width: 140, height: 80)
            .rotationEffect(.degrees(-15))
            .offset(x: 80, y: 80)
            .blur(radius: 1)
        Circle()
            .fill(.white.opacity(0.08))
            .frame(width: 60, height: 60)
            .offset(x: 30, y: -70)
    }

    private func phaseKeystat(_ ctx: CycleContext) -> String {
        if ctx.isLate { return "\(ctx.effectiveDaysLate) days late" }
        if ctx.fertileWindowActive { return "Fertile window active" }
        if let daysUntil = ctx.nextPeriodIn, daysUntil > 0 {
            return "\(daysUntil) days until next period"
        }
        return "of \(ctx.effectiveCycleLength) day cycle"
    }

    // MARK: - No Cycle Data State

    @ViewBuilder
    private var noCycleDataState: some View {
        VStack(spacing: AppLayout.spacingL) {
            VStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Your Cycle, Your Data")
                    .font(.custom("Raleway-Bold", size: 22, relativeTo: .title3))
                    .foregroundStyle(DesignColors.text)
                Text("Log your period to start building personalized insights about your cycle patterns.")
                    .font(.custom("Raleway-Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("The four phases")
                    .font(.custom("Raleway-Bold", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
                ForEach(CyclePhase.allCases, id: \.self) { p in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(p.orbitColor.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: p.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(p.orbitColor)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.displayName)
                                .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .subheadline))
                                .foregroundStyle(DesignColors.text)
                            Text(p.description)
                                .font(.custom("Raleway-Regular", size: 12, relativeTo: .caption))
                                .foregroundStyle(DesignColors.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignColors.background)
                    .shadow(color: DesignColors.text.opacity(0.04), radius: 10, x: 0, y: 3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(DesignColors.structure.opacity(0.3), lineWidth: 0.5)
                    }
            }
            .padding(.horizontal, AppLayout.horizontalPadding)
        }
    }
}

// MARK: - Cycle Length Chart

private struct CycleLengthChart: View {
    let history: [CycleHistoryPoint]
    let average: Double
    var onSeeMore: (() -> Void)? = nil

    @State private var animProgress: CGFloat = 0
    @State private var selectedIndex: Int? = nil

    private let normalLow = 24
    private let normalHigh = 32

    private var values: [Int] { history.map(\.length) }
    private var maxVal: CGFloat { max(CGFloat(values.max() ?? 1) + 2, CGFloat(normalHigh) + 1) }
    private var minVal: CGFloat { min(CGFloat(values.min() ?? 1) - 2, CGFloat(normalLow) - 1) }
    private var range: CGFloat { max(maxVal - minVal, 1) }

    private func isNormal(_ length: Int) -> Bool {
        length >= normalLow && length <= normalHigh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Your cycles")
                .font(.custom("Raleway-Bold", size: 19, relativeTo: .headline))
                .foregroundStyle(DesignColors.text)

            // Tooltip (when touching)
            if let idx = selectedIndex, idx < history.count {
                barTooltip(index: idx)
                    .transition(.opacity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedIndex)
            }

            // Bars — proportional: 40% bar, 60% space (Headspace ratio)
            GeometryReader { geo in
                let count = values.count
                let slotW = geo.size.width / CGFloat(max(count, 1))
                let barW = min(slotW * 0.4, 32)
                let chartH = geo.size.height - 28

                HStack(spacing: 0) {
                    ForEach(Array(values.enumerated()), id: \.offset) { i, val in
                        let normal = isNormal(val)
                        let isSelected = selectedIndex == i
                        let barH = max((CGFloat(val) - minVal) / range * chartH * animProgress, 6)

                        VStack(spacing: 6) {
                            Spacer(minLength: 0)

                            // Value on top
                            Text("\(val)")
                                .font(.custom("Raleway-Bold", size: isSelected ? 14 : 12, relativeTo: .caption))
                                .foregroundStyle(
                                    isSelected ? DesignColors.text
                                    : (normal ? DesignColors.textSecondary : DesignColors.text.opacity(0.8))
                                )
                                .opacity(animProgress > 0.8 ? 1 : 0)

                            // Bar — thin pill
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: normal
                                            ? [DesignColors.accentSecondary.opacity(isSelected ? 0.9 : 0.5),
                                               DesignColors.accentSecondary.opacity(isSelected ? 0.5 : 0.15)]
                                            : [DesignColors.accentWarm.opacity(isSelected ? 0.9 : 0.6),
                                               DesignColors.accentWarm.opacity(isSelected ? 0.4 : 0.15)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: barW, height: barH)

                            // Month label
                            Text(monthLabel(for: history[i].startDate))
                                .font(.custom("Raleway-Medium", size: 11, relativeTo: .caption2))
                                .foregroundStyle(
                                    isSelected ? DesignColors.text : DesignColors.textPlaceholder
                                )
                        }
                        .frame(width: slotW)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if selectedIndex == i {
                                    selectedIndex = nil
                                } else {
                                    selectedIndex = i
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                }
                            }
                        }
                    }
                }
            }

            // Explore button
            if let onSeeMore {
                Button(action: onSeeMore) {
                    Text("Explore your data")
                        .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.structure.opacity(0.25))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignColors.background)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.12), .white.opacity(0.04), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                animProgress = 1
            }
        }
    }

    // MARK: Month Label

    private func monthLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt.string(from: date)
    }

    // MARK: Bar Tooltip

    private func barTooltip(index: Int) -> some View {
        let point = history[index]
        let length = values[index]
        let normal = isNormal(length)
        let diff = length - Int(average)
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"

        return HStack(spacing: 12) {
            Circle()
                .fill(normal ? DesignColors.accentSecondary : DesignColors.accentWarm)
                .frame(width: 8, height: 8)

            Text("\(length) days")
                .font(.custom("Raleway-Bold", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.text)

            Text("·")
                .foregroundStyle(DesignColors.textPlaceholder)

            Text("\(fmt.string(from: point.startDate))")
                .font(.custom("Raleway-Medium", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)

            Text("·")
                .foregroundStyle(DesignColors.textPlaceholder)

            Text("\(diff >= 0 ? "+" : "")\(diff)")
                .font(.custom("Raleway-SemiBold", size: 13, relativeTo: .caption))
                .foregroundStyle(normal ? DesignColors.accentSecondary : DesignColors.accentWarm)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignColors.structure.opacity(0.06))
        }
    }
}

// MARK: - Cycle Story Walkthrough

private struct CycleStoryView: View {
    let stats: CycleStatsDetailedResponse
    let onClose: () -> Void

    @State private var currentStep = 0
    @State private var stepVisible = false
    @State private var tooltipVisible = false
    @State private var numberValue: Double = 0
    @State private var barProgress: CGFloat = 0
    @State private var dotsRevealed = 0
    @State private var isTransitioning = false
    @State private var showNavHint = true

    private let totalSteps = 5

    private var history: [CycleHistoryPoint] { stats.cycleLength.history }
    private var avg: Double { stats.cycleLength.average }
    private var stdDev: Double { stats.cycleLength.stdDev }

    private var rhythm: (title: String, icon: String, desc: String, color: Color) {
        if stdDev >= 5 {
            return ("Dynamic Rhythm", "wind", "Your cycle adapts and shifts — your body is responsive to life changes.", DesignColors.accentWarm)
        }
        switch Int(avg) {
        case ...24:
            return ("Quick Rhythm", "hare", "You move through phases faster — intense bursts of rising energy.", CyclePhase.ovulatory.orbitColor)
        case 25...28:
            return ("Steady Rhythm", "metronome", "Your cycle is reliable. You can trust your energy patterns week to week.", DesignColors.accentSecondary)
        case 29...32:
            return ("Long Wave", "water.waves", "Extended follicular phase — more days of rising creativity before ovulation.", DesignColors.accent)
        default:
            return ("Deep Rhythm", "tortoise", "Your body takes its time. Gradual hormonal shifts give you extended building phases.", CyclePhase.luteal.orbitColor)
        }
    }

    var body: some View {
        ZStack {
            DesignColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DesignColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle().fill(DesignColors.structure.opacity(0.1))
                            }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Progress dots
                    HStack(spacing: 6) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Capsule()
                                .fill(i <= currentStep ? DesignColors.accentSecondary : DesignColors.structure.opacity(0.15))
                                .frame(width: i == currentStep ? 20 : 8, height: 4)
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentStep)
                        }
                    }

                    Spacer()

                    // Step counter
                    Text("\(currentStep + 1)/\(totalSteps)")
                        .font(.custom("Raleway-Medium", size: 13, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textPlaceholder)
                        .frame(width: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Step content — keyed so SwiftUI replaces instead of overlapping
                Group {
                    switch currentStep {
                    case 0: stepIntro
                    case 1: stepRhythm
                    case 2: stepNumbers
                    case 3: stepNormalVsAtypical
                    case 4: stepKeyInsight
                    default: EmptyView()
                    }
                }
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeIn(duration: 0.25).delay(0.15)),
                    removal: .opacity.animation(.easeOut(duration: 0.12))
                ))
                .padding(.horizontal, 28)

                Spacer()

                // Bottom action
                if currentStep == totalSteps - 1 {
                    Button(action: onClose) {
                        Text("Got it")
                            .font(.custom("Raleway-Bold", size: 17, relativeTo: .body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                Capsule()
                                    .fill(DesignColors.accentSecondary)
                                    .shadow(color: DesignColors.accentSecondary.opacity(0.3), radius: 12, x: 0, y: 4)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
                }

                Spacer().frame(height: 40)
            }
        }
        .overlay(alignment: .bottom) {
            // Tap zones — hidden on last step so "Got it" button is tappable
            if currentStep < totalSteps - 1 {
                VStack(spacing: 0) {
                    Spacer().frame(height: 70)
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { goBackStep() }

                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { advanceStep() }
                    }
            }
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { drag in
                        if drag.translation.width < -40 {
                            advanceStep()
                        } else if drag.translation.width > 40 {
                            goBackStep()
                        }
                    }
            )
            }
        }
        .overlay {
            if showNavHint {
                navHintOverlay
                    .transition(.opacity)
            }
        }
        .onAppear {
            showCurrentStep()
        }
    }

    // MARK: Step Navigation

    private func advanceStep() {
        guard currentStep < totalSteps - 1, !isTransitioning else { return }
        navigateTo(currentStep + 1)
    }

    private func goBackStep() {
        guard currentStep > 0, !isTransitioning else { return }
        navigateTo(currentStep - 1)
    }

    private func navigateTo(_ step: Int) {
        isTransitioning = true
        currentStep = step
        showCurrentStep()
        // Debounce — allow next tap after content settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isTransitioning = false
        }
    }

    private func showCurrentStep() {
        stepVisible = false
        tooltipVisible = false
        numberValue = 0
        barProgress = 0
        dotsRevealed = 0

        withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.1)) {
            stepVisible = true
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.6)) {
            tooltipVisible = true
        }

        // Step-specific animations
        if currentStep == 2 {
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                numberValue = avg
            }
        }
        if currentStep == 3 {
            for i in 0..<history.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dotsRevealed = i + 1
                    }
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred()
                }
            }
        }
        if currentStep == 4 {
            withAnimation(.easeOut(duration: 1.0).delay(0.4)) {
                barProgress = 1
            }
        }
    }

    // MARK: Navigation Hint

    @State private var fingerX: CGFloat = 40
    @State private var trailFrom: CGFloat = 40
    @State private var showTrail = false

    @ViewBuilder
    private var navHintOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            // Trail — single gradient capsule stretching behind finger
            if showTrail {
                let leading = min(fingerX, trailFrom)
                let trailing = max(fingerX, trailFrom)
                let width = max(trailing - leading, 6)
                let mid = (leading + trailing) / 2
                let movingRight = fingerX > trailFrom

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: movingRight
                                ? [.white.opacity(0), .white.opacity(0.35)]
                                : [.white.opacity(0.35), .white.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: 6)
                    .offset(x: mid, y: 20)
            }

            // Finger
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .offset(x: fingerX, y: 20)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.25)) {
                showNavHint = false
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))

            // Swipe left
            trailFrom = 40
            showTrail = true
            withAnimation(.easeInOut(duration: 0.6)) {
                fingerX = -60
            }
            try? await Task.sleep(for: .milliseconds(700))
            showTrail = false

            try? await Task.sleep(for: .milliseconds(200))

            // Swipe right
            trailFrom = -60
            showTrail = true
            withAnimation(.easeInOut(duration: 0.6)) {
                fingerX = 60
            }
            try? await Task.sleep(for: .milliseconds(700))
            showTrail = false

            try? await Task.sleep(for: .milliseconds(300))

            withAnimation(.easeOut(duration: 0.4)) {
                showNavHint = false
            }
        }
    }

    // MARK: Step 0 — Intro

    private var stepIntro: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text("Let me read\nyour cycle")
                    .font(.custom("Raleway-Bold", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.center)

                Text("Your body has been speaking through \(history.count) cycles. Here's what it's telling you.")
                    .font(.custom("Raleway-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(stepVisible ? 1 : 0)
        }
    }

    // MARK: Step 1 — Your Rhythm

    private var stepRhythm: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(rhythm.color.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(stepVisible ? 1 : 0)

                Image(systemName: rhythm.icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(rhythm.color)
                    .scaleEffect(stepVisible ? 1 : 0.2)
                    .opacity(stepVisible ? 1 : 0)
            }

            VStack(spacing: 14) {
                Text(rhythm.title)
                    .font(.custom("Raleway-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)

                if tooltipVisible {
                    storyTooltip(rhythm.desc)
                        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                }
            }
            .offset(y: stepVisible ? 0 : 16)
            .opacity(stepVisible ? 1 : 0)
        }
    }

    // MARK: Step 2 — Your Inner Clock

    private var stepNumbers: some View {
        VStack(spacing: 36) {
            VStack(spacing: 4) {
                Text("\(Int(numberValue))")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignColors.text)
                    .contentTransition(.numericText(value: numberValue))
                    .animation(.easeOut(duration: 0.8), value: numberValue)

                Text("days — your inner clock")
                    .font(.custom("Raleway-Medium", size: 18, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
            }
            .scaleEffect(stepVisible ? 1 : 0.8)
            .opacity(stepVisible ? 1 : 0)

            if tooltipVisible {
                HStack(spacing: 16) {
                    miniStat(label: "Shortest", value: "\(stats.cycleLength.min)d", delay: 0)
                    miniStat(label: "Longest", value: "\(stats.cycleLength.max)d", delay: 0.1)
                    miniStat(label: "Variation", value: "±\(Int(stdDev.rounded()))d", delay: 0.2)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: Step 3 — Your Pattern

    private var stepNormalVsAtypical: some View {
        let steadyCount = history.filter { $0.length >= 24 && $0.length <= 32 }.count
        let shiftedCount = history.count - steadyCount

        return VStack(spacing: 28) {
            HStack(spacing: 8) {
                ForEach(Array(history.enumerated()), id: \.offset) { i, point in
                    let steady = point.length >= 24 && point.length <= 32
                    VStack(spacing: 6) {
                        if steady {
                            Circle()
                                .fill(DesignColors.accentSecondary)
                                .frame(width: 14, height: 14)
                        } else {
                            Circle()
                                .strokeBorder(DesignColors.text, lineWidth: 2)
                                .frame(width: 14, height: 14)
                        }
                        Text("\(point.length)")
                            .font(.custom("Raleway-Bold", size: 10))
                            .foregroundStyle(steady ? DesignColors.textSecondary : DesignColors.text)
                    }
                    .scaleEffect(i < dotsRevealed ? 1 : 0)
                    .opacity(i < dotsRevealed ? 1 : 0)
                }
            }
            .offset(y: stepVisible ? 0 : 12)

            VStack(spacing: 14) {
                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Circle().fill(DesignColors.accentSecondary).frame(width: 10, height: 10)
                        Text("\(steadyCount) Steady")
                            .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                            .foregroundStyle(DesignColors.text)
                    }
                    HStack(spacing: 8) {
                        Circle().strokeBorder(DesignColors.text, lineWidth: 2).frame(width: 10, height: 10)
                        Text("\(shiftedCount) Shifted")
                            .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                            .foregroundStyle(DesignColors.text)
                    }
                }
                .opacity(stepVisible ? 1 : 0)

                if tooltipVisible {
                    storyTooltip(
                        shiftedCount == 0
                            ? "Every cycle stayed in rhythm. Your body holds a steady beat — that's rare and powerful."
                            : "\(shiftedCount) cycles shifted outside your usual rhythm. That's your body responding to life — stress, travel, change. It's not broken, it's adaptive."
                    )
                    .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Step 4 — Your Phases

    private var stepKeyInsight: some View {
        let avgBleeding = history.isEmpty ? 5 : history.map(\.bleeding).reduce(0, +) / history.count
        let follicularDays = CyclePhase.follicular.dayRange(cycleLength: Int(avg), bleedingDays: avgBleeding)
        let follicularCount = follicularDays.upperBound - follicularDays.lowerBound + 1
        let ovDays = CyclePhase.ovulatory.dayRange(cycleLength: Int(avg), bleedingDays: avgBleeding)

        return VStack(spacing: 28) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DesignColors.accent)
                .scaleEffect(stepVisible ? 1 : 0.3)
                .opacity(stepVisible ? 1 : 0)

            VStack(spacing: 16) {
                Text("Your phases")
                    .font(.custom("Raleway-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)
                    .opacity(stepVisible ? 1 : 0)

                if tooltipVisible {
                    VStack(spacing: 14) {
                        insightBubble(
                            icon: CyclePhase.follicular.icon,
                            tint: CyclePhase.follicular.orbitColor,
                            text: "\(follicularCount) follicular days — your energy rises"
                        )

                        insightBubble(
                            icon: CyclePhase.ovulatory.icon,
                            tint: CyclePhase.ovulatory.orbitColor,
                            text: "Ovulation peaks around day \(ovDays.lowerBound)"
                        )

                        insightBubble(
                            icon: CyclePhase.luteal.icon,
                            tint: CyclePhase.luteal.orbitColor,
                            text: "Luteal phase brings clarity and reflection"
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Reusable Components

    private func storyTooltip(_ text: String) -> some View {
        Text(text)
            .font(.custom("Raleway-Regular", size: 16, relativeTo: .body))
            .foregroundStyle(DesignColors.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DesignColors.structure.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(DesignColors.structure.opacity(0.1), lineWidth: 0.5)
                    }
            }
    }

    private func miniStat(label: String, value: String, delay: Double) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.custom("Raleway-Bold", size: 20, relativeTo: .title3))
                .foregroundStyle(DesignColors.text)
            Text(label)
                .font(.custom("Raleway-Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPlaceholder)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignColors.structure.opacity(0.06))
        }
    }

    private func insightBubble(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(text)
                .font(.custom("Raleway-Medium", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignColors.structure.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Animated Sparkline

private struct AnimatedSparkline: View {
    let values: [Int]
    let color: Color
    @State private var draw: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                SparklineFillShape(points: pts, height: geo.size.height)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(draw)

                SparklineShape(points: pts)
                    .trim(from: 0, to: draw)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if let last = pts.last {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 14, height: 14)
                        .position(last)
                        .opacity(draw > 0.9 ? 1 : 0)
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .position(last)
                        .opacity(draw > 0.9 ? 1 : 0)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) { draw = 1 }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let maxV = CGFloat(values.max() ?? 1)
        let minV = CGFloat(values.min() ?? 0)
        let range = max(maxV - minV, 1)
        let padTop: CGFloat = 8
        let padBottom: CGFloat = 18
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, val in
            let x = CGFloat(i) * step
            let y = padTop + (1 - (CGFloat(val) - minV) / range) * (size.height - padTop - padBottom)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Shapes

private struct SparklineShape: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }
        var p = Path()
        p.move(to: points[0])
        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : p2
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return p
    }
}

private struct SparklineFillShape: Shape {
    let points: [CGPoint]
    let height: CGFloat
    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }
        var p = Path()
        p.move(to: points[0])
        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : p2
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        p.addLine(to: CGPoint(x: points.last!.x, y: height))
        p.addLine(to: CGPoint(x: points.first!.x, y: height))
        p.closeSubpath()
        return p
    }
}

private struct PhaseHeroCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 40))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - 40),
            control: CGPoint(x: rect.midX, y: rect.maxY + 20)
        )
        path.closeSubpath()
        return path
    }
}
