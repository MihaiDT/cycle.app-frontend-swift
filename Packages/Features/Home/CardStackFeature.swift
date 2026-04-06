import ComposableArchitecture
import SwiftData
import SwiftUI
import UIKit

// MARK: - Card Stack Feature

@Reducer
public struct CardStackFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var cards: [DailyCard] = []
        public var isLoading: Bool = false
        public var frontIndex: Int = 0
        public var dragOffset: CGFloat = 0
        public var isDragging: Bool = false
        /// Track current combo to skip redundant loads
        public var currentPhase: CyclePhase?
        public var currentDay: Int?

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
        case cardsGenerated([DailyCard])
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

    private enum CancelID { case cardFetch }

    @Dependency(\.continuousClock) var clock

    private static let cardsURL = "http://34.72.143.234:8081/api/daily-cards"

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .loadCards(phase, day):
                // Same phase — nothing to do (day is cosmetic, phase drives content)
                guard state.currentPhase != phase else {
                    state.currentDay = day
                    return .none
                }

                state.currentPhase = phase
                state.currentDay = day
                let today = Self.todayString()

                // Cache hit — keyed by (date, phase) only
                let cached = Self.loadCachedCards(date: today, phase: phase, day: day)
                if !cached.isEmpty {
                    state.cards = cached
                    state.frontIndex = 0
                    state.dragOffset = 0
                    state.isLoading = false
                    return .none
                }

                // Cache miss — fetch from AI, debounced
                state.isLoading = true
                state.cards = []
                let phaseStr = phase.rawValue
                return .run { [clock] send in
                    do {
                        try await clock.sleep(for: .milliseconds(300))
                    } catch {
                        return // cancelled by cancelInFlight — next loadCards will retry
                    }
                    if let aiCards = await Self.fetchAICards(phase: phaseStr, day: day) {
                        Self.cacheCards(aiCards, date: today, phase: phaseStr)
                        await send(.cardsGenerated(aiCards))
                    } else {
                        await send(.cardsGenerated([]))
                    }
                }
                .cancellable(id: CancelID.cardFetch, cancelInFlight: true)

            case let .cardsGenerated(cards):
                state.isLoading = false
                guard !cards.isEmpty else { return .none }
                state.cards = cards
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
        if store.isLoading {
            CardSkeletonView()
        } else {
            cardContent
                .transition(.opacity.animation(.easeIn(duration: 0.3)))
        }
    }

    private var cardContent: some View {
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
                        displayDay: store.currentDay,
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

// MARK: - Card Skeleton (Shimmer Loading)

private struct CardSkeletonView: View {
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your day")
                .font(.custom("Raleway-Bold", size: 28, relativeTo: .title))
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, AppLayout.horizontalPadding)

            ZStack {
                // Back card skeleton
                skeletonCard
                    .scaleEffect(0.92)
                    .offset(y: 28)
                    .opacity(0.5)

                // Middle card skeleton
                skeletonCard
                    .scaleEffect(0.96)
                    .offset(y: 14)
                    .rotationEffect(.degrees(-3), anchor: .bottom)
                    .opacity(0.7)

                // Front card skeleton
                skeletonCard
            }
            .padding(.horizontal, AppLayout.horizontalPadding)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmerOffset = 2
            }
        }
    }

    private var skeletonCard: some View {
        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
            .fill(Color(red: 0.94, green: 0.93, blue: 0.91))
            .frame(height: 320)
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.4), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset * 300)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
            .overlay {
                VStack(alignment: .leading, spacing: 16) {
                    // Icon placeholder
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 36, height: 36)

                    Spacer()

                    // Title placeholder
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 180, height: 18)

                    // Body placeholder lines
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 220, height: 12)
                }
                .padding(24)
            }
    }
}

// MARK: - Daily Card View

private struct DailyCardView: View {
    let card: DailyCard
    /// Always use the latest broadcast day, not the baked-in card value
    var displayDay: Int?
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
        case .late:
            [Color(red: 0.92, green: 0.91, blue: 0.89), Color(red: 0.96, green: 0.95, blue: 0.94)]
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
                    .font(.custom("Raleway-Bold", size: 24, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(4)

                if !card.body.isEmpty {
                    Text(card.body)
                        .font(.custom("Raleway-Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .lineSpacing(3)
                        .lineLimit(3)
                }

                Spacer().frame(height: 16)

                HStack {
                    if let day = displayDay ?? card.cycleDay {
                        Text(card.cyclePhase == .late
                             ? "\(day) days late"
                             : "Day \(day) · \(card.cyclePhase.displayName)")
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
                    .font(.custom("Raleway-Bold", size: 24, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(4)

                if !card.body.isEmpty {
                    Text(card.body)
                        .font(.custom("Raleway-Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textSecondary)
                        .lineSpacing(3)
                        .lineLimit(3)
                }

                Spacer().frame(height: 16)

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
                    .font(.custom("Raleway-Bold", size: 24, relativeTo: .title))
                    .foregroundStyle(.white)
                    .lineSpacing(4)

                if !card.body.isEmpty {
                    Text(card.body)
                        .font(.custom("Raleway-Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineSpacing(3)
                        .lineLimit(2)
                }

                Spacer().frame(height: 16)

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

// MARK: - AI Card Generation

extension CardStackFeature {

    static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private static let cacheTTL: TimeInterval = 7 * 24 * 3600 // 7 days

    static func loadCachedCards(date: String, phase: CyclePhase, day: Int) -> [DailyCard] {
        let container = CycleDataStore.shared
        let context = ModelContext(container)
        let phaseStr = phase.rawValue
        let descriptor = FetchDescriptor<DailyCardRecord>(
            predicate: #Predicate { $0.date == date && $0.cyclePhase == phaseStr },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let records = try? context.fetch(descriptor), !records.isEmpty else { return [] }

        // TTL — stale cards get purged and regenerated
        if let oldest = records.first, Date.now.timeIntervalSince(oldest.createdAt) > cacheTTL {
            for record in records { context.delete(record) }
            try? context.save()
            return []
        }

        return records.map { record in
            DailyCard(
                id: .init("\(record.cardType)-\(record.date)"),
                cardType: CardType(rawValue: record.cardType) ?? .feel,
                title: record.title,
                body: record.body,
                cyclePhase: phase,
                cycleDay: day,
                action: record.cardType == "go_deeper"
                    ? CardAction(actionType: .openLens, label: "Discover")
                    : record.cardType == "do"
                        ? CardAction(actionType: .breathing, label: "Try this")
                        : nil
            )
        }
    }

    static func cacheCards(_ cards: [DailyCard], date: String, phase: String) {
        let container = CycleDataStore.shared
        let context = ModelContext(container)

        // Clear cards for this phase today
        let descriptor = FetchDescriptor<DailyCardRecord>(
            predicate: #Predicate { $0.date == date && $0.cyclePhase == phase }
        )
        if let existing = try? context.fetch(descriptor) {
            for record in existing { context.delete(record) }
        }

        // Purge stale cards from previous days
        let staleDescriptor = FetchDescriptor<DailyCardRecord>(
            predicate: #Predicate { $0.date != date }
        )
        if let stale = try? context.fetch(staleDescriptor) {
            for record in stale { context.delete(record) }
        }

        for card in cards {
            let record = DailyCardRecord(
                date: date,
                cardType: card.cardType.rawValue,
                title: card.title,
                body: card.body,
                cyclePhase: phase,
                cycleDay: card.cycleDay ?? 0
            )
            context.insert(record)
        }
        try? context.save()
    }

    static func fetchAICards(phase: String, day: Int) async -> [DailyCard]? {
        // Get current health context
        let container = CycleDataStore.shared
        let ctx = ModelContext(container)

        var energy = 3, mood = 3, stress = 3, sleep = 3, hbiScore = 0
        var symptoms: [String] = []

        let reportDesc = FetchDescriptor<SelfReportRecord>(
            sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
        )
        if let report = try? ctx.fetch(reportDesc).first {
            energy = report.energyLevel
            mood = report.moodLevel
            stress = report.stressLevel
            sleep = report.sleepQuality
        }

        let scoreDesc = FetchDescriptor<HBIScoreRecord>(
            sortBy: [SortDescriptor(\.scoreDate, order: .reverse)]
        )
        if let score = try? ctx.fetch(scoreDesc).first {
            hbiScore = Int(score.hbiAdjusted.rounded())
        }

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let symptomDesc = FetchDescriptor<SymptomRecord>(
            predicate: #Predicate { $0.symptomDate >= weekAgo }
        )
        symptoms = ((try? ctx.fetch(symptomDesc)) ?? []).map(\.symptomType)

        // Build request
        let payload: [String: Any] = [
            "cycle_phase": phase,
            "cycle_day": day,
            "energy": energy,
            "mood": mood,
            "stress": stress,
            "sleep": sleep,
            "hbi_score": hbiScore,
            "recent_symptoms": Array(Set(symptoms)),
        ]

        guard let url = URL(string: cardsURL),
              let body = try? JSONSerialization.data(withJSONObject: payload)
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResp = response as? HTTPURLResponse,
              httpResp.statusCode == 200
        else { return nil }

        struct AIResponse: Decodable {
            let cards: [AICard]
            struct AICard: Decodable {
                let card_type: String
                let title: String
                let body: String
            }
        }

        guard let aiResp = try? JSONDecoder().decode(AIResponse.self, from: data) else { return nil }

        let cyclePhase = CyclePhase(rawValue: phase) ?? .follicular

        return aiResp.cards.map { card in
            let cardType = CardType(rawValue: card.card_type) ?? .feel
            return DailyCard(
                id: .init("\(card.card_type)-ai-\(todayString())"),
                cardType: cardType,
                title: card.title,
                body: card.body,
                cyclePhase: cyclePhase,
                cycleDay: day,
                action: cardType == .goDeeper
                    ? CardAction(actionType: .openLens, label: "Discover")
                    : cardType == .do
                        ? CardAction(actionType: .breathing, label: "Try this")
                        : nil
            )
        }
    }
}
