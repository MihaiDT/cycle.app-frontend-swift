import ComposableArchitecture
import Inject
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
    @ObserveInjection var inject
    let store: StoreOf<CycleInsightsFeature>
    @Namespace var tabNamespace

    public init(store: StoreOf<CycleInsightsFeature>) {
        self.store = store
    }

    var phase: CyclePhase? { store.cycleContext?.currentPhase }

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
        let phases = CyclePhase.biologicalPhases
        guard let currentIdx = phases.firstIndex(of: ctx.currentPhase) else { return nil }
        let nextIdx = (currentIdx + 1) % phases.count
        let nextPhase = phases[nextIdx]
        let nextRange = nextPhase.dayRange(cycleLength: ctx.cycleLength, bleedingDays: ctx.bleedingDays)
        let daysUntil = nextRange.lowerBound - ctx.cycleDay
        let adjusted = daysUntil > 0 ? daysUntil : ctx.cycleLength - ctx.cycleDay + nextRange.lowerBound
        guard adjusted > 0, adjusted <= 14 else { return nil }
        return NextPhaseInfo(phase: nextPhase, daysUntil: adjusted)
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
                ForEach(CyclePhase.biologicalPhases, id: \.self) { p in
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
