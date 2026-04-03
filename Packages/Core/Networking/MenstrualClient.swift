import ComposableArchitecture
import Foundation

// MARK: - Menstrual Client

public struct MenstrualClient: Sendable {
    public var getStatus: @Sendable (String) async throws -> MenstrualStatusResponse
    public var getInsights: @Sendable (String) async throws -> MenstrualInsightsResponse
    public var getCalendar: @Sendable (String, Date, Date) async throws -> MenstrualCalendarResponse
    public var confirmPeriod: @Sendable (String, ConfirmPeriodRequest) async throws -> Void
    public var logSymptom: @Sendable (String, LogSymptomRequest) async throws -> Void
    public var getSymptoms: @Sendable (String, Date) async throws -> [MenstrualSymptomResponse]
    public var generatePrediction: @Sendable (String) async throws -> Void
    public var removePeriodDays: @Sendable (String, RemovePeriodDaysRequest) async throws -> Void
    public var getCycleStats: @Sendable (String) async throws -> CycleStatsDetailedResponse

    public init(
        getStatus: @escaping @Sendable (String) async throws -> MenstrualStatusResponse,
        getInsights: @escaping @Sendable (String) async throws -> MenstrualInsightsResponse,
        getCalendar: @escaping @Sendable (String, Date, Date) async throws -> MenstrualCalendarResponse,
        confirmPeriod: @escaping @Sendable (String, ConfirmPeriodRequest) async throws -> Void,
        logSymptom: @escaping @Sendable (String, LogSymptomRequest) async throws -> Void,
        getSymptoms: @escaping @Sendable (String, Date) async throws -> [MenstrualSymptomResponse],
        generatePrediction: @escaping @Sendable (String) async throws -> Void,
        removePeriodDays: @escaping @Sendable (String, RemovePeriodDaysRequest) async throws -> Void,
        getCycleStats: @escaping @Sendable (String) async throws -> CycleStatsDetailedResponse
    ) {
        self.getStatus = getStatus
        self.getInsights = getInsights
        self.getCalendar = getCalendar
        self.confirmPeriod = confirmPeriod
        self.logSymptom = logSymptom
        self.getSymptoms = getSymptoms
        self.generatePrediction = generatePrediction
        self.removePeriodDays = removePeriodDays
        self.getCycleStats = getCycleStats
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
            },
            getInsights: { token in
                try await apiClient.send(
                    MenstrualEndpoints.insights().authenticated(with: token)
                )
            },
            getCalendar: { token, start, end in
                try await apiClient.send(
                    MenstrualEndpoints.calendar(start: start, end: end).authenticated(with: token)
                )
            },
            confirmPeriod: { token, request in
                try await apiClient.send(
                    MenstrualEndpoints.confirmPeriod(request).authenticated(with: token)
                )
            },
            logSymptom: { token, request in
                try await apiClient.send(
                    MenstrualEndpoints.logSymptom(request).authenticated(with: token)
                )
            },
            getSymptoms: { token, date in
                try await apiClient.send(
                    MenstrualEndpoints.symptoms(date: date).authenticated(with: token)
                )
            },
            generatePrediction: { token in
                try await apiClient.send(
                    MenstrualEndpoints.predict().authenticated(with: token)
                )
            },
            removePeriodDays: { token, request in
                try await apiClient.send(
                    MenstrualEndpoints.removePeriodDays(request).authenticated(with: token)
                )
            },
            getCycleStats: { token in
                try await apiClient.send(
                    MenstrualEndpoints.cycleStats().authenticated(with: token)
                )
            }
        )
    }
}

// MARK: - Mock Implementation

extension MenstrualClient {
    public static func mock() -> Self {
        MenstrualClient(
            getStatus: { _ in .mock },
            getInsights: { _ in .mock },
            getCalendar: { _, _, _ in .mock },
            confirmPeriod: { _, _ in },
            logSymptom: { _, _ in },
            getSymptoms: { _, _ in [] },
            generatePrediction: { _ in },
            removePeriodDays: { _, _ in },
            getCycleStats: { _ in .mock }
        )
    }
}
