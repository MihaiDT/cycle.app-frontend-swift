import ComposableArchitecture
import Foundation

// MARK: - HBI Client

public struct HBIClient: Sendable {
    public var getDashboard: @Sendable (String) async throws -> HBIDashboardResponse
    public var getToday: @Sendable (String) async throws -> HBITodayResponse
    public var submitDailyReport: @Sendable (String, DailyReportRequest) async throws -> DailyReportResponse

    public init(
        getDashboard: @escaping @Sendable (String) async throws -> HBIDashboardResponse,
        getToday: @escaping @Sendable (String) async throws -> HBITodayResponse,
        submitDailyReport: @escaping @Sendable (String, DailyReportRequest) async throws -> DailyReportResponse
    ) {
        self.getDashboard = getDashboard
        self.getToday = getToday
        self.submitDailyReport = submitDailyReport
    }
}

// MARK: - Dependency Key

extension HBIClient: DependencyKey {
    public static let liveValue = HBIClient.live()
    public static let testValue = HBIClient.mock()
    public static let previewValue = HBIClient.mock()
}

extension DependencyValues {
    public var hbiClient: HBIClient {
        get { self[HBIClient.self] }
        set { self[HBIClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension HBIClient {
    public static func live() -> Self {
        @Dependency(\.apiClient) var apiClient

        return HBIClient(
            getDashboard: { token in
                try await apiClient.send(
                    HBIEndpoints.dashboard().authenticated(with: token)
                )
            },
            getToday: { token in
                try await apiClient.send(
                    HBIEndpoints.today().authenticated(with: token)
                )
            },
            submitDailyReport: { token, request in
                try await apiClient.send(
                    HBIEndpoints.submitDailyReport(request).authenticated(with: token)
                )
            }
        )
    }
}

// MARK: - Mock Implementation

extension HBIClient {
    public static func mock() -> Self {
        HBIClient(
            getDashboard: { _ in
                HBIDashboardResponse(
                    today: .mock,
                    weekTrend: [.mock],
                    latestReport: .mock,
                    cyclePhase: "follicular",
                    cycleDay: 8,
                    insights: [
                        "Your wellness is trending up this week — great progress!",
                        "Connect HealthKit for more accurate HBI scores.",
                    ]
                )
            },
            getToday: { _ in
                HBITodayResponse(
                    hbiScore: .mock,
                    selfReport: .mock,
                    hasData: true,
                    message: "Today's HBI data"
                )
            },
            submitDailyReport: { _, _ in
                DailyReportResponse(
                    report: .mock,
                    hbiScore: .mock,
                    message: "Daily report saved successfully"
                )
            }
        )
    }
}
