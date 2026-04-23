// Packages/Features/Home/Glow/ChallengeJourneyView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeJourneyView: View {
    @Bindable var store: StoreOf<ChallengeJourneyFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if store.step == .accept {
                ChallengeAcceptInlineView(
                    challenge: store.challenge,
                    onStart: { store.send(.startChallengeTapped) },
                    onClose: { store.send(.closeTapped) }
                )
            } else {
                VStack(spacing: 0) {
                    stepHeader
                        .padding(.bottom, 14)
                    timerAndBeyond
                }
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColors.background.ignoresSafeArea())
        .onAppear { store.send(.appeared) }
    }

    // MARK: - Step Header (dots leading, title centered, close trailing — single row)

    private var stepHeader: some View {
        ZStack {
            // Centered title — reserve room for dots + close so long titles
            // don't collide with them.
            Text(store.challenge.challengeTitle)
                .font(.custom("Raleway-Bold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textPrincipal)
                .lineLimit(1)
                .padding(.horizontal, 72)
                .accessibilityAddTraits(.isHeader)

            // Leading: progress dots — trailing: close button. One row so
            // everything is vertically aligned by default.
            HStack(alignment: .center) {
                progressDots
                Spacer()
                closeButton
            }
        }
        .frame(height: 44)
    }

    // MARK: - Close Button (shared across non-accept steps)

    private var closeButton: some View {
        Button { store.send(.closeTapped) } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DesignColors.text)
                .frame(width: 38, height: 38)
                .background(Circle().fill(DesignColors.text.opacity(0.08)))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close challenge")
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        let stepIndex = stepToIndex(store.step)
        return HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                if index < stepIndex {
                    // Done
                    Capsule()
                        .fill(DesignColors.accentWarm)
                        .frame(width: 6, height: 6)
                } else if index == stepIndex {
                    // Active
                    Capsule()
                        .fill(DesignColors.accentWarm)
                        .frame(width: 20, height: 6)
                } else {
                    // Upcoming
                    Capsule()
                        .fill(DesignColors.divider)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .animation(
            reduceMotion ? nil : .appBalanced,
            value: store.step
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Challenge progress")
        .accessibilityValue(progressDotsValue(stepIndex: stepIndex))
    }

    private func progressDotsValue(stepIndex: Int) -> String {
        guard stepIndex >= 0 else { return "Getting started" }
        return "Step \(stepIndex + 1) of 3"
    }

    private func stepToIndex(_ step: ChallengeJourneyFeature.State.Step) -> Int {
        switch step {
        case .accept: return -1 // no dots on accept
        case .timer: return 0
        case .proof: return 1
        case .validating, .celebration: return 2
        }
    }

    // MARK: - Step Content (timer and beyond)

    @ViewBuilder
    private var timerAndBeyond: some View {
        switch store.step {
        case .accept:
            EmptyView()

        case .timer:
            ChallengeTimerView(store: store)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                )

        case .proof:
            ChallengeProofView(store: store)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                )

        case .validating:
            ChallengeValidatingView(store: store)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        )
                )

        case .celebration:
            ChallengeCelebrationView(store: store)
                .transition(.opacity)
        }
    }
}
