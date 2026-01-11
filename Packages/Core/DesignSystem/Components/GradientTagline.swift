import SwiftUI

// MARK: - Gradient Tagline

public struct GradientTagline: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .tracking(2)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        DesignColors.gradientLight,
                        DesignColors.gradientMid,
                        DesignColors.gradientDark,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

#Preview("Gradient Tagline") {
    ZStack {
        LinearGradient(
            colors: [.white, Color(red: 0.85, green: 0.75, blue: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GradientTagline("Your rhythm, decoded")
    }
}
