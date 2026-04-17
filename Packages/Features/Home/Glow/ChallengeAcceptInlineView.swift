import SwiftUI

/// Inline version of the challenge accept screen — used as the first step
/// of the ChallengeJourneyView. Driven by closures instead of a TCA store.
struct ChallengeAcceptInlineView: View {
    let challenge: ChallengeSnapshot
    let onStart: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    phaseAnchor
                    titleBlock
                    whySubtitle
                    statRow
                    howCard
                    Spacer(minLength: 170)
                }
            }
            ctaCluster
        }
        .background(DesignColors.background.ignoresSafeArea())
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignColors.text)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(DesignColors.text.opacity(0.08)))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close challenge")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Phase anchor

    private var phaseAnchor: some View {
        Text("Today · \(challenge.cyclePhase) phase")
            .font(.custom("Raleway-Bold", size: 11, relativeTo: .caption2))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(DesignColors.accentWarm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
            .accessibilityLabel("Today, \(challenge.cyclePhase) phase")
    }

    // MARK: - Title

    private var titleBlock: some View {
        Text(challenge.challengeTitle)
            .font(.custom("Raleway-Black", size: 44, relativeTo: .largeTitle))
            .tracking(-0.9)
            .lineSpacing(-6)
            .foregroundStyle(DesignColors.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Description

    private var whySubtitle: some View {
        Text(challenge.challengeDescription.cleanedAIText)
            .font(.custom("Raleway-Medium", size: 17, relativeTo: .body))
            .foregroundStyle(DesignColors.textPrincipal)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
    }

    // MARK: - Stats

    private var statRow: some View {
        HStack(spacing: 10) {
            statBox(value: challenge.durationDisplay, label: "Time")
            statBox(value: challenge.effortDisplay, label: "Effort")
            statBox(value: challenge.themeDisplay, label: "Theme")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 7) {
            Text(value)
                .font(.custom("Raleway-Black", size: 20, relativeTo: .title3))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(.custom("Raleway-Bold", size: 9, relativeTo: .caption2))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 10)
        .glowCardBackground(tint: .neutral)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - How to

    private var howCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How to do it")
                .font(.custom("Raleway-Black", size: 10, relativeTo: .caption2))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.bottom, 14)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(challenge.tips.enumerated()), id: \.offset) { index, tip in
                tipRow(number: index + 1, text: tip, isFirst: index == 0)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glowCardBackground(tint: .rose)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func tipRow(number: Int, text: String, isFirst: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFirst {
                Rectangle()
                    .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .top, spacing: 14) {
                Text("\(number)")
                    .font(.custom("Raleway-Black", size: 11, relativeTo: .caption))
                    .foregroundStyle(DesignColors.background)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(DesignColors.text))
                    .accessibilityHidden(true)
                Text(text)
                    .font(.custom("Raleway-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.textPrincipal)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Step \(number): \(text)")
        }
    }

    // MARK: - CTA

    private var ctaCluster: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [DesignColors.background.opacity(0), DesignColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStart()
                } label: {
                    Text("Begin your moment")
                }
                .buttonStyle(GlowPrimaryButtonStyle())
                .accessibilityLabel("Begin your moment")
                .accessibilityHint("Starts the challenge timer")
            }
            .padding(.horizontal, AppLayout.horizontalPadding)
            .padding(.bottom, 34)
            .background(DesignColors.background)
        }
    }
}

// MARK: - ChallengeSnapshot Display Helpers

extension ChallengeSnapshot {
    /// Short label for the stat row. `energyLevel` is a 1–10 scale.
    var effortDisplay: String {
        switch energyLevel {
        case ...3:  return "Gentle"
        case 4...6: return "Moderate"
        default:    return "Active"
        }
    }

    /// Human-readable category label for the stat row.
    var themeDisplay: String {
        switch challengeCategory.lowercased() {
        case "self_care":   return "Self care"
        case "mindfulness": return "Mindful"
        case "movement":    return "Movement"
        case "creative":    return "Creative"
        case "nutrition":   return "Nutrition"
        case "social":      return "Social"
        default:            return challengeCategory.prefix(1).uppercased() + challengeCategory.dropFirst()
        }
    }

    /// Time estimate for the stat row. Local heuristic until backend adds an estimatedMinutes field.
    var durationDisplay: String {
        switch challengeCategory.lowercased() {
        case "creative": return "15 min"
        case "movement": return "10 min"
        default:         return "5 min"
        }
    }
}
