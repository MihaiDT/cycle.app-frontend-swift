// Packages/Features/Home/Glow/ChallengeTimerView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeTimerView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    var body: some View {
        VStack(spacing: 0) {
            topBar
            timerRing
                .padding(.bottom, 16)
            tipsCard
            Spacer(minLength: 14)
            imDoneButton
            timerHint
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { store.send(.closeTapped) } label: {
                ZStack {
                    Circle()
                        .fill(DesignColors.cardWarm)
                        .overlay(
                            Circle().strokeBorder(DesignColors.divider, lineWidth: 1)
                        )
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .frame(width: 28, height: 28)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close challenge")

            Spacer()

            Text(store.challenge.challengeTitle)
                .font(.custom("Raleway-Bold", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPrincipal)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Balance spacer
            Color.clear
                .frame(width: 28, height: 28)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHidden(true)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(DesignColors.divider, lineWidth: 3)

            // Progress arc
            Circle()
                .trim(from: 0, to: store.timerProgress)
                .stroke(
                    DesignColors.accentWarm,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 2) {
                Text(store.timerDisplayString)
                    .font(.custom("Raleway-Black", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(DesignColors.text)
                    .monospacedDigit()

                Text("remaining")
                    .font(.custom("Raleway-SemiBold", size: 11, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textPlaceholder)
            }
        }
        .frame(width: 140, height: 140)
        .background(
            Circle().fill(DesignColors.cardWarm)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Challenge timer")
        .accessibilityValue("\(store.timerDisplayString) remaining")
    }

    // MARK: - Tips Card

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to")
                .font(.custom("Raleway-Bold", size: 11, relativeTo: .caption))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.accentWarm)

            ForEach(Array(store.challenge.tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(DesignColors.accentWarm.opacity(0.12))
                        Text("\(index + 1)")
                            .font(.custom("Raleway-Bold", size: 10, relativeTo: .caption))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)

                    Text(tip)
                        .font(.custom("Raleway-Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textPrincipal)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(index + 1): \(tip)")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glowCardBackground(tint: .neutral)
    }

    // MARK: - Button

    private var imDoneButton: some View {
        Button { store.send(.imDoneTapped) } label: {
            Text("I'm done")
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
        .accessibilityHint("Marks the challenge as complete and starts photo capture")
    }

    private var timerHint: some View {
        Text("Timer continues in Dynamic Island")
            .font(.custom("Raleway-Medium", size: 10, relativeTo: .caption))
            .foregroundStyle(DesignColors.textPlaceholder)
            .padding(.top, 8)
    }
}
