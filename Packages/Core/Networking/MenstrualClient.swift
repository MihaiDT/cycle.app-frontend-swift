import ComposableArchitecture
import Foundation

// MARK: - Menstrual Client

public struct MenstrualClient: Sendable {
    public var getStatus: @Sendable (String) async throws -> MenstrualStatusResponse

    public init(
        getStatus: @escaping @Sendable (String) async throws -> MenstrualStatusResponse
    ) {
        self.getStatus = getStatus
    }
}

// MARK: - Dependency Key

extension MenstrualClient: DependencyKey {
    public static let liveValue = MenstrualClient.live()
    public static let testValue = MenstrualClient.mock()
    public static let previewValue = MenstrualClient.mock()
}

extension DependencyValues {
    public var menstrualClient: MenstrualClient {
        get { self[MenstrualClient.self] }
        set { self[MenstrualClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension MenstrualClient {
    public static func live() -> Self {
        @Dependency(\.apiClient) var apiClient

        return MenstrualClient(
            getStatus: { token in
                try await apiClient.send(
                    MenstrualEndpoints.status().authenticated(with: token)
                )
            }
        )
    }
}

// MARK: - Mock Implementation

extension MenstrualClient {
    public static func mock() -> Self {
        MenstrualClient(
            getStatus: { _ in .mock }
        )
    }
}
