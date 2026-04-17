import Inject
import SwiftUI

// MARK: - Personal Goal Type

public enum PersonalGoal: String, CaseIterable, Identifiable, Equatable, Hashable, Sendable {
    case emotionalBalance = "emotional_balance"
    case energyClarity = "energy_clarity"
    case harmoniousRelationships = "harmonious_relationships"
    case motivation = "motivation"
    case selfUnderstanding = "self_understanding"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .emotionalBalance: return "Emotional Balance"
        case .energyClarity: return "Energy & Clarity"
        case .harmoniousRelationships: return "Harmonious Relationships"
        case .motivation: return "Motivation"
        case .selfUnderstanding: return "Self Understanding"
        }
    }

    public var subtitle: String {
        switch self {
        case .emotionalBalance: return "Find inner peace and stability"
        case .energyClarity: return "Feel vibrant and focused"
        case .harmoniousRelationships: return "Connect deeply with others"
        case .motivation: return "Stay driven and inspired"
        case .selfUnderstanding: return "Know yourself better"
        }
    }
}

// MARK: - Personal Goals View

public struct PersonalGoalsView: View {
    @ObserveInjection var inject
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var selectedGoals: Set<PersonalGoal>
    public let onNext: () -> Void
    public let onBack: (() -> Void)?

    @State private var animatedGoals: Set<PersonalGoal> = []

    public init(
        selectedGoals: Binding<Set<PersonalGoal>>,
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self._selectedGoals = selectedGoals
        self.onNext = onNext
        self.onBack = onBack
    }

    public var body: some View {
        OnboardingLayout(
            currentStep: 10,
            totalSteps: 11,
            onBack: onBack,
            onNext: onNext,
            nextButtonEnabled: !selectedGoals.isEmpty,
            nextButtonTitle: "Almost Done"
        ) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text("personal touch")
                        .font(.raleway("Regular", size: 13, relativeTo: .caption))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundColor(DesignColors.text.opacity(0.5))

                    Text("Your Intentions")
                        .font(.raleway("Bold", size: 32, relativeTo: .title))
                        .foregroundColor(DesignColors.text)
                        .accessibilityAddTraits(.isHeader)

                    Text("Select all that resonate with you")
                        .font(.raleway("Regular", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(.bottom, 20)

                // Goals list
                VStack(spacing: 12) {
                    ForEach(Array(PersonalGoal.allCases.enumerated()), id: \.element.id) { index, goal in
                        GoalCard(
                            goal: goal,
                            isSelected: selectedGoals.contains(goal),
                            isAnimated: animatedGoals.contains(goal)
                        ) {
                            toggleGoal(goal)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear {
            // Stagger animation on appear - show instantly under reduceMotion
            if reduceMotion {
                animatedGoals = Set(PersonalGoal.allCases)
            } else {
                for (index, goal) in PersonalGoal.allCases.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.06) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            _ = animatedGoals.insert(goal)
                        }
                    }
                }
            }
        }
        .enableInjection()
    }

    private func toggleGoal(_ goal: PersonalGoal) {
        #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        #endif

        withAnimation(reduceMotion ? nil : .appBalanced) {
            if selectedGoals.contains(goal) {
                selectedGoals.remove(goal)
            } else {
                _ = selectedGoals.insert(goal)
            }
        }
    }
}

// MARK: - Goal Card

private struct GoalCard: View {
    let goal: PersonalGoal
    let isSelected: Bool
    let isAnimated: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [DesignColors.accentWarm, DesignColors.accentSecondary.opacity(0.4)]
                                : [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, 12)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.raleway("SemiBold", size: 17, relativeTo: .body))
                        .foregroundColor(DesignColors.text)

                    Text(goal.subtitle)
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(isSelected ? 0.6 : 0.4))
                }
                .padding(.leading, 16)

                Spacer()

                // Checkbox
                GoalCheckbox(isSelected: isSelected)
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 20)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 20)
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignColors.accentWarm.opacity(0.08))
                        .blur(radius: 12)
                        .offset(y: 4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: isSelected
                                ? [DesignColors.accentWarm.opacity(0.5), DesignColors.accentWarm.opacity(0.15)]
                                : [Color.white.opacity(0.3), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            }
            .shadow(
                color: isSelected
                    ? DesignColors.accentWarm.opacity(0.12)
                    : Color.black.opacity(0.06),
                radius: isSelected ? 12 : 6,
                x: 0,
                y: isSelected ? 6 : 3
            )
            .scaleEffect(isAnimated ? 1.0 : 0.95)
            .opacity(isAnimated ? 1.0 : 0.0)
        }
        .buttonStyle(.plain)
        .animation(.appBalanced, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(goal.title). \(goal.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

// MARK: - Goal Checkbox (Same style as other screens)

private struct GoalCheckbox: View {
    let isSelected: Bool

    private var checkmarkColor: Color {
        DesignColors.accentWarm
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: 1.78125 * (24.0 / 19.0),
            lineCap: .round,
            lineJoin: .round
        )
    }

    var body: some View {
        ZStack {
            // Full circle - visible when not selected
            Circle()
                .stroke(DesignColors.accentSecondary.opacity(0.5), style: strokeStyle)
                .opacity(isSelected ? 0 : 1)

            // Circle with gap - visible when selected
            GoalCircleWithGap()
                .stroke(checkmarkColor, style: strokeStyle)
                .opacity(isSelected ? 1 : 0)

            // Checkmark - animated
            GoalCheckmark(progress: isSelected ? 1 : 0)
                .stroke(checkmarkColor, style: strokeStyle)
                .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Circle with Gap Shape

private struct GoalCircleWithGap: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 19.0

        var path = Path()

        path.move(to: CGPoint(x: 17.4168 * scale, y: 8.77148 * scale))
        path.addLine(to: CGPoint(x: 17.4168 * scale, y: 9.49981 * scale))

        path.addCurve(
            to: CGPoint(x: 15.8409 * scale, y: 14.2354 * scale),
            control1: CGPoint(x: 17.4159 * scale, y: 11.207 * scale),
            control2: CGPoint(x: 16.8631 * scale, y: 12.8681 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 11.7448 * scale, y: 17.0871 * scale),
            control1: CGPoint(x: 14.8187 * scale, y: 15.6027 * scale),
            control2: CGPoint(x: 13.3819 * scale, y: 16.603 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 6.75662 * scale, y: 16.9214 * scale),
            control1: CGPoint(x: 10.1077 * scale, y: 17.5711 * scale),
            control2: CGPoint(x: 8.35799 * scale, y: 17.513 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 2.85884 * scale, y: 13.8042 * scale),
            control1: CGPoint(x: 5.15524 * scale, y: 16.3297 * scale),
            control2: CGPoint(x: 3.78801 * scale, y: 15.2363 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 1.60066 * scale, y: 8.97439 * scale),
            control1: CGPoint(x: 1.92967 * scale, y: 12.372 * scale),
            control2: CGPoint(x: 1.48833 * scale, y: 10.6779 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 3.48213 * scale, y: 4.35166 * scale),
            control1: CGPoint(x: 1.71298 * scale, y: 7.27093 * scale),
            control2: CGPoint(x: 2.37295 * scale, y: 5.6494 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 7.75548 * scale, y: 1.77326 * scale),
            control1: CGPoint(x: 4.59132 * scale, y: 3.05392 * scale),
            control2: CGPoint(x: 6.09028 * scale, y: 2.14949 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 12.7223 * scale, y: 2.26398 * scale),
            control1: CGPoint(x: 9.42067 * scale, y: 1.39703 * scale),
            control2: CGPoint(x: 11.1629 * scale, y: 1.56916 * scale)
        )

        return path
    }
}

// MARK: - Checkmark Shape

private struct GoalCheckmark: Shape {
    var animatableData: CGFloat

    init(progress: CGFloat = 1) {
        self.animatableData = progress
    }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 19.0

        var path = Path()
        path.move(to: CGPoint(x: 7.12517 * scale, y: 8.71606 * scale))
        path.addLine(to: CGPoint(x: 9.50017 * scale, y: 11.0911 * scale))
        path.addLine(to: CGPoint(x: 17.4168 * scale, y: 3.16648 * scale))

        return path.trimmedPath(from: 0, to: animatableData)
    }
}

// MARK: - Preview

#Preview {
    PersonalGoalsView(
        selectedGoals: .constant([.emotionalBalance, .motivation]),
        onNext: {},
        onBack: {}
    )
}
