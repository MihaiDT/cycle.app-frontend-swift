import SwiftUI

// MARK: - Onboarding Header

public struct OnboardingHeader: View {
    public let currentStep: Int
    public let totalSteps: Int
    public let onBack: (() -> Void)?

    public init(
        currentStep: Int,
        totalSteps: Int,
        onBack: (() -> Void)? = nil
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
    }

    public var body: some View {
        HStack {
            if let onBack {
                GlassBackButton(action: onBack)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            Spacer()

            OnboardingProgressBar(currentStep: currentStep, totalSteps: totalSteps)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnboardingBackground()

        VStack {
            OnboardingHeader(currentStep: 2, totalSteps: 5, onBack: {})
            Spacer()
        }
        .padding(.top, 100)
    }
}
