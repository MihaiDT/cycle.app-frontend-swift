import ComposableArchitecture
import SwiftUI

// MARK: - Aria Recap Stories

struct AriaRecapStories: View {
    let store: StoreOf<CycleJourneyFeature>
    @State private var shimmerPhase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private let storyGradients: [[Color]] = [
        [Color(red: 0.72, green: 0.36, blue: 0.40), Color(red: 0.82, green: 0.52, blue: 0.45)],
        [Color(red: 0.78, green: 0.48, blue: 0.40), Color(red: 0.88, green: 0.65, blue: 0.50)],
        [Color(red: 0.55, green: 0.42, blue: 0.65), Color(red: 0.70, green: 0.58, blue: 0.75)],
        [Color(red: 0.75, green: 0.55, blue: 0.30), Color(red: 0.85, green: 0.70, blue: 0.42)],
        [Color(red: 0.32, green: 0.23, blue: 0.20), Color(red: 0.50, green: 0.36, blue: 0.30)],
    ]

    var body: some View {
        if let recap = store.recap {
            ZStack {
                LinearGradient(
                    colors: storyGradients[min(recap.currentPage, storyGradients.count - 1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: recap.currentPage)

                VStack(spacing: 0) {
                    VStack(spacing: 14) {
                        storyProgressBars(currentPage: recap.currentPage)

                        HStack {
                            Text(Self.monthFormatter.string(from: recap.summary.startDate))
                                .font(.custom("Raleway-Medium", size: 13))
                                .foregroundStyle(.white.opacity(0.7))

                            Spacer()

                            Button { store.send(.recapDismissed) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(.white.opacity(0.15)))
                            }
                            .accessibilityLabel("Close recap")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    if recap.isLoading {
                        storyLoadingContent
                    } else {
                        storyPageContent(recap: recap, page: recap.currentPage)
                            .id(recap.currentPage)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: recap.currentPage)
                    }

                    Spacer()
                    Spacer()
                }

                VStack(spacing: 0) {
                    Color.clear.frame(height: 70)

                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { goBack(from: recap.currentPage) }
                            .accessibilityLabel("Previous page")
                            .accessibilityAddTraits(.isButton)

                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { goForward(from: recap.currentPage) }
                            .accessibilityLabel("Next page")
                            .accessibilityAddTraits(.isButton)
                    }

                    Color.clear.frame(height: 140)
                }
            }
            .statusBarHidden()
        }
    }

    // MARK: - Progress Bars

    private func storyProgressBars(currentPage: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<RecapState.totalPages, id: \.self) { i in
                Capsule()
                    .fill(i <= currentPage ? Color.white : Color.white.opacity(0.25))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Loading Shimmer

    private var storyLoadingContent: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(shimmerPhase ? 0.2 : 0.08))
                .frame(width: 180, height: 28)

            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(shimmerPhase ? 0.15 : 0.06))
                        .frame(height: 16)
                        .frame(maxWidth: i == 2 ? 200 : .infinity)
                }
            }
            .padding(.horizontal, 40)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: shimmerPhase)
        .onAppear { if !reduceMotion { shimmerPhase = true } }
    }

    // MARK: - Page Content

    @ViewBuilder
    private func storyPageContent(recap: RecapState, page: Int) -> some View {
        switch page {
        case 0: storyOverviewPage(recap: recap)
        case 1: storyBodyPage(recap: recap)
        case 2: storyMindPage(recap: recap)
        case 3: storyPatternPage(recap: recap)
        case 4: storyAskAriaPage(recap: recap)
        default: EmptyView()
        }
    }

    private func storyOverviewPage(recap: RecapState) -> some View {
        VStack(spacing: 24) {
            Text(recap.cycleVibe.uppercased())
                .font(.custom("Raleway-Bold", size: 52))
                .foregroundStyle(.white.opacity(0.10))
                .tracking(8)

            Text(recap.headline)
                .font(.custom("Raleway-Bold", size: 30))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(recap.overviewText)
                .font(.custom("Raleway-Regular", size: 18))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 6) {
                Text("Cycle \(recap.summary.cycleNumber)")
                    .font(.custom("Raleway-Medium", size: 13))
                Text("\u{00B7}")
                Text("\(recap.summary.cycleLength) days")
                    .font(.custom("Raleway-Medium", size: 13))
            }
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
    }

    private func storyBodyPage(recap: RecapState) -> some View {
        VStack(spacing: 28) {
            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.5))

            Text("Your Body")
                .font(.custom("Raleway-Bold", size: 28))
                .foregroundStyle(.white)

            Text(recap.bodyText)
                .font(.custom("Raleway-Regular", size: 18))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            let phaseTotal = recap.summary.phaseBreakdown.menstrualDays
                + recap.summary.phaseBreakdown.follicularDays
                + recap.summary.phaseBreakdown.ovulatoryDays
                + recap.summary.phaseBreakdown.lutealDays
            if phaseTotal > 0 {
                storyPhaseMiniBar(recap: recap)
            }
        }
        .padding(.horizontal, 20)
    }

    private func storyMindPage(recap: RecapState) -> some View {
        VStack(spacing: 28) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.5))

            Text("Your Mind")
                .font(.custom("Raleway-Bold", size: 28))
                .foregroundStyle(.white)

            Text(recap.mindText)
                .font(.custom("Raleway-Regular", size: 18))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let mood = recap.summary.avgMood, let energy = recap.summary.avgEnergy {
                HStack(spacing: 24) {
                    storyMoodIndicator(label: "Mood", value: mood)
                    storyMoodIndicator(label: "Energy", value: energy)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func storyPatternPage(recap: RecapState) -> some View {
        VStack(spacing: 28) {
            Image(systemName: "waveform.path")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.5))

            Text("The Pattern")
                .font(.custom("Raleway-Bold", size: 28))
                .foregroundStyle(.white)

            Text(recap.patternText)
                .font(.custom("Raleway-Regular", size: 18))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let label = recap.summary.accuracyLabel {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 14))
                    Text("Prediction: \(label)")
                        .font(.custom("Raleway-Medium", size: 14))
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.12)))
            }
        }
        .padding(.horizontal, 20)
    }

    private func storyAskAriaPage(recap: RecapState) -> some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.55, blue: 0.48),
                                Color(red: 0.72, green: 0.45, blue: 0.58),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Text("A")
                    .font(.custom("Raleway-Bold", size: 28))
                    .foregroundStyle(.white)
            }

            Text("Something on your mind?")
                .font(.custom("Raleway-Bold", size: 28))
                .foregroundStyle(.white)

            Text("Ask Aria anything about this cycle — why it felt different, what your mood patterns mean, or how to prepare for the next one.")
                .font(.custom("Raleway-Regular", size: 17))
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                store.send(.askAriaAboutCycle(recap.summary))
            } label: {
                HStack(spacing: 10) {
                    Text("Talk with Aria")
                        .font(.custom("Raleway-SemiBold", size: 17))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.35, green: 0.25, blue: 0.22))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Capsule().fill(.white))
            }
            .padding(.horizontal, 40)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func storyPhaseMiniBar(recap: RecapState) -> some View {
        let bd = recap.summary.phaseBreakdown
        let total = bd.menstrualDays + bd.follicularDays + bd.ovulatoryDays + bd.lutealDays
        let phases: [(String, Int, Color)] = [
            ("M", bd.menstrualDays, CyclePhase.menstrual.orbitColor),
            ("F", bd.follicularDays, CyclePhase.follicular.orbitColor),
            ("O", bd.ovulatoryDays, CyclePhase.ovulatory.orbitColor),
            ("L", bd.lutealDays, CyclePhase.luteal.orbitColor),
        ]

        return VStack(spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                        let pct = total > 0 ? CGFloat(phase.1) / CGFloat(total) : 0.25
                        RoundedRectangle(cornerRadius: 3)
                            .fill(phase.2.opacity(0.8))
                            .frame(width: max(4, (geo.size.width - 6) * pct))
                    }
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 60)

            HStack(spacing: 16) {
                ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                    HStack(spacing: 4) {
                        Circle().fill(phase.2.opacity(0.8)).frame(width: 6, height: 6)
                        Text("\(phase.1)d")
                            .font(.custom("Raleway-Regular", size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    private func storyMoodIndicator(label: String, value: Double) -> some View {
        VStack(spacing: 6) {
            Text(String(format: "%.1f", value))
                .font(.custom("Raleway-Bold", size: 24))
                .foregroundStyle(.white)
            Text(label)
                .font(.custom("Raleway-Medium", size: 12))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(width: 80)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.12))
        )
    }

    // MARK: - Navigation

    private func goBack(from page: Int) {
        guard page > 0 else { return }
        store.send(.recapPageChanged(page - 1))
    }

    private func goForward(from page: Int) {
        guard page < RecapState.totalPages - 1 else { return }
        store.send(.recapPageChanged(page + 1))
    }
}
