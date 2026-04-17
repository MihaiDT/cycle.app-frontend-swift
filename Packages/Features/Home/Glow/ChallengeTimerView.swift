// Packages/Features/Home/Glow/ChallengeTimerView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeTimerView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    var body: some View {
        VStack(spacing: 0) {
            timerRing
                .padding(.top, 8)
                .padding(.bottom, 28)
            tipsCard
            Spacer(minLength: 16)
            imDoneButton
            timerHint
        }
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(DesignColors.divider, lineWidth: 4)

            // Progress arc
            Circle()
                .trim(from: 0, to: store.timerProgress)
                .stroke(
                    DesignColors.accentWarm,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 4) {
                Text(store.timerDisplayString)
                    .font(.custom("Raleway-Black", size: 56, relativeTo: .largeTitle))
                    .foregroundStyle(DesignColors.text)
                    .monospacedDigit()

                Text("remaining")
                    .font(.custom("Raleway-SemiBold", size: 13, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textPlaceholder)
            }
        }
        .frame(width: 210, height: 210)
        .background(
            Circle().fill(DesignColors.cardWarm)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Challenge timer")
        .accessibilityValue("\(store.timerDisplayString) remaining")
    }

    // MARK: - Tips Card

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to")
                .font(.custom("Raleway-Bold", size: 13, relativeTo: .caption))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.accentWarm)

            ForEach(Array(store.challenge.tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(DesignColors.accentWarm.opacity(0.12))
                        Text("\(index + 1)")
                            .font(.custom("Raleway-Bold", size: 13, relativeTo: .caption))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                    Text(tip)
                        .font(.custom("Raleway-Medium", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.textPrincipal)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(index + 1): \(tip)")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glowCardBackground(tint: .neutral)
    }

    // MARK: - Button

    private var imDoneButton: some View {
        Button { store.send(.imDoneTapped) } label: {
            Text("I'm done")
                .font(.custom("Raleway-Bold", size: 17, relativeTo: .body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignColors.accentWarm)
                )
                .shadow(color: DesignColors.text.opacity(0.22), radius: 10, x: 0, y: 4)
                .shadow(color: DesignColors.text.opacity(0.10), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Marks the challenge as complete and starts photo capture")
    }

    private var timerHint: some View {
        Text("Timer continues in Dynamic Island")
            .font(.custom("Raleway-Medium", size: 12, relativeTo: .caption))
            .foregroundStyle(DesignColors.textPlaceholder)
            .padding(.top, 10)
    }
}
