import Foundation
import Tagged

// MARK: - Session

public struct Session: Codable, Equatable, Sendable {
    public typealias ID = Tagged<Session, String>

    public let id: ID
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let user: User

    public init(
        id: ID,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        user: User
    ) {
        self.id = id
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.user = user
    }

    public var isExpired: Bool {
        expiresAt < .now
    }

    public var isValid: Bool {
        !isExpired && !accessToken.isEmpty
    }
}

// MARK: - Mock Data

extension Session {
    public static let mock = Session(
        id: .init("session-123"),
        accessToken: "mock-access-token",
        refreshToken: "mock-refresh-token",
        expiresAt: Date.now.addingTimeInterval(3600),
        user: .mock
    )
}
