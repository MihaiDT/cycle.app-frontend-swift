import ComposableArchitecture
import ConcurrencyExtras
import Foundation

// MARK: - Keychain Client

public struct KeychainClient: Sendable {
    public var save: @Sendable (String, Data) throws -> Void
    public var load: @Sendable (String) throws -> Data?
    public var delete: @Sendable (String) throws -> Void
    public var clear: @Sendable () throws -> Void

    public init(
        save: @escaping @Sendable (String, Data) throws -> Void,
        load: @escaping @Sendable (String) throws -> Data?,
        delete: @escaping @Sendable (String) throws -> Void,
        clear: @escaping @Sendable () throws -> Void
    ) {
        self.save = save
        self.load = load
        self.delete = delete
        self.clear = clear
    }
}

// MARK: - Convenience Methods

extension KeychainClient {
    public func save<T: Encodable>(_ key: String, value: T) throws {
        let data = try JSONEncoder().encode(value)
        try save(key, data)
    }

    public func load<T: Decodable>(_ key: String) throws -> T? {
        guard let data = try load(key) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Dependency

extension KeychainClient: DependencyKey {
    public static let liveValue = KeychainClient.live()
    public static let testValue = KeychainClient.mock()
    public static let previewValue = KeychainClient.mock()
}

extension DependencyValues {
    public var keychainClient: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension KeychainClient {
    public static func live(service: String = "app.cycle.ios") -> Self {
        KeychainClient(
            save: { key, data in
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: key,
                    kSecValueData as String: data,
                ]

                SecItemDelete(query as CFDictionary)
                let status = SecItemAdd(query as CFDictionary, nil)

                guard status == errSecSuccess else {
                    throw KeychainError.saveFailed(status)
                }
            },
            load: { key in
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: key,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                ]

                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)

                guard status == errSecSuccess else {
                    if status == errSecItemNotFound {
                        return nil
                    }
                    throw KeychainError.loadFailed(status)
                }

                return result as? Data
            },
            delete: { key in
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: key,
                ]

                let status = SecItemDelete(query as CFDictionary)

                guard status == errSecSuccess || status == errSecItemNotFound else {
                    throw KeychainError.deleteFailed(status)
                }
            },
            clear: {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                ]

                let status = SecItemDelete(query as CFDictionary)

                guard status == errSecSuccess || status == errSecItemNotFound else {
                    throw KeychainError.clearFailed(status)
                }
            }
        )
    }
}

// MARK: - Mock Implementation

extension KeychainClient {
    public static func mock() -> Self {
        let storage = LockIsolated<[String: Data]>([:])

        return KeychainClient(
            save: { key, data in
                storage.withValue { $0[key] = data }
            },
            load: { key in
                storage.withValue { $0[key] }
            },
            delete: { key in
                storage.withValue { $0[key] = nil }
            },
            clear: {
                storage.withValue { $0.removeAll() }
            }
        )
    }
}

// MARK: - Keychain Error

public enum KeychainError: Error, Sendable {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case clearFailed(OSStatus)
}
