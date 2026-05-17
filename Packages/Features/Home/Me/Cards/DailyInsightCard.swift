import SwiftUI

// MARK: - Daily Insight Card
//
// Editorial card inspired by Stoic / journal-prompt apps: a small
// phase pill at the top, then the insight rendered as a large
// centred question that fills the card. The trailing "Save it"
// pill and ellipsis menu sit at the bottom + top-right corners so
// the focal point of the surface stays the writing itself.

private enum DailyInsightMetrics {
    static let cornerRadius: CGFloat = 22
    /// Lowered from 320 — at 320 the centring spacers fanned out
    /// by ~30pt each, producing visible ivory dead-space above the
    /// eyebrow pill (especially obvious when the collapsed Me
    /// navbar pinned the card right under the status bar). At 220
    /// the natural content fits without forcing the spacers to
    /// expand beyond their minLength, so the card hugs its text.
    static let minHeight: CGFloat = 220
    static let menuTop: CGFloat = 14
    static let menuTrailing: CGFloat = 14
    static let contentHorizontal: CGFloat = 28
    static let contentVerticalPadding: CGFloat = 30
}

public struct DailyInsightCard: View {
    public let insight: DailyInsightItem
    /// Whether the displayed insight is currently saved (hearted).
    /// Owned by the parent feature so the state persists across
    /// the InsightHistory overlay being opened / dismissed and so
    /// unliking a card from the history mirrors back to the heart
    /// fill on this card.
    public let isSaved: Bool
    public let onSavedTap: () -> Void
    public let onMenuTap: () -> Void

    /// Counter that increments on every tap so the keyframe
    /// animator re-runs from the start each time (a bool toggle
    /// would skip alternating taps).
    @State private var heartTrigger: Int = 0

    /// Wall-clock start of the current flight. `TimelineView`
    /// reads it on every frame and derives progress from the
    /// elapsed interval — this is the only way to get arc + pop
    /// curves visible, since `withAnimation` only delivers two
    /// body evaluations (start, end) and SwiftUI's interpolation
    /// is linear between them, which collapses the arc / pop to
    /// zero (sin(0)=sin(π)=0, opacity 0 at both ends).
    @State private var flightStartDate: Date? = nil

    /// Trigger for the chip's "filled" punch — pulses the chip
    /// at the exact frame the ghost arrives so it reads as the
    /// ghost merging into / filling the chip's heart.
    @State private var chipPunchTrigger: Int = 0

    /// Tracks whether the chip should render its heart filled.
    /// Toggled to true mid-flight (when the ghost reaches the
    /// chip) so the icon transitions from outline to filled at
    /// the moment of impact via `contentTransition(.symbolEffect)`.
    @State private var chipHeartFilled: Bool = false

    public init(
        insight: DailyInsightItem,
        isSaved: Bool,
        onSavedTap: @escaping () -> Void,
        onMenuTap: @escaping () -> Void = {}
    ) {
        self.insight = insight
        self.isSaved = isSaved
        self.onSavedTap = onSavedTap
        self.onMenuTap = onMenuTap
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 28) {
                Spacer(minLength: 4)

                phasePill

                Text(insight.text)
                    .font(.raleway("Medium", size: 26, relativeTo: .title2))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, DailyInsightMetrics.contentHorizontal)
            .padding(.vertical, DailyInsightMetrics.contentVerticalPadding)
            .frame(maxWidth: .infinity, minHeight: DailyInsightMetrics.minHeight)

            arrowChip
                .padding(.top, DailyInsightMetrics.menuTop)
                .padding(.trailing, DailyInsightMetrics.menuTrailing)

            heartSaveButton
                .padding(.bottom, DailyInsightMetrics.menuTop)
                .padding(.leading, DailyInsightMetrics.menuTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            flyingHeartOverlay
        }
        .background(cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: DailyInsightMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: DesignColors.text.opacity(0.10), radius: 22, x: 0, y: 10)
        .shadow(color: DesignColors.text.opacity(0.04), radius: 3, x: 0, y: 1)
        .padding(.horizontal, 14)
        // Whole card is tappable — same destination as the arrow
        // chip. Heart + arrow chip handle their own taps first
        // (Buttons get priority over `onTapGesture`).
        .contentShape(RoundedRectangle(cornerRadius: DailyInsightMetrics.cornerRadius, style: .continuous))
        .onTapGesture {
            onMenuTap()
        }
    }

    /// Card backdrop layered with three accents that rhyme with the
    /// Bonds card without being as saturated:
    ///   1. Cycle-phase corner blobs (half-opacity vs Bonds) so the
    ///      surface ties into the same palette family,
    ///   2. The peach liquid asset overflowing bottom-right,
    ///   3. A whisper of frosted material to soften every layer
    ///      into a single editorial wash.
    private var cardSurface: some View {
        ZStack(alignment: .bottomTrailing) {
            DesignColors.background

            // Top-leading — period rose (very subtle)
            Circle()
                .fill(DesignColors.calendarPeriodGlyph.opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: -100, y: -100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Top-trailing — follicular oat
            Circle()
                .fill(DesignColors.calendarFollicularGlyph.opacity(0.30))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 100, y: -90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Bottom-leading — fertile sand
            Circle()
                .fill(DesignColors.calendarFertileGlyph.opacity(0.20))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: -90, y: 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // Bottom-trailing — luteal mauve (paired with the liquid)
            Circle()
                .fill(DesignColors.calendarLutealGlyph.opacity(0.22))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 90, y: 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Peach liquid overflow accent
            Image("InsightLiquid")
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
                .opacity(0.80)
                .offset(x: 60, y: 70)

            // Soft glass frost ties everything together
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.22)
        }
        .clipShape(RoundedRectangle(cornerRadius: DailyInsightMetrics.cornerRadius, style: .continuous))
        // Rasterise the multi-layer surface (ivory + 4 blurred
        // corner blobs + liquid asset + frosted material) into a
        // single texture — GPU just translates during scroll
        // instead of recomposing every frame.
        .drawingGroup(opaque: false)
    }

    private var phasePill: some View {
        Text(insight.phaseLabel)
            .font(.raleway("SemiBold", size: 12, relativeTo: .footnote))
            .tracking(-0.1)
            .foregroundStyle(DesignColors.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.6)
            )
            .shadow(color: DesignColors.text.opacity(0.10), radius: 8, x: 0, y: 3)
    }

    /// Dashed cycle-gradient heart chip — destination of the
    /// fly-to-save animation. The heart inside transitions from
    /// outline to filled the moment the ghost arrives, so the
    /// "save" reads as the ghost merging into / filling this
    /// chip. Same dashed gradient as the original arrow chip so
    /// it visually rhymes with the Story / Bonds cards' chips.
    private var arrowChip: some View {
        Button(action: onMenuTap) {
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                DesignColors.calendarPeriodGlyph,
                                DesignColors.calendarFollicularGlyph,
                                DesignColors.calendarFertileGlyph,
                                DesignColors.calendarLutealGlyph,
                                DesignColors.calendarPeriodGlyph,
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 1.4, dash: [3, 4])
                    )

                Image(systemName: chipHeartFilled ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        chipHeartFilled
                            ? DesignColors.calendarPeriodGlyph
                            : DesignColors.text
                    )
                    .contentTransition(.symbolEffect(.replace.downUp))
                    // Punch on arrival — scales up briefly then
                    // settles. Re-uses the same keyframe shape
                    // as the heart-button burst so the two
                    // gestures rhyme.
                    .keyframeAnimator(
                        initialValue: 1.0,
                        trigger: chipPunchTrigger
                    ) { content, value in
                        content.scaleEffect(value)
                    } keyframes: { _ in
                        KeyframeTrack {
                            SpringKeyframe(1.45, duration: 0.14, spring: .snappy)
                            SpringKeyframe(1.0, duration: 0.34, spring: .bouncy)
                        }
                    }
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Saved insights")
    }

    /// Ghost heart that flies from the heart button (bottom-
    /// leading) to the chip (top-trailing) — driven by
    /// `TimelineView(.animation)` so every frame re-evaluates
    /// the arc + pop calculations. Active only while
    /// `flightStartDate != nil`, so it costs nothing at rest.
    private var flyingHeartOverlay: some View {
        GeometryReader { proxy in
            // Heart button center inside the card body.
            let startX = DailyInsightMetrics.menuTrailing + 22
            let startY = proxy.size.height - DailyInsightMetrics.menuTop - 22
            // Chip center inside the card body.
            let endX = proxy.size.width - DailyInsightMetrics.menuTrailing - 26
            let endY = DailyInsightMetrics.menuTop + 26
            let dx = endX - startX
            let dy = endY - startY
            // Arc rises ~40% of the card height at midpoint —
            // visibly a semicircle, not a near-straight line.
            let arcPeak = proxy.size.height * 0.4

            if let start = flightStartDate {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    let duration: TimeInterval = 1.1
                    let raw = max(0, min(elapsed / duration, 1.0))

                    // Ease-in-out cubic shaping on the linear
                    // progress so the heart accelerates out of
                    // the button and decelerates into the chip.
                    let progress: CGFloat = raw < 0.5
                        ? 2 * CGFloat(raw) * CGFloat(raw)
                        : 1 - pow(-2 * CGFloat(raw) + 2, 2) / 2

                    let arc = sin(progress * .pi) * arcPeak
                    let popPhase = min(progress / 0.10, 1.0)
                    let endPhase = max(0, (progress - 0.88) / 0.12)
                    let scale = 1.0 + 0.35 * popPhase - 0.6 * endPhase
                    let opacity = raw < 1.0 ? min(popPhase, 1.0 - endPhase) : 0

                    Image(systemName: "heart.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(DesignColors.calendarPeriodGlyph)
                        .shadow(color: DesignColors.calendarPeriodGlyph.opacity(0.5), radius: 12, x: 0, y: 0)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .position(
                            x: startX + dx * progress,
                            y: startY + dy * progress - arc
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    /// Triggers the fly-to-chip animation. Only called on save.
    /// Sets `flightStartDate`, which causes the `TimelineView`
    /// inside `flyingHeartOverlay` to mount and start ticking at
    /// 60Hz. The chip fills + punches at ~1.0s so the fill lands
    /// exactly when the ghost arrives, then transitions back to
    /// outline once the punch has settled — the chip is a
    /// destination cue, not a persistent saved-count indicator,
    /// so it shouldn't stay filled.
    private func launchHeartFlight() {
        flightStartDate = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Second haptic at the impact moment — the first one
            // fired when the user tapped the heart button; this
            // one confirms the ghost has landed in the chip. A
            // .rigid impact reads as a slightly firmer "click"
            // than the soft impact on the tap, so the two
            // gestures don't feel identical.
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            chipHeartFilled = true
            chipPunchTrigger &+= 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // Tear the TimelineView down so it stops re-rendering
            // the card at 60Hz once the flight is over.
            flightStartDate = nil
        }
        // Return the chip to its resting outline state after the
        // punch settles (punch keyframes total ~0.48s). Wrapped
        // in withAnimation so the symbol-effect transition runs.
        // A lighter haptic at this moment so the unfill reads as
        // the heart "departing" — softer than the rigid impact
        // on arrival.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation {
                chipHeartFilled = false
            }
        }
    }

    /// Instagram-style like: haptic punch + keyframe burst that
    /// snaps up to 1.45x and settles back through a bouncy spring.
    /// `keyframeAnimator` runs the whole sequence on the render
    /// thread without a DispatchQueue hop, so the punch and the
    /// settle stay in lockstep — no perceptible mid-animation lag.
    private var heartSaveButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            heartTrigger &+= 1
            // Fire the fly-to-arrow only when saving, not when
            // unsaving — the animation would feel like the wrong
            // direction otherwise.
            if !isSaved {
                launchHeartFlight()
            }
            onSavedTap()
        } label: {
            Image(systemName: isSaved ? "heart.fill" : "heart")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(
                    isSaved
                        ? DesignColors.calendarPeriodGlyph
                        : DesignColors.text.opacity(0.55)
                )
                .contentTransition(.symbolEffect(.replace.downUp))
                .keyframeAnimator(
                    initialValue: 1.0,
                    trigger: heartTrigger
                ) { content, value in
                    content.scaleEffect(value)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(1.45, duration: 0.14, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.34, spring: .bouncy)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Saved" : "Save insight")
    }
}

#Preview {
    DailyInsightCard(
        insight: .mock,
        isSaved: false,
        onSavedTap: {}
    )
    .padding(.vertical, 40)
    .background(DesignColors.background)
}
