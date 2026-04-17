@testable import CycleApp
import ComposableArchitecture
import Foundation
import Testing

// MARK: - Challenge Journey: Validation → Celebration → Profile fetch

/// Verifies the `validationResponse` branch of `ChallengeJourneyFeature`:
/// a successful validation transitions to `.celebration` AND fetches the
/// latest `GlowProfileSnapshot` so the celebration screen can render real
/// streak + weekly progress instead of placeholders (Sprint 6 B2).
@MainActor
@Suite("ChallengeJourney — Validation profile fetch")
struct ChallengeJourneyProfileFetchTests {

    private static func makeChallenge() -> ChallengeSnapshot {
        ChallengeSnapshot(
            id: UUID(),
            date: Date(),
            templateId: "test",
            challengeCategory: "self_care",
            challengeTitle: "Test",
            challengeDescription: "Test description",
            tips: ["tip 1", "tip 2"],
            goldHint: "gold",
            validationPrompt: "prompt",
            cyclePhase: "follicular",
            cycleDay: 7,
            energyLevel: 5,
            status: .available,
            completedAt: nil,
            photoThumbnail: nil,
            validationRating: nil,
            validationFeedback: nil,
            xpEarned: 0
        )
    }

    private static func makeProfile(streak: Int = 4) -> GlowProfileSnapshot {
        GlowProfileSnapshot(
            id: UUID(),
            totalXP: 250,
            currentLevel: 2,
            totalCompleted: 12,
            currentConsistencyDays: streak,
            longestConsistencyDays: streak,
            lastCompletedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            goldCount: 3,
            silverCount: 5,
            bronzeCount: 4
        )
    }

    @Test("Valid response transitions to .celebration and fetches profile")
    func validResponseFetchesProfile() async {
        let fetchedProfile = Self.makeProfile(streak: 4)
        let store = TestStore(
            initialState: ChallengeJourneyFeature.State(challenge: Self.makeChallenge())
        ) {
            ChallengeJourneyFeature()
        } withDependencies: {
            $0.glowLocal.getProfile = { fetchedProfile }
        }
        store.exhaustivity = .off

        let response = ChallengeValidationResponse(
            valid: true,
            rating: "gold",
            feedback: "great",
            xpMultiplier: 1.5
        )

        await store.send(.validationResponse(.success(response)))
        await store.receive(\.profileLoaded) {
            $0.glowProfile = fetchedProfile
        }

        #expect(store.state.step == .celebration)
        #expect(store.state.validationState == .success)
        #expect(store.state.celebrationRating == "gold")
        #expect(store.state.celebrationFeedback == "great")
        #expect(store.state.glowProfile?.currentConsistencyDays == 4)
    }

    @Test("Invalid response flips to failure and does NOT fetch profile")
    func invalidResponseSkipsProfile() async {
        let store = TestStore(
            initialState: ChallengeJourneyFeature.State(challenge: Self.makeChallenge())
        ) {
            ChallengeJourneyFeature()
        } withDependencies: {
            $0.glowLocal.getProfile = {
                Issue.record("Profile should not be fetched when validation fails")
                return .empty
            }
        }

        let response = ChallengeValidationResponse(
            valid: false,
            rating: "",
            feedback: "try again",
            xpMultiplier: 0
        )

        await store.send(.validationResponse(.success(response))) {
            $0.validationState = .failure("try again")
        }

        #expect(store.state.glowProfile == nil)
    }

    @Test("Network failure surfaces validationState failure and skips profile")
    func networkFailureSkipsProfile() async {
        struct NetworkError: Error {}
        let store = TestStore(
            initialState: ChallengeJourneyFeature.State(challenge: Self.makeChallenge())
        ) {
            ChallengeJourneyFeature()
        } withDependencies: {
            $0.glowLocal.getProfile = {
                Issue.record("Profile should not be fetched when validation fails")
                return .empty
            }
        }

        await store.send(.validationResponse(.failure(NetworkError()))) {
            $0.validationState = .failure("Something went wrong. Try again?")
        }

        #expect(store.state.glowProfile == nil)
    }
}
