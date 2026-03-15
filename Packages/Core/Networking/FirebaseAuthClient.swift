import ComposableArchitecture
import FirebaseAuth
import Foundation

// MARK: - Firebase Auth Client

/// TCA-compatible client for Firebase Authentication
public struct FirebaseAuthClient: Sendable {
    public var signUp: @Sendable (String, String) async throws -> AuthUser
    public var signIn: @Sendable (String, String) async throws -> AuthUser
    public var signInAnonymously: @Sendable () async throws -> AuthUser
    public var signInWithGoogle: @Sendable (String, String) async throws -> AuthUser
    public var signOut: @Sendable () async throws -> Void
    public var resetPassword: @Sendable (String) async throws -> Void
    public var getCurrentUser: @Sendable () async -> AuthUser?
    public var getIDToken: @Sendable () async throws -> String

    public init(
        signUp: @escaping @Sendable (String, String) async throws -> AuthUser,
        signIn: @escaping @Sendable (String, String) async throws -> AuthUser,
        signInAnonymously: @escaping @Sendable () async throws -> AuthUser,
        signInWithGoogle: @escaping @Sendable (String, String) async throws -> AuthUser,
        signOut: @escaping @Sendable () async throws -> Void,
        resetPassword: @escaping @Sendable (String) async throws -> Void,
        getCurrentUser: @escaping @Sendable () async -> AuthUser?,
        getIDToken: @escaping @Sendable () async throws -> String
    ) {
        self.signUp = signUp
        self.signIn = signIn
        self.signInAnonymously = signInAnonymously
        self.signInWithGoogle = signInWithGoogle
        self.signOut = signOut
        self.resetPassword = resetPassword
        self.getCurrentUser = getCurrentUser
        self.getIDToken = getIDToken
    }
}

// MARK: - Auth User Model

public struct AuthUser: Equatable, Sendable {
    public let uid: String
    public let email: String?
    public let displayName: String?
    public let isEmailVerified: Bool
    public let isAnonymous: Bool

    public init(uid: String, email: String?, displayName: String?, isEmailVerified: Bool, isAnonymous: Bool = false) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.isEmailVerified = isEmailVerified
        self.isAnonymous = isAnonymous
    }
}

// MARK: - Dependency Key

extension FirebaseAuthClient: DependencyKey {
    public static let liveValue: FirebaseAuthClient = {
        FirebaseAuthClient(
            signUp: { email, password in
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                return AuthUser(
                    uid: result.user.uid,
                    email: result.user.email,
                    displayName: result.user.displayName,
                    isEmailVerified: result.user.isEmailVerified,
                    isAnonymous: false
                )
            },
            signIn: { email, password in
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                return AuthUser(
                    uid: result.user.uid,
                    email: result.user.email,
                    displayName: result.user.displayName,
                    isEmailVerified: result.user.isEmailVerified,
                    isAnonymous: false
                )
            },
            signInAnonymously: {
                let result = try await Auth.auth().signInAnonymously()
                return AuthUser(
                    uid: result.user.uid,
                    email: nil,
                    displayName: nil,
                    isEmailVerified: false,
                    isAnonymous: true
                )
            },
            signInWithGoogle: { idToken, accessToken in
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                let result = try await Auth.auth().signIn(with: credential)
                return AuthUser(
                    uid: result.user.uid,
                    email: result.user.email,
                    displayName: result.user.displayName,
                    isEmailVerified: result.user.isEmailVerified,
                    isAnonymous: false
                )
            },
            signOut: {
                try Auth.auth().signOut()
            },
            resetPassword: { email in
                try await Auth.auth().sendPasswordReset(withEmail: email)
            },
            getCurrentUser: {
                guard let user = Auth.auth().currentUser else { return nil }
                return AuthUser(
                    uid: user.uid,
                    email: user.email,
                    displayName: user.displayName,
                    isEmailVerified: user.isEmailVerified,
                    isAnonymous: user.isAnonymous
                )
            },
            getIDToken: {
                guard let user = Auth.auth().currentUser else {
                    throw FirebaseAuthError.notAuthenticated
                }
                return try await user.getIDToken()
            }
        )
    }()

    public static let testValue = FirebaseAuthClient(
        signUp: { _, _ in
            AuthUser(uid: "test-uid", email: "test@example.com", displayName: "Test User", isEmailVerified: true)
        },
        signIn: { _, _ in
            AuthUser(uid: "test-uid", email: "test@example.com", displayName: "Test User", isEmailVerified: true)
        },
        signInAnonymously: {
            AuthUser(uid: "test-guest-uid", email: nil, displayName: nil, isEmailVerified: false, isAnonymous: true)
        },
        signInWithGoogle: { _, _ in
            AuthUser(uid: "test-uid", email: "test@example.com", displayName: "Test User", isEmailVerified: true)
        },
        signOut: {},
        resetPassword: { _ in },
        getCurrentUser: { nil },
        getIDToken: { "test-token" }
    )
}

extension DependencyValues {
    public var firebaseAuthClient: FirebaseAuthClient {
        get { self[FirebaseAuthClient.self] }
        set { self[FirebaseAuthClient.self] = newValue }
    }
}

// MARK: - Firebase Auth Errors

public enum FirebaseAuthError: LocalizedError, Sendable {
    case notAuthenticated
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in"
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyInUse:
            return "This email is already registered"
        case .weakPassword:
            return "Password is too weak"
        case .networkError:
            return "Network error. Please check your connection"
        case .unknown(let message):
            return message
        }
    }
}
