import ComposableArchitecture
import Foundation

// MARK: - Anonymous ID Client

/// Manages a random UUID stored in Keychain for anonymous chat.
/// The server links messages to this ID but cannot identify the user.
/// The ID can be rotated — old conversations become orphaned.
public struct AnonymousIDClient: Sendable {
    /// Get the current anonymous ID (creates one if none exists).
    public var getID: @Sendable () -> String
    /// Rotate to a new anonymous ID. Old server data becomes orphaned.
    public var rotateID: @Sendable () -> String
    /// Delete the anonymous ID from Keychain.
    public var deleteID: @Sendable () -> Void
}

// MARK: - Dependency

extension AnonymousIDClient: DependencyKey {
    public static let liveValue = AnonymousIDClient.live()
    public static let testValue = AnonymousIDClient.mock()
    public static let previewValue = AnonymousIDClient.mock()
}

extension DependencyValues {
    public var anonymousID: AnonymousIDClient {
        get { self[AnonymousIDClient.self] }
        set { self[AnonymousIDClient.self] = newValue }
    }
}

// MARK: - Live

extension AnonymousIDClient {
    private static let keychainKey = "cycle.anonymousID"

    static func live() -> Self {
        AnonymousIDClient(
            getID: {
                // Try to load existing ID from Keychain
                if let data = try? KeychainClient.live().load(keychainKey),
                   let id = String(data: data, encoding: .utf8)
                {
                    return id
                }
                // Generate and store a new one
                let newID = UUID().uuidString.lowercased()
                if let data = newID.data(using: .utf8) {
                    try? KeychainClient.live().save(keychainKey, data)
                }
                return newID
            },
            rotateID: {
                let newID = UUID().uuidString.lowercased()
                if let data = newID.data(using: .utf8) {
                    try? KeychainClient.live().save(keychainKey, data)
                }
                return newID
            },
            deleteID: {
                try? KeychainClient.live().delete(keychainKey)
            }
        )
    }
}

// MARK: - Mock

extension AnonymousIDClient {
    static func mock() -> Self {
        let mockID = "mock-anonymous-id"
        return AnonymousIDClient(
            getID: { mockID },
            rotateID: { mockID },
            deleteID: { }
        )
    }
}
