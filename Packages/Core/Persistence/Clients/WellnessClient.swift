import Foundation
import SwiftData

// MARK: - Wellness Message Client

public struct WellnessMessageData: Sendable {
    public let morning: String
    public let afternoon: String
    public let evening: String
}

public enum WellnessClient {
    private static let baseURL = "https://dth-backend-277319586889.us-central1.run.app/api/wellness-message"

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    static func dateKey(for date: Date = Date()) -> String {
        dateKeyFormatter.string(from: date)
    }

    /// Returns the appropriate message for the current time of day
    public static func messageForNow(from record: WellnessMessageRecord) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return record.morning }
        if hour < 18 { return record.afternoon }
        return record.evening
    }

    /// Load cached message for today from SwiftData
    public static func loadCached(container: ModelContainer) -> WellnessMessageRecord? {
        let context = ModelContext(container)
        let key = dateKey()
        let descriptor = FetchDescriptor<WellnessMessageRecord>(
            predicate: #Predicate<WellnessMessageRecord> { $0.dateKey == key }
        )
        return try? context.fetch(descriptor).first
    }

    /// Fetch from API, cache, and return
    public static func fetchAndCache(
        cyclePhase: String,
        cycleDay: Int,
        daysUntilPeriod: Int,
        isLate: Bool,
        recentSymptoms: [String],
        moodLevel: Int,
        energyLevel: Int,
        cyclesTracked: Int,
        container: ModelContainer
    ) async -> WellnessMessageRecord? {
        let payload: [String: Any] = [
            "cycle_phase": cyclePhase,
            "cycle_day": cycleDay,
            "days_until_period": daysUntilPeriod,
            "is_late": isLate,
            "recent_symptoms": recentSymptoms,
            "mood_level": moodLevel,
            "energy_level": energyLevel,
            "cycles_tracked": cyclesTracked,
        ]

        guard let url = URL(string: baseURL),
              let body = try? JSONSerialization.data(withJSONObject: payload)
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200
        else { return nil }

        struct APIResponse: Decodable {
            let morning: String
            let afternoon: String
            let evening: String
        }

        guard let parsed = try? JSONDecoder().decode(APIResponse.self, from: data) else { return nil }

        // Cache in SwiftData
        let context = ModelContext(container)
        let key = dateKey()

        // Delete old records
        let oldDescriptor = FetchDescriptor<WellnessMessageRecord>(
            predicate: #Predicate<WellnessMessageRecord> { $0.dateKey == key }
        )
        if let old = try? context.fetch(oldDescriptor) {
            for record in old { context.delete(record) }
        }

        // Clean up records older than 7 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cleanupDescriptor = FetchDescriptor<WellnessMessageRecord>(
            predicate: #Predicate<WellnessMessageRecord> { $0.createdAt < cutoff }
        )
        if let stale = try? context.fetch(cleanupDescriptor) {
            for record in stale { context.delete(record) }
        }

        let record = WellnessMessageRecord(
            dateKey: key,
            morning: parsed.morning,
            afternoon: parsed.afternoon,
            evening: parsed.evening
        )
        context.insert(record)
        try? context.save()

        return record
    }
}
