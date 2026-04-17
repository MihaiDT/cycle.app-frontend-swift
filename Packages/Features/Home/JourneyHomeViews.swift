import SwiftUI

// MARK: - Notifications Panel

public struct NotificationsPanel: View {
    let recapMonth: String?
    let onRecapTapped: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Notifications")
                .font(.raleway("Bold", size: 24, relativeTo: .title))
                .foregroundStyle(DesignColors.text)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Divider()
                .overlay(DesignColors.text.opacity(0.08))

            if recapMonth != nil || true {
                ScrollView {
                    VStack(spacing: 0) {
                        // Recap notification
                        if let month = recapMonth {
                            Button(action: onRecapTapped) {
                                HStack(spacing: 14) {
                                    // Aria avatar
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 40, height: 40)
                                        Text("A")
                                            .font(.raleway("Bold", size: 17, relativeTo: .headline))
                                            .foregroundStyle(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Aria")
                                                .font(.raleway("Bold", size: 15, relativeTo: .body))
                                                .foregroundStyle(DesignColors.accentWarm)
                                            Spacer()
                                            Text("New")
                                                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(DesignColors.accentWarm, in: Capsule())
                                        }
                                        Text("Your \(month) recap is ready")
                                            .font(.raleway("Medium", size: 15, relativeTo: .body))
                                            .foregroundStyle(DesignColors.text)
                                        Text("Tap to see what I found about your cycle")
                                            .font(.raleway("Regular", size: 13, relativeTo: .caption))
                                            .foregroundStyle(DesignColors.text.opacity(0.5))
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(DesignColors.text.opacity(0.3))
                                }
                                .padding(16)
                                .background(DesignColors.text.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }

                        // Empty state when no notifications
                        if recapMonth == nil {
                            VStack(spacing: 12) {
                                Image(systemName: "bell.slash")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(DesignColors.text.opacity(0.2))
                                Text("No new notifications")
                                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                                    .foregroundStyle(DesignColors.text.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Recap Ready Banner (Home Screen)

public struct RecapReadyBanner: View {
    let monthName: String?
    let onTap: () -> Void

    public init(monthName: String?, onTap: @escaping () -> Void) {
        self.monthName = monthName
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            if let month = monthName {
                Button(action: onTap) {
                    HStack(alignment: .top, spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            Text("A")
                                .font(.raleway("Bold", size: 14, relativeTo: .subheadline))
                                .foregroundStyle(.white)
                        }
                        .padding(.trailing, 10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Aria")
                                .font(.raleway("Bold", size: 12, relativeTo: .caption))
                                .foregroundStyle(DesignColors.accentWarm)

                            Text("Your \(month) recap is ready. Tap to see what I found about your cycle.")
                                .font(.raleway("Regular", size: 15, relativeTo: .body))
                                .foregroundStyle(DesignColors.text)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 4) {
                                Text("View Recap")
                                    .font(.raleway("SemiBold", size: 13, relativeTo: .caption))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(DesignColors.accentWarm)
                            .padding(.top, 2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(GlassCardModifier())
                    }
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Aria Recap Sheet

/// Bottom sheet with Aria typing effect for cycle recap notification.
public struct AriaRecapSheet: View {
    let monthName: String
    var message: String?
    var buttonTitle: String = "View Recap"
    var onAction: (() -> Void)?
    let onViewRecap: (() -> Void)?

    @State private var showTypingDots = true
    @State private var typedText = ""
    @State private var showButton = false

    private var fullMessage: String {
        message ?? "Your \(monthName) recap is ready. I found some interesting patterns about your cycle."
    }

    /// Recap convenience init
    public init(monthName: String, onViewRecap: @escaping () -> Void) {
        self.monthName = monthName
        self.onViewRecap = onViewRecap
    }

    /// Generic Aria sheet init
    public init(monthName: String, message: String, buttonTitle: String, onAction: @escaping () -> Void) {
        self.monthName = monthName
        self.message = message
        self.buttonTitle = buttonTitle
        self.onAction = onAction
        self.onViewRecap = nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Aria avatar + name
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Text("A")
                        .font(.raleway("Bold", size: 17, relativeTo: .headline))
                        .foregroundStyle(.white)
                }
                Text("Aria")
                    .font(.raleway("Bold", size: 20, relativeTo: .title2))
                    .foregroundStyle(DesignColors.accentWarm)
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Aria, your cycle assistant")

            // Typing dots or message
            if showTypingDots {
                TypingDotsView()
                    .transition(.opacity)
                    .accessibilityLabel("Aria is typing")
            } else {
                Text(typedText)
                    .font(.raleway("Medium", size: 18, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(6)
                    .transition(.opacity)
                    .accessibilityLabel(fullMessage)
            }

            // Action button
            if showButton {
                Button(action: { (onAction ?? onViewRecap)?() }) {
                    HStack(spacing: 8) {
                        Text(buttonTitle)
                            .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .accessibilityHint("Opens your cycle recap stories")
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(28)
        .task {
            // 1. Show typing dots for 1s
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // 2. Switch to typing effect
            withAnimation(.easeOut(duration: 0.2)) {
                showTypingDots = false
            }
            // 3. Type out message character by character
            for char in fullMessage {
                typedText.append(char)
                try? await Task.sleep(nanoseconds: 25_000_000) // 25ms per char
            }
            // 4. Show button with haptic
            try? await Task.sleep(nanoseconds: 300_000_000)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showButton = true
            }
        }
    }
}

/// Three animated dots indicating Aria is "typing"
private struct TypingDotsView: View {
    @State private var activeDot = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(DesignColors.accentWarm.opacity(activeDot == index ? 1.0 : 0.3))
                    .frame(width: 10, height: 10)
                    .scaleEffect(activeDot == index ? 1.3 : 1.0)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation(.easeInOut(duration: 0.3)) {
                    activeDot = (activeDot + 1) % 3
                }
            }
        }
    }
}

// MARK: - Journey Preview Section (Home Screen)

public struct JourneyPreviewSection: View {
    let cycleCount: Int
    let currentCycleNumber: Int
    let missedMonth: MissedMonth?
    let onTap: () -> Void

    public init(cycleCount: Int, currentCycleNumber: Int, missedMonth: MissedMonth? = nil, onTap: @escaping () -> Void) {
        self.cycleCount = cycleCount
        self.currentCycleNumber = currentCycleNumber
        self.missedMonth = missedMonth
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppLayout.spacingM) {
                HStack {
                    Text("Your Journey")
                        .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Cycle \(currentCycleNumber)")
                            .font(.raleway("Medium", size: 13, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignColors.textPlaceholder)
                    }
                }

                HStack(spacing: 6) {
                    ForEach(0..<min(cycleCount, 12), id: \.self) { i in
                        Circle()
                            .fill(i == cycleCount - 1
                                ? DesignColors.accentWarm
                                : DesignColors.structure)
                            .frame(width: 8, height: 8)
                            .overlay {
                                if i == cycleCount - 1 {
                                    Circle()
                                        .stroke(DesignColors.accentWarm.opacity(0.4), lineWidth: 2)
                                        .frame(width: 14, height: 14)
                                }
                            }
                    }
                    if cycleCount > 12 {
                        Text("...")
                            .font(.raleway("Medium", size: 12, relativeTo: .caption))
                            .foregroundStyle(DesignColors.textPlaceholder)
                    }
                    Spacer()
                }

                if let missed = missedMonth {
                    Text("\(missed.name) is missing — tap to complete your story")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.accentWarm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if cycleCount < 3 {
                    Text("\(3 - cycleCount) more cycles until your Blueprint")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if cycleCount < 6 {
                    Text("\(6 - cycleCount) more cycles until Patterns")
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppLayout.spacingL)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your Journey, Cycle \(currentCycleNumber)")
        .accessibilityHint("Double tap to view your cycle journey timeline")
    }
}

// MARK: - Journey Mandala

struct JourneyMandala: View {
    let summaries: [JourneyCycleSummary]
    let currentCycleProgress: CGFloat?
    let targetCycles: Int
    var onInsightsTapped: (() -> Void)?

    private var completedCount: Int { summaries.filter { !$0.isCurrentCycle }.count }
    private var totalTracked: Int { summaries.count }

    private var milestone: (name: String, icon: String, target: Int) {
        if completedCount < 3 { return ("Pattern Found", "sparkles", 3) }
        if completedCount < 6 { return ("Rhythm", "waveform.path", 6) }
        if completedCount < 12 { return ("Full Year", "sun.max.fill", 12) }
        return ("Full Year", "sun.max.fill", completedCount)
    }

    private let warmPalette: [Color] = DesignColors.journeyPalette

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(spacing: 2) {
                Text("\(totalTracked)")
                    .font(.raleway("Bold", size: 56, relativeTo: .largeTitle))
                    .foregroundStyle(DesignColors.text)

                Text(totalTracked == 1 ? "cycle" : "cycles")
                    .font(.raleway("Medium", size: 13, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(DesignColors.structure.opacity(0.12))
                .frame(width: 1, height: 60)

            VStack(alignment: .leading, spacing: 8) {
                if completedCount >= 3 {
                    let warmBrown = DesignColors.warmBrown
                    Button {
                        onInsightsTapped?()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Pattern Found")
                                .font(.raleway("Bold", size: 18, relativeTo: .headline))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(warmBrown)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 6) {
                    ForEach(0..<milestone.target, id: \.self) { i in
                        let isCompleted = i < completedCount
                        let isCurrent = i == completedCount && summaries.contains(where: \.isCurrentCycle)

                        Circle()
                            .fill(
                                isCompleted
                                    ? warmPalette[i % warmPalette.count]
                                    : isCurrent
                                        ? warmPalette[i % warmPalette.count].opacity(0.35)
                                        : DesignColors.journeyPaletteMuted.opacity(0.15)
                            )
                            .frame(width: 9, height: 9)
                    }
                }

                let remaining = milestone.target - completedCount
                if remaining > 0 {
                    Text("\(remaining) to \(milestone.name)")
                        .font(.raleway("Medium", size: 13, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, AppLayout.spacingL)
        .padding(.horizontal, AppLayout.spacingL)
        .modifier(GlassCardModifier())
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.bottom, AppLayout.spacingL)
    }
}
