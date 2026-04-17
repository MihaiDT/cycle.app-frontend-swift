import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - Cycle Story Walkthrough

struct CycleStoryView: View {
    let stats: CycleStatsDetailedResponse
    let onClose: () -> Void

    @State private var currentStep = 0
    @State private var stepVisible = false
    @State private var tooltipVisible = false
    @State private var numberValue: Double = 0
    @State private var dotsRevealed = 0
    @State private var isTransitioning = false
    @State private var showNavHint = true

    private let totalSteps = 5

    private var history: [CycleHistoryPoint] { stats.cycleLength.history }
    private var avg: Double { stats.cycleLength.average }
    private var stdDev: Double { stats.cycleLength.stdDev }

    private var rhythm: (title: String, icon: String, desc: String, color: Color) {
        if stdDev >= 5 {
            return ("Dynamic Rhythm", "wind", "Your cycle adapts and shifts — your body is responsive to life changes.", DesignColors.accentWarm)
        }
        switch Int(avg) {
        case ...24:
            return ("Quick Rhythm", "hare", "You move through phases faster — intense bursts of rising energy.", CyclePhase.ovulatory.orbitColor)
        case 25...28:
            return ("Steady Rhythm", "metronome", "Your cycle is reliable. You can trust your energy patterns week to week.", DesignColors.accentSecondary)
        case 29...32:
            return ("Long Wave", "water.waves", "Extended follicular phase — more days of rising creativity before ovulation.", DesignColors.accent)
        default:
            return ("Deep Rhythm", "tortoise", "Your body takes its time. Gradual hormonal shifts give you extended building phases.", CyclePhase.luteal.orbitColor)
        }
    }

    var body: some View {
        ZStack {
            DesignColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DesignColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle().fill(DesignColors.structure.opacity(0.1))
                            }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Progress dots
                    HStack(spacing: 6) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Capsule()
                                .fill(i <= currentStep ? DesignColors.accentSecondary : DesignColors.structure.opacity(0.15))
                                .frame(width: i == currentStep ? 20 : 8, height: 4)
                                .animation(.appBalanced, value: currentStep)
                        }
                    }

                    Spacer()

                    // Step counter
                    Text("\(currentStep + 1)/\(totalSteps)")
                        .font(.custom("Raleway-Medium", size: 13, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textPlaceholder)
                        .frame(width: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Step content — keyed so SwiftUI replaces instead of overlapping
                Group {
                    switch currentStep {
                    case 0: stepIntro
                    case 1: stepRhythm
                    case 2: stepNumbers
                    case 3: stepNormalVsAtypical
                    case 4: stepKeyInsight
                    default: EmptyView()
                    }
                }
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeIn(duration: 0.25).delay(0.15)),
                    removal: .opacity.animation(.easeOut(duration: 0.12))
                ))
                .padding(.horizontal, 28)

                Spacer()

                // Bottom action
                if currentStep == totalSteps - 1 {
                    Button(action: onClose) {
                        Text("Got it")
                            .font(.custom("Raleway-Bold", size: 17, relativeTo: .body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                Capsule()
                                    .fill(DesignColors.accentSecondary)
                                    .shadow(color: DesignColors.accentSecondary.opacity(0.3), radius: 12, x: 0, y: 4)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.appBalanced, value: currentStep)
                }

                Spacer().frame(height: 40)
            }
        }
        .overlay(alignment: .bottom) {
            // Tap zones — hidden on last step so "Got it" button is tappable
            if currentStep < totalSteps - 1 {
                VStack(spacing: 0) {
                    Spacer().frame(height: 70)
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { goBackStep() }

                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { advanceStep() }
                    }
            }
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { drag in
                        if drag.translation.width < -40 {
                            advanceStep()
                        } else if drag.translation.width > 40 {
                            goBackStep()
                        }
                    }
            )
            }
        }
        .overlay {
            if showNavHint {
                navHintOverlay
                    .transition(.opacity)
            }
        }
        .onAppear {
            showCurrentStep()
        }
    }

    // MARK: Step Navigation

    private func advanceStep() {
        guard currentStep < totalSteps - 1, !isTransitioning else { return }
        navigateTo(currentStep + 1)
    }

    private func goBackStep() {
        guard currentStep > 0, !isTransitioning else { return }
        navigateTo(currentStep - 1)
    }

    private func navigateTo(_ step: Int) {
        isTransitioning = true
        currentStep = step
        showCurrentStep()
        // Debounce — allow next tap after content settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isTransitioning = false
        }
    }

    private func showCurrentStep() {
        stepVisible = false
        tooltipVisible = false
        numberValue = 0
        dotsRevealed = 0

        withAnimation(.appReveal.delay(0.1)) {
            stepVisible = true
        }
        withAnimation(Animation.appBalanced.delay(0.6)) {
            tooltipVisible = true
        }

        // Step-specific animations
        if currentStep == 2 {
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                numberValue = avg
            }
        }
        if currentStep == 3 {
            for i in 0..<history.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dotsRevealed = i + 1
                    }
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred()
                }
            }
        }
    }

    // MARK: Navigation Hint

    @State private var fingerX: CGFloat = 40
    @State private var trailFrom: CGFloat = 40
    @State private var showTrail = false

    @ViewBuilder
    private var navHintOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            // Trail — single gradient capsule stretching behind finger
            if showTrail {
                let leading = min(fingerX, trailFrom)
                let trailing = max(fingerX, trailFrom)
                let width = max(trailing - leading, 6)
                let mid = (leading + trailing) / 2
                let movingRight = fingerX > trailFrom

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: movingRight
                                ? [.white.opacity(0), .white.opacity(0.35)]
                                : [.white.opacity(0.35), .white.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: 6)
                    .offset(x: mid, y: 20)
            }

            // Finger
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .offset(x: fingerX, y: 20)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.25)) {
                showNavHint = false
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))

            // Swipe left
            trailFrom = 40
            showTrail = true
            withAnimation(.easeInOut(duration: 0.6)) {
                fingerX = -60
            }
            try? await Task.sleep(for: .milliseconds(700))
            showTrail = false

            try? await Task.sleep(for: .milliseconds(200))

            // Swipe right
            trailFrom = -60
            showTrail = true
            withAnimation(.easeInOut(duration: 0.6)) {
                fingerX = 60
            }
            try? await Task.sleep(for: .milliseconds(700))
            showTrail = false

            try? await Task.sleep(for: .milliseconds(300))

            withAnimation(.easeOut(duration: 0.4)) {
                showNavHint = false
            }
        }
    }

    // MARK: Step 0 — Intro

    private var stepIntro: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text("Let me read\nyour cycle")
                    .font(.custom("Raleway-Bold", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.center)

                Text("Your body has been speaking through \(history.count) cycles. Here's what it's telling you.")
                    .font(.custom("Raleway-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(stepVisible ? 1 : 0)
        }
    }

    // MARK: Step 1 — Your Rhythm

    private var stepRhythm: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(rhythm.color.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(stepVisible ? 1 : 0)

                Image(systemName: rhythm.icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(rhythm.color)
                    .scaleEffect(stepVisible ? 1 : 0.2)
                    .opacity(stepVisible ? 1 : 0)
            }

            VStack(spacing: 14) {
                Text(rhythm.title)
                    .font(.custom("Raleway-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)

                if tooltipVisible {
                    storyTooltip(rhythm.desc)
                        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                }
            }
            .offset(y: stepVisible ? 0 : 16)
            .opacity(stepVisible ? 1 : 0)
        }
    }

    // MARK: Step 2 — Your Inner Clock

    private var stepNumbers: some View {
        VStack(spacing: 36) {
            VStack(spacing: 4) {
                Text("\(Int(numberValue))")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignColors.text)
                    .contentTransition(.numericText(value: numberValue))
                    .animation(.easeOut(duration: 0.8), value: numberValue)

                Text("days — your inner clock")
                    .font(.custom("Raleway-Medium", size: 18, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
            }
            .scaleEffect(stepVisible ? 1 : 0.8)
            .opacity(stepVisible ? 1 : 0)

            if tooltipVisible {
                HStack(spacing: 16) {
                    miniStat(label: "Shortest", value: "\(stats.cycleLength.min)d", delay: 0)
                    miniStat(label: "Longest", value: "\(stats.cycleLength.max)d", delay: 0.1)
                    miniStat(label: "Variation", value: "±\(Int(stdDev.rounded()))d", delay: 0.2)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: Step 3 — Your Pattern

    private var stepNormalVsAtypical: some View {
        let steadyCount = history.filter { $0.length >= 24 && $0.length <= 32 }.count
        let shiftedCount = history.count - steadyCount

        return VStack(spacing: 28) {
            HStack(spacing: 8) {
                ForEach(Array(history.enumerated()), id: \.offset) { i, point in
                    let steady = point.length >= 24 && point.length <= 32
                    VStack(spacing: 6) {
                        if steady {
                            Circle()
                                .fill(DesignColors.accentSecondary)
                                .frame(width: 14, height: 14)
                        } else {
                            Circle()
                                .strokeBorder(DesignColors.text, lineWidth: 2)
                                .frame(width: 14, height: 14)
                        }
                        Text("\(point.length)")
                            .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                            .foregroundStyle(steady ? DesignColors.textSecondary : DesignColors.text)
                    }
                    .scaleEffect(i < dotsRevealed ? 1 : 0)
                    .opacity(i < dotsRevealed ? 1 : 0)
                }
            }
            .offset(y: stepVisible ? 0 : 12)

            VStack(spacing: 14) {
                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Circle().fill(DesignColors.accentSecondary).frame(width: 10, height: 10)
                        Text("\(steadyCount) Steady")
                            .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                            .foregroundStyle(DesignColors.text)
                    }
                    HStack(spacing: 8) {
                        Circle().strokeBorder(DesignColors.text, lineWidth: 2).frame(width: 10, height: 10)
                        Text("\(shiftedCount) Shifted")
                            .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                            .foregroundStyle(DesignColors.text)
                    }
                }
                .opacity(stepVisible ? 1 : 0)

                if tooltipVisible {
                    storyTooltip(
                        shiftedCount == 0
                            ? "Every cycle stayed in rhythm. Your body holds a steady beat — that's rare and powerful."
                            : "\(shiftedCount) cycles shifted outside your usual rhythm. That's your body responding to life — stress, travel, change. It's not broken, it's adaptive."
                    )
                    .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Step 4 — Your Phases

    private var stepKeyInsight: some View {
        let avgBleeding = history.isEmpty ? 5 : history.map(\.bleeding).reduce(0, +) / history.count
        let follicularDays = CyclePhase.follicular.dayRange(cycleLength: Int(avg), bleedingDays: avgBleeding)
        let follicularCount = follicularDays.upperBound - follicularDays.lowerBound + 1
        let ovDays = CyclePhase.ovulatory.dayRange(cycleLength: Int(avg), bleedingDays: avgBleeding)

        return VStack(spacing: 28) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DesignColors.accent)
                .scaleEffect(stepVisible ? 1 : 0.3)
                .opacity(stepVisible ? 1 : 0)

            VStack(spacing: 16) {
                Text("Your phases")
                    .font(.custom("Raleway-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)
                    .opacity(stepVisible ? 1 : 0)

                if tooltipVisible {
                    VStack(spacing: 14) {
                        insightBubble(
                            icon: CyclePhase.follicular.icon,
                            tint: CyclePhase.follicular.orbitColor,
                            text: "\(follicularCount) follicular days — your energy rises"
                        )

                        insightBubble(
                            icon: CyclePhase.ovulatory.icon,
                            tint: CyclePhase.ovulatory.orbitColor,
                            text: "Ovulation peaks around day \(ovDays.lowerBound)"
                        )

                        insightBubble(
                            icon: CyclePhase.luteal.icon,
                            tint: CyclePhase.luteal.orbitColor,
                            text: "Luteal phase brings clarity and reflection"
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Reusable Components

    private func storyTooltip(_ text: String) -> some View {
        Text(text)
            .font(.custom("Raleway-Regular", size: 16, relativeTo: .body))
            .foregroundStyle(DesignColors.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DesignColors.structure.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(DesignColors.structure.opacity(0.1), lineWidth: 0.5)
                    }
            }
    }

    private func miniStat(label: String, value: String, delay: Double) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.custom("Raleway-Bold", size: 20, relativeTo: .title3))
                .foregroundStyle(DesignColors.text)
            Text(label)
                .font(.custom("Raleway-Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPlaceholder)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignColors.structure.opacity(0.06))
        }
    }

    private func insightBubble(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(text)
                .font(.custom("Raleway-Medium", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignColors.structure.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}
