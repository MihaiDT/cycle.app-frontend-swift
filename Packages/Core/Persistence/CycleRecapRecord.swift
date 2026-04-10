import Foundation
import SwiftData

// MARK: - Cycle Recap Record

/// Cached AI-generated story recap for a cycle.
/// One record per cycle (keyed by cycle start date string).
/// Contains all 4 story chapters as JSON-encoded strings.
@Model
public final class CycleRecapRecord {
    /// Cycle start date as "yyyy-MM-dd" — unique key (enforced in code, not DB — CloudKit doesn't support unique constraints)
    public var cycleKey: String = ""

    /// Chapter 1: Overview narrative
    public var chapterOverview: String = ""

    /// Chapter 2: Body & physical insights
    public var chapterBody: String = ""

    /// Chapter 3: Mind & emotional insights
    public var chapterMind: String = ""

    /// Chapter 4: Pattern & rhythm insights
    public var chapterPattern: String = ""

    /// Headline for the cycle (shown on chapter 1)
    public var headline: String = ""

    /// One-word cycle vibe (e.g. "Balanced", "Resilient")
    public var cycleVibe: String = ""

    /// Whether the user has opened the story for this recap
    public var isViewed: Bool = false

    public var createdAt: Date = Date.now

    public init(
        cycleKey: String,
        chapterOverview: String,
        chapterBody: String,
        chapterMind: String,
        chapterPattern: String,
        headline: String,
        cycleVibe: String,
        createdAt: Date = .now
    ) {
        self.cycleKey = cycleKey
        self.chapterOverview = chapterOverview
        self.chapterBody = chapterBody
        self.chapterMind = chapterMind
        self.chapterPattern = chapterPattern
        self.headline = headline
        self.cycleVibe = cycleVibe
        self.createdAt = createdAt
    }
}
