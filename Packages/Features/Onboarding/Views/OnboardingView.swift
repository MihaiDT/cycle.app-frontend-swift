import SwiftUI

// MARK: - Onboarding View (Begin Screen)

public struct OnboardingView: View {
    public let onBegin: () -> Void

    public init(onBegin: @escaping () -> Void) {
        self.onBegin = onBegin
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                OnboardingBackground()

                VStack(spacing: 0) {
                    VerticalSpace(geometry.safeAreaInsets.top + 120)

                    // Logo with gradient
                    Image("LogoGradient")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 139, height: 217)

                    VerticalSpace.xl

                    // Tagline with gradient text
                    GradientTagline("Your rhythm, decoded")

                    Spacer()

                    // Begin button
                    GlassButton.begin(action: onBegin)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + AppLayout.bottomOffset)
                }
            }
            .ignoresSafeArea()
        }
    }
}

#Preview("Onboarding") {
    OnboardingView {}
}
