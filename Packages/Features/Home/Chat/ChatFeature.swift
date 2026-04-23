import ComposableArchitecture
import Foundation
import SwiftData
import SwiftUI

// MARK: - Chat Feature

@Reducer
public struct ChatFeature: Sendable {

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
        public var messages: [ChatMessage] = []
        public var inputText: String = ""
        public var isConnected: Bool = false
        public var isStreaming: Bool = false
        public var sessionID: String
        public var hasLoadedHistory: Bool = false
        /// True once the WebSocket has failed at least once without ever
        /// successfully connecting in this session. Used to surface an inline
        /// "Can't reach Aria" banner with a retry. Cleared on successful connect.
        public var hasConnectionError: Bool = false

        public init() {
            if let stored = UserDefaults.standard.string(forKey: "cycle.chat.sessionID"), !stored.isEmpty {
                self.sessionID = stored
            } else {
                let newID = UUID().uuidString.lowercased()
                UserDefaults.standard.set(newID, forKey: "cycle.chat.sessionID")
                self.sessionID = newID
            }
        }
    }

    // MARK: - Chat Message

    public struct ChatMessage: Equatable, Identifiable, Sendable, Codable {
        public let id: String
        public let role: Role
        public var content: String
        public let timestamp: Date

        public enum Role: String, Sendable, Codable {
            case user, assistant, system
        }

        public init(id: String = UUID().uuidString, role: Role, content: String, timestamp: Date = .now) {
            self.id = id
            self.role = role
            self.content = content
            self.timestamp = timestamp
        }
    }

    // MARK: - Actions

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case sendTapped
        case sendMessage(String)
        case newSession
        case webSocketConnected
        case webSocketDisconnected
        case messageReceived(String)
        case historyLoaded([ChatMessage])
        case retryConnectionTapped
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case noop
        }
    }

    // MARK: - Dependencies

    @Dependency(\.anonymousID) var anonymousID
    @Dependency(\.continuousClock) var clock

    public init() {}

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {

            // MARK: onAppear

            case .onAppear:
                guard !state.hasLoadedHistory else { return .none }
                state.hasLoadedHistory = true

                let sessionID = state.sessionID
                let anonID = anonymousID.getID()

                return .merge(
                    // Load history from SwiftData
                    .run { send in
                        let container = CycleDataStore.shared
                        let context = ModelContext(container)
                        var descriptor = FetchDescriptor<ChatMessageRecord>(
                            predicate: #Predicate { $0.sessionId == sessionID },
                            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                        )
                        descriptor.fetchLimit = 200
                        let records = (try? context.fetch(descriptor)) ?? []
                        let messages = records.map { record in
                            ChatMessage(
                                id: record.messageId,
                                role: ChatMessage.Role(rawValue: record.role) ?? .assistant,
                                content: record.content,
                                timestamp: record.timestamp
                            )
                        }
                        await send(.historyLoaded(messages))
                    },
                    // Connect WebSocket (slight delay to let UI render first)
                    Self.webSocketConnectEffect(sessionID: sessionID, anonID: anonID)
                )

            case .retryConnectionTapped:
                state.hasConnectionError = false
                let sessionID = state.sessionID
                let anonID = anonymousID.getID()
                return Self.webSocketConnectEffect(sessionID: sessionID, anonID: anonID)

            // MARK: historyLoaded

            case .historyLoaded(let messages):
                state.messages = messages
                return .none

            // MARK: sendTapped

            case .sendTapped:
                let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, state.isConnected else { return .none }
                state.inputText = ""
                return .send(.sendMessage(text))

            // MARK: sendMessage (from input or starter chips)

            case .sendMessage(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }

                let userMsg = ChatMessage(role: .user, content: trimmed)
                state.messages.append(userMsg)
                state.isStreaming = true

                let sessionID = state.sessionID

                return .run { _ in
                    // Persist user message
                    let container = CycleDataStore.shared
                    let context = ModelContext(container)
                    let record = ChatMessageRecord(
                        messageId: userMsg.id,
                        sessionId: sessionID,
                        role: "user",
                        content: trimmed,
                        timestamp: userMsg.timestamp
                    )
                    context.insert(record)
                    try? context.save()

                    // Build ephemeral context
                    let ariaContext = AriaContextProvider.currentContext(container: container)
                    let payload: [String: Any] = [
                        "type": "message",
                        "content": trimmed,
                        "session_id": sessionID,
                        "ephemeral_context": [
                            "cycle_phase": ariaContext.cyclePhase as Any,
                            "cycle_day": ariaContext.cycleDay as Any,
                            "hbi_score": ariaContext.hbiScore as Any,
                            "mood": ariaContext.mood as Any,
                            "energy": ariaContext.energy as Any,
                            "recent_symptoms": ariaContext.recentSymptoms,
                        ] as [String: Any],
                    ]

                    if let data = try? JSONSerialization.data(withJSONObject: payload),
                       let jsonString = String(data: data, encoding: .utf8)
                    {
                        try? await WebSocketManager.shared.task?.send(.string(jsonString))
                    }
                }

            // MARK: newSession

            case .newSession:
                let newID = UUID().uuidString.lowercased()
                UserDefaults.standard.set(newID, forKey: "cycle.chat.sessionID")
                state.sessionID = newID
                state.messages = []
                state.isStreaming = false
                state.hasLoadedHistory = true
                return .none

            // MARK: WebSocket lifecycle

            case .webSocketConnected:
                state.isConnected = true
                state.hasConnectionError = false
                return .none

            case .webSocketDisconnected:
                state.isConnected = false
                // Only flag as error state if we've never connected OR the
                // retry loop has been trying for a while. For now, any drop
                // surfaces the banner — re-connects clear it automatically.
                state.hasConnectionError = true
                return .none

            // MARK: messageReceived

            case .messageReceived(let text):
                guard let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String
                else { return .none }

                let sessionID = state.sessionID

                switch type {
                case "stream_chunk", "stream":
                    if let content = json["content"] as? String, !content.isEmpty {
                        if let lastIndex = state.messages.indices.last,
                           state.messages[lastIndex].role == .assistant
                        {
                            state.messages[lastIndex].content += content
                        } else {
                            let msg = ChatMessage(role: .assistant, content: content)
                            state.messages.append(msg)
                        }
                        state.isStreaming = true
                    }

                case "response":
                    state.isStreaming = false
                    // Response with content = full non-streamed response
                    // Response with empty content = streaming finished, save what we have
                    let responseContent = json["content"] as? String ?? ""

                    if !responseContent.isEmpty {
                        // Non-streamed: set content directly
                        if let lastIndex = state.messages.indices.last,
                           state.messages[lastIndex].role == .assistant
                        {
                            state.messages[lastIndex].content = responseContent
                        } else {
                            state.messages.append(ChatMessage(role: .assistant, content: responseContent))
                        }
                    }

                    // Persist the final assistant message (streamed or not)
                    if let lastIndex = state.messages.indices.last,
                       state.messages[lastIndex].role == .assistant,
                       !state.messages[lastIndex].content.isEmpty
                    {
                        let finalMsg = state.messages[lastIndex]
                        return .run { _ in
                            let container = CycleDataStore.shared
                            let ctx = ModelContext(container)
                            let record = ChatMessageRecord(
                                messageId: finalMsg.id,
                                sessionId: sessionID,
                                role: "assistant",
                                content: finalMsg.content,
                                timestamp: finalMsg.timestamp
                            )
                            ctx.insert(record)
                            try? ctx.save()
                        }
                    }

                case "stream_end":
                    state.isStreaming = false
                    // Persist the final streamed assistant message
                    if let lastIndex = state.messages.indices.last,
                       state.messages[lastIndex].role == .assistant
                    {
                        let finalMsg = state.messages[lastIndex]
                        return .run { _ in
                            let container = CycleDataStore.shared
                            let ctx = ModelContext(container)
                            let record = ChatMessageRecord(
                                messageId: finalMsg.id,
                                sessionId: sessionID,
                                role: "assistant",
                                content: finalMsg.content,
                                timestamp: finalMsg.timestamp
                            )
                            ctx.insert(record)
                            try? ctx.save()
                        }
                    }

                case "error":
                    state.isStreaming = false
                    let errorContent = (json["error"] as? String) ?? "Something went wrong"
                    let errorMsg = ChatMessage(role: .assistant, content: errorContent)
                    state.messages.append(errorMsg)

                default:
                    break
                }
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }

    // MARK: - Constants

    private static let wsURL = "ws://34.72.143.234:8081/ws"

    private enum CancelID {
        case webSocket
    }

    // MARK: - WebSocket connect helper

    /// Shared WebSocket connection effect used by both `onAppear` and
    /// `retryConnectionTapped`. Wrapped in `.cancellable(cancelInFlight:)` so
    /// a retry tears down any prior listener cleanly.
    private static func webSocketConnectEffect(sessionID: String, anonID: String) -> Effect<Action> {
        .run { send in
            try? await Task.sleep(for: .milliseconds(300))
            let url = URL(string: "\(ChatFeature.wsURL)?anonymous_id=\(anonID)")!
            let session = URLSession(configuration: .default)
            var backoffSeconds: UInt64 = 2

            func connect() -> URLSessionWebSocketTask {
                let task = session.webSocketTask(with: url)
                task.resume()
                WebSocketManager.shared.task = task
                return task
            }

            var wsTask = connect()
            WebSocketManager.shared.sessionID = sessionID
            await send(.webSocketConnected)

            while !Task.isCancelled {
                do {
                    let message = try await wsTask.receive()
                    backoffSeconds = 2  // Reset on success
                    switch message {
                    case .string(let text):
                        await send(.messageReceived(text))
                    case .data:
                        break
                    @unknown default:
                        break
                    }
                } catch {
                    guard !Task.isCancelled else { break }
                    await send(.webSocketDisconnected)
                    // Exponential backoff: 2s, 4s, 8s, 16s, max 30s
                    try? await Task.sleep(for: .seconds(backoffSeconds))
                    backoffSeconds = min(backoffSeconds * 2, 30)
                    guard !Task.isCancelled else { break }
                    wsTask = connect()
                    await send(.webSocketConnected)
                }
            }
        }.cancellable(id: CancelID.webSocket, cancelInFlight: true)
    }
}

// MARK: - WebSocket Manager (Sendable singleton)

final class WebSocketManager: @unchecked Sendable {
    static let shared = WebSocketManager()
    var task: URLSessionWebSocketTask?
    var sessionID: String = ""
    private init() {}
}
