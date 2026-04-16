import ComposableArchitecture
import Foundation

@Reducer
public struct ChallengeJourneyFeature: Sendable {

    @ObservableState
    public struct State: Equatable, Sendable {
        let challenge: ChallengeSnapshot
        var step: Step = .timer

        var timerSecondsRemaining: Int
        let timerDurationTotal: Int

        var capturedFullSize: Data?
        var capturedThumbnail: Data?
        var isShowingCamera = false
        var isShowingGallery = false

        var validationState: ValidationState = .idle

        var celebrationFeedback: String = ""
        var celebrationRating: String = ""
        var celebrationXP: Int = 0

        enum Step: Equatable, Sendable {
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
        case timerTick
        case imDoneTapped
        case openCameraTapped
        case openGalleryTapped
        case photoCaptured(Data)
        case photoCancelled
        case retakeTapped
        case submitPhotoTapped
        case validationResponse(Result<ChallengeValidationResponse, Error>)
        case tryAgainTapped
        case backToMyDayTapped
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case completed(
                photoData: Data, thumbnailData: Data,
                xpEarned: Int, rating: String, feedback: String
            )
            case cancelled
        }
    }

    public init() {}

    @Dependency(\.continuousClock) var clock
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.anonymousID) var anonymousID

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appeared:
                let title = state.challenge.challengeTitle
                let phase = state.challenge.cyclePhase
                let duration = State.durationMinutes(for: state.challenge.challengeCategory)
                return .merge(
                    .run { send in
                        for await _ in self.clock.timer(interval: .seconds(1)) {
                            await send(.timerTick)
                        }
                    }
                    .cancellable(id: CancelID.timer),
                    .run { _ in
                        await ChallengeActivityBridge.start(
                            title: title, phase: phase, durationMinutes: duration
                        )
                    }
                )

            case .timerTick:
                guard state.step == .timer, state.timerSecondsRemaining > 0 else { return .none }
                state.timerSecondsRemaining -= 1
                return .none

            case .imDoneTapped:
                state.step = .proof
                state.isShowingCamera = true
                return .cancel(id: CancelID.timer)

            case .openCameraTapped:
                state.isShowingCamera = true
                return .none

            case .openGalleryTapped:
                state.isShowingGallery = true
                return .none

            case let .photoCaptured(data):
                state.isShowingCamera = false
                state.isShowingGallery = false
                guard let processed = PhotoProcessor.process(data) else { return .none }
                state.capturedFullSize = processed.fullSize
                state.capturedThumbnail = processed.thumbnail
                return .none

            case .photoCancelled:
                state.isShowingCamera = false
                state.isShowingGallery = false
                return .none

            case .retakeTapped:
                state.capturedFullSize = nil
                state.capturedThumbnail = nil
                state.isShowingCamera = true
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
                        let base64 = photoData.base64EncodedString()
                        let request = ChallengeValidationRequest(
                            anonymousId: anonId,
                            challengeType: challenge.templateId,
                            challengeDescription: challenge.challengeDescription,
                            goldHint: challenge.goldHint,
                            imageBase64: base64
                        )
                        let endpoint = Endpoint.validateChallenge(body: request)
                        do {
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
                } else {
                    state.validationState = .failure(response.feedback)
                }
                return .none

            case .validationResponse(.failure):
                state.validationState = .failure("Something went wrong. Try again?")
                return .none

            case .tryAgainTapped:
                state.step = .proof
                state.capturedFullSize = nil
                state.capturedThumbnail = nil
                state.validationState = .idle
                state.isShowingCamera = true
                return .none

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
                return .merge(
                    .run { _ in await ChallengeActivityBridge.endAll() },
                    .send(.delegate(.cancelled))
                )

            case .delegate:
                return .none
            }
        }
    }

    private enum CancelID { case timer }
}
