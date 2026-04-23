import ActivityKit
import Foundation

struct ChallengeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let timerStart: Date
        let timerEnd: Date
    }

    let challengeTitle: String
    let challengeCategory: String
    let cyclePhase: String
    let durationMinutes: Int
}

enum ChallengeActivityBridge {

    @MainActor
    static func start(
        title: String,
        category: String,
        phase: String,
        durationMinutes: Int,
        timerEnd: Date
    ) async {
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else { return }

        // Skip if activity already running (e.g. user tapped Continue)
        guard Activity<ChallengeActivityAttributes>.activities.isEmpty else { return }

        let attributes = ChallengeActivityAttributes(
            challengeTitle: title,
            challengeCategory: category,
            cyclePhase: phase,
            durationMinutes: durationMinutes
        )

        let state = ChallengeActivityAttributes.ContentState(timerStart: Date(), timerEnd: timerEnd)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: timerEnd),
                pushType: nil
            )
        } catch {
            // Live Activity is enhancement, not critical path
        }
    }

    @MainActor
    static func endAll() {
        Task {
            for activity in Activity<ChallengeActivityAttributes>.activities {
                let finalState = ChallengeActivityAttributes.ContentState(timerStart: .now, timerEnd: .now)
                await activity.end(
                    .init(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
    }
}
