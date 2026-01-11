import SwiftUI

// MARK: - Privacy Consent View

public struct PrivacyConsentView: View {
    public let healthDataConsent: Bool
    public let termsConsent: Bool
    public let onToggleHealthData: () -> Void
    public let onToggleTerms: () -> Void
    public let onBegin: () -> Void
    public let onBack: (() -> Void)?

    public init(
        healthDataConsent: Bool,
        termsConsent: Bool,
        onToggleHealthData: @escaping () -> Void,
        onToggleTerms: @escaping () -> Void,
        onBegin: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.healthDataConsent = healthDataConsent
        self.termsConsent = termsConsent
        self.onToggleHealthData = onToggleHealthData
        self.onToggleTerms = onToggleTerms
        self.onBegin = onBegin
        self.onBack = onBack
    }

    private var canContinue: Bool {
        healthDataConsent && termsConsent
    }

    public var body: some View {
        OnboardingLayout(
            currentStep: 1,
            totalSteps: 5,
            onBack: onBack,
            onNext: onBegin,
            nextButtonEnabled: canContinue
        ) {
            VStack(spacing: 0) {
                // Shield icon with checkmark (centered)
                ShieldCheckIcon()
                    .frame(width: 237, height: 237)
                    .frame(maxWidth: .infinity)

                // Gap to title
                Spacer().frame(height: 12)

                // Subtitle
                Text("your privacy matters")
                    .font(.custom("Raleway-Regular", size: 13))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(DesignColors.text.opacity(0.5))
                    .frame(maxWidth: .infinity)

                Spacer().frame(height: 8)

                // Title (centered)
                Text("For you. And only you.")
                    .font(.custom("Raleway-Bold", size: 24))
                    .foregroundColor(DesignColors.text)
                    .frame(maxWidth: .infinity)

                // Gap to description
                Spacer().frame(height: 12)

                // Description (centered)
                Text("Your health data is protected and kept private.\nReview, export, or delete it anytime.")
                    .font(.custom("Raleway-Regular", size: 18))
                    .foregroundColor(DesignColors.text.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 24)

                // Gap to checkboxes
                Spacer().frame(height: 24)

                // Consent checkboxes
                VStack(spacing: 26) {
                    // Health data consent
                    ConsentCheckbox(
                        isChecked: healthDataConsent,
                        action: onToggleHealthData
                    ) {
                        (Text("I consent to the processing of my health data to enable core features in Cycle.\n")
                            .font(.custom("Raleway-Regular", size: 16))
                            .foregroundColor(DesignColors.text.opacity(0.7))
                            + Text("Learn more in the ")
                            .font(.custom("Raleway-Regular", size: 16))
                            .foregroundColor(DesignColors.text.opacity(0.7))
                            + Text("Privacy Policy")
                            .font(.custom("Raleway-SemiBold", size: 16))
                            .foregroundColor(DesignColors.link)
                            .underline()
                            + Text(".")
                            .font(.custom("Raleway-Regular", size: 16))
                            .foregroundColor(DesignColors.text.opacity(0.7)))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Terms consent
                    ConsentCheckbox(
                        isChecked: termsConsent,
                        action: onToggleTerms
                    ) {
                        (Text("I agree to the ")
                            .font(.custom("Raleway-Regular", size: 16))
                            .foregroundColor(DesignColors.text.opacity(0.7))
                            + Text("Privacy Policy")
                            .font(.custom("Raleway-SemiBold", size: 16))
                            .foregroundColor(DesignColors.link)
                            .underline()
                            + Text(" and ")
                            .font(.custom("Raleway-Regular", size: 16))
                            .foregroundColor(DesignColors.text.opacity(0.7))
                            + Text("Terms of Use")
                            .font(.custom("Raleway-SemiBold", size: 16))
                            .foregroundColor(DesignColors.link)
                            .underline()
                            + Text(".")
                            .font(.custom("Raleway-Regular", size: 16))
                            .foregroundColor(DesignColors.text.opacity(0.7)))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
    }
}

#Preview("Privacy Consent") {
    PrivacyConsentView(
        healthDataConsent: false,
        termsConsent: false,
        onToggleHealthData: {},
        onToggleTerms: {},
        onBegin: {},
        onBack: { print("Back tapped") }
    )
}

#Preview("Privacy Consent - Checked") {
    PrivacyConsentView(
        healthDataConsent: true,
        termsConsent: true,
        onToggleHealthData: {},
        onToggleTerms: {},
        onBegin: {},
        onBack: { print("Back tapped") }
    )
}
