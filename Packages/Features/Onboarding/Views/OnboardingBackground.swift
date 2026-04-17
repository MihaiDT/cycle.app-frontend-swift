import SwiftUI

// MARK: - Onboarding Background

public struct OnboardingBackground: View {
    public init() {}

    public var body: some View {
        Image("SplashBackground")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview("Onboarding Background") {
    OnboardingBackground()
}
