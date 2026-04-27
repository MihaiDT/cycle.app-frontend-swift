import SwiftUI

// MARK: - Glossy Bar
//
// Tinted bar with a top-down gradient base and a soft white specular
// sheen at the crown. Same material language as the per-day dots on
// Cycle History (`PhaseGlossyDot`) — extracted here so any chart that
// stacks vertical bars (Cycle Trend, HRV-by-phase, future charts)
// uses the exact same ink instead of drifting into one-off
// `LinearGradient` calls.
//
// `tintOpacity` lets the same call site render an "active / past"
// hierarchy (current bar at 1.0, past bars at ~0.45) by dimming the
// whole bar — including the specular — so muted bars don't look
// suspiciously crisp at the top.

public struct GlossyBar: View {
    public let tint: Color
    public let tintOpacity: Double
    public let height: CGFloat
    public let cornerRadius: CGFloat

    public init(
        tint: Color,
        tintOpacity: Double = 1.0,
        height: CGFloat,
        cornerRadius: CGFloat = 10
    ) {
        self.tint = tint
        self.tintOpacity = tintOpacity
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(tintOpacity),
                        tint.opacity(max(tintOpacity - 0.28, tintOpacity * 0.55))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: height)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: max(cornerRadius - 3, 4), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55 * tintOpacity),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 3)
                    .padding(.top, 2)
                    .frame(height: min(22, max(8, height * 0.22)))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
