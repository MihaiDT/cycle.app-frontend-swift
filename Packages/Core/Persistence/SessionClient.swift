import ComposableArchitecture
import FirebaseAuth
import Foundation

// MARK: - Session Client

public struct SessionClient: Sendable {
    public var isAuthenticated: @Sendable () async -> Bool
    public var getSession: @Sendable () async -> Session?
    public var setSession: @Sendable (Session) async throws -> Void
    public var clearSession: @Sendable () async throws -> Void
    public var getAccessToken: @Sendable () async -> String?

    public init(
        isAuthenticated: @escaping @Sendable () async -> Bool,
        getSession: @escaping @Sendable () async -> Session?,
        setSession: @escaping @Sendable (Session) async throws -> Void,
        clearSession: @escaping @Sendable () async throws -> Void,
        getAccessToken: @escaping @Sendable () async -> String?
    ) {
        self.isAuthenticated = isAuthenticated
        self.getSession = getSession
        self.setSession = setSession
        self.clearSession = clearSession
        self.getAccessToken = getAccessToken
    }
}

// MARK: - Dependency

extension SessionClient: DependencyKey {
    public static let liveValue = SessionClient.live()
    public static let testValue = SessionClient.mock()
    public static let previewValue = SessionClient.mock()
}

extension DependencyValues {
    public var sessionClient: SessionClient {
        get { self[SessionClient.self] }
        set { self[SessionClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension SessionClient {
    public static func live() -> Self {
        let storage = LockIsolated<Session?>(nil)

        @Dependency(\.keychainClient) var keychain

        return SessionClient(
            isAuthenticated: {
                if let session = storage.value {
                    return session.isValid
                }
                let session: Session? = try? keychain.load(KeychainClient.Keys.session)
                storage.setValue(session)
                return session?.isValid ?? false
            },
            getSession: {
                if let session = storage.value {
                    return session
                }
                let session: Session? = try? keychain.load(KeychainClient.Keys.session)
                storage.setValue(session)
                return session
            },
            setSession: { session in
                storage.setValue(session)
                try keychain.save(KeychainClient.Keys.session, value: session)
            },
            clearSession: {
                storage.setValue(nil)
                try keychain.delete(KeychainClient.Keys.session)
            },
            getAccessToken: {
                // Always get a fresh token from Firebase — it caches internally
                // and only makes a network call when the token is expired
                if let user = Auth.auth().currentUser {
                    if let freshToken = try? await user.getIDToken() {
                        // Update stored session with fresh token
                        if let session = storage.value {
                            let updated = Session(
                                id: session.id,
                                accessToken: freshToken,
                                refreshToken: session.refreshToken,
                                expiresAt: Date().addingTimeInterval(3600),
                                user: session.user
                            )
                            storage.setValue(updated)
                            try? keychain.save(KeychainClient.Keys.session, value: updated)
                        }
                        return freshToken
                    }
                }
                // Fallback to stored token
                if let session = storage.value {
                    return session.accessToken
                }
                let session: Session? = try? keychain.load(KeychainClient.Keys.session)
                storage.setValue(session)
                return session?.accessToken
            }
        )
    }
}

// MARK: - Mock Implementation

extension SessionClient {
    public static func mock(isAuthenticated: Bool = false) -> Self {
        let storage = LockIsolated<Session?>(isAuthenticated ? .mock : nil)

        return SessionClient(
            isAuthenticated: { storage.value?.isValid ?? false },
            getSession: { storage.value },
            setSession: { storage.setValue($0) },
            clearSession: { storage.setValue(nil) },
            getAccessToken: { storage.value?.accessToken }
        )
    }
}
