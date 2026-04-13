import Foundation

// MARK: - Challenge Snapshot

public struct ChallengeSnapshot: Equatable, Sendable {
    let id: UUID
    let date: Date
    let templateId: String
    let challengeCategory: String
    let challengeTitle: String
    let challengeDescription: String
    let tips: [String]
    let goldHint: String
    let validationPrompt: String
    let cyclePhase: String
    let cycleDay: Int
    let energyLevel: Int
    var status: ChallengeStatus
    var completedAt: Date?
    var photoThumbnail: Data?
    var validationRating: String?
    var validationFeedback: String?
    var xpEarned: Int

    enum ChallengeStatus: String, Equatable, Sendable {
        case available
        case completed
        case skipped
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
