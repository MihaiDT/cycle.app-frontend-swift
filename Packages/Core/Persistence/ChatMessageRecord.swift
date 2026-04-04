import Foundation
import SwiftData

// MARK: - Chat Message Record (SwiftData)

/// Persisted chat message for Aria conversations.
/// Stored locally in SwiftData, synced via CloudKit E2E encryption.
@Model
public final class ChatMessageRecord {
    public var messageId: String = ""
    public var sessionId: String = ""
    public var role: String = "user"
    public var content: String = ""
    public var timestamp: Date = Date.now

    public init(
        messageId: String,
        sessionId: String,
        role: String,
        content: String,
        timestamp: Date = .now
    ) {
        self.messageId = messageId
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
