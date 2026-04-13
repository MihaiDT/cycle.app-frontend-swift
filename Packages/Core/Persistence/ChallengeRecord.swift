import Foundation
import SwiftData

// MARK: - Challenge Record

@Model
final class ChallengeRecord {
    var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var date: Date = Date.now
    @Attribute(.allowsCloudEncryption) var templateId: String = ""
    @Attribute(.allowsCloudEncryption) var challengeCategory: String = ""
    @Attribute(.allowsCloudEncryption) var challengeTitle: String = ""
    @Attribute(.allowsCloudEncryption) var challengeDescription: String = ""
    @Attribute(.allowsCloudEncryption) var tips: String = "[]"
    @Attribute(.allowsCloudEncryption) var goldHint: String = ""
    @Attribute(.allowsCloudEncryption) var validationPrompt: String = ""
    @Attribute(.allowsCloudEncryption) var cyclePhase: String = ""
    @Attribute(.allowsCloudEncryption) var cycleDay: Int = 0
    @Attribute(.allowsCloudEncryption) var energyLevel: Int = 3
    /// "available" | "completed" | "skipped"
    @Attribute(.allowsCloudEncryption) var status: String = "available"
    @Attribute(.allowsCloudEncryption) var completedAt: Date?
    @Attribute(.allowsCloudEncryption) var photoData: Data?
    @Attribute(.allowsCloudEncryption) var photoThumbnail: Data?
    /// "bronze" | "silver" | "gold"
    @Attribute(.allowsCloudEncryption) var validationRating: String?
    @Attribute(.allowsCloudEncryption) var validationFeedback: String?
    @Attribute(.allowsCloudEncryption) var xpEarned: Int = 0

    init(
        templateId: String,
        challengeCategory: String,
        challengeTitle: String,
        challengeDescription: String,
        tips: String = "[]",
        goldHint: String = "",
        validationPrompt: String = "",
        cyclePhase: String,
        cycleDay: Int,
        energyLevel: Int = 3
    ) {
        self.templateId = templateId
        self.challengeCategory = challengeCategory
        self.challengeTitle = challengeTitle
        self.challengeDescription = challengeDescription
        self.tips = tips
        self.goldHint = goldHint
        self.validationPrompt = validationPrompt
        self.cyclePhase = cyclePhase
        self.cycleDay = cycleDay
        self.energyLevel = energyLevel
    }
}
