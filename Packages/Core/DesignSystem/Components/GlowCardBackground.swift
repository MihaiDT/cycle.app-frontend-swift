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
                        colors: [DesignColors.background, DesignColors.cardGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignColors.structure.opacity(0.4),
                                    DesignColors.accentWarm.opacity(0.15),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
    }
}
