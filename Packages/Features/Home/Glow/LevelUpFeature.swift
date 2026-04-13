import ComposableArchitecture
import SwiftUI

// MARK: - Level Up Feature

@Reducer
public struct LevelUpFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public let newLevel: Int
        public let levelTitle: String
        public let levelEmoji: String
        public let unlockDescription: String
        public init(newLevel: Int, levelTitle: String, levelEmoji: String, unlockDescription: String) {
            self.newLevel = newLevel
            self.levelTitle = levelTitle
            self.levelEmoji = levelEmoji
            self.unlockDescription = unlockDescription
        }
    }

    public enum Action: Sendable {
        case appeared
        case dismissTapped
        case autoDismissTimerFired
        case delegate(Delegate)
        public enum Delegate: Sendable {
            case dismissed
        }
    }

    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .appeared:
                return .run { send in
                    try await clock.sleep(for: .seconds(4))
                    await send(.autoDismissTimerFired)
                }
            case .dismissTapped, .autoDismissTimerFired:
                return .send(.delegate(.dismissed))
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Level Up Overlay

struct LevelUpOverlay: View {
    let store: StoreOf<LevelUpFeature>
    @State private var emojiScale: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { store.send(.dismissTapped) }

            VStack(spacing: 16) {
                Text(store.levelEmoji)
                    .font(.system(size: 72))
                    .scaleEffect(emojiScale)

                Text("LEVEL UP!")
                    .font(.custom("Raleway-Bold", size: 28))
                    .foregroundStyle(DesignColors.accentWarm)
                    .opacity(textOpacity)

                Text("You're now a \(store.levelTitle)")
                    .font(.custom("Raleway-SemiBold", size: 20))
                    .foregroundStyle(DesignColors.text)
                    .opacity(textOpacity)

                Text(store.unlockDescription)
                    .font(.custom("Raleway-Regular", size: 15))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
            }
            .padding(40)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                emojiScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                textOpacity = 1.0
            }
            store.send(.appeared)
        }
    }
}
