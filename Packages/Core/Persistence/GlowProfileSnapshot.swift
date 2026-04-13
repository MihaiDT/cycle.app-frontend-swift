import Foundation

// MARK: - Glow Profile Snapshot

public struct GlowProfileSnapshot: Equatable, Sendable {
    public let id: UUID
    public var totalXP: Int
    public var currentLevel: Int
    public var totalCompleted: Int
    public var currentConsistencyDays: Int
    public var longestConsistencyDays: Int
    public var lastCompletedDate: Date?
    public var goldCount: Int
    public var silverCount: Int
    public var bronzeCount: Int

    public var levelTitle: String {
        GlowConstants.levelFor(xp: totalXP).title
    }

    public var levelEmoji: String {
        GlowConstants.levelFor(xp: totalXP).emoji
    }

    public var isMaxLevel: Bool {
        currentLevel >= GlowConstants.levels.last!.level
    }

    public init(
        id: UUID, totalXP: Int, currentLevel: Int, totalCompleted: Int,
        currentConsistencyDays: Int, longestConsistencyDays: Int,
        lastCompletedDate: Date?, goldCount: Int, silverCount: Int, bronzeCount: Int
    ) {
        self.id = id; self.totalXP = totalXP; self.currentLevel = currentLevel
        self.totalCompleted = totalCompleted; self.currentConsistencyDays = currentConsistencyDays
        self.longestConsistencyDays = longestConsistencyDays
        self.lastCompletedDate = lastCompletedDate
        self.goldCount = goldCount; self.silverCount = silverCount; self.bronzeCount = bronzeCount
    }

    public static let empty = GlowProfileSnapshot(
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
