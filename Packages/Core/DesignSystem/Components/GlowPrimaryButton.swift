import SwiftUI

// MARK: - Glow Primary Button Style

/// Full-width dark cocoa CTA with a cream circular arrow badge.
/// Matches the "Start challenge" button on the Daily Glow detail screen.
/// Use for the single most important action on a screen — not for secondary or exploratory buttons.
public struct GlowPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
                .font(.custom("Raleway-Black", size: 17))
                .tracking(-0.2)
                .foregroundStyle(DesignColors.background)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignColors.text)
                .frame(width: 32, height: 32)
                .background(Circle().fill(DesignColors.background))
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 26)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(DesignColors.text)
        )
        .shadow(color: DesignColors.text.opacity(DesignColors.shadowOpacityPrimary), radius: 20, x: 0, y: 8)
        .shadow(color: DesignColors.text.opacity(DesignColors.shadowOpacitySecondary), radius: 4, x: 0, y: 2)
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
