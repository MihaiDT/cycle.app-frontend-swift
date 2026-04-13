import SwiftUI

// MARK: - Glow Card Background

public extension View {
    /// Warm ivory-to-pink gradient card background used across the Home card
    /// stack and the Daily Glow challenge card. Includes the rose-accented
    /// 0.5pt border and corner clipping so consumers don't have to repeat it.
    func glowCardBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DesignColors.cardGradientStart, DesignColors.cardGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignColors.text.opacity(0.08),
                                    DesignColors.accentWarm.opacity(0.22),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
    }
}
