import Foundation

// MARK: - Menstrual Endpoints

public enum MenstrualEndpoints {
    public static func status() -> Endpoint {
        .get("/api/menstrual/status")
    }

    public static func insights() -> Endpoint {
        .get("/api/menstrual/insights")
    }

    public static func confirmPeriod(_ request: ConfirmPeriodRequest) -> Endpoint {
        .post("/api/menstrual/confirm", body: request)
    }

    public static func calendar(start: Date, end: Date) -> Endpoint {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")!
        return .get(
            "/api/menstrual/calendar",
            queryItems: [
                URLQueryItem(name: "start", value: formatter.string(from: start)),
                URLQueryItem(name: "end", value: formatter.string(from: end)),
            ]
        )
    }

    public static func logSymptom(_ request: LogSymptomRequest) -> Endpoint {
        .post("/api/menstrual/symptoms", body: request)
    }

    public static func symptoms(date: Date) -> Endpoint {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")!
        return .get(
            "/api/menstrual/symptoms",
            queryItems: [
                URLQueryItem(name: "date", value: formatter.string(from: date)),
            ]
        )
    }

    public static func predict() -> Endpoint {
        .post("/api/menstrual/predict", body: EmptyBody())
    }

    public static func removePeriodDays(_ request: RemovePeriodDaysRequest) -> Endpoint {
        .post("/api/menstrual/remove-days", body: request)
    }

    public static func cycleStats() -> Endpoint {
        .get("/api/menstrual/cycle-stats")
    }
}

private struct EmptyBody: Encodable, Sendable {}

// MARK: - Request Models

public struct ConfirmPeriodRequest: Encodable, Sendable {
    public let actualStartDate: Date
    public let bleedingDays: Int
    public let notes: String

    public init(actualStartDate: Date, bleedingDays: Int, notes: String = "") {
        self.actualStartDate = actualStartDate
        self.bleedingDays = bleedingDays
        self.notes = notes
    }
}

public struct RemovePeriodDaysRequest: Encodable, Sendable {
    public let dates: [String]  // Format: "yyyy-MM-dd"

    public init(dates: Set<String>) {
        self.dates = Array(dates)
    }
}

public struct LogSymptomRequest: Encodable, Sendable {
    public let symptomDate: Date
    public let symptomType: String
    public let severity: Int
    public let notes: String

    public init(symptomDate: Date, symptomType: String, severity: Int, notes: String = "") {
        self.symptomDate = symptomDate
        self.symptomType = symptomType
        self.severity = severity
        self.notes = notes
    }
}
