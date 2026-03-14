import SwiftUI

// MARK: - Onboarding Recap View

public struct OnboardingRecapView: View {
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

    @State private var animateIn = false

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

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                OnboardingBackground()

                VStack(spacing: 0) {
                    // Header
                    Spacer().frame(height: geometry.safeAreaInsets.top + 16)

                    OnboardingHeader(
                        currentStep: 10,
                        totalSteps: 10,
                        onBack: onBack
                    )

                    Spacer().frame(height: 24)

                    // Title section
                    VStack(spacing: 8) {
                        Text("all set")
                            .font(.custom("Raleway-Regular", size: 13))
                            .tracking(3)
                            .textCase(.uppercase)
                            .foregroundColor(DesignColors.text.opacity(0.5))

                        Text("Welcome, \(userName)!")
                            .font(.custom("Raleway-Bold", size: 28))
                            .foregroundColor(DesignColors.text)

                        Text("Here's your personalized profile")
                            .font(.custom("Raleway-Regular", size: 16))
                            .foregroundColor(DesignColors.textSecondary)
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)

                    Spacer().frame(height: 32)

                    // Recap cards
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Personal Info
                            RecapCard(title: "Personal Info", icon: "person.fill") {
                                RecapRow(label: "Name", value: userName)
                                RecapRow(label: "Birth Date", value: dateFormatter.string(from: birthDate))
                                if let status = relationshipStatus {
                                    RecapRow(label: "Relationship", value: status.rawValue)
                                }
                                if let context = professionalContext {
                                    RecapRow(label: "Profession", value: context.rawValue)
                                }
                                if let lifestyle = lifestyleType {
                                    RecapRow(label: "Lifestyle", value: lifestyle.title)
                                }
                            }
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 20)

                            // Cycle Info
                            RecapCard(title: "Cycle Details", icon: "calendar") {
                                RecapRow(label: "Cycle Length", value: "\(cycleDuration) days")
                                RecapRow(label: "Period Duration", value: "\(periodDuration) days")
                            }
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 20)

                            // Goals
                            if !personalGoals.isEmpty {
                                RecapCard(title: "Your Goals", icon: "star.fill") {
                                    ForEach(Array(personalGoals), id: \.self) { goal in
                                        RecapRow(label: "", value: goal.title)
                                    }
                                }
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 20)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    // Finish button
                    GlassButton("Start Your Journey", showArrow: true, width: 240) {
                        onFinish()
                    }
                    .opacity(animateIn ? 1 : 0)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + AppLayout.bottomOffset)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Recap Card

private struct RecapCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignColors.accentWarm)

                Text(title)
                    .font(.custom("Raleway-SemiBold", size: 18))
                    .foregroundColor(DesignColors.text)
            }

            // Content
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignColors.background.opacity(0.8))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - Recap Row

private struct RecapRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            if !label.isEmpty {
                Text(label)
                    .font(.custom("Raleway-Regular", size: 15))
                    .foregroundColor(DesignColors.textSecondary)
                Spacer()
            }
            Text(value)
                .font(.custom("Raleway-Medium", size: 15))
                .foregroundColor(DesignColors.text)
            if label.isEmpty {
                Spacer()
            }
        }
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
        onFinish: { print("Finish tapped") },
        onBack: { print("Back tapped") }
    )
}
