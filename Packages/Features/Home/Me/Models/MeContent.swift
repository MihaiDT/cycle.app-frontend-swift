import Foundation

// MARK: - Me Content Models
//
// Mock value types used by the ME tab cards. Persistence + AI
// generation come later; for now everything renders from these
// stubs so the layout can settle before the data layer lands.

public struct StoryCategory: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let label: String

    public init(id: UUID = UUID(), label: String) {
        self.id = id
        self.label = label
    }
}

public struct MyStoryCard: Equatable, Sendable, Identifiable {
    public let id: UUID
    /// Short editorial tagline shown at the top of the card.
    public let tagline: String
    /// Caps eyebrow above the category slider ("Featured", "Today",
    /// etc.). Mirrors the Apple Music "Featured" label pattern.
    public let eyebrow: String
    /// Categories the user can scroll through. The first item is
    /// the focused chapter; the rest hint at more to swipe.
    public let categories: [StoryCategory]

    public init(
        id: UUID = UUID(),
        tagline: String,
        eyebrow: String,
        categories: [StoryCategory]
    ) {
        self.id = id
        self.tagline = tagline
        self.eyebrow = eyebrow
        self.categories = categories
    }
}

public struct DailyInsightItem: Equatable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let phaseLabel: String
    /// Full insight text. The italic suffix (`italicSuffix`) is the
    /// trailing fragment that should render italic — extracted as a
    /// separate field so the AttributedString builder can style it
    /// without re-parsing the body.
    public let text: String
    public let italicSuffix: String

    public init(
        id: UUID = UUID(),
        phaseLabel: String,
        text: String,
        italicSuffix: String
    ) {
        self.id = id
        self.phaseLabel = phaseLabel
        self.text = text
        self.italicSuffix = italicSuffix
    }

    /// Parses `phaseLabel` ("Luteal", "Follicular", "Ovulatory",
    /// "Menstrual" — case-insensitive) into a `CyclePhase`. Returns
    /// `nil` for unknown / placeholder labels so the share-image
    /// renderer falls back to its neutral palette.
    public var cyclePhase: CyclePhase? {
        switch phaseLabel.lowercased() {
        case "menstrual": return .menstrual
        case "follicular": return .follicular
        case "ovulatory": return .ovulatory
        case "luteal": return .luteal
        case "late": return .late
        default: return nil
        }
    }
}

// MARK: - Mocks

extension MyStoryCard {
    public static let mock = MyStoryCard(
        tagline: "Your personal reading, written just for you",
        eyebrow: "Your decode",
        categories: [
            StoryCategory(label: "Body Whispers"),
            StoryCategory(label: "Cycle Wisdom"),
            StoryCategory(label: "Emotional Patterns"),
            StoryCategory(label: "Hidden Strength"),
        ]
    )
}

extension DailyInsightItem {
    public static let mock = DailyInsightItem(
        phaseLabel: "Lorem",
        text: "Your energy asks for an inner rhythm. Follow it.",
        italicSuffix: "Follow it."
    )

    /// Mock collection of previously-liked insights used to seed
    /// the saved-insights pinterest grid until the real persistence
    /// layer is wired in. Lengths vary so the masonry layout
    /// staggers naturally.
    public static let mockSaved: [DailyInsightItem] = [
        DailyInsightItem(
            phaseLabel: "Luteal",
            text: "Soften the edges of your week. The body is asking for less.",
            italicSuffix: "less."
        ),
        DailyInsightItem(
            phaseLabel: "Follicular",
            text: "Begin again — gently.",
            italicSuffix: "gently."
        ),
        DailyInsightItem(
            phaseLabel: "Ovulatory",
            text: "Say the thing you've been carrying. Today it lands lighter.",
            italicSuffix: "lighter."
        ),
        DailyInsightItem(
            phaseLabel: "Menstrual",
            text: "Rest is not a reward you earn — it's the soil the rest grows from.",
            italicSuffix: "grows from."
        ),
        DailyInsightItem(
            phaseLabel: "Luteal",
            text: "Slow down where you can. Speed up only where it matters.",
            italicSuffix: "matters."
        ),
        DailyInsightItem(
            phaseLabel: "Follicular",
            text: "Curiosity over certainty.",
            italicSuffix: "certainty."
        ),
        DailyInsightItem(
            phaseLabel: "Ovulatory",
            text: "Notice who you become around them. Then choose accordingly.",
            italicSuffix: "accordingly."
        ),
        DailyInsightItem(
            phaseLabel: "Menstrual",
            text: "The wave returns. So do you.",
            italicSuffix: "do you."
        ),
    ]
}
