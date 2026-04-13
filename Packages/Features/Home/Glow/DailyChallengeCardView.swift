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
                    .font(.system(size: 12, weight: .bold))
                Text("Challenge")
                    .font(.custom("Raleway-Black", size: 12, relativeTo: .caption))
                    .tracking(0.3)
            }
            .foregroundStyle(DesignColors.accentWarm)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { Capsule().fill(DesignColors.accentWarm.opacity(0.12)) }
            .accessibilityLabel("Challenge")

            Spacer(minLength: 12)

            Text(challenge.challengeTitle)
                .font(.custom("Raleway-Black", size: 24, relativeTo: .title2))
                .tracking(-0.4)
                .foregroundStyle(DesignColors.text)
                .lineSpacing(2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(challenge.challengeDescription)
                .font(.custom("Raleway-Medium", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .lineSpacing(3)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                tagPill(challenge.cyclePhase.capitalized)
                tagPill(challenge.durationDisplay)
                tagPill(challenge.effortDisplay)
            }
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(challenge.cyclePhase.capitalized), " +
                "\(challenge.durationDisplay), " +
                "\(challenge.effortDisplay)"
            )

            Spacer().frame(height: 14)

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDoIt()
                } label: {
                    Text("Do It")
                        .font(.custom("Raleway-Black", size: 16, relativeTo: .body))
                        .tracking(-0.2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Do challenge")
                .accessibilityHint("Opens the challenge detail screen")

                Button { onSkip() } label: {
                    Text("Skip")
                        .font(.custom("Raleway-Medium", size: 15, relativeTo: .callout))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip today's challenge")
            }
        }
        .padding(28)
        .frame(height: 380)
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
        .frame(height: 380)
        .glowCardBackground(tint: .cocoa)
    }

    // MARK: - Skipped

    private var skippedState: some View {
        VStack {
            Spacer()

            Text("Your challenge is here whenever you're ready")
                .font(.custom("Raleway-Medium", size: 17, relativeTo: .body))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: 24)

            Button { onMaybeLater() } label: {
                Text("Maybe Later")
                    .font(.custom("Raleway-Black", size: 15, relativeTo: .callout))
                    .foregroundStyle(DesignColors.accentWarm)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Maybe later")
            .accessibilityHint("Keep today's challenge available for later")

            Spacer()
        }
        .padding(28)
        .frame(height: 380)
        .glowCardBackground(tint: .neutral)
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
