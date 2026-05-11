import Foundation

// MARK: - Pattern Reading
//
// Shared editorial-paragraph model used by both BodyPatterns
// surfaces:
//   • `BodyPatternsReadingCard` (root feed) — overview reading
//     synthesising across the user's confirmed and emerging
//     patterns.
//   • `PatternReadingSection` (detail screen) — per-pattern
//     reading sitting after the Highlights stat tiles.
//
// Both surfaces render a single editorial paragraph with sentence-
// line-breaks. The model stays minimal on purpose — the rendering
// cards do not need shape, severity, or per-day arrays here; that
// data lives on `DetectedPattern` and `PatternMetrics`. This struct
// carries only the synthesised copy + an optional phase tint for
// the eyebrow accent dot.
//
// Computed by the future Why Engine (`CycleNarrativeEngine`) over
// `DetectedPattern[]` + `PatternMetrics` + cycle aggregates. Stays
// decoupled from `CycleRecapRecord` — these readings live in the
// patterns surface, not in the recap surface.

public struct PatternReading: Equatable, Sendable {
    /// Single editorial paragraph (2-3 sentences). The card's
    /// formatter inserts hard line breaks per sentence so each
    /// thought owns its own breath.
    public let copy: String

    /// Optional phase tint for the eyebrow accent dot. Nil → falls
    /// back to a neutral dot (`textSecondary`). Used only by the
    /// root `BodyPatternsReadingCard` eyebrow; the detail
    /// `PatternReadingSection` doesn't render an eyebrow because
    /// the host screen already names the phase in its header.
    public let phase: CyclePhase?

    public init(copy: String, phase: CyclePhase? = nil) {
        self.copy = copy
        self.phase = phase
    }
}
