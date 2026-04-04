import Foundation
import SwiftData

// MARK: - Daily Card Record

/// Cached AI-generated daily insight card.
/// Generated once per day, stored locally.
@Model
public final class DailyCardRecord {
    public var date: String = ""          // "2026-04-04"
    public var cardType: String = "feel"  // feel, do, go_deeper
    public var title: String = ""
    public var body: String = ""
    public var cyclePhase: String = ""
    public var cycleDay: Int = 1
    public var createdAt: Date = Date.now

    public init(
        date: String,
        cardType: String,
        title: String,
        body: String,
        cyclePhase: String,
        cycleDay: Int,
        createdAt: Date = .now
    ) {
        self.date = date
        self.cardType = cardType
        self.title = title
        self.body = body
        self.cyclePhase = cyclePhase
        self.cycleDay = cycleDay
        self.createdAt = createdAt
    }
}
