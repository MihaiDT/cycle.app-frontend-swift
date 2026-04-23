import SwiftUI

// MARK: - App Typography
//
// Single source of truth for every card / section title across the
// app. Before this file, each card file picked its own Raleway size
// inline — sizes spread between 13 and 36pt with no tier structure,
// so titles on small tiles (13pt) felt cramped next to 30pt hero
// cards. These tokens collapse the spread into three tiers with
// consistent weight + tracking rules, so swapping a card from one
// context to another never needs a typography decision again.
//
// Naming follows role, not size, so a later restyle changes only
// this file.

public enum AppTypography {
    // MARK: Card titles (3-tier scale)

    /// Hero-scale card / screen title. Used on editorial full-width
    /// cards (Cycle History, Your Phases, Average Cycle) and on
    /// modal-style detail headers. Usually UPPERCASE and multi-line.
    public static let cardTitlePrimary: Font = .raleway("Bold", size: 28, relativeTo: .largeTitle)
    public static let cardTitlePrimaryTracking: CGFloat = -0.4

    /// Standard card / tile title. Used on mid-density widgets —
    /// Journey destination tiles, Wellness ritual, Live widget,
    /// Symptom pattern card. Title Case, single line.
    public static let cardTitleSecondary: Font = .raleway("Bold", size: 22, relativeTo: .title2)
    public static let cardTitleSecondaryTracking: CGFloat = -0.3

    /// Inner-section header inside a larger card, or the title of a
    /// dense mini-tile (Wellness score pill, detail metric). Reads
    /// at glance but doesn't crowd the surrounding numbers.
    public static let cardTitleTertiary: Font = .raleway("Bold", size: 17, relativeTo: .headline)
    public static let cardTitleTertiaryTracking: CGFloat = -0.2

    // MARK: Stat label

    /// Inline label paired with a numeric value inside a card
    /// ("Average cycle length" → "30 days", "Previous cycle length"
    /// → "30 days"). Bold enough to register as the subject of the
    /// row, muted enough that the value still dominates. Sits above
    /// captions/eyebrows, below the card title.
    public static let cardLabel: Font = .raleway("SemiBold", size: 14, relativeTo: .subheadline)
    public static let cardLabelTracking: CGFloat = -0.1

    // MARK: Eyebrow

    /// UPPERCASE category label (e.g. "JOURNEY", "RANGE", "TRACKED").
    /// Pair with `.tracking(cardEyebrowTracking)` and
    /// `.foregroundStyle(DesignColors.textSecondary)`.
    public static let cardEyebrow: Font = .raleway("SemiBold", size: 11, relativeTo: .caption2)
    public static let cardEyebrowTracking: CGFloat = 1.2
}
