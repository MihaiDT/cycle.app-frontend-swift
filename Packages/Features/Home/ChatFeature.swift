import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - Chat Feature

@Reducer
public struct ChatFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var messages: [ChatMessage] = []
        public var inputText: String = ""
        public var isConnected: Bool = false
        public var isTyping: Bool = false
        public var sessionID: String = UUID().uuidString.lowercased()

        public init() {}
    }

    public struct ChatMessage: Equatable, Identifiable, Sendable {
        public let id: String
        public let role: Role
        public var content: String
        public let createdAt: Date

        public enum Role: String, Sendable {
            case user
            case assistant
        }

        public init(role: Role, content: String) {
            self.id = UUID().uuidString
            self.role = role
            self.content = content
            self.createdAt = .now
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case onDisappear
        case sendTapped
        case webSocketConnected
        case webSocketDisconnected
        case messageReceived(String)
        case streamChunkReceived(String, String) // sessionID, chunk
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case noop
        }
    }

    @Dependency(\.anonymousID) var anonymousID
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                let anonID = anonymousID.getID()
                let sessionID = state.sessionID
                return .run { send in
                    await send(.webSocketConnected)
                    let url = URL(string: "ws://34.72.143.234:8081/ws?anonymous_id=\(anonID)")!
                    let session = URLSession(configuration: .default)

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
                            try? await Task.sleep(for: .seconds(2))
                            guard !Task.isCancelled else { break }
                            // Create a fresh connection
                            wsTask = connect()
                            await send(.webSocketConnected)
                        }
                    }
                }

            case .onDisappear:
                WebSocketManager.shared.task?.cancel(with: .normalClosure, reason: nil)
                WebSocketManager.shared.task = nil
                return .none

            case .sendTapped:
                let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return .none }

                state.inputText = ""
                state.messages.append(ChatMessage(role: .user, content: text))
                state.isTyping = true

                let sessionID = state.sessionID
                return .run { _ in
                    let payload: [String: Any] = [
                        "type": "message",
                        "content": text,
                        "session_id": sessionID,
                    ]
                    if let data = try? JSONSerialization.data(withJSONObject: payload),
                       let jsonString = String(data: data, encoding: .utf8)
                    {
                        try? await WebSocketManager.shared.task?.send(.string(jsonString))
                    }
                }

            case .webSocketConnected:
                state.isConnected = true
                return .none

            case .webSocketDisconnected:
                state.isConnected = false
                return .none

            case .messageReceived(let text):
                guard let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String
                else { return .none }

                switch type {
                case "response":
                    state.isTyping = false
                    if let content = json["content"] as? String, !content.isEmpty {
                        // If we were streaming, the last stream message already has the content
                        // Only add if not already streaming
                        if let last = state.messages.last, last.role == .assistant {
                            // Already have a streaming message — update it
                            state.messages[state.messages.count - 1].content = content
                        } else {
                            state.messages.append(ChatMessage(role: .assistant, content: content))
                        }
                    }

                case "stream_chunk", "stream":
                    state.isTyping = false
                    if let content = json["content"] as? String, !content.isEmpty {
                        if let last = state.messages.last, last.role == .assistant {
                            state.messages[state.messages.count - 1].content += content
                        } else {
                            state.messages.append(ChatMessage(role: .assistant, content: content))
                        }
                    }

                case "error":
                    state.isTyping = false
                    let errorMsg = (json["error"] as? String) ?? "Something went wrong"
                    state.messages.append(ChatMessage(role: .assistant, content: errorMsg))

                default:
                    break
                }
                return .none

            case .streamChunkReceived:
                return .none

            case .binding, .delegate:
                return .none
            }
        }
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

    public init(store: StoreOf<ChatFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if store.isTyping, store.messages.last?.role != .assistant {
                            typingIndicator
                                .id("typing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: store.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(store.messages.last?.id ?? "typing", anchor: .bottom)
                    }
                }
            }

            // Input bar
            inputBar
        }
        .background(DesignColors.background)
        .task { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        .enableInjection()
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

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(DesignColors.textSecondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .offset(y: typingOffset(for: i))
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: store.isTyping
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
            }
            Spacer()
        }
    }

    private func typingOffset(for index: Int) -> CGFloat {
        store.isTyping ? -3 : 0
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
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                        }
                }
                .onSubmit { store.send(.sendTapped) }

            Button(action: { store.send(.sendTapped) }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? DesignColors.textPlaceholder
                            : DesignColors.accentWarm
                    )
            }
            .disabled(store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
