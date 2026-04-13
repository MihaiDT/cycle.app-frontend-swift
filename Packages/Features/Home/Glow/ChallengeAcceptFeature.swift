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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignColors.accentWarm)
                    Text(store.challenge.challengeTitle)
                        .font(.custom("Raleway-Bold", size: 22))
                        .foregroundStyle(DesignColors.text)
                }

                Text(store.challenge.challengeDescription)
                    .font(.custom("Raleway-Regular", size: 16))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(4)

                HStack(spacing: 8) {
                    contextPill(store.challenge.cyclePhase.capitalized)
                    contextPill("Day \(store.challenge.cycleDay)")
                    energyDots(level: store.challenge.energyLevel)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundStyle(DesignColors.text)
                    ForEach(store.challenge.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\u{2022}").foregroundStyle(DesignColors.accentWarm)
                            Text(tip)
                                .font(.custom("Raleway-Regular", size: 14))
                                .foregroundStyle(DesignColors.textSecondary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text("\u{1F947}")
                    Text(store.challenge.goldHint)
                        .font(.custom("Raleway-Medium", size: 14))
                        .foregroundStyle(DesignColors.accentWarm)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignColors.accentWarm.opacity(0.08))
                }

                Text("50\u{2013}100 XP")
                    .font(.custom("Raleway-SemiBold", size: 18))
                    .foregroundStyle(DesignColors.accentWarm)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.send(.openCameraTapped)
                    } label: {
                        Label("Open Camera", systemImage: "camera.fill")
                            .font(.custom("Raleway-SemiBold", size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(DesignColors.accentWarm)
                            }
                    }
                    .buttonStyle(.plain)

                    Button { store.send(.chooseFromGalleryTapped) } label: {
                        Text("Choose from Gallery")
                            .font(.custom("Raleway-Medium", size: 15))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .background(DesignColors.background)
    }

    private func contextPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("Raleway-Medium", size: 12))
            .foregroundStyle(DesignColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background { Capsule().fill(DesignColors.structure.opacity(0.15)) }
    }

    private func energyDots(level: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= level ? DesignColors.accentWarm : DesignColors.structure.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background { Capsule().fill(DesignColors.structure.opacity(0.15)) }
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
