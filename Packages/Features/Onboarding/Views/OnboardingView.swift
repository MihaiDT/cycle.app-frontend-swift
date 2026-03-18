import Inject
import SwiftUI

// MARK: - Onboarding View (Marketing Screen)

public struct OnboardingView: View {
    @ObserveInjection var inject
    public let onBegin: () -> Void
    public let onLogin: () -> Void

    @State private var showBadge = false
    @State private var showHeadline = false
    @State private var showSubtitle = false
    @State private var showCarousel = false
    @State private var showButton = false

    public init(onBegin: @escaping () -> Void, onLogin: @escaping () -> Void) {
        self.onBegin = onBegin
        self.onLogin = onLogin
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                OnboardingBackground()

                VStack(spacing: 0) {
                    Spacer()

                    // Badge pill
                    Text("Built for Her")
                        .font(.custom("Raleway-SemiBold", size: 13))
                        .tracking(1)
                        .foregroundStyle(DesignColors.accentWarm)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .glassEffectCapsule()
                        .opacity(showBadge ? 1 : 0)
                        .offset(y: showBadge ? 0 : 10)

                    VerticalSpace(24)

                    // Headline with gradient
                    Text("Your Cycle,\nYour Power.")
                        .font(.custom("Raleway-Bold", size: 38))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    DesignColors.text,
                                    DesignColors.textPrincipal,
                                    DesignColors.accentWarm,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(showHeadline ? 1 : 0)
                        .offset(y: showHeadline ? 0 : 16)

                    VerticalSpace(14)

                    // Subtitle with mixed weight
                    (Text("Insights for ")
                        .foregroundStyle(DesignColors.textSecondary)
                        + Text("deeper clarity")
                        .foregroundStyle(DesignColors.textPrincipal)
                        + Text(",\n")
                        .foregroundStyle(DesignColors.textSecondary)
                        + Text("lasting wellness")
                        .foregroundStyle(DesignColors.textPrincipal)
                        + Text(", and ")
                        .foregroundStyle(DesignColors.textSecondary)
                        + Text("real balance")
                        .foregroundStyle(DesignColors.textPrincipal))
                        .font(.custom("Raleway-Regular", size: 16))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 12)

                    VerticalSpace(36)

                    // Three carousel rows
                    VStack(spacing: 10) {
                        InfiniteCarouselRow(
                            chips: [
                                ("waveform.path.ecg", "Cycle Tracking"),
                                ("brain.head.profile", "AI Insights"),
                                ("heart.text.clipboard", "Health Sync"),
                                ("leaf", "Self-Care Rituals"),
                            ],
                            duration: 22,
                            direction: .left
                        )

                        InfiniteCarouselRow(
                            chips: [
                                ("moon.stars", "Mood & Energy"),
                                ("chart.line.uptrend.xyaxis", "Predictions"),
                                ("bell.badge", "Smart Reminders"),
                                ("sparkles", "Personalized"),
                            ],
                            duration: 26,
                            direction: .right
                        )

                        InfiniteCarouselRow(
                            chips: [
                                ("figure.walk", "Activity"),
                                ("drop.fill", "Flow Log"),
                                ("calendar", "Calendar"),
                                ("person.2", "Community"),
                            ],
                            duration: 20,
                            direction: .left
                        )
                    }
                    .opacity(showCarousel ? 1 : 0)

                    Spacer()

                    // CTA button — circle slides right as progress fill
                    OnboardingCTAButton(title: "Get Started", action: onBegin)
                        .opacity(showButton ? 1 : 0)
                        .scaleEffect(showButton ? 1 : 0.9)

                    Spacer().frame(height: 16)

                    // Login link for returning users
                    Button(action: onLogin) {
                        (Text("Already have an account? ")
                            .foregroundStyle(DesignColors.textSecondary)
                            + Text("Log in")
                            .foregroundStyle(DesignColors.accentWarm)
                            .fontWeight(.semibold))
                            .font(.custom("Raleway-Regular", size: 14))
                    }
                    .buttonStyle(.plain)
                    .opacity(showButton ? 1 : 0)

                    Spacer().frame(height: geometry.safeAreaInsets.bottom + AppLayout.bottomOffset)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear { startEntranceAnimation() }
        .enableInjection()
    }

    private func startEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.6)) {
            showBadge = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.2)) {
            showHeadline = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            showSubtitle = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
            showCarousel = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(1.1)) {
            showButton = true
        }
    }
}

// MARK: - Onboarding CTA Button

struct OnboardingCTAButton: View {
    let title: String
    let action: () -> Void

    private let buttonWidth: CGFloat = 260
    private let buttonHeight: CGFloat = 56
    private let circleSize: CGFloat = 46
    private let inset: CGFloat = 5

    @State private var completed = false
    @State private var dragOffset: CGFloat = 0

    private var maxTravel: CGFloat {
        buttonWidth - circleSize - inset * 2
    }

    private var progress: CGFloat {
        guard maxTravel > 0 else { return 0 }
        return min(max(dragOffset / maxTravel, 0), 1)
    }

    private var titleOpacity: Double {
        Swift.max(0, 1 - progress * 2.5)
    }

    private var circleX: CGFloat {
        inset + maxTravel * progress
    }

    /// How far (0-1) the user must drag to trigger the action
    private let threshold: CGFloat = 0.85

    var body: some View {
        ZStack(alignment: .leading) {
            // Glass track
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    DesignColors.accent.opacity(0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }

            // Snail trail — hidden behind circle at rest, expands with it
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignColors.accent.opacity(0.15),
                            DesignColors.accent.opacity(0.4),
                            DesignColors.accentSecondary.opacity(0.7),
                            DesignColors.accentWarm.opacity(0.9),
                            DesignColors.accentWarm,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: circleX + circleSize + inset)
                .frame(height: buttonHeight)
                .opacity(progress > 0 ? 1 : 0)

            // Title
            Text(title)
                .font(Font.custom("Raleway-SemiBold", size: 17))
                .foregroundStyle(DesignColors.text)
                .frame(maxWidth: .infinity)
                .padding(.leading, circleSize + inset)
                .opacity(titleOpacity)

            // Draggable circle with arrow
            Circle()
                .fill(DesignColors.accentWarm)
                .frame(width: circleSize, height: circleSize)
                .overlay {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .offset(x: circleX)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !completed else { return }
                            dragOffset = max(0, min(value.translation.width, maxTravel))
                        }
                        .onEnded { _ in
                            guard !completed else { return }
                            if progress >= threshold {
                                completed = true
                                withAnimation(.easeOut(duration: 0.25)) {
                                    dragOffset = maxTravel
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    action()
                                }
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
        }
        .frame(width: buttonWidth, height: buttonHeight)
        .clipShape(Capsule())
        .contentShape(Capsule())
    }
}

// MARK: - Floating Particles

private struct FloatingParticles: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    let size = CGFloat([3, 4, 5, 6, 4, 3, 5, 4, 6, 3, 5, 4][i])
                    let xFrac = CGFloat([13, 72, 45, 88, 31, 60, 8, 52, 95, 25, 78, 40][i]) / 100.0
                    let yFrac = CGFloat([20, 55, 75, 35, 90, 12, 65, 42, 80, 50, 28, 68][i]) / 100.0
                    let opacity = [0.1, 0.15, 0.08, 0.12, 0.18, 0.1, 0.14, 0.09, 0.16, 0.11, 0.13, 0.08][i]

                    Circle()
                        .fill(DesignColors.accentWarm.opacity(opacity))
                        .frame(width: size, height: size)
                        .position(
                            x: xFrac * geo.size.width,
                            y: animate
                                ? yFrac * geo.size.height - 60
                                : yFrac * geo.size.height + 60
                        )
                }
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                    .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Infinite Carousel Row

private struct InfiniteCarouselRow: View {
    let chips: [(icon: String, text: String)]
    let duration: Double
    let direction: Direction

    enum Direction {
        case left, right
    }

    @State private var setWidth: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var measured = false

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { batch in
                    HStack(spacing: 10) {
                        ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                            FeatureChip(icon: chip.icon, text: chip.text)
                        }
                    }
                    .background {
                        if batch == 0 {
                            GeometryReader { geo in
                                Color.clear.onAppear {
                                    guard !measured else { return }
                                    measured = true
                                    let w = geo.size.width + 10
                                    setWidth = w
                                    // For .right: start at -setWidth so content is visible
                                    // For .left: start at 0
                                    xOffset = direction == .right ? -w : 0
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        startAnimation(setWidth: w)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .fixedSize()
            .offset(x: xOffset)
        }
        .frame(height: 40)
        .clipped()
    }

    private func startAnimation(setWidth: CGFloat) {
        // .left:  0 → -setWidth (scrolls left, resets seamlessly)
        // .right: -setWidth → 0 (scrolls right, resets seamlessly)
        let target = direction == .left ? -setWidth : 0
        withAnimation(
            .linear(duration: duration)
                .repeatForever(autoreverses: false)
        ) {
            xOffset = target
        }
    }
}

// MARK: - Feature Chip

private struct FeatureChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignColors.accentWarm)

            Text(text)
                .font(.custom("Raleway-Medium", size: 13))
                .foregroundStyle(DesignColors.text.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .fixedSize()
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.45),
                                    DesignColors.accent.opacity(0.15),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(onBegin: {}, onLogin: {})
}
