import ComposableArchitecture
import Foundation
import SwiftData
import SwiftUI


// MARK: - Chat View

public struct ChatView: View {
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

            // Connection error banner — shown when the WebSocket has failed
            // and we haven't auto-reconnected yet. Uses a warm (not red) tone
            // to match the premium aesthetic.
            if store.hasConnectionError && !store.isConnected {
                connectionErrorBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

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
        .animation(.easeInOut(duration: 0.25), value: store.hasConnectionError)
        .animation(.easeInOut(duration: 0.25), value: store.isConnected)
    }

    // MARK: - Connection Error Banner

    private var connectionErrorBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignColors.accentWarm)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Can't reach Aria")
                    .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
                Text("Check your connection and try again.")
                    .font(.raleway("Regular", size: 11, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
            }

            Spacer(minLength: 8)

            Button {
                store.send(.retryConnectionTapped)
            } label: {
                Text("Try again")
                    .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        Capsule()
                            .fill(DesignColors.accentWarm)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Retries the connection to Aria")
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(DesignColors.accentWarm.opacity(0.25), lineWidth: 0.5)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Can't reach Aria. Check your connection and try again.")
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Text("Aria")
                    .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                    .foregroundColor(DesignColors.text)
                // Streaming signal (while Aria types) takes priority over the plain connection dot.
                if store.isStreaming {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.mini)
                        .tint(DesignColors.accentWarm)
                        .transition(.opacity)
                } else {
                    Circle()
                        .fill(store.isConnected ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                        .transition(.opacity)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                store.isStreaming
                    ? "Aria is typing"
                    : store.isConnected ? "Aria connected" : "Aria disconnected"
            )
            Spacer()
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 0.2), value: store.isStreaming)
        .animation(.easeInOut(duration: 0.2), value: store.isConnected)
    }

    // MARK: - Welcome Screen (Empty State)

    private var welcomeScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                // Simple avatar stack — NyraOrb was causing the chat
                // view to freeze on tab entry (likely Task/animation
                // interaction with WebSocket connect). Reverted to the
                // lightweight circle-gradient avatar for now.
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
                        .font(.raleway("Bold", size: 28, relativeTo: .title))
                        .foregroundColor(.white)
                }

                // Title
                VStack(spacing: 6) {
                    Text("Hey, I'm Aria")
                        .font(.raleway("Bold", size: 26, relativeTo: .title))
                        .foregroundColor(DesignColors.text)

                    Text("What's on your mind?")
                        .font(.raleway("Regular", size: 16, relativeTo: .body))
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
                .font(.raleway("Medium", size: 15, relativeTo: .body))
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
                .font(.raleway("Regular", size: 15, relativeTo: .body))
                .foregroundColor(message.role == .user ? .white : DesignColors.text)
                .padding(.horizontal, AppLayout.screenHorizontal)
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
                .font(.raleway("Regular", size: 11, relativeTo: .caption2))
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
                .font(.raleway("Regular", size: 15, relativeTo: .body))
                .foregroundColor(DesignColors.text)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, AppLayout.screenHorizontal)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Int = 0
    @State private var bounceTimer: Timer?

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(DesignColors.textSecondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .offset(y: (!reduceMotion && phase == index) ? -5 : 0)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aria is typing")
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            guard !reduceMotion else { return }
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
