import Foundation

// MARK: - Day Detail Payload
//
// A snapshot of a single past day: metadata + every signal logged for
// that date, plus a deterministic narrative phrase derived by
// `JourneyEchoEngine`. Used by the Home "Echo" card and the full
// `DayDetailView` sheet — both surfaces share this payload so the
// card teaser and the expanded view stay in lock-step.

public struct DayDetailPayload: Equatable, Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let cycleStartDate: Date
    public let cycleNumber: Int
    public let cycleDay: Int
    public let phase: CyclePhase

    /// Self-report levels on a 1-5 scale. `nil` when the user skipped
    /// the check-in that day.
    public let mood: Int?
    public let energy: Int?
    public let stress: Int?
    public let sleep: Int?

    /// Moment (challenge) completed on this day, if any.
    public let moment: Moment?

    /// Adjusted HBI for the day (0-100). `nil` when no score was stored.
    public let hbiAdjusted: Double?

    /// Trend vs the user's luteal/follicular baseline for the day's
    /// phase. Positive = above baseline, negative = below.
    public let hbiTrendVsBaseline: Double?

    /// Deterministic narrative phrase derived from the signals above.
    public let phrase: String

    /// True when at least one signal (check-in / moment / HBI) exists.
    public let hasAnyData: Bool

    public init(
        date: Date,
        cycleStartDate: Date,
        cycleNumber: Int,
        cycleDay: Int,
        phase: CyclePhase,
        mood: Int?,
        energy: Int?,
        stress: Int?,
        sleep: Int?,
        moment: Moment?,
        hbiAdjusted: Double?,
        hbiTrendVsBaseline: Double?,
        phrase: String,
        hasAnyData: Bool
    ) {
        self.date = date
        self.cycleStartDate = cycleStartDate
        self.cycleNumber = cycleNumber
        self.cycleDay = cycleDay
        self.phase = phase
        self.mood = mood
        self.energy = energy
        self.stress = stress
        self.sleep = sleep
        self.moment = moment
        self.hbiAdjusted = hbiAdjusted
        self.hbiTrendVsBaseline = hbiTrendVsBaseline
        self.phrase = phrase
        self.hasAnyData = hasAnyData
    }

    public struct Moment: Equatable, Sendable {
        public let title: String
        public let category: String
        public let validationFeedback: String?
        public let validationRating: String?
        public let photoThumbnailData: Data?

        public init(
            title: String,
            category: String,
            validationFeedback: String?,
            validationRating: String?,
            photoThumbnailData: Data?
        ) {
            self.title = title
            self.category = category
            self.validationFeedback = validationFeedback
            self.validationRating = validationRating
            self.photoThumbnailData = photoThumbnailData
        }
    }
}
