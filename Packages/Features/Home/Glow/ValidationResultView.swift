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
            ValidationPulsingCircle().frame(width: 60, height: 60)
            Text("Aria is checking...")
                .font(.custom("Raleway-Medium", size: 17))
                .foregroundStyle(DesignColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    private func successView(result: ValidationFeature.ValidationResult) -> some View {
        StaggeredSuccessView(result: result, store: store)
    }

    private func failureView(result: ValidationFeature.ValidationResult) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(result.feedback)
                .font(.custom("Raleway-Medium", size: 17))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(spacing: 12) {
                Button {
                    store.send(.tryAgainTapped)
                } label: {
                    Text("Try Again")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        }
                }
                .buttonStyle(.plain)

                Button { store.send(.skipForTodayTapped) } label: {
                    Text("Skip for Today")
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .buttonStyle(.plain)
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
                    .opacity(showBadge ? 1 : 0)
                    .scaleEffect(showBadge ? 1 : 0.5)

                // 2. Feedback — appears at 0.9s
                Text(result.feedback)
                    .font(.custom("Raleway-Medium", size: 17))
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(showFeedback ? 1 : 0)
                    .offset(y: showFeedback ? 0 : 12)

                // 3. XP count-up — appears at 1.5s
                ValidationXPCountUp(targetXP: result.xpEarned, startCounting: showXP)
                    .opacity(showXP ? 1 : 0)
                    .scaleEffect(showXP ? 1 : 0.8)

                // 4. Progress bar — appears at 2.2s
                XPProgressBar(currentXP: result.xpEarned, animated: showProgress)
                    .padding(.horizontal, 8)
                    .opacity(showProgress ? 1 : 0)

                // 5. Button — appears at 2.8s
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.send(.dismissTapped)
                } label: {
                    Text("Amazing!")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        }
                }
                .buttonStyle(.plain)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                showBadge = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
                showFeedback = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(1.5)) {
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

// MARK: - Validation Pulsing Circle

private struct ValidationPulsingCircle: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(DesignColors.accentWarm.opacity(0.2))
            .overlay {
                Circle()
                    .fill(DesignColors.accentWarm.opacity(0.4))
                    .scaleEffect(isPulsing ? 0.6 : 0.3)
            }
            .scaleEffect(isPulsing ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Validation XP Count Up

private struct ValidationXPCountUp: View {
    let targetXP: Int
    var startCounting: Bool = true
    @State private var displayXP: Int = 0

    var body: some View {
        Text("+\(displayXP) XP")
            .font(.custom("Raleway-Bold", size: 32))
            .foregroundStyle(DesignColors.accentWarm)
            .contentTransition(.numericText())
            .onChange(of: startCounting) { _, counting in
                guard counting else { return }
                withAnimation(.easeOut(duration: 1.2)) {
                    displayXP = targetXP
                }
            }
    }
}
