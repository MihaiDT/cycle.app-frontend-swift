import Foundation

// MARK: - Menstrual Endpoints

public enum MenstrualEndpoints {
    public static func status() -> Endpoint {
        .get("/api/menstrual/status")
    }

    public static func insights() -> Endpoint {
        .get("/api/menstrual/insights")
    }

    public static func calendar(start: Date, end: Date) -> Endpoint {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return .get(
            "/api/menstrual/calendar",
            queryItems: [
                URLQueryItem(name: "start", value: formatter.string(from: start)),
                URLQueryItem(name: "end", value: formatter.string(from: end)),
            ]
        )
    }
}
