import SwiftUI

// MARK: - Daily Challenge Card View

struct DailyChallengeCardView: View {
    let challenge: ChallengeSnapshot
    let onDoIt: () -> Void
    let onSkip: () -> Void
    let onMaybeLater: () -> Void

    var body: some View {
        switch challenge.status {
        case .available, .skipped: availableState
        case .completed: completedState
        }
    }

    // MARK: - Available

    private var availableState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Challenge")
                    .font(.custom("Raleway-SemiBold", size: 12, relativeTo: .caption))
                    .tracking(0.2)
            }
            .foregroundStyle(DesignColors.accentWarm)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { Capsule().fill(DesignColors.accentWarm.opacity(0.12)) }
            .accessibilityLabel("Challenge")

            Text(challenge.challengeTitle)
                .font(.custom("Raleway-Bold", size: 22, relativeTo: .title2))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .lineSpacing(2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: DesignColors.background.opacity(0.75), radius: 4, x: 0, y: 0)
                .accessibilityAddTraits(.isHeader)

            Text(challenge.challengeDescription)
                .font(.custom("Raleway-Medium", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .lineSpacing(3)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: DesignColors.background.opacity(0.6), radius: 3, x: 0, y: 0)

            HStack(spacing: 6) {
                tagPill(challenge.cyclePhase.capitalized)
                tagPill(challenge.durationDisplay)
                tagPill(challenge.effortDisplay)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(challenge.cyclePhase.capitalized), " +
                "\(challenge.durationDisplay), " +
                "\(challenge.effortDisplay)"
            )

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDoIt()
            } label: {
                Text("I'm in")
                    .font(.custom("Raleway-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignColors.accentWarm)
                    }
                    .shadow(color: DesignColors.text.opacity(0.30), radius: 12, x: 0, y: 5)
                    .shadow(color: DesignColors.text.opacity(0.14), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Do challenge")
            .accessibilityHint("Opens the challenge detail screen")
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 340)
        .glowCardBackground(tint: .cocoa)
    }

    // MARK: - Completed

    private var completedState: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 12) {
                if let thumbData = challenge.photoThumbnail,
                   let uiImage = UIImage(data: thumbData)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let rating = challenge.validationRating {
                        RatingBadge(rating: rating, size: 24)
                    }
                    Text("+\(challenge.xpEarned) XP")
                        .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .callout))
                        .foregroundStyle(DesignColors.accentWarm)
                }
            }

            Spacer()

            if let feedback = challenge.validationFeedback {
                Text(feedback)
                    .font(.custom("Raleway-Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(4)
                    .lineLimit(3)
            }

            Text(challenge.challengeTitle)
                .font(.custom("Raleway-Regular", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .padding(28)
        .frame(height: 340)
        .glowCardBackground(tint: .cocoa)
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("Raleway-SemiBold", size: 11, relativeTo: .caption))
            .foregroundStyle(DesignColors.textPrincipal)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background { Capsule().fill(DesignColors.text.opacity(0.06)) }
    }
}

// `glowCardBackground()` moved to DesignSystem/Components/GlowCardBackground.swift
