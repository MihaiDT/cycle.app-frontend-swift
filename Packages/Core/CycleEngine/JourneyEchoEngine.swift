import Foundation

// MARK: - Journey Echo Engine
//
// Derives a narrative phrase + full payload for the "day matching the
// current cycle day, one cycle ago". Rules-based (deterministic) so
// the echo stays reproducible between app launches. The engine is
// pure: it takes already-fetched per-day signals and produces a
// `DayDetailPayload`. The caller is responsible for loading signals
// from persistence.

public enum JourneyEchoEngine {

    // MARK: - Input types

    public struct DaySignals: Equatable, Sendable {
        public let mood: Int?
        public let energy: Int?
        public let stress: Int?
        public let sleep: Int?
        public let momentCategory: String?
        public let momentTitle: String?
        public let momentValidationFeedback: String?
        public let momentValidationRating: String?
        public let momentPhotoThumbnail: Data?
        public let hbiAdjusted: Double?
        public let hbiTrendVsBaseline: Double?

        public init(
            mood: Int? = nil,
            energy: Int? = nil,
            stress: Int? = nil,
            sleep: Int? = nil,
            momentCategory: String? = nil,
            momentTitle: String? = nil,
            momentValidationFeedback: String? = nil,
            momentValidationRating: String? = nil,
            momentPhotoThumbnail: Data? = nil,
            hbiAdjusted: Double? = nil,
            hbiTrendVsBaseline: Double? = nil
        ) {
            self.mood = mood
            self.energy = energy
            self.stress = stress
            self.sleep = sleep
            self.momentCategory = momentCategory
            self.momentTitle = momentTitle
            self.momentValidationFeedback = momentValidationFeedback
            self.momentValidationRating = momentValidationRating
            self.momentPhotoThumbnail = momentPhotoThumbnail
            self.hbiAdjusted = hbiAdjusted
            self.hbiTrendVsBaseline = hbiTrendVsBaseline
        }
    }

    // MARK: - Entry point

    /// Build the echo payload for `date`, given the signals logged on
    /// that day + cycle metadata (start date, cycle number, phase).
    public static func buildEcho(
        for date: Date,
        cycleStartDate: Date,
        cycleNumber: Int,
        cycleDay: Int,
        cycleLength: Int,
        bleedingDays: Int,
        signals: DaySignals
    ) -> DayDetailPayload {
        let phaseResult = CycleMath.cyclePhase(
            cycleDay: cycleDay,
            cycleLength: cycleLength,
            bleedingDays: bleedingDays
        )
        let phase = CyclePhase(rawValue: phaseResult.rawValue) ?? .menstrual

        let hasAnyData = signals.mood != nil
            || signals.energy != nil
            || signals.momentCategory != nil
            || signals.hbiAdjusted != nil

        let phrase = makePhrase(signals: signals)

        let moment: DayDetailPayload.Moment? = {
            guard let category = signals.momentCategory,
                  let title = signals.momentTitle else { return nil }
            return DayDetailPayload.Moment(
                title: title,
                category: category,
                validationFeedback: signals.momentValidationFeedback,
                validationRating: signals.momentValidationRating,
                photoThumbnailData: signals.momentPhotoThumbnail
            )
        }()

        return DayDetailPayload(
            date: date,
            cycleStartDate: cycleStartDate,
            cycleNumber: cycleNumber,
            cycleDay: cycleDay,
            phase: phase,
            mood: signals.mood,
            energy: signals.energy,
            stress: signals.stress,
            sleep: signals.sleep,
            moment: moment,
            hbiAdjusted: signals.hbiAdjusted,
            hbiTrendVsBaseline: signals.hbiTrendVsBaseline,
            phrase: phrase,
            hasAnyData: hasAnyData
        )
    }

    // MARK: - Phrase rules

    /// Deterministic mapping from signals to a single-line narrative.
    /// Rules fire in priority order — the first matching rule wins.
    /// See `docs/` for the full table; each branch below mirrors it.
    public static func makePhrase(signals: DaySignals) -> String {
        // 1. Untracked days get a neutral fallback so the echo card
        //    never lies about having observations.
        let hasCheckIn = signals.mood != nil || signals.energy != nil
        let hasMoment = signals.momentCategory != nil
        if !hasCheckIn && !hasMoment {
            return "this day wasn't tracked"
        }

        // 2. Moment signals override check-in averaging because an
        //    action ("I did X today") is the most narrative-rich
        //    event we have.
        if let category = signals.momentCategory {
            return phraseForMoment(category: category, energy: signals.energy ?? 3)
        }

        // 3. Check-in only paths. Read mood + energy + stress in that
        //    order and pick the strongest signal.
        let mood = signals.mood ?? 3
        let energy = signals.energy ?? 3
        let stress = signals.stress ?? 3

        if stress >= 4 {
            return "you carried weight"
        }
        if mood <= 2 {
            return "it was a softer day"
        }
        if mood >= 4 && energy >= 4 {
            return "you ran easy"
        }
        if mood >= 4 {
            return "your mood lifted"
        }
        if energy <= 2 {
            return "your body asked for less"
        }
        return "you held steady"
    }

    private static func phraseForMoment(category: String, energy: Int) -> String {
        switch category.lowercased() {
        case "self_care":
            return energy <= 3 ? "you chose rest" : "you took care of yourself"
        case "movement":
            return energy >= 4 ? "you went all in" : "you moved anyway"
        case "mindfulness":
            return "you turned inward"
        case "creative":
            return "you made space to create"
        case "nutrition":
            return "you nourished yourself"
        case "social":
            return energy >= 4 ? "you showed up" : "you reached out"
        default:
            return "you chose to show up"
        }
    }
}
