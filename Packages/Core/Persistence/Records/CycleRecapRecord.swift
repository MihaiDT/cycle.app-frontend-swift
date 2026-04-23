import Foundation
import SwiftData

// MARK: - Cycle Recap Record

/// Cached AI-generated story recap for a cycle. One record per cycle
/// (keyed by cycle start date string). Currently stores the six chapter
/// narratives plus the headline + a short "vibe" word.
@Model
public final class CycleRecapRecord {
    /// Cycle start date as "yyyy-MM-dd" — unique key (enforced in code,
    /// not DB — CloudKit doesn't support unique constraints).
    public var cycleKey: String = ""

    /// Chapter 1: Theme — the throughline of the cycle.
    public var chapterTheme: String = ""

    /// Chapter 2: Body — physical story.
    public var chapterBody: String = ""

    /// Chapter 3: Heart & Mind — emotional story.
    public var chapterMind: String = ""

    /// Chapter 4: Rhythm — cross-cycle pattern narrative.
    public var chapterPattern: String = ""

    /// Chapter 5: Key Days — JSON-encoded `[KeyDay]` array.
    public var chapterKeyDaysJSON: String = ""

    /// Chapter 6: What's Coming — preview narrative for the next cycle.
    public var chapterWhatsComing: String = ""

    /// Headline shown on Chapter 1.
    public var headline: String = ""

    /// Short cycle "vibe" word (Balanced / Radiant / Tender / ...).
    public var cycleVibe: String = ""

    /// Legacy Overview chapter kept for backward compatibility with
    /// caches written before the 6-chapter refactor. Unused by the new
    /// flow; do not rely on it.
    public var chapterOverview: String = ""

    /// Whether the user has opened the story for this recap.
    public var isViewed: Bool = false

    public var createdAt: Date = Date.now

    public init(
        cycleKey: String,
        chapterTheme: String,
        chapterBody: String,
        chapterMind: String,
        chapterPattern: String,
        chapterKeyDaysJSON: String,
        chapterWhatsComing: String,
        headline: String,
        cycleVibe: String,
        createdAt: Date = .now
    ) {
        self.cycleKey = cycleKey
        self.chapterTheme = chapterTheme
        self.chapterBody = chapterBody
        self.chapterMind = chapterMind
        self.chapterPattern = chapterPattern
        self.chapterKeyDaysJSON = chapterKeyDaysJSON
        self.chapterWhatsComing = chapterWhatsComing
        self.headline = headline
        self.cycleVibe = cycleVibe
        self.createdAt = createdAt
    }
}
