import SwiftUI

// MARK: - XP Progress Bar

struct XPProgressBar: View {
    let currentXP: Int
    let animated: Bool

    @State private var displayProgress: Double = 0

    private var progress: Double {
        GlowConstants.xpProgress(currentXP: currentXP)
    }

    private var isMaxLevel: Bool {
        GlowConstants.xpForNextLevel(currentXP: currentXP) == nil
    }

    private var levelInfo: (level: Int, title: String, emoji: String) {
        GlowConstants.levelFor(xp: currentXP)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(levelInfo.emoji) \(levelInfo.title)")
                    .font(.custom("Raleway-SemiBold", size: 14))
                    .foregroundStyle(DesignColors.text)

                Spacer()

                if isMaxLevel {
                    Text("MAX LEVEL")
                        .font(.custom("Raleway-Bold", size: 12))
                        .foregroundStyle(DesignColors.accentWarm)
                } else if let remaining = GlowConstants.xpForNextLevel(currentXP: currentXP) {
                    Text("\(remaining) XP to next level")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignColors.structure.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * displayProgress)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            if animated {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    displayProgress = progress
                }
            } else {
                displayProgress = progress
            }
        }
    }
}
