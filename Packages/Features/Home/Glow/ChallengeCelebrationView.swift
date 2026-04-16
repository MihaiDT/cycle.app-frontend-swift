// Packages/Features/Home/Glow/ChallengeCelebrationView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeCelebrationView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    @State private var showCard = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            celebrationCard
                .scaleEffect(showCard ? 1.0 : 0.9)
                .opacity(showCard ? 1.0 : 0)

            Spacer()

            Button { store.send(.backToMyDayTapped) } label: {
                Text("Back to my day")
                    .font(.custom("Raleway-Bold", size: 15, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignColors.accentWarm)
                    )
                    .shadow(color: DesignColors.text.opacity(0.22), radius: 10, x: 0, y: 4)
                    .shadow(color: DesignColors.text.opacity(0.10), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 16)

            Text("New challenge tomorrow")
                .font(.custom("Raleway-Medium", size: 11, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPlaceholder)
                .padding(.top, 8)
                .opacity(showButton ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                showCard = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(1.2)) {
                showButton = true
            }
        }
    }

    // MARK: - Card

    private var celebrationCard: some View {
        VStack(spacing: 16) {
            Text("Beautiful!")
                .font(.custom("Raleway-Black", size: 24, relativeTo: .title))
                .foregroundStyle(DesignColors.text)

            Text(store.celebrationFeedback)
                .font(.custom("Raleway-Medium", size: 13, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 4)

            Text("Challenge complete")
                .font(.custom("Raleway-Bold", size: 13, relativeTo: .caption))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(DesignColors.accentWarm)
                )

            // Gamification placeholder — will be redesigned
            gamificationPlaceholder
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glowCardBackground(tint: .rose)
    }

    private var gamificationPlaceholder: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.custom("Raleway-Bold", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.accentWarm)
                    Spacer()
                    Text("4 of 7")
                        .font(.custom("Raleway-Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textPlaceholder)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(DesignColors.text.opacity(0.06))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 0.57)
                    }
                }
                .frame(height: 5)
            }

            Text("4 day streak")
                .font(.custom("Raleway-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(DesignColors.accentWarm.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(DesignColors.accentWarm.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
}
