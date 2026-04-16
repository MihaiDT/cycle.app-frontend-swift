import ActivityKit
import Foundation

struct ChallengeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let timerEnd: Date
    }

    let challengeTitle: String
    let cyclePhase: String
    let durationMinutes: Int
}

enum ChallengeActivityBridge {

    @MainActor
    static func start(
        title: String,
        phase: String,
        durationMinutes: Int
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = ChallengeActivityAttributes(
            challengeTitle: title,
            cyclePhase: phase,
            durationMinutes: durationMinutes
        )

        let timerEnd = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        let state = ChallengeActivityAttributes.ContentState(timerEnd: timerEnd)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: timerEnd),
                pushType: nil
            )
        } catch {
            // Silently fail — Live Activity is enhancement, not critical path
        }
    }

    @MainActor
    static func endAll() {
        Task {
            for activity in Activity<ChallengeActivityAttributes>.activities {
                let finalState = ChallengeActivityAttributes.ContentState(timerEnd: .now)
                await activity.end(
                    .init(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
    }
}
