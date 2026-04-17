import SwiftUI

public extension Animation {
    /// Snappy: element appears on screen (response: 0.15, damping: 0.6)
    static let appSnappy: Animation = .spring(response: 0.15, dampingFraction: 0.6)

    /// Balanced: content transitions (response: 0.4, damping: 0.8)
    static let appBalanced: Animation = .spring(response: 0.4, dampingFraction: 0.8)

    /// Reveal: staged entrances for hero/celebration elements — slightly slower
    /// start, gentle settle without bounce. Used for RatingBadge pop, LevelUp
    /// overlay, Challenge celebration cards (response: 0.5, damping: 0.8).
    static let appReveal: Animation = .spring(response: 0.5, dampingFraction: 0.8)

    /// Bouncy: celebratory reveals with visible oscillation (response: 0.45,
    /// damping: 0.92). Prefer `.appReveal` for hero entrances where the bounce
    /// would feel off-brand.
    static let appBouncy: Animation = .spring(response: 0.45, dampingFraction: 0.92)
}
