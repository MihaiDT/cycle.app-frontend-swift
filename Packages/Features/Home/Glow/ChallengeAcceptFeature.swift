import ComposableArchitecture
import SwiftUI

// MARK: - Challenge Accept Feature

@Reducer
public struct ChallengeAcceptFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public let challenge: ChallengeSnapshot
        public init(challenge: ChallengeSnapshot) { self.challenge = challenge }
    }

    public enum Action: Sendable {
        case openCameraTapped
        case chooseFromGalleryTapped
        case delegate(Delegate)
        public enum Delegate: Sendable {
            case openCamera
            case openGallery
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .openCameraTapped:
                return .send(.delegate(.openCamera))
            case .chooseFromGalleryTapped:
                return .send(.delegate(.openGallery))
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Challenge Accept View

struct ChallengeAcceptView: View {
    let store: StoreOf<ChallengeAcceptFeature>
    @Environment(\.dismiss) private var dismiss

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
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignColors.text)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(DesignColors.text.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Phase anchor

    private var phaseAnchor: some View {
        Text("Today · \(store.challenge.cyclePhase) phase")
            .font(.custom("Raleway-Bold", size: 11))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(DesignColors.accentWarm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
            .accessibilityLabel("Today, \(store.challenge.cyclePhase) phase")
    }

    // MARK: - Title block

    private var titleBlock: some View {
        Text(store.challenge.challengeTitle)
            .font(.custom("Raleway-Black", size: 44))
            .tracking(-0.9)
            .lineSpacing(-6)
            .foregroundStyle(DesignColors.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Why subtitle

    private var whySubtitle: some View {
        Text(store.challenge.challengeDescription)
            .font(.custom("Raleway-Medium", size: 17))
            .foregroundStyle(DesignColors.textPrincipal)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: 10) {
            statBox(value: store.challenge.durationDisplay, label: "Time")
            statBox(value: store.challenge.effortDisplay, label: "Effort")
            statBox(value: store.challenge.themeDisplay, label: "Theme")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Takes \(store.challenge.durationDisplay), " +
            "effort \(store.challenge.effortDisplay), " +
            "theme \(store.challenge.themeDisplay)"
        )
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 7) {
            Text(value)
                .font(.custom("Raleway-Black", size: 20))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(.custom("Raleway-Bold", size: 9))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DesignColors.cardWarm)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DesignColors.text.opacity(0.07), lineWidth: 1)
                )
        )
    }

    // MARK: - How card

    private var howCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How to do it")
                .font(.custom("Raleway-Black", size: 10))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.bottom, 14)

            ForEach(Array(store.challenge.tips.enumerated()), id: \.offset) { index, tip in
                tipRow(number: index + 1, text: tip, isFirst: index == 0)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignColors.cardWarm)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DesignColors.text.opacity(0.07), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func tipRow(number: Int, text: String, isFirst: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFirst {
                Rectangle()
                    .fill(DesignColors.text.opacity(0.08))
                    .frame(height: 1)
            }
            HStack(alignment: .top, spacing: 14) {
                Text("\(number)")
                    .font(.custom("Raleway-Black", size: 11))
                    .foregroundStyle(DesignColors.background)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(DesignColors.text))
                Text(text)
                    .font(.custom("Raleway-Medium", size: 15))
                    .foregroundStyle(DesignColors.textPrincipal)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)")
    }

    // MARK: - CTA cluster

    private var ctaCluster: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [DesignColors.background.opacity(0), DesignColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.send(.openCameraTapped)
                } label: {
                    Text("Start challenge")
                }
                .buttonStyle(GlowPrimaryButtonStyle())
                .accessibilityLabel("Start challenge")
                .accessibilityHint("Opens the camera to take a photo of your challenge")

                Button {
                    store.send(.chooseFromGalleryTapped)
                } label: {
                    Text("Or choose from gallery")
                        .font(.custom("Raleway-SemiBold", size: 13))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Choose an existing photo instead of taking a new one")

                Text("Earns 50–100 glow on completion")
                    .font(.custom("Raleway-SemiBold", size: 11))
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.top, 4)
                    .accessibilityLabel("Earns 50 to 100 glow points on completion")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
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
