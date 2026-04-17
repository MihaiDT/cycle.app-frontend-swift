import ComposableArchitecture
import SwiftUI

// MARK: - Validation Result View

struct ValidationResultView: View {
    let store: StoreOf<ValidationFeature>

    var body: some View {
        VStack(spacing: 0) {
            switch store.validationState {
            case .loading:
                loadingView
            case let .success(result):
                successView(result: result)
            case let .failure(result):
                failureView(result: result)
            }
        }
        .background(DesignColors.background)
        .onAppear { store.send(.appeared) }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ValidationPulsingCircle()
                .frame(width: 60, height: 60)
                .accessibilityHidden(true)
            Text("Aria is checking...")
                .font(.raleway("Medium", size: 17, relativeTo: .body))
                .foregroundStyle(DesignColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Aria is checking your photo")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func successView(result: ValidationFeature.ValidationResult) -> some View {
        StaggeredSuccessView(result: result, store: store)
    }

    private func failureView(result: ValidationFeature.ValidationResult) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(result.feedback)
                .font(.raleway("Medium", size: 17, relativeTo: .body))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .accessibilityLabel("Validation failed: \(result.feedback)")

            VStack(spacing: 12) {
                Button {
                    store.send(.tryAgainTapped)
                } label: {
                    Text("Try Again")
                        .font(.raleway("SemiBold", size: 16, relativeTo: .headline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Retake the photo and try again")

                Button { store.send(.skipForTodayTapped) } label: {
                    Text("Skip for Today")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Dismiss this challenge until tomorrow")
            }

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Staggered Success View

private struct StaggeredSuccessView: View {
    let result: ValidationFeature.ValidationResult
    let store: StoreOf<ValidationFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Total XP after adding this challenge's XP
    private var newTotalXP: Int {
        store.profileTotalXP + result.xpEarned
    }

    @State private var showBadge = false
    @State private var showFeedback = false
    @State private var showXP = false
    @State private var showProgress = false
    @State private var showButton = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)

                // 1. Rating badge — appears at 0.3s
                RatingBadge(rating: result.rating, size: 48, animated: true)
                    .opacity(reduceMotion ? 1 : (showBadge ? 1 : 0))
                    .scaleEffect(reduceMotion ? 1 : (showBadge ? 1 : 0.5))

                // 2. Feedback — appears at 0.9s
                Text(result.feedback)
                    .font(.raleway("Medium", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(reduceMotion ? 1 : (showFeedback ? 1 : 0))
                    .offset(y: reduceMotion ? 0 : (showFeedback ? 0 : 12))

                // 3. XP count-up + level — appears at 1.5s
                VStack(spacing: 4) {
                    ValidationXPCountUp(
                        targetXP: result.xpEarned,
                        startCounting: showXP,
                        reduceMotion: reduceMotion
                    )

                    let level = GlowConstants.levelFor(xp: newTotalXP)
                    Text("\(level.emoji) \(level.title) · \(newTotalXP) XP total")
                        .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(DesignColors.textSecondary)
                        .accessibilityLabel("Level \(level.level), \(level.title). Total \(newTotalXP) XP.")
                }
                .opacity(reduceMotion ? 1 : (showXP ? 1 : 0))
                .scaleEffect(reduceMotion ? 1 : (showXP ? 1 : 0.8))

                // 4. Progress bar — appears at 2.2s (shows total XP with new challenge included)
                XPProgressBar(currentXP: newTotalXP, animated: showProgress)
                    .padding(.horizontal, 8)
                    .opacity(reduceMotion ? 1 : (showProgress ? 1 : 0))

                // 5. Button — appears at 2.8s
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.send(.dismissTapped)
                } label: {
                    Text("Amazing!")
                        .font(.raleway("SemiBold", size: 16, relativeTo: .headline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        }
                }
                .buttonStyle(.plain)
                .opacity(reduceMotion ? 1 : (showButton ? 1 : 0))
                .offset(y: reduceMotion ? 0 : (showButton ? 0 : 16))
                .accessibilityLabel("Amazing, dismiss")
                .accessibilityHint("Closes the celebration screen")
            }
            .padding(24)
        }
        .onAppear {
            if reduceMotion {
                showBadge = true
                showFeedback = true
                showXP = true
                showProgress = true
                showButton = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                    showBadge = true
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
                    showFeedback = true
                }
                withAnimation(.appBalanced.delay(1.5)) {
                    showXP = true
                }
                withAnimation(.easeOut(duration: 0.4).delay(2.2)) {
                    showProgress = true
                }
                withAnimation(.easeOut(duration: 0.4).delay(2.8)) {
                    showButton = true
                }
            }
        }
    }
}

// MARK: - Validation Pulsing Circle

private struct ValidationPulsingCircle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        // Reduce motion: render a fully-expanded, intentional-looking "active" state
        // (outer ring at 1.0 + a solid inner disc at 0.6 — the peak of the animated
        // pulse). Reads as a deliberate, finished visual rather than a frozen frame.
        // Motion on: animate between 0.8→1.0 outer / 0.3→0.6 inner.
        Circle()
            .fill(DesignColors.accentWarm.opacity(0.2))
            .overlay {
                Circle()
                    .fill(DesignColors.accentWarm.opacity(0.4))
                    .scaleEffect(reduceMotion ? 0.6 : (isPulsing ? 0.6 : 0.3))
            }
            .scaleEffect(reduceMotion ? 1.0 : (isPulsing ? 1.0 : 0.8))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                guard !reduceMotion else { return }
                isPulsing = true
            }
    }
}

// MARK: - Validation XP Count Up

private struct ValidationXPCountUp: View {
    let targetXP: Int
    var startCounting: Bool = true
    var reduceMotion: Bool = false
    @State private var displayXP: Int = 0

    var body: some View {
        Text("+\(displayXP) XP")
            .font(.raleway("Bold", size: 32, relativeTo: .largeTitle))
            .foregroundStyle(DesignColors.accentWarm)
            .contentTransition(.numericText())
            .accessibilityLabel("Earned \(targetXP) experience points")
            .onChange(of: startCounting) { _, counting in
                guard counting else { return }
                if reduceMotion {
                    displayXP = targetXP
                } else {
                    withAnimation(.easeOut(duration: 1.2)) {
                        displayXP = targetXP
                    }
                }
            }
            .onAppear {
                if reduceMotion, startCounting {
                    displayXP = targetXP
                }
            }
    }
}
