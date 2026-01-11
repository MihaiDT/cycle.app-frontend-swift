import Foundation
import Tagged

// MARK: - User

public struct User: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = Tagged<User, String>

    public let id: ID
    public var email: String
    public var firstName: String?
    public var lastName: String?
    public var avatarURL: URL?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: ID,
        email: String,
        firstName: String? = nil,
        lastName: String? = nil,
        avatarURL: URL? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var fullName: String? {
        switch (firstName, lastName) {
        case let (first?, last?):
            "\(first) \(last)"
        case let (first?, nil):
            first
        case let (nil, last?):
            last
        case (nil, nil):
            nil
        }
    }

    public var initials: String {
        let first = firstName?.first.map(String.init) ?? ""
        let last = lastName?.first.map(String.init) ?? ""
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - Mock Data

extension User {
    public static let mock = User(
        id: .init("user-123"),
        email: "john@example.com",
        firstName: "John",
        lastName: "Doe"
    )
}
