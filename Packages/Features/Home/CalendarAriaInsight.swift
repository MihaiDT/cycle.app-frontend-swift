import SwiftUI

// MARK: - Aria Insight Text

enum AriaInsightText: Sendable {
    static func insight(for cycleDay: Int?, phase: CyclePhase?, isPredicted: Bool) -> String {
        guard let day = cycleDay else {
            return "Log your cycle start date to receive personalized AI-powered insights for every day of your cycle."
        }
        let p = isPredicted
        switch day {
        case 1:
            return p
                ? "Your period is about to begin. Rest, warmth, and iron-rich foods will make a real difference in the days ahead."
                : "Day 1 — your cycle resets. Honour the heaviness with rest. Warm compresses and magnesium-rich foods ease cramps."
        case 2:
            return p
                ? "Flow will likely be at its heaviest. Clear your schedule where you can and lean into slower movement."
                : "Flow peaks today for most. Energy is at its lowest — this is not the day to push hard. Your body is doing profound work."
        case 3:
            return p
                ? "The sharpest fatigue starts to ease. Gentle walks and warming meals will support your recovery."
                : "The edge softens today. A little iron and vitamin C together — think spinach with lemon — will help replenish what you're losing."
        case 4:
            return p
                ? "Flow lightens and mood begins to lift. A good day to re-engage with light tasks."
                : "Lighter flow, lighter mood. Estrogen is quietly beginning its rise. You may notice a small but real shift in your energy."
        case 5:
            return p
                ? "Your period is nearly over. Expect a noticeable lift in energy in the coming days."
                : "Last day of bleeding for most. The fog is clearing — notice how differently your body feels compared to day 1."
        case 6:
            return p
                ? "Follicular phase begins. Curiosity and motivation will build steadily over the next week."
                : "Estrogen climbs and so does your drive. A great day to revisit goals or start something you've been putting off."
        case 7:
            return p
                ? "Mental clarity will sharpen. This is an excellent window for focused, deep work."
                : "Your brain is running cleaner today. Verbal fluency and memory are measurably stronger in the follicular phase — use it."
        case 8:
            return p
                ? "Creative energy is building. Plan space for ideas, writing, or any work that rewards fresh thinking."
                : "Creativity is near its peak. Ideas flow more freely now. A whiteboard session, a new recipe, a song — go for it."
        case 9:
            return p
                ? "Social magnetism increases. Conversations, networking, and connection will feel more natural and rewarding."
                : "You're more persuasive and charismatic today than at almost any other point in your cycle. Own it."
        case 10:
            return p
                ? "Confidence and focus compound. Ambitious projects started now tend to gain real momentum."
                : "Estrogen is high and your threshold for stress is elevated. Tackle the hard conversation or the bold project today."
        case 11:
            return p
                ? "Energy approaches its monthly peak. Schedule the things that demand your best."
                : "You're close to your peak — physically and mentally. Your body is primed for intensity, connection, and performance."
        case 12:
            return p
                ? "LH surge is imminent. Expect a noticeable spike in drive and confidence."
                : "The pre-ovulation surge is here. Your body temperature rises slightly and so does your appetite for challenge."
        case 13:
            return p
                ? "Tomorrow may be ovulation. Your magnetism and verbal skills are at their monthly high."
                : "Peak estrogen and rising LH. Your face, voice, and posture subtly shift — research confirms you appear and feel most confident today."
        case 14:
            return p
                ? "Ovulation is likely today. High energy, strong communication, and heightened senses are all normal."
                : "Ovulation day. You are at peak vitality — strong, social, and sharp. Schedule your most important meeting or workout today."
        case 15:
            return p
                ? "Progesterone begins rising. Energy stays high but will gradually soften inward."
                : "The shift begins. Progesterone climbs and your body starts a quieter, more inward phase. You still have plenty of fuel."
        case 16:
            return p
                ? "Energy remains good but starts transitioning. Begin wrapping up high-output work."
                : "A bridge day — still capable of high output, but your nervous system will thank you for starting to taper intensity."
        case 17:
            return p
                ? "Luteal phase begins. Structured routines and nourishing meals become more important now."
                : "Progesterone dominates. Stability and routine feel more grounding than novelty today. Lean in."
        case 18:
            return p
                ? "Introspective energy rises. Good for journaling, detailed work, and creative finishing."
                : "You're entering a 'finishing' mode — detail-oriented, discerning. Great for editing, refining, and deep solo work."
        case 19:
            return p
                ? "A calmer, more grounded window. Steady output is very achievable with the right pacing."
                : "Progesterone's calming effect is real. Use this steadier emotional state for meaningful conversations you've been postponing."
        case 20:
            return p
                ? "Your body will need more nourishment. Prioritise protein, healthy fats, and complex carbs."
                : "Metabolism speeds up slightly in the luteal phase — your body genuinely needs more fuel. Don't fight the hunger."
        case 21:
            return p
                ? "PMS symptoms may begin. Reduce caffeine and alcohol, increase magnesium and omega-3s."
                : "If PMS arrives, it typically starts around now. Magnesium-rich foods — dark chocolate, pumpkin seeds, avocado — genuinely help."
        case 22:
            return p
                ? "Cravings will likely increase. They're hormonal, not a lack of willpower — nourish yourself without guilt."
                : "Carbohydrate cravings peak because serotonin dips with progesterone. Complex carbs stabilise both blood sugar and mood."
        case 23:
            return p
                ? "Energy dips become more pronounced. Protect your sleep and reduce high-intensity training."
                : "Your body is working hard beneath the surface. Swap intense workouts for yoga or walking — recovery is the real work now."
        case 24:
            return p
                ? "Emotional sensitivity heightens. Extra rest and boundary-setting will serve you well."
                : "Your amygdala is more reactive today. It's not you overreacting — it's biology. Name it, and give yourself more space."
        case 25:
            return p
                ? "Pre-menstrual phase deepens. Slow down, hydrate, and reduce commitments where possible."
                : "Inflammation can rise in the late luteal phase. Anti-inflammatory foods — turmeric, berries, oily fish — ease the approach to your period."
        case 26:
            return p
                ? "Fatigue and irritability may peak. Protect your evenings and communicate your needs clearly."
                : "You're in the final descent. Be gentle with yourself and honest with others about your capacity right now."
        case 27:
            return p
                ? "One or two days remain. Rest as much as possible and prepare your body for the reset ahead."
                : "Almost there. Your body is preparing to shed. Heat, rest, and solitude are the best gifts you can give yourself today."
        case 28:
            return p
                ? "Your cycle completes tomorrow. The rhythm continues — each cycle is data about your health."
                : "Cycle day 28 — the last page before a new chapter. Reflect on this month: what your body asked for, what you gave it."
        default:
            let phase = phase
            switch phase {
            case .menstrual:
                return p
                    ? "Your period is near. Rest and warmth are your allies."
                    : "Rest deeply. Your body is doing important work."
            case .follicular:
                return p
                    ? "Energy and clarity are building. Make space for bold ideas."
                    : "Estrogen is rising — your focus and creativity follow."
            case .ovulatory:
                return p ? "Peak energy approaches. Show up fully." : "You're at your most vital. Make it count."
            case .luteal:
                return p
                    ? "Turn inward. Nourish and protect your energy."
                    : "Slow down with intention. This phase rewards rest and reflection."
            case .late:
                return p
                    ? "Your period is later than expected. Your body may be adjusting — listen to what it needs."
                    : "A late cycle is your body asking for attention. Check in with yourself today."
            case nil:
                return
                    "Log your cycle start date to receive personalized AI-powered insights for every day of your cycle."
            }
        }
    }
}

// MARK: - Aria Insight Card

struct AriaInsightCard: View {
    let phase: CyclePhase?
    let cycleDay: Int?
    let isPredicted: Bool
    @State private var displayedText: String = ""
    @State private var animTask: Task<Void, Never>?

    private var fullInsight: String {
        AriaInsightText.insight(for: cycleDay, phase: phase, isPredicted: isPredicted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Aria")
                    .font(.custom("Raleway-Bold", size: 14))
                    .foregroundStyle(DesignColors.text)
                Spacer()
                Text(isPredicted ? "AI Prediction" : "AI Insight")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.5))
            }

            Text(displayedText.isEmpty ? " " : displayedText)
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundStyle(DesignColors.text.opacity(0.85))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if displayedText.count == fullInsight.count && !displayedText.isEmpty {
                Text("Powered by Aria · Personalized AI")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.45))
                    .transition(.opacity)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignColors.accentWarm.opacity(0.45),
                                    DesignColors.accentSecondary.opacity(0.2),
                                    Color.white.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .onAppear { startTypewriter() }
        .onChange(of: cycleDay) { _, _ in startTypewriter() }
        .onChange(of: isPredicted) { _, _ in startTypewriter() }
        .onDisappear {
            animTask?.cancel()
            animTask = nil
        }
    }

    private func startTypewriter() {
        animTask?.cancel()
        displayedText = ""
        let text = fullInsight
        animTask = Task { @MainActor in
            for char in text {
                guard !Task.isCancelled else { break }
                displayedText.append(char)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
}

// MARK: - Aria Prompt Overlay

struct AriaPromptOverlay: View {
    let message: String
    let onTalk: () -> Void
    let onDismiss: () -> Void

    @State private var displayedText: String = ""
    @State private var animTask: Task<Void, Never>?
    @State private var showButtons: Bool = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    // Aria avatar + header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DesignColors.accentWarm.opacity(0.8),
                                            DesignColors.accent.opacity(0.6),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aria noticed something")
                                .font(.custom("Raleway-Bold", size: 16))
                                .foregroundStyle(DesignColors.text)
                            Text("Your AI companion")
                                .font(.custom("Raleway-Regular", size: 12))
                                .foregroundStyle(DesignColors.textSecondary)
                        }

                        Spacer()

                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DesignColors.textSecondary.opacity(0.5))
                                .frame(width: 30, height: 30)
                                .background {
                                    Circle().fill(Color.white.opacity(0.08))
                                }
                        }
                        .buttonStyle(.plain)
                    }

                    // Typewriter message
                    Text(displayedText.isEmpty ? " " : displayedText)
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundStyle(DesignColors.text.opacity(0.9))
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Action buttons
                    if showButtons {
                        VStack(spacing: 10) {
                            Button {
                                onTalk()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Talk to Aria")
                                        .font(.custom("Raleway-Bold", size: 15))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [DesignColors.accentWarm, DesignColors.accent],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .shadow(color: DesignColors.accentWarm.opacity(0.4), radius: 12, x: 0, y: 4)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                onDismiss()
                            } label: {
                                Text("Maybe later")
                                    .font(.custom("Raleway-Medium", size: 14))
                                    .foregroundStyle(DesignColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(DesignColors.background.opacity(0.97))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            DesignColors.accentWarm.opacity(0.3),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                        }
                        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear { startTypewriter() }
        .onDisappear { animTask?.cancel() }
    }

    private func startTypewriter() {
        animTask?.cancel()
        displayedText = ""
        showButtons = false
        let text = message
        animTask = Task { @MainActor in
            for char in text {
                guard !Task.isCancelled else { break }
                displayedText.append(char)
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showButtons = true
            }
        }
    }
}
