import SwiftUI

// MARK: - Pattern Widget Card
//
// One detected pattern, rendered in the Gentler-Streak idiom:
//
//   ┌───────────────────────────────────────────┐
//   │  💧  MENSTRUAL                            │
//   │                                           │
//   │  Cramps                          ┐        │
//   │                                  │ 3      │← ghost
//   │  Estrogen drops, prostaglandins  ┘        │  numeral
//   │  spike. Day 1 to 2.                       │
//   └───────────────────────────────────────────┘
//
// Layout intent:
//   * Hero ghost numeral lives in the trailing edge of the
//     card (Apple Health / Gentler Streak idiom). It anchors
//     the card without competing with the editorial column.
//   * Editorial column reads top-down: phase eyebrow w/
//     SF Symbol → symptom title → hormonal body line.
//   * On appear, the ghost numeral counts from 0 → occurrences
//     so the card "seeds" itself rather than landing static.
//   * Card stays non-interactive in Phase 1/2 — the detail
//     screen ships in Phase 3.

struct PatternWidgetCard: View {
    let pattern: DetectedPattern

    var onTap: () -> Void = {}

    private var palette: BodyPatternsPalette {
        BodyPatternsPalette.forPhase(pattern.phase)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                backdrop
                textureOverlay
                ghostNumeral
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.10),
                                palette.accent.opacity(0.30),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: palette.accent.opacity(0.18), radius: 18, x: 0, y: 10)
            .opacity(pattern.isEmerging ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this pattern's recap")
    }

    // MARK: - Backdrop

    /// Capped at 0.85 even on a 100% match so the upper sliver
    /// stays pale — saturated phase ink at full fill turned
    /// the card into an alert anchor.
    private var backdrop: some View {
        let raw = pattern.totalCycles > 0
            ? CGFloat(pattern.occurrences) / CGFloat(pattern.totalCycles)
            : 0
        let bounded = min(raw, 0.85)
        return WaterFillBackdrop(
            fillRatio: bounded,
            color: palette.accent,
            glow: palette.glow
        )
    }

    // MARK: - Texture overlay

    /// Subtle warm-cool gradient veil over the card — gives
    /// the colour block a temperature shift instead of reading
    /// as a single saturated tone. The veil leans warmer in
    /// the top-leading corner (where the editorial title
    /// lives) and cooler at the bottom-trailing where the
    /// ghost numeral sits, so the eye reads depth.
    private var textureOverlay: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.18),
                Color.clear,
                palette.accent.opacity(0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }

    // MARK: - Ghost numeral

    /// Pale gigantic numeral living in the trailing edge of
    /// the card — Apple Health hero device. Gradient stays
    /// strong enough that the user reads it as the card's
    /// hero element, not as a watermark.
    private var ghostNumeral: some View {
        // Watermark glyph — uses the same `symptomIcon`
        // helper as the calendar log sheet, so the card
        // shows the user's actual symptom artwork (custom
        // asset when present, SF Symbol fallback otherwise).
        // The "of N cycles" caption was removed — the
        // recurring/just-appearing section title above the
        // carousel already names the strength of the signal.
        Group {
            if let symptom = matchedSymptomType {
                symptomIcon(for: symptom, size: 110)
            } else {
                Image(systemName: pattern.symptomIconName)
                    .font(.system(size: 110, weight: .light))
            }
        }
        .foregroundStyle(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.70),
                    Color.white.opacity(0.32),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(.top, 22)
        .padding(.trailing, 4)
        .padding(.bottom, 16)
        .allowsHitTesting(false)
    }

    /// Map the pattern's `symptomDisplayName` back to the
    /// strongly-typed `SymptomType`. The detector strips that
    /// type when it builds `DetectedPattern`, so we resolve it
    /// here on demand. Linear scan over `SymptomType.allCases`
    /// is cheap (catalogue is ~60 entries) and runs once per
    /// card render.
    private var matchedSymptomType: SymptomType? {
        SymptomType.allCases.first { $0.displayName == pattern.symptomDisplayName }
    }

    // MARK: - Content

    /// Compact editorial column. Title + body sit close so
    /// the eye reads them as one unit — no more dead space
    /// between the chrome and the body line.
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(pattern.symptomDisplayName)
                .font(.raleway("SemiBold", size: 28, relativeTo: .title2))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignColors.text,
                            DesignColors.textPrincipal,
                            DesignColors.text.opacity(0.85),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .tracking(-0.4)

            Text(pattern.editorial)
                .font(.raleway("Medium", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.accentWarmText.opacity(0.92))
                .lineLimit(3)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.trailing, 88)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Caption

    /// Caption rendered under the ghost numeral. Plain
    /// natural language so the user reads scope at a glance
    /// — "every cycle" (3/3), "across 3 cycles" (2/3, 1/3,
    /// etc.). Skips the bare "of N cycles" math we used to
    /// pair with the numeral.
    private var countCaption: String {
        guard pattern.totalCycles > 0 else { return "" }
        if pattern.occurrences == pattern.totalCycles {
            return pattern.totalCycles == 1
                ? "this cycle"
                : "every cycle"
        }
        return "across \(pattern.totalCycles) cycles"
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let frequency = "\(pattern.occurrences) of \(pattern.totalCycles) cycles"
        return "\(pattern.symptomDisplayName), \(pattern.phaseDisplayName) phase, \(frequency). \(pattern.editorial)"
    }
}
