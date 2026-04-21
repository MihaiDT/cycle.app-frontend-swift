import ComposableArchitecture
import SwiftUI

// MARK: - Daily Check-In Ritual View
//
// Four-question editorial ritual (heart / energy / rest / weather inside)
// followed by an Aria closing page. Each question uses a vertical slider
// with a draggable thumb and 5 tappable word labels. Background gradient
// reacts live to the slider position. On close, the selected indices are
// mapped to the domain fields on DailyCheckInFeature.State and submitted.

struct DailyCheckInRitualView: View {
    @Bindable var store: StoreOf<DailyCheckInFeature>

    @State private var currentPage: Int = 0
    @State private var answers: [Int] = Array(repeating: 2, count: 4)
    @State private var interacted: [Bool] = Array(repeating: false, count: 4)
    @State private var ariaVisibleCount: Int = 0
    @State private var ariaCloseVisible: Bool = false

    private static let questions: [RitualQuestion] = [
        RitualQuestion(
            eyebrow: "01 · 04",
            prefix: "How's your",
            keyword: "heart",
            suffix: "today?",
            words: ["heavy", "muted", "steady", "bright", "luminous"]
        ),
        RitualQuestion(
            eyebrow: "02 · 04",
            prefix: "Where did your",
            keyword: "energy",
            suffix: "land?",
            words: ["drained", "low", "steady", "bright", "electric"]
        ),
        RitualQuestion(
            eyebrow: "03 · 04",
            prefix: "Did",
            keyword: "rest",
            suffix: "find you?",
            words: ["restless", "light", "enough", "deep", "dreamy"]
        ),
        RitualQuestion(
            eyebrow: "04 · 04",
            prefix: "What's the",
            keyword: "weather",
            suffix: "inside?",
            words: ["storming", "tense", "gathering", "calm", "clear"]
        )
    ]

    private let totalPages: Int = 5 // 4 questions + Aria

    var body: some View {
        ZStack {
            reactiveBackground
                .animation(.easeOut(duration: 0.8), value: currentPage)
                .animation(.easeOut(duration: 0.6), value: answers)

            Group {
                if currentPage < 4 {
                    questionPage(index: currentPage)
                        .id("page-\(currentPage)")
                } else {
                    ariaPage
                        .id("aria")
                }
            }
            .transition(.opacity.animation(.easeOut(duration: 0.4)))

            topBar
                .opacity(currentPage < 4 ? 1 : 0)
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: currentPage) { _, newValue in
            if newValue == 4 { beginAriaReveal() }
        }
    }

    // MARK: - Top bar (dots + skip)

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if currentPage < 4 {
                    Text(Self.todayLabel)
                        .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                }

                Spacer()

                HomeWidgetCarouselDots(
                    pageCount: 4,
                    currentIndex: Binding(
                        get: { min(currentPage, 3) },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.5)) {
                                currentPage = newValue
                            }
                        }
                    )
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffectCapsule()
                .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
            }
            .padding(.horizontal, 24)
            .padding(.top, 46)

            Spacer()
        }
    }

    private static let todayLabel: String = {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: Date()).lowercased()
    }()

    private func goBack() {
        guard currentPage > 0 else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            currentPage -= 1
        }
    }

    // MARK: - Question page

    @ViewBuilder
    private func questionPage(index pageIdx: Int) -> some View {
        let q = Self.questions[pageIdx]
        VStack(spacing: 0) {
            Spacer().frame(height: 96)

            VStack(alignment: .leading, spacing: 10) {
                (Text(q.prefix + " ")
                    .font(.raleway("Regular", size: 24, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)
                + Text(q.keyword)
                    .font(.raleway("Bold", size: 26, relativeTo: .title2))
                    .italic()
                    .foregroundStyle(DesignColors.accentWarmText)
                + Text(" " + q.suffix)
                    .font(.raleway("Regular", size: 24, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text))
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)

            Spacer(minLength: 0)

            CircularRitualDial(
                words: q.words,
                index: Binding(
                    get: { answers[pageIdx] },
                    set: { newValue in
                        if answers[pageIdx] != newValue {
                            answers[pageIdx] = newValue
                            interacted[pageIdx] = true
                        }
                    }
                )
            )
            .padding(.horizontal, 28)

            Spacer(minLength: 0)

            HStack {
                if pageIdx > 0 {
                    Button(action: goBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back")
                                .font(.raleway("SemiBold", size: 15, relativeTo: .headline))
                        }
                        .foregroundStyle(DesignColors.text.opacity(0.75))
                        .padding(.horizontal, 22)
                        .frame(height: 52)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                Spacer()

                Button(action: advancePage) {
                    HStack(spacing: 8) {
                        continueLabel(for: pageIdx)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(DesignColors.text)
                    .padding(.horizontal, 28)
                    .frame(height: 52)
                    .glassEffectCapsule()
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .animation(.easeOut(duration: 0.3), value: pageIdx)
            .padding(.horizontal, AppLayout.horizontalPadding)
            .padding(.bottom, 42)
        }
    }

    // MARK: - Aria page

    private var ariaPage: some View {
        let tokens = ariaTokens()
        return VStack(spacing: 0) {
            Spacer()

            NyraOrb(size: 138, mood: .comforting)
                .padding(.bottom, 28)

            // Summary of selections — the four words the user picked
            summaryRow
                .padding(.bottom, 28)

            // Word-by-word reveal
            RitualFlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                    Group {
                        if token.emphasized {
                            Text(token.word).italic()
                                .font(.raleway("SemiBold", size: 28, relativeTo: .title2))
                                .foregroundStyle(DesignColors.accentWarmText)
                        } else {
                            Text(token.word)
                                .font(.raleway("Regular", size: 28, relativeTo: .title2))
                                .foregroundStyle(DesignColors.text)
                        }
                    }
                    .opacity(index < ariaVisibleCount ? 1 : 0)
                    .offset(y: index < ariaVisibleCount ? 0 : 10)
                    .animation(.easeOut(duration: 0.7), value: ariaVisibleCount)
                }
            }
            .padding(.horizontal, 38)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            Spacer()

            if let errorMessage = store.error {
                Text(errorMessage)
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.red.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }

            HStack {
                Spacer()
                Button(action: closeRitual) {
                    HStack(spacing: 8) {
                        if store.isSubmitting {
                            ProgressView()
                                .tint(DesignColors.text)
                        }
                        Text(store.isSubmitting ? "Saving…" : "All done")
                            .font(.raleway("SemiBold", size: 15, relativeTo: .headline))
                            .foregroundStyle(DesignColors.text)
                    }
                    .padding(.horizontal, 32)
                    .frame(height: 52)
                    .glassEffectCapsule()
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(store.isSubmitting)
                .fixedSize()
                Spacer()
            }
            .opacity(ariaCloseVisible ? 1 : 0)
            .offset(y: ariaCloseVisible ? 0 : 8)
            .animation(.easeOut(duration: 0.6), value: ariaCloseVisible)
            .padding(.bottom, 56)
        }
    }

    private var line: some View {
        Rectangle()
            .fill(DesignColors.accentWarm.opacity(0.35))
            .frame(width: 22, height: 1)
    }

    // MARK: - Reactive background

    private var reactiveBackground: some View {
        LinearGradient(
            stops: backgroundStops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var backgroundStops: [Gradient.Stop] {
        guard currentPage < 4 else {
            return [
                .init(color: Color(hex: 0xFDF2E4), location: 0.0),
                .init(color: Color(hex: 0xF2E4D3), location: 1.0)
            ]
        }
        let idx = answers[currentPage]
        let palette = Self.backgroundPalettes[currentPage]
        let pair = palette[idx]
        return [
            .init(color: pair.0, location: 0.0),
            .init(color: pair.1, location: 1.0)
        ]
    }

    // Four distinct palettes, all in the cycle.app warm brand family.
    // Each question has its own character (blush / coral / bloom / earth)
    // but stays within peach, rose, rust, and brown tones.
    private static let backgroundPalettes: [[(Color, Color)]] = [
        // ── Heart — warm blush / rose ────────────────────────────
        [
            (Color(hex: 0xD9BBB7), Color(hex: 0xA67570)),
            (Color(hex: 0xE8CAC2), Color(hex: 0xC29F98)),
            (Color(hex: 0xFDE8E0), Color(hex: 0xF3C9C2)),
            (Color(hex: 0xFEE5DC), Color(hex: 0xF5B3A6)),
            (Color(hex: 0xFEF0E8), Color(hex: 0xFBCEBA))
        ],
        // ── Energy — amber peach / coral ─────────────────────────
        [
            (Color(hex: 0xD6C4BA), Color(hex: 0xA98A7B)),
            (Color(hex: 0xE6CDBA), Color(hex: 0xC29A85)),
            (Color(hex: 0xFCEDDC), Color(hex: 0xF1CEAE)),
            (Color(hex: 0xFED9BC), Color(hex: 0xF5A378)),
            (Color(hex: 0xFEE2C2), Color(hex: 0xFA8E5E))
        ],
        // ── Rest — dusty bloom (muted peach + soft rose) ─────────
        [
            (Color(hex: 0xE4CFC5), Color(hex: 0xB89B92)),
            (Color(hex: 0xEFD8CC), Color(hex: 0xC7A89E)),
            (Color(hex: 0xFCE6D4), Color(hex: 0xF3C9C2)),
            (Color(hex: 0xFDEEDD), Color(hex: 0xF6D4C7)),
            (Color(hex: 0xFDF2E8), Color(hex: 0xF9E2D6))
        ],
        // ── Weather — earth brown → ivory peach ──────────────────
        [
            (Color(hex: 0xA68877), Color(hex: 0x5C3B30)),
            (Color(hex: 0xC5A799), Color(hex: 0x8A5A1E)),
            (Color(hex: 0xE8CCB8), Color(hex: 0xC99B95)),
            (Color(hex: 0xFBE6D1), Color(hex: 0xF3C9C2)),
            (Color(hex: 0xFDF2E3), Color(hex: 0xFCE6D4))
        ]
    ]

    // MARK: - Continue label (hints what's next)

    // MARK: - Aria summary row

    /// The four words the user chose across the ritual, separated by
    /// centered dots. A gentle closure / validation of the session.
    private var summaryRow: some View {
        let chosen: [String] = (0..<4).map { i in
            Self.questions[i].words[answers[i]]
        }
        return HStack(spacing: 10) {
            ForEach(Array(chosen.enumerated()), id: \.offset) { idx, word in
                if idx > 0 {
                    Circle()
                        .fill(DesignColors.accentWarmText.opacity(0.35))
                        .frame(width: 3, height: 3)
                }
                Text(word)
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .italic()
                    .foregroundStyle(DesignColors.accentWarmText.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Continue label

    private func continueLabel(for pageIdx: Int) -> some View {
        let keyword: String
        switch pageIdx {
        case 0: keyword = "energy"
        case 1: keyword = "rest"
        case 2: keyword = "weather"
        case 3: keyword = "reflection"
        default: keyword = ""
        }
        return Text(keyword)
            .font(.raleway("Bold", size: 15, relativeTo: .headline))
            .italic()
            .foregroundStyle(DesignColors.text)
    }

    // MARK: - Actions

    private func advancePage() {
        guard currentPage < 4 else { return }
        withAnimation(.easeInOut(duration: 0.55)) {
            currentPage += 1
        }
    }

    private func skipToAria() {
        withAnimation(.easeInOut(duration: 0.55)) {
            currentPage = 4
        }
    }

    private func closeRitual() {
        // Map selected indices (0-4) → domain 1-5; stress is inverted (clear=low stress).
        store.moodLevel = Double(answers[0] + 1)
        store.energyLevel = Double(answers[1] + 1)
        store.sleepQuality = Double(answers[2] + 1)
        store.stressLevel = Double(5 - answers[3])
        store.send(.submitTapped)
    }

    // MARK: - Aria reveal

    private func beginAriaReveal() {
        let tokens = ariaTokens()
        ariaVisibleCount = 0
        ariaCloseVisible = false
        for i in 0..<tokens.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.115 + 0.3) {
                if currentPage == 4 {
                    ariaVisibleCount = i + 1
                }
            }
        }
        let total = Double(tokens.count) * 0.115 + 1.1
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            if currentPage == 4 { ariaCloseVisible = true }
        }
    }

    private func ariaTokens() -> [AriaToken] {
        let valid = answers.prefix(4)
        guard !valid.isEmpty else { return Self.ariaMessages.empty }
        let avg = Double(valid.reduce(0, +)) / Double(valid.count)
        switch avg {
        case ..<1.2: return Self.ariaMessages.soft
        case ..<2.2: return Self.ariaMessages.tender
        case ..<3.2: return Self.ariaMessages.balanced
        case ..<4.2: return Self.ariaMessages.bright
        default:     return Self.ariaMessages.light
        }
    }

    private struct AriaMessages {
        let empty: [AriaToken]
        let soft: [AriaToken]
        let tender: [AriaToken]
        let balanced: [AriaToken]
        let bright: [AriaToken]
        let light: [AriaToken]
    }

    private static let ariaMessages = AriaMessages(
        empty: tokens("A quiet day, lovingly *witnessed.* Tomorrow begins again."),
        soft: tokens("Today your body is asking for *softness.* Trust it."),
        tender: tokens("A tender day, lovingly held. *Rest* when you can."),
        balanced: tokens("Somewhere between storm and shine — *let it be.*"),
        bright: tokens("The current is moving with you. Follow its *ease.*"),
        light: tokens("Carry the *light* gently — bright days still need rest.")
    )

    private static func tokens(_ text: String) -> [AriaToken] {
        // Words wrapped in *...* are emphasized.
        var out: [AriaToken] = []
        let parts = text.split(separator: " ", omittingEmptySubsequences: true)
        for part in parts {
            let raw = String(part)
            if raw.hasPrefix("*") && raw.hasSuffix("*") && raw.count > 2 {
                let inner = String(raw.dropFirst().dropLast())
                out.append(AriaToken(word: inner, emphasized: true))
            } else if raw.hasPrefix("*") {
                let inner = String(raw.dropFirst())
                out.append(AriaToken(word: inner, emphasized: true))
            } else if raw.hasSuffix("*") {
                let inner = String(raw.dropLast())
                out.append(AriaToken(word: inner, emphasized: true))
            } else {
                out.append(AriaToken(word: raw, emphasized: false))
            }
        }
        return out
    }
}

// MARK: - Ritual question model

private struct RitualQuestion {
    let eyebrow: String
    let prefix: String
    let keyword: String
    let suffix: String
    let words: [String]
}

private struct AriaToken {
    let word: String
    let emphasized: Bool
}

// MARK: - Gradient Ritual Scale
//
// Editorial vertical scale inspired by the wellness-app reference:
// big bold active word on the left, thin center track with five tick
// dots, and a solid draggable handle (warm peach, white ring, soft
// shadow). Two short horizontal "ears" extend from the handle to mark
// the active tick. Haptic soft-impact on each tick crossing.

struct GradientRitualScale: View {
    let words: [String]
    @Binding var index: Int

    @State private var isDragging: Bool = false
    @State private var continuousY: CGFloat = 0

    private let height: CGFloat = 320
    private let handleSize: CGFloat = 48
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    private var step: CGFloat { height / 4 }

    private func yForIndex(_ i: Int) -> CGFloat {
        CGFloat(4 - i) * step
    }

    private func indexForY(_ y: CGFloat) -> Int {
        let clamped = max(0, min(height, y))
        let raw = 4.0 - (clamped / step)
        return max(0, min(4, Int(raw.rounded())))
    }

    private var handleY: CGFloat {
        isDragging ? continuousY : yForIndex(index)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            labelsColumn
            trackAndHandle
        }
        .frame(height: height)
    }

    // MARK: Labels column

    private var labelsColumn: some View {
        VStack(spacing: 0) {
            ForEach([4, 3, 2, 1, 0], id: \.self) { i in
                Button {
                    if index != i { haptic.impactOccurred() }
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                        index = i
                    }
                } label: {
                    Text(words[i])
                        .font(.raleway(
                            index == i ? "Bold" : "Regular",
                            size: index == i ? 22 : 15,
                            relativeTo: .body
                        ))
                        .foregroundStyle(
                            index == i
                                ? DesignColors.text
                                : DesignColors.textSecondary.opacity(0.4)
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: step)
                        .contentShape(Rectangle())
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: index)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 150)
    }

    // MARK: Track + handle

    private var trackAndHandle: some View {
        ZStack(alignment: .top) {
            // Thin center track
            Capsule()
                .fill(DesignColors.accentWarm.opacity(0.28))
                .frame(width: 2, height: height)

            // Five small tick dots on the track
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(
                        index == i
                            ? DesignColors.accentWarm
                            : DesignColors.accentWarm.opacity(0.45)
                    )
                    .frame(width: index == i ? 8 : 5, height: index == i ? 8 : 5)
                    .offset(y: yForIndex(i) - (index == i ? 4 : 2.5))
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: index)
            }

            // "Ears" — short horizontal lines flanking the handle
            HStack(spacing: handleSize + 14) {
                Capsule()
                    .fill(DesignColors.accentWarm)
                    .frame(width: 14, height: 2)
                Capsule()
                    .fill(DesignColors.accentWarm)
                    .frame(width: 14, height: 2)
            }
            .offset(y: handleY - 1)
            .animation(
                isDragging ? nil : .spring(response: 0.48, dampingFraction: 0.72),
                value: handleY
            )

            // Handle
            handleView
                .offset(y: handleY - handleSize / 2)
                .animation(
                    isDragging ? nil : .spring(response: 0.48, dampingFraction: 0.72),
                    value: handleY
                )
        }
        .frame(width: 60, height: height, alignment: .top)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        haptic.prepare()
                    }
                    let y = max(0, min(height, value.location.y))
                    continuousY = y
                    let newIdx = indexForY(y)
                    if newIdx != index {
                        index = newIdx
                        haptic.impactOccurred()
                    }
                }
                .onEnded { _ in
                    let newIdx = indexForY(continuousY)
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                        isDragging = false
                        index = newIdx
                        continuousY = yForIndex(newIdx)
                    }
                }
        )
    }

    // MARK: Handle

    private var handleView: some View {
        ZStack {
            Circle()
                .fill(DesignColors.accentWarm)
                .frame(width: handleSize, height: handleSize)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(
                    color: DesignColors.accentWarm.opacity(isDragging ? 0.55 : 0.32),
                    radius: isDragging ? 16 : 10,
                    x: 0, y: 4
                )
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 2, x: 0, y: 1
                )

            // Grip indicator — 3 thin horizontal lines
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 14, height: 1.5)
                }
            }
        }
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
}

// MARK: - Breathing orb (Aria page)

private struct AriaBreathingOrb: View {
    @State private var breathe: Bool = false

    var body: some View {
        ZStack {
            // Outer breath rings
            ForEach(0..<2) { i in
                Circle()
                    .stroke(DesignColors.accentWarm.opacity(0.18), lineWidth: 1)
                    .scaleEffect(breathe ? 1.35 + CGFloat(i) * 0.18 : 0.95)
                    .opacity(breathe ? 0 : 0.55)
                    .animation(
                        .easeOut(duration: 4.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 1.6),
                        value: breathe
                    )
            }

            // Orb body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            DesignColors.accentWarm.opacity(0.5),
                            DesignColors.accentWarm.opacity(0.85)
                        ],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: 4,
                        endRadius: 90
                    )
                )
                .shadow(color: DesignColors.accentWarm.opacity(0.45), radius: 28, x: 0, y: 10)
                .scaleEffect(breathe ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 4.5).repeatForever(autoreverses: true),
                    value: breathe
                )
        }
        .onAppear { breathe = true }
    }
}

// MARK: - Flow layout (wraps words across lines like CSS flex-wrap)

private struct RitualFlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var lineHeight: CGFloat = 0

        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if lineWidth + s.width > width, lineWidth > 0 {
                totalHeight += lineHeight + lineSpacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
        totalHeight += lineHeight
        return CGSize(width: width == .infinity ? lineWidth : width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width

        // Compute lines with sizes, then center each line horizontally
        struct LineEntry { var subview: LayoutSubviews.Element; var size: CGSize }
        var lines: [[LineEntry]] = [[]]
        var currentWidth: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if currentWidth + s.width > width, !(lines.last?.isEmpty ?? true) {
                lines.append([])
                currentWidth = 0
            }
            lines[lines.count - 1].append(LineEntry(subview: sub, size: s))
            currentWidth += s.width + spacing
        }

        var y = bounds.minY
        for line in lines {
            let lineContentWidth = line.reduce(CGFloat(0)) { $0 + $1.size.width } + spacing * CGFloat(max(0, line.count - 1))
            var x = bounds.minX + (width - lineContentWidth) / 2
            let lineHeight = line.map { $0.size.height }.max() ?? 0
            for entry in line {
                entry.subview.place(
                    at: CGPoint(x: x, y: y + (lineHeight - entry.size.height) / 2),
                    proposal: ProposedViewSize(width: entry.size.width, height: entry.size.height)
                )
                x += entry.size.width + spacing
            }
            y += lineHeight + lineSpacing
        }
    }
}
