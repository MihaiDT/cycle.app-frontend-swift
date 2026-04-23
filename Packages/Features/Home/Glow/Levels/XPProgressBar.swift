import SwiftUI

// MARK: - XP Progress Bar

struct XPProgressBar: View {
    let currentXP: Int
    let animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    private var accessibilityValueDescription: String {
        if isMaxLevel {
            return "Level \(levelInfo.level), \(levelInfo.title), max level reached, \(currentXP) XP total"
        }
        if let remaining = GlowConstants.xpForNextLevel(currentXP: currentXP) {
            return "Level \(levelInfo.level), \(levelInfo.title), \(currentXP) XP total, \(remaining) XP to next level"
        }
        return "Level \(levelInfo.level), \(levelInfo.title), \(currentXP) XP total"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(levelInfo.emoji) \(levelInfo.title)")
                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)

                Spacer()

                if isMaxLevel {
                    Text("MAX LEVEL")
                        .font(.raleway("Bold", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.accentWarm)
                } else if let remaining = GlowConstants.xpForNextLevel(currentXP: currentXP) {
                    Text("\(remaining) XP to next level")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Experience progress")
        .accessibilityValue(accessibilityValueDescription)
        .onAppear {
            if animated, !reduceMotion {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    displayProgress = progress
                }
            } else {
                displayProgress = progress
            }
        }
    }
}
