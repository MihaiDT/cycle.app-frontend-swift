import Foundation
import SwiftData

@Model
public final class WellnessMessageRecord {
    public var dateKey: String = ""
    public var morning: String = ""
    public var afternoon: String = ""
    public var evening: String = ""
    public var createdAt: Date = Date.now

    public init(dateKey: String, morning: String, afternoon: String, evening: String) {
        self.dateKey = dateKey
        self.morning = morning
        self.afternoon = afternoon
        self.evening = evening
    }
}
