// Packages/Features/Home/Glow/ChallengeJourneyView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeJourneyView: View {
    @Bindable var store: StoreOf<ChallengeJourneyFeature>

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.bottom, 14)

            stepContent
                .animation(.spring(response: 0.45, dampingFraction: 0.9), value: store.step)
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 20)
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
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                let stepIndex = stepToIndex(store.step)
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
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: store.step)
    }

    private func stepToIndex(_ step: ChallengeJourneyFeature.State.Step) -> Int {
        switch step {
        case .timer: return 0
        case .proof: return 1
        case .validating, .celebration: return 2
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch store.step {
        case .timer:
            ChallengeTimerView(store: store)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .proof:
            ChallengeProofView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .validating:
            ChallengeValidatingView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))

        case .celebration:
            ChallengeCelebrationView(store: store)
                .transition(.opacity)
        }
    }
}
