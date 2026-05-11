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

    /// Section-marker card title. Used on editorial full-width cards
    /// (Cycle History, Cycle Trend, Your Body) and on modal-style
    /// detail headers. UPPERCASE single-line — sized so the title
    /// stays the chapter marker without competing with the data
    /// inside the card for visual weight. Larger stacked variants
    /// were tested at 28pt and read as five mini-magazine covers
    /// stacked together; this size keeps the editorial voice while
    /// letting the numbers carry the screen.
    public static let cardTitlePrimary: Font = .raleway("Bold", size: 20, relativeTo: .title3)
    public static let cardTitlePrimaryTracking: CGFloat = -0.2

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

    // MARK: Display

    /// Editorial hero quote / pull-phrase used at the top of modal
    /// detail screens (Day Detail, recap stories) where a single line
    /// of italic copy carries the emotional weight of the screen.
    /// Pair with `.tracking(heroDisplayTracking)`.
    public static let heroDisplay: Font = .raleway("BoldItalic", size: 30, relativeTo: .title)
    public static let heroDisplayTracking: CGFloat = -0.4

    /// Non-italic display header used for short numeric / textual
    /// titles that anchor the top of a screen — e.g. the "2026" year
    /// title in the Calendar Year view. Sits between `cardTitlePrimary`
    /// (20pt section markers) and `statDisplay` (36pt pull-stats).
    /// Pair with `.tracking(displayHeaderTracking)`.
    public static let displayHeader: Font = .raleway("Bold", size: 28, relativeTo: .title)
    public static let displayHeaderTracking: CGFloat = -0.3

    /// Big numeric value (HBI score, percentage, count) used as the
    /// hero number on detail screens. Black weight + tight tracking
    /// gives it the editorial weight of a magazine pull-stat. Pair
    /// with `.tracking(statDisplayTracking)`.
    public static let statDisplay: Font = .raleway("Black", size: 36, relativeTo: .title)
    public static let statDisplayTracking: CGFloat = -0.8

    // MARK: Modal header

    /// Sheet/modal header title. Used inline at the top of presented
    /// detail views (e.g. the date row at the top of Day Detail).
    /// Smaller than card titles because the modal frame already
    /// signals importance — the header just labels the scope.
    public static let modalHeader: Font = .raleway("Bold", size: 15, relativeTo: .headline)

    // MARK: Body

    /// Standard editorial body copy used inside cards and modals
    /// for descriptive sentences, empty-state hints, and inline
    /// labels. Slightly tighter than `.body` so dense detail screens
    /// stay readable without crowding the data.
    public static let bodyMedium: Font = .raleway("Medium", size: 13, relativeTo: .body)
}
