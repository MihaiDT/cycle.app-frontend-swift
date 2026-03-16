import SwiftUI

// MARK: - Wellness Pillar Card

public struct WellnessPillarCard: View {
    public let name: String
    public let score: Int
    public let icon: String
    public let trend: String?

    public init(name: String, score: Int, icon: String, trend: String? = nil) {
        self.name = name
        self.score = score
        self.icon = icon
        self.trend = trend
    }

    private var trendIcon: String? {
        switch trend {
        case "up": "arrow.up.right"
        case "down": "arrow.down.right"
        case "stable": "arrow.right"
        default: nil
        }
    }

    private var trendColor: Color {
        switch trend {
        case "up": DesignColors.accentWarm
        case "down": DesignColors.textSecondary
        default: DesignColors.textPlaceholder
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingS) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignColors.accentWarm)

                Spacer()

                if let trendIcon {
                    Image(systemName: trendIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(trendColor)
                }
            }

            Text("\(score)")
                .font(.custom("Raleway-Bold", size: 28))
                .foregroundColor(DesignColors.text)

            Text(name)
                .font(.custom("Raleway-Medium", size: 13))
                .foregroundColor(DesignColors.textSecondary)
        }
        .padding(AppLayout.spacingM)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()

        LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            WellnessPillarCard(name: "Energy", score: 72, icon: "bolt.fill", trend: "up")
            WellnessPillarCard(name: "Mood", score: 85, icon: "face.smiling.fill", trend: "up")
            WellnessPillarCard(name: "Sleep", score: 65, icon: "moon.fill", trend: "stable")
            WellnessPillarCard(name: "Calm", score: 78, icon: "leaf.fill", trend: "down")
        }
        .padding(.horizontal, 32)
    }
}
