import SwiftUI

// MARK: - Pattern Stat Tile
//
// Single metric tile rendered inside `PatternHighlightsCard`'s
// 2-column grid. Same idiom as Apple Health's Activity / Workout
// summary tiles — small caps title at the top, big bold value
// in the middle, secondary line at the bottom.
//
// All tiles ride on the shared `widgetCardStyle` (Liquid Glass on
// iOS 26, white fallback below) — the four insights have equal
// semantic weight, so a saturated hero would be design-driven
// hierarchy without data backing. The phase ink shows up in
// content accents (trend chevron) rather than as a tile fill.

struct PatternStatTile: View {
    let label: String
    let value: String
    let unit: String?
    let subtitle: String
    var trendDirection: TrendDirection? = nil
    let palette: BodyPatternsPalette
    var onTap: (() -> Void)? = nil

    enum TrendDirection {
        case up, down

        var systemName: String {
            switch self {
            case .up:   return "chevron.up"
            case .down: return "chevron.down"
            }
        }
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
            onTap?()
        } label: {
            tileContent
                // `interactive: false` — the custom
                // `PatternStatTilePressStyle` already paints the
                // press feedback (phase tint overlay + scale +
                // opacity). iOS 26's interactive glass shader on
                // top of that competed with the Button for
                // hit-testing and occasionally ate taps —
                // matches "I had to tap a tile twice to drill
                // in" + the `IOSurfaceClientSetSurfaceNotify`
                // console errors.
                .widgetCardStyle(cornerRadius: 22, interactive: false)
        }
        .buttonStyle(PatternStatTilePressStyle(tint: palette.accent, cornerRadius: 22))
    }

    // MARK: - Content

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            valueLine
            Text(subtitle)
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)\(unit.map { " \($0)" } ?? ""), \(subtitle)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(1)
            if let trendDirection {
                Image(systemName: trendDirection.systemName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
        }
    }

    // MARK: - Value

    private var valueLine: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value)
                .font(.raleway("Bold", size: 28, relativeTo: .title2))
                .tracking(-0.5)
                .monospacedDigit()
                .foregroundStyle(DesignColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let unit {
                Text(unit)
                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Press style
//
// Custom `ButtonStyle` that paints a phase-ink tint over the tile
// while the user holds it down. iOS 26's native `.glassEffect(...
// .interactive())` only renders a subtle shader ripple — no color.
// Stacking this style on top adds the visible "tap ink" the user
// expects from a tappable card on cycle.app, while leaving the
// underlying Liquid Glass shader to handle the press shimmer.

private struct PatternStatTilePressStyle: ButtonStyle {
    let tint: Color
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
                    .opacity(configuration.isPressed ? 0.16 : 0)
                    .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: configuration.isPressed)
    }
}
