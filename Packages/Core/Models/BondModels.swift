import Foundation

public struct BondSummary: Codable, Sendable, Equatable {
    public let cyclePhase: String
    public let energyLevel: Int
    public let moodLevel: Int
    public let dominantElement: String
    public let tensionScore: Double
    public let timestamp: Date

    public init(cyclePhase: String, energyLevel: Int, moodLevel: Int,
                dominantElement: String, tensionScore: Double, timestamp: Date = Date()) {
        self.cyclePhase = cyclePhase
        self.energyLevel = energyLevel
        self.moodLevel = moodLevel
        self.dominantElement = dominantElement
        self.tensionScore = tensionScore
        self.timestamp = timestamp
    }
}

public struct BondState: Codable, Sendable, Equatable {
    public let alignment: Double
    public let dominantTheme: String
    public let suggestion: String
    public let timestamp: Date

    public init(alignment: Double, dominantTheme: String, suggestion: String, timestamp: Date = Date()) {
        self.alignment = alignment
        self.dominantTheme = dominantTheme
        self.suggestion = suggestion
        self.timestamp = timestamp
    }
}

public struct BondInfo: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let partnerID: String
    public let partnerName: String?
    public let status: BondStatus
    public let createdAt: Date

    public init(id: String, partnerID: String, partnerName: String? = nil,
                status: BondStatus, createdAt: Date) {
        self.id = id
        self.partnerID = partnerID
        self.partnerName = partnerName
        self.status = status
        self.createdAt = createdAt
    }
}

public enum BondStatus: String, Codable, Sendable, Equatable {
    case pending
    case active
    case revoked
}
