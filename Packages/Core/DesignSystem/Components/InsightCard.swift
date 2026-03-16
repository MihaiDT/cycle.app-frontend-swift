import SwiftUI

// MARK: - Insight Card

public struct InsightCard: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Vertical accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [DesignColors.accentWarm, DesignColors.accent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)

            Text(text)
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundColor(DesignColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppLayout.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()

        VStack(spacing: 12) {
            InsightCard(text: "Your wellness is trending up this week — great progress!")
            InsightCard(text: "Connect HealthKit for more accurate HBI scores.")
            InsightCard(text: "Sleep quality could improve — aim for 7-9 hours tonight.")
        }
        .padding(.horizontal, 32)
    }
}
