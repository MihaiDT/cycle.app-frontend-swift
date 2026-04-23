import ComposableArchitecture
import Foundation

@Reducer
public struct ChallengeJourneyFeature: Sendable {

    @ObservableState
    public struct State: Equatable, Sendable {
        let challenge: ChallengeSnapshot
        var step: Step = .accept

        var timerSecondsRemaining: Int
        let timerDurationTotal: Int
        var timerEndDate: Date

        var capturedFullSize: Data?
        var capturedThumbnail: Data?

        var validationState: ValidationState = .idle

        var celebrationFeedback: String = ""
        var celebrationRating: String = ""
        var celebrationXP: Int = 0

        /// Loaded once validation succeeds so the celebration view can show
        /// the user's real streak + weekly progress. Reflects the state BEFORE
        /// this challenge has been persisted (persist happens on "Back to my day").
        /// The celebration projects the post-completion values from these fields.
        var glowProfile: GlowProfileSnapshot?

        enum Step: Equatable, Sendable {
            case accept
            case timer
            case proof
            case validating
            case celebration
        }

        enum ValidationState: Equatable, Sendable {
            case idle
            case loading
            case success
            case failure(String)
        }

        public init(challenge: ChallengeSnapshot) {
            self.challenge = challenge
            let minutes = Self.durationMinutes(for: challenge.challengeCategory)
            self.timerDurationTotal = minutes * 60
            self.timerSecondsRemaining = minutes * 60
            self.timerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        }

        static func durationMinutes(for category: String) -> Int {
            switch category.lowercased() {
            case "creative", "nutrition": return 15
            case "movement": return 10
            default: return 5
            }
        }

        var timerProgress: Double {
            guard timerDurationTotal > 0 else { return 0 }
            return 1.0 - Double(timerSecondsRemaining) / Double(timerDurationTotal)
        }

        var timerDisplayString: String {
            let m = timerSecondsRemaining / 60
            let s = timerSecondsRemaining % 60
            return String(format: "%d:%02d", m, s)
        }
    }

    public enum Action: Sendable {
        case appeared
        case startChallengeTapped
        case timerTick
        case imDoneTapped
        case photoCaptured(Data)
        case retakeTapped
        case submitPhotoTapped
        case validationResponse(Result<ChallengeValidationResponse, Error>)
        case profileLoaded(GlowProfileSnapshot)
        case tryAgainTapped
        case letItGoTapped
        case backToMyDayTapped
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case challengeStarted(timerEndDate: Date)
            case completed(
                photoData: Data, thumbnailData: Data,
                xpEarned: Int, rating: String, feedback: String
            )
            /// Journey was dismissed without a decision (X tapped, soft cancel).
            /// Challenge state is preserved — user can resume.
            case cancelled
            /// User chose "Let it go for today" on the failure screen — the
            /// challenge is skipped until tomorrow. Parent marks the card
            /// as `.skipped` and persists via `glowLocal.skipChallenge`.
            case skippedForToday
        }
    }

    public init() {}

    @Dependency(\.continuousClock) var clock
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.anonymousID) var anonymousID
    @Dependency(\.glowLocal) var glowLocal

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appeared:
                // If resuming (Continue tapped), start timer immediately
                if state.step == .timer {
                    return .run { send in
                        for await _ in self.clock.timer(interval: .seconds(1)) {
                            await send(.timerTick)
                        }
                    }
                    .cancellable(id: CancelID.timer)
                }
                return .none

            case .startChallengeTapped:
                state.step = .timer
                // Recalculate timerEndDate now (user may have spent time on accept screen)
                let minutes = State.durationMinutes(for: state.challenge.challengeCategory)
                state.timerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
                state.timerSecondsRemaining = minutes * 60
                let title = state.challenge.challengeTitle
                let category = state.challenge.challengeCategory
                let phase = state.challenge.cyclePhase
                let endDate = state.timerEndDate
                return .merge(
                    .send(.delegate(.challengeStarted(timerEndDate: endDate))),
                    .run { send in
                        for await _ in self.clock.timer(interval: .seconds(1)) {
                            await send(.timerTick)
                        }
                    }
                    .cancellable(id: CancelID.timer),
                    .run { _ in
                        await ChallengeActivityBridge.start(
                            title: title, category: category,
                            phase: phase, durationMinutes: minutes,
                            timerEnd: endDate
                        )
                    }
                )

            case .timerTick:
                guard state.step == .timer else { return .none }
                let remaining = Int(state.timerEndDate.timeIntervalSinceNow)
                state.timerSecondsRemaining = max(0, remaining)
                return .none

            case .imDoneTapped:
                state.step = .proof
                return .cancel(id: CancelID.timer)

            case let .photoCaptured(data):
                guard let processed = PhotoProcessor.process(data) else { return .none }
                state.capturedFullSize = processed.fullSize
                state.capturedThumbnail = processed.thumbnail
                return .none

            case .retakeTapped:
                state.capturedFullSize = nil
                state.capturedThumbnail = nil
                return .none

            case .submitPhotoTapped:
                guard let photoData = state.capturedFullSize else { return .none }
                state.step = .validating
                state.validationState = .loading
                let challenge = state.challenge
                let anonId = anonymousID.getID()
                return .merge(
                    .run { _ in await ChallengeActivityBridge.endAll() },
                    .run { send in
                        do {
                            let base64 = photoData.base64EncodedString()
                            let request = ChallengeValidationRequest(
                                anonymousId: anonId,
                                challengeType: challenge.templateId,
                                challengeDescription: challenge.challengeDescription,
                                goldHint: challenge.goldHint,
                                imageBase64: base64
                            )
                            let endpoint = try Endpoint.validateChallenge(body: request)
                            let response: ChallengeValidationResponse = try await apiClient.send(endpoint)
                            await send(.validationResponse(.success(response)))
                        } catch {
                            await send(.validationResponse(.failure(error)))
                        }
                    }
                )

            case let .validationResponse(.success(response)):
                let xp = Int(Double(GlowConstants.baseXP) * response.xpMultiplier)
                if response.valid {
                    state.validationState = .success
                    state.celebrationFeedback = response.feedback
                    state.celebrationRating = response.rating
                    state.celebrationXP = xp
                    state.step = .celebration
                    // Load the current glow profile so celebration can render
                    // real streak + weekly progress instead of placeholders.
                    return .run { [glowLocal] send in
                        let profile = try await glowLocal.getProfile()
                        await send(.profileLoaded(profile))
                    }
                } else {
                    state.validationState = .failure(response.feedback)
                }
                return .none

            case let .profileLoaded(profile):
                state.glowProfile = profile
                return .none

            case .validationResponse(.failure):
                state.validationState = .failure("Something went wrong. Try again?")
                return .none

            case .tryAgainTapped:
                state.step = .proof
                state.capturedFullSize = nil
                state.capturedThumbnail = nil
                state.validationState = .idle
                return .none

            case .letItGoTapped:
                // Close with a "skipped" intent so the parent can mark the
                // challenge as done-for-today and swap the Home card to the
                // "see you tomorrow" state.
                return .send(.delegate(.skippedForToday))

            case .backToMyDayTapped:
                guard let fullSize = state.capturedFullSize,
                      let thumbnail = state.capturedThumbnail else { return .none }
                return .send(.delegate(.completed(
                    photoData: fullSize, thumbnailData: thumbnail,
                    xpEarned: state.celebrationXP,
                    rating: state.celebrationRating,
                    feedback: state.celebrationFeedback
                )))

            case .closeTapped:
                return .send(.delegate(.cancelled))

            case .delegate:
                return .none
            }
        }
    }

    private enum CancelID { case timer }
}
