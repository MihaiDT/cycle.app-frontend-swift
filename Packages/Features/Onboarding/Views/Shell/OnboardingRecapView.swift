import SwiftUI

// MARK: - Onboarding Recap View

public struct OnboardingRecapView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let userName: String
    public let birthDate: Date
    public let relationshipStatus: RelationshipStatus?
    public let professionalContext: ProfessionalContext?
    public let lifestyleType: LifestyleType?
    public let cycleDuration: Int
    public let periodDuration: Int
    public let personalGoals: Set<PersonalGoal>
    public let onFinish: () -> Void
    public let onBack: (() -> Void)?

    @State private var showHeader = false
    @State private var showCards = false
    @State private var showButton = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    public init(
        userName: String,
        birthDate: Date,
        relationshipStatus: RelationshipStatus?,
        professionalContext: ProfessionalContext?,
        lifestyleType: LifestyleType?,
        cycleDuration: Int,
        periodDuration: Int,
        personalGoals: Set<PersonalGoal>,
        onFinish: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.userName = userName
        self.birthDate = birthDate
        self.relationshipStatus = relationshipStatus
        self.professionalContext = professionalContext
        self.lifestyleType = lifestyleType
        self.cycleDuration = cycleDuration
        self.periodDuration = periodDuration
        self.personalGoals = personalGoals
        self.onFinish = onFinish
        self.onBack = onBack
    }

    private var infoChips: [(String, String)] {
        var chips: [(String, String)] = []
        if let status = relationshipStatus {
            chips.append(("heart", status.rawValue))
        }
        if let context = professionalContext {
            chips.append(("briefcase", context.rawValue))
        }
        if let lifestyle = lifestyleType {
            chips.append(("leaf", lifestyle.title))
        }
        return chips
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                OnboardingBackground()

                VStack(spacing: 0) {
                    Spacer().frame(height: geometry.safeAreaInsets.top + 16)

                    OnboardingHeader(
                        currentStep: 11,
                        totalSteps: 11,
                        onBack: onBack
                    )

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer().frame(height: 32)

                            // Greeting with checkmark
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    DesignColors.accent.opacity(0.4),
                                                    DesignColors.accentWarm.opacity(0.6),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 64, height: 64)

                                    Image(systemName: "checkmark")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .scaleEffect(showHeader ? 1 : 0.3)
                                .opacity(showHeader ? 1 : 0)
                                .accessibilityHidden(true)

                                Text("You're all set,\n\(userName)!")
                                    .font(.raleway("Bold", size: 32, relativeTo: .title))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                DesignColors.text,
                                                DesignColors.textPrincipal,
                                                DesignColors.accentWarm,
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .opacity(showHeader ? 1 : 0)
                                    .offset(y: showHeader ? 0 : 12)
                                    .accessibilityAddTraits(.isHeader)
                            }

                            Spacer().frame(height: 28)

                            // Stat pills row
                            HStack(spacing: 12) {
                                StatPill(
                                    icon: "calendar.circle.fill",
                                    value: "\(cycleDuration)",
                                    label: "day cycle"
                                )

                                StatPill(
                                    icon: "drop.circle.fill",
                                    value: "\(periodDuration)",
                                    label: "day period"
                                )

                                StatPill(
                                    icon: "birthday.cake.fill",
                                    value: ageString,
                                    label: "years old"
                                )
                            }
                            .padding(.horizontal, 24)
                            .opacity(showCards ? 1 : 0)
                            .offset(y: showCards ? 0 : 16)

                            Spacer().frame(height: 24)

                            // Info chips (relationship, profession, lifestyle)
                            if !infoChips.isEmpty {
                                RecapFlowLayout(spacing: 10) {
                                    ForEach(Array(infoChips.enumerated()), id: \.offset) { _, chip in
                                        HStack(spacing: 8) {
                                            Image(systemName: chip.0)
                                                .font(.system(size: 13))
                                                .foregroundColor(DesignColors.accentWarm)
                                                .accessibilityHidden(true)
                                            Text(chip.1)
                                                .font(.raleway("Medium", size: 14, relativeTo: .body))
                                                .foregroundColor(DesignColors.text)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background {
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                                .overlay {
                                                    Capsule()
                                                        .strokeBorder(
                                                            LinearGradient(
                                                                colors: [
                                                                    Color.white.opacity(0.5),
                                                                    Color.white.opacity(0.1),
                                                                ],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            ),
                                                            lineWidth: 0.5
                                                        )
                                                }
                                        }
                                        .accessibilityElement(children: .combine)
                                    }
                                }
                                .padding(.horizontal, 32)
                                .opacity(showCards ? 1 : 0)
                                .offset(y: showCards ? 0 : 16)

                                Spacer().frame(height: 24)
                            }

                            // Goals section
                            if !personalGoals.isEmpty {
                                VStack(spacing: 14) {
                                    Text("Your Focus")
                                        .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                                        .tracking(1)
                                        .foregroundColor(DesignColors.text.opacity(0.5))
                                        .accessibilityAddTraits(.isHeader)

                                    VStack(spacing: 10) {
                                        ForEach(Array(personalGoals.sorted(by: { $0.title < $1.title })), id: \.self) {
                                            goal in
                                            HStack(spacing: 14) {
                                                Image(systemName: goalIcon(for: goal))
                                                    .font(.system(size: 18))
                                                    .foregroundColor(DesignColors.accentWarm)
                                                    .frame(width: 28)
                                                    .accessibilityHidden(true)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(goal.title)
                                                        .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                                                        .foregroundColor(DesignColors.text)
                                                    Text(goal.subtitle)
                                                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                                                        .foregroundColor(DesignColors.textSecondary)
                                                }

                                                Spacer()

                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(DesignColors.accentWarm.opacity(0.7))
                                                    .accessibilityHidden(true)
                                            }
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 14)
                                            .background {
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(.ultraThinMaterial)
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .strokeBorder(
                                                                LinearGradient(
                                                                    colors: [
                                                                        Color.white.opacity(0.4),
                                                                        Color.white.opacity(0.1),
                                                                    ],
                                                                    startPoint: .topLeading,
                                                                    endPoint: .bottomTrailing
                                                                ),
                                                                lineWidth: 0.5
                                                            )
                                                    }
                                            }
                                            .accessibilityElement(children: .combine)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .opacity(showCards ? 1 : 0)
                                .offset(y: showCards ? 0 : 16)
                            }

                            Spacer().frame(height: 32)

                            // Motivational tagline
                            Text("Your journey to self-awareness starts now")
                                .font(.raleway("Regular", size: 14, relativeTo: .body))
                                .foregroundColor(DesignColors.textSecondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .opacity(showButton ? 1 : 0)

                            Spacer().frame(height: 100)
                        }
                    }

                    Spacer()

                    // CTA button
                    OnboardingCTAButton(title: "Start Your Journey", action: onFinish)
                        .opacity(showButton ? 1 : 0)
                        .scaleEffect(showButton ? 1 : 0.9)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + AppLayout.bottomOffset)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                showHeader = true
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.4)) {
                showCards = true
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.7)) {
                showButton = true
            }

        }
    }

    private var ageString: String {
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return "\(age)"
    }

    private func goalIcon(for goal: PersonalGoal) -> String {
        switch goal {
        case .emotionalBalance: return "heart.circle"
        case .energyClarity: return "bolt.circle"
        case .harmoniousRelationships: return "person.2.circle"
        case .motivation: return "flame.circle"
        case .selfUnderstanding: return "brain.head.profile"
        }
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(DesignColors.accentWarm)
                .accessibilityHidden(true)

            Text(value)
                .font(.raleway("Bold", size: 24, relativeTo: .title2))
                .foregroundColor(DesignColors.text)

            Text(label)
                .font(.raleway("Regular", size: 11, relativeTo: .caption2))
                .foregroundColor(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Flow Layout

private struct RecapFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize)
    {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return (positions, CGSize(width: totalWidth, height: currentY + lineHeight))
    }
}

// MARK: - Preview

#Preview("Onboarding Recap") {
    OnboardingRecapView(
        userName: "Maria",
        birthDate: Date(),
        relationshipStatus: .inRelationship,
        professionalContext: .freelancer,
        lifestyleType: .calm,
        cycleDuration: 28,
        periodDuration: 5,
        personalGoals: [.emotionalBalance, .energyClarity],
        onFinish: { },
        onBack: { }
    )
}
