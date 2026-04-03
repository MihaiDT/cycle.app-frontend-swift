import ComposableArchitecture
import SwiftUI
import UIKit

// MARK: - Card Stack Feature

@Reducer
public struct CardStackFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var cards: [DailyCard] = []
        public var frontIndex: Int = 0
        public var dragOffset: CGFloat = 0
        public var isDragging: Bool = false

        public init() {}

        var visibleCards: [(card: DailyCard, depth: Int)] {
            guard !cards.isEmpty else { return [] }
            let count = cards.count
            return (0..<min(3, count)).map { depth in
                let index = (frontIndex + depth) % count
                return (cards[index], depth)
            }.reversed()
        }
    }

    public enum Action: Sendable {
        case loadCards(CyclePhase, Int)
        case dragChanged(CGFloat)
        case dragEnded(CGFloat, CGFloat)
        case dismissFront
        case cardTapped(DailyCard)
        case actionTapped(DailyCard)
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case openLens
            case startBreathing
            case openJournal(prompt: String)
            case openCheckIn
        }
    }

    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .loadCards(phase, day):
                state.cards = DailyCard.mockCards(for: phase, day: day)
                state.frontIndex = 0
                state.dragOffset = 0
                return .none

            case let .dragChanged(offset):
                state.dragOffset = offset
                state.isDragging = true
                return .none

            case let .dragEnded(translation, velocity):
                state.isDragging = false
                let threshold: CGFloat = 100
                let velocityThreshold: CGFloat = 500
                if abs(translation) > threshold || abs(velocity) > velocityThreshold {
                    let direction: CGFloat = translation > 0 ? 1 : -1
                    state.dragOffset = direction * 500
                    return .send(.dismissFront)
                } else {
                    state.dragOffset = 0
                    return .none
                }

            case .dismissFront:
                guard !state.cards.isEmpty else { return .none }
                state.frontIndex = (state.frontIndex + 1) % state.cards.count
                state.dragOffset = 0
                return .none

            case let .cardTapped(card):
                if card.cardType == .goDeeper {
                    return .send(.delegate(.openLens))
                }
                return .none

            case let .actionTapped(card):
                guard let action = card.action else { return .none }
                switch action.actionType {
                case .openLens:
                    return .send(.delegate(.openLens))
                case .breathing:
                    return .send(.delegate(.startBreathing))
                case .journal:
                    return .send(.delegate(.openJournal(prompt: card.title)))
                case .quickCheck, .challenge:
                    return .none
                }

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Card Stack View

struct CardStackView: View {
    let store: StoreOf<CardStackFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline) {
                Text("Your day")
                    .font(.custom("Raleway-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)

                Spacer()

                // Card position dots
                HStack(spacing: 6) {
                    ForEach(0..<store.cards.count, id: \.self) { i in
                        Circle()
                            .fill(
                                i == store.frontIndex % max(store.cards.count, 1)
                                    ? DesignColors.accentWarm
                                    : DesignColors.structure.opacity(0.25)
                            )
                            .frame(width: 7, height: 7)
                            .animation(.easeInOut(duration: 0.2), value: store.frontIndex)
                    }
                }
                .padding(.bottom, 4)
            }
            .padding(.horizontal, AppLayout.horizontalPadding)

            ZStack {
                ForEach(store.visibleCards, id: \.card.id) { item in
                    let isFront = item.depth == 0

                    DailyCardView(
                        card: item.card,
                        onAction: { store.send(.actionTapped(item.card)) },
                        onCheckIn: { store.send(.delegate(.openCheckIn)) }
                    )
                    .padding(.horizontal, AppLayout.horizontalPadding)
                    .scaleEffect(scale(for: item.depth))
                    .offset(
                        x: isFront ? store.dragOffset : fanOffsetX(for: item.depth),
                        y: fanOffsetY(for: item.depth)
                    )
                    .rotationEffect(
                        isFront
                            ? .degrees(Double(store.dragOffset) * 0.03)
                            : fanRotation(for: item.depth),
                        anchor: .bottom
                    )
                    .opacity(opacity(for: item.depth))
                    .zIndex(Double(3 - item.depth))
                    .allowsHitTesting(isFront)
                    .animation(
                        store.isDragging
                            ? .interactiveSpring(response: 0.15, dampingFraction: 0.8)
                            : .spring(response: 0.4, dampingFraction: 0.75),
                        value: store.dragOffset
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: store.frontIndex)
                    .simultaneousGesture(
                        isFront
                            ? DragGesture(minimumDistance: 30)
                                .onChanged { value in
                                    let dx = abs(value.translation.width)
                                    let dy = abs(value.translation.height)
                                    guard dx > dy * 1.5 else { return }
                                    store.send(.dragChanged(value.translation.width))
                                }
                                .onEnded { value in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    store.send(.dragEnded(
                                        value.translation.width,
                                        value.velocity.width
                                    ))
                                }
                            : nil
                    )
                    .onTapGesture {
                        store.send(.cardTapped(item.card))
                    }
                }
            }
            .frame(height: 370)
        }
    }

    // MARK: - Fan Layout

    private func scale(for depth: Int) -> CGFloat {
        switch depth {
        case 0: return 1.0
        case 1: return 0.93
        default: return 0.86
        }
    }

    private func fanOffsetX(for depth: Int) -> CGFloat {
        switch depth {
        case 1: return -10
        default: return 16
        }
    }

    private func fanOffsetY(for depth: Int) -> CGFloat {
        switch depth {
        case 0: return 0
        case 1: return 14
        default: return 28
        }
    }

    private func fanRotation(for depth: Int) -> Angle {
        switch depth {
        case 1: return .degrees(-3)
        default: return .degrees(5)
        }
    }

    private func opacity(for depth: Int) -> Double {
        switch depth {
        case 0: return 1.0
        case 1: return 0.85
        default: return 0.65
        }
    }
}

// MARK: - Daily Card View

private struct DailyCardView: View {
    let card: DailyCard
    var onAction: (() -> Void)?
    var onCheckIn: (() -> Void)?

    private var phaseAccent: Color { card.cyclePhase.orbitColor }

    private var cardGradient: LinearGradient {
        let colors: [Color] = switch card.cyclePhase {
        case .menstrual:
            [Color(red: 0.94, green: 0.84, blue: 0.82), Color(red: 0.97, green: 0.92, blue: 0.90)]
        case .follicular:
            [Color(red: 0.85, green: 0.93, blue: 0.89), Color(red: 0.93, green: 0.96, blue: 0.94)]
        case .ovulatory:
            [Color(red: 0.96, green: 0.91, blue: 0.80), Color(red: 0.98, green: 0.95, blue: 0.89)]
        case .luteal:
            [Color(red: 0.90, green: 0.87, blue: 0.95), Color(red: 0.95, green: 0.93, blue: 0.97)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        switch card.cardType {
        case .feel: feelLayout
        case .do: doLayout
        case .goDeeper: goDeeperLayout
        }
    }

    // MARK: - FEEL

    private var feelLayout: some View {
        ZStack(alignment: .bottomLeading) {
            cardGradient

            // Watermark icon
            Image(systemName: card.cyclePhase.icon)
                .font(.system(size: 140, weight: .ultraLight))
                .foregroundStyle(phaseAccent.opacity(0.08))
                .offset(x: 90, y: -30)

            VStack(alignment: .leading) {
                Spacer()

                Text(card.title)
                    .font(.custom("Raleway-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(4)

                Spacer().frame(height: 24)

                HStack {
                    if let day = card.cycleDay {
                        Text("Day \(day) · \(card.cyclePhase.displayName)")
                            .font(.custom("Raleway-Medium", size: 14, relativeTo: .caption))
                            .foregroundStyle(phaseAccent.opacity(0.6))
                    }

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onCheckIn?()
                    } label: {
                        HStack(spacing: 6) {
                            Text("How do you feel?")
                                .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .body))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(phaseAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
    }

    // MARK: - DO

    private var doLayout: some View {
        ZStack {
            Color(hex: 0xFDFCF7)

            Circle()
                .fill(DesignColors.accentWarm.opacity(0.1))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 80, y: -60)

            VStack(alignment: .leading) {
                // Action type pill
                if let action = card.action {
                    let iconName: String = switch action.actionType {
                    case .breathing: "wind"
                    case .journal: "pencil.line"
                    case .challenge: "flag.fill"
                    case .quickCheck: "hand.tap.fill"
                    case .openLens: "sparkles"
                    }
                    HStack(spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 12, weight: .medium))
                        Text(action.actionType == .breathing ? "Breathe" :
                                action.actionType == .journal ? "Journal" :
                                action.actionType == .challenge ? "Challenge" : "Check in")
                            .font(.custom("Raleway-SemiBold", size: 12, relativeTo: .caption))
                    }
                    .foregroundStyle(DesignColors.accentWarm)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule().fill(DesignColors.accentWarm.opacity(0.1))
                    }
                }

                Spacer()

                Text(card.title)
                    .font(.custom("Raleway-Bold", size: 26, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(4)

                Spacer().frame(height: 24)

                // CTA
                if let action = card.action {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onAction?()
                    } label: {
                        Text(action.label)
                            .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(DesignColors.accentWarm)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
    }

    // MARK: - GO DEEPER

    private var goDeeperLayout: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.20, blue: 0.28),
                    Color(red: 0.32, green: 0.26, blue: 0.36),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(phaseAccent.opacity(0.15))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: -60, y: -80)

            Circle()
                .fill(DesignColors.accentSecondary.opacity(0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .offset(x: 100, y: 60)

            VStack(alignment: .leading) {
                Spacer()

                Text(card.title)
                    .font(.custom("Raleway-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(.white)
                    .lineSpacing(4)

                Spacer().frame(height: 24)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAction?()
                } label: {
                    HStack(spacing: 8) {
                        Text(card.action?.label ?? "Discover")
                            .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .overlay {
                                Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.75)
                            }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(32)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 10)
    }
}
