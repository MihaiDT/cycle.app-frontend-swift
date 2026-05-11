import SwiftUI

// MARK: - Body Patterns Phase Palette
//
// Single source of phase ink for everything on the Body Patterns
// surface — the gauge fill / track, the eyebrow dot, the soft glow
// behind the widget. Mirrors `CycleRhythmReflectionCard.PhasePalette`
// so the two surfaces share the same colour vocabulary; if we ever
// promote a shared `Phase → Color` mapper to DesignSystem, drop this
// file and rewire callers.

struct BodyPatternsPalette: Equatable {
    /// Saturated phase ink — used for filled gauge segments + the
    /// eyebrow dot. Pulled from the canonical phase tokens already
    /// in use on Cycle Stats / Cycle History / Rhythm Reflection.
    let accent: Color

    /// Soft phase wash — used for empty gauge segments. Same hue as
    /// `accent` at low opacity so the gauge reads as a single tinted
    /// arc, not as two unrelated colours.
    let track: Color

    /// Atmospheric phase glow that sits behind the gauge, top-half
    /// only. Cycle.app's analogue of Oura's mountain photo —
    /// dimensional warmth, never a flat fill.
    let glow: Color

    static func forPhase(_ phase: CyclePhase) -> BodyPatternsPalette {
        switch phase {
        case .menstrual:
            return BodyPatternsPalette(
                accent: DesignColors.calendarPeriodGlyph,
                track: DesignColors.calendarPeriodGlyph.opacity(0.16),
                glow:  DesignColors.calendarPeriodGlyph.opacity(0.18)
            )
        case .follicular:
            return BodyPatternsPalette(
                accent: DesignColors.accentSecondary,
                track: DesignColors.accentSecondary.opacity(0.20),
                glow:  DesignColors.accentSecondary.opacity(0.18)
            )
        case .ovulatory:
            return BodyPatternsPalette(
                accent: DesignColors.accentHoney,
                track: DesignColors.accentHoney.opacity(0.22),
                glow:  DesignColors.accentHoney.opacity(0.20)
            )
        case .luteal:
            return BodyPatternsPalette(
                accent: DesignColors.roseTaupe,
                track: DesignColors.roseTaupe.opacity(0.20),
                glow:  DesignColors.roseTaupe.opacity(0.18)
            )
        case .late:
            return BodyPatternsPalette(
                accent: DesignColors.accentHoney,
                track: DesignColors.accentHoney.opacity(0.20),
                glow:  DesignColors.accentHoney.opacity(0.18)
            )
        }
    }

    /// Quiet variant for the empty / "no patterns yet" widget — the
    /// gauge silhouette stays muted neutral instead of taking on a
    /// phase. Caller sites use this when they don't have a phase to
    /// theme around.
    static let neutral = BodyPatternsPalette(
        accent: DesignColors.textSecondary,
        track:  DesignColors.text.opacity(0.10),
        glow:   .clear
    )

    /// SF Symbol that visually anchors the phase on a card —
    /// drop for the bleeding window, leaf for the rising
    /// follicular phase, sun for ovulatory peak, moon for the
    /// luteal wind-down. Replaces the bare phase dot which
    /// disappeared at small sizes against saturated backdrops.
    static func iconName(for phase: CyclePhase) -> String {
        switch phase {
        case .menstrual:  return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulatory:  return "sun.max.fill"
        case .luteal:     return "moon.fill"
        case .late:       return "hourglass"
        }
    }
}
