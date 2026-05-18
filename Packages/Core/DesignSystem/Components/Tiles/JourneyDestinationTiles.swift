import SwiftUI

// MARK: - Journey Destination Card (wide)
//
// Lead box on Home's Journey widget page. Points to the full Journey
// list — the recap-stories flow. Uses the same glass surface
// (`widgetCardStyle`) as the Rhythm hero so the two carousel pages
// feel like siblings from the same system.

public struct JourneyDestinationCard: View {
    public let subtitle: String
    public let isNew: Bool
    public let onTap: () -> Void

    public init(subtitle: String, isNew: Bool, onTap: @escaping () -> Void) {
        self.subtitle = subtitle
        self.isNew = isNew
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                meta
                    .padding(.bottom, 12)

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your story")
                            .font(AppTypography.cardTitlePrimary)
                            .tracking(AppTypography.cardTitlePrimaryTracking)
                            .foregroundStyle(DesignColors.accentWarmText)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    journeyGlyph
                        .frame(width: 84, height: 84)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(18)
        .widgetCardStyle()
        .overlay(alignment: .topTrailing) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                .padding(.top, 12)
                .padding(.trailing, 12)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your Journey. \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var meta: some View {
        HStack(spacing: 8) {
            Text("JOURNEY")
                .font(AppTypography.cardEyebrow)
                .tracking(0.6)
                .foregroundStyle(DesignColors.textSecondary)

            if isNew {
                Text("NEW")
                    .font(.raleway("Black", size: 9, relativeTo: .caption2))
                    .tracking(0.5)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(DesignColors.accentWarm))
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var journeyGlyph: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Journey Destination Tile (half width)
//
// Secondary tile pair under the Journey card. Mirrors the `WellnessRitualTile`
// structure — text block on top-left, bottom-right glyph, glass surface —
// so the Journey page feels identical in rhythm to the Rhythm page.

public struct JourneyDestinationTile: View {
    public enum Kind: Sendable {
        case stats
        case body

        var badge: String {
            switch self {
            case .stats: return "CYCLE STATS"
            // No eyebrow on the body tile — title "Patterns"
            // already communicates the destination, and the
            // caps eyebrow above it would have read redundantly
            // as "BODY PATTERNS / Patterns".
            case .body:  return ""
            }
        }

        var title: String {
            switch self {
            case .stats: return "Averages"
            case .body:  return "Patterns"
            }
        }

        var subtitle: String {
            switch self {
            case .stats: return "Cycle length & trends"
            case .body:  return "Signals by phase"
            }
        }

        var icon: String {
            switch self {
            case .stats: return "chart.bar.fill"
            case .body:  return "heart.text.square.fill"
            }
        }
    }

    public let kind: Kind
    public let stat: String
    public let onTap: () -> Void

    public init(kind: Kind, stat: String, onTap: @escaping () -> Void) {
        self.kind = kind
        self.stat = stat
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                textBlock
                Spacer(minLength: 0)
                bottomRow
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(18)
            .frame(minHeight: 190)
            .widgetCardStyle()
            // Explicit clip after `widgetCardStyle` — on iOS 26
            // `.glassEffect(.regular, in: shape)` clips the glass
            // surface but does NOT clip its child content, so
            // offset / negative-padded children (the body dots
            // grid) painted past the card's rounded edge. This
            // shape clip enforces visual containment so the
            // overflow gets actually cropped at the corner.
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.badge). \(kind.title). \(stat)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !kind.badge.isEmpty {
                Text(kind.badge)
                    .font(AppTypography.cardEyebrow)
                    .tracking(0.6)
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Text(kind.title)
                .font(AppTypography.cardTitleSecondary)
                .tracking(AppTypography.cardTitleSecondaryTracking)
                .foregroundStyle(DesignColors.text)
                .lineLimit(1)

            Text(kind.subtitle)
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .tracking(0.1)
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var bottomRow: some View {
        switch kind {
        case .stats:
            statsBottomRow
        case .body:
            bodyDotsPreview
        }
    }

    /// Original stats bottom row — big numeric stat ("~28d")
    /// + chart-bar glyph in a soft accentWarm disc.
    private var statsBottomRow: some View {
        HStack(alignment: .center) {
            Text(stat)
                .font(.raleway("Bold", size: 22, relativeTo: .title3))
                .tracking(-0.4)
                .foregroundStyle(DesignColors.accentWarmText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(DesignColors.accentWarm.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: kind.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignColors.accentWarm)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Body Patterns mini visualisation — 2-row dot grid that
    /// echoes the heatmap inside the destination screen. Dots
    /// run off the trailing edge so the tile feels like a window
    /// onto a wider chart rather than a closed icon. Last cells
    /// at very low opacity drift toward the card's rounded edge,
    /// where `widgetCardStyle`'s clip drops them — same trailing
    /// fade idiom as the actual `PatternDayHeatmap` mask.
    ///
    /// Pattern is hand-designed (not data-driven) — the tile is
    /// a teaser, not a live readout. Saturation gradient runs
    /// roughly leading→trailing so the visual weight settles in
    /// the lower-left corner where the eye lands after reading
    /// the title block, then trails off to the right as a hint
    /// to "tap to see the rest".
    private var bodyDotsPreview: some View {
        let row1: [Double] = [1.00, 0.85, 0.55, 0.70, 0.25, 0.10]
        let row2: [Double] = [0.65, 0.95, 0.35, 0.15, 0.45, 0.08]
        let row3: [Double] = [0.40, 0.50, 0.20, 0.55, 0.12, 0.05]

        return HStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 7) {
                dotRow(row1)
                dotRow(row2)
                dotRow(row3)
            }
            // Push the grid right (past card's 18pt padding)
            // AND down (past the card's bottom edge). Both
            // axes overflow are clipped by `widgetCardStyle`'s
            // shape — produces a "window onto a wider chart"
            // reading where dots fall away both right and down.
            // Same trailing-fade idiom as `PatternDayHeatmap`.
            .offset(x: 30, y: 22)
        }
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
        .accessibilityHidden(true)
    }

    private func dotRow(_ opacities: [Double]) -> some View {
        HStack(spacing: 7) {
            ForEach(opacities.indices, id: \.self) { idx in
                Circle()
                    .fill(DesignColors.accentWarm.opacity(opacities[idx]))
                    .frame(width: 18, height: 18)
            }
        }
    }
}

// MARK: - Preview

#Preview("Journey destinations") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        VStack(spacing: 12) {
            JourneyDestinationCard(
                subtitle: "Every cycle, a chapter of your story.",
                isNew: true,
                onTap: {}
            )
            HStack(alignment: .top, spacing: 12) {
                JourneyDestinationTile(kind: .stats, stat: "~28d", onTap: {})
                JourneyDestinationTile(kind: .body, stat: "Luteal", onTap: {})
            }
        }
        .padding(20)
    }
}
