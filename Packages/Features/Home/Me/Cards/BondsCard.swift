import SwiftUI

// MARK: - Bonds Card
//
// Empty-state hero for "Your bonds". Painted watercolour backdrop
// (the four menstruation-cycle phase glyph colours blended as soft
// overlapping blobs, not a linear gradient) bleeds through a glass
// surface — the card reads as a frosted window over a hand-painted
// palette rather than a flat tile. Inside: a "you" disc + a dashed
// empty disc with `+` inviting the user to add their first bond.

private enum BondsCardMetrics {
    static let cornerRadius: CGFloat = 28
    static let horizontalPadding: CGFloat = 14
    static let contentHorizontal: CGFloat = 22
    static let contentTop: CGFloat = 22
    static let contentBottom: CGFloat = 26
    static let circleSize: CGFloat = 140
    static let circleOverlap: CGFloat = 8
    static let chipSize: CGFloat = 30
}

public struct BondsCard: View {
    public let onAddTap: () -> Void
    public let onArrowTap: () -> Void

    public init(
        onAddTap: @escaping () -> Void,
        onArrowTap: @escaping () -> Void = {}
    ) {
        self.onAddTap = onAddTap
        self.onArrowTap = onArrowTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            headerRow

            circlePair

            footerRow
        }
        .padding(.horizontal, BondsCardMetrics.contentHorizontal)
        .padding(.top, BondsCardMetrics.contentTop)
        .padding(.bottom, BondsCardMetrics.contentBottom)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: BondsCardMetrics.cornerRadius, style: .continuous)
                .strokeBorder(DesignColors.divider.opacity(0.45), lineWidth: 0.5)
        )
        .shadow(color: DesignColors.text.opacity(0.10), radius: 22, x: 0, y: 12)
        .shadow(color: DesignColors.text.opacity(0.04), radius: 3, x: 0, y: 1)
        .padding(.horizontal, BondsCardMetrics.horizontalPadding)
    }

    /// Card backdrop matched 1:1 to the Daily Insight card's
    /// surface so the two surfaces read as one editorial system:
    /// subtle cycle-phase corner blooms (half-opacity vs the
    /// original Bonds bloom) + the peach liquid asset overflowing
    /// one corner + a whisper of frosted material that ties the
    /// layers together.
    private var cardSurface: some View {
        ZStack(alignment: .topLeading) {
            DesignColors.background

            // Top-leading — period rose
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

            // Bottom-trailing — luteal mauve
            Circle()
                .fill(DesignColors.calendarLutealGlyph.opacity(0.22))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 90, y: 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Soft glass frost ties the corner blooms together
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.22)
        }
        .clipShape(RoundedRectangle(cornerRadius: BondsCardMetrics.cornerRadius, style: .continuous))
        // Rasterise the multi-layer surface (ivory + 4 blurred
        // corner blobs + frosted material) into a single Metal
        // texture so the GPU only has to translate the texture
        // during scroll instead of redrawing every layer per frame.
        .drawingGroup(opaque: false)
    }

    // MARK: - Sections

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("How you\nflow together")
                .font(.raleway("Bold", size: 30, relativeTo: .title))
                .tracking(-0.6)
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
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Dashed cycle-gradient arrow chip — same treatment as
            // the Story card's top-right hint so the two surfaces
            // rhyme. Suggests "tap to open" without committing to a
            // labelled button.
            arrowChip
        }
    }

    private var arrowChip: some View {
        Button(action: onArrowTap) {
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
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignColors.text)
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("See your bonds")
    }

    private var circlePair: some View {
        HStack(spacing: -BondsCardMetrics.circleOverlap) {
            youCircle
            emptyBondCircle
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var footerRow: some View {
        HStack(spacing: 10) {
            Text("Add the people who matter - see what's between you.")
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Pieces

    private var youCircle: some View {
        blob(asset: "BondBlobYou", rotation: -12) {
            Text("you")
                .font(.raleway("Bold", size: 24, relativeTo: .title2))
                .tracking(-0.4)
                .foregroundStyle(DesignColors.text)
        }
    }

    private var emptyBondCircle: some View {
        Button(action: onAddTap) {
            blob(asset: "BondBlobEmpty", rotation: 140) {
                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DesignColors.text)
                    Text("Add bond")
                        .font(.raleway("SemiBold", size: 11, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.text.opacity(0.65))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add first person")
        .contentShape(Circle())
    }

    /// Renders the on-brand pink blob asset at the given rotation
    /// angle with the content laid over it. Rotating the asset (not
    /// the content) lets the same source PNG read as two distinct
    /// shapes — the asymmetric silhouette catches light differently
    /// at each angle so the pair feels intentional, not duplicated.
    private func blob<Content: View>(
        asset: String,
        rotation: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Image(asset)
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(rotation))

            content()
        }
        .frame(width: BondsCardMetrics.circleSize, height: BondsCardMetrics.circleSize)
    }

}

#Preview {
    BondsCard(onAddTap: {})
        .padding(.vertical, 40)
        .background(DesignColors.background)
}
