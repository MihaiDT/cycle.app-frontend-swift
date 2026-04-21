import SwiftUI

// MARK: - Wellness Ritual Tile
//
// Square card tile used in the Wellness section to represent the day's
// rituals (check-in, moment). Styled like Cal AI's macro tiles: bold
// title + subtitle stacked at the top, big asset area at the bottom.
// The asset area is intentionally generous — future iterations will
// drop Lottie animations / custom illustrations in here without having
// to restructure the layout.

public struct WellnessRitualTile: View {
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let isDone: Bool
    public let onTap: (() -> Void)?

    public init(
        title: String,
        subtitle: String,
        iconName: String,
        isDone: Bool,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.isDone = isDone
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                textBlock
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(18)
            .frame(minHeight: 190)
            .widgetCardStyle()
            .opacity(isDone ? 0.75 : 1)
            .overlay(alignment: .topTrailing) {
                if isDone { doneBadge }
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDone || onTap == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isDone ? "done" : "pending"). \(subtitle)")
        .accessibilityAddTraits(isDone ? [] : [.isButton])
    }

    // MARK: Text

    @ViewBuilder
    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.raleway("Bold", size: 20, relativeTo: .title3))
                .tracking(-0.3)
                .foregroundStyle(isDone ? DesignColors.textSecondary : DesignColors.text)
                .lineLimit(1)

            Text(isDone ? "Done" : subtitle)
                .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                .tracking(0.1)
                .foregroundStyle(
                    isDone ? DesignColors.accentWarmText : DesignColors.textSecondary
                )
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: Asset

    /// Bottom visual anchor. Circular plate with an SF Symbol today — in
    /// the future swap in a Lottie / PNG / SVG without changing the tile
    /// layout. Size stays constant so tiles line up across the grid.
    @ViewBuilder
    private var assetBlock: some View {
        HStack {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(
                        isDone
                            ? DesignColors.accentWarm.opacity(0.14)
                            : DesignColors.accentWarm.opacity(0.18)
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        isDone
                            ? DesignColors.accentWarmText.opacity(0.75)
                            : DesignColors.accentWarm
                    )
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Done badge (top-right checkmark)

    @ViewBuilder
    private var doneBadge: some View {
        ZStack {
            Circle()
                .fill(DesignColors.accentWarm)
                .frame(width: 22, height: 22)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .padding(12)
        .accessibilityHidden(true)
    }

}

// MARK: - Preview

#Preview("Grid") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                WellnessRitualTile(
                    title: "Check-in",
                    subtitle: "How do you feel?",
                    iconName: "heart.fill",
                    isDone: false,
                    onTap: {}
                )
                WellnessRitualTile(
                    title: "Your moment",
                    subtitle: "Scent ritual",
                    iconName: "drop.fill",
                    isDone: false,
                    onTap: {}
                )
            }

            HStack(spacing: 12) {
                WellnessRitualTile(
                    title: "Check-in",
                    subtitle: "How do you feel?",
                    iconName: "heart.fill",
                    isDone: true,
                    onTap: {}
                )
                WellnessRitualTile(
                    title: "Your moment",
                    subtitle: "Scent ritual",
                    iconName: "drop.fill",
                    isDone: true,
                    onTap: {}
                )
            }
        }
        .padding(18)
    }
}
