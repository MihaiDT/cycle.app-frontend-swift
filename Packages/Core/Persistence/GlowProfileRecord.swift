import Foundation
import SwiftData

// MARK: - Glow Profile Record

@Model
final class GlowProfileRecord {
    var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var totalXP: Int = 0
    @Attribute(.allowsCloudEncryption) var currentLevel: Int = 1
    @Attribute(.allowsCloudEncryption) var totalCompleted: Int = 0
    @Attribute(.allowsCloudEncryption) var currentConsistencyDays: Int = 0
    @Attribute(.allowsCloudEncryption) var longestConsistencyDays: Int = 0
    @Attribute(.allowsCloudEncryption) var lastCompletedDate: Date?
    @Attribute(.allowsCloudEncryption) var goldCount: Int = 0
    @Attribute(.allowsCloudEncryption) var silverCount: Int = 0
    @Attribute(.allowsCloudEncryption) var bronzeCount: Int = 0

    init() {}
}
