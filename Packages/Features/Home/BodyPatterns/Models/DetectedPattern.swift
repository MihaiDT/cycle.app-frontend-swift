import Foundation

// MARK: - Detected Pattern
//
// Value type representing a single body-pattern surfaced by the
// detector — one symptom that returned in the same cycle phase
// across enough cycles to count as a rhythm. Three or more matching
// cycles → confirmed pattern (`isEmerging == false`); two cycles →
// emerging pattern (`isEmerging == true`).
//
// Lives in the feature folder because the detector outputs are not
// yet shared anywhere else. If we ever surface patterns from another
// feature (Cycle Recap, Aria context, etc.), promote this to
// `Packages/Core/Models/`.

public struct DetectedPattern: Equatable, Sendable, Identifiable, Hashable {
    public let id: String

    /// Raw `SymptomType.rawValue` of the pattern's symptom — e.g.
    /// "cramps", "bloating". Used by the detail screen to query
    /// `MenstrualLocalClient.patternMetrics` against
    /// `SymptomRecord.symptomType` without a reverse-lookup over
    /// the SymptomType catalogue.
    public let symptomTypeRaw: String

    /// User-facing symptom title — Title Case, no abbreviations.
    /// E.g. "Cramps", "Bloating", "Mood dip", "Skin breakouts".
    public let symptomDisplayName: String

    /// SF Symbol name for the matching `SymptomType` — drives
    /// the watermark icon rendered behind the card content
    /// (the audit replaced the bare cycle numeral with this).
    /// Defaults to a generic shape if the lookup fails so the
    /// view never has to render a missing-glyph rectangle.
    public let symptomIconName: String

    /// Cycle phase the signal returned in. Drives both the eyebrow
    /// label and the phase ink for the gauge.
    public let phase: CyclePhase

    /// Number of cycles in the lookback window where the signal was
    /// logged in this phase. Becomes the gauge's filled-segment count
    /// and the centre numeral.
    public let occurrences: Int

    /// Total cycles considered in the lookback window — the gauge's
    /// total segment count and the small caps "of N cycles" caption.
    public let totalCycles: Int

    /// First/last cycle-day the signal was observed in. Rendered as
    /// "Day {start} to {end}" beneath the title. `start == end` is
    /// rendered as "Day {start}".
    public let dayRange: ClosedRange<Int>

    /// Editorial body line shown under the symptom title. Phase 1
    /// ships a curated copy bank; Phase 2 swaps in OpenAI-generated
    /// hormonal context. Either way the UI consumes one string.
    public let editorial: String

    /// Three matching cycles → false (confirmed); two → true
    /// (emerging). Drives the "Emerging" section, the muted card
    /// treatment, and the small "Watching" eyebrow chip.
    public let isEmerging: Bool

    public init(
        id: String,
        symptomTypeRaw: String,
        symptomDisplayName: String,
        symptomIconName: String,
        phase: CyclePhase,
        occurrences: Int,
        totalCycles: Int,
        dayRange: ClosedRange<Int>,
        editorial: String,
        isEmerging: Bool
    ) {
        self.id = id
        self.symptomTypeRaw = symptomTypeRaw
        self.symptomDisplayName = symptomDisplayName
        self.symptomIconName = symptomIconName
        self.phase = phase
        self.occurrences = occurrences
        self.totalCycles = totalCycles
        self.dayRange = dayRange
        self.editorial = editorial
        self.isEmerging = isEmerging
    }
}

extension DetectedPattern {
    /// Phase Title-Case label for the eyebrow row ("Menstrual", not
    /// "MENSTRUAL" — the eyebrow style modifier handles caps via
    /// `.textCase(.uppercase)`).
    var phaseDisplayName: String {
        switch phase {
        case .menstrual:  return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulatory:  return "Ovulatory"
        case .luteal:     return "Luteal"
        case .late:       return "Late"
        }
    }

    /// "Day 1 to 3" / "Day 12". Single-day patterns drop the dash.
    /// Concise form for compact stat-tile slots (`PatternHighlightsCard`'s
    /// "Typical days" row, editorial copy templates).
    var dayRangeDisplay: String {
        if dayRange.lowerBound == dayRange.upperBound {
            return "Day \(dayRange.lowerBound)"
        }
        return "Day \(dayRange.lowerBound) to \(dayRange.upperBound)"
    }

    /// Self-explanatory form for the detail header meta line —
    /// "Days 3–6 of your cycle". Adds the "your cycle" anchor so a
    /// first-time user reads the range as cycle days, not generic
    /// dates. Single-day patterns: "Day 12 of your cycle".
    var dayRangeDisplayLong: String {
        if dayRange.lowerBound == dayRange.upperBound {
            return "Day \(dayRange.lowerBound) of your cycle"
        }
        return "Days \(dayRange.lowerBound)–\(dayRange.upperBound) of your cycle"
    }
}

// MARK: - Mock fixtures

extension DetectedPattern {
    /// Phase 1 mock data so the screen renders without the detector
    /// wired. Replace with `PatternDetector.detect(...)` output once
    /// the algorithm lands. Keep the mock here (not in a
    /// `#if DEBUG` block in the View) so previews + Phase 1
    /// integration share the exact same fixture.
    static let mockActive: [DetectedPattern] = [
        .init(
            id: "mock.cramps",
            symptomTypeRaw: "cramps",
            symptomDisplayName: "Cramps",
            symptomIconName: "bolt.heart",
            phase: .menstrual,
            occurrences: 4,
            totalCycles: 5,
            dayRange: 1...3,
            editorial: "Day 1 to 3, settling milder over the past four cycles.",
            isEmerging: false
        ),
        .init(
            id: "mock.bloating",
            symptomTypeRaw: "bloating",
            symptomDisplayName: "Bloating",
            symptomIconName: "circle.dotted",
            phase: .luteal,
            occurrences: 3,
            totalCycles: 5,
            dayRange: 22...28,
            editorial: "Day 22 to 28. Persistent across this season's cycles.",
            isEmerging: false
        ),
        .init(
            id: "mock.moodDip",
            symptomTypeRaw: "sad",
            symptomDisplayName: "Mood dip",
            symptomIconName: "cloud.rain",
            phase: .luteal,
            occurrences: 3,
            totalCycles: 5,
            dayRange: 25...28,
            editorial: "Day 25 to 28. Sharpest two days before the bleed begins.",
            isEmerging: false
        )
    ]

    static let mockEmerging: [DetectedPattern] = [
        .init(
            id: "mock.skin",
            symptomTypeRaw: "acne",
            symptomDisplayName: "Skin breakouts",
            symptomIconName: "sparkles",
            phase: .follicular,
            occurrences: 2,
            totalCycles: 4,
            dayRange: 7...10,
            editorial: "Day 7 to 10. One more cycle to confirm a pattern.",
            isEmerging: true
        )
    ]
}
