import ComposableArchitecture
import SwiftData
import SwiftUI


// MARK: - Cycle Journey View

public struct CycleJourneyView: View {
    let store: StoreOf<CycleJourneyFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardWidthRatio: CGFloat = 0.72
    private let cardHeight: CGFloat = 170
    private let horizontalInset: CGFloat = AppLayout.screenHorizontal

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
