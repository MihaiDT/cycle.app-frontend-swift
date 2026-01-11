import SwiftUI

// MARK: - Onboarding Layout

public struct OnboardingLayout<Content: View>: View {
    public let currentStep: Int
    public let totalSteps: Int
    public let onBack: (() -> Void)?
    public let onNext: () -> Void
    public let nextButtonEnabled: Bool
    public let content: Content

    public init(
        currentStep: Int,
        totalSteps: Int,
        onBack: (() -> Void)? = nil,
        onNext: @escaping () -> Void,
        nextButtonEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onNext = onNext
        self.nextButtonEnabled = nextButtonEnabled
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                OnboardingBackground()

                VStack(spacing: 0) {
                    // Header
                    Spacer().frame(height: geometry.safeAreaInsets.top + 16)

                    OnboardingHeader(
                        currentStep: currentStep,
                        totalSteps: totalSteps,
                        onBack: onBack
                    )

                    // Content
                    Spacer()

                    content

                    Spacer()

                    // Footer
                    GlassButton.next(action: onNext)
                        .opacity(nextButtonEnabled ? 1 : 0.5)
                        .disabled(!nextButtonEnabled)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + AppLayout.bottomOffset)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingLayout(
        currentStep: 2,
        totalSteps: 5,
        onBack: {},
        onNext: {},
        nextButtonEnabled: true
    ) {
        VStack(spacing: 24) {
            Text("Content goes here")
                .font(.custom("Raleway-Bold", size: 24))
                .foregroundColor(DesignColors.text)
        }
    }
}
