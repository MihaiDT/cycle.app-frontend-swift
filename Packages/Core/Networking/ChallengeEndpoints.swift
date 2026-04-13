import Foundation

// MARK: - Challenge Validation

struct ChallengeValidationRequest: Encodable, Sendable {
    let anonymousId: String
    let challengeType: String
    let challengeDescription: String
    let goldHint: String
    let imageBase64: String
}

struct ChallengeValidationResponse: Decodable, Sendable {
    let valid: Bool
    let rating: String
    let feedback: String
    let xpMultiplier: Double
}

extension Endpoint {
    static func validateChallenge(body: ChallengeValidationRequest) -> Endpoint {
        .post("/api/challenge/validate", body: body)
    }
}
