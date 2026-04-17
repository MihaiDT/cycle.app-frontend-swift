import SwiftUI

// MARK: - Daily Challenge Card View

struct DailyChallengeCardView: View {
    let challenge: ChallengeSnapshot
    var isInProgress: Bool = false
    let onDoIt: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onMaybeLater: () -> Void

    var body: some View {
        switch challenge.status {
        case .available: availableState
        case .skipped: skippedState
        case .completed: completedState
        }
    }

    // MARK: - Available

    private var availableState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your moment")
                .font(.custom("Raleway-SemiBold", size: 12, relativeTo: .caption))
                .tracking(0.2)
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background { Capsule().fill(DesignColors.accentWarm.opacity(0.12)) }
                .accessibilityLabel("Your moment")

            Text(challenge.challengeTitle)
                .font(.custom("Raleway-Bold", size: 22, relativeTo: .title2))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .lineSpacing(2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: DesignColors.background.opacity(0.75), radius: 4, x: 0, y: 0)
                .accessibilityAddTraits(.isHeader)

            Text(challenge.challengeDescription.cleanedAIText)
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
                if isInProgress {
                    onContinue()
                } else {
                    onDoIt()
                }
            } label: {
                Text(isInProgress ? "Continue" : "Take your moment")
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
            .accessibilityLabel(isInProgress ? "Continue your moment" : "Take your moment")
            .accessibilityHint("Opens the challenge detail screen")
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 340)
        .glowCardBackground(tint: .cocoa)
    }

    // MARK: - Skipped ("Let it go for today" → see you tomorrow)

    private var skippedState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Resting")
                    .font(.custom("Raleway-SemiBold", size: 12, relativeTo: .caption))
                    .tracking(0.2)
            }
            .foregroundStyle(DesignColors.accentWarm)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { Capsule().fill(DesignColors.accentWarm.opacity(0.12)) }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                Text("Tomorrow - something fresh")
                    .font(.custom("Raleway-Bold", size: 22, relativeTo: .title2))
                    .tracking(-0.3)
                    .foregroundStyle(DesignColors.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: DesignColors.background.opacity(0.75), radius: 4, x: 0, y: 0)
                    .accessibilityAddTraits(.isHeader)

                Text("Today wasn't the right day for \u{201C}\(challenge.challengeTitle)\u{201D} — Aria will pick a new challenge for you tomorrow.")
                    .font(.custom("Raleway-Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.textPrincipal)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: DesignColors.background.opacity(0.6), radius: 3, x: 0, y: 0)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignColors.accentWarm)
                    .accessibilityHidden(true)
                Text("See you tomorrow")
                    .font(.custom("Raleway-SemiBold", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.accentWarm)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 340)
        .glowCardBackground(tint: .cocoa)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Challenge resting. Today wasn't the right day for \(challenge.challengeTitle). " +
            "Aria will pick a fresh challenge for you tomorrow."
        )
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
                        .accessibilityLabel("Earned \(challenge.xpEarned) experience points")
                }
            }
            .accessibilityElement(children: .combine)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(completedAccessibilityLabel)
    }

    private var completedAccessibilityLabel: String {
        var parts: [String] = ["Completed challenge: \(challenge.challengeTitle)"]
        if let rating = challenge.validationRating {
            parts.append("Rating: \(rating.capitalized)")
        }
        parts.append("Earned \(challenge.xpEarned) experience points")
        if let feedback = challenge.validationFeedback {
            parts.append(feedback)
        }
        return parts.joined(separator: ". ")
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

// MARK: - Challenge Empty State

/// Shown in the card stack's "do" slot when the challenge selector returns
/// nil (no template matched today's phase/energy combination, or the glow
/// profile returned empty). Reads as premium/gentle, not as a hard error.
struct ChallengeEmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Challenge")
                    .font(.custom("Raleway-SemiBold", size: 12, relativeTo: .caption))
                    .tracking(0.2)
            }
            .foregroundStyle(DesignColors.accentWarm)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { Capsule().fill(DesignColors.accentWarm.opacity(0.12)) }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("No challenge today")
                    .font(.custom("Raleway-Bold", size: 22, relativeTo: .title2))
                    .tracking(-0.3)
                    .foregroundStyle(DesignColors.text)
                    .shadow(color: DesignColors.background.opacity(0.75), radius: 4, x: 0, y: 0)

                Text("Rest up — a fresh one will be here\ntomorrow, tuned to how you feel.")
                    .font(.custom("Raleway-Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.textPrincipal)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: DesignColors.background.opacity(0.6), radius: 3, x: 0, y: 0)
            }

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 340)
        .glowCardBackground(tint: .cocoa)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No challenge today. Rest up — a fresh one will be here tomorrow, tuned to how you feel.")
    }
}

// `glowCardBackground()` moved to DesignSystem/Components/GlowCardBackground.swift
