import Foundation

// MARK: - Glow Profile Snapshot

struct GlowProfileSnapshot: Equatable, Sendable {
    let id: UUID
    var totalXP: Int
    var currentLevel: Int
    var totalCompleted: Int
    var currentConsistencyDays: Int
    var longestConsistencyDays: Int
    var lastCompletedDate: Date?
    var goldCount: Int
    var silverCount: Int
    var bronzeCount: Int

    var levelTitle: String {
        GlowConstants.levelFor(xp: totalXP).title
    }

    var levelEmoji: String {
        GlowConstants.levelFor(xp: totalXP).emoji
    }

    var isMaxLevel: Bool {
        currentLevel >= GlowConstants.levels.last!.level
    }

    static let empty = GlowProfileSnapshot(
        id: UUID(),
        totalXP: 0,
        currentLevel: 1,
        totalCompleted: 0,
        currentConsistencyDays: 0,
        longestConsistencyDays: 0,
        lastCompletedDate: nil,
        goldCount: 0,
        silverCount: 0,
        bronzeCount: 0
    )
}

// MARK: - Record → Snapshot

extension GlowProfileSnapshot {
    init(record: GlowProfileRecord) {
        self.init(
            id: record.id,
            totalXP: record.totalXP,
            currentLevel: record.currentLevel,
            totalCompleted: record.totalCompleted,
            currentConsistencyDays: record.currentConsistencyDays,
            longestConsistencyDays: record.longestConsistencyDays,
            lastCompletedDate: record.lastCompletedDate,
            goldCount: record.goldCount,
            silverCount: record.silverCount,
            bronzeCount: record.bronzeCount
        )
    }
}
