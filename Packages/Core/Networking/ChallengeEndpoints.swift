import Foundation

// MARK: - Challenge Validation

public struct ChallengeValidationRequest: Encodable, Sendable {
    public let anonymousId: String
    public let challengeType: String
    public let challengeDescription: String
    public let goldHint: String
    public let imageBase64: String
}

public struct ChallengeValidationResponse: Decodable, Sendable {
    public let valid: Bool
    public let rating: String
    public let feedback: String
    public let xpMultiplier: Double
}

extension Endpoint {
    static func validateChallenge(body: ChallengeValidationRequest) -> Endpoint {
        .post("/api/challenge/validate", body: body)
    }
}
