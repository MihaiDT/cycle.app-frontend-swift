import Foundation
import SwiftData

// MARK: - Natal Chart Record

/// Stores the user's natal chart — computed once from birth data, cached permanently.
@Model
final class NatalChartRecord: @unchecked Sendable {
    @Attribute(.allowsCloudEncryption) var birthDate: Date = Date(timeIntervalSince1970: 0)
    @Attribute(.allowsCloudEncryption) var birthTime: String = "12:00"
    @Attribute(.allowsCloudEncryption) var city: String = ""
    @Attribute(.allowsCloudEncryption) var country: String = ""
    @Attribute(.allowsCloudEncryption) var timezone: String = "UTC"
    @Attribute(.allowsCloudEncryption) var latitude: Double = 0.0
    @Attribute(.allowsCloudEncryption) var longitude: Double = 0.0

    /// JSON-encoded NatalProfile
    @Attribute(.allowsCloudEncryption) var natalProfileJSON: Data = Data()

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}

    init(birthDate: Date, birthTime: String, city: String, country: String,
         timezone: String, latitude: Double, longitude: Double, natalProfileJSON: Data) {
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.city = city
        self.country = country
        self.timezone = timezone
        self.latitude = latitude
        self.longitude = longitude
        self.natalProfileJSON = natalProfileJSON
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Daily Astrology Record

/// Caches daily astrology calculations — one per day per user.
/// Invalidated/regenerated each day.
@Model
final class DailyAstrologyRecord: @unchecked Sendable {
    @Attribute(.allowsCloudEncryption) var date: Date = Date(timeIntervalSince1970: 0)
    @Attribute(.allowsCloudEncryption) var cycleDay: Int = 1

    /// JSON-encoded AstrologyReport
    @Attribute(.allowsCloudEncryption) var reportJSON: Data = Data()

    var createdAt: Date = Date()

    init() {}

    init(date: Date, cycleDay: Int, reportJSON: Data) {
        self.date = date
        self.cycleDay = cycleDay
        self.reportJSON = reportJSON
        self.createdAt = Date()
    }
}
