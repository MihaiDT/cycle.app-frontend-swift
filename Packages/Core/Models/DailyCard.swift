import Foundation
import Tagged

// MARK: - Insight Card

public struct DailyCard: Codable, Equatable, Sendable, Identifiable {
    public typealias ID = Tagged<DailyCard, String>

    public let id: ID
    public let cardType: CardType
    public let title: String
    public let body: String
    public let cyclePhase: CyclePhase
    public let cycleDay: Int?
    public let action: CardAction?

    public init(
        id: ID,
        cardType: CardType,
        title: String,
        body: String,
        cyclePhase: CyclePhase,
        cycleDay: Int? = nil,
        action: CardAction? = nil
    ) {
        self.id = id
        self.cardType = cardType
        self.title = title
        self.body = body
        self.cyclePhase = cyclePhase
        self.cycleDay = cycleDay
        self.action = action
    }
}

// MARK: - Card Type

public enum CardType: String, Codable, Equatable, Sendable {
    case feel
    case `do`
    case goDeeper = "go_deeper"
}

// MARK: - Card Action

public struct CardAction: Codable, Equatable, Sendable {
    public let actionType: CardActionType
    public let label: String

    public init(actionType: CardActionType, label: String) {
        self.actionType = actionType
        self.label = label
    }
}

public enum CardActionType: String, Codable, Equatable, Sendable {
    case breathing
    case journal
    case quickCheck = "quick_check"
    case challenge
    case openLens = "open_lens"
}
