import SwiftUI

// MARK: - Glass Logo Card

public struct GlassLogoCard: View {
    private let cardSize: CGFloat
    private let cornerRadius: CGFloat

    public init(cardSize: CGFloat = 140, cornerRadius: CGFloat = 30) {
        self.cardSize = cardSize
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        ZStack {
            // Logo
            Image("SLLogo")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.white.opacity(0.9))
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 112)
                .accessibilityHidden(true)
        }
        .frame(width: cardSize, height: cardSize)
        .glassEffect(cornerRadius: cornerRadius)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cycle app logo")
    }
}

#Preview("Glass Card") {
    ZStack {
        LinearGradient(
            colors: [.white, DesignColors.onboardingPreviewTint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassLogoCard()
    }
}
