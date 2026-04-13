import SwiftUI

// MARK: - Daily Challenge Card View

struct DailyChallengeCardView: View {
    let challenge: ChallengeSnapshot
    let onDoIt: () -> Void
    let onSkip: () -> Void
    let onMaybeLater: () -> Void

    var body: some View {
        switch challenge.status {
        case .available: availableState
        case .completed: completedState
        case .skipped: skippedState
        }
    }

    // MARK: - Available

    private var availableState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Challenge")
                    .font(.custom("Raleway-SemiBold", size: 12))
            }
            .foregroundStyle(DesignColors.accentWarm)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { Capsule().fill(DesignColors.accentWarm.opacity(0.1)) }

            Spacer(minLength: 12)

            Text(challenge.challengeTitle)
                .font(.custom("Raleway-Bold", size: 24))
                .foregroundStyle(DesignColors.text)
                .lineSpacing(2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(challenge.challengeDescription)
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(3)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                tagPill(challenge.cyclePhase.capitalized)
                tagPill(challenge.durationDisplay)
                tagPill(challenge.effortDisplay)
            }
            .padding(.top, 2)

            Spacer().frame(height: 14)

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDoIt()
                } label: {
                    Text("Do It")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        }
                }
                .buttonStyle(.plain)

                Button { onSkip() } label: {
                    Text("Skip")
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(height: 380)
        .glowCardBackground()
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
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let rating = challenge.validationRating {
                        RatingBadge(rating: rating, size: 24)
                    }
                    Text("+\(challenge.xpEarned) XP")
                        .font(.custom("Raleway-SemiBold", size: 14))
                        .foregroundStyle(DesignColors.accentWarm)
                }
            }

            Spacer()

            if let feedback = challenge.validationFeedback {
                Text(feedback)
                    .font(.custom("Raleway-Medium", size: 16))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(4)
                    .lineLimit(3)
            }

            Text(challenge.challengeTitle)
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .padding(28)
        .frame(height: 380)
        .glowCardBackground()
    }

    // MARK: - Skipped

    private var skippedState: some View {
        VStack {
            Spacer()

            Text("Your challenge is here whenever you're ready")
                .font(.custom("Raleway-Medium", size: 17))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: 24)

            Button { onMaybeLater() } label: {
                Text("Maybe Later")
                    .font(.custom("Raleway-Medium", size: 15))
                    .foregroundStyle(DesignColors.accentWarm)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(28)
        .frame(height: 380)
        .glowCardBackground()
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("Raleway-Medium", size: 11))
            .foregroundStyle(DesignColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background { Capsule().fill(DesignColors.structure.opacity(0.15)) }
    }
}

// `glowCardBackground()` moved to DesignSystem/Components/GlowCardBackground.swift
