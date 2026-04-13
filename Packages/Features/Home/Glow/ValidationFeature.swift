import ComposableArchitecture
import Foundation

// MARK: - Validation Feature

@Reducer
public struct ValidationFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public let challenge: ChallengeSnapshot
        public let photoData: Data
        public let thumbnailData: Data
        public var validationState: ValidationState = .loading

        public enum ValidationState: Equatable, Sendable {
            case loading
            case success(ValidationResult)
            case failure(ValidationResult)
        }

        public init(challenge: ChallengeSnapshot, photoData: Data, thumbnailData: Data) {
            self.challenge = challenge
            self.photoData = photoData
            self.thumbnailData = thumbnailData
        }
    }

    public struct ValidationResult: Equatable, Sendable {
        public let valid: Bool
        public let rating: String
        public let feedback: String
        public let xpMultiplier: Double
        public let xpEarned: Int
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case appeared
        case validationResponse(Result<ChallengeValidationResponse, Error>)
        case dismissTapped
        case tryAgainTapped
        case skipForTodayTapped
        case delegate(Delegate)
        public enum Delegate: Sendable {
            case completed(
                photoData: Data, thumbnailData: Data,
                xpEarned: Int, rating: String, feedback: String
            )
            case tryAgain
            case skipForToday
        }
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.anonymousID) var anonymousID

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .appeared:
                let challenge = state.challenge
                let photoData = state.photoData
                let anonId = anonymousID.getID()
                return .run { send in
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

            case let .validationResponse(.success(response)):
                let xp = Int(Double(GlowConstants.baseXP) * response.xpMultiplier)
                let result = ValidationResult(
                    valid: response.valid,
                    rating: response.rating,
                    feedback: response.feedback,
                    xpMultiplier: response.xpMultiplier,
                    xpEarned: xp
                )
                state.validationState = response.valid ? .success(result) : .failure(result)
                return .none

            case .validationResponse(.failure):
                let result = ValidationResult(
                    valid: false, rating: "bronze",
                    feedback: "Something went wrong. Try again or skip for today.",
                    xpMultiplier: 1.0, xpEarned: 0
                )
                state.validationState = .failure(result)
                return .none

            case .dismissTapped:
                guard case let .success(result) = state.validationState else { return .none }
                return .send(.delegate(.completed(
                    photoData: state.photoData, thumbnailData: state.thumbnailData,
                    xpEarned: result.xpEarned, rating: result.rating, feedback: result.feedback
                )))

            case .tryAgainTapped:
                return .send(.delegate(.tryAgain))

            case .skipForTodayTapped:
                return .send(.delegate(.skipForToday))

            case .delegate:
                return .none
            }
        }
    }
}
