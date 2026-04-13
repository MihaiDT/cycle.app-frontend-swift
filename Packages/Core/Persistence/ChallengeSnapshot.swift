import Foundation

// MARK: - Challenge Snapshot

public struct ChallengeSnapshot: Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let templateId: String
    public let challengeCategory: String
    public let challengeTitle: String
    public let challengeDescription: String
    public let tips: [String]
    public let goldHint: String
    public let validationPrompt: String
    public let cyclePhase: String
    public let cycleDay: Int
    public let energyLevel: Int
    public var status: ChallengeStatus
    public var completedAt: Date?
    public var photoThumbnail: Data?
    public var validationRating: String?
    public var validationFeedback: String?
    public var xpEarned: Int

    public enum ChallengeStatus: String, Equatable, Sendable {
        case available
        case completed
        case skipped
    }

    public init(
        id: UUID, date: Date, templateId: String, challengeCategory: String,
        challengeTitle: String, challengeDescription: String, tips: [String],
        goldHint: String, validationPrompt: String, cyclePhase: String,
        cycleDay: Int, energyLevel: Int, status: ChallengeStatus,
        completedAt: Date?, photoThumbnail: Data?, validationRating: String?,
        validationFeedback: String?, xpEarned: Int
    ) {
        self.id = id; self.date = date; self.templateId = templateId
        self.challengeCategory = challengeCategory; self.challengeTitle = challengeTitle
        self.challengeDescription = challengeDescription; self.tips = tips
        self.goldHint = goldHint; self.validationPrompt = validationPrompt
        self.cyclePhase = cyclePhase; self.cycleDay = cycleDay
        self.energyLevel = energyLevel; self.status = status
        self.completedAt = completedAt; self.photoThumbnail = photoThumbnail
        self.validationRating = validationRating; self.validationFeedback = validationFeedback
        self.xpEarned = xpEarned
    }
}

// MARK: - Record → Snapshot

extension ChallengeSnapshot {
    init(record: ChallengeRecord) {
        let parsedTips = (try? JSONDecoder().decode([String].self, from: Data(record.tips.utf8))) ?? []
        self.init(
            id: record.id,
            date: record.date,
            templateId: record.templateId,
            challengeCategory: record.challengeCategory,
            challengeTitle: record.challengeTitle,
            challengeDescription: record.challengeDescription,
            tips: parsedTips,
            goldHint: record.goldHint,
            validationPrompt: record.validationPrompt,
            cyclePhase: record.cyclePhase,
            cycleDay: record.cycleDay,
            energyLevel: record.energyLevel,
            status: ChallengeStatus(rawValue: record.status) ?? .available,
            completedAt: record.completedAt,
            photoThumbnail: record.photoThumbnail,
            validationRating: record.validationRating,
            validationFeedback: record.validationFeedback,
            xpEarned: record.xpEarned
        )
    }
}
