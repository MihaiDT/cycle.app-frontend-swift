import ComposableArchitecture
import Foundation
import Inject
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
                )

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
                return .none

            case .webSocketDisconnected:
                state.isConnected = false
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
}

// MARK: - WebSocket Manager (Sendable singleton)

final class WebSocketManager: @unchecked Sendable {
    static let shared = WebSocketManager()
    var task: URLSessionWebSocketTask?
    var sessionID: String = ""
    private init() {}
}

// MARK: - Chat View

public struct ChatView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<ChatFeature>
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?

    public init(store: StoreOf<ChatFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Content
            if store.messages.isEmpty {
                welcomeScreen
            } else {
                messageList
            }

            // Input bar
            inputBar
        }
        .background(DesignColors.background)
        .onTapGesture { isInputFocused = false }
        .task { store.send(.onAppear) }
        .enableInjection()
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Text("Aria")
                    .font(.custom("Raleway-SemiBold", size: 17))
                    .foregroundColor(DesignColors.text)
                Circle()
                    .fill(store.isConnected ? Color.green : Color.gray)
                    .frame(width: 7, height: 7)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Welcome Screen (Empty State)

    private var welcomeScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                // Avatar / gradient orb
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    DesignColors.accent.opacity(0.8),
                                    DesignColors.accentWarm.opacity(0.6),
                                    DesignColors.accentSecondary.opacity(0.3),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Text("A")
                        .font(.custom("Raleway-Bold", size: 28))
                        .foregroundColor(.white)
                }

                // Title
                VStack(spacing: 6) {
                    Text("Hey, I'm Aria")
                        .font(.custom("Raleway-Bold", size: 26))
                        .foregroundColor(DesignColors.text)

                    Text("What's on your mind?")
                        .font(.custom("Raleway-Regular", size: 16))
                        .foregroundColor(DesignColors.textSecondary)
                }

                // Starter chips
                VStack(spacing: 10) {
                    starterChip("How am I feeling today?")
                    starterChip("Tell me about my cycle")
                    starterChip("I need to talk")
                    starterChip("Just vibing")
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func starterChip(_ text: String) -> some View {
        Button {
            store.send(.sendMessage(text))
        } label: {
            Text(text)
                .font(.custom("Raleway-Medium", size: 15))
                .foregroundColor(DesignColors.text)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(DesignColors.divider.opacity(0.5), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.messages) { message in
                        VStack(spacing: 2) {
                            messageBubble(message)
                            messageTimestamp(message)
                        }
                        .id(message.id)
                    }

                    if store.isStreaming, store.messages.last?.role != .assistant {
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(store.messages.last?.id ?? "typing", anchor: .bottom)
                }
            }
            .onChange(of: store.messages.last?.content) { _, _ in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(store.messages.last?.id ?? "typing", anchor: .bottom)
                }
            }
            .onAppear { scrollProxy = proxy }
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ message: ChatFeature.ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Text(message.content)
                .font(.custom("Raleway-Regular", size: 15))
                .foregroundColor(message.role == .user ? .white : DesignColors.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if message.role == .user {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(
                                        Color.white.opacity(0.2),
                                        lineWidth: 0.5
                                    )
                            }
                    }
                }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    // MARK: - Message Timestamp

    @ViewBuilder
    private func messageTimestamp(_ message: ChatFeature.ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer() }
            Text(relativeTime(message.timestamp))
                .font(.custom("Raleway-Regular", size: 11))
                .foregroundColor(DesignColors.textPlaceholder)
                .padding(.horizontal, 6)
            if message.role == .assistant { Spacer() }
        }
        .padding(.bottom, 4)
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date.now.timeIntervalSince(date))
        if seconds < 10 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message Aria...", text: $store.inputText, axis: .vertical)
                .font(.custom("Raleway-Regular", size: 15))
                .foregroundColor(DesignColors.text)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(DesignColors.divider.opacity(0.4), lineWidth: 0.5)
                        }
                }
                .onSubmit { store.send(.sendTapped) }

            Button(action: { store.send(.sendTapped) }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(sendButtonColor)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var canSend: Bool {
        !store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.isConnected
    }

    private var sendButtonColor: Color {
        canSend ? DesignColors.accentWarm : DesignColors.textPlaceholder
    }
}

// MARK: - Typing Indicator (Proper Bouncing Animation)

private struct TypingIndicatorView: View {
    @State private var phase: Int = 0
    @State private var bounceTimer: Timer?

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(DesignColors.textSecondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .offset(y: phase == index ? -5 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    }
            }
            Spacer()
        }
        .onAppear {
            bounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = (phase + 1) % 4
                }
            }
        }
        .onDisappear {
            bounceTimer?.invalidate()
            bounceTimer = nil
        }
    }
}
