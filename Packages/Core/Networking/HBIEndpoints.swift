import Foundation

// MARK: - HBI Endpoints

public enum HBIEndpoints {
    public static func dashboard() -> Endpoint {
        .get("/api/hbi/dashboard")
    }

    public static func today() -> Endpoint {
        .get("/api/hbi/today")
    }

    public static func submitDailyReport(_ request: DailyReportRequest) -> Endpoint {
        .post("/api/hbi/daily-report", body: request)
    }
}
