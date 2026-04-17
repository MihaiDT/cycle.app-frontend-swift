import SwiftUI

// MARK: - Onboarding Progress Bar

/// A progress bar for onboarding screens showing current step out of total steps.
/// Uses Figma design: 8pt height, pill shape, cream background, cocoa fill.
public struct OnboardingProgressBar: View {
    public let currentStep: Int
    public let totalSteps: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(currentStep: Int, totalSteps: Int) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
    }

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(currentStep) / CGFloat(totalSteps)
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // Background - light cream (full width)
            Capsule()
                .fill(Color(red: 0.95, green: 0.93, blue: 0.92))

            // Fill - gradient that darkens as it grows
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignColors.accent,
                            DesignColors.accentSecondary,
                            DesignColors.accentWarm,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 180 * progress)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: progress)
        }
        .frame(width: 180, height: 8)
        .accessibilityElement()
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(currentStep) of \(totalSteps)")
    }
}

#Preview("Progress Bar - Step 1/3") {
    OnboardingProgressBar(currentStep: 1, totalSteps: 3)
        .padding(32)
        .background(Color(hex: 0xEFE1DC))
}

#Preview("Progress Bar - Step 2/3") {
    OnboardingProgressBar(currentStep: 2, totalSteps: 3)
        .padding(32)
        .background(Color(hex: 0xEFE1DC))
}

#Preview("Progress Bar - Step 3/3") {
    OnboardingProgressBar(currentStep: 3, totalSteps: 3)
        .padding(32)
        .background(Color(hex: 0xEFE1DC))
}
