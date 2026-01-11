import SwiftUI

// MARK: - Name Input View

public struct NameInputView: View {
    @Binding public var name: String
    public let onNext: () -> Void
    public let onBack: (() -> Void)?

    public init(
        name: Binding<String>,
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self._name = name
        self.onNext = onNext
        self.onBack = onBack
    }

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        OnboardingLayout(
            currentStep: 2,
            totalSteps: 5,
            onBack: onBack,
            onNext: onNext,
            nextButtonEnabled: canContinue
        ) {
            VStack(spacing: 0) {
                // Subtitle
                Text("a personal touch")
                    .font(.custom("Raleway-Regular", size: 13))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(DesignColors.text.opacity(0.5))

                Spacer().frame(height: 12)

                // Title
                Text("What should we call you?")
                    .font(.custom("Raleway-Bold", size: 24))
                    .foregroundColor(DesignColors.text)

                Spacer().frame(height: 32)

                // Name input field
                GlassTextField(
                    text: $name,
                    placeholder: "Your name"
                )
                .padding(.horizontal, 32)

                Spacer().frame(height: 16)

                // Description
                Text("This will appear in your experience.\nChange it anytime.")
                    .font(.custom("Raleway-Regular", size: 18))
                    .foregroundColor(DesignColors.text.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview("Name Input") {
    NameInputView(
        name: .constant(""),
        onNext: {},
        onBack: { print("Back tapped") }
    )
}

#Preview("Name Input - Filled") {
    NameInputView(
        name: .constant("Sarah"),
        onNext: {},
        onBack: { print("Back tapped") }
    )
}
