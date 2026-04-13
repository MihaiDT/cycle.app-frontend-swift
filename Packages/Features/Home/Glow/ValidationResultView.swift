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
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)
                RatingBadge(rating: result.rating, size: 48, animated: true)

                Text(result.feedback)
                    .font(.custom("Raleway-Medium", size: 17))
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                ValidationXPCountUp(targetXP: result.xpEarned)

                XPProgressBar(currentXP: result.xpEarned, animated: true)
                    .padding(.horizontal, 8)

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
            }
            .padding(24)
        }
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
    @State private var displayXP: Int = 0

    var body: some View {
        Text("+\(displayXP) XP")
            .font(.custom("Raleway-Bold", size: 32))
            .foregroundStyle(DesignColors.accentWarm)
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                    displayXP = targetXP
                }
            }
    }
}
