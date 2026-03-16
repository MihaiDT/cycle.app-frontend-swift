import SwiftUI

// MARK: - Cycle Phase Banner

public struct CyclePhaseBanner: View {
    public let phase: String
    public let day: Int?

    public init(phase: String, day: Int? = nil) {
        self.phase = phase
        self.day = day
    }

    private var phaseIcon: String {
        switch phase.lowercased() {
        case "menstrual": "moon.stars"
        case "follicular": "leaf"
        case "ovulatory": "sun.max"
        case "luteal": "cloud.sun"
        default: "circle"
        }
    }

    private var phaseDisplayName: String {
        switch phase.lowercased() {
        case "menstrual": "Menstrual"
        case "follicular": "Follicular"
        case "ovulatory": "Ovulatory"
        case "luteal": "Luteal"
        default: phase.capitalized
        }
    }

    private var phaseInsight: String {
        switch phase.lowercased() {
        case "menstrual": "Rest and gentle movement are key during this phase."
        case "follicular": "Great time for new activities and challenges!"
        case "ovulatory": "You may feel more social and energetic."
        case "luteal": "Focus on self-care and gentle routines."
        default: ""
        }
    }

    public var body: some View {
        HStack(spacing: AppLayout.spacingM) {
            // Phase icon
            Image(systemName: phaseIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DesignColors.accentWarm)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(DesignColors.accent.opacity(0.3))
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(phaseDisplayName)
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundColor(DesignColors.text)

                    if let day {
                        Text("Day \(day)")
                            .font(.custom("Raleway-Medium", size: 13))
                            .foregroundColor(DesignColors.textSecondary)
                    }
                }

                Text(phaseInsight)
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundColor(DesignColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(AppLayout.spacingM)
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
            CyclePhaseBanner(phase: "follicular", day: 8)
            CyclePhaseBanner(phase: "ovulatory", day: 14)
            CyclePhaseBanner(phase: "luteal", day: 21)
            CyclePhaseBanner(phase: "menstrual", day: 2)
        }
        .padding(.horizontal, 32)
    }
}
