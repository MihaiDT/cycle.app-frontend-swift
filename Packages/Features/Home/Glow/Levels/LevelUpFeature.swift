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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var emojiScale: CGFloat = 0
    @State private var textOpacity: Double = 0

    private var accessibilityAnnouncement: String {
        "Level up to \(store.newLevel): \(store.levelTitle). \(store.unlockDescription)"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { store.send(.dismissTapped) }
                .accessibilityLabel("Dismiss level up")
                .accessibilityHint("Double tap to close")
                .accessibilityAddTraits(.isButton)

            VStack(spacing: 16) {
                Text(store.levelEmoji)
                    .font(.system(size: 72))
                    .scaleEffect(reduceMotion ? 1 : emojiScale)
                    .accessibilityHidden(true)

                Text("LEVEL UP!")
                    .font(.raleway("Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(DesignColors.accentWarm)
                    .opacity(reduceMotion ? 1 : textOpacity)

                Text("You're now a \(store.levelTitle)")
                    .font(.raleway("SemiBold", size: 20, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)
                    .opacity(reduceMotion ? 1 : textOpacity)

                Text(store.unlockDescription)
                    .font(.raleway("Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(reduceMotion ? 1 : textOpacity)
            }
            .padding(40)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(reduceMotion ? 1 : textOpacity)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityAnnouncement)
            .accessibilityAddTraits(.isHeader)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if reduceMotion {
                emojiScale = 1.0
                textOpacity = 1.0
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    emojiScale = 1.0
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                    textOpacity = 1.0
                }
            }
            store.send(.appeared)
        }
    }
}
