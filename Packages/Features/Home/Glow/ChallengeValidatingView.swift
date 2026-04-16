// Packages/Features/Home/Glow/ChallengeValidatingView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeValidatingView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    @State private var isPulsing = false

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
        VStack(spacing: 6) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DesignColors.accent, DesignColors.accent.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 36
                        )
                    )
                    .frame(width: 64, height: 64)
                    .scaleEffect(isPulsing ? 1.12 : 1.0)
                    .opacity(isPulsing ? 1.0 : 0.85)

                Circle()
                    .fill(DesignColors.accentWarm)
                    .frame(width: 24, height: 24)
            }
            .padding(.bottom, 14)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }

            Text("Aria is checking...")
                .font(.custom("Raleway-Bold", size: 18, relativeTo: .title3))
                .foregroundStyle(DesignColors.text)

            Text("Matching your photo\nwith the challenge")
                .font(.custom("Raleway-Medium", size: 13, relativeTo: .body))
                .foregroundStyle(DesignColors.textPlaceholder)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
        }
    }

    // MARK: - Failure

    private func failureContent(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(message)
                .font(.custom("Raleway-Medium", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                Button { store.send(.tryAgainTapped) } label: {
                    Text("Try again")
                        .font(.custom("Raleway-Bold", size: 15, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        )
                }
                .buttonStyle(.plain)

                Button { store.send(.closeTapped) } label: {
                    Text("Skip for today")
                        .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textPlaceholder)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }
}
