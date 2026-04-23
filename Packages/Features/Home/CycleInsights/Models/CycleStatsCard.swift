import Foundation

// MARK: - Cycle Stats Cards
//
// Enumerates every card that can appear on the Cycle Stats screen.
// The raw values are stable — changing them breaks layouts already
// persisted on a user's device, so treat them as a published API.
// Reordering `CaseIterable` here is safe; the default layout lives
// in `CycleStatsLayout.default`, not in case order.

public enum CycleStatsCard: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case overview
    case normality
    case avgCycle
    case history
    case reflection

    public var id: String { rawValue }

    /// Human label rendered in the customize list. Not visible on
    /// the stats screen itself – the cards carry their own titles.
    public var displayName: String {
        switch self {
        case .overview:   return "Averages overview"
        case .normality:  return "Normality check"
        case .avgCycle:   return "Average cycle chart"
        case .history:    return "Cycle history"
        case .reflection: return "Rhythm reflection"
        }
    }

    /// One-line description shown under the row title so a user
    /// who doesn't remember what each card does can still make an
    /// informed choice about hiding it.
    public var blurb: String {
        switch self {
        case .overview:
            return "Two small boxes at the top: average cycle and period length."
        case .normality:
            return "Clinical read on your last cycle and variability."
        case .avgCycle:
            return "Chart of past cycle lengths with the projected next one."
        case .history:
            return "Scrollable list of past cycles with Energy, Mood, and Sleep dots."
        case .reflection:
            return "Editorial quote that reads your rhythm out loud."
        }
    }
}

// MARK: - Layout

/// User-owned arrangement of the Cycle Stats screen.
///
/// Persisted as JSON in UserDefaults: this is UI chrome, not health
/// data, and it's explicitly per-device (a reinstall or a new device
/// starts from `.default`). Keeping it out of SwiftData/CloudKit also
/// means a bad layout can't brick the stats screen across devices.
public struct CycleStatsLayout: Equatable, Codable, Sendable {
    public var order: [CycleStatsCard]
    public var hidden: Set<CycleStatsCard>

    public init(order: [CycleStatsCard], hidden: Set<CycleStatsCard>) {
        self.order = order
        self.hidden = hidden
    }

    // Tolerant decoder: when the persisted JSON references a card
    // case that's no longer in `allCases` (one we removed between
    // releases — e.g. "phases"), drop it silently instead of
    // failing the whole decode and wiping the user's custom order.
    // Raw values round-trip as strings, so we lift both collections
    // through `String` and `compactMap` unknowns away.
    private enum CodingKeys: String, CodingKey {
        case order
        case hidden
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawOrder = try container.decode([String].self, forKey: .order)
        let rawHidden = try container.decode([String].self, forKey: .hidden)
        self.order = rawOrder.compactMap(CycleStatsCard.init(rawValue:))
        self.hidden = Set(rawHidden.compactMap(CycleStatsCard.init(rawValue:)))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(order.map(\.rawValue), forKey: .order)
        try container.encode(hidden.map(\.rawValue), forKey: .hidden)
    }

    /// The canonical reading order applied to new users and used
    /// as the reset target: averages → verdict → chart → history
    /// → editorial close.
    public static let `default` = CycleStatsLayout(
        order: [.overview, .normality, .avgCycle, .history, .reflection],
        hidden: []
    )

    /// Cards that should render, in render order. Callers don't
    /// have to re-check the hidden set — a single source of truth
    /// for "what the user sees on Cycle Stats right now."
    public var visibleOrder: [CycleStatsCard] {
        order.filter { !hidden.contains($0) }
    }

    /// Reconciles a decoded layout with the set of cards the *current*
    /// app build knows about:
    ///   - drops cases whose raw value is no longer in `allCases`
    ///     (a card removed in a newer build)
    ///   - appends any newly-introduced cases at the end so future
    ///     cards appear the next time the screen opens, with their
    ///     default visibility (shown)
    ///   - strips stale entries from `hidden`
    ///
    /// Called from the persistence client immediately after decode so
    /// the rest of the app never has to worry about mismatched layouts.
    public static func normalize(_ layout: CycleStatsLayout) -> CycleStatsLayout {
        let known = Set(CycleStatsCard.allCases)
        var order = layout.order.filter { known.contains($0) }
        let seen = Set(order)
        for card in CycleStatsCard.allCases where !seen.contains(card) {
            order.append(card)
        }
        let hidden = layout.hidden.intersection(known)
        return CycleStatsLayout(order: order, hidden: hidden)
    }
}
