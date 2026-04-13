import ComposableArchitecture
import Foundation

// MARK: - Validation Feature

@Reducer
struct ValidationFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let challenge: ChallengeSnapshot
        let photoData: Data
        let thumbnailData: Data
        var validationState: ValidationState = .loading

        enum ValidationState: Equatable, Sendable {
            case loading
            case success(ValidationResult)
            case failure(ValidationResult)
        }
    }

    struct ValidationResult: Equatable, Sendable {
        let valid: Bool
        let rating: String
        let feedback: String
        let xpMultiplier: Double
        let xpEarned: Int
    }

    enum Action: Sendable {
        case appeared
        case validationResponse(Result<ChallengeValidationResponse, Error>)
        case dismissTapped
        case tryAgainTapped
        case skipForTodayTapped
        case delegate(Delegate)
        enum Delegate: Sendable {
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

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
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
