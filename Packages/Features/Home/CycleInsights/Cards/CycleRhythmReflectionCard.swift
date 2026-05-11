import SwiftUI

// MARK: - Cycle Rhythm Reflection Card
//
// The closing editorial card on Cycle Stats. Phrased in cycle.app
// voice, attributed to Aria. Visual treatment is bespoke: a phase-
// tinted gradient backdrop, a soft radial highlight catching the
// top-trailing edge like a glaze on porcelain, an oversized phase
// glyph painted at very low opacity as a watermark, the pull-quote
// in serif italic, attribution and a glass share capsule at the
// foot. Treated as a full surface rather than a `widgetCardStyle`
// rectangle so each phase reads with its own colour personality —
// the rest of the screen stays peach-uniform; this card alone
// shifts with where the user is in the cycle.

struct CycleRhythmReflectionCard: View {
    let copy: String
    let phase: CyclePhase?
    let onShare: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
            shareButton
        }
        .frame(maxWidth: .infinity)
        .background(backdrop)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            // Hairline inset border in the phase tint, very low
            // opacity. Reads as a precision rim, not as a stroke —
            // the kind of detail that makes the surface feel
            // machined rather than slabbed on.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(palette.accent.opacity(0.18), lineWidth: 0.6)
        }
        .shadow(color: palette.accent.opacity(0.18), radius: 24, x: 0, y: 8)
    }

    // MARK: - Backdrop

    /// Cream base with the phase tint pouring in from the top —
    /// strongest at the very top edge, fading toward the centre so
    /// the lower half stays cream and the dark serif italic copy
    /// reads cleanly. The top-trailing blob is the focal point; a
    /// whisper of accent under the share button keeps the affordance
    /// tied into the phase colour without bleeding into the text.
    /// Final radial highlight + bottom veil catch the rim like glass.
    private var backdrop: some View {
        ZStack {
            DesignColors.background

            // Top wash — the phase tint comes in from above and
            // settles by the time it reaches the text band. Keeps
            // the bottom half cream so dark serif italic stays
            // legible against it.
            LinearGradient(
                colors: [
                    palette.accent.opacity(0.42),
                    palette.accent.opacity(0.16),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            // Primary blob, top-trailing — the focal accent. Larger
            // and pulled higher than before so the colour reads as
            // weather coming from above, not a corner sticker.
            Circle()
                .fill(palette.accent)
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .opacity(0.58)
                .offset(x: 110, y: -130)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Whisper blob under the share button — just enough to
            // tint the affordance into the phase palette, far enough
            // off-screen and dim enough not to muddy the copy.
            Circle()
                .fill(palette.accent)
                .frame(width: 200, height: 200)
                .blur(radius: 100)
                .opacity(0.22)
                .offset(x: 140, y: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Specular highlight on the rim — light catching glass.
            RadialGradient(
                colors: [
                    Color.white.opacity(0.45),
                    Color.white.opacity(0.0)
                ],
                center: .init(x: 0.92, y: 0.05),
                startRadius: 4,
                endRadius: 200
            )
            .blendMode(.softLight)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Caps eyebrow leads — same vocabulary as the
            // rest of the surface so the reflection card
            // reads as a sibling section instead of an alien
            // editorial island.
            // Section title moved out — see
            // `CycleInsightsView.sectionWrap("Rhythm reflection")`.
            EmptyView()

            // Switched from serif italic to Raleway SemiBold
            // for typographic consistency with Body Patterns
            // / Cycle Stats. Serif italic was the only place
            // on the entire surface using a non-Raleway face,
            // and it read as a foreign chapter in an
            // otherwise unified editorial system.
            Text(formattedCopy)
                .font(.raleway("SemiBold", size: 20, relativeTo: .title3))
                .tracking(-0.2)
                .foregroundStyle(palette.deep.opacity(0.92))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 44)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Force a hard line break after every sentence so the next
    /// sentence's leading word never dangles at the end of the
    /// previous line ("...starting to show. A" / "few more...").
    /// Editorial copy reads cleaner when each thought owns its own
    /// line — the natural cadence of the prose lines up with the
    /// visual cadence of the type.
    private var formattedCopy: String {
        copy
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "? ", with: "?\n")
            .replacingOccurrences(of: "! ", with: "!\n")
    }

    // MARK: - Share button

    /// Native-style circular share button — opaque cream-white fill
    /// with the system glyph in the same dark text token used in the
    /// rest of the app. Reads as the standard Apple in-card action
    /// (Photos / Notes / Health), so the user doesn't have to
    /// register a custom affordance on the one card that already
    /// carries phase colour and serif-italic copy.
    @ViewBuilder
    private var shareButton: some View {
        Button(action: onShare) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignColors.text)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .background { Circle().fill(.regularMaterial) }
                .overlay {
                    Circle()
                        .strokeBorder(DesignColors.text.opacity(0.08), lineWidth: 0.6)
                }
                .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .accessibilityLabel("Share reflection")
    }

    // MARK: - Phase palette

    private var palette: PhasePalette {
        PhasePalette.forPhase(phase)
    }

    /// Per-phase colour set. Each phase gets a 4-stop gradient that
    /// fades from a warmer top-leading hue to a cooler bottom-trailing
    /// settle, plus an `accent` (mid-tone for chrome — the eyebrow
    /// dot, the rim, the share button glass) and a `deep` (text-safe
    /// dark variant). Pulled entirely from the cycle.app palette so
    /// the card stays on-brand.
    fileprivate struct PhasePalette {
        let accent: Color
        let deep: Color
        let symbolName: String

        static func forPhase(_ phase: CyclePhase?) -> PhasePalette {
            switch phase {
            case .menstrual:
                return PhasePalette(
                    accent: DesignColors.calendarPeriodGlyph,
                    deep: DesignColors.text,
                    symbolName: "drop.fill"
                )
            case .follicular:
                return PhasePalette(
                    accent: DesignColors.accentSecondary,
                    deep: DesignColors.accentWarmText,
                    symbolName: "leaf.fill"
                )
            case .ovulatory:
                return PhasePalette(
                    accent: DesignColors.accentHoney,
                    deep: DesignColors.accentHoneyText,
                    symbolName: "sun.max.fill"
                )
            case .luteal:
                return PhasePalette(
                    accent: DesignColors.roseTaupe,
                    deep: DesignColors.accentWarmText,
                    symbolName: "moon.stars.fill"
                )
            case .late:
                return PhasePalette(
                    accent: DesignColors.accentHoney,
                    deep: DesignColors.accentWarmText,
                    symbolName: "clock.fill"
                )
            case .none:
                return PhasePalette(
                    accent: DesignColors.accentWarm,
                    deep: DesignColors.accentWarmText,
                    symbolName: "sparkle"
                )
            }
        }
    }
}
