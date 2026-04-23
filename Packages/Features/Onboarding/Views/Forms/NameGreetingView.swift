import SwiftUI
import UIKit

// MARK: - Name Greeting View

public struct NameGreetingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let name: String
    public let onContinue: () -> Void

    @State private var showContent = false
    @State private var showGlow = false
    @State private var glowBreathing = false
    @State private var glassReveal = false

    public init(
        name: String,
        onContinue: @escaping () -> Void
    ) {
        self.name = name
        self.onContinue = onContinue
    }

    public var body: some View {
        ZStack {
            OnboardingBackground()

            // Soft feminine glow - layered for depth
            ZStack {
                // Outer warm glow
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignColors.onboardingGlowOuterStart.opacity(0.4),
                                DesignColors.onboardingGlowOuterEnd.opacity(0.2),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 280)
                    .blur(radius: 50)
                    .opacity(showGlow ? 1 : 0)
                    .scaleEffect(glowBreathing ? 1.03 : 1.0)

                // Inner soft peach glow
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignColors.onboardingGlowInnerStart.opacity(0.5),
                                DesignColors.onboardingGlowInnerEnd.opacity(0.2),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 160)
                    .blur(radius: 30)
                    .opacity(showGlow ? 1 : 0)
                    .scaleEffect(glowBreathing ? 0.98 : 1.0)
            }
            .accessibilityHidden(true)

            // Content - centered
            VStack(spacing: 12) {
                // Greeting text
                Text("Nice to meet you,")
                    .font(.raleway("Regular", size: 18, relativeTo: .body))
                    .foregroundColor(DesignColors.text.opacity(0.7))
                    .opacity(showContent ? 1 : 0)
                    .blur(radius: showContent ? 0 : 8)

                // Name with liquid glass effect
                ZStack {
                    // Glass backdrop blur layer
                    Text(name)
                        .font(.raleway("SemiBold", size: 40, relativeTo: .largeTitle))
                        .foregroundColor(.white.opacity(0.3))
                        .blur(radius: glassReveal ? 0 : 20)
                        .scaleEffect(glassReveal ? 1 : 1.1)
                        .opacity(glassReveal ? 0 : 0.6)
                        .accessibilityHidden(true)

                    // Glass highlight layer
                    Text(name)
                        .font(.raleway("SemiBold", size: 40, relativeTo: .largeTitle))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.8),
                                    .white.opacity(0.2),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blur(radius: glassReveal ? 0 : 15)
                        .opacity(glassReveal ? 0 : 0.4)
                        .accessibilityHidden(true)

                    // Final text
                    Text(name)
                        .font(.raleway("SemiBold", size: 40, relativeTo: .largeTitle))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    DesignColors.text,
                                    DesignColors.accent,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(glassReveal ? 1 : 0)
                        .blur(radius: glassReveal ? 0 : 4)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            onContinue()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nice to meet you, \(name)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to continue")
        .onAppear {
            // Greeting fades in first
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) {
                showContent = true
            }

            // Liquid glass reveal for name
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1.0).delay(0.2)) {
                glassReveal = true
            }

            // Glow fades in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1.2).delay(0.4)) {
                showGlow = true
            }

            // Start subtle breathing - skip under reduceMotion
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(
                        .easeInOut(duration: 4.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        glowBreathing = true
                    }
                }
            }

            // Auto-continue — extend delay for VoiceOver so users have time to
            // hear the greeting and tap to continue on their own terms.
            let delay: TimeInterval = UIAccessibility.isVoiceOverRunning ? 8.0 : 2.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                onContinue()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NameGreetingView(name: "Denise") {}
}
