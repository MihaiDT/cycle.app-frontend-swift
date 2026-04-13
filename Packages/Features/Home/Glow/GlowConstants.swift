import Foundation

// MARK: - Glow Constants

enum GlowConstants {
    static let baseXP = 50
    static let consistencyBonus3Days = 30
    static let consistencyBonus7Days = 100

    static let levels: [(level: Int, title: String, xp: Int, emoji: String)] = [
        (1, "Seed", 0, "🌱"),
        (2, "Sprout", 200, "🌿"),
        (3, "Bloom", 500, "🌸"),
        (4, "Flourish", 1_000, "🌺"),
        (5, "Radiant", 2_000, "✨"),
        (6, "Luminous", 3_500, "💫"),
        (7, "Decoded", 5_500, "🔮"),
    ]

    static let unlockDescriptions: [Int: String] = [
        2: "You're growing! Keep going.",
        3: "Shareable cards unlocked!",
        4: "Choose from multiple challenges!",
        5: "You're radiant. Keep shining.",
        6: "Aria now remembers your photos.",
        7: "Full cycle photo timeline unlocked.",
    ]

    static func levelFor(xp: Int) -> (level: Int, title: String, emoji: String) {
        let match = levels.last(where: { $0.xp <= xp }) ?? levels[0]
        return (match.level, match.title, match.emoji)
    }

    static func xpForNextLevel(currentXP: Int) -> Int? {
        let currentLevel = levelFor(xp: currentXP).level
        guard let next = levels.first(where: { $0.level == currentLevel + 1 }) else { return nil }
        return next.xp - currentXP
    }

    /// Returns 0.0–1.0 progress within current level. 1.0 at max level.
    static func xpProgress(currentXP: Int) -> Double {
        let current = levelFor(xp: currentXP)
        guard let nextLevel = levels.first(where: { $0.level == current.level + 1 }) else { return 1.0 }
        let prevXP = levels.first(where: { $0.level == current.level })?.xp ?? 0
        let range = nextLevel.xp - prevXP
        guard range > 0 else { return 1.0 }
        return Double(currentXP - prevXP) / Double(range)
    }

    /// Calculates final XP including consistency bonus.
    static func calculateXP(
        multiplier: Double,
        consecutiveDays: Int
    ) -> (baseXP: Int, bonus: Int, total: Int) {
        let base = Int(Double(baseXP) * multiplier)
        let bonus: Int
        if consecutiveDays >= 7 {
            bonus = consistencyBonus7Days
        } else if consecutiveDays >= 3 {
            bonus = consistencyBonus3Days
        } else {
            bonus = 0
        }
        return (base, bonus, base + bonus)
    }
}
