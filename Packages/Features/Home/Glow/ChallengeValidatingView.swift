// Packages/Features/Home/Glow/ChallengeValidatingView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeValidatingView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phraseIndex: Int = 0
    @State private var dotPhase: Double = 0

    /// Aria-voice reflection phrases — warm, present-tense, observational.
    /// Rotate every ~1.8s while validation is in flight. Keep poetic but
    /// grounded so the tone reads like a thoughtful companion rather than
    /// a generic "Loading…" spinner.
    private let phrases: [String] = [
        "Opening your moment",
        "Reading the light",
        "Noticing the care in it",
        "Feeling what you felt",
        "Holding it with you"
    ]

    var body: some View {
        switch store.validationState {
        case .loading, .idle:
            loadingContent
        case let .failure(message):
            failureContent(message)
        case .success:
            // Transition handled by parent — step changes to .celebration
            EmptyView()
        }
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: 32) {
            Spacer()

            thinkingDots
                .accessibilityHidden(true)

            shimmerPhrase
                .padding(.horizontal, 20)

            Spacer()
        }
        .onAppear {
            startPhraseCycle()
            startDotBreath()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aria is reviewing your moment")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Thinking Dots

    private var thinkingDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(DesignColors.accentWarm)
                    .frame(width: 9, height: 9)
                    .opacity(dotOpacity(for: index))
                    .scaleEffect(dotScale(for: index))
            }
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        guard !reduceMotion else { return 0.8 }
        // Staggered breath — each dot trails the previous by 1/3 of the cycle.
        let phase = (dotPhase + Double(index) / 3.0).truncatingRemainder(dividingBy: 1.0)
        return 0.35 + 0.55 * sin(phase * .pi)
    }

    private func dotScale(for index: Int) -> Double {
        guard !reduceMotion else { return 1.0 }
        let phase = (dotPhase + Double(index) / 3.0).truncatingRemainder(dividingBy: 1.0)
        return 0.85 + 0.2 * sin(phase * .pi)
    }

    // MARK: - Shimmer Phrase (rises from below as a single block, shimmer runs on glyphs)

    private var shimmerPhrase: some View {
        // Single Text keeps Raleway kerning intact. Whole phrase rises
        // from below on each swap; `.id(phraseIndex)` drives the
        // asymmetric transition.
        phraseText
            .overlay(shimmerSweep)
            .mask(phraseText)
            .id(phraseIndex)
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 22)),
                        removal: .opacity.combined(with: .offset(y: -22))
                    )
            )
            .animation(
                reduceMotion ? nil : .appReveal,
                value: phraseIndex
            )
    }

    private var phraseText: some View {
        Text(phrases[phraseIndex])
            .font(.custom("Raleway-Bold", size: 30, relativeTo: .title2))
            .foregroundStyle(DesignColors.text)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
    }

    /// Diagonal highlight band sweeping across the glyphs, driven by a
    /// `TimelineView` so the animation continues uninterrupted across
    /// phrase swaps (where `.id(phraseIndex)` remounts the mask view).
    /// Wide band for a more "evident" sweep.
    private var shimmerSweep: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                let period: Double = 3.5
                let now = context.date.timeIntervalSinceReferenceDate
                let progress = (now.truncatingRemainder(dividingBy: period)) / period
                // Map [0,1] to [-0.6, 1.6] — band enters from well outside
                // the left edge, sweeps all the way past the right edge.
                let shift = (progress * 2.2 - 0.6) * width

                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.00),
                        .init(color: Color.clear, location: 0.32),
                        .init(color: DesignColors.accentWarm.opacity(0.55), location: 0.44),
                        .init(color: Color.white.opacity(0.95), location: 0.50),
                        .init(color: DesignColors.accentWarm.opacity(0.55), location: 0.56),
                        .init(color: Color.clear, location: 0.68),
                        .init(color: Color.clear, location: 1.00)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: width * 1.8, height: height * 2)
                .offset(x: reduceMotion ? 0 : shift, y: 0)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Animation Drivers

    private func startPhraseCycle() {
        guard !reduceMotion else { return }
        Task { @MainActor in
            while true {
                // Give each phrase enough time for the per-letter rise to
                // finish + breathe before swapping to the next one.
                try? await Task.sleep(for: .milliseconds(2400))
                phraseIndex = (phraseIndex + 1) % phrases.count
            }
        }
    }


    private func startDotBreath() {
        guard !reduceMotion else { return }
        dotPhase = 0
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            dotPhase = 1
        }
    }

    // MARK: - Failure

    private func failureContent(_ message: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Centered copy block — no icon, no alert chrome. The message
            // itself (coming from Aria's validation feedback) is enough;
            // a big warning glyph made this state read as punitive.
            Text("Aria noticed")
                .font(.custom("Raleway-Bold", size: 13, relativeTo: .caption))
                .tracking(2.4)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.bottom, 14)

            Text(message.cleanedAIText)
                .font(.custom("Raleway-Medium", size: 17, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 24)
                .accessibilityLabel("Aria noticed: \(message)")

            Spacer()

            VStack(spacing: 10) {
                Button { store.send(.tryAgainTapped) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Try again")
                            .font(.custom("Raleway-Bold", size: 17, relativeTo: .body))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DesignColors.accentWarm)
                    )
                    .shadow(color: DesignColors.text.opacity(0.18), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Retakes the photo and re-submits")

                Button { store.send(.letItGoTapped) } label: {
                    Text("Let it go for today")
                        .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.textPlaceholder)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Closes the challenge for today and comes back tomorrow")
            }
            .padding(.bottom, 12)
        }
    }
}
