import ComposableArchitecture
import Inject
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

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case refresh
        case journeyLoaded(Result<JourneyData, Error>)
        case logMissedTapped
        case dismissTapped
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case dismiss
            case logMissedMonth(Date)
        }
    }

    @Dependency(\.menstrualLocal) var menstrualLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasAppeared else { return .none }
                state.hasAppeared = true
                state.isLoading = true
                return .run { [menstrualLocal] send in
                    await send(.journeyLoaded(Result { try await menstrualLocal.getJourneyData() }))
                }

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
                return .none

            case .journeyLoaded(.failure):
                state.isLoading = false
                return .none

            case .logMissedTapped:
                let targetDate = state.missedMonths.first?.date ?? Date()
                return .send(.delegate(.logMissedMonth(targetDate)))

            case .dismissTapped:
                return .send(.delegate(.dismiss))

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Cycle Journey View

public struct CycleJourneyView: View {
    @ObserveInjection var inject
    let store: StoreOf<CycleJourneyFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.72
    private let cardHeight: CGFloat = 280
    private let verticalSpacing: CGFloat = 60
    private let horizontalInset: CGFloat = AppLayout.horizontalPadding

    public init(store: StoreOf<CycleJourneyFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .top) {
            DesignColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
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
            }
        }
        .onAppear { store.send(.onAppear) }
        .enableInjection()
    }

    // MARK: - Header

    private var journeyHeader: some View {
        HStack(spacing: AppLayout.spacingM) {
            Button {
                store.send(.dismissTapped)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignColors.text)
                    .frame(width: AppLayout.minTapTarget, height: AppLayout.minTapTarget)
            }

            Text("Your Journey")
                .font(.custom("Raleway-Bold", size: 22))
                .foregroundStyle(DesignColors.text)

            Spacer()
        }
        .padding(.horizontal, horizontalInset)
        .padding(.top, AppLayout.spacingS)
        .padding(.bottom, AppLayout.spacingM)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppLayout.spacingM) {
            Image(systemName: "map")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DesignColors.textPlaceholder)

            Text("Your journey begins here")
                .font(.custom("Raleway-SemiBold", size: 17))
                .foregroundStyle(DesignColors.text)

            Text("Confirm your first period to start mapping your cycle journey.")
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppLayout.spacingXL)
        }
    }

    // MARK: - Scroll Content

    private var journeyScrollContent: some View {
        let currentIndex = store.summaries.firstIndex(where: \.isCurrentCycle) ?? (store.summaries.count - 1)
        let today = Calendar.current.startOfDay(for: Date())
        let futurePredictions = store.predictions.filter { $0.predictedDate > today }
        let totalItems = store.summaries.count + (store.missedMonths.isEmpty ? 0 : 1) + futurePredictions.count

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(store.summaries.enumerated()), id: \.element.id) { index, summary in
                        let currentPhase = currentPhaseFor(summary: summary)
                        let isFutureSegment = index >= currentIndex

                        journeyCardRow(
                            summary: summary,
                            phase: currentPhase,
                            isFuture: false,
                            index: index
                        )
                        .id(summary.id)

                        // Connector line after this card (if not last item)
                        if index < store.summaries.count - 1 || !store.missedMonths.isEmpty || !futurePredictions.isEmpty {
                            ConnectorLine(
                                fromLeft: index % 2 == 0,
                                toLeft: (index + 1) % 2 == 0,
                                isDashed: isFutureSegment
                            )
                        }
                    }

                    // Aria nudge
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

                    // Future predictions
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
        index: Int
    ) -> some View {
        let isLeftAligned = index % 2 == 0
        let currentDay: Int? = summary.isCurrentCycle
            ? store.cycleContext?.cycleDay
            : nil

        return HStack {
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
            .accessibilityLabel(cardAccessibilityLabel(summary: summary, isFuture: isFuture))
            .accessibilityHint("Double tap to view cycle details")

            if isLeftAligned {
                Spacer()
            }
        }
        .padding(.horizontal, horizontalInset)
    }

    // MARK: - Milestone Badge Row

    private func milestoneBadgeRow(milestone: MilestoneInfo, index: Int) -> some View {
        let isLeftAligned = index % 2 == 0
        return HStack {
            if isLeftAligned {
                Spacer()
                    .frame(width: horizontalInset + cardWidth * 0.3)
            }
            MilestoneBadge(text: milestone.text, icon: milestone.icon)
            if !isLeftAligned {
                Spacer()
                    .frame(width: horizontalInset + cardWidth * 0.3)
            }
            Spacer()
        }
        .padding(.horizontal, horizontalInset)
    }

    // MARK: - Serpentine Path

    // MARK: - Helpers

    private func currentPhaseFor(summary: JourneyCycleSummary) -> CyclePhase? {
        guard summary.isCurrentCycle, let cycle = store.cycleContext else { return nil }
        return cycle.phase(for: Calendar.current.startOfDay(for: Date()))
            ?? cycle.phase(forCycleDay: cycle.cycleDay)
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

    private func cardAccessibilityLabel(summary: JourneyCycleSummary, isFuture: Bool) -> String {
        if isFuture {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Predicted Cycle \(summary.cycleNumber), estimated \(formatter.string(from: summary.startDate))."
        }
        if summary.isCurrentCycle {
            let day = store.cycleContext?.cycleDay ?? summary.cycleLength
            let phase = store.cycleContext?.currentPhase.displayName ?? "Tracking"
            return "Current Cycle \(summary.cycleNumber), Day \(day), \(phase) phase."
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Cycle \(summary.cycleNumber), \(summary.cycleLength) days, started \(formatter.string(from: summary.startDate))."
    }
}

// MARK: - Milestone Info

private struct MilestoneInfo: Sendable {
    let text: String
    let icon: String
}

private func milestoneAfterCycle(_ cycleNumber: Int) -> MilestoneInfo? {
    switch cycleNumber {
    case 3:
        return MilestoneInfo(text: "Blueprint", icon: "sparkles")
    case 6:
        return MilestoneInfo(text: "Patterns", icon: "waveform.path")
    case 12:
        return MilestoneInfo(text: "Full Year", icon: "crown.fill")
    default:
        return nil
    }
}

// MARK: - Journey Cycle Card

private struct JourneyCycleCard: View {
    let summary: JourneyCycleSummary
    let phase: CyclePhase?
    let isFuture: Bool
    let currentDay: Int?

    private var isLate: Bool { phase == .late }

    private var displayPhase: CyclePhase {
        // Late is a tracking status, not a biological phase — show luteal on journey
        if let phase, phase != .late { return phase }
        if phase == .late { return .luteal }
        let bd = summary.phaseBreakdown
        let maxDays = max(bd.menstrualDays, bd.follicularDays, bd.ovulatoryDays, bd.lutealDays)
        if maxDays == bd.lutealDays { return .luteal }
        if maxDays == bd.ovulatoryDays { return .ovulatory }
        if maxDays == bd.menstrualDays { return .menstrual }
        return .follicular
    }

    private var phaseAccent: Color { displayPhase.orbitColor }

    private var cardGradient: LinearGradient {
        // Only the current cycle gets phase color. Past & future get neutral warm.
        guard summary.isCurrentCycle else {
            return LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.96, blue: 0.93),
                    Color(red: 0.96, green: 0.93, blue: 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        let colors: [Color] = switch displayPhase {
        case .menstrual:
            [Color(red: 0.94, green: 0.84, blue: 0.82), Color(red: 0.97, green: 0.92, blue: 0.90)]
        case .follicular:
            [Color(red: 0.85, green: 0.93, blue: 0.89), Color(red: 0.93, green: 0.96, blue: 0.94)]
        case .ovulatory:
            [Color(red: 0.96, green: 0.91, blue: 0.80), Color(red: 0.98, green: 0.95, blue: 0.89)]
        case .luteal:
            [Color(red: 0.90, green: 0.87, blue: 0.95), Color(red: 0.95, green: 0.93, blue: 0.97)]
        case .late:
            [Color(red: 0.92, green: 0.91, blue: 0.89), Color(red: 0.96, green: 0.95, blue: 0.94)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var dateRangeText: String {
        let start = Self.dayMonthFormatter.string(from: summary.startDate)
        // Current cycle is ongoing — show "Started Mar 1" not a range with bleeding end
        if summary.isCurrentCycle {
            return "Started \(start)"
        }
        // Past cycles: show full cycle range (start → start + cycleLength)
        if summary.cycleLength > 0 {
            let cycleEnd = Calendar.current.date(byAdding: .day, value: summary.cycleLength - 1, to: summary.startDate)
            if let cycleEnd {
                return "\(start) — \(Self.dayMonthFormatter.string(from: cycleEnd))"
            }
        }
        return start
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cardGradient
                .opacity(isFuture ? 0.5 : 1)

            // Watermark
            if summary.isCurrentCycle {
                Image(systemName: displayPhase.icon)
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(phaseAccent.opacity(0.08))
                    .offset(x: 80, y: -20)
            } else if isFuture {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 100, weight: .ultraLight))
                    .foregroundStyle(DesignColors.structure.opacity(0.15))
                    .offset(x: 80, y: -20)
            } else {
                Text("\(summary.cycleNumber)")
                    .font(.custom("Raleway-Bold", size: 100))
                    .foregroundStyle(DesignColors.structure.opacity(0.12))
                    .offset(x: 70, y: -10)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Top: cycle label
                Text(topLabel)
                    .font(.custom("Raleway-Medium", size: 13))
                    .foregroundStyle(phaseAccent.opacity(0.7))

                Spacer()

                // Title
                Text(titleText)
                    .font(.custom("Raleway-Bold", size: 24, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(4)

                // Subtitle
                Text(subtitleText)
                    .font(.custom("Raleway-Regular", size: 14))
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.top, 4)

                Spacer().frame(height: 20)

                // Bottom info
                if !bottomLabel.isEmpty {
                    Text(bottomLabel)
                        .font(.custom("Raleway-Medium", size: 14))
                        .foregroundStyle(summary.isCurrentCycle ? phaseAccent.opacity(0.6) : DesignColors.textSecondary)
                }
            }
            .padding(AppLayout.spacingL)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
        .shadow(color: .black.opacity(isFuture ? 0.03 : 0.08), radius: 16, x: 0, y: 6)
        .overlay {
            if summary.isCurrentCycle {
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [phaseAccent.opacity(0.5), phaseAccent.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            } else if isFuture {
                // Frosted overlay
                ZStack {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.6))
                    Image(systemName: "ellipsis")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(DesignColors.textPlaceholder.opacity(0.6))
                }
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
            }
        }
    }

    // MARK: Text

    private var topLabel: String {
        if isFuture { return "Upcoming" }
        if summary.isCurrentCycle { return "Current cycle" }
        return "\(summary.cycleLength) days"
    }

    private var titleText: String {
        if isFuture {
            return "~\(Self.dayMonthFormatter.string(from: summary.startDate))"
        }
        return dateRangeText
    }

    private var subtitleText: String {
        if isFuture {
            return "~\(summary.cycleLength) days estimated"
        }
        if summary.isCurrentCycle {
            if isLate {
                let daysLate = (currentDay ?? summary.cycleLength) - summary.cycleLength
                return "\(max(1, daysLate)) days late"
            }
            return displayPhase.displayName
        }
        // Build subtitle: "5 day period" + mood/energy if available
        var parts: [String] = ["\(summary.bleedingDays) day period"]
        if let mood = summary.moodLabel, let energy = summary.avgEnergy {
            parts.append("\(mood) \u{00B7} Energy \(String(format: "%.1f", energy))")
        }
        return parts.joined(separator: "\n")
    }

    private var bottomLabel: String {
        if summary.isCurrentCycle {
            if isLate {
                return "Expected \(max(1, (currentDay ?? summary.cycleLength) - summary.cycleLength)) days ago"
            }
            return "Day \(currentDay ?? summary.cycleLength) \u{00B7} \(displayPhase.displayName)"
        }
        if isFuture {
            return ""
        }
        if let label = summary.accuracyLabel {
            return "Prediction: \(label)"
        }
        return ""
    }
}

// MARK: - Connector Line

private struct ConnectorLine: View {
    let fromLeft: Bool
    let toLeft: Bool
    let isDashed: Bool
    let lineHeight: CGFloat = 60

    var body: some View {
        Canvas { context, size in
            let cardInset: CGFloat = 50
            let startX = fromLeft
                ? size.width * 0.3 + cardInset
                : size.width * 0.7 - cardInset
            let endX = toLeft
                ? size.width * 0.3 + cardInset
                : size.width * 0.7 - cardInset

            var path = Path()
            path.move(to: CGPoint(x: startX, y: 0))
            path.addCurve(
                to: CGPoint(x: endX, y: size.height),
                control1: CGPoint(x: startX, y: size.height * 0.5),
                control2: CGPoint(x: endX, y: size.height * 0.5)
            )

            let style = isDashed
                ? StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
                : StrokeStyle(lineWidth: 2, lineCap: .round)
            let color = isDashed ? DesignColors.structure : DesignColors.accent

            context.stroke(path, with: .color(color), style: style)
        }
        .frame(height: lineHeight)
        .allowsHitTesting(false)
    }
}

// MARK: - Aria Journey Nudge

private struct AriaJourneyNudge: View {
    let missedMonths: [MissedMonth]
    let onLogTapped: () -> Void

    private var message: String {
        if missedMonths.count == 1 {
            return "Your \(missedMonths[0].name) chapter is still unwritten. Tap to complete your story."
        }
        let months = missedMonths.map(\.name).joined(separator: " & ")
        return "Your \(months) chapters are missing. Log them to keep your journey whole."
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Aria avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Text("A")
                    .font(.custom("Raleway-Bold", size: 13))
                    .foregroundStyle(.white)
            }

            // Chat bubble
            Button(action: onLogTapped) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(message)
                        .font(.custom("Raleway-Regular", size: 16))
                        .foregroundStyle(DesignColors.text)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text("Log period")
                            .font(.custom("Raleway-SemiBold", size: 15))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(DesignColors.accentWarm)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DesignColors.background)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Milestone Badge

private struct MilestoneBadge: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(.custom("Raleway-SemiBold", size: 10))
        }
        .foregroundStyle(DesignColors.accentWarm)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Journey Preview Section (Home Screen)

public struct JourneyPreviewSection: View {
    let cycleCount: Int
    let currentCycleNumber: Int
    let missedMonth: MissedMonth?
    let onTap: () -> Void

    public init(cycleCount: Int, currentCycleNumber: Int, missedMonth: MissedMonth? = nil, onTap: @escaping () -> Void) {
        self.cycleCount = cycleCount
        self.currentCycleNumber = currentCycleNumber
        self.missedMonth = missedMonth
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppLayout.spacingM) {
                HStack {
                    Text("Your Journey")
                        .font(.custom("Raleway-SemiBold", size: 17))
                        .foregroundStyle(DesignColors.text)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Cycle \(currentCycleNumber)")
                            .font(.custom("Raleway-Medium", size: 13))
                            .foregroundStyle(DesignColors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignColors.textPlaceholder)
                    }
                }

                // Dot row
                HStack(spacing: 6) {
                    ForEach(0..<min(cycleCount, 12), id: \.self) { i in
                        Circle()
                            .fill(i == cycleCount - 1
                                ? DesignColors.accentWarm
                                : DesignColors.structure)
                            .frame(width: 8, height: 8)
                            .overlay {
                                if i == cycleCount - 1 {
                                    Circle()
                                        .stroke(DesignColors.accentWarm.opacity(0.4), lineWidth: 2)
                                        .frame(width: 14, height: 14)
                                }
                            }
                    }
                    if cycleCount > 12 {
                        Text("...")
                            .font(.custom("Raleway-Medium", size: 12))
                            .foregroundStyle(DesignColors.textPlaceholder)
                    }
                    Spacer()
                }

                // Teaser or nudge
                if let missed = missedMonth {
                    Text("\(missed.name) is missing — tap to complete your story")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundStyle(DesignColors.accentWarm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if cycleCount < 3 {
                    Text("\(3 - cycleCount) more cycles until your Blueprint")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundStyle(DesignColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if cycleCount < 6 {
                    Text("\(6 - cycleCount) more cycles until Patterns")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundStyle(DesignColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppLayout.spacingL)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your Journey, Cycle \(currentCycleNumber)")
        .accessibilityHint("Double tap to view your cycle journey timeline")
    }
}
