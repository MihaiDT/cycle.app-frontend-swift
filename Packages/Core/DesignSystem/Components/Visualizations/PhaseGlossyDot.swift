import SwiftUI

// MARK: - Phase Glossy Dot
//
// Small tinted dot with a top-down gradient fill plus a subtle white
// specular highlight at the crown. Same material language as the
// per-day dots on the Cycle History bar — extracted here so any UI
// element that needs the "phase chip" (Cycle History bar + legend,
// Body Signals phase badge, future phase indicators) can render the
// exact same ink instead of drifting into one-off flat circles.
//
// The glossy treatment is intentionally lightweight (~2 shapes per
// dot) — the full `liquidGlass` modifier was too expensive at the
// densities the History bar reaches (30+ dots × multiple cycles).

public struct PhaseGlossyDot: View {
    public let tint: Color
    public let size: CGFloat
    public let tintOpacity: Double

    public init(tint: Color, size: CGFloat = 7, tintOpacity: Double = 0.95) {
        self.tint = tint
        self.size = size
        self.tintOpacity = tintOpacity
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(tintOpacity),
                            tint.opacity(max(tintOpacity - 0.25, 0.2))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.7, height: size * 0.35)
                .offset(y: 0.4)
        }
        .frame(width: size, height: size)
    }
}
