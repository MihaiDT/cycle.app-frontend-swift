import SwiftUI

// MARK: - HBI Score Ring

public struct HBIScoreRing: View {
    public let score: Int
    public let animationProgress: Double
    public let size: CGFloat

    @State private var isBreathing = false

    public init(score: Int, animationProgress: Double = 1.0, size: CGFloat = 180) {
        self.score = score
        self.animationProgress = animationProgress
        self.size = size
    }

    private var displayScore: Int {
        Int(Double(score) * animationProgress)
    }

    private var ringProgress: Double {
        Double(score) / 100.0 * animationProgress
    }

    private var scoreColor: Color {
        switch score {
        case 80...100: DesignColors.accentWarm
        case 60..<80: DesignColors.accent
        case 40..<60: DesignColors.structure
        default: DesignColors.textSecondary
        }
    }

    public var body: some View {
        ZStack {
            // Breathing glow
            Circle()
                .fill(scoreColor.opacity(0.1))
                .frame(width: size + 24, height: size + 24)
                .scaleEffect(isBreathing ? 1.04 : 1.0)
                .blur(radius: 12)

            // Track
            Circle()
                .stroke(DesignColors.divider.opacity(0.3), lineWidth: 8)
                .frame(width: size, height: size)

            // Progress arc
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [scoreColor.opacity(0.4), scoreColor, scoreColor],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Inner glass circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size - 32, height: size - 32)
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

            // Score number + label
            VStack(spacing: 4) {
                Text("\(displayScore)")
                    .font(.custom("Raleway-Bold", size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignColors.text, DesignColors.accentWarm],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())

                Text("HBI Score")
                    .font(.custom("Raleway-Medium", size: 13))
                    .foregroundColor(DesignColors.textSecondary)
                    .tracking(1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        HBIScoreRing(score: 76, animationProgress: 1.0)
    }
}
