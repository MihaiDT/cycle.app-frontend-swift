import SwiftUI

struct ChallengeInProgressBanner: View {
    let challengeTitle: String
    let challengeCategory: String
    let timerStartDate: Date
    let timerEndDate: Date
    let onDone: () -> Void

    var body: some View {
        let isExpired = timerEndDate < Date()

        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if isExpired {
                    Text("Time's up")
                        .font(.custom("Raleway-Black", size: 20, relativeTo: .title))
                        .foregroundStyle(.white)
                } else {
                    Text(timerEndDate, style: .timer)
                        .font(.custom("Raleway-Black", size: 24, relativeTo: .title))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("cycle")
                        .font(.custom("Raleway-Black", size: 9, relativeTo: .caption))
                        .foregroundStyle(DesignColors.accentWarm)
                    Text(challengeTitle)
                        .font(.custom("Raleway-SemiBold", size: 12, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            if !isExpired {
                ProgressView(
                    timerInterval: timerStartDate...timerEndDate,
                    countsDown: true
                )
                .progressViewStyle(.linear)
                .tint(DesignColors.accentWarm)
                .labelsHidden()
                .accessibilityHidden(true)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDone()
            } label: {
                Text(isExpired ? "Log your moment" : "I'm done")
                    .font(.custom("Raleway-Bold", size: 13, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignColors.accentWarm)
                    )
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpired ? "Log your moment" : "I'm done")
            .accessibilityHint(
                isExpired
                    ? "Opens the photo capture step for your challenge"
                    : "Ends the challenge timer and starts photo capture"
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                .fill(DesignColors.text.opacity(0.85))
        )
        .padding(.horizontal, AppLayout.horizontalPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(bannerAccessibilityLabel(isExpired: isExpired))
    }

    private func bannerAccessibilityLabel(isExpired: Bool) -> String {
        if isExpired {
            return "\(challengeTitle), challenge time is up"
        }
        return "\(challengeTitle), challenge in progress"
    }

    private var categoryIcon: String {
        switch challengeCategory.lowercased() {
        case "movement": return "figure.walk"
        case "mindfulness": return "brain.head.profile"
        case "self_care": return "heart.fill"
        case "creative": return "paintbrush.fill"
        case "nutrition": return "leaf.fill"
        case "social": return "person.2.fill"
        default: return "star.fill"
        }
    }
}
