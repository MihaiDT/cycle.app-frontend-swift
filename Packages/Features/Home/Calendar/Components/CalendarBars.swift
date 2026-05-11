import ComposableArchitecture
import SwiftUI

// MARK: - Edit Period Prediction Banner

struct EditPeriodPredictionBanner: View {
    let isUpdating: Bool
    let isDone: Bool
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if isDone {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .stroke(DesignColors.accentSecondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                        .scaleEffect(pulseScale)

                    Circle()
                        .stroke(DesignColors.accentWarm.opacity(0.2), lineWidth: 1)
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulseScale * 0.9)

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .frame(width: 36, height: 36)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isDone)

            VStack(alignment: .leading, spacing: 2) {
                Text(isDone ? "Predictions updated" : "Updating predictions")
                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
                    .contentTransition(.numericText())

                Text(isDone ? "Your calendar is up to date" : "Analyzing your cycle patterns...")
                    .font(.raleway("Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignColors.accent.opacity(0.15),
                                    DesignColors.roseTaupeLight.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignColors.accentSecondary.opacity(0.4),
                                    DesignColors.structure.opacity(0.2),
                                    DesignColors.accent.opacity(0.15),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
                .shadow(color: DesignColors.accentSecondary.opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .padding(.horizontal, 16)
        .onAppear {
            if !isDone {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }
        }
    }
}


