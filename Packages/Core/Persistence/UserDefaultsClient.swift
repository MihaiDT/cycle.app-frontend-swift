import ComposableArchitecture
import ConcurrencyExtras
import Foundation

// MARK: - User Defaults Client

public struct UserDefaultsClient: Sendable {
    public var boolForKey: @Sendable (String) -> Bool
    public var dataForKey: @Sendable (String) -> Data?
    public var doubleForKey: @Sendable (String) -> Double
    public var integerForKey: @Sendable (String) -> Int
    public var stringForKey: @Sendable (String) -> String?

    public var setBool: @Sendable (Bool, String) -> Void
    public var setData: @Sendable (Data?, String) -> Void
    public var setDouble: @Sendable (Double, String) -> Void
    public var setInteger: @Sendable (Int, String) -> Void
    public var setString: @Sendable (String?, String) -> Void

    public var remove: @Sendable (String) -> Void
    public var hasKey: @Sendable (String) -> Bool

    public init(
        boolForKey: @escaping @Sendable (String) -> Bool,
        dataForKey: @escaping @Sendable (String) -> Data?,
        doubleForKey: @escaping @Sendable (String) -> Double,
        integerForKey: @escaping @Sendable (String) -> Int,
        stringForKey: @escaping @Sendable (String) -> String?,
        setBool: @escaping @Sendable (Bool, String) -> Void,
        setData: @escaping @Sendable (Data?, String) -> Void,
        setDouble: @escaping @Sendable (Double, String) -> Void,
        setInteger: @escaping @Sendable (Int, String) -> Void,
        setString: @escaping @Sendable (String?, String) -> Void,
        remove: @escaping @Sendable (String) -> Void,
        hasKey: @escaping @Sendable (String) -> Bool
    ) {
        self.boolForKey = boolForKey
        self.dataForKey = dataForKey
        self.doubleForKey = doubleForKey
        self.integerForKey = integerForKey
        self.stringForKey = stringForKey
        self.setBool = setBool
        self.setData = setData
        self.setDouble = setDouble
        self.setInteger = setInteger
        self.setString = setString
        self.remove = remove
        self.hasKey = hasKey
    }
}

// MARK: - Convenience Methods

extension UserDefaultsClient {
    public func setCodable<T: Codable>(_ value: T?, forKey key: String) {
        guard let value else {
            setData(nil, key)
            return
        }
        let data = try? JSONEncoder().encode(value)
        setData(data, key)
    }

    public func codableForKey<T: Codable>(_ key: String) -> T? {
        guard let data = dataForKey(key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Keys

extension UserDefaultsClient {
    public enum Keys {
        public static let hasCompletedOnboarding = "cycle.hasCompletedOnboarding"
        public static let lastSyncDate = "cycle.lastSyncDate"
        public static let preferredTheme = "cycle.preferredTheme"
        public static let notificationsEnabled = "cycle.notificationsEnabled"
    }
}

// MARK: - Dependency

extension UserDefaultsClient: DependencyKey {
    public static let liveValue = UserDefaultsClient.live()
    public static let testValue = UserDefaultsClient.mock()
    public static let previewValue = UserDefaultsClient.mock()
}

extension DependencyValues {
    public var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension UserDefaultsClient {
    public static func live() -> Self {
        UserDefaultsClient(
            boolForKey: { UserDefaults.standard.bool(forKey: $0) },
            dataForKey: { UserDefaults.standard.data(forKey: $0) },
            doubleForKey: { UserDefaults.standard.double(forKey: $0) },
            integerForKey: { UserDefaults.standard.integer(forKey: $0) },
            stringForKey: { UserDefaults.standard.string(forKey: $0) },
            setBool: { value, key in UserDefaults.standard.set(value, forKey: key) },
            setData: { value, key in UserDefaults.standard.set(value, forKey: key) },
            setDouble: { value, key in UserDefaults.standard.set(value, forKey: key) },
            setInteger: { value, key in UserDefaults.standard.set(value, forKey: key) },
            setString: { value, key in UserDefaults.standard.set(value, forKey: key) },
            remove: { UserDefaults.standard.removeObject(forKey: $0) },
            hasKey: { UserDefaults.standard.object(forKey: $0) != nil }
        )
    }
}

// MARK: - Mock Implementation

extension UserDefaultsClient {
    public static func mock() -> Self {
        // For mock, we use separate storages for each type to be Sendable-compatible
        let boolStorage = LockIsolated<[String: Bool]>([:])
        let dataStorage = LockIsolated<[String: Data]>([:])
        let doubleStorage = LockIsolated<[String: Double]>([:])
        let intStorage = LockIsolated<[String: Int]>([:])
        let stringStorage = LockIsolated<[String: String]>([:])

        return UserDefaultsClient(
            boolForKey: { key in boolStorage.value[key] ?? false },
            dataForKey: { key in dataStorage.value[key] },
            doubleForKey: { key in doubleStorage.value[key] ?? 0 },
            integerForKey: { key in intStorage.value[key] ?? 0 },
            stringForKey: { key in stringStorage.value[key] },
            setBool: { value, key in boolStorage.withValue { $0[key] = value } },
            setData: { value, key in dataStorage.withValue { $0[key] = value } },
            setDouble: { value, key in doubleStorage.withValue { $0[key] = value } },
            setInteger: { value, key in intStorage.withValue { $0[key] = value } },
            setString: { value, key in stringStorage.withValue { $0[key] = value } },
            remove: { key in
                boolStorage.withValue { $0[key] = nil }
                dataStorage.withValue { $0[key] = nil }
                doubleStorage.withValue { $0[key] = nil }
                intStorage.withValue { $0[key] = nil }
                stringStorage.withValue { $0[key] = nil }
            },
            hasKey: { key in
                boolStorage.value[key] != nil || dataStorage.value[key] != nil || doubleStorage.value[key] != nil
                    || intStorage.value[key] != nil || stringStorage.value[key] != nil
            }
        )
    }
}
