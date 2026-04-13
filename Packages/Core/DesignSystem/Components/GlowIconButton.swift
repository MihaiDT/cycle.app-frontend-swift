import SwiftUI

// MARK: - Glow Icon Button Style

/// Circular dark cocoa icon button with a cream-colored label.
/// The icon-only companion to `GlowPrimaryButtonStyle` — use for top-bar
/// actions (notifications, calendar) that should visually sit alongside
/// the primary CTA treatment without carrying a full text label.
public struct GlowIconButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(DesignColors.background)
            .frame(width: 44, height: 44)
            .background(
                Circle().fill(DesignColors.text)
            )
            .shadow(color: DesignColors.text.opacity(DesignColors.shadowOpacityPrimary), radius: 12, x: 0, y: 6)
            .shadow(color: DesignColors.text.opacity(DesignColors.shadowOpacitySecondary), radius: 3, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
