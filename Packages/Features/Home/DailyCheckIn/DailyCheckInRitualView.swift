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

    @State var currentPage: Int = 0
    @State var answers: [Int] = Array(repeating: 2, count: 4)
    @State var interacted: [Bool] = Array(repeating: false, count: 4)
    @State var ariaVisibleCount: Int = 0
    @State var ariaCloseVisible: Bool = false

    static let questions: [RitualQuestion] = [
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

    var topBar: some View {
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
                .padding(.horizontal, AppLayout.screenHorizontal)
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

    func goBack() {
        guard currentPage > 0 else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            currentPage -= 1
        }
    }

    // MARK: - Question page

    @ViewBuilder
    func questionPage(index pageIdx: Int) -> some View {
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

    // MARK: - Actions

    func advancePage() {
        guard currentPage < 4 else { return }
        withAnimation(.easeInOut(duration: 0.55)) {
            currentPage += 1
        }
    }

    func skipToAria() {
        withAnimation(.easeInOut(duration: 0.55)) {
            currentPage = 4
        }
    }

    func closeRitual() {
        // Map selected indices (0-4) → domain 1-5; stress is inverted (clear=low stress).
        store.moodLevel = Double(answers[0] + 1)
        store.energyLevel = Double(answers[1] + 1)
        store.sleepQuality = Double(answers[2] + 1)
        store.stressLevel = Double(5 - answers[3])
        store.send(.submitTapped)
    }

    // MARK: - Aria reveal

    func beginAriaReveal() {
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

    func ariaTokens() -> [AriaToken] {
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

    static func tokens(_ text: String) -> [AriaToken] {
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

struct RitualQuestion {
    let eyebrow: String
    let prefix: String
    let keyword: String
    let suffix: String
    let words: [String]
}

struct AriaToken {
    let word: String
    let emphasized: Bool
}

// MARK: - Flow layout (wraps words across lines like CSS flex-wrap)

struct RitualFlowLayout: Layout {
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
