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
                    progressDots
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
        // Camera
        .fullScreenCover(isPresented: Binding(
            get: { store.isShowingCamera },
            set: { if !$0 { store.send(.photoCancelled) } }
        )) {
            CameraPickerRepresentable(
                onCapture: { data in store.send(.photoCaptured(data)) },
                onCancel: { store.send(.photoCancelled) }
            )
            .ignoresSafeArea()
        }
        // Gallery
        .fullScreenCover(isPresented: Binding(
            get: { store.isShowingGallery },
            set: { if !$0 { store.send(.photoCancelled) } }
        )) {
            GalleryPickerRepresentable(
                onPick: { data in store.send(.photoCaptured(data)) },
                onCancel: { store.send(.photoCancelled) }
            )
        }
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
